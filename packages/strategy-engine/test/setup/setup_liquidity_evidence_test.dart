import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const evaluator = SetupEvaluator();

  test(
    'liquidity evidence enriches eligible setup without becoming a gate',
    () {
      final withLiquidity = evaluator.evaluate(
        bias: TradingBias.buy,
        pullback: _pullback(),
        confirmation: _waitingConfirmation(),
        liquidityEvidence: const [
          LiquidityEvidence(
            type: LiquidityEvidenceType.directionalLevelSweep,
            present: true,
          ),
          LiquidityEvidence(
            type: LiquidityEvidenceType.directionalPoolSweep,
            present: false,
          ),
        ],
      );

      expect(withLiquidity.isEligible, isTrue);
      expect(
        withLiquidity.hasEvidence(SetupEvidenceType.directionalLevelSweep),
        isTrue,
      );
      expect(
        withLiquidity.hasEvidence(SetupEvidenceType.directionalPoolSweep),
        isFalse,
      );
    },
  );

  test('missing all liquidity evidence does not block eligible setup', () {
    final withoutLiquidity = evaluator.evaluate(
      bias: TradingBias.buy,
      pullback: _pullback(),
      confirmation: _waitingConfirmation(),
    );

    expect(withoutLiquidity.isEligible, isTrue);
    expect(
      withoutLiquidity.hasEvidence(SetupEvidenceType.directionalLevelSweep),
      isFalse,
    );
    expect(
      withoutLiquidity.hasEvidence(SetupEvidenceType.directionalPoolSweep),
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
