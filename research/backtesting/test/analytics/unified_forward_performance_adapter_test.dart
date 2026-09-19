import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/analytics/unified_forward_performance_adapter.dart';
import 'package:tradeforge_backtesting/src/forward/paper_signal.dart';
import 'package:tradeforge_backtesting/src/forward/paper_trade_result.dart';

void main() {
  const adapter = UnifiedForwardPerformanceAdapter();

  test('tracks only resolved A/B/C5 formal forward signals', () {
    final a = _signal('a', 'A', PaperSignalSide.buy, 1);
    final b = _signal('b', 'B', PaperSignalSide.sell, 2);
    final c5 = _signal('c5', 'C5', PaperSignalSide.buy, 3);
    final segment = _signal('seg', 'TREND_PULLBACK', PaperSignalSide.sell, 4);

    final report = adapter.analyze(
      signals: [a, b, c5, segment],
      results: [
        _result(a, 2),
        _result(b, -1),
        _result(c5, 2),
        _result(segment, 2),
      ],
    );

    expect(report.overall.tradeCount, 3);
    expect(report.overall.totalR, 3);
    expect(report.byStrategy.keys, containsAll(['A', 'B', 'C5']));
    expect(report.byStrategy, isNot(contains('TREND_PULLBACK')));
    expect(report.byStrategyAndSide['A']!['BUY']!.tradeCount, 1);
    expect(report.byStrategyAndSide['B']!['SELL']!.tradeCount, 1);
  });

  test('does not count unresolved or ambiguous result as a trade', () {
    final a = _signal('a', 'A', PaperSignalSide.buy, 1);
    final report = adapter.analyze(signals: [a], results: [_result(a, null)]);

    expect(report.overall.tradeCount, 0);
  });

  test('fails closed on orphan resolved result', () {
    final orphan = PaperTradeResult(
      signalId: 'missing',
      strategy: 'A',
      status: PaperSignalStatus.targetHit,
      resolvedAt: DateTime.utc(2026, 9, 19),
      grossR: 2,
    );

    expect(
      () => adapter.analyze(signals: const [], results: [orphan]),
      throwsStateError,
    );
  });
}

PaperSignal _signal(
  String id,
  String strategy,
  PaperSignalSide side,
  int minute,
) => PaperSignal(
  id: id,
  symbol: 'XAUUSD',
  strategy: strategy,
  side: side,
  observedAt: DateTime.utc(2026, 9, 19, 0, minute),
  entry: 3600,
  stopLoss: side == PaperSignalSide.buy ? 3590 : 3610,
  takeProfit: side == PaperSignalSide.buy ? 3620 : 3580,
  rewardRisk: 2,
  reason: 'test formal signal',
  status: PaperSignalStatus.triggered,
);

PaperTradeResult _result(PaperSignal signal, double? r) => PaperTradeResult(
  signalId: signal.id,
  strategy: signal.strategy,
  status: r == null
      ? PaperSignalStatus.ambiguous
      : r > 0
      ? PaperSignalStatus.targetHit
      : PaperSignalStatus.stopHit,
  resolvedAt: signal.observedAt.add(const Duration(minutes: 5)),
  grossR: r,
);
