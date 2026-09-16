import 'package:risk_engine/risk_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const evaluator = RiskEligibilityEvaluator();
  const rrCalculator = RiskRewardCalculator();
  const rrGate = MinimumRiskRewardGate();

  group('RiskEligibilityEvaluator', () {
    test('eligible when all risk components are valid and RR gate passes', () {
      final fixture = _fixture(
        entry: 2300,
        stop: 2295,
        target: 2310,
        minimumRr: 2,
      );

      final result = evaluator.evaluate(
        entryZoneAnalysis: fixture.entryZone,
        protectiveStopAnalysis: fixture.protectiveStop,
        targetAnalysis: fixture.target,
        riskRewardAnalysis: fixture.riskReward,
        minimumRiskRewardGateResult: fixture.rrGate,
      );

      expect(result.isEligible, isTrue);
      expect(result.blockReason, isNull);
      expect(result.riskReward!.ratio, 2);
      expect(result.minimumRiskReward, 2);
    });

    test('entry-zone failure is reported first', () {
      final fixture = _fixture();

      final result = evaluator.evaluate(
        entryZoneAnalysis: const EntryZoneAnalysis.unavailable(
          EntryZoneUnavailableReason.setupBlocked,
        ),
        protectiveStopAnalysis: fixture.protectiveStop,
        targetAnalysis: fixture.target,
        riskRewardAnalysis: fixture.riskReward,
        minimumRiskRewardGateResult: fixture.rrGate,
      );

      expect(result.isEligible, isFalse);
      expect(
        result.blockReason,
        RiskEligibilityBlockReason.entryZoneUnavailable,
      );
    });

    test('protective-stop failure blocks risk eligibility', () {
      final fixture = _fixture();

      final result = evaluator.evaluate(
        entryZoneAnalysis: fixture.entryZone,
        protectiveStopAnalysis: const ProtectiveStopAnalysis.unavailable(
          ProtectiveStopUnavailableReason.noStructuralStop,
        ),
        targetAnalysis: fixture.target,
        riskRewardAnalysis: fixture.riskReward,
        minimumRiskRewardGateResult: fixture.rrGate,
      );

      expect(result.isEligible, isFalse);
      expect(
        result.blockReason,
        RiskEligibilityBlockReason.protectiveStopUnavailable,
      );
    });

    test('missing target blocks risk eligibility', () {
      final fixture = _fixture();

      final result = evaluator.evaluate(
        entryZoneAnalysis: fixture.entryZone,
        protectiveStopAnalysis: fixture.protectiveStop,
        targetAnalysis: const TargetCandidateAnalysis.unavailable(
          TargetCandidateUnavailableReason.noOpposingActiveLevelAhead,
        ),
        riskRewardAnalysis: fixture.riskReward,
        minimumRiskRewardGateResult: fixture.rrGate,
      );

      expect(result.isEligible, isFalse);
      expect(result.blockReason, RiskEligibilityBlockReason.targetUnavailable);
    });

    test('invalid RR blocks before minimum-RR comparison', () {
      final fixture = _fixture();
      final invalid = rrCalculator.calculate(
        bias: TradingBias.buy,
        entryPrice: 2300,
        stopPrice: 2301,
        targetPrice: 2310,
      );
      final invalidGate = rrGate.evaluate(
        analysis: invalid,
        policy: MinimumRiskRewardPolicy(2),
      );

      final result = evaluator.evaluate(
        entryZoneAnalysis: fixture.entryZone,
        protectiveStopAnalysis: fixture.protectiveStop,
        targetAnalysis: fixture.target,
        riskRewardAnalysis: invalid,
        minimumRiskRewardGateResult: invalidGate,
      );

      expect(result.isEligible, isFalse);
      expect(result.blockReason, RiskEligibilityBlockReason.invalidRiskReward);
    });

    test('below-minimum RR blocks while preserving measured RR', () {
      final fixture = _fixture(
        entry: 2300,
        stop: 2295,
        target: 2308,
        minimumRr: 2,
      );

      final result = evaluator.evaluate(
        entryZoneAnalysis: fixture.entryZone,
        protectiveStopAnalysis: fixture.protectiveStop,
        targetAnalysis: fixture.target,
        riskRewardAnalysis: fixture.riskReward,
        minimumRiskRewardGateResult: fixture.rrGate,
      );

      expect(result.isEligible, isFalse);
      expect(
        result.blockReason,
        RiskEligibilityBlockReason.belowMinimumRiskReward,
      );
      expect(result.riskReward!.ratio, 1.6);
      expect(result.minimumRiskReward, 2);
    });
  });
}

_RiskFixture _fixture({
  double entry = 2300,
  double stop = 2295,
  double target = 2310,
  double minimumRr = 2,
}) {
  final support = KeyLevel(
    type: KeyLevelType.support,
    source: KeyLevelSource.swingLow,
    status: KeyLevelStatus.active,
    lowerBound: 2299,
    upperBound: 2301,
    createdAtCandleIndex: 10,
  );
  final resistance = KeyLevel(
    type: KeyLevelType.resistance,
    source: KeyLevelSource.swingHigh,
    status: KeyLevelStatus.active,
    lowerBound: target,
    upperBound: target + 2,
    createdAtCandleIndex: 12,
  );

  final entryZone = EntryZoneAnalysis.available(
    EntryZone(
      lowerBound: support.lowerBound,
      upperBound: support.upperBound,
      sourceLevel: support,
    ),
  );

  final structural = StructuralStop(
    price: support.lowerBound,
    bias: TradingBias.buy,
    sourceLevel: support,
  );
  final protective = ProtectiveStopAnalysis.available(
    ProtectiveStop(
      price: stop,
      structuralBoundary: structural.price,
      bufferDistance: structural.price - stop,
      bias: TradingBias.buy,
    ),
  );

  final targetAnalysis = TargetCandidateAnalysis.available(
    TargetCandidate(
      price: target,
      bias: TradingBias.buy,
      sourceLevel: resistance,
    ),
  );

  final riskReward = rrCalculator.calculate(
    bias: TradingBias.buy,
    entryPrice: entry,
    stopPrice: stop,
    targetPrice: target,
  );
  final gate = rrGate.evaluate(
    analysis: riskReward,
    policy: MinimumRiskRewardPolicy(minimumRr),
  );

  return _RiskFixture(
    entryZone: entryZone,
    protectiveStop: protective,
    target: targetAnalysis,
    riskReward: riskReward,
    rrGate: gate,
  );
}

const rrCalculator = RiskRewardCalculator();
const rrGate = MinimumRiskRewardGate();

final class _RiskFixture {
  const _RiskFixture({
    required this.entryZone,
    required this.protectiveStop,
    required this.target,
    required this.riskReward,
    required this.rrGate,
  });

  final EntryZoneAnalysis entryZone;
  final ProtectiveStopAnalysis protectiveStop;
  final TargetCandidateAnalysis target;
  final RiskRewardAnalysis riskReward;
  final MinimumRiskRewardGateResult rrGate;
}
