. "$PSScriptRoot/evidence_common.ps1"

function Resolve-ContainedPath([string]$Root,[string]$Relative) {
  if (!$Relative -or [IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\\/])\.\.([\\/]|$)' -or $Relative.Contains(':')) { throw 'DELIVERY_PATH: relative path required' }
  $rootPath=[IO.Path]::GetFullPath($Root).TrimEnd('\','/')
  $path=[IO.Path]::GetFullPath((Join-Path $rootPath $Relative))
  if (!$path.StartsWith($rootPath+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'DELIVERY_PATH: path escapes root' }
  $current=$path
  while ($current.Length -gt $rootPath.Length) {
    if ((Test-Path -LiteralPath $current) -and ((Get-Item -LiteralPath $current).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'DELIVERY_PATH: reparse point refused' }
    $current=Split-Path $current -Parent
  }
  return $path
}

function Get-DeliveryFiles([string]$Root) {
  $rootPath=[IO.Path]::GetFullPath($Root).TrimEnd('\','/')
  $items=@(Get-ChildItem -LiteralPath $rootPath -Recurse -Force)
  if (@($items | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) { throw 'DELIVERY_PATH: reparse point refused' }
  @($items | Where-Object { !$_.PSIsContainer -and $_.FullName -ne (Join-Path $rootPath 'delivery_manifest.json') } | Sort-Object FullName | ForEach-Object {
    @{path=$_.FullName.Substring($rootPath.Length+1).Replace('\','/');bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
  })
}

function Assert-Delivery([string]$Root) {
  if ((Get-Item -LiteralPath $Root).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'DELIVERY_PATH: reparse root refused' }
  $manifest=Get-Content -Raw -LiteralPath (Join-Path $Root 'delivery_manifest.json') | ConvertFrom-Json
  if ($manifest.schemaVersion -ne 1 -or $manifest.result -ne 'PASS' -or !$manifest.files.Count) { throw 'DELIVERY_MANIFEST: invalid manifest' }
  $seen=@{}
  foreach ($row in $manifest.files) {
    $path=Resolve-ContainedPath $Root $row.path
    if ($seen.ContainsKey($path)) { throw 'DELIVERY_MANIFEST: duplicate file' }
    $seen[$path]=$true
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "DELIVERY_MISSING: $($row.path)" }
    if ((Get-Item -LiteralPath $path).Length -ne $row.bytes -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $row.sha256) { throw "DELIVERY_HASH: $($row.path)" }
  }
  $actual=@(Get-DeliveryFiles $Root)
  if ($actual.Count -ne $manifest.files.Count) { throw 'DELIVERY_EXTRA: unlisted file' }
  $summary=Get-Content -Raw -LiteralPath (Join-Path $Root 'acceptance_summary.json') | ConvertFrom-Json
  if ($summary.result -ne 'PASS' -or $summary.runId -ne $manifest.runId -or $summary.source.sha256 -ne $manifest.sourceSha256) { throw 'DELIVERY_IDENTITY: acceptance mismatch' }
  Assert-SourceIdentity $summary.source $Root
  return $manifest
}

function Assert-AcceptanceRun($Summary,[string]$Snapshot) {
  $expected=@('Toolchain and license preflight','Workflow integrity self-tests','Gate negative self-tests',
    'RTL lint and structural CDC/RDC','APB completion-edge and FIFO parameter contract','Independent randomized FIFO unit checks',
    'OOC synthesis, timing and CDC path classification','Three-seed regression and coverage gates',
    'Parameterized UVM and no-probe checks','Same-seed baseline controlled mutation campaign')
  $plan=Import-PowerShellDataFile (Join-Path $Snapshot 'config/verification_plan.psd1')
  $expected+=@($plan.StressProfiles | ForEach-Object { 'Stress '+$_.Name })
  if ($Summary.result -ne 'PASS' -or $Summary.steps.Count -ne $expected.Count -or
      @($Summary.steps | Where-Object result -ne 'PASS').Count -or
      @($Summary.steps.name | Select-Object -Unique).Count -ne $expected.Count) { throw 'DELIVERY_ACCEPTANCE: incomplete or failed run' }
  foreach ($name in $expected) { if ($name -notin $Summary.steps.name) { throw "DELIVERY_ACCEPTANCE: missing $name" } }
  Assert-SourceIdentity $Summary.source $Snapshot
  foreach ($relative in @('runtime_manifest.json','workflow_selftests.json','evidence_gate_selftests.json','static_checks.json',
    'contract_tests.json','fifo_unit_tests.json','parameter_regression/summary.json','mutation_campaign.json',
    'final_regression/final_regression_summary.json','final_regression/coverage/functional_assertion_gate.json',
    'final_regression/coverage/rtl_coverage_gate.json','synthesis/cdc_review.json')) {
    $report=Get-Content -Raw -LiteralPath (Join-Path $Snapshot "reports/$relative") | ConvertFrom-Json
    if ($report.result -ne 'PASS') { throw "DELIVERY_REPORT: not PASS: $relative" }
    if ($report.PSObject.Properties.Name -contains 'source' -and $report.source.PSObject.Properties.Name -contains 'sha256') {
      if ($report.source.sha256 -ne $Summary.source.sha256) { throw "DELIVERY_REPORT: mixed source: $relative" }
    }
  }
  $identity=Get-Content -Raw (Join-Path $Snapshot 'reports/final_regression/source_manifest.json') | ConvertFrom-Json
  if ($identity.sha256 -ne $Summary.source.sha256) { throw 'DELIVERY_REPORT: mixed source manifest' }
  foreach ($relative in @('reports/final_regression/coverage/regression_merged.ucdb','reports/final_regression/coverage/html/index.html','reports/synthesis/qor.json')) {
    $p=Join-Path $Snapshot $relative
    if (!(Test-Path -LiteralPath $p -PathType Leaf) -or (Get-Item -LiteralPath $p).Length -eq 0) { throw "DELIVERY_MISSING: $relative" }
  }
  $reg=Get-Content -Raw (Join-Path $Snapshot 'reports/final_regression/final_regression_summary.json') | ConvertFrom-Json
  if ($reg.tests.Count -ne ($plan.RegressionTests.Count*$Summary.seeds.Count) -or @($reg.tests | Where-Object Status -ne 'PASS').Count) { throw 'DELIVERY_REPORT: incomplete regression' }
  foreach ($profile in $plan.StressProfiles) {
    $stress=Get-Content -Raw (Join-Path $Snapshot ("reports/stress/"+$profile.Name+'/regression_summary.json')) | ConvertFrom-Json
    if ($stress.result -ne 'PASS' -or $stress.source.sha256 -ne $Summary.source.sha256 -or $stress.tests.Count -ne $profile.Tests.Count) { throw 'DELIVERY_REPORT: mixed or incomplete stress' }
  }
  $qor=Get-Content -Raw (Join-Path $Snapshot 'reports/synthesis/qor.json') | ConvertFrom-Json
  if ($qor.sourceSha256 -ne $Summary.source.sha256 -or $qor.overallSetupWnsNs -lt 0) { throw 'DELIVERY_REPORT: synthesis mismatch' }
}

function New-PaperResults([string]$Root,$Summary) {
  function Read-Report([string]$Path) { Get-Content -Raw -LiteralPath (Join-Path $Root "reports/$Path") | ConvertFrom-Json }
  $reg=Read-Report 'final_regression/final_regression_summary.json'
  $param=Read-Report 'parameter_regression/summary.json'
  $fifo=Read-Report 'fifo_unit_tests.json'
  $mut=Read-Report 'mutation_campaign.json'
  $coverage=Read-Report 'final_regression/coverage/functional_assertion_gate.json'
  $rtl=Read-Report 'final_regression/coverage/rtl_coverage_gate.json'
  $cdc=Read-Report 'synthesis/cdc_review.json'
  $qor=Read-Report 'synthesis/qor.json'
  $stress=0
  $plan=Import-PowerShellDataFile (Join-Path $Root 'config/verification_plan.psd1')
  foreach ($profile in $plan.StressProfiles) { $s=Read-Report ("stress/"+$profile.Name+'/regression_summary.json'); $stress+=$s.tests.Count }
  $parameterCount=0
  foreach ($row in $param.widths) { $parameterCount+=$row.tests.Count }
  $lines=@('# 本轮验收与论文结果表','',"运行：$($Summary.runId)。以下数字只对应这一轮，不累计历史测试。",
    "源码 SHA-256：$($Summary.source.sha256)",'',
    "随机模式：$($Summary.seedMode)，campaign seed：$($Summary.campaignSeed)，正式回归基准 seed：$($Summary.seeds -join ', ')。",'',
    '| 检查 | 本轮结果 | 证据 |','| --- | --- | --- |',
    "| 完整验收 | $($Summary.steps.Count)/$($Summary.steps.Count) PASS | [验收摘要](acceptance_summary.json) |",
    "| 正式 UVM 回归 | $($reg.tests.Count)/$($reg.tests.Count) | [回归](reports/final_regression/final_regression_summary.json) |",
    "| FIFO 深度参数子集 | $parameterCount/$parameterCount | [参数矩阵](reports/parameter_regression/summary.json) |",
    "| 无探针模式 | $($param.noProbe.tests.Count)/$($param.noProbe.tests.Count) | 同上 |",
    "| 快 UART、慢 APB | $($param.fastUart.tests.Count)/$($param.fastUart.tests.Count) | 同上 |",
    "| 错相压力 | $stress/$stress | reports/stress |",
    "| 独立 FIFO 随机测试 | $($fifo.cases.Count)/$($fifo.cases.Count) | [FIFO 单元](reports/fifo_unit_tests.json) |",
    "| 故障注入 | $($mut.killed)/$($mut.total) KILLED | [同测试、同种子基线](reports/mutation_campaign.json) |")
  foreach ($gate in $coverage.gates) { $lines+="| $($gate.metric) | $($gate.hits)/$($gate.active) | [覆盖率门禁](reports/final_regression/coverage/functional_assertion_gate.json) |" }
  $lines+="| RTL 门禁 | $($rtl.gates.Count)/$($rtl.gates.Count) | [RTL 门禁](reports/final_regression/coverage/rtl_coverage_gate.json) |"
  $lines+="| CDC 路径分类 | $($cdc.parsed)/$($cdc.declared)，Critical $(@($cdc.paths | Where-Object severity -eq 'Critical').Count)，Warning $(@($cdc.paths | Where-Object severity -eq 'Warning').Count) | [CDC 审核](reports/synthesis/cdc_review.json) |"
  $lines+=@('',"OOC 器件：$($qor.part)；Slice LUT：$($qor.fpgaResources.sliceLuts)；Slice Registers：$($qor.fpgaResources.sliceRegisters)；LUT as Memory：$($qor.fpgaResources.lutAsMemory)；总体 setup WNS：$($qor.overallSetupWnsNs) ns。",'',
    '这些结果说明计划范围内的仿真、覆盖率门禁和综合检查通过，不是无缺陷证明，也不是布局布线、板级频率或真实串口运行证据。',
    '交付清单使用相对路径，可在搬移后校验。原始日志和报告中的本机绝对路径作为运行出处保留，不作为交付包导航入口。')
  $lines | Set-Content -LiteralPath (Join-Path $Root 'paper_results.md') -Encoding UTF8
}
