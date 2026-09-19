import '../fundamentals/candidate_fundamental_review_service.dart';
import '../fundamentals/gemini_fundamental_review.dart';
import 'candidate_confidence_review.dart';
import 'candidate_final_review.dart';

Map<String, Object?> fundamentalReviewProjection(
  FundamentalReviewResult result, {
  Map<String, Object?>? candidate,
}) {
  final risk = switch (result.review.risk) {
    FundamentalRisk.normal => 'NORMAL',
    FundamentalRisk.caution => 'CAUTION',
    FundamentalRisk.highRisk => 'HIGH_RISK',
  };
  final confidence = candidate == null
      ? null
      : buildCandidateConfidenceReview(candidate, result);
  final finalReview = candidate == null
      ? null
      : buildCandidateFinalReview(candidate);

  return <String, Object?>{
    'risk': risk,
    'goldBias': result.review.goldBias,
    'summary': result.review.summary,
    'relevantFactors': result.review.relevantFactors,
    'candidateSummary': result.review.candidateSummary,
    'technicalReasons': result.review.technicalReasons,
    'riskReasons': result.review.riskReasons,
    'aiAvailable': result.review.available,
    'model': result.review.model,
    'reason': result.review.reason,
    'newsCacheHit': result.newsCacheHit,
    'calendarCacheHit': result.calendarCacheHit,
    'candidatePreserved': result.candidatePreserved,
    if (finalReview != null) ...<String, Object?>{
      'executionIntegrityOk': finalReview.integrityOk,
      'executionIntegrityReasons': finalReview.integrityReasons,
    },
    if (confidence != null) ...<String, Object?>{
      'confidence': confidence.level.name.toUpperCase(),
      'confidenceCalibrated': confidence.calibrated,
      'confidenceReasons': confidence.supportingReasons,
      'confidenceCautions': confidence.cautionReasons,
    },
  };
}
