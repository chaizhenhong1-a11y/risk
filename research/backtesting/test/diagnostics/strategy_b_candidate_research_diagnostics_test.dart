import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  group('StrategyBCandidateResearchDiagnostics', () {
    test('keeps the frozen 2.0 RR boundary visible in target-room buckets', () {
      final diagnostics = StrategyBCandidateResearchDiagnostics();
      for (final rr in [1.49, 1.50, 1.99, 2.00, 2.49, 2.50, 2.99, 3.00]) {
        diagnostics.add(_sample(rr: rr, eligible: rr >= 2.0));
      }

      final buckets = diagnostics.summarizeTargetRoom();
      expect(
        buckets[StrategyBTargetRoomBucket.belowOnePointFiveR]!.candidates,
        1,
      );
      expect(
        buckets[StrategyBTargetRoomBucket.onePointFiveToTwoR]!.candidates,
        2,
      );
      expect(
        buckets[StrategyBTargetRoomBucket.twoToTwoPointFiveR]!.candidates,
        2,
      );
      expect(
        buckets[StrategyBTargetRoomBucket.twoPointFiveToThreeR]!.candidates,
        2,
      );
      expect(buckets[StrategyBTargetRoomBucket.atLeastThreeR]!.candidates, 1);
      expect(diagnostics.riskEligibleCount, 5);
    });

    test(
      'separates pullback depth and volatility without changing eligibility',
      () {
        final diagnostics = StrategyBCandidateResearchDiagnostics()
          ..add(_sample(rr: 2.2, eligible: true, pullback: 0.3, atrRatio: 0.7))
          ..add(_sample(rr: 2.4, eligible: true, pullback: 0.8, atrRatio: 1.0))
          ..add(
            _sample(rr: 1.8, eligible: false, pullback: 1.2, atrRatio: 1.4),
          );

        final pullbacks = diagnostics.summarizePullbackDepth();
        final volatility = diagnostics.summarizeVolatility();
        expect(pullbacks[StrategyBPullbackDepthBucket.shallow]!.candidates, 1);
        expect(pullbacks[StrategyBPullbackDepthBucket.moderate]!.candidates, 1);
        expect(pullbacks[StrategyBPullbackDepthBucket.deep]!.candidates, 1);
        expect(volatility[StrategyBVolatilityBucket.compressed]!.candidates, 1);
        expect(volatility[StrategyBVolatilityBucket.normal]!.candidates, 1);
        expect(volatility[StrategyBVolatilityBucket.expanded]!.candidates, 1);
        expect(diagnostics.riskEligibleCount, 2);
      },
    );

    test('reports continuation only from resolved research labels', () {
      final diagnostics = StrategyBCandidateResearchDiagnostics()
        ..add(
          _sample(
            rr: 2.2,
            eligible: true,
            outcome: StrategyBCandidateOutcome.continuation,
          ),
        )
        ..add(
          _sample(
            rr: 2.3,
            eligible: true,
            outcome: StrategyBCandidateOutcome.rejection,
          ),
        )
        ..add(
          _sample(
            rr: 2.4,
            eligible: true,
            outcome: StrategyBCandidateOutcome.unresolved,
          ),
        );

      final summary = diagnostics
          .summarizeTargetRoom()[StrategyBTargetRoomBucket.twoToTwoPointFiveR]!;
      expect(summary.candidates, 3);
      expect(summary.continuation, 1);
      expect(summary.rejection, 1);
      expect(summary.unresolved, 1);
      expect(summary.resolvedContinuationRate, 0.5);
    });
  });
}

StrategyBCandidateResearchSample _sample({
  required double rr,
  required bool eligible,
  double? pullback,
  double? atrRatio,
  StrategyBCandidateOutcome outcome = StrategyBCandidateOutcome.unresolved,
}) => StrategyBCandidateResearchSample(
  direction: StrategyBCandidateDirection.buy,
  rawRiskReward: rr,
  targetRoomAtr: rr * 0.8,
  pullbackDepthAtr: pullback,
  atrRelativeToMedian: atrRatio,
  riskEligible: eligible,
  outcome: outcome,
);
