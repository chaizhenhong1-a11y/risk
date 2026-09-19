import 'package:flutter_test/flutter_test.dart';
import 'package:tradeforge_mobile/src/domain/performance_view.dart';
import 'package:tradeforge_mobile/src/domain/signal_history_view.dart';

void main() {
  test('historical baseline remains separate and frozen', () {
    expect(historicalPerformanceBaseline, hasLength(3));
    expect(
      historicalPerformanceBaseline.map((item) => item.strategy).toSet(),
      {'A', 'B', 'C5'},
    );
    expect(
      historicalPerformanceBaseline
          .firstWhere((item) => item.strategy == 'A')
          .winRate,
      40.23,
    );
    expect(
      historicalPerformanceBaseline
          .firstWhere((item) => item.strategy == 'C5')
          .trades,
      108,
    );
  });

  test('same C5 exposure is counted only once in performance', () {
    final root = _signal(
      id: 'c5-root',
      observedAt: DateTime.utc(2026, 9, 19, 1),
      realizedR: 2,
    );
    final duplicate1 = _signal(
      id: 'c5-duplicate-1',
      observedAt: DateTime.utc(2026, 9, 19, 1, 5),
      realizedR: 2,
      exposureStatus: 'same_exposure',
      independentEvidence: false,
      exposureGroupId: 'c5-root',
    );
    final duplicate2 = _signal(
      id: 'c5-duplicate-2',
      observedAt: DateTime.utc(2026, 9, 19, 1, 10),
      realizedR: -1,
      exposureStatus: 'same_exposure',
      independentEvidence: false,
      exposureGroupId: 'c5-root',
    );

    final metrics = PerformanceMetricsView.fromHistory([
      root,
      duplicate1,
      duplicate2,
    ]);

    expect(metrics.trades, 1);
    expect(metrics.wins, 1);
    expect(metrics.losses, 0);
    expect(metrics.winRate, 100);
    expect(metrics.totalR, 2);
    expect(metrics.expectancyR, 2);
    expect(metrics.maxDrawdownR, 0);
  });

  test('independent portfolio overlap remains valid evidence', () {
    final metrics = PerformanceMetricsView.fromHistory([
      _signal(
        id: 'a',
        strategy: 'A',
        observedAt: DateTime.utc(2026, 9, 19, 2),
        realizedR: 2,
        exposureStatus: 'portfolio_overlap',
        independentEvidence: true,
      ),
      _signal(
        id: 'c5',
        observedAt: DateTime.utc(2026, 9, 19, 2, 1),
        realizedR: -1,
        exposureStatus: 'portfolio_overlap',
        independentEvidence: true,
      ),
    ]);

    expect(metrics.trades, 2);
    expect(metrics.wins, 1);
    expect(metrics.losses, 1);
    expect(metrics.winRate, 50);
    expect(metrics.totalR, 1);
  });

  test('non-independent evidence is excluded even if status is malformed', () {
    final metrics = PerformanceMetricsView.fromHistory([
      _signal(
        id: 'legacy-duplicate',
        observedAt: DateTime.utc(2026, 9, 19, 3),
        realizedR: 2,
        exposureStatus: 'independent',
        independentEvidence: false,
      ),
    ]);

    expect(metrics.trades, 0);
    expect(metrics.winRate, isNull);
    expect(metrics.totalR, 0);
  });
}

SignalHistoryView _signal({
  required String id,
  required DateTime observedAt,
  required double realizedR,
  String strategy = 'C5',
  String exposureStatus = 'independent',
  bool independentEvidence = true,
  String? exposureGroupId,
}) =>
    SignalHistoryView(
      id: id,
      source: 'production_forward',
      symbol: 'XAUUSD',
      strategy: strategy,
      side: 'BUY',
      observedAt: observedAt,
      entry: 4300,
      stopLoss: 4290,
      takeProfit: 4320,
      riskReward: 2,
      status: realizedR > 0
          ? SignalHistoryStatus.targetHit
          : SignalHistoryStatus.stopHit,
      realizedR: realizedR,
      exposureStatus: exposureStatus,
      independentEvidence: independentEvidence,
      exposureGroupId: exposureGroupId,
    );
