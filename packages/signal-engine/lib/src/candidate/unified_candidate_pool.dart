enum UnifiedStrategySource { strategyA, strategyB, strategyC5 }

enum UnifiedCandidateDirection { buy, sell }

enum UnifiedCandidatePoolDisposition { accepted, merged, conflict }

final class UnifiedSignalCandidate {
  UnifiedSignalCandidate({
    required this.symbol,
    required this.observedAt,
    required this.direction,
    required this.source,
    required this.entryPrice,
    required this.stopLoss,
    required this.takeProfit,
    required this.riskReward,
    required Iterable<String> evidence,
  }) : evidence = List.unmodifiable(evidence) {
    if (symbol.trim().isEmpty) {
      throw ArgumentError.value(symbol, 'symbol', 'Symbol cannot be empty.');
    }
    for (final value in [entryPrice, stopLoss, takeProfit, riskReward]) {
      if (!value.isFinite) {
        throw ArgumentError('Candidate prices and RR must be finite.');
      }
    }
    if (riskReward <= 0) {
      throw ArgumentError.value(
        riskReward,
        'riskReward',
        'Risk/reward must be greater than zero.',
      );
    }
    final validGeometry = switch (direction) {
      UnifiedCandidateDirection.buy =>
        stopLoss < entryPrice && takeProfit > entryPrice,
      UnifiedCandidateDirection.sell =>
        stopLoss > entryPrice && takeProfit < entryPrice,
    };
    if (!validGeometry) {
      throw ArgumentError(
        'Entry/SL/TP geometry does not match candidate direction.',
      );
    }
  }

  final String symbol;
  final DateTime observedAt;
  final UnifiedCandidateDirection direction;
  final UnifiedStrategySource source;
  final double entryPrice;
  final double stopLoss;
  final double takeProfit;
  final double riskReward;
  final List<String> evidence;

  String get opportunityKey =>
      '${symbol.toUpperCase()}|${observedAt.toUtc().toIso8601String()}';
}

final class UnifiedCandidatePoolItem {
  const UnifiedCandidatePoolItem({
    required this.opportunityKey,
    required this.candidates,
    required this.disposition,
  });

  final String opportunityKey;
  final List<UnifiedSignalCandidate> candidates;
  final UnifiedCandidatePoolDisposition disposition;

  bool get hasConflict =>
      disposition == UnifiedCandidatePoolDisposition.conflict;

  Set<UnifiedStrategySource> get sources =>
      candidates.map((candidate) => candidate.source).toSet();
}

final class UnifiedCandidatePoolResult {
  const UnifiedCandidatePoolResult({
    required this.items,
    required this.inputCandidates,
    required this.sameDirectionMerges,
    required this.directionConflicts,
  });

  final List<UnifiedCandidatePoolItem> items;
  final int inputCandidates;
  final int sameDirectionMerges;
  final int directionConflicts;

  int get uniqueOpportunities => items.length;
  int get reviewableOpportunities =>
      items.where((item) => !item.hasConflict).length;
}

/// Strategy-neutral pre-Final-Review candidate pool.
///
/// A, B and C5 keep their own strategy/risk logic. This class only normalizes
/// their already-formed plans into one review queue.
///
/// Same symbol + same observation time:
/// - same direction => one opportunity retaining every source candidate;
/// - opposite direction => explicit conflict, never silently resolved.
///
/// No score, strategy priority or trade-frequency quota is introduced here.
final class UnifiedCandidatePool {
  const UnifiedCandidatePool();

  UnifiedCandidatePoolResult build(
    Iterable<UnifiedSignalCandidate> candidates,
  ) {
    final input = candidates.toList();
    final groups = <String, List<UnifiedSignalCandidate>>{};

    for (final candidate in input) {
      groups.putIfAbsent(candidate.opportunityKey, () => []).add(candidate);
    }

    var merges = 0;
    var conflicts = 0;
    final items = <UnifiedCandidatePoolItem>[];

    for (final entry in groups.entries) {
      final group = List<UnifiedSignalCandidate>.unmodifiable(entry.value);
      final directions = group.map((candidate) => candidate.direction).toSet();

      late final UnifiedCandidatePoolDisposition disposition;
      if (directions.length > 1) {
        disposition = UnifiedCandidatePoolDisposition.conflict;
        conflicts++;
      } else if (group.length > 1) {
        disposition = UnifiedCandidatePoolDisposition.merged;
        merges++;
      } else {
        disposition = UnifiedCandidatePoolDisposition.accepted;
      }

      items.add(
        UnifiedCandidatePoolItem(
          opportunityKey: entry.key,
          candidates: group,
          disposition: disposition,
        ),
      );
    }

    items.sort(
      (a, b) => a.candidates.first.observedAt.compareTo(
        b.candidates.first.observedAt,
      ),
    );

    return UnifiedCandidatePoolResult(
      items: List.unmodifiable(items),
      inputCandidates: input.length,
      sameDirectionMerges: merges,
      directionConflicts: conflicts,
    );
  }
}
