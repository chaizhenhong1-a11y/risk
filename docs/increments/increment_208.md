# Increment 208 — AI Review 一致性审计基础

新增 `AiReviewConsistencyAudit`，用于比较相邻的同策略、同方向 AI Review。

当前只做审计，不做平滑、不覆盖 Gemini 输出：
- 比较同 strategy + same side；
- 记录 previous/current supportPercent；
- 记录 supportDelta；
- 默认变化 >= 30 个百分点标记 largeSwing；
- 不同策略或不同方向不比较；
- AI 百分比不可用时不强行判断。

重要：largeSwing 不是 Gate，不会删除 Candidate，不会修改 BUY/SELL、Entry、SL、TP，也不会偷偷把 AI 百分比改小或平均化。

本增量先建立纯函数与测试。下一步接入 coordinator 时，必须同时带上行情/新闻/时效变化证据，避免把真实市场变化误判成 AI 不一致。
