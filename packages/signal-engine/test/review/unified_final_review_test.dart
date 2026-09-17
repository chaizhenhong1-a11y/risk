import 'package:signal_engine/signal_engine.dart';
import 'package:test/test.dart';

void main() {
  group('UnifiedFinalReviewer', () {
    test('approves a valid reviewable candidate', () {
      final item = _poolItem(_buy());
      final result = const UnifiedFinalReviewer().review(item: item);

      expect(result.decision, FinalReviewDecision.approved);
      expect(result.isApproved, isTrue);
    });

    test('rejects RR below the final-review floor', () {
      final item = _poolItem(_buy(riskReward: 1.5));
      final result = const UnifiedFinalReviewer().review(item: item);

      expect(result.decision, FinalReviewDecision.rejected);
      expect(
        result.reasons,
        contains(FinalReviewReason.insufficientRiskReward),
      );
    });

    test('blocks explicit candidate-pool direction conflicts', () {
      final time = DateTime.utc(2026, 9, 17);
      final pool = const UnifiedCandidatePool().build([
        _buy(time: time),
        _sell(time: time),
      ]);

      final result = const UnifiedFinalReviewer().review(
        item: pool.items.single,
      );

      expect(result.decision, FinalReviewDecision.conflict);
      expect(result.isApproved, isFalse);
    });

    test('rejects when news or macro gate is blocked', () {
      final item = _poolItem(_buy());
      final result = const UnifiedFinalReviewer().review(
        item: item,
        context: FinalReviewContext(newsMacroClear: false),
      );

      expect(result.decision, FinalReviewDecision.rejected);
      expect(result.reasons, contains(FinalReviewReason.newsMacroBlocked));
    });

    test('rejects when portfolio risk is unacceptable', () {
      final item = _poolItem(_buy());
      final result = const UnifiedFinalReviewer().review(
        item: item,
        context: FinalReviewContext(portfolioRiskAcceptable: false),
      );

      expect(result.decision, FinalReviewDecision.rejected);
      expect(result.reasons, contains(FinalReviewReason.portfolioRiskBlocked));
    });

    test('does not use a daily opportunity quota', () {
      final reviewer = const UnifiedFinalReviewer();
      final first = reviewer.review(item: _poolItem(_buy()));
      final second = reviewer.review(
        item: _poolItem(_buy(time: DateTime.utc(2026, 9, 17, 2))),
      );

      expect(first.isApproved, isTrue);
      expect(second.isApproved, isTrue);
    });
  });
}

UnifiedCandidatePoolItem _poolItem(UnifiedSignalCandidate candidate) {
  return const UnifiedCandidatePool().build([candidate]).items.single;
}

UnifiedSignalCandidate _buy({DateTime? time, double riskReward = 2}) {
  return UnifiedSignalCandidate(
    symbol: 'XAUUSD',
    observedAt: time ?? DateTime.utc(2026, 9, 17, 1),
    direction: UnifiedCandidateDirection.buy,
    source: UnifiedStrategySource.strategyC5,
    entryPrice: 2600,
    stopLoss: 2590,
    takeProfit: 2620,
    riskReward: riskReward,
    evidence: const ['validated strategy evidence'],
  );
}

UnifiedSignalCandidate _sell({required DateTime time}) {
  return UnifiedSignalCandidate(
    symbol: 'XAUUSD',
    observedAt: time,
    direction: UnifiedCandidateDirection.sell,
    source: UnifiedStrategySource.strategyB,
    entryPrice: 2600,
    stopLoss: 2610,
    takeProfit: 2580,
    riskReward: 2,
    evidence: const ['strategy evidence'],
  );
}
