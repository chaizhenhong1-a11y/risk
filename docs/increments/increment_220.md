# Increment 220 — Frozen Paper Historical Replay

Adds a reproducible 2024–2026 historical report for all eight frozen Paper
Forward segment definitions.

The runner reuses:

- `MainstreamStrategyBatch` candidate detection and lifecycle
- `paperForwardSegmentPortfolioV3` exact strategy / side / regime definitions
- existing expectancy validation

It reports each frozen segment independently with discovered cases, resolved
trades, W/L, win rate, net expectancy, Profit Factor, Total R, Max Drawdown R,
and yearly breakdown.

Historical evidence remains separate from Paper Forward and Production and
cannot promote or gate a strategy.

## Run

```powershell
cd "C:\flutter project\tradeforge_v2\research\backtesting"
dart format .
dart analyze
dart test
dart run bin/xauusd_paper_historical_replay.dart "C:\flutter project\tradeforge\data\mt5"
```
