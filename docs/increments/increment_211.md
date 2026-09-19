# Increment 211 — A/B/C5 真实 Performance Report 入口

新增 `bin/xauusd_abc_performance_report.dart`。

它直接读取现有 A/B/C5 lifecycle JSONL，与 Increment 138 的 expectancy audit 使用相同的真实生命周期字段：
- strategy
- observedAt
- resolution
- rewardRisk
- costR

如果 lifecycle row 已经包含 `side: BUY|SELL`，报告会额外输出真实方向拆分。
如果没有 side，不猜测方向。

输出：
- Overall
- Strategy A / B / C5
- trade count
- W/L/BE
- win rate
- expectancy R
- profit factor
- total R
- max drawdown R
- BUY/SELL（仅真实 side 存在时）

本增量不重新构造 Entry/SL/TP，不修改 frozen strategy rules，不使用 AI 生成 performance。
