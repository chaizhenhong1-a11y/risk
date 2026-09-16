import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';

/// Status of Entry Zone planning.
///
/// An Entry Zone can only exist for an eligible directional setup with a
/// matched pullback level. This is planning data, not an execution instruction.
enum EntryZoneStatus { unavailable, available }

enum EntryZoneUnavailableReason { setupBlocked, noMatchedPullbackLevel }

/// Price area where the already-eligible setup may be considered.
///
/// TradeForge intentionally models a zone instead of inventing a single precise
/// entry price before execution logic exists.
final class EntryZone {
  const EntryZone({
    required this.lowerBound,
    required this.upperBound,
    required this.sourceLevel,
  });

  final double lowerBound;
  final double upperBound;
  final KeyLevel sourceLevel;

  double get midpoint => (lowerBound + upperBound) / 2;

  bool contains(double price) => price >= lowerBound && price <= upperBound;
}

final class EntryZoneAnalysis {
  const EntryZoneAnalysis._({
    required this.status,
    this.zone,
    this.unavailableReason,
  });

  const EntryZoneAnalysis.available(EntryZone zone)
    : this._(status: EntryZoneStatus.available, zone: zone);

  const EntryZoneAnalysis.unavailable(EntryZoneUnavailableReason reason)
    : this._(status: EntryZoneStatus.unavailable, unavailableReason: reason);

  final EntryZoneStatus status;
  final EntryZone? zone;
  final EntryZoneUnavailableReason? unavailableReason;

  bool get isAvailable => status == EntryZoneStatus.available;
}

/// Builds the first Risk Engine artifact from Phase 4 facts.
///
/// Baseline rule:
/// - blocked setup -> no Entry Zone
/// - eligible setup without a matched pullback level -> no Entry Zone
/// - eligible setup with a matched pullback level -> reuse that validated level
///   zone as the Entry Zone
///
/// No midpoint entry order, spread adjustment, ATR offset, SL, TP, RR, position
/// size, or execution decision is introduced here.
final class EntryZonePlanner {
  const EntryZonePlanner();

  EntryZoneAnalysis plan({
    required SetupEvidenceSnapshot snapshot,
    required PullbackAnalysis pullback,
  }) {
    if (!snapshot.isEligible) {
      return const EntryZoneAnalysis.unavailable(
        EntryZoneUnavailableReason.setupBlocked,
      );
    }

    final level = pullback.matchedLevel;
    if (level == null) {
      return const EntryZoneAnalysis.unavailable(
        EntryZoneUnavailableReason.noMatchedPullbackLevel,
      );
    }

    return EntryZoneAnalysis.available(
      EntryZone(
        lowerBound: level.lowerBound,
        upperBound: level.upperBound,
        sourceLevel: level,
      ),
    );
  }
}
