param(
  [string]$Test = "uart_irq_test",
  [int]$Seed = 81,
  [string]$Filelist = "filelist.f",
  [string]$Library = "work_irq_mutation"
)

$ErrorActionPreference = "Stop"

foreach ($tool in @("vlib", "vlog", "vsim")) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    throw "Required tool '$tool' was not found in PATH."
  }
}

New-Item -ItemType Directory -Force logs, reports | Out-Null
if (-not (Test-Path $Library)) {
  vlib $Library | Out-Host
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$compileLog = "logs/compile_irq_mutation.log"
$runLog = "logs/mutation_irq_stuck_low_${Seed}.log"

vlog -work $Library -sv -assertdebug +acc "+define+UART_MUTATE_IRQ_STUCK_LOW" `
  -f $Filelist -l $compileLog | Out-Host
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$top = "${Library}.tb_apb_uart"
vsim -c $top "+UVM_TESTNAME=$Test" "+PCLK_HALF_NS=5" "+UART_HALF_NS=20" `
  "+PCLK_PHASE_NS=0" "+UART_PHASE_NS=0" -sv_seed $Seed -assertdebug `
  -do "run -all; quit -f" -l $runLog | Out-Host
$simExit = $LASTEXITCODE

$logText = if (Test-Path $runLog) { Get-Content -Raw -Encoding UTF8 $runLog } else { "" }
$checkerHit = ($logText -match "IRQ_STATUS") -or ($logText -match "irq_matches_rx_state")
$hasFailure = ($logText -match "UVM_ERROR\s*:\s*[1-9][0-9]*") -or
              ($logText -match "Error:\s+.*irq_matches_rx_state")
$detected = $checkerHit -and $hasFailure
$result = if ($detected) { "PASS (mutation detected)" } else { "FAIL (mutation escaped)" }
$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$summary = @(
  "# IRQ Control Mutation Summary",
  "",
  "- Time: ``$now``",
  "- Mutation: force IRQ output low (``UART_MUTATE_IRQ_STUCK_LOW``)",
  "- Test: ``$Test``",
  "- Seed: ``$Seed``",
  "- Isolated simulation library: ``$Library``",
  "- IRQ checker reported a failure: ``$checkerHit``",
  "- Result: **$result**",
  "- Log: ``$runLog``",
  "",
  "This script passes only when the injected IRQ control fault is detected."
)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines(
  (Join-Path (Get-Location) "reports/control_mutation_summary.md"),
  $summary,
  $utf8NoBom
)

if (($simExit -ne 0) -and (-not $detected)) { exit $simExit }
if (-not $detected) { exit 1 }
