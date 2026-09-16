import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const evaluator = LiquidityEvidenceEvaluator();

  group('LiquidityEvidenceEvaluator', () {
    test('BUY recognizes support sweep as directional evidence', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.buy,
        analysis: _analysis(
          levelSweeps: [
            LiquiditySweep(
              direction: LiquiditySweepDirection.belowSupport,
              level: _support(),
              extremePrice: 3248,
              closePrice: 3250,
            ),
          ],
        ),
      );

      expect(
        _present(evidence, LiquidityEvidenceType.directionalLevelSweep),
        isTrue,
      );
    });

    test('BUY recognizes equal-low pool sweep as directional evidence', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.buy,
        analysis: _analysis(
          poolSweeps: [
            LiquidityPoolSweep(
              direction: LiquidityPoolSweepDirection.belowEqualLows,
              pool: _pool(LiquidityPoolType.equalLows),
              extremePrice: 3248,
              closePrice: 3250,
            ),
          ],
        ),
      );

      expect(
        _present(evidence, LiquidityEvidenceType.directionalPoolSweep),
        isTrue,
      );
    });

    test('BUY ignores bearish-side liquidity evidence', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.buy,
        analysis: _analysis(
          levelSweeps: [
            LiquiditySweep(
              direction: LiquiditySweepDirection.aboveResistance,
              level: _resistance(),
              extremePrice: 3302,
              closePrice: 3300,
            ),
          ],
          poolSweeps: [
            LiquidityPoolSweep(
              direction: LiquidityPoolSweepDirection.aboveEqualHighs,
              pool: _pool(LiquidityPoolType.equalHighs),
              extremePrice: 3302,
              closePrice: 3300,
            ),
          ],
        ),
      );

      expect(evidence.every((item) => !item.present), isTrue);
    });

    test('SELL recognizes resistance and equal-high sweeps', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.sell,
        analysis: _analysis(
          levelSweeps: [
            LiquiditySweep(
              direction: LiquiditySweepDirection.aboveResistance,
              level: _resistance(),
              extremePrice: 3302,
              closePrice: 3300,
            ),
          ],
          poolSweeps: [
            LiquidityPoolSweep(
              direction: LiquidityPoolSweepDirection.aboveEqualHighs,
              pool: _pool(LiquidityPoolType.equalHighs),
              extremePrice: 3302,
              closePrice: 3300,
            ),
          ],
        ),
      );

      expect(evidence.every((item) => item.present), isTrue);
    });

    test('NO TRADE has no directional liquidity evidence', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.noTrade,
        analysis: _analysis(),
      );

      expect(evidence.every((item) => !item.present), isTrue);
    });

    test('result is unmodifiable for directional bias', () {
      final evidence = evaluator.evaluate(
        bias: TradingBias.buy,
        analysis: _analysis(),
      );

      expect(
        () => evidence.add(
          const LiquidityEvidence(
            type: LiquidityEvidenceType.directionalLevelSweep,
            present: true,
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });
}

bool _present(
  Iterable<LiquidityEvidence> evidence,
  LiquidityEvidenceType type,
) => evidence.any((item) => item.type == type && item.present);

LevelLiquidityAnalysis _analysis({
  List<LiquiditySweep> levelSweeps = const [],
  List<LiquidityPoolSweep> poolSweeps = const [],
}) => LevelLiquidityAnalysis(
  keyLevels: const [],
  liquidityPools: const [],
  levelSweeps: levelSweeps,
  poolSweeps: poolSweeps,
);

KeyLevel _support() => KeyLevel(
  type: KeyLevelType.support,
  source: KeyLevelSource.swingLow,
  status: KeyLevelStatus.active,
  lowerBound: 3249,
  upperBound: 3251,
  createdAtCandleIndex: 10,
);

KeyLevel _resistance() => KeyLevel(
  type: KeyLevelType.resistance,
  source: KeyLevelSource.swingHigh,
  status: KeyLevelStatus.active,
  lowerBound: 3299,
  upperBound: 3301,
  createdAtCandleIndex: 20,
);

LiquidityPool _pool(LiquidityPoolType type) => LiquidityPool(
  type: type,
  lowerBound: type == LiquidityPoolType.equalLows ? 3249 : 3299,
  upperBound: type == LiquidityPoolType.equalLows ? 3251 : 3301,
  swingCandleIndexes: const [10, 20],
);
