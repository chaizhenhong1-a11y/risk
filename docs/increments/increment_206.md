# Increment 206 — AI Review 上下文时效性审计

AI Review 现在会收到行情、新闻、经济日历的时效性诊断。

默认参考阈值：
- 新闻：45 分钟
- 经济日历：15 分钟
- 市场上下文：10 分钟

新增审计字段：
- newsAgeMinutes / newsStale
- calendarAgeMinutes / calendarStale
- marketAgeMinutes / marketStale
- hasStaleContext

这些字段会以 `contextFreshness` 放进 review-only candidate copy，让 Gemini 明确知道资料是否陈旧。

重要边界：
- stale 只是 advisory context；
- 不删除 Candidate；
- 不修改 BUY/SELL；
- 不修改 Entry/SL/TP；
- 不改变 execution eligibility；
- 不成为 Gate；
- coverage FULL/PARTIAL/LIMITED 仍只描述输入覆盖程度。
