# Increment 207 — AI Review 综合推理契约

复核顺序固定为：多周期行情 → 新闻/经济日历 → contextFreshness → 综合 second opinion。

supportPercent / opposePercent 仍然只是 AI Review 倾向，不是胜率、回测概率、隐藏公式或 Gate。即使反对 95%+，也不能删除或拒绝 Candidate。

## 应用

在 `research/backtesting` 目录运行一次：

`dart run tool/apply_increment_207.dart`

成功后删除 `tool/apply_increment_207.dart`。它只是一次性补丁工具，不属于正式源码。
