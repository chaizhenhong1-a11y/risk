import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const evaluator = SetupEvaluator();

  test('aligned D1 context enriches eligible setup', () {
    final result = evaluator.evaluate(
      bias: TradingBias.buy,
      pullback: _pullback(),
      confirmation: _waitingConfirmation(),
      d1ContextEvidence: const D1ContextEvidence(
        alignment: D1ContextAlignment.aligned,
      ),
    );

    expect(result.isEligible, isTrue);
    expect(result.hasEvidence(SetupEvidenceType.directionalD1Context), isTrue);
  });

  test('opposed D1 context does not become a gate', () {
    final result = evaluator.evaluate(
      bias: TradingBias.buy,
      pullback: _pullback(),
      confirmation: _waitingConfirmation(),
      d1ContextEvidence: const D1ContextEvidence(
        alignment: D1ContextAlignment.opposed,
      ),
    );

    expect(result.isEligible, isTrue);
    expect(result.hasEvidence(SetupEvidenceType.directionalD1Context), isFalse);
  });

  test('missing D1 context does not block eligible setup', () {
    final result = evaluator.evaluate(
      bias: TradingBias.buy,
      pullback: _pullback(),
      confirmation: _waitingConfirmation(),
    );

    expect(result.isEligible, isTrue);
    expect(result.hasEvidence(SetupEvidenceType.directionalD1Context), isFalse);
  });
}

PullbackAnalysis _pullback() => PullbackAnalysis(
  state: PullbackState.inZone,
  reason: PullbackReason.priceAtSupport,
  matchedLevel: KeyLevel(
    type: KeyLevelType.support,
    source: KeyLevelSource.swingLow,
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
