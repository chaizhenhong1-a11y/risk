import '../bias/multi_timeframe_bias.dart';
import 'market_regime_router.dart';

final class StrategyOpportunityCandidate {
  const StrategyOpportunityCandidate({
    required this.symbol,
    required this.observedAt,
    required this.strategy,
    required this.bias,
  });

  final String symbol;
  final DateTime observedAt;
  final StrategyRouteId strategy;
  final TradingBias bias;

  bool get isDirectional => bias != TradingBias.noTrade;
}

final class PooledStrategyOpportunity {
  PooledStrategyOpportunity({
    required this.symbol,
    required this.observedAt,
    required this.bias,
    required Iterable<StrategyRouteId> sources,
  }) : sources = Set<StrategyRouteId>.unmodifiable(sources);

  final String symbol;
  final DateTime observedAt;
  final TradingBias bias;
  final Set<StrategyRouteId> sources;

  bool get hasMultipleSources => sources.length > 1;
}

final class StrategyCandidateConflict {
  StrategyCandidateConflict({
    required this.symbol,
    required this.observedAt,
    required Iterable<StrategyOpportunityCandidate> candidates,
  }) : candidates = List<StrategyOpportunityCandidate>.unmodifiable(candidates);

  final String symbol;
  final DateTime observedAt;
  final List<StrategyOpportunityCandidate> candidates;
}

final class StrategyCandidatePoolResult {
  StrategyCandidatePoolResult({
    required Iterable<PooledStrategyOpportunity> opportunities,
    required Iterable<StrategyCandidateConflict> conflicts,
  }) : opportunities = List<PooledStrategyOpportunity>.unmodifiable(opportunities),
       conflicts = List<StrategyCandidateConflict>.unmodifiable(conflicts);

  final List<PooledStrategyOpportunity> opportunities;
  final List<StrategyCandidateConflict> conflicts;
}

/// Same symbol + exact observation time + same direction is one opportunity.
/// Opposite directions are surfaced as conflicts for later Final Review.
final class StrategyCandidatePool {
  const StrategyCandidatePool();

  StrategyCandidatePoolResult combine(
    Iterable<StrategyOpportunityCandidate> candidates,
  ) {
    final groups = <_CandidateKey, List<StrategyOpportunityCandidate>>{};

    for (final candidate in candidates.where((item) => item.isDirectional)) {
      final key = _CandidateKey(candidate.symbol, candidate.observedAt);
      groups.putIfAbsent(key, () => []).add(candidate);
    }

    final opportunities = <PooledStrategyOpportunity>[];
    final conflicts = <StrategyCandidateConflict>[];

    for (final entry in groups.entries) {
      final biases = entry.value.map((item) => item.bias).toSet();
      if (biases.length > 1) {
        conflicts.add(
          StrategyCandidateConflict(
            symbol: entry.key.symbol,
            observedAt: entry.key.observedAt,
            candidates: entry.value,
          ),
        );
        continue;
      }

      opportunities.add(
        PooledStrategyOpportunity(
          symbol: entry.key.symbol,
          observedAt: entry.key.observedAt,
          bias: biases.single,
          sources: entry.value.map((item) => item.strategy),
        ),
      );
    }

    opportunities.sort((a, b) => a.observedAt.compareTo(b.observedAt));
    conflicts.sort((a, b) => a.observedAt.compareTo(b.observedAt));
    return StrategyCandidatePoolResult(
      opportunities: opportunities,
      conflicts: conflicts,
    );
  }
}

final class _CandidateKey {
  const _CandidateKey(this.symbol, this.observedAt);

  final String symbol;
  final DateTime observedAt;

  @override
  bool operator ==(Object other) =>
      other is _CandidateKey &&
      other.symbol == symbol &&
      other.observedAt == observedAt;

  @override
  int get hashCode => Object.hash(symbol, observedAt);
}
