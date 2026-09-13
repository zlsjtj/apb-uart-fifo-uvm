$ErrorActionPreference='Stop'
. "$PSScriptRoot/delivery_common.ps1"
. "$PSScriptRoot/toolchain_common.ps1"
$dir=Join-Path (Get-Location).Path ('reports/workflow_selftests/'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $dir | Out-Null
$rows=@()
function Check([string]$Name,[bool]$Condition) {
  if (!$Condition) { throw "WORKFLOW_SELFTEST: $Name" }
  $script:rows+=@{name=$Name;result='PASS'}
}
function Reject([string]$Name,[scriptblock]$Action,[string]$Pattern) {
  $message=''
  try { & $Action | Out-Null } catch { $message=$_.Exception.Message }
  Check $Name ($message -match $Pattern)
}
Write-EvidenceJson 'reports/workflow_selftests.json' @{result='RUNNING'}
try {
  Check 'fixed mode preserves baseline' ((Get-CampaignSeed 731 fixed 5000) -eq 731)
  Check 'expanded mode derives reproducible seed' ((Get-CampaignSeed 731 expanded 5000) -eq 5731)
  Check 'second campaign uses another seed' ((Get-CampaignSeed 731 expanded 6000) -ne (Get-CampaignSeed 731 expanded 5000))
  Reject 'expanded mode rejects zero seed' { Get-CampaignSeed 731 expanded 0 } 'SEED_CONFIG'
  Reject 'seed overflow rejected' { Get-CampaignSeed 2147480000 expanded 100 } 'SEED_CONFIG'
  Check 'actual Vivado output parsed' ((Get-VivadoPreflightVersion "TOOLCHAIN_PART_PASS part1`nTOOLCHAIN_VIVADO_VERSION 2023.2`n" 'part1') -eq '2023.2')
  Reject 'echoed Tcl is not successful preflight output' { Get-VivadoPreflightVersion 'puts "TOOLCHAIN_PART_PASS part1"; puts "TOOLCHAIN_VIVADO_VERSION [version -short]"' 'part1' } 'TOOL_PREFLIGHT'
  Reject 'different installed part does not satisfy request' { Get-VivadoPreflightVersion "TOOLCHAIN_PART_PASS part2`nTOOLCHAIN_VIVADO_VERSION 2023.2" 'part1' } 'TOOL_PREFLIGHT'
  Reject 'parent traversal rejected' { Resolve-ContainedPath $dir '../outside' } 'DELIVERY_PATH'
  Reject 'absolute path rejected' { Resolve-ContainedPath $dir 'C:\outside' } 'DELIVERY_PATH'
  Reject 'alternate data stream rejected' { Resolve-ContainedPath $dir 'file:stream' } 'DELIVERY_PATH'
  $savedPart=$env:APB_UART_PART; $savedBin=$env:APB_UART_QUESTA_BIN
  try {
    $env:APB_UART_PART='../invalid'
    Reject 'invalid part rejected before invoking tools' { Initialize-Toolchain } 'TOOL_CONFIG'
    $env:APB_UART_PART='xc7a35tcpg236-1'
    $env:APB_UART_QUESTA_BIN=Join-Path $dir 'nonexistent'
    Reject 'missing tool directory rejected' { Initialize-Toolchain } 'TOOL_CONFIG'
  } finally { $env:APB_UART_PART=$savedPart; $env:APB_UART_QUESTA_BIN=$savedBin }
  $fixture=Join-Path $dir 'bundle'
  New-Item -ItemType Directory -Force (Join-Path $fixture 'rtl'),(Join-Path $fixture 'config') | Out-Null
  'module fixture; endmodule' | Set-Content (Join-Path $fixture 'rtl/fixture.sv')
  'rtl/fixture.sv' | Set-Content (Join-Path $fixture 'filelist.f')
  'rtl/fixture.sv' | Set-Content (Join-Path $fixture 'rtl_filelist.f')
  '@{ StressProfiles=@() }' | Set-Content (Join-Path $fixture 'config/verification_plan.psd1')
  $identity=Get-SourceIdentity $fixture
  $summary=@{result='PASS';runId='fixture';source=$identity;steps=@()}
  Write-EvidenceJson (Join-Path $fixture 'acceptance_summary.json') $summary
  $manifest=@{schemaVersion=1;result='PASS';runId='fixture';sourceSha256=$identity.sha256;files=@(Get-DeliveryFiles $fixture)}
  $manifestPath=Join-Path $fixture 'delivery_manifest.json'
  Write-EvidenceJson $manifestPath $manifest
  Check 'valid package manifest accepted' ((Assert-Delivery $fixture).runId -eq 'fixture')
  $relocated=Join-Path $dir 'relocated'; Copy-Item -LiteralPath $fixture -Destination $relocated -Recurse
  Check 'relocated package verified' ((Assert-Delivery $relocated).runId -eq 'fixture')
  'tampered' | Set-Content (Join-Path $relocated 'rtl/fixture.sv')
  Reject 'modified file rejected' { Assert-Delivery $relocated } 'DELIVERY_HASH'
  $extra=Join-Path $dir 'extra'; Copy-Item -LiteralPath $fixture -Destination $extra -Recurse
  'unexpected' | Set-Content (Join-Path $extra 'unexpected.txt')
  Reject 'extra unlisted file rejected' { Assert-Delivery $extra } 'DELIVERY_EXTRA'
  $missing=Join-Path $dir 'missing'; Copy-Item -LiteralPath $fixture -Destination $missing -Recurse
  $missingFile=Resolve-ContainedPath $missing 'rtl/fixture.sv'
  Remove-Item -LiteralPath $missingFile
  Reject 'missing file rejected' { Assert-Delivery $missing } 'DELIVERY_MISSING'
  $originalFiles=$manifest.files
  $manifest.files=@($originalFiles)+@($originalFiles[0]); Write-EvidenceJson $manifestPath $manifest
  Reject 'duplicate entry rejected' { Assert-Delivery $fixture } 'DELIVERY_MANIFEST'
  $manifest.files=@(@{path='../outside';bytes=0;sha256='0'}); Write-EvidenceJson $manifestPath $manifest
  Reject 'malicious manifest path rejected' { Assert-Delivery $fixture } 'DELIVERY_PATH'
  $manifest.files=$originalFiles; $manifest.sourceSha256='wrong'; Write-EvidenceJson $manifestPath $manifest
  Reject 'source identity disagreement rejected' { Assert-Delivery $fixture } 'DELIVERY_IDENTITY'
  Reject 'PASS without required steps rejected' { Assert-AcceptanceRun ([pscustomobject]$summary) $fixture } 'DELIVERY_ACCEPTANCE'
  $summary.result='RUNNING'
  Reject 'unfinished acceptance rejected' { Assert-AcceptanceRun ([pscustomobject]$summary) $fixture } 'DELIVERY_ACCEPTANCE'
  $summary.result='FAIL'
  Reject 'failed acceptance rejected' { Assert-AcceptanceRun ([pscustomobject]$summary) $fixture } 'DELIVERY_ACCEPTANCE'
  Write-EvidenceJson 'reports/workflow_selftests.json' @{result='PASS';total=$rows.Count;cases=$rows}
} catch { Write-EvidenceJson 'reports/workflow_selftests.json' @{result='FAIL';error=$_.Exception.Message;cases=$rows}; throw }
$global:LASTEXITCODE=0
Write-Host "Workflow integrity self-tests passed: $($rows.Count)/$($rows.Count)"
