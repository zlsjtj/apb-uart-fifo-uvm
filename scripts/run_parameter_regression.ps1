param([int]$Seed=1501,[string]$PlanPath='config/verification_plan.psd1')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'evidence_common.ps1')
$source=Get-SourceIdentity
$plan=Import-PowerShellDataFile $PlanPath
$rows=@()
foreach ($width in $plan.ParameterWidths) {
  $base=$Seed+100*$rows.Count
  & "$PSScriptRoot/run_questa.ps1" -Tests $plan.ParameterTests -Seed $base -FifoAddrWidth $width -PlanPath $PlanPath
  if ($LASTEXITCODE) { throw "Parameterized UVM failed: width=$width" }
  $summary=Get-Content -Raw reports/regression_summary.json | ConvertFrom-Json
  if ($summary.result -ne 'PASS' -or $summary.tests.Count -ne $plan.ParameterTests.Count -or $summary.fifoAddrWidth -ne $width) { throw 'Invalid parameter result' }
  $dir="reports/parameter_regression/width_$width"
  New-Item -ItemType Directory -Force $dir | Out-Null
  Copy-Item -LiteralPath reports/regression_summary.json,reports/regression_summary.md -Destination $dir -Force
  $rows+=@{width=$width;result='PASS';tests=$summary.tests}
}
& "$PSScriptRoot/run_questa.ps1" -Tests $plan.NoProbeTests -Seed ($Seed+900) -NoWhitebox -PlanPath $PlanPath
if ($LASTEXITCODE) { throw 'No-probe UVM failed' }
$noProbe=Get-Content -Raw reports/regression_summary.json | ConvertFrom-Json
if ($noProbe.result -ne 'PASS' -or $noProbe.whiteboxEnabled -or $noProbe.tests.Count -ne $plan.NoProbeTests.Count) { throw 'Invalid no-probe result' }
$dir='reports/parameter_regression/no_probe'
New-Item -ItemType Directory -Force $dir | Out-Null
Copy-Item -LiteralPath reports/regression_summary.json,reports/regression_summary.md -Destination $dir -Force
& "$PSScriptRoot/run_questa.ps1" -Tests @('uart_tx_completion_test','uart_fifo_wrap_test') -Seed ($Seed+950) -FifoAddrWidth 1 -PclkHalfNs 17 -UartHalfNs 2 -PclkPhaseNs 1
if ($LASTEXITCODE) { throw 'Fast-UART/depth-two completion test failed' }
$fast=Get-Content -Raw reports/regression_summary.json | ConvertFrom-Json
$dir='reports/parameter_regression/fast_uart'
New-Item -ItemType Directory -Force $dir | Out-Null
Copy-Item -LiteralPath reports/regression_summary.json,reports/regression_summary.md -Destination $dir -Force
Assert-SourceIdentity $source
Write-EvidenceJson 'reports/parameter_regression/summary.json' @{result='PASS';source=$source;widths=$rows;noProbe=$noProbe;fastUart=$fast}
Write-Host "Parameterized UVM and no-probe regression passed"
