# Increment 205 — M5/M15/H1/H4 接入 AI Review

## 目标
把现有 `AiMarketContextSnapshot` 真正接入 Candidate → Gemini Review，
让 AI 在复核已存在的策略 Candidate 时，同时看到候选时刻的多周期 CLOSED-bar 摘要。

## 数据路径
`BiQuoteClosedBarStore`
→ `BiQuoteLiveMarketSnapshot.fromStore(observedAt: candidate.observedAt)`
→ `AiMarketContextSnapshot`
→ `candidate.marketContext`
→ `CandidateFundamentalReviewService`
→ Gemini Review

## 防未来数据
市场快照严格按 Candidate 自己的 `observedAt` 重建。
`BiQuoteLiveMarketSnapshot.fromStore` 只保留 `closeTime <= observedAt` 的 CLOSED bars，
因此后来进入 store 的 K 线不会泄漏给旧 Candidate。

## Fail-open
只有 M5/M15/H1/H4 四个周期都有 CLOSED bar 时才附加 `marketContext`。
若任一周期缺失：
- Candidate 仍保留；
- AI Review 仍可继续；
- `aiContextAudit.marketContextAvailable = false`；
- 不新增 Gate。

## 不改变
- 不修改 Strategy。
- 不修改 BUY/SELL。
- 不修改 Entry/SL/TP。
- 不修改 execution eligibility。
- AI 支持/反对比例仍只是 Review 倾向，不是胜率。
- AI Review 仍然不能删除或拒绝 Candidate。
