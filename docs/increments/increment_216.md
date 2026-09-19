# Increment 216 — Real A/B Historical Performance Report

Connect the frozen A/B historical lifecycle output to the reusable performance
analytics reporting path.

## Integration

The existing `xauusd_ab_unified_expectancy_audit.dart` already produces the
authoritative Strategy A and Strategy B `HistoricalSignalRecord` collections.
The runner should pass those exact collections to
`HistoricalRecordPerformanceAdapter` using the real M5 close-time lookup, then
print the result with `formatStrategyPerformanceReport`.

Recommended runner integration immediately after the existing A/B expectancy
audit results are created:

```dart
const performanceAdapter = HistoricalRecordPerformanceAdapter();
final performance = performanceAdapter.analyze([
  HistoricalStrategyPerformanceInput(
    strategy: 'A',
    records: a,
    timeForObservationIndex: (index) => m5[index].closeTime,
  ),
  HistoricalStrategyPerformanceInput(
    strategy: 'B',
    records: b,
    timeForObservationIndex: (index) => m5[index].closeTime,
  ),
]);

stdout.writeln('');
stdout.writeln(
  formatStrategyPerformanceReport(
    performance,
    title: 'A/B HISTORICAL PERFORMANCE',
  ),
);
```

Required imports:

```dart
import 'package:tradeforge_backtesting/src/analytics/historical_record_performance_adapter.dart';
import 'package:tradeforge_backtesting/src/analytics/strategy_performance_report_formatter.dart';
```

## Invariants

- No historical replay rule is duplicated or changed.
- No trade is reconstructed from Entry/SL/TP.
- BUY/SELL comes from the frozen historical lifecycle record.
- Overall maximum drawdown remains globally chronological across A and B.
- Sample Quality is reporting context only and never a strategy gate.
- C5 remains outside this A/B report until its separate frozen structural
  lifecycle is integrated.
