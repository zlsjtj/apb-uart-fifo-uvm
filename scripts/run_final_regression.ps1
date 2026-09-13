param(
  [int[]]$Seeds = @(101, 201, 301),
  [int]$PclkHalfNs = 5,
  [int]$UartHalfNs = 20,
  [int]$PclkPhaseNs = 0,
  [int]$UartPhaseNs = 0,
  [string]$PlanPath = "config/verification_plan.psd1",
  [string]$OutputDir = "reports/final_regression"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'evidence_common.ps1')
. "$PSScriptRoot/toolchain_common.ps1"
$null=Initialize-Toolchain
$sourceIdentity=Get-SourceIdentity

function Require-Tool($Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required tool '$Name' was not found in PATH."
  }
}

function Write-Utf8File([string]$Path, [string[]]$Lines) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllLines((Join-Path (Get-Location) $Path), $Lines, $utf8NoBom)
}

function Read-RegressionRows([string]$SummaryPath) {
  $rows = @()
  foreach ($line in (Get-Content -Encoding UTF8 $SummaryPath)) {
    if ($line -match '^\|\s*([A-Za-z0-9_]+)\s*\|\s*(\d+)\s*\|\s*(PASS|FAIL)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|') {
      $rows += [pscustomobject]@{
        Test = $Matches[1]
        Seed = [int]$Matches[2]
        Status = $Matches[3]
        Errors = [int]$Matches[4]
        Fatals = [int]$Matches[5]
        Warnings = [int]$Matches[6]
      }
    }
  }
  return $rows
}

Require-Tool "vlog"
Require-Tool "vsim"
Require-Tool "vcover"
Require-Tool "git"

if (-not (Test-Path $PlanPath)) {
  throw "Verification plan '$PlanPath' was not found."
}
$verificationPlan = Import-PowerShellDataFile $PlanPath
$expectedTestCount = @($verificationPlan.RegressionTests).Count
if ($expectedTestCount -eq 0) {
  throw "Verification plan contains no regression tests."
}

& (Join-Path $PSScriptRoot "run_reg_model_check.ps1")
& (Join-Path $PSScriptRoot "run_cdc_structural_check.ps1")
& (Join-Path $PSScriptRoot "run_p2_structural_check.ps1")
& (Join-Path $PSScriptRoot "run_architecture_check.ps1")

if ($Seeds.Count -eq 0) {
  throw "At least one seed is required."
}
if ((@($Seeds | Select-Object -Unique).Count) -ne $Seeds.Count) {
  throw "Seed values must be unique."
}

New-Item -ItemType Directory -Force $OutputDir | Out-Null

