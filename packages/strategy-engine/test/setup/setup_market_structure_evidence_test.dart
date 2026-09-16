import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const setupEvaluator = SetupEvaluator();
  const structureEvaluator = MarketStructureEvidenceEvaluator();

  test('matching M15 structure enriches an eligible setup', () {
    final structureEvidence = structureEvaluator.evaluate(
      bias: TradingBias.buy,
      m15Structure: MarketStructure.bullish,
    );

    final result = setupEvaluator.evaluate(
      bias: TradingBias.buy,
      pullback: _pullback(),
      confirmation: _waitingConfirmation(),
      marketStructureEvidence: structureEvidence,
    );

    expect(result.isEligible, isTrue);
    expect(
      result.hasEvidence(SetupEvidenceType.directionalM15Structure),
      isTrue,
    );
  });

  test('missing M15 structure evidence does not become a gate', () {
    final structureEvidence = structureEvaluator.evaluate(
      bias: TradingBias.buy,
      m15Structure: MarketStructure.neutral,
    );

    final result = setupEvaluator.evaluate(
      bias: TradingBias.buy,
      pullback: _pullback(),
      confirmation: _waitingConfirmation(),
      marketStructureEvidence: structureEvidence,
    );

    expect(result.isEligible, isTrue);
    expect(
      result.hasEvidence(SetupEvidenceType.directionalM15Structure),
      isFalse,
    );
  });

  test('opposite M15 structure does not add evidence or block setup', () {
    final structureEvidence = structureEvaluator.evaluate(
      bias: TradingBias.buy,
      m15Structure: MarketStructure.bearish,
    );

    final result = setupEvaluator.evaluate(
      bias: TradingBias.buy,
      pullback: _pullback(),
      confirmation: _waitingConfirmation(),
      marketStructureEvidence: structureEvidence,
    );

    expect(result.isEligible, isTrue);
    expect(
      result.hasEvidence(SetupEvidenceType.directionalM15Structure),
      isFalse,
    );
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
