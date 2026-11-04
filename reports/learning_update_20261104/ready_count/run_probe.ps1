param([Parameter(Mandatory=$true)][string]$OutputDir)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'scripts/toolchain_common.ps1')
$null = Initialize-Toolchain
foreach ($tool in @('vlib','vlog','vsim','vcover')) {
  if (!(Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Missing tool: $tool" }
}
$rtl = Join-Path $root 'rtl/uart_tx.sv'
$probe = Join-Path $PSScriptRoot 'probe.sv'
$before = (Get-FileHash -LiteralPath $rtl -Algorithm SHA256).Hash
$sourceLines = @(Get-Content -LiteralPath $rtl)
$assignments = @(0..($sourceLines.Count-1) | Where-Object {
  $sourceLines[$_] -match '^\s*assign ready_o = \(state == TX_IDLE\);\s*$'
})
if ($assignments.Count -ne 1) { throw 'Reproducer no longer matches the RTL' }
$line = $assignments[0] + 1
$destination = [IO.Path]::GetFullPath($OutputDir)
if (Test-Path -LiteralPath $destination) { throw 'Output directory must not exist' }
New-Item -ItemType Directory -Path $destination | Out-Null

function Invoke-ProbeTool([string]$Tool, [string[]]$Options, [string]$Log, [switch]$CheckSummary) {
  $output = @(& $Tool @Options 2>&1)
  $code = $LASTEXITCODE
  $output | Set-Content -LiteralPath $Log -Encoding UTF8
  $text = $output -join "`n"
  if ($code -ne 0 -or $text -match '(?m)^#?\s*\*\*\s*(Error|Fatal|Warning)(?:\s*\([^)]*\))?:' -or
      ($CheckSummary -and $text -notmatch '(?m)^#?\s*Errors:\s*0,\s*Warnings:\s*0\s*$')) {
    throw "Tool did not complete cleanly: $Tool; inspect $Log"
  }
}

Push-Location $destination
try {
  Invoke-ProbeTool vlib @('work') 'vlib.txt'
  Invoke-ProbeTool vlog @('-sv','-work','work','+cover=bcesft',$rtl) 'compile-rtl.txt' -CheckSummary
  Invoke-ProbeTool vlog @('-sv','-work','work',$probe) 'compile-probe.txt' -CheckSummary
  Invoke-ProbeTool vsim @('-c','probe','-voptargs=-access=rw+/probe -debug','-coverage',
    '-do','coverage save -onexit probe.ucdb; run -all; quit -f') 'run.txt' -CheckSummary
  if (!(Test-Path 'probe.ucdb') -or (Get-Item 'probe.ucdb').Length -eq 0) { throw 'Missing fresh UCDB' }
  Invoke-ProbeTool vcover @('report','-du=*','-details','-code','s','-output','statements.txt','probe.ucdb') 'vcover.txt' -CheckSummary
  $run = Get-Content -Raw 'run.txt'
  $report = Get-Content -Raw 'statements.txt'
  $behavior = [regex]::Match($run, '(?m)^#\s*PROBE_PASS changes=(\d+)\s*$')
  $counter = [regex]::Matches($report, ('(?m)^\s*'+$line+'\s+1\s+\**(\d+)\**\s*$'))
  if (!$behavior.Success -or [int]$behavior.Groups[1].Value -lt 10 -or $counter.Count -ne 1 -or
      $report -notmatch '(?m)^\s*Statements\s+28\s+') {
    throw 'Incomplete behavior evidence or changed statement-bin population'
  }
  if ((Get-FileHash -LiteralPath $rtl -Algorithm SHA256).Hash -cne $before) { throw 'RTL changed during probe' }
  $hits = [int]$counter[0].Groups[1].Value
  $result = if ($hits -gt 0) { 'COUNTER_OBSERVED' } else { 'UNRESOLVED_COUNTER_MISMATCH' }
  [ordered]@{
    result=$result; behavior='PASS'; knownReadyEvents=[int]$behavior.Groups[1].Value
    statementLine=$line; statementCount=$hits; statementBins=28
    rtlSha256=$before; probeSha256=(Get-FileHash -LiteralPath $probe -Algorithm SHA256).Hash
    compiler=(@(& vlog -version 2>&1) -join "`n"); outputDirectory=$destination
  } | ConvertTo-Json | Set-Content -LiteralPath 'result.json' -Encoding UTF8
  Write-Host "$result; ready events=$($behavior.Groups[1].Value); statement count=$hits"
} finally { Pop-Location }
if ($hits -eq 0) { exit 1 }
