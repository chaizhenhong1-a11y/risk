import 'package:risk_engine/risk_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';
import 'package:test/test.dart';

void main() {
  const planner = EntryZonePlanner();

  group('EntryZonePlanner', () {
    test('reuses matched support zone for eligible BUY setup', () {
      final level = _support();

      final result = planner.plan(
        snapshot: _eligibleSnapshot(),
        pullback: PullbackAnalysis(
          state: PullbackState.inZone,
          reason: PullbackReason.priceAtSupport,
          matchedLevel: level,
        ),
      );

      expect(result.isAvailable, isTrue);
      expect(result.unavailableReason, isNull);
      expect(result.zone!.lowerBound, 2299);
      expect(result.zone!.upperBound, 2301);
      expect(result.zone!.midpoint, 2300);
      expect(result.zone!.sourceLevel, same(level));
      expect(result.zone!.contains(2299), isTrue);
      expect(result.zone!.contains(2301), isTrue);
      expect(result.zone!.contains(2301.01), isFalse);
    });

    test('reuses matched resistance zone for eligible SELL setup', () {
      final level = _resistance();

      final result = planner.plan(
        snapshot: _eligibleSnapshot(),
        pullback: PullbackAnalysis(
          state: PullbackState.inZone,
          reason: PullbackReason.priceAtResistance,
          matchedLevel: level,
        ),
      );

      expect(result.isAvailable, isTrue);
      expect(result.zone!.lowerBound, 2305);
      expect(result.zone!.upperBound, 2307);
      expect(result.zone!.sourceLevel, same(level));
    });

    test('blocked setup cannot receive an Entry Zone', () {
      final result = planner.plan(
        snapshot: SetupEvidenceSnapshot(
          eligibility: SetupEligibility.blocked,
          blockReason: SetupBlockReason.noTradeBias,
          evidence: const [],
          d1ContextAlignment: D1ContextAlignment.unavailable,
          keyLevelQuality: KeyLevelQuality.unavailable,
        ),
        pullback: PullbackAnalysis(
          state: PullbackState.inZone,
          reason: PullbackReason.priceAtSupport,
          matchedLevel: _support(),
        ),
      );

      expect(result.isAvailable, isFalse);
      expect(result.unavailableReason, EntryZoneUnavailableReason.setupBlocked);
      expect(result.zone, isNull);
    });

    test('eligible setup without matched pullback level stays unavailable', () {
      final result = planner.plan(
        snapshot: _eligibleSnapshot(),
        pullback: const PullbackAnalysis(
          state: PullbackState.waiting,
          reason: PullbackReason.priceNotAtDirectionalLevel,
        ),
      );

      expect(result.isAvailable, isFalse);
      expect(
        result.unavailableReason,
        EntryZoneUnavailableReason.noMatchedPullbackLevel,
      );
      expect(result.zone, isNull);
    });
  });
}

SetupEvidenceSnapshot _eligibleSnapshot() => SetupEvidenceSnapshot(
  eligibility: SetupEligibility.eligible,
  blockReason: null,
  evidence: const [],
  d1ContextAlignment: D1ContextAlignment.unavailable,
  keyLevelQuality: KeyLevelQuality.unavailable,
);

KeyLevel _support() => KeyLevel(
  type: KeyLevelType.support,
  source: KeyLevelSource.swingLow,
  status: KeyLevelStatus.active,
  lowerBound: 2299,
  upperBound: 2301,
  createdAtCandleIndex: 10,
);

KeyLevel _resistance() => KeyLevel(
  type: KeyLevelType.resistance,
  source: KeyLevelSource.swingHigh,
  status: KeyLevelStatus.active,
  lowerBound: 2305,
  upperBound: 2307,
  createdAtCandleIndex: 12,
);
