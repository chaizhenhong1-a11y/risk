import 'package:technical_analysis/technical_analysis.dart';

enum KeyLevelQuality { unavailable, weak, established, wellTested }

final class KeyLevelQualityEvidence {
  const KeyLevelQualityEvidence({required this.quality});

  final KeyLevelQuality quality;

  bool get present =>
      quality == KeyLevelQuality.established ||
      quality == KeyLevelQuality.wellTested;
}

/// Converts Phase 3 level-strength facts into SOFT strategy evidence.
///
/// The baseline preserves the Phase 3 strength categories without assigning
/// numeric weights. Established and well-tested levels count as positive
/// quality evidence. Weak/untested levels simply provide no positive evidence
/// and never block an otherwise eligible setup.
final class KeyLevelQualityEvidenceEvaluator {
  const KeyLevelQualityEvidenceEvaluator();

  KeyLevelQualityEvidence evaluate({LevelStrength? levelStrength}) {
    if (levelStrength == null) {
      return const KeyLevelQualityEvidence(
        quality: KeyLevelQuality.unavailable,
      );
    }

    final quality = switch (levelStrength) {
      LevelStrength.untested => KeyLevelQuality.unavailable,
      LevelStrength.weak => KeyLevelQuality.weak,
      LevelStrength.established => KeyLevelQuality.established,
      LevelStrength.wellTested => KeyLevelQuality.wellTested,
    };

    return KeyLevelQualityEvidence(quality: quality);
  }
}
