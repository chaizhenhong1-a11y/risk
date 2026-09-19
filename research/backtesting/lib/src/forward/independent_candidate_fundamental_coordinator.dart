import '../fundamentals/candidate_fundamental_review_service.dart';
import 'ai_market_context_snapshot.dart';
import 'biquote_closed_bar_store.dart';
import 'biquote_live_market_snapshot.dart';
import 'fundamental_review_projection.dart';

/// Only independent evidence reaches providers/Gemini.
/// Same-exposure duplicates neither consume AI calls nor raise confidence.
///
/// Market context is reconstructed from authoritative CLOSED bars at the
/// candidate's own observedAt. This keeps AI review candidate-specific and
/// prevents later/future bars from leaking into an older candidate review.
final class IndependentCandidateFundamentalCoordinator {
  IndependentCandidateFundamentalCoordinator(
    this.service, {
    BiQuoteClosedBarStore? marketStore,
  }) : _marketStore = marketStore;

  final CandidateFundamentalReviewService service;
  final BiQuoteClosedBarStore? _marketStore;
  final Map<String, FundamentalReviewResult> _reviews = {};

  Future<void> enrich(List<Map<String, Object?>> history) async {
    for (final item in history) {
      if (item['independentEvidence'] != true) continue;
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) continue;
      var result = _reviews[id];
      if (result == null) {
        final candidate = Map<String, dynamic>.from(item);
        final marketContext = _marketContextFor(item);
        if (marketContext != null) {
          candidate['marketContext'] = marketContext;
        }
        result = await service.reviewIndependentCandidate(
          candidate: candidate,
          nowUtc: DateTime.now().toUtc(),
        );
        _reviews[id] = result;
      }
      item['fundamentalReview'] = fundamentalReviewProjection(
        result,
        candidate: item,
      );
    }
  }

  Map<String, Object?>? _marketContextFor(Map<String, Object?> item) {
    final store = _marketStore;
    if (store == null) return null;
    final observedAt = DateTime.tryParse(item['observedAt']?.toString() ?? '');
    if (observedAt == null) return null;

    final liveSnapshot = BiQuoteLiveMarketSnapshot.fromStore(
      store,
      observedAt: observedAt.toUtc(),
    );
    if (!liveSnapshot.hasMinimumTimeframes) return null;
    return AiMarketContextSnapshot.fromLive(liveSnapshot).toJson();
  }

  int get reviewedIndependentCandidateCount => _reviews.length;
}
