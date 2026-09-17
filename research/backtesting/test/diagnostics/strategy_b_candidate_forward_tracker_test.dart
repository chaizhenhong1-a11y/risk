import 'package:market_models/market_models.dart';
import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  test(
    'forward tracker excludes candidate candle and labels later continuation',
    () {
      final tracker = StrategyBCandidateForwardTracker(horizonsM5: const [2]);
      tracker.registerCandidate(
        direction: StrategyBCandidateDirection.buy,
        referencePrice: 100,
        atr: 10,
        rawRiskReward: 2.2,
        targetRoomAtr: 2.0,
        pullbackDepthAtr: null,
        atrRelativeToMedian: 1.0,
        riskEligible: true,
      );

      tracker.observeLaterCandle(_candle(101, 109, 99, 105));
      expect(tracker.diagnosticsByHorizon[2]!.candidateCount, 0);
      tracker.observeLaterCandle(_candle(105, 111, 104, 110));

      final sample = tracker.diagnosticsByHorizon[2]!.samples.single;
      expect(sample.outcome, StrategyBCandidateOutcome.continuation);
    },
  );

  test('same-candle favorable/adverse barrier conflict stays unresolved', () {
    final tracker = StrategyBCandidateForwardTracker(horizonsM5: const [1]);
    tracker.registerCandidate(
      direction: StrategyBCandidateDirection.buy,
      referencePrice: 100,
      atr: 10,
      rawRiskReward: 1.0,
      targetRoomAtr: 1.0,
      pullbackDepthAtr: null,
      atrRelativeToMedian: 1.0,
      riskEligible: false,
    );
    tracker.observeLaterCandle(_candle(100, 111, 89, 100));
    expect(
      tracker.diagnosticsByHorizon[1]!.samples.single.outcome,
      StrategyBCandidateOutcome.unresolved,
    );
  });
}

Candle _candle(double open, double high, double low, double close) => Candle(
  openTime: DateTime(2026, 1, 1),
  closeTime: DateTime(2026, 1, 1, 0, 5),
  open: open,
  high: high,
  low: low,
  close: close,
  volume: 1,
);
