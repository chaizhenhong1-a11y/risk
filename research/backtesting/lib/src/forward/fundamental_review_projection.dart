import '../fundamentals/candidate_fundamental_review_service.dart';
import '../fundamentals/gemini_fundamental_review.dart';

Map<String, Object?> fundamentalReviewProjection(
  FundamentalReviewResult result,
) {
  final risk = switch (result.review.risk) {
    FundamentalRisk.normal => 'NORMAL',
    FundamentalRisk.caution => 'CAUTION',
    FundamentalRisk.highRisk => 'HIGH_RISK',
  };
  return <String, Object?>{
    'risk': risk,
    'goldBias': result.review.goldBias,
    'summary': result.review.summary,
    'relevantFactors': result.review.relevantFactors,
    'aiAvailable': result.review.available,
    'model': result.review.model,
    'reason': result.review.reason,
    'newsCacheHit': result.newsCacheHit,
    'calendarCacheHit': result.calendarCacheHit,
    'candidatePreserved': result.candidatePreserved,
  };
}
