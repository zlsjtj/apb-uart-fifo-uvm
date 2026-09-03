$ErrorActionPreference = "Stop"
$started = Get-Date

$cases = @(
  [pscustomobject]@{
    Name = "TX data bit inversion"
    Script = "run_mutation_check.ps1"
    Test = "uart_loopback_test"
    Seed = 71
    Checker = "SB_TX_MISMATCH"
  },
  [pscustomobject]@{
    Name = "IRQ stuck low"
    Script = "run_control_mutation_check.ps1"
    Test = "uart_irq_test"
    Seed = 81
    Checker = "IRQ_STATUS / irq_matches_rx_state"
  },
  [pscustomobject]@{
    Name = "FIFO full stuck low"
    Script = "run_fifo_mutation_check.ps1"
    Test = "uart_rx_fifo_full_test"
    Seed = 91
    Checker = "RX_FIFO_FULL / SB_RX_MISMATCH"
  }
)

foreach ($case in $cases) {
  Write-Host "[MUTATION] $($case.Name)"
  & (Join-Path $PSScriptRoot $case.Script)
  if ($LASTEXITCODE -ne 0) {
    throw "Mutation '$($case.Name)' escaped or failed to run."
  }
}

$elapsed = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
$summary = @(
  "# Mutation Matrix", "",
  "- Time: ``$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')``",
  "- Mutants killed: ``$($cases.Count)/$($cases.Count)``",
  "- Mutation score: ``100%``",
  "- Elapsed seconds: ``$elapsed``", "",
  "| Mutation | Test | Seed | Primary detector | Result |",
  "| --- | --- | ---: | --- | --- |"
)
foreach ($case in $cases) {
  $summary += "| $($case.Name) | ``$($case.Test)`` | $($case.Seed) | ``$($case.Checker)`` | KILLED |"
}
$summary += ""
$summary += "The score applies only to the three deliberately selected fault models; it is not a claim of exhaustive mutation coverage."
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines(
  (Join-Path (Get-Location) "reports/mutation_matrix.md"),
  $summary,
  $utf8NoBom
)
Write-Host "Mutation suite passed: $($cases.Count)/$($cases.Count) mutants killed"

