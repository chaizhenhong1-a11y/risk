final class AiReviewContextAudit {
  const AiReviewContextAudit({
    required this.presentCandidateFields,
    required this.missingCandidateFields,
    required this.newsAvailable,
    required this.calendarAvailable,
    required this.marketContextAvailable,
    this.newsAgeMinutes,
    this.calendarAgeMinutes,
    this.marketAgeMinutes,
    this.newsStale = false,
    this.calendarStale = false,
    this.marketStale = false,
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
  final bool marketContextAvailable;

  /// Advisory age diagnostics only. These values never gate a candidate.
  final int? newsAgeMinutes;
  final int? calendarAgeMinutes;
  final int? marketAgeMinutes;
  final bool newsStale;
  final bool calendarStale;
  final bool marketStale;

  bool get candidateCoreComplete => missingCandidateFields.isEmpty;
  bool get hasStaleContext => newsStale || calendarStale || marketStale;

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
    'newsAgeMinutes': newsAgeMinutes,
    'calendarAgeMinutes': calendarAgeMinutes,
    'marketAgeMinutes': marketAgeMinutes,
    'newsStale': newsStale,
    'calendarStale': calendarStale,
    'marketStale': marketStale,
    'hasStaleContext': hasStaleContext,
  };
}

AiReviewContextAudit auditAiReviewContext({
  required Map<String, dynamic> candidate,
  required Map<String, dynamic> economicCalendar,
  required Map<String, dynamic> newsContext,
  required DateTime referenceTimeUtc,
  Duration newsFreshness = const Duration(minutes: 45),
  Duration calendarFreshness = const Duration(minutes: 15),
  Duration marketFreshness = const Duration(minutes: 10),
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
  final marketContextAvailable = candidate['marketContext'] is Map;

  final newsAge = _ageMinutes(newsContext['observedAtUtc'], referenceTimeUtc);
  final calendarAge = _ageMinutes(
    economicCalendar['observedAtUtc'],
    referenceTimeUtc,
  );
  final market = candidate['marketContext'];
  final marketAge = market is Map
      ? _ageMinutes(market['observedAt'], referenceTimeUtc)
      : null;

  return AiReviewContextAudit(
    presentCandidateFields: List.unmodifiable(present),
    missingCandidateFields: List.unmodifiable(missing),
    newsAvailable: newsAvailable,
    calendarAvailable: calendarAvailable,
    marketContextAvailable: marketContextAvailable,
    newsAgeMinutes: newsAge,
    calendarAgeMinutes: calendarAge,
    marketAgeMinutes: marketAge,
    newsStale:
        newsAvailable &&
        (newsAge == null || newsAge >= newsFreshness.inMinutes),
    calendarStale:
        calendarAvailable &&
        (calendarAge == null || calendarAge >= calendarFreshness.inMinutes),
    marketStale:
        marketContextAvailable &&
        (marketAge == null || marketAge >= marketFreshness.inMinutes),
  );
}

int? _ageMinutes(Object? raw, DateTime referenceTimeUtc) {
  final observed = DateTime.tryParse(raw?.toString() ?? '');
  if (observed == null) return null;
  final delta = referenceTimeUtc.toUtc().difference(observed.toUtc());
  if (delta.isNegative) return 0;
  return delta.inMinutes;
}

bool _hasUsableValue(Object? value) {
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  if (value is num) return value.isFinite;
  return true;
}
