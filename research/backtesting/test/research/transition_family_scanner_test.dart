import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/research/transition_family_scanner.dart';

void main() {
  const scanner = TransitionFamilyScanner();

  test('classifies all five transition structure families', () {
    expect(
      scanner.classify(
        h4: CachedStructure.bullish,
        h1: CachedStructure.neutral,
      ),
      TransitionFamily.h4BullishH1Neutral,
    );
    expect(
      scanner.classify(
        h4: CachedStructure.bearish,
        h1: CachedStructure.neutral,
      ),
      TransitionFamily.h4BearishH1Neutral,
    );
    expect(
      scanner.classify(
        h4: CachedStructure.neutral,
        h1: CachedStructure.bullish,
      ),
      TransitionFamily.h4NeutralH1Bullish,
    );
    expect(
      scanner.classify(
        h4: CachedStructure.neutral,
        h1: CachedStructure.bearish,
      ),
      TransitionFamily.h4NeutralH1Bearish,
    );
    expect(
      scanner.classify(
        h4: CachedStructure.neutral,
        h1: CachedStructure.neutral,
      ),
      TransitionFamily.h4NeutralH1Neutral,
    );
  });

  test('does not misclassify trend or correction as transition', () {
    expect(
      scanner.classify(
        h4: CachedStructure.bullish,
        h1: CachedStructure.bullish,
      ),
      isNull,
    );
    expect(
      scanner.classify(
        h4: CachedStructure.bullish,
        h1: CachedStructure.bearish,
      ),
      isNull,
    );
  });

  test('ranks families by cached observation count', () {
    final ranked = scanner.rank(const [
      (CachedStructure.neutral, CachedStructure.neutral),
      (CachedStructure.bullish, CachedStructure.neutral),
      (CachedStructure.neutral, CachedStructure.neutral),
    ]);

    expect(ranked.first.family, TransitionFamily.h4NeutralH1Neutral);
    expect(ranked.first.observations, 2);
  });
}