$allRows = @()
$runScript = Join-Path $PSScriptRoot "run_questa.ps1"
foreach ($seed in $Seeds) {
  & $runScript -PlanPath $PlanPath -Seed $seed -PclkHalfNs $PclkHalfNs -UartHalfNs $UartHalfNs `
    -PclkPhaseNs $PclkPhaseNs -UartPhaseNs $UartPhaseNs
  if ($LASTEXITCODE -ne 0) {
    throw "Regression failed for base seed $seed."
  }

  $seedSummary = "reports/regression_summary.md"
  $rows = @(Read-RegressionRows $seedSummary)
  if (($rows.Count -ne $expectedTestCount) -or
      (@($rows | Where-Object { $_.Status -ne "PASS" }).Count -ne 0)) {
    throw "Regression summary for base seed $seed is incomplete or contains failures."
  }

  $seedCopy = Join-Path $OutputDir "seed_${seed}_summary.md"
  Copy-Item $seedSummary $seedCopy -Force
  $allRows += $rows
}

$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$summaryPath = Join-Path $OutputDir "final_regression_summary.md"
$summary = @(
  "# Final Regression Summary",
  "",
  "- Time: ``$now``",
  "- Base seeds: ``$($Seeds -join ', ')``",
  "- Clock config: ``pclk_half=${PclkHalfNs}ns pclk_phase=${PclkPhaseNs}ns uart_half=${UartHalfNs}ns uart_phase=${UartPhaseNs}ns``",
  "- Total runs: $($allRows.Count)",
  "",
  "| Test | Seed | Status | Errors | Fatals | Warnings |",
  "| --- | ---: | --- | ---: | ---: | ---: |"
)
foreach ($row in $allRows) {
  $summary += "| $($row.Test) | $($row.Seed) | $($row.Status) | $($row.Errors) | $($row.Fatals) | $($row.Warnings) |"
}
$summary += ""
$summary += "Passed $(@($allRows | Where-Object { $_.Status -eq 'PASS' }).Count)/$($allRows.Count) runs."
Write-Utf8File $summaryPath $summary
Write-EvidenceJson (Join-Path $OutputDir 'final_regression_summary.json') @{result='PASS';source=$sourceIdentity;seeds=$Seeds;tests=$allRows}

$coverageDir = Join-Path $OutputDir "coverage"
& (Join-Path $PSScriptRoot "merge_coverage.ps1") -SummaryPath $summaryPath -OutputDir $coverageDir
if ($LASTEXITCODE -ne 0) {
  throw "Coverage merge failed."
}

$sourcePaths = @(
  "filelist.f",
  "rtl_filelist.f",
  "config/verification_plan.psd1",
  "config/mutation_plan.psd1",
  "config/rtl_coverage_policy.psd1",
  "scripts/run_questa.ps1",
  "scripts/merge_coverage.ps1",
  "scripts/generate_rtl_coverage_gate.ps1",
  "scripts/run_final_regression.ps1",
  "scripts/run_mutation_check.ps1",
  "scripts/run_control_mutation_check.ps1",
  "scripts/run_cdc_structural_check.ps1",
  "scripts/run_reg_model_check.ps1",
  "scripts/run_p2_structural_check.ps1",
  "scripts/run_architecture_check.ps1",
  "scripts/run_acceptance.ps1",
  "scripts/run_fifo_mutation_check.ps1",
  "scripts/run_baud_mutation_check.ps1",
  "scripts/run_mutation_suite.ps1",
  "scripts/run_mutation_campaign.ps1",
  "scripts/run_static_checks.ps1",
  "scripts/run_vivado_synth.ps1",
  "scripts/vivado_synth.tcl"
)
$sourcePaths += Get-ChildItem -Path "rtl", "tb", "scripts", "config", "constraints" -Recurse -File |
  ForEach-Object { $_.FullName }
$sourcePaths = @($sourcePaths | Sort-Object -Unique)

$sourceManifestPath = Join-Path $OutputDir "source_manifest.md"
$sourceManifest = @(
  "# Source Manifest",
  "",
  "- Time: ``$now``",
  "- Hash algorithm: ``SHA-256``",
  "",
  "| File | SHA-256 |",
  "| --- | --- |"
)
foreach ($sourcePath in $sourcePaths) {
  $hash = (Get-FileHash -Algorithm SHA256 $sourcePath).Hash.ToLowerInvariant()
  $fullPath = (Resolve-Path $sourcePath).Path
  $relativePath = $fullPath.Substring((Get-Location).Path.Length).TrimStart([char[]]@('\', '/'))
  $sourceManifest += "| ``$relativePath`` | ``$hash`` |"
}
Write-Utf8File $sourceManifestPath $sourceManifest
Assert-SourceIdentity $sourceIdentity
Write-EvidenceJson (Join-Path $OutputDir 'source_manifest.json') $sourceIdentity

$savedGitConfigGlobal = $env:GIT_CONFIG_GLOBAL
try {
  # Some lab machines redirect the global Git config to a protected directory.
  # Provenance only needs repository-local data, so make the query independent
  # of that machine-specific configuration.
  $env:GIT_CONFIG_GLOBAL = "NUL"
  $gitHead = (& git rev-parse HEAD).Trim()
  $gitState = @(& git status --short)
  $sourceGitState = @(& git status --short -- $sourcePaths)
} finally {
  $env:GIT_CONFIG_GLOBAL = $savedGitConfigGlobal
}
$vlogVersion = @(& vlog -version 2>&1 | Select-Object -First 1) -join " "
$seedLiteral = "@(" + (($Seeds | ForEach-Object { $_.ToString() }) -join ", ") + ")"
$manifestPath = Join-Path $OutputDir "final_regression_manifest.md"
$manifest = @(
  "# Final Regression Manifest",
  "",
  "- Time: ``$now``",
  "- Baseline git commit: ``$gitHead``",
  "- Exact executed source identity: ``$($sourceIdentity.sha256)``",
  "- Source remained unchanged during this run: ``true``",
  "- Simulator: ``$vlogVersion``",
  "- UVM: ``UVM-1.1d built-in; Questa UVM-1.2.2 reported by simulation log``",
  "- Command: ``& .\scripts\run_final_regression.ps1 -Seeds $seedLiteral``",
  "- Regression summary: ``$summaryPath``",
  "- Coverage directory: ``$coverageDir``",
  "- Register-model structural report: ``reports/register_model_structural_summary.md``",
  "- CDC structural report: ``reports/cdc_structural_summary.md``",
  "- P2 structural report: ``reports/p2_structural_summary.md``",
  "- Architecture structural report: ``reports/architecture_structural_summary.md``",
  "- Source hashes: ``$sourceManifestPath``",
  "",
  "## Working tree status"
)
if ($sourceGitState.Count -eq 0) {
  $manifest += ""
  $manifest += "Git reports no tracked changes at this execution path. An isolated ignored snapshot is not proven to match HEAD by this result; source_manifest.json is the authoritative executed-source identity."
} else {
  $manifest += ""
  $manifest += "The source tree differs from the baseline commit. Use source_manifest.md to identify the exact simulated files. Generated reports are not used to decide source cleanliness."
  $manifest += ""
  $manifest += '```text'
  $manifest += $sourceGitState
  $manifest += '```'
}
$manifest += ""
$manifest += "Full working-tree status is recorded separately because this run updates tracked evidence files."
if ($gitState.Count -ne 0) {
  $manifest += ""
  $manifest += '```text'
  $manifest += $gitState
  $manifest += '```'
}
Write-Utf8File $manifestPath $manifest

Write-Host "Final regression passed: $($allRows.Count)/$($allRows.Count) runs"
Write-Host "Evidence manifest: $manifestPath"
