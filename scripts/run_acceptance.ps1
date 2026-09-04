param(
  [int[]]$Seeds = @(101, 201, 301),
  [string]$PlanPath = "config/verification_plan.psd1"
)

$ErrorActionPreference = "Stop"
$started = Get-Date
$steps = @()
$verificationPlan = Import-PowerShellDataFile $PlanPath
$stressProfiles = @($verificationPlan.StressProfiles)
if ($stressProfiles.Count -lt 2) {
  throw "Verification plan must define at least two stress profiles."
}

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

Run-Step "RTL lint and CDC/RDC structural audit" {
  & (Join-Path $PSScriptRoot "run_static_checks.ps1")
}
Run-Step "Generic FPGA out-of-context synthesis" {
  & (Join-Path $PSScriptRoot "run_vivado_synth.ps1")
}
Run-Step "Architecture structural audit" {
  & (Join-Path $PSScriptRoot "run_architecture_check.ps1")
}
Run-Step "Three-seed final regression and coverage merge" {
  & (Join-Path $PSScriptRoot "run_final_regression.ps1") -Seeds $Seeds -PlanPath $PlanPath
}
Run-Step "Skewed non-integer clock regression" {
  $profile = $stressProfiles[0]
  & (Join-Path $PSScriptRoot "run_questa.ps1") `
    -PlanPath $PlanPath -Tests $profile.Tests -Seed $profile.Seed `
    -PclkHalfNs $profile.PclkHalfNs -UartHalfNs $profile.UartHalfNs `
    -PclkPhaseNs $profile.PclkPhaseNs -UartPhaseNs $profile.UartPhaseNs
}
Run-Step "Second skewed clock regression" {
  $profile = $stressProfiles[1]
  & (Join-Path $PSScriptRoot "run_questa.ps1") `
    -PlanPath $PlanPath -Tests $profile.Tests -Seed $profile.Seed `
    -PclkHalfNs $profile.PclkHalfNs -UartHalfNs $profile.UartHalfNs `
    -PclkPhaseNs $profile.PclkPhaseNs -UartPhaseNs $profile.UartPhaseNs
}
Run-Step "Declared representative mutation campaign" {
  & (Join-Path $PSScriptRoot "run_mutation_suite.ps1")
}

$elapsed = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
$summary = @(
  "# Acceptance Summary", "",
  "- Time: ``$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')``",
  "- Result: **PASS**",
  "- Elapsed seconds: ``$elapsed``",
  "- Final-regression seeds: ``$($Seeds -join ', ')``",
  "- Stress profiles: ``$($stressProfiles.Name -join ', ')``", "",
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
$machine = [ordered]@{
  generatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  result = "PASS"
  elapsedSeconds = $elapsed
  seeds = $Seeds
  stressProfiles = @($stressProfiles.Name)
  steps = $steps
}
$machine | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 reports/acceptance_summary.json
Write-Host "Acceptance passed: $($steps.Count)/$($steps.Count) steps"
