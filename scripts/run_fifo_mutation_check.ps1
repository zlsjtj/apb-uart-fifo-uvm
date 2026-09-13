param([string]$Test='uart_rx_fifo_full_test', [int]$Seed=91, [string]$Filelist='filelist.f')
# Compatibility entry for UART_MUTATE_FIFO_FULL_STUCK_LOW. All verdicts use the baseline-controlled campaign.
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'run_mutation_campaign.ps1') -CaseIds 'fifo_full_low' -TestOverride $Test -SeedOverride $Seed -Filelist $Filelist
if ($LASTEXITCODE -ne 0) { throw 'Mutation campaign failed' }
Copy-Item -LiteralPath 'reports/mutation_campaign.md' -Destination 'reports/fifo_mutation_summary.md' -Force
