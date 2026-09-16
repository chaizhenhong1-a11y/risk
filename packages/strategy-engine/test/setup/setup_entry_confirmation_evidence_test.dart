import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const evaluator = SetupEvaluator();

  test('M5 confirmation enriches an eligible setup', () {
    final result = evaluator.evaluate(
      bias: TradingBias.buy,
      pullback: _pullback(),
      confirmation: _waitingConfirmation(),
      entryConfirmationEvidence: const EntryConfirmationEvidence(
        type: EntryConfirmationEvidenceType.directionalM5Confirmation,
        present: true,
      ),
    );

    expect(result.isEligible, isTrue);
    expect(
      result.hasEvidence(SetupEvidenceType.directionalM5Confirmation),
      isTrue,
    );
  });

  test('missing M5 confirmation does not block an eligible setup', () {
    final result = evaluator.evaluate(
      bias: TradingBias.buy,
      pullback: _pullback(),
      confirmation: _waitingConfirmation(),
    );

    expect(result.isEligible, isTrue);
    expect(
      result.hasEvidence(SetupEvidenceType.directionalM5Confirmation),
      isFalse,
    );
  });

  test('negative M5 confirmation remains soft evidence only', () {
    final result = evaluator.evaluate(
      bias: TradingBias.sell,
      pullback: _pullback(type: KeyLevelType.resistance),
      confirmation: _waitingConfirmation(),
      entryConfirmationEvidence: const EntryConfirmationEvidence(
        type: EntryConfirmationEvidenceType.directionalM5Confirmation,
        present: false,
      ),
    );

    expect(result.isEligible, isTrue);
    expect(
      result.hasEvidence(SetupEvidenceType.directionalM5Confirmation),
      isFalse,
    );
  });
}

PullbackAnalysis _pullback({KeyLevelType type = KeyLevelType.support}) =>
    PullbackAnalysis(
      state: PullbackState.inZone,
      reason: type == KeyLevelType.support
          ? PullbackReason.priceAtSupport
          : PullbackReason.priceAtResistance,
      matchedLevel: KeyLevel(
        type: type,
        source: type == KeyLevelType.support
            ? KeyLevelSource.swingLow
            : KeyLevelSource.swingHigh,
        status: KeyLevelStatus.active,
        lowerBound: 3249,
        upperBound: 3251,
        createdAtCandleIndex: 10,
      ),
    );

PullbackConfirmation _waitingConfirmation() => const PullbackConfirmation(
  state: PullbackConfirmationState.waiting,
  reason: PullbackConfirmationReason.waitingForBullishRejection,
);
