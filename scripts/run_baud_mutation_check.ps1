param([string]$Test='uart_baud_timing_test', [int]$Seed=96, [string]$Filelist='filelist.f')
# Compatibility entry for UART_MUTATE_BAUD_TICK_FAST. All verdicts use the baseline-controlled campaign.
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'run_mutation_campaign.ps1') -CaseIds 'baud_fast' -TestOverride $Test -SeedOverride $Seed -Filelist $Filelist
if ($LASTEXITCODE -ne 0) { throw 'Mutation campaign failed' }
Copy-Item -LiteralPath 'reports/mutation_campaign.md' -Destination 'reports/baud_mutation_summary.md' -Force
