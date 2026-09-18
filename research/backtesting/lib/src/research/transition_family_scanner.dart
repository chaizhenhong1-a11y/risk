enum CachedStructure { bullish, bearish, neutral, unknown }

enum TransitionFamily {
  h4BullishH1Neutral,
  h4BearishH1Neutral,
  h4NeutralH1Bullish,
  h4NeutralH1Bearish,
  h4NeutralH1Neutral,
}

final class TransitionFamilyCount {
  const TransitionFamilyCount({
    required this.family,
    required this.observations,
  });

  final TransitionFamily family;
  final int observations;
}

final class TransitionFamilyScanner {
  const TransitionFamilyScanner();

  TransitionFamily? classify({
    required CachedStructure h4,
    required CachedStructure h1,
  }) => switch ((h4, h1)) {
    (CachedStructure.bullish, CachedStructure.neutral) =>
      TransitionFamily.h4BullishH1Neutral,
    (CachedStructure.bearish, CachedStructure.neutral) =>
      TransitionFamily.h4BearishH1Neutral,
    (CachedStructure.neutral, CachedStructure.bullish) =>
      TransitionFamily.h4NeutralH1Bullish,
    (CachedStructure.neutral, CachedStructure.bearish) =>
      TransitionFamily.h4NeutralH1Bearish,
    (CachedStructure.neutral, CachedStructure.neutral) =>
      TransitionFamily.h4NeutralH1Neutral,
    _ => null,
  };

  List<TransitionFamilyCount> rank(
    Iterable<(CachedStructure, CachedStructure)> observations,
  ) {
    final counts = <TransitionFamily, int>{
      for (final family in TransitionFamily.values) family: 0,
    };

    for (final (h4, h1) in observations) {
      final family = classify(h4: h4, h1: h1);
      if (family != null) counts[family] = counts[family]! + 1;
    }

    final result = [
      for (final entry in counts.entries)
        TransitionFamilyCount(family: entry.key, observations: entry.value),
    ]..sort((a, b) => b.observations.compareTo(a.observations));

    return result;
  }
}
