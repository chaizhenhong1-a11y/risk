import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const evaluator = SetupEvaluator();

  group('SetupEvaluator', () {
    test('directional bias + pullback makes setup eligible', () {
      final result = evaluator.evaluate(
        bias: TradingBias.buy,
        pullback: _pullback(),
        confirmation: _waitingConfirmation(),
      );

      expect(result.eligibility, SetupEligibility.eligible);
      expect(result.blockReason, isNull);
      expect(result.isEligible, isTrue);
      expect(result.hasEvidence(SetupEvidenceType.directionalBias), isTrue);
      expect(
        result.hasEvidence(SetupEvidenceType.pullbackAtDirectionalLevel),
        isTrue,
      );
    });

    test('missing rejection confirmation does not block setup', () {
      final result = evaluator.evaluate(
        bias: TradingBias.buy,
        pullback: _pullback(),
        confirmation: _waitingConfirmation(),
      );

      expect(result.isEligible, isTrue);
      expect(
        result.hasEvidence(SetupEvidenceType.rejectionConfirmation),
        isFalse,
      );
      expect(result.presentEvidenceCount, 2);
    });

    test('confirmed rejection adds evidence without changing eligibility', () {
      final result = evaluator.evaluate(
        bias: TradingBias.sell,
        pullback: _pullback(type: KeyLevelType.resistance),
        confirmation: _confirmedConfirmation(),
      );

      expect(result.isEligible, isTrue);
      expect(
        result.hasEvidence(SetupEvidenceType.rejectionConfirmation),
        isTrue,
      );
      expect(result.presentEvidenceCount, 3);
    });

    test('NO TRADE bias remains a hard block', () {
      final result = evaluator.evaluate(
        bias: TradingBias.noTrade,
        pullback: _pullback(),
        confirmation: _confirmedConfirmation(),
      );

      expect(result.eligibility, SetupEligibility.blocked);
      expect(result.blockReason, SetupBlockReason.noTradeBias);
      expect(result.isEligible, isFalse);
    });

    test('missing pullback remains a hard block', () {
      final result = evaluator.evaluate(
        bias: TradingBias.buy,
        pullback: const PullbackAnalysis(
          state: PullbackState.waiting,
          reason: PullbackReason.priceNotAtDirectionalLevel,
        ),
        confirmation: _waitingConfirmation(),
      );

      expect(result.eligibility, SetupEligibility.blocked);
      expect(result.blockReason, SetupBlockReason.pullbackNotPresent);
    });

    test('evidence collection is unmodifiable', () {
      final result = evaluator.evaluate(
        bias: TradingBias.buy,
        pullback: _pullback(),
        confirmation: _confirmedConfirmation(),
      );

      expect(
        () => result.evidence.add(
          const SetupEvidence(
            type: SetupEvidenceType.rejectionConfirmation,
            present: true,
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });
}

PullbackAnalysis _pullback({KeyLevelType type = KeyLevelType.support}) {
  final level = KeyLevel(
    type: type,
    source: type == KeyLevelType.support
        ? KeyLevelSource.swingLow
        : KeyLevelSource.swingHigh,
    status: KeyLevelStatus.active,
    lowerBound: 3249,
    upperBound: 3251,
    createdAtCandleIndex: 10,
  );

  return PullbackAnalysis(
    state: PullbackState.inZone,
    reason: type == KeyLevelType.support
        ? PullbackReason.priceAtSupport
        : PullbackReason.priceAtResistance,
    matchedLevel: level,
  );
}

PullbackConfirmation _waitingConfirmation() => const PullbackConfirmation(
  state: PullbackConfirmationState.waiting,
  reason: PullbackConfirmationReason.waitingForBullishRejection,
);

PullbackConfirmation _confirmedConfirmation() => const PullbackConfirmation(
  state: PullbackConfirmationState.confirmed,
  reason: PullbackConfirmationReason.bullishRejectionConfirmed,
);
