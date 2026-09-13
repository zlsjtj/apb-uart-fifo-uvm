param([int[]]$Widths = @(1..16))
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/toolchain_common.ps1"
$null=Initialize-Toolchain
New-Item -ItemType Directory -Force logs, reports | Out-Null
if (!(Test-Path work_contract)) { & vlib work_contract | Out-Null }
& vlog -work work_contract -sv -f rtl_filelist.f rtl/async_fifo_sva.sv tb/unit/apb_contract_tb.sv -l logs/contract_compile.log | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Contract test compilation failed' }
$rows = @()
foreach ($width in $Widths) {
  if ($width -lt 1 -or $width -gt 16) { throw 'FIFO width outside 1..16' }
  $log = "logs/apb_contract_width_$width.log"
  $mode = if ($width -in @(1,2,4,6)) { 'functional_wraparound' } else { 'elaboration_only' }
  [string[]]$extra = @()
  if ($mode -eq 'elaboration_only') { $extra = @('+ELAB_ONLY') }
  & vsim -c work_contract.apb_contract_tb "-gFIFO_ADDR_WIDTH=$width" @extra -do 'run -all; quit -f' -l $log | Out-Null
  $exit = $LASTEXITCODE
  $txt = Get-Content -Raw $log
  if ($exit -ne 0 -or $txt -notmatch 'APB_CONTRACT_PASS' -or $txt -match '(?m)^#?\s*\*\* (Error|Fatal):') {
    throw "APB contract failed for FIFO width $width; see $log"
  }
  $rows += [pscustomobject]@{ width=$width; depth=(1 -shl $width); mode=$mode; result='PASS'; log=$log }
}
@{ result='PASS'; cases=$rows; boundary='Strict completion-edge APB and FIFO wraparound, widths explicitly listed' } |
  ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 reports/contract_tests.json
Write-Host "APB contract and FIFO parameter tests passed: $($rows.Count)/$($rows.Count)"
