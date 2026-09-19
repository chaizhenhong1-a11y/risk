# Increment 212 — Paper Forward Performance Adapter

This increment connects the existing paper-forward result files directly to the
strategy performance analytics engine.

Supported sources:

- `.paper_forward/xauusd_results.jsonl`
  - C5 paper-forward lifecycle results.
  - `observedAt`, strategy and BUY/SELL are recovered from the existing
    `signalId`.
  - `grossR` is used as the realized R outcome.

- `.paper_forward/segments/segment_results.jsonl`
  - Segment paper-forward results.
  - `segmentId` supplies the segment strategy name.
  - `side`, `observedAt` and `realizedR` are used directly.

C5 and Segment reports remain completely separate. Segment research strategies
are never mixed into the A/B/C5 aggregate.

The adapter sorts resolved outcomes chronologically before analytics so maximum
drawdown uses the actual result sequence. It does not reconstruct trades,
change Entry/SL/TP, or involve AI.

Run from `research/backtesting`:

    dart run bin/xauusd_paper_forward_performance.dart

An alternate paper-forward root may be passed as the first argument.
