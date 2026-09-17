import 'dart:convert';

final class C5BarrierBar {
  const C5BarrierBar({
    required this.offset,
    required this.high,
    required this.low,
  });

  final int offset;
  final double high;
  final double low;

  factory C5BarrierBar.fromJson(Map<String, dynamic> json) => C5BarrierBar(
    offset: (json['offset'] as num).toInt(),
    high: (json['high'] as num).toDouble(),
    low: (json['low'] as num).toDouble(),
  );
}

final class C5BarrierPath {
  const C5BarrierPath({required this.entryClose, required this.bars});

  final double entryClose;
  final List<C5BarrierBar> bars;

  factory C5BarrierPath.fromJsonLine(String line) {
    final json = jsonDecode(line) as Map<String, dynamic>;
    final entry = json['entry'] as Map<String, dynamic>;
    return C5BarrierPath(
      entryClose: (entry['close'] as num).toDouble(),
      bars: (json['forwardBars'] as List<dynamic>)
          .map((e) => C5BarrierBar.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

enum BarrierOutcome { targetFirst, stopFirst, ambiguousSameBar, unresolved }

final class BarrierLifecycleResult {
  const BarrierLifecycleResult({
    required this.stopDistance,
    required this.rewardMultiple,
    required this.samples,
    required this.targetFirst,
    required this.stopFirst,
    required this.ambiguousSameBar,
    required this.unresolved,
  });

  final double stopDistance;
  final double rewardMultiple;
  final int samples;
  final int targetFirst;
  final int stopFirst;
  final int ambiguousSameBar;
  final int unresolved;

  int get resolved => targetFirst + stopFirst;
  double get resolvedWinRate => resolved == 0 ? 0 : targetFirst / resolved;
  double get expectancyR =>
      resolved == 0 ? 0 : (targetFirst * rewardMultiple - stopFirst) / resolved;
}

final class C5BarrierLifecycleAnalysis {
  const C5BarrierLifecycleAnalysis();

  BarrierOutcome classify(
    C5BarrierPath path, {
    required double stopDistance,
    required double rewardMultiple,
  }) {
    final stop = path.entryClose - stopDistance;
    final target = path.entryClose + stopDistance * rewardMultiple;

    for (final bar in path.bars) {
      final hitStop = bar.low <= stop;
      final hitTarget = bar.high >= target;

      if (hitStop && hitTarget) return BarrierOutcome.ambiguousSameBar;
      if (hitStop) return BarrierOutcome.stopFirst;
      if (hitTarget) return BarrierOutcome.targetFirst;
    }
    return BarrierOutcome.unresolved;
  }

  BarrierLifecycleResult evaluate(
    List<C5BarrierPath> paths, {
    required double stopDistance,
    required double rewardMultiple,
  }) {
    var targetFirst = 0;
    var stopFirst = 0;
    var ambiguous = 0;
    var unresolved = 0;

    for (final path in paths) {
      switch (classify(
        path,
        stopDistance: stopDistance,
        rewardMultiple: rewardMultiple,
      )) {
        case BarrierOutcome.targetFirst:
          targetFirst++;
        case BarrierOutcome.stopFirst:
          stopFirst++;
        case BarrierOutcome.ambiguousSameBar:
          ambiguous++;
        case BarrierOutcome.unresolved:
          unresolved++;
      }
    }

    return BarrierLifecycleResult(
      stopDistance: stopDistance,
      rewardMultiple: rewardMultiple,
      samples: paths.length,
      targetFirst: targetFirst,
      stopFirst: stopFirst,
      ambiguousSameBar: ambiguous,
      unresolved: unresolved,
    );
  }
}
