enum SignalHistoryStatus {
  pending,
  triggered,
  targetHit,
  stopHit,
  expired,
  ambiguous,
  rejected,
  unknown,
}

enum FundamentalRiskView { normal, caution, highRisk, unknown }

class FundamentalReviewView {
  const FundamentalReviewView({
    required this.risk,
    required this.goldBias,
    required this.summary,
    required this.relevantFactors,
    required this.aiAvailable,
    required this.candidatePreserved,
    this.candidateSummary = '',
    this.technicalReasons = const <String>[],
    this.riskReasons = const <String>[],
    this.aiSupportPercent,
    this.aiOpposePercent,
    this.aiSupportExplanation = '',
    this.aiOpposeExplanation = '',
    this.executionIntegrityOk = true,
    this.executionIntegrityReasons = const <String>[],
    this.model,
    this.reason,
    this.newsCacheHit = false,
    this.calendarCacheHit = false,
    this.confidence = 'STANDARD',
    this.confidenceCalibrated = false,
    this.confidenceReasons = const <String>[],
    this.confidenceCautions = const <String>[],
  });

  final FundamentalRiskView risk;
  final String goldBias;
  final String summary;
  final List<String> relevantFactors;
  final String candidateSummary;
  final List<String> technicalReasons;
  final List<String> riskReasons;
  final int? aiSupportPercent;
  final int? aiOpposePercent;
  final String aiSupportExplanation;
  final String aiOpposeExplanation;
  final bool executionIntegrityOk;
  final List<String> executionIntegrityReasons;
  final bool aiAvailable;
  final bool candidatePreserved;
  final String? model;
  final String? reason;
  final bool newsCacheHit;
  final bool calendarCacheHit;
  final String confidence;
  final bool confidenceCalibrated;
  final List<String> confidenceReasons;
  final List<String> confidenceCautions;

  String get confidenceLabel => confidence.replaceAll('_', ' ');

  factory FundamentalReviewView.fromJson(Map<String, dynamic> json) {
    final risk = switch (json['risk']?.toString().toUpperCase()) {
      'NORMAL' => FundamentalRiskView.normal,
      'CAUTION' => FundamentalRiskView.caution,
      'HIGH_RISK' => FundamentalRiskView.highRisk,
      _ => FundamentalRiskView.unknown,
    };
    List<String> strings(String key) => json[key] is List
        ? (json[key] as List).map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    int? percent(String key) {
      final value = json[key];
      if (value is! num) return null;
      final parsed = value.toInt();
      return parsed >= 0 && parsed <= 100 ? parsed : null;
    }

    return FundamentalReviewView(
      risk: risk,
      goldBias: json['goldBias']?.toString() ?? 'unclear',
      summary: json['summary']?.toString() ?? '',
      relevantFactors: strings('relevantFactors'),
      candidateSummary: json['candidateSummary']?.toString() ?? '',
      technicalReasons: strings('technicalReasons'),
      riskReasons: strings('riskReasons'),
      aiSupportPercent: percent('aiSupportPercent'),
      aiOpposePercent: percent('aiOpposePercent'),
      aiSupportExplanation: json['aiSupportExplanation']?.toString() ?? '',
      aiOpposeExplanation: json['aiOpposeExplanation']?.toString() ?? '',
      executionIntegrityOk: json['executionIntegrityOk'] as bool? ?? true,
      executionIntegrityReasons: strings('executionIntegrityReasons'),
      aiAvailable: json['aiAvailable'] as bool? ?? false,
      candidatePreserved: json['candidatePreserved'] as bool? ?? true,
      model: json['model']?.toString(),
      reason: json['reason']?.toString(),
      newsCacheHit: json['newsCacheHit'] as bool? ?? false,
      calendarCacheHit: json['calendarCacheHit'] as bool? ?? false,
      confidence: json['confidence']?.toString() ?? 'STANDARD',
      confidenceCalibrated: json['confidenceCalibrated'] as bool? ?? false,
      confidenceReasons: strings('confidenceReasons'),
      confidenceCautions: strings('confidenceCautions'),
    );
  }
}

class SignalHistoryView {
  const SignalHistoryView({
    required this.id,
    required this.source,
    required this.symbol,
    required this.strategy,
    required this.side,
    required this.observedAt,
    required this.entry,
    required this.stopLoss,
    required this.takeProfit,
    required this.riskReward,
    required this.status,
    this.segmentId,
    this.regime,
    this.reason = '',
    this.resolvedAt,
    this.realizedR,
    this.exposureStatus = 'independent',
    this.independentEvidence = true,
    this.executionEligible = true,
    this.portfolioOverlap = false,
    this.exposureGroupId,
    this.overlapsSignalId,
    this.fundamentalReview,
  });

