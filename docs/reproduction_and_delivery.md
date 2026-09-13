# 复现与交付

## 配置工具

项目默认值在 config/toolchain.psd1。机器路径放在根目录 toolchain.local.psd1，不进入 Git，也不进入被测源码身份。例如：

```powershell
@{
  QuestaBin = 'C:\modeltech64_10.4\win64'
  VivadoBat = 'E:\Xilinx\Vivado\2023.2\bin\vivado.bat'
}
```

优先级为环境变量、机器配置、项目配置。环境变量为 APB_UART_QUESTA_BIN、APB_UART_VIVADO_BAT、APB_UART_PART。空路径使用 PATH；更换器件仍需重新审查约束与 CDC 策略。

```powershell
pwsh -NoProfile -File scripts/run_toolchain_preflight.ps1
pwsh -NoProfile -File scripts/test_workflow.ps1
```

预检查记录实际文件路径、版本和器件；真正编译、加载、运行小模块检查仿真许可，启动 Vivado 检查器件支持。它不能保证后续所有工具功能都不遇到许可问题，正式步骤仍检查退出码和结果。

## 运行与种子

固定模式保留原始复现种子；expanded 模式将 campaign seed 加到压力配置和每项 mutation 的基准种子。正式回归仍由 Seeds 控制。

```powershell
pwsh -NoProfile -Command '& ./scripts/run_acceptance.ps1 -Seeds @(3701,3801,3901) -SeedMode expanded -CampaignSeed 10000'
pwsh -NoProfile -Command '& ./scripts/run_acceptance.ps1 -Seeds @(4701,4801,4901) -SeedMode expanded -CampaignSeed 20000'
```

验收为 12 步：环境预检查、工作流测试，加上原有 10 项检查。runtime_manifest.json 记录实际环境；验收摘要记录种子模式，各子报告保留实际种子。

## 导出与校验

读取 reports/acceptance_summary.json 的实际 runId，替换占位符：

```powershell
pwsh -NoProfile -File scripts/export_acceptance.ps1 -RunId '<runId>'
pwsh -NoProfile -File scripts/verify_delivery.ps1 -Path 'deliveries/<runId>'
```

只接受完整 PASS 且源码相符的运行。不读取工作区零散旧报告，先写临时目录，核对文件后改名。正式交付目录不覆盖；失败留下临时目录便于排查，不更新最新入口。

delivery_manifest.json 覆盖源码、文档、日志、UCDB、HTML 和报告。新增、缺失、哈希变化、重复项和越界路径都会失败。整个目录搬移后可继续校验；这是完整性检查，不是带签名的来源认证。原始报告中的本机绝对路径保留为运行出处，交付导航使用相对路径。

完整包位于本地 deliveries，不进入 Git。reports/published/latest.json 指向仓库内的摘要、清单、版本和论文结果表。轻量结果表保留完整包内部的相对链接，查看全部证据请打开本地完整包。

## 论文与演示

当前结构见 current_architecture_and_optimization.md，图示见 architecture_figures.md。交付包的 paper_results.md 是结果表来源；requirements_and_scope.md 和 traceability_matrix.md 用于说明范围。

两个案例分别见 bug_closure_case.md 和 tx_completion_case.md。前者讲 APB 完成沿响应与 BFM 共同假设，后者讲 TX 完成语义、Gray 返回路径与提前完成故障注入。

演示顺序建议为：寄存器与 loopback、无探针检查、完整停止位前 TX_BUSY 保持、同种子正确基线与提前完成 mutation 对比、覆盖率与交付校验。历史数字只属于原记录，不并入当前表。
