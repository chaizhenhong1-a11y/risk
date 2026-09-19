# Increment 202 — AI 复核支持 / 反对比例

- Gemini Candidate Review 新增 `supportPercent` 与 `opposePercent`。
- 两个比例必须是 0–100 的整数并且总和严格等于 100。
- 百分比表示 AI 对现有策略 Candidate 的复核倾向，不表示胜率或亏损概率。
- AI Review 保持 advisory-only，不成为 Gate；即使 AI 95% 反对也不会删除或阻挡 Candidate。
- AI 返回非法比例时 Review 降级为 unavailable，策略 Candidate 继续保留。
- API projection 新增 `aiSupportPercent` / `aiOpposePercent`。
- Flutter 信号页改为简洁中文 UI，突出“支持 / 反对”比例，并移除 Review 卡片中的复杂英文标签。
- 保留 execution integrity 与 AI opinion 的边界：只有客观执行完整性问题属于硬错误。
