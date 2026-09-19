# Increment 218 — Strategy Deployment Registry (corrected)

## Lifecycle

`Historical Research -> Forward Shadow -> Paper -> Production`

## Current deployment

### Production
- A
- C5

### Paper Forward — 8 frozen segments / 7 distinct strategy IDs
The registry does **not** maintain a second handwritten Paper list. It reads the
existing frozen `paperForwardSegmentPortfolioV3` directly.

1. ATR_EXPANSION | BUY | TREND
2. TREND_PULLBACK | SELL | RANGE
3. LIQ_SWEEP | SELL | RANGE
4. ADX_TREND | BUY | TREND
5. EMA_MEAN_REVERT | SELL | RANGE
6. NR7_BREAKOUT | SELL | RANGE
7. ENGULFING_REVERSAL | SELL | RANGE
8. ENGULFING_REVERSAL | BUY | TREND

There are 8 segments but 7 distinct strategy IDs because
ENGULFING_REVERSAL has two separately frozen side/regime segments.

### Historical Research
- B — Correction Continuation

## Invariants
- Paper membership has one source of truth: `paperForwardSegmentPortfolioV3`.
- Paper segments cannot become Production merely by appearing in the registry.
- B cannot emit user signals or enter Production forward statistics.
- Historical, Paper, and Production evidence remain separate.
- This increment changes deployment metadata only, not trading rules.
- Promotion/demotion/deletion remains an explicit research decision.

## Validate

```powershell
cd "C:\flutter project\tradeforge_v2\research\backtesting"
dart format .
dart analyze
dart test
```
