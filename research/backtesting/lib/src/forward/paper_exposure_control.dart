/// Downstream exposure classification for Paper Forward.
///
/// It never suppresses strategy discovery or mutates frozen strategy triggers.
/// Exact duplicate IDs are collapsed first. Distinct signals from the same
/// strategy + side that overlap an already-active signal remain visible, but
/// are not treated as independent execution/evidence. Cross-strategy overlap
/// remains independently observable and is flagged for portfolio review.
final class PaperExposureRecord {
  const PaperExposureRecord({
    required this.id,
    required this.strategy,
    required this.side,
    required this.observedAt,
    this.resolvedAt,
  });

  final String id;
  final String strategy;
  final String side;
  final DateTime observedAt;
  final DateTime? resolvedAt;
}

final class PaperExposureDecision {
  const PaperExposureDecision({
    required this.exposureStatus,
    required this.independentEvidence,
    required this.executionEligible,
    required this.portfolioOverlap,
    this.exposureGroupId,
    this.overlapsSignalId,
  });

  final String exposureStatus;
  final bool independentEvidence;
  final bool executionEligible;
  final bool portfolioOverlap;
  final String? exposureGroupId;
  final String? overlapsSignalId;
}

final class PaperExposureControl {
  const PaperExposureControl();

  Map<String, PaperExposureDecision> classify(
    Iterable<PaperExposureRecord> records,
  ) {
    // Exact deterministic-ID duplicates are not separate records.
    final byId = <String, PaperExposureRecord>{};
    for (final record in records) {
      byId[record.id] = record;
    }

    final ordered = byId.values.toList(growable: false)
      ..sort((a, b) {
        final time = a.observedAt.compareTo(b.observedAt);
        return time != 0 ? time : a.id.compareTo(b.id);
      });

    final decisions = <String, PaperExposureDecision>{};
    final acceptedRoots = <PaperExposureRecord>[];

    for (final current in ordered) {
      PaperExposureRecord? sameExposure;
      var portfolioOverlap = false;

      for (final active in acceptedRoots) {
        if (!_overlaps(active, current)) continue;
        if (active.side != current.side) continue;

        if (active.strategy == current.strategy) {
          sameExposure ??= active;
        } else {
          portfolioOverlap = true;
        }
      }

      if (sameExposure != null) {
        final rootDecision = decisions[sameExposure.id];
        decisions[current.id] = PaperExposureDecision(
          exposureStatus: 'same_exposure',
          independentEvidence: false,
          executionEligible: false,
          portfolioOverlap: portfolioOverlap,
          exposureGroupId: rootDecision?.exposureGroupId ?? sameExposure.id,
          overlapsSignalId: sameExposure.id,
        );
        continue;
      }

      acceptedRoots.add(current);
      decisions[current.id] = PaperExposureDecision(
        exposureStatus: portfolioOverlap ? 'portfolio_overlap' : 'independent',
        independentEvidence: true,
        executionEligible: true,
        portfolioOverlap: portfolioOverlap,
        exposureGroupId: current.id,
      );
    }

    return decisions;
  }

  bool _overlaps(PaperExposureRecord active, PaperExposureRecord current) {
    if (current.observedAt.isBefore(active.observedAt)) return false;
    final resolvedAt = active.resolvedAt;
    // Pending means the exposure is still active.
    return resolvedAt == null || current.observedAt.isBefore(resolvedAt);
  }
}
