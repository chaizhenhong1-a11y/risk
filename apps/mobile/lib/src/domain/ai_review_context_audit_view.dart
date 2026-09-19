class AiReviewContextAuditView {
  const AiReviewContextAuditView({
    required this.coverage,
    required this.candidateCoreComplete,
    required this.presentCandidateFields,
    required this.missingCandidateFields,
    required this.newsAvailable,
    required this.calendarAvailable,
    required this.marketContextAvailable,
  });

  final String coverage;
  final bool candidateCoreComplete;
  final List<String> presentCandidateFields;
  final List<String> missingCandidateFields;
  final bool newsAvailable;
  final bool calendarAvailable;
  final bool marketContextAvailable;

  factory AiReviewContextAuditView.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) => json[key] is List
        ? (json[key] as List).map((e) => e.toString()).toList(growable: false)
        : const <String>[];

    return AiReviewContextAuditView(
      coverage: json['coverage']?.toString() ?? 'LIMITED',
      candidateCoreComplete: json['candidateCoreComplete'] as bool? ?? false,
      presentCandidateFields: strings('presentCandidateFields'),
      missingCandidateFields: strings('missingCandidateFields'),
      newsAvailable: json['newsAvailable'] as bool? ?? false,
      calendarAvailable: json['calendarAvailable'] as bool? ?? false,
      marketContextAvailable: json['marketContextAvailable'] as bool? ?? false,
    );
  }
}
