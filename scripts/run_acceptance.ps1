param(
  [int[]]$Seeds = @(101, 201, 301),
  [int]$StressSeed = 731,
  [int]$StressSeed2 = 751
)

$ErrorActionPreference = "Stop"
$started = Get-Date
$steps = @()

function Run-Step([string]$Name, [scriptblock]$Action) {
  Write-Host "[ACCEPTANCE] $Name"
  $global:LASTEXITCODE = 0
  & $Action
  if (-not $?) {
    throw "Acceptance step '$Name' failed."
  }
  if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "Acceptance step '$Name' failed with exit code $LASTEXITCODE."
  }
  $script:steps += [pscustomobject]@{ Name = $Name; Result = "PASS" }
}

Run-Step "Architecture structural audit" {
  & (Join-Path $PSScriptRoot "run_architecture_check.ps1")
}
Run-Step "Three-seed final regression and coverage merge" {
  & (Join-Path $PSScriptRoot "run_final_regression.ps1") -Seeds $Seeds
}
Run-Step "Skewed non-integer clock regression" {
  & (Join-Path $PSScriptRoot "run_questa.ps1") `
    -Tests uart_config_latency_test,uart_loopback_test,uart_external_rx_test,uart_external_rx_baud_test,uart_reset_cdc_test `
    -Seed $StressSeed -PclkHalfNs 7 -UartHalfNs 11 -PclkPhaseNs 2 -UartPhaseNs 5
}
Run-Step "Second skewed clock regression" {
  & (Join-Path $PSScriptRoot "run_questa.ps1") `
    -Tests uart_config_latency_test,uart_frame_error_test,uart_external_rx_baud_test,uart_rx_fifo_full_test,uart_reset_cdc_test `
    -Seed $StressSeed2 -PclkHalfNs 9 -UartHalfNs 13 -PclkPhaseNs 4 -UartPhaseNs 1
}
Run-Step "Four-case mutation suite" {
  & (Join-Path $PSScriptRoot "run_mutation_suite.ps1")
}

$elapsed = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
$summary = @(
  "# Acceptance Summary", "",
  "- Time: ``$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')``",
  "- Result: **PASS**",
  "- Elapsed seconds: ``$elapsed``",
  "- Final-regression seeds: ``$($Seeds -join ', ')``",
  "- Stress seeds: ``$StressSeed, $StressSeed2``", "",
  "| Step | Result |", "| --- | --- |"
)
foreach ($step in $steps) {
  $summary += "| $($step.Name) | $($step.Result) |"
}
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines(
  (Join-Path (Get-Location) "reports/acceptance_summary.md"),
  $summary,
  $utf8NoBom
)
Write-Host "Acceptance passed: $($steps.Count)/$($steps.Count) steps"
