# Increment 219.1 — Independent Exposure Performance Fix

Fixes forward performance aggregation so repeated triggers from the same active
strategy exposure cannot inflate trade count or performance.

## Rule

A resolved signal contributes to performance only when:

- `independentEvidence == true`
- it is not `same_exposure`
- `realizedR` exists and is finite

`same_exposure` records remain in signal history for auditability but do not
contribute to:

- trade count
- W/L
- win rate
- expectancy
- total R
- max drawdown

Cross-strategy `portfolio_overlap` remains valid evidence when
`independentEvidence == true`.

## Regression tests

- Three C5 triggers in one exposure count as exactly one trade.
- Portfolio overlap remains countable.
- Non-independent evidence is excluded defensively.

## Validate

```powershell
cd "C:\flutter project\tradeforge_v2\apps\mobile"
dart format .
flutter analyze
flutter test
flutter run -d edge
```
