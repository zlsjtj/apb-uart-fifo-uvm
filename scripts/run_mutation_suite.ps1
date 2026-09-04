$ErrorActionPreference = "Stop"
& (Join-Path $PSScriptRoot "run_mutation_campaign.ps1")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Copy-Item reports/mutation_campaign.md reports/mutation_matrix.md -Force