  final String id;
  final String source;
  final String symbol;
  final String strategy;
  final String side;
  final String? segmentId;
  final String? regime;
  final DateTime observedAt;
  final double entry;
  final double stopLoss;
  final double takeProfit;
  final double riskReward;
  final String reason;
  final SignalHistoryStatus status;
  final DateTime? resolvedAt;
  final double? realizedR;
  final String exposureStatus;
  final bool independentEvidence;
  final bool executionEligible;
  final bool portfolioOverlap;
  final String? exposureGroupId;
  final String? overlapsSignalId;
  final FundamentalReviewView? fundamentalReview;

  bool get isSameExposure => exposureStatus == 'same_exposure';
  bool get isPortfolioOverlap => exposureStatus == 'portfolio_overlap';
  bool get isPaperForward => source == 'paper_forward';

  factory SignalHistoryView.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status']?.toString() ?? '';
    final rawReview = json['fundamentalReview'];
    return SignalHistoryView(
      id: json['id']?.toString() ?? '',
      source: json['source']?.toString() ?? 'unknown',
      symbol: json['symbol']?.toString() ?? 'XAUUSD',
      strategy: json['strategy']?.toString() ?? 'UNKNOWN',
      side: json['side']?.toString().toUpperCase() ?? 'UNKNOWN',
      segmentId: json['segmentId']?.toString(),
      regime: json['regime']?.toString(),
      observedAt:
          _date(json['observedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      entry: (json['entry'] as num?)?.toDouble() ?? 0,
      stopLoss: (json['stopLoss'] as num?)?.toDouble() ?? 0,
      takeProfit: (json['takeProfit'] as num?)?.toDouble() ?? 0,
      riskReward: (json['riskReward'] as num?)?.toDouble() ?? 0,
      reason: json['reason']?.toString() ?? '',
      status: SignalHistoryStatus.values
              .where((e) => e.name == rawStatus)
              .firstOrNull ??
          SignalHistoryStatus.unknown,
      resolvedAt: _date(json['resolvedAt']),
      realizedR: (json['realizedR'] as num?)?.toDouble(),
      exposureStatus: json['exposureStatus']?.toString() ?? 'independent',
      independentEvidence: json['independentEvidence'] as bool? ?? true,
      executionEligible: json['executionEligible'] as bool? ?? true,
      portfolioOverlap: json['portfolioOverlap'] as bool? ?? false,
      exposureGroupId: json['exposureGroupId']?.toString(),
      overlapsSignalId: json['overlapsSignalId']?.toString(),
      fundamentalReview: rawReview is Map
          ? FundamentalReviewView.fromJson(
              Map<String, dynamic>.from(rawReview),
            )
          : null,
    );
  }

  static DateTime? _date(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class SignalExposureGroup {
  const SignalExposureGroup({
    required this.root,
    required this.overlappingTriggers,
  });

  final SignalHistoryView root;
  final List<SignalHistoryView> overlappingTriggers;

  int get triggerCount => 1 + overlappingTriggers.length;
  int get suppressedTriggerCount => overlappingTriggers.length;
}

List<SignalExposureGroup> buildSignalExposureGroups(
  List<SignalHistoryView> history,
) {
  final roots = <String, SignalHistoryView>{};
  final children = <String, List<SignalHistoryView>>{};
  final fallbackRoots = <SignalHistoryView>[];

  for (final item in history) {
    if (!item.isSameExposure) {
      roots[item.id] = item;
      fallbackRoots.add(item);
    }
  }

  for (final item in history) {
    if (!item.isSameExposure) continue;
    final groupId = item.exposureGroupId;
    if (groupId != null && roots.containsKey(groupId)) {
      children.putIfAbsent(groupId, () => <SignalHistoryView>[]).add(item);
      continue;
    }

    SignalHistoryView? candidate;
    for (final root in fallbackRoots) {
      if (root.strategy != item.strategy || root.side != item.side) continue;
      if (root.observedAt.isAfter(item.observedAt)) continue;
      final ended = root.resolvedAt;
      if (ended != null && !item.observedAt.isBefore(ended)) continue;
      if (candidate == null || root.observedAt.isAfter(candidate.observedAt)) {
        candidate = root;
      }
    }
    if (candidate != null) {
      children.putIfAbsent(candidate.id, () => <SignalHistoryView>[]).add(item);
    } else {
      roots[item.id] = item;
    }
  }

  final groups = roots.values
      .map(
        (root) => SignalExposureGroup(
          root: root,
          overlappingTriggers: List<SignalHistoryView>.unmodifiable(
            children[root.id] ?? const [],
          ),
        ),
      )
      .toList(growable: false)
    ..sort((a, b) => b.root.observedAt.compareTo(a.root.observedAt));
  return groups;
}
