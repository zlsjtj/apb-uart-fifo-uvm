param([string]$Test='uart_irq_test', [int]$Seed=81, [string]$Filelist='filelist.f')
# Compatibility entry for UART_MUTATE_IRQ_STUCK_LOW. All verdicts use the baseline-controlled campaign.
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'run_mutation_campaign.ps1') -CaseIds 'irq_low' -TestOverride $Test -SeedOverride $Seed -Filelist $Filelist
if ($LASTEXITCODE -ne 0) { throw 'Mutation campaign failed' }
Copy-Item -LiteralPath 'reports/mutation_campaign.md' -Destination 'reports/control_mutation_summary.md' -Force
