import 'dart:convert';

final class C5AdaptiveBar {
  const C5AdaptiveBar({
    required this.high,
    required this.low,
    required this.close,
  });

  final double high;
  final double low;
  final double close;

  factory C5AdaptiveBar.fromJson(Map<String, dynamic> json) => C5AdaptiveBar(
    high: (json['high'] as num).toDouble(),
    low: (json['low'] as num).toDouble(),
    close: (json['close'] as num).toDouble(),
  );
}

final class C5AdaptivePath {
  const C5AdaptivePath({
    required this.time,
    required this.entryHigh,
    required this.entryLow,
    required this.entryClose,
    required this.bars,
  });

  final DateTime time;
  final double entryHigh;
  final double entryLow;
  final double entryClose;
  final List<C5AdaptiveBar> bars;

  double get entryRange => entryHigh - entryLow;

  factory C5AdaptivePath.fromJsonLine(String line) {
    final json = jsonDecode(line) as Map<String, dynamic>;
    final entry = json['entry'] as Map<String, dynamic>;
    return C5AdaptivePath(
      time: DateTime.parse(json['time'] as String),
      entryHigh: (entry['high'] as num).toDouble(),
      entryLow: (entry['low'] as num).toDouble(),
      entryClose: (entry['close'] as num).toDouble(),
      bars: (json['forwardBars'] as List<dynamic>)
          .map((e) => C5AdaptiveBar.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

enum C5AdaptiveOutcome { target, stop, expiry, ambiguous }

final class C5AdaptiveSettlement {
  const C5AdaptiveSettlement(this.outcome, this.r);

  final C5AdaptiveOutcome outcome;
  final double? r;
}

final class C5AdaptiveConfig {
  const C5AdaptiveConfig({
    required this.label,
    required this.stopDistance,
    required this.rewardMultiple,
  });

  final String label;
  final double Function(C5AdaptivePath) stopDistance;
  final double rewardMultiple;
}

final class C5AdaptiveWindow {
  C5AdaptiveWindow({
    required this.window,
    required this.start,
    required this.end,
    required this.samples,
  });

  final int window;
  final DateTime start;
  final DateTime end;
  final int samples;
  int target = 0;
  int stop = 0;
  int expiry = 0;
  int ambiguous = 0;
  int invalidRisk = 0;
  int settled = 0;
  int positive = 0;
  double rSum = 0;

  double get expectancy => settled == 0 ? 0 : rSum / settled;
  double get positiveRate => settled == 0 ? 0 : positive / settled;

  void add(C5AdaptiveSettlement settlement) {
    switch (settlement.outcome) {
      case C5AdaptiveOutcome.target:
        target++;
      case C5AdaptiveOutcome.stop:
        stop++;
      case C5AdaptiveOutcome.expiry:
        expiry++;
      case C5AdaptiveOutcome.ambiguous:
        ambiguous++;
    }
    if (settlement.r != null) {
      settled++;
      rSum += settlement.r!;
      if (settlement.r! > 0) positive++;
    }
  }
}

final class C5AdaptiveRiskValidation {
  const C5AdaptiveRiskValidation();

  C5AdaptiveSettlement? settle(C5AdaptivePath path, C5AdaptiveConfig config) {
    final distance = config.stopDistance(path);
    if (!distance.isFinite || distance <= 0) return null;

    final stop = path.entryClose - distance;
    final target = path.entryClose + distance * config.rewardMultiple;

    for (final bar in path.bars) {
      final hitStop = bar.low <= stop;
      final hitTarget = bar.high >= target;
      if (hitStop && hitTarget) {
        return const C5AdaptiveSettlement(C5AdaptiveOutcome.ambiguous, null);
      }
      if (hitStop) {
        return const C5AdaptiveSettlement(C5AdaptiveOutcome.stop, -1);
      }
      if (hitTarget) {
        return C5AdaptiveSettlement(
          C5AdaptiveOutcome.target,
          config.rewardMultiple,
        );
      }
    }

    final expiryR = (path.bars.last.close - path.entryClose) / distance;
    return C5AdaptiveSettlement(
      C5AdaptiveOutcome.expiry,
      expiryR.clamp(-1.0, config.rewardMultiple).toDouble(),
    );
  }

  List<C5AdaptiveWindow> evaluateFiveWindows(
    List<C5AdaptivePath> input,
    C5AdaptiveConfig config,
  ) {
    final paths = [...input]..sort((a, b) => a.time.compareTo(b.time));
    final results = <C5AdaptiveWindow>[];

    for (var window = 0; window < 5; window++) {
      final startIndex = (paths.length * window / 5).floor();
      final endIndex = (paths.length * (window + 1) / 5).floor();
      final slice = paths.sublist(startIndex, endIndex);
      if (slice.isEmpty) continue;

      final result = C5AdaptiveWindow(
        window: window + 1,
        start: slice.first.time,
        end: slice.last.time,
        samples: slice.length,
      );

      for (final path in slice) {
        final settlement = settle(path, config);
        if (settlement == null) {
          result.invalidRisk++;
          continue;
        }
        result.add(settlement);
      }
      results.add(result);
    }
    return results;
  }
}

List<C5AdaptiveConfig> c5AdaptiveConfigs() => [
  C5AdaptiveConfig(
    label: 'entryRange_1.0x_TP2R',
    stopDistance: (p) => p.entryRange,
    rewardMultiple: 2,
  ),
  C5AdaptiveConfig(
    label: 'entryRange_1.5x_TP2R',
    stopDistance: (p) => p.entryRange * 1.5,
    rewardMultiple: 2,
  ),
  C5AdaptiveConfig(
    label: 'entryRange_2.0x_TP2R',
    stopDistance: (p) => p.entryRange * 2,
    rewardMultiple: 2,
  ),
  C5AdaptiveConfig(
    label: 'entryRange_1.0x_TP3R',
    stopDistance: (p) => p.entryRange,
    rewardMultiple: 3,
  ),
  C5AdaptiveConfig(
    label: 'entryRange_1.5x_TP3R',
    stopDistance: (p) => p.entryRange * 1.5,
    rewardMultiple: 3,
  ),
  C5AdaptiveConfig(
    label: 'entryRange_2.0x_TP3R',
    stopDistance: (p) => p.entryRange * 2,
    rewardMultiple: 3,
  ),
];
