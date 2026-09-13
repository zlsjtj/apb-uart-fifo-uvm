param([int]$Seed=1401)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'evidence_common.ps1')
. "$PSScriptRoot/toolchain_common.ps1"
$null=Initialize-Toolchain
$source=Get-SourceIdentity
New-Item -ItemType Directory -Force logs,reports | Out-Null
if (!(Test-Path work_fifo_unit)) { & vlib work_fifo_unit | Out-Null; if ($LASTEXITCODE) { throw 'vlib failed' } }
& vlog -work work_fifo_unit -sv -assertdebug rtl/reset_sync.sv rtl/async_fifo.sv tb/unit/async_fifo_random_tb.sv -l logs/fifo_unit_compile.log | Out-Null
if ($LASTEXITCODE) { throw 'FIFO unit compilation failed' }
$rows=@()
foreach ($width in @(1,2,4,6)) {
  foreach ($clock in @(@(3,5),@(7,2))) {
    $actualSeed=$Seed+$rows.Count
    $log="logs/fifo_unit_w${width}_$actualSeed.log"
    & vsim -c work_fifo_unit.async_fifo_random_tb "-gADDR_WIDTH=$width" "-gWR_HALF=$($clock[0])" "-gRD_HALF=$($clock[1])" -sv_seed $actualSeed -assertdebug -do 'run -all; quit -f' -l $log | Out-Null
    $exit=$LASTEXITCODE; $text=Get-Content -Raw $log
    if ($exit -ne 0 -or $text -notmatch 'FIFO_RANDOM_PASS' -or $text -match '(?m)^#?\s*\*\* (Error|Fatal|Warning)') { throw "FIFO unit failure: $log" }
    $marker=([regex]::Match($text,'FIFO_RANDOM_PASS[^\r\n]+')).Value
    $rows+=@{width=$width; seed=$actualSeed; wrHalf=$clock[0]; rdHalf=$clock[1]; result='PASS'; log=$log; evidence=$marker}
  }
}
Assert-SourceIdentity $source
Write-EvidenceJson 'reports/fifo_unit_tests.json' @{result='PASS';source=$source;cases=$rows}
Write-Host "FIFO independent unit tests passed: $($rows.Count)/$($rows.Count)"
