# Increment 210 — 真实 lifecycle 结果接入 Strategy Analytics

209 的统计引擎现在接到项目已有的 `StrategyTradeResult` / `StrategyAuditInput`。

## 原则
- 不重新模拟交易；
- 不修改 A / B / C5 策略；
- 不让 AI 计算胜率；
- 只使用已有 lifecycle 已解析的真实 `netR`；
- expired / ambiguous 不伪装成胜负；
- A / B / C5 分开统计。

## BUY / SELL
现有 `StrategyTradeResult` 本身没有方向字段。因此 210 **不会猜 BUY/SELL**。

没有方向来源时统一标记 `UNKNOWN`。
只有调用方提供真实 directional lifecycle data 时，才生成 BUY / SELL 分析。

这样避免为了做漂亮报表而制造假数据。

## 下一步
211 应定位 A/B/C5 replay/audit 入口，把它们实际产生的 `StrategyAuditInput` 汇总到统一报告命令，并确认哪些 replay 已经保留真实 side。之后才输出项目真实 Overall / Strategy 胜率。
