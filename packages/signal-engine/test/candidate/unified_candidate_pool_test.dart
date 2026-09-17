import 'package:signal_engine/src/candidate/unified_candidate_pool.dart';
import 'package:test/test.dart';

void main() {
  group('UnifiedCandidatePool', () {
    test('keeps independent opportunities separate', () {
      final result = const UnifiedCandidatePool().build([
        _candidate(
          source: UnifiedStrategySource.strategyA,
          time: DateTime.utc(2026, 9, 17, 1),
        ),
        _candidate(
          source: UnifiedStrategySource.strategyC5,
          time: DateTime.utc(2026, 9, 17, 2),
        ),
      ]);

      expect(result.inputCandidates, 2);
      expect(result.uniqueOpportunities, 2);
      expect(result.reviewableOpportunities, 2);
      expect(result.sameDirectionMerges, 0);
      expect(result.directionConflicts, 0);
    });

    test('merges same timestamp and direction while retaining sources', () {
      final time = DateTime.utc(2026, 9, 17, 1);
      final result = const UnifiedCandidatePool().build([
        _candidate(source: UnifiedStrategySource.strategyA, time: time),
        _candidate(source: UnifiedStrategySource.strategyB, time: time),
      ]);

      expect(result.uniqueOpportunities, 1);
      expect(result.sameDirectionMerges, 1);
      expect(result.items.single.sources, {
        UnifiedStrategySource.strategyA,
        UnifiedStrategySource.strategyB,
      });
    });

    test('opposite directions become an explicit conflict', () {
      final time = DateTime.utc(2026, 9, 17, 1);
      final result = const UnifiedCandidatePool().build([
        _candidate(source: UnifiedStrategySource.strategyA, time: time),
        _candidate(
          source: UnifiedStrategySource.strategyB,
          time: time,
          direction: UnifiedCandidateDirection.sell,
        ),
      ]);

      expect(result.uniqueOpportunities, 1);
      expect(result.directionConflicts, 1);
      expect(result.reviewableOpportunities, 0);
      expect(result.items.single.hasConflict, isTrue);
    });

    test('rejects invalid BUY geometry', () {
      expect(
        () => UnifiedSignalCandidate(
          symbol: 'XAUUSD',
          observedAt: DateTime.utc(2026, 9, 17),
          direction: UnifiedCandidateDirection.buy,
          source: UnifiedStrategySource.strategyC5,
          entryPrice: 2600,
          stopLoss: 2610,
          takeProfit: 2630,
          riskReward: 2,
          evidence: const ['C5'],
        ),
        throwsArgumentError,
      );
    });
  });
}

UnifiedSignalCandidate _candidate({
  required UnifiedStrategySource source,
  required DateTime time,
  UnifiedCandidateDirection direction = UnifiedCandidateDirection.buy,
}) {
  return switch (direction) {
    UnifiedCandidateDirection.buy => UnifiedSignalCandidate(
      symbol: 'XAUUSD',
      observedAt: time,
      direction: direction,
      source: source,
      entryPrice: 2600,
      stopLoss: 2590,
      takeProfit: 2620,
      riskReward: 2,
      evidence: const ['test'],
    ),
    UnifiedCandidateDirection.sell => UnifiedSignalCandidate(
      symbol: 'XAUUSD',
      observedAt: time,
      direction: direction,
      source: source,
      entryPrice: 2600,
      stopLoss: 2610,
      takeProfit: 2580,
      riskReward: 2,
      evidence: const ['test'],
    ),
  };
}
