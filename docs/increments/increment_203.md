# Increment 203 — AI 百分比解释层

- AI 复核在 `支持 % / 反对 %` 之外增加两条简短解释：
  - `supportExplanation`：为什么支持比例会上升。
  - `opposeExplanation`：为什么反对比例会上升。
- Gemini 被要求所有面向用户的 Review 文本使用简洁中文。
- 解释只能引用输入中已有的 Candidate、经济日历和新闻事实，不允许编造指标、行情结构、事件或数学评分公式。
- 百分比仍然只是 AI Review 倾向，不是胜率，也不是统计校准概率。
- API 新增 `aiSupportExplanation` / `aiOpposeExplanation`。
- Mobile UI 在百分比下方直接显示“为什么支持 / 为什么反对”，保持简洁中文。
- AI Review 继续保持 advisory-only；任何支持/反对比例都不能成为 Candidate Gate。
