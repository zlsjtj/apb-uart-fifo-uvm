param(
  [string]$ByDuReport,
  [string]$PolicyPath = "config/rtl_coverage_policy.psd1",
  [string]$OutputDir = "reports/coverage"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $ByDuReport)) { throw "Coverage report '$ByDuReport' was not found." }
if (-not (Test-Path $PolicyPath)) { throw "Coverage policy '$PolicyPath' was not found." }

$policy = Import-PowerShellDataFile $PolicyPath
$reportText = Get-Content -Raw -Encoding UTF8 $ByDuReport
$results = @()

function Read-CoverageMetric([string]$Module, [string]$Metric) {
  $modulePattern = "(?ms)^=== Design Unit: work\." + [regex]::Escape($Module) +
                   "\s*$.*?(?=^=== Design Unit:|\z)"
  $match = [regex]::Match($reportText, $modulePattern)
  if (-not $match.Success) { throw "Design unit '$Module' is absent from '$ByDuReport'." }
  $label = switch ($Metric) {
    "Statements" { "Stmts" }
    "Branches"   { "Branches" }
    "FSM"        { "FSMs" }
    default      { throw "Unsupported RTL coverage metric '$Metric'." }
  }
  $metricMatch = [regex]::Match($match.Value,
    "(?m)^\s*" + [regex]::Escape($label) + ".*?([0-9]+(?:\.[0-9]+)?)\s*$")
  if (-not $metricMatch.Success) {
    throw "Metric '$Metric' for design unit '$Module' was not found."
  }
  return [double]$metricMatch.Groups[1].Value
}

foreach ($gate in $policy.Gates) {
  $actual = Read-CoverageMetric $gate.Module $gate.Metric
  $pass = $actual -ge [double]$gate.Minimum
  $waiverIds = New-Object System.Collections.ArrayList
  if ($gate.ContainsKey("WaiverIds")) {
    foreach ($waiverId in $gate.WaiverIds) {
      if (-not @($policy.Waivers | Where-Object Id -eq $waiverId).Count) {
        throw "Coverage gate references unknown waiver '$waiverId'."
      }
      [void]$waiverIds.Add($waiverId)
    }
  }
  $results += [pscustomobject]@{
    Module = $gate.Module
    Metric = $gate.Metric
    Minimum = [double]$gate.Minimum
    Actual = $actual
    WaiverIds = $waiverIds
    Result = if ($pass) { "PASS" } else { "FAIL" }
  }
}

$failed = @($results | Where-Object Result -ne "PASS")
$payload = [ordered]@{
  generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
  result = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }
  sourceReport = $ByDuReport
  policy = $PolicyPath
  gates = $results
  waivers = @($policy.Waivers)
}

New-Item -ItemType Directory -Force $OutputDir | Out-Null
$jsonPath = Join-Path $OutputDir "rtl_coverage_gate.json"
$mdPath = Join-Path $OutputDir "rtl_coverage_gate.md"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path (Get-Location) $jsonPath),
  ($payload | ConvertTo-Json -Depth 6) + "`n", $utf8NoBom)

$markdown = @(
  "# RTL-only Coverage Gate", "",
  "- Time: ``$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')``",
  "- Result: **$($payload.result)**",
  "- Source: ``$ByDuReport``", "",
  "| RTL module | Metric | Minimum | Actual | Waiver | Result |",
  "| --- | --- | ---: | ---: | --- | --- |"
)
foreach ($row in $results) {
  $waiverText = if ($row.WaiverIds.Count) { $row.WaiverIds -join ', ' } else { '-' }
  $markdown += "| ``$($row.Module)`` | $($row.Metric) | $($row.Minimum)% | $($row.Actual)% | $waiverText | $($row.Result) |"
}
$markdown += ""
$markdown += "## Waivers"
$markdown += ""
foreach ($waiver in $policy.Waivers) {
  $markdown += "- **$($waiver.Id)**（$($waiver.Scope)）：$($waiver.Reason)"
}
[System.IO.File]::WriteAllLines((Join-Path (Get-Location) $mdPath), $markdown, $utf8NoBom)

if ($failed.Count -ne 0) {
  $failed | Format-Table -AutoSize | Out-Host
  throw "RTL-only coverage gate failed: $($failed.Count)/$($results.Count)."
}
Write-Host "RTL-only coverage gate passed: $($results.Count)/$($results.Count)"
