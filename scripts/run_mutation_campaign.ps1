param(
  [string]$PlanPath = "config/mutation_plan.psd1",
  [string]$Filelist = "filelist.f"
)

$ErrorActionPreference = "Stop"
foreach ($tool in @("vlib", "vlog", "vsim")) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    throw "Required tool '$tool' was not found in PATH."
  }
}
if (-not (Test-Path $PlanPath)) { throw "Mutation plan '$PlanPath' was not found." }
$plan = Import-PowerShellDataFile $PlanPath
$cases = @($plan.Cases)
if ($cases.Count -lt 8) { throw "Mutation plan must contain at least eight representative cases." }

New-Item -ItemType Directory -Force logs, reports | Out-Null
$results = @()
foreach ($case in $cases) {
  $library = "work_mut_$($case.Id)"
  $compileLog = "logs/mutation_$($case.Id)_compile.log"
  $runLog = "logs/mutation_$($case.Id)_$($case.Seed).log"
  Write-Host "[MUTATION] $($case.Name) [$($case.Define)]"
  if (-not (Test-Path $library)) {
    & vlib $library | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not create $library." }
  }

  & vlog -work $library -sv -assertdebug +acc "+define+$($case.Define)" `
    -f $Filelist -l $compileLog | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Mutation $($case.Id) did not compile. See $compileLog" }

  $top = "$library.tb_apb_uart"
  & vsim -c $top "+UVM_TESTNAME=$($case.Test)" "+PCLK_HALF_NS=5" "+UART_HALF_NS=20" `
    "+PCLK_PHASE_NS=0" "+UART_PHASE_NS=0" -sv_seed $case.Seed -assertdebug `
    -do "run -all; quit -f" -l $runLog | Out-Null
  $simExit = $LASTEXITCODE
  $logText = if (Test-Path $runLog) { Get-Content -Raw $runLog } else { "" }
  $detectorHit = $logText -match $case.Detector
  $failureSeen = ($logText -match 'UVM_(ERROR|FATAL)\s*:\s*[1-9][0-9]*') -or
                 ($logText -match '(?m)^#?\s*\*\* Error:')
  $killed = $detectorHit -and $failureSeen
  $results += [pscustomobject]@{
    id = $case.Id
    name = $case.Name
    define = $case.Define
    test = $case.Test
    seed = [int]$case.Seed
    detector = $case.Detector
    detectorHit = $detectorHit
    failureSeen = $failureSeen
    simulatorExit = $simExit
    result = if ($killed) { "KILLED" } else { "SURVIVED" }
    log = $runLog
  }
}

$killedCount = @($results | Where-Object { $_.result -eq "KILLED" }).Count
$score = [math]::Round(100.0 * $killedCount / $results.Count, 1)
$machine = [ordered]@{
  generatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  result = if ($killedCount -eq $results.Count) { "PASS" } else { "FAIL" }
  killed = $killedCount
  total = $results.Count
  mutationScorePercent = $score
  cases = $results
  boundary = "Score covers only the declared representative fault models; it is not exhaustive mutation coverage."
}
$machine | ConvertTo-Json -Depth 7 | Set-Content -Encoding UTF8 reports/mutation_campaign.json

$summary = @(
  "# Mutation Campaign", "",
  "- Time: ``$($machine.generatedAt)``",
  "- Result: **$($machine.result)**",
  "- Mutants killed: ``$killedCount/$($results.Count)``",
  "- Mutation score: ``$score%``", "",
  "| Fault model | Define | Test | Seed | Detector | Result |",
  "| --- | --- | --- | ---: | --- | --- |"
)
foreach ($row in $results) {
  $summary += "| $($row.name) | ``$($row.define)`` | ``$($row.test)`` | $($row.seed) | ``$($row.detector)`` | $($row.result) |"
}
$summary += ""
$summary += "该分数只覆盖表中声明的代表性故障，不表示所有 RTL 缺陷都能被检出。"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines((Join-Path (Get-Location) "reports/mutation_campaign.md"), $summary, $utf8NoBom)

if ($killedCount -ne $results.Count) {
  $survivors = ($results | Where-Object { $_.result -ne "KILLED" } | ForEach-Object id) -join ", "
  throw "Mutation campaign failed; survivors: $survivors"
}
Write-Host "Mutation campaign passed: $killedCount/$($results.Count) mutants killed"
