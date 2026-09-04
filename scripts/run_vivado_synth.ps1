param(
  [string]$VivadoBat = "E:\Xilinx\Vivado\2023.2\bin\vivado.bat"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $VivadoBat)) {
  throw "Vivado was not found at '$VivadoBat'."
}
New-Item -ItemType Directory -Force reports/synthesis, logs | Out-Null

& $VivadoBat -mode batch -nolog -nojournal -source scripts/vivado_synth.tcl 2>&1 |
  Tee-Object -FilePath logs/vivado_synth.log
if ($LASTEXITCODE -ne 0) {
  throw "Vivado synthesis failed. See logs/vivado_synth.log"
}
$logText = Get-Content -Raw logs/vivado_synth.log
if (($logText -notmatch 'SYNTH_EVIDENCE_PASS') -or ($logText -match '(?m)^ERROR:')) {
  throw "Vivado synthesis did not produce an explicit PASS marker."
}
$qor = Get-Content -Raw reports/synthesis/qor.json | ConvertFrom-Json
if (($qor.timing.pclk.wnsNs -lt 0) -or ($qor.timing.uartClock.wnsNs -lt 0)) {
  throw "Post-synthesis timing does not meet the declared clock constraints."
}
if ($qor.utilization.distributedRamCells -le 0) {
  throw "FIFO storage was not inferred as distributed RAM."
}
$synthWarningCount = if ($logText -match 'Synthesis finished with 0 errors, 0 critical warnings and (\d+) warnings') {
  [int]$Matches[1]
} else { $null }
$qor | Add-Member -NotePropertyName synthesisWarningCount -NotePropertyValue $synthWarningCount -Force
$qor | ConvertTo-Json -Depth 7 | Set-Content -Encoding UTF8 reports/synthesis/qor.json
$summary = @(
  "# Vivado Synthesis Summary", "",
  "- Time: ``$($qor.generatedAt)``",
  "- Result: **PASS**",
  "- Tool: ``$($qor.tool)``",
  "- Part: ``$($qor.part)``（通用证据器件）",
  "- LUT cells: ``$($qor.utilization.lutCells)``",
  "- Sequential cells: ``$($qor.utilization.sequentialCells)``",
  "- Distributed RAM primitive cells: ``$($qor.utilization.distributedRamCells)``",
  "- Synthesis warnings: ``$synthWarningCount``（均保留在原始日志中）",
  "- PCLK constraint / WNS / estimated Fmax: ``10.0 ns / $($qor.timing.pclk.wnsNs) ns / $($qor.timing.pclk.estimatedFmaxMHz) MHz``",
  "- UART clock constraint / WNS / estimated Fmax: ``40.0 ns / $($qor.timing.uartClock.wnsNs) ns / $($qor.timing.uartClock.estimatedFmaxMHz) MHz``", "",
  "该结果来自 ``xc7a35tcpg236-1`` 的 RTL 综合，用于证明设计可综合并给出资源、综合后时序基线。它不是布局布线结果，不代表具体开发板频率，也没有生成 bitstream 或完成上板测试。"
)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines((Join-Path (Get-Location) "reports/synthesis/summary.md"), $summary, $utf8NoBom)
Write-Host "Vivado synthesis evidence passed: $($qor.part)"
