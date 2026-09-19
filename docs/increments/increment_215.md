# Increment 215 — Historical A/B Performance Adapter

Adds the bridge from the existing frozen A/B `HistoricalSignalRecord` lifecycle
output into Strategy Performance Analytics.

## Semantics

- Reuses existing lifecycle records; it does not replay or reconstruct trades.
- Only triggered TP/SL records become trading P/L.
- TP contributes the record's frozen planned RR.
- SL contributes `-1R`.
- Pre-entry invalidation/expiry is excluded from trading P/L.
- BUY/SELL comes from the frozen `HistoricalSignalRecord.direction`.
- A/B trades are globally sorted by trigger observation time before the Overall
  analytics calculation, preserving chronological maximum drawdown.
- No AI input, strategy threshold, risk parameter, execution rule, or gate is
  changed.

This increment establishes the safe integration boundary. The next increment
can wire the existing A/B historical runner into this adapter and print the real
A/B performance report with sample-quality labels.
