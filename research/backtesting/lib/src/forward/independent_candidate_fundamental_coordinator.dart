import '../fundamentals/candidate_fundamental_review_service.dart';
import 'fundamental_review_projection.dart';

/// Reviews only candidates already classified as independent evidence.
/// Same-exposure duplicates never reach the external providers or Gemini.
final class IndependentCandidateFundamentalCoordinator {
  IndependentCandidateFundamentalCoordinator(this.service);

  final CandidateFundamentalReviewService service;
  final Map<String, FundamentalReviewResult> _reviews = {};

  Future<void> enrich(List<Map<String, Object?>> history) async {
    for (final item in history) {
      if (item['independentEvidence'] != true) continue;
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) continue;

      var result = _reviews[id];
      if (result == null) {
        result = await service.reviewIndependentCandidate(
          candidate: Map<String, dynamic>.from(item),
          nowUtc: DateTime.now().toUtc(),
        );
        _reviews[id] = result;
      }
      item['fundamentalReview'] = fundamentalReviewProjection(result);
    }
  }

  int get reviewedIndependentCandidateCount => _reviews.length;
}
