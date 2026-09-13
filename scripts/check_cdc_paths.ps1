param([string]$Report='reports/synthesis/cdc.rpt', [string]$Policy='config/cdc_path_policy.psd1',
      [string]$Output='reports/synthesis/cdc_review.json')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'evidence_common.ps1')
$rules = (Import-PowerShellDataFile $Policy).Rules
$rows=@(); $declared=0
foreach ($line in (Get-Content $Report)) {
  if ($line -match '^CDC-\d+\s+(?:Info|Warning|Critical)\s+(\d+)') { $declared += [int]$Matches[1] }
  if ($line -notmatch '^\s*\d+\s+(CDC-\d+)\s+(Info|Warning|Critical)\s+') { continue }
  $code=$Matches[1]; $severity=$Matches[2]
  $parts=$line.Trim() -split '\s{2,}'
  $source=$parts[-2]; $dest=$parts[-1]
  $matched=@($rules | Where-Object { $_.Code -eq $code -and $source -match $_.Source -and $dest -match $_.Destination })
  $disposition=if ($severity -eq 'Critical') { 'REJECT' }
    elseif ($severity -eq 'Info' -and $code -in @('CDC-3','CDC-9')) { 'SYNCHRONIZER_INFO' }
    elseif ($matched.Count -eq 1) { $matched[0].Id } else { 'UNREVIEWED' }
  $rows += [pscustomobject]@{ code=$code; severity=$severity; source=$source; destination=$dest; disposition=$disposition }
}
$bad=@($rows | Where-Object { $_.disposition -in @('REJECT','UNREVIEWED') })
$result=if ($declared -gt 0 -and $rows.Count -eq $declared -and $bad.Count -eq 0) { 'PASS' } else { 'FAIL' }
Write-EvidenceJson $Output ([ordered]@{ result=$result; declared=$declared; parsed=$rows.Count; rejected=$bad.Count; paths=$rows; rules=$rules;
  boundary='Vivado synthesized internal CDC path classification for this teaching interface, not commercial CDC/RDC signoff. RXDATA ends at combinational APB output and is manually reviewed under the FIFO read contract; rx_i has a synchronous teaching timing assumption, not asynchronous board qualification.' })
if ($result -ne 'PASS') { throw "CDC_PATH_REVIEW_FAILED: $($bad.Count) unreviewed/rejected; parsed $($rows.Count)/$declared" }
Write-Host "CDC paths reviewed: $($rows.Count)/$declared; no unreviewed Critical/Warning"
