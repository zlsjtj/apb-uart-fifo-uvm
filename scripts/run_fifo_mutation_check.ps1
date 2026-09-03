param(
  [string]$Test = "uart_rx_fifo_full_test",
  [int]$Seed = 91,
  [string]$Filelist = "filelist.f",
  [string]$Library = "work_fifo_mutation"
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

$compileLog = "logs/compile_fifo_mutation.log"
$runLog = "logs/mutation_fifo_full_stuck_low_${Seed}.log"

vlog -work $Library -sv -assertdebug +acc "+define+UART_MUTATE_FIFO_FULL_STUCK_LOW" `
  -f $Filelist -l $compileLog | Out-Host
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$top = "${Library}.tb_apb_uart"
vsim -c $top "+UVM_TESTNAME=$Test" "+PCLK_HALF_NS=5" "+UART_HALF_NS=20" `
  "+PCLK_PHASE_NS=0" "+UART_PHASE_NS=0" -sv_seed $Seed -assertdebug `
  -do "run -all; quit -f" -l $runLog | Out-Host
$simExit = $LASTEXITCODE

$logText = if (Test-Path $runLog) { Get-Content -Raw -Encoding UTF8 $runLog } else { "" }
$checkerHit = ($logText -match "RX_FIFO_FULL") -or
              ($logText -match "RX_FIFO_ORDER") -or
              ($logText -match "SB_RX_")
$hasFailure = $logText -match "UVM_ERROR\s*:\s*[1-9][0-9]*"
$detected = $checkerHit -and $hasFailure
$result = if ($detected) { "PASS (mutation detected)" } else { "FAIL (mutation escaped)" }
$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$summary = @(
  "# FIFO Control Mutation Summary", "",
  "- Time: ``$now``",
  "- Mutation: force FIFO full flag low (``UART_MUTATE_FIFO_FULL_STUCK_LOW``)",
  "- Test: ``$Test``",
  "- Seed: ``$Seed``",
  "- Isolated simulation library: ``$Library``",
  "- FIFO checker reported a failure: ``$checkerHit``",
  "- Result: **$result**",
  "- Log: ``$runLog``", "",
  "This script passes only when the injected FIFO-control fault is detected."
)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines(
  (Join-Path (Get-Location) "reports/fifo_mutation_summary.md"),
  $summary,
  $utf8NoBom
)

if (($simExit -ne 0) -and (-not $detected)) { exit $simExit }
if (-not $detected) { exit 1 }
