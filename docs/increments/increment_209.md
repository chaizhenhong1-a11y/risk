# Increment 209 — Strategy Performance Analytics 核心引擎

本增量开始建立纯回测统计层，不经过 AI。

## 当前指标
- Overall 总交易次数
- 胜 / 负 / Break-even
- 胜率
- Expectancy（R）
- Average R
- Profit Factor
- Total R
- Maximum Drawdown（R）
- 每个 Strategy 独立统计
- 每个 Strategy 的 BUY / SELL 独立统计

## 重要定义
胜率只用已经分出胜负的样本：wins / (wins + losses)，Break-even 单独记录。

Expectancy 当前按每笔真实 realized R 的平均值计算，因此与 Average R 数值相同，但保留独立字段，方便后续扩展手续费、滑点和不同风险模型。

Profit Factor = Gross Winning R / Gross Losing R。

Maximum Drawdown 使用按交易发生顺序累积的 R equity curve，从历史峰值到后续低点计算。

## 范围
209 只建立统计数学核心和测试，不伪造任何 Strategy A/B/C 的真实胜率。
下一步需要把现有 replay/backtest 的真实 trade outcomes 接进该引擎，再生成 Overall 与各 Strategy 的真实报告。
