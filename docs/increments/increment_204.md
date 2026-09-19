# Increment 204 — AI Review 输入质量审计

本增量只审计 Gemini 实际收到的上下文，不改变策略、Candidate 或执行资格。

## 新增
- `AiReviewContextAudit`
- 审计 Candidate 核心字段：
  - strategy
  - side
  - entry
  - stopLoss
  - takeProfit
  - riskReward
  - reason
  - exposureStatus
- 审计新闻上下文是否可用。
- 审计经济日历上下文是否可用。
- 明确审计 `marketContextAvailable`。

## 重要发现
仓库已有 `AiMarketContextSnapshot`（M5/M15/H1/H4），但当前 Candidate → Gemini Review
链路尚未把它接入，因此本增量不会假装 Gemini 已经看到多周期行情。

## 边界
- `FULL / PARTIAL / LIMITED` 只描述 AI 输入覆盖程度。
- 它不是胜率。
- 它不是 Confidence。
- 它不是 Candidate Gate。
- 输入不完整不会删除 Candidate。
- AI/新闻/日历不可用仍然 fail-open。
- 本增量不修改 BUY/SELL、Entry、SL、TP 或任何策略规则。

后续增量可在确认 live snapshot 生命周期后，再安全接入现有
`AiMarketContextSnapshot`，而不是在本增量中直接硬接。
