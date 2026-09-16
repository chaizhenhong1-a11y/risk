import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const classifier = MarketRegimeClassifier();
  const router = MarketRegimeRouter();
  const strategyA = StrategyRouteId.trendPullbackStructureConfirmation;
  const strategyB = StrategyRouteId.correctionContinuation;

  MarketRegimeAnalysis classify({
    required MarketStructure h4,
    required MarketStructure h1,
    bool rangeEvidencePresent = false,
  }) {
    return classifier.classify(
      h4Structure: h4,
      h1Structure: h1,
      rangeEvidencePresent: rangeEvidencePresent,
    );
  }

  group('MarketRegimeRouter', () {
    test('allows Strategy A in bullish aligned trend', () {
      final route = router.route(
        classify(h4: MarketStructure.bullish, h1: MarketStructure.bullish),
      );

      expect(route.regime, MarketRegime.trendAligned);
      expect(route.direction, MarketRegimeDirection.bullish);
      expect(route.hasEligibleStrategy, isTrue);
      expect(route.allows(strategyA), isTrue);
      expect(route.eligibleStrategies, {strategyA});
    });

    test('allows Strategy A in bearish aligned trend', () {
      final route = router.route(
        classify(h4: MarketStructure.bearish, h1: MarketStructure.bearish),
      );

      expect(route.regime, MarketRegime.trendAligned);
      expect(route.direction, MarketRegimeDirection.bearish);
      expect(route.allows(strategyA), isTrue);
    });

    test('routes only Strategy B into bullish correction regime', () {
      final route = router.route(
        classify(h4: MarketStructure.bullish, h1: MarketStructure.bearish),
      );

      expect(
        route.regime,
        MarketRegime.higherTimeframeTrendLowerTimeframeCorrection,
      );
      expect(route.direction, MarketRegimeDirection.bullish);
      expect(route.hasEligibleStrategy, isTrue);
      expect(route.allows(strategyA), isFalse);
      expect(route.allows(strategyB), isTrue);
      expect(route.eligibleStrategies, {strategyB});
    });

    test('routes only Strategy B into bearish correction regime', () {
      final route = router.route(
        classify(h4: MarketStructure.bearish, h1: MarketStructure.bullish),
      );

      expect(route.direction, MarketRegimeDirection.bearish);
      expect(route.allows(strategyA), isFalse);
      expect(route.allows(strategyB), isTrue);
    });

    test('does not route an unimplemented strategy into range', () {
      final route = router.route(
        classify(
          h4: MarketStructure.neutral,
          h1: MarketStructure.neutral,
          rangeEvidencePresent: true,
        ),
      );

      expect(route.regime, MarketRegime.range);
      expect(route.hasEligibleStrategy, isFalse);
    });

    test('transition remains unrouted', () {
      final route = router.route(
        classify(h4: MarketStructure.neutral, h1: MarketStructure.neutral),
      );

      expect(route.regime, MarketRegime.transition);
      expect(route.hasEligibleStrategy, isFalse);
    });

    test('unknown remains unrouted', () {
      final route = router.route(
        classify(h4: MarketStructure.unknown, h1: MarketStructure.neutral),
      );

      expect(route.regime, MarketRegime.unknown);
      expect(route.hasEligibleStrategy, isFalse);
    });

    test('route strategy set is immutable', () {
      final route = router.route(
        classify(h4: MarketStructure.bullish, h1: MarketStructure.bullish),
      );

      expect(() => route.eligibleStrategies.clear(), throwsUnsupportedError);
    });
  });
}
