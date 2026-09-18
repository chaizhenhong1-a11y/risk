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

  bool get isSameExposure => exposureStatus == 'same_exposure';
  bool get isPortfolioOverlap => exposureStatus == 'portfolio_overlap';

  bool get isPaperForward => source == 'paper_forward';

  factory SignalHistoryView.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status']?.toString() ?? '';
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

/// Groups raw triggers for presentation/statistics while preserving every raw
/// trigger in [TradeForgeLiveState.signalHistory].
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

    // Defensive fallback for old API rows: find the nearest earlier active
    // same-strategy/same-side root. This affects presentation only.
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
      // Never hide an ungroupable raw trigger.
      roots[item.id] = item;
    }
  }

  final groups = roots.values
      .map(
        (root) => SignalExposureGroup(
          root: root,
          overlappingTriggers: List<SignalHistoryView>.unmodifiable(
              children[root.id] ?? const []),
        ),
      )
      .toList(growable: false)
    ..sort((a, b) => b.root.observedAt.compareTo(a.root.observedAt));
  return groups;
}
