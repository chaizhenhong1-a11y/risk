import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const evaluator = SetupEvaluator();

  test('established key-level quality enriches eligible setup', () {
    final result = evaluator.evaluate(
      bias: TradingBias.buy,
      pullback: _pullback(),
      confirmation: _waitingConfirmation(),
      keyLevelQualityEvidence: const KeyLevelQualityEvidence(
        quality: KeyLevelQuality.established,
      ),
    );

    expect(result.isEligible, isTrue);
    expect(result.hasEvidence(SetupEvidenceType.keyLevelQuality), isTrue);
  });

  test('well-tested key-level quality enriches eligible setup', () {
    final result = evaluator.evaluate(
      bias: TradingBias.buy,
      pullback: _pullback(),
      confirmation: _waitingConfirmation(),
      keyLevelQualityEvidence: const KeyLevelQualityEvidence(
        quality: KeyLevelQuality.wellTested,
      ),
    );

    expect(result.isEligible, isTrue);
    expect(result.hasEvidence(SetupEvidenceType.keyLevelQuality), isTrue);
  });

  test('weak key level does not block otherwise eligible setup', () {
    final result = evaluator.evaluate(
      bias: TradingBias.buy,
      pullback: _pullback(),
      confirmation: _waitingConfirmation(),
      keyLevelQualityEvidence: const KeyLevelQualityEvidence(
        quality: KeyLevelQuality.weak,
      ),
    );

    expect(result.isEligible, isTrue);
    expect(result.hasEvidence(SetupEvidenceType.keyLevelQuality), isFalse);
  });

  test('missing key-level quality does not become a gate', () {
    final result = evaluator.evaluate(
      bias: TradingBias.buy,
      pullback: _pullback(),
      confirmation: _waitingConfirmation(),
    );

    expect(result.isEligible, isTrue);
    expect(result.hasEvidence(SetupEvidenceType.keyLevelQuality), isFalse);
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
