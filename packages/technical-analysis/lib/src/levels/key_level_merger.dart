import 'key_level.dart';

/// Merges nearby active key levels of the same type into wider price zones.
///
/// The merge distance is explicit so TradeForge V2 does not hard-code an
/// uncalibrated XAUUSD distance before ATR/volatility work is complete.
final class KeyLevelMerger {
  const KeyLevelMerger();

  List<KeyLevel> merge(Iterable<KeyLevel> levels, {required double maxGap}) {
    if (!maxGap.isFinite || maxGap < 0) {
      throw ArgumentError.value(
        maxGap,
        'maxGap',
        'must be finite and non-negative',
      );
    }

    final sorted = levels.toList()
      ..sort((a, b) {
        final typeOrder = a.type.index.compareTo(b.type.index);
        if (typeOrder != 0) {
          return typeOrder;
        }
        return a.lowerBound.compareTo(b.lowerBound);
      });

    final merged = <KeyLevel>[];

    for (final level in sorted) {
      if (!level.isActive) {
        merged.add(level);
        continue;
      }

      final candidateIndex = _findMergeCandidate(merged, level, maxGap);
      if (candidateIndex == null) {
        merged.add(level);
        continue;
      }

      final candidate = merged[candidateIndex];
      merged[candidateIndex] = KeyLevel(
        type: candidate.type,
        source: candidate.source,
        status: KeyLevelStatus.active,
        lowerBound: candidate.lowerBound < level.lowerBound
            ? candidate.lowerBound
            : level.lowerBound,
        upperBound: candidate.upperBound > level.upperBound
            ? candidate.upperBound
            : level.upperBound,
        createdAtCandleIndex:
            candidate.createdAtCandleIndex < level.createdAtCandleIndex
            ? candidate.createdAtCandleIndex
            : level.createdAtCandleIndex,
      );
    }

    merged.sort(
      (a, b) => a.createdAtCandleIndex.compareTo(b.createdAtCandleIndex),
    );
    return List.unmodifiable(merged);
  }

  int? _findMergeCandidate(
    List<KeyLevel> merged,
    KeyLevel level,
    double maxGap,
  ) {
    for (var index = merged.length - 1; index >= 0; index--) {
      final candidate = merged[index];

      if (!candidate.isActive || candidate.type != level.type) {
        continue;
      }

      final gap = _gap(candidate, level);
      if (gap <= maxGap) {
        return index;
      }
    }
    return null;
  }

  double _gap(KeyLevel a, KeyLevel b) {
    if (a.upperBound < b.lowerBound) {
      return b.lowerBound - a.upperBound;
    }
    if (b.upperBound < a.lowerBound) {
      return a.lowerBound - b.upperBound;
    }
    return 0;
  }
}
