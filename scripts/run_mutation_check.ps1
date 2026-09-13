param([string]$Test='uart_loopback_test', [int]$Seed=71, [string]$Filelist='filelist.f')
# Compatibility entry for UART_MUTATE_TX_LSB. All verdicts use the baseline-controlled campaign.
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'run_mutation_campaign.ps1') -CaseIds 'tx_lsb' -TestOverride $Test -SeedOverride $Seed -Filelist $Filelist
if ($LASTEXITCODE -ne 0) { throw 'Mutation campaign failed' }
Copy-Item -LiteralPath 'reports/mutation_campaign.md' -Destination 'reports/mutation_summary.md' -Force
