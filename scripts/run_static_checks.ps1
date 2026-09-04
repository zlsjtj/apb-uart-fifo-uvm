$ErrorActionPreference = "Stop"

function Write-Utf8File([string]$Path, [string[]]$Lines) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllLines((Join-Path (Get-Location) $Path), $Lines, $utf8NoBom)
}

if (-not (Get-Command vlog -ErrorAction SilentlyContinue)) {
  throw "Required RTL lint tool 'vlog' was not found in PATH."
}

New-Item -ItemType Directory -Force reports, logs | Out-Null
if (-not (Test-Path work_lint)) {
  & vlib work_lint
  if ($LASTEXITCODE -ne 0) { throw "Could not create the lint work library." }
}

$lintLog = "logs/rtl_lint.log"
& vlog -work work_lint -sv -lint -pedanticerrors -warning error -f rtl_filelist.f -l $lintLog
if ($LASTEXITCODE -ne 0) {
  throw "RTL lint failed. See $lintLog"
}
$lintText = Get-Content -Raw $lintLog
if (($lintText -match '(?m)^\*\* (Error|Warning):') -or
    ($lintText -notmatch 'Errors:\s*0,\s*Warnings:\s*0')) {
  throw "RTL lint did not finish with zero errors and warnings. See $lintLog"
}

& (Join-Path $PSScriptRoot "run_cdc_structural_check.ps1")
if ($LASTEXITCODE -ne 0) { throw "CDC/RDC structural audit failed." }

$availableSignoffTool = @("questa_cdc", "qverify", "spyglass") |
  Where-Object { Get-Command $_ -ErrorAction SilentlyContinue } |
  Select-Object -First 1
$result = [ordered]@{
  generatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  result = "PASS"
  rtlLint = [ordered]@{
    tool = ((& vlog -version 2>&1 | Select-Object -First 1) -join " ")
    errors = 0
    warnings = 0
    log = $lintLog
  }
  cdcRdcStructuralAudit = [ordered]@{
    result = "PASS"
    report = "reports/cdc_structural_summary.md"
  }
  commercialCdcSignoff = [ordered]@{
    available = ($null -ne $availableSignoffTool)
    performed = $false
    boundary = "The automated result is an RTL structural audit, not a commercial CDC/RDC signoff waiver review."
  }
}
$result | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 reports/static_checks.json

$summary = @(
  "# Static Check Summary", "",
  "- Time: ``$($result.generatedAt)``",
  "- Result: **PASS**",
  "- RTL lint: zero errors and zero warnings",
  "- CDC/RDC structural audit: PASS",
  "- Commercial CDC/RDC signoff performed: ``false``", "",
  "本报告证明当前 RTL 能通过可复现的语法与 lint 门禁，也证明项目约定的同步器、邮箱和复位结构存在。它不等同于商业 CDC 工具的路径分类、waiver 审核和 signoff。"
)
Write-Utf8File "reports/static_checks.md" $summary
Write-Host "Static checks passed: RTL lint and CDC/RDC structural audit"
