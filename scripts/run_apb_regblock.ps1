param([switch]$InjectFault, [int]$Seed = 1702)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'toolchain_common.ps1')
$null = Initialize-Toolchain
$repo = Split-Path $PSScriptRoot -Parent
Push-Location $repo
try {
  foreach ($tool in @('vlib', 'vlog', 'vsim')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Required tool '$tool' not found in PATH." }
  }
  # Isolated work library and fresh logs; no UART regression/UCDB dependency.
  $mode = if ($InjectFault) { 'fault' } else { 'baseline' }
  $out = "logs/apb-regblock/${mode}_${Seed}"
  New-Item -ItemType Directory -Force $out | Out-Null
  $lib = "$out/work"
  $libPath = [IO.Path]::GetFullPath((Join-Path $repo $lib))
  $logRoot = [IO.Path]::GetFullPath((Join-Path $repo 'logs/apb-regblock'))
  if (!$libPath.StartsWith($logRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Work library must stay inside logs/apb-regblock'
  }
  if (Test-Path -LiteralPath $libPath) { Remove-Item -LiteralPath $libPath -Recurse -Force }
  & vlib $lib
  if ($LASTEXITCODE -ne 0) { throw 'vlib failed' }
  $defines = @()
  if ($InjectFault) { $defines += '+define+REGBLOCK_INJECT_FAULT' }
  & vlog -sv -work $lib @defines -f examples/apb-regblock/filelist.f -l "$out/compile.log"
  if ($LASTEXITCODE -ne 0) { throw 'Compilation failed (never an expected fault result)' }
  $log = "$out/run.log"
  if (Test-Path $log) { Remove-Item $log -Force }
  & vsim -c -lib $lib tb_regblock +UVM_TESTNAME=regblock_test -sv_seed $Seed -do 'run -all; quit -f' -l $log
  $status = $LASTEXITCODE
  if ($status -ne 0 -or !(Test-Path $log)) { throw 'Simulator failed or run log missing' }
  $text = Get-Content -Raw $log
  if ($text -match 'REGBLOCK_TIMEOUT|(?m)^#?\s*\*\*\s*(Error|Fatal|Warning):' -or
      [regex]::Matches($text, '(?m)^#?\s*UVM_INFO[^\r\n]*\[REGBLOCK_SUMMARY\]\s+observed=12 expected=12\s*$').Count -ne 1) {
    throw 'Simulation did not complete cleanly'
  }
  foreach ($severity in @('UVM_ERROR', 'UVM_FATAL', 'UVM_WARNING')) {
    $expected = if ($InjectFault -and $severity -eq 'UVM_ERROR') { 2 } else { 0 }
    $summaries = [regex]::Matches($text, "(?m)^#?\s*${severity}\s*:\s*(\d+)\s*$")
    if ($summaries.Count -ne 1 -or [int]$summaries[0].Groups[1].Value -ne $expected) {
      throw "Expected exactly one $severity summary with count $expected"
    }
  }
  $errors = [regex]::Matches($text, '(?m)^#?\s*UVM_ERROR\s+[^\r\n]*?\[([^\]]+)\]')
  $dataErrors = @($errors | Where-Object { $_.Groups[1].Value -eq 'REGBLOCK_DATA' }).Count
  if ($errors.Count -ne $dataErrors -or $text -match '(?m)^#?\s*UVM_(FATAL|WARNING)\s+[^\r\n]*\[') {
    throw 'Unexpected UVM diagnostic'
  }
  if ($InjectFault) {
    if ($dataErrors -ne 2) {
      throw 'Expected exactly two REGBLOCK_DATA errors from corrupted scratch readback'
    }
    Write-Host 'EXPECTED_FAULT_DETECTED: two monitored scratch readback mismatches (exit 0)'
  } else {
    if ($dataErrors -ne 0) { throw 'Register checking failed' }
    Write-Host 'PASS: 12 monitored APB transfers checked (exit 0)'
  }
} finally { Pop-Location }
