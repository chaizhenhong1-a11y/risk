final class AiReviewContextAudit {
  const AiReviewContextAudit({
    required this.presentCandidateFields,
    required this.missingCandidateFields,
    required this.newsAvailable,
    required this.calendarAvailable,
    required this.marketContextAvailable,
  });

  static const requiredCandidateFields = <String>[
    'strategy',
    'side',
    'entry',
    'stopLoss',
    'takeProfit',
    'riskReward',
    'reason',
    'exposureStatus',
  ];

  final List<String> presentCandidateFields;
  final List<String> missingCandidateFields;
  final bool newsAvailable;
  final bool calendarAvailable;

  /// Increment 204 audits this explicitly. Existing AiMarketContextSnapshot is
  /// not yet wired into the Gemini candidate-review request.
  final bool marketContextAvailable;

  bool get candidateCoreComplete => missingCandidateFields.isEmpty;

  /// Describes review-input coverage only. It is never a strategy/execution gate.
  String get coverage =>
      candidateCoreComplete &&
          newsAvailable &&
          calendarAvailable &&
          marketContextAvailable
      ? 'FULL'
      : candidateCoreComplete
      ? 'PARTIAL'
      : 'LIMITED';

  Map<String, Object?> toJson() => <String, Object?>{
    'coverage': coverage,
    'candidateCoreComplete': candidateCoreComplete,
    'presentCandidateFields': presentCandidateFields,
    'missingCandidateFields': missingCandidateFields,
    'newsAvailable': newsAvailable,
    'calendarAvailable': calendarAvailable,
    'marketContextAvailable': marketContextAvailable,
  };
}

AiReviewContextAudit auditAiReviewContext({
  required Map<String, dynamic> candidate,
  required Map<String, dynamic> economicCalendar,
  required Map<String, dynamic> newsContext,
}) {
  final present = <String>[];
  final missing = <String>[];

  for (final field in AiReviewContextAudit.requiredCandidateFields) {
    if (_hasUsableValue(candidate[field])) {
      present.add(field);
    } else {
      missing.add(field);
    }
  }

  final newsAvailable = newsContext['availability']?.toString() == 'available';
  final calendarAvailable =
      economicCalendar['source']?.toString().isNotEmpty == true &&
      economicCalendar['source']?.toString() != 'finance_calendar_unavailable';

  return AiReviewContextAudit(
    presentCandidateFields: List.unmodifiable(present),
    missingCandidateFields: List.unmodifiable(missing),
    newsAvailable: newsAvailable,
    calendarAvailable: calendarAvailable,
    marketContextAvailable: candidate['marketContext'] is Map,
  );
}

bool _hasUsableValue(Object? value) {
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  if (value is num) return value.isFinite;
  return true;
}
