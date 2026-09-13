param([string]$ConfigPath='')
$ErrorActionPreference='Stop'
. "$PSScriptRoot/evidence_common.ps1"
. "$PSScriptRoot/toolchain_common.ps1"
$state=[ordered]@{result='RUNNING';generatedAt=(Get-Date -Format o);configuration=$null;tools=@();error=$null}
Write-EvidenceJson 'reports/runtime_manifest.json' $state
try {
  $state.configuration=Initialize-Toolchain $ConfigPath
  foreach ($name in @('vlib','vlog','vsim','vcover','git')) {
    $command=Get-Command $name -CommandType Application -ErrorAction Stop | Select-Object -First 1
    if ($name -eq 'vlib') {
      # ModelSim 10.4 vlib has no -version option. Record file metadata and
      # validate its actual library creation below; do not waive exit errors.
      $fileVersion=(Get-Item -LiteralPath $command.Source).VersionInfo.FileVersion
      $state.tools+=@{name=$name;path=$command.Source;version=$fileVersion;versionSource='executable metadata; no CLI version option'}
      continue
    }
    $versionArg=if ($name -eq 'git') { '--version' } else { '-version' }
    $savedGit=$env:GIT_CONFIG_GLOBAL
    try {
      if ($name -eq 'git') { $env:GIT_CONFIG_GLOBAL='NUL' }
      $version=@(& $command.Source $versionArg 2>&1)
    } finally { $env:GIT_CONFIG_GLOBAL=$savedGit }
    if ($LASTEXITCODE -ne 0) { throw "TOOL_PREFLIGHT: $name version command failed ($LASTEXITCODE): $($version -join ' ')" }
    $state.tools+=@{name=$name;path=$command.Source;version=($version -join "`n").Trim()}
  }
  $state.tools+=@{name='PowerShell';path=(Get-Process -Id $PID).Path;version=$PSVersionTable.PSVersion.ToString()}
  $vivado=$state.configuration.vivadoBat
  if (!$vivado -or !(Test-Path -LiteralPath $vivado -PathType Leaf)) { throw 'TOOL_PREFLIGHT: configure VivadoBat in toolchain.local.psd1 or APB_UART_VIVADO_BAT' }
  New-Item -ItemType Directory -Force logs | Out-Null
  & $vivado -mode batch -nolog -nojournal -source scripts/toolchain_preflight.tcl > logs/toolchain_vivado.log 2>&1
  $exit=$LASTEXITCODE; $text=Get-Content -Raw logs/toolchain_vivado.log
  if ($exit -ne 0 -or $text -notmatch 'TOOLCHAIN_PART_PASS' -or $text -match '(?m)^ERROR:') { throw 'TOOL_PREFLIGHT: Vivado startup/part check failed; logs/toolchain_vivado.log' }
  $version=Get-VivadoPreflightVersion $text $state.configuration.part
  $state.tools+=@{name='Vivado';path=$vivado;version=$version}
  if (!(Test-Path work_preflight)) { & vlib work_preflight | Out-Null; if ($LASTEXITCODE) { throw 'TOOL_PREFLIGHT: vlib failed' } }
  & vlog -work work_preflight -sv tb/unit/toolchain_smoke_tb.sv -l logs/toolchain_compile.log | Out-Null
  if ($LASTEXITCODE) { throw 'TOOL_PREFLIGHT: compiler smoke failed' }
  & vsim -c work_preflight.toolchain_smoke_tb -do 'run -all; quit -f' -l logs/toolchain_simulation.log | Out-Null
  $exit=$LASTEXITCODE; $text=Get-Content -Raw logs/toolchain_simulation.log
  if ($exit -ne 0 -or $text -notmatch 'TOOLCHAIN_SIMULATION_PASS' -or $text -match '(?m)^#?\s*\*\* (Error|Fatal):') { throw 'TOOL_PREFLIGHT: simulator/license smoke failed' }
  $state.result='PASS'
} catch { $state.result='FAIL'; $state.error=$_.Exception.Message; throw }
finally { Write-EvidenceJson 'reports/runtime_manifest.json' $state }
Write-Host 'Toolchain preflight passed: tools, versions, FPGA part and simulator license'
