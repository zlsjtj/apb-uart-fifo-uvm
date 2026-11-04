param(
  [string]$SummaryPath = "reports/regression_summary.md",
  [string]$OutputDir = "reports/coverage",
  [switch]$SkipHtml
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'evidence_common.ps1')
. "$PSScriptRoot/toolchain_common.ps1"
$null=Initialize-Toolchain

function Require-Tool($Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required tool '$Name' was not found in PATH."
  }
}

function Run-Vcover([string[]]$Arguments) {
  $script:vcoverStep++
  $output = @(& vcover @Arguments 2>&1)
  $status = $LASTEXITCODE
  $output | Set-Content -LiteralPath (Join-Path $OutputDir ("vcover_{0:D2}.log" -f $script:vcoverStep)) -Encoding UTF8
  $output | Out-Host
  $text = $output -join "`n"
  if ($status -ne 0 -or $text -match '(?im)^\s*\*\*\s*(?:(?:Warning|Error|Fatal)\b|UI-Msg\s*\((?:Warning|Error|Fatal)\))' -or
      $text -match '(?im)^\s*(?:Errors|Warnings):\s*[1-9]') {
    throw "vcover failed: vcover $($Arguments -join ' ')"
  }
}

Require-Tool "vcover"

if (-not (Test-Path $SummaryPath)) {
  throw "Regression summary '$SummaryPath' was not found."
}

$summaryLines = Get-Content -Encoding UTF8 $SummaryPath
$ucdbFiles = @()
$testRows = @()

foreach ($line in $summaryLines) {
  if ($line -match '^\|\s*([A-Za-z0-9_]+)\s*\|\s*(\d+)\s*\|\s*(PASS|FAIL)\s*\|') {
    $testName = $Matches[1]
    $seed = [int]$Matches[2]
    $status = $Matches[3]
    if ($status -ne "PASS") {
      throw "Refusing to merge coverage because $testName seed $seed is $status."
    }

    $ucdbPath = Join-Path "reports" "${testName}_${seed}.ucdb"
    if (-not (Test-Path $ucdbPath)) {
      throw "Coverage database '$ucdbPath' listed by the regression summary is missing."
    }

    $ucdbFiles += $ucdbPath
    $testRows += [pscustomobject]@{ Test = $testName; Seed = $seed; Ucdb = $ucdbPath }
  }
}

if ($ucdbFiles.Count -eq 0) {
  throw "No PASS test rows were found in '$SummaryPath'."
}

New-Item -ItemType Directory -Force $OutputDir | Out-Null
$script:vcoverStep = 0
$version = (& vcover -version 2>&1) -join "`n"
$modernVcover = $version -match '\b(20\d{2})\.\d+\b' -and [int]$Matches[1] -ge 2024
$outputOption = if ($modernVcover) { '-output' } else { '-file' }
$totalsOption = if ($modernVcover) { '-summary' } else { '-totals' }
$duOption = if ($modernVcover) { '-du=*' } else { '-bydu' }
$htmlOption = if ($modernVcover) { '-output' } else { '-htmldir' }
$summaryCategories = if ($modernVcover) { @('-cvg','-assert','-directive') } else { @() }
$assertionCategories = if ($modernVcover) { @('-assert','-directive') } else { @('-assert') }
$mergedUcdb = Join-Path $OutputDir "regression_merged.ucdb"
$totalsReport = Join-Path $OutputDir "coverage_totals.txt"
$functionalReport = Join-Path $OutputDir "functional_coverage.txt"
$codeReport = Join-Path $OutputDir "code_coverage.txt"
$assertionReport = Join-Path $OutputDir "assertion_coverage.txt"
$dutByDuReport = Join-Path $OutputDir "dut_bydu_coverage.txt"
$htmlDir = Join-Path $OutputDir "html"
$manifestPath = Join-Path $OutputDir "coverage_manifest.md"

Run-Vcover (@("merge", "-quiet", $mergedUcdb) + $ucdbFiles)
Run-Vcover (@("report", $totalsOption, "-code", "bcesft") + $summaryCategories + @($outputOption, $totalsReport, $mergedUcdb))
$coverageGates = @(Assert-CoverageTotals (Get-Content -Raw $totalsReport))
Write-EvidenceJson (Join-Path $OutputDir 'functional_assertion_gate.json') @{
  result='PASS'; gates=$coverageGates; source=$mergedUcdb
}
Run-Vcover @("report", "-details", "-cvg", $outputOption, $functionalReport, $mergedUcdb)
Run-Vcover @("report", "-details", "-code", "bcesft", $outputOption, $codeReport, $mergedUcdb)
Run-Vcover (@("report", "-details") + $assertionCategories + @($outputOption, $assertionReport, $mergedUcdb))
Run-Vcover @("report", $duOption, "-code", "bcesft", $outputOption, $dutByDuReport, $mergedUcdb)
if (-not $SkipHtml) {
  New-Item -ItemType Directory -Force $htmlDir | Out-Null
  Run-Vcover (@("report", "-html", $htmlOption, $htmlDir, "-code", "bcesft", "-cvg", "-details") + $assertionCategories + @($mergedUcdb))
  if (!(Test-Path (Join-Path $htmlDir 'index.html'))) { throw 'Coverage HTML index missing' }
}

# Keep complete reports available when a coverage gate rejects the run.
& (Join-Path $PSScriptRoot "generate_rtl_coverage_gate.ps1") `
  -ByDuReport $dutByDuReport -OutputDir $OutputDir
if ($LASTEXITCODE -ne 0) {
  throw "RTL-only coverage gate failed."
}

$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$manifest = @(
  "# Coverage Merge Manifest",
  "",
  "- Time: ``$now``",
  "- Regression summary: ``$SummaryPath``",
  "- Tests merged: $($testRows.Count)",
  "- Merged UCDB: ``$mergedUcdb``",
  "- Totals report: ``$totalsReport``",
  "- Functional report: ``$functionalReport``",
  "- Code report: ``$codeReport``",
  "- Assertion report: ``$assertionReport``",
  "- By-design-unit report: ``$dutByDuReport``",
  "- RTL-only gate: ``$(Join-Path $OutputDir 'rtl_coverage_gate.md')``",
  "",
  "| Test | Seed | UCDB |",
  "| --- | ---: | --- |"
)

foreach ($row in $testRows) {
  $manifest += "| $($row.Test) | $($row.Seed) | ``$($row.Ucdb)`` |"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines(
  (Join-Path (Get-Location) $manifestPath),
  $manifest,
  $utf8NoBom
)

Write-Host "Merged $($testRows.Count) UCDB files into $mergedUcdb"
Write-Host "Coverage totals: $totalsReport"
if (-not $SkipHtml) {
  Write-Host "HTML report: $htmlDir"
}
