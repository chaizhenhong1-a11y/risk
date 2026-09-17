import 'dart:convert';

final class C5RiskBar {
  const C5RiskBar({required this.high, required this.low, required this.close});

  final double high;
  final double low;
  final double close;

  factory C5RiskBar.fromJson(Map<String, dynamic> json) => C5RiskBar(
    high: (json['high'] as num).toDouble(),
    low: (json['low'] as num).toDouble(),
    close: (json['close'] as num).toDouble(),
  );
}

final class C5RiskPath {
  const C5RiskPath({
    required this.time,
    required this.entryClose,
    required this.bars,
  });

  final DateTime time;
  final double entryClose;
  final List<C5RiskBar> bars;

  factory C5RiskPath.fromJsonLine(String line) {
    final json = jsonDecode(line) as Map<String, dynamic>;
    final entry = json['entry'] as Map<String, dynamic>;
    return C5RiskPath(
      time: DateTime.parse(json['time'] as String),
      entryClose: (entry['close'] as num).toDouble(),
      bars: (json['forwardBars'] as List<dynamic>)
          .map((e) => C5RiskBar.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

enum C5RiskOutcome { target, stop, expiry, ambiguous }

final class C5RiskSettlement {
  const C5RiskSettlement(this.outcome, this.r);

  final C5RiskOutcome outcome;
  final double? r;
}

final class C5RiskWindowResult {
  C5RiskWindowResult({
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
  int settled = 0;
  int positive = 0;
  double rSum = 0;

  double get expectancy => settled == 0 ? 0 : rSum / settled;
  double get positiveRate => settled == 0 ? 0 : positive / settled;

  void add(C5RiskSettlement settlement) {
    switch (settlement.outcome) {
      case C5RiskOutcome.target:
        target++;
      case C5RiskOutcome.stop:
        stop++;
      case C5RiskOutcome.expiry:
        expiry++;
      case C5RiskOutcome.ambiguous:
        ambiguous++;
    }
    if (settlement.r != null) {
      settled++;
      rSum += settlement.r!;
      if (settlement.r! > 0) positive++;
    }
  }
}

final class C5RiskConfiguration {
  const C5RiskConfiguration({
    required this.stopDistance,
    required this.rewardMultiple,
  });

  final double stopDistance;
  final double rewardMultiple;

  String get label =>
      'SL${stopDistance.toStringAsFixed(1)}_TP${rewardMultiple.toStringAsFixed(1)}R';
}

final class C5RiskRobustnessValidation {
  const C5RiskRobustnessValidation();

  C5RiskSettlement settle(C5RiskPath path, C5RiskConfiguration config) {
    final stop = path.entryClose - config.stopDistance;
    final target =
        path.entryClose + config.stopDistance * config.rewardMultiple;

    for (final bar in path.bars) {
      final hitStop = bar.low <= stop;
      final hitTarget = bar.high >= target;
      if (hitStop && hitTarget) {
        return const C5RiskSettlement(C5RiskOutcome.ambiguous, null);
      }
      if (hitStop) return const C5RiskSettlement(C5RiskOutcome.stop, -1);
      if (hitTarget) {
        return C5RiskSettlement(C5RiskOutcome.target, config.rewardMultiple);
      }
    }

    final expiryR =
        (path.bars.last.close - path.entryClose) / config.stopDistance;
    return C5RiskSettlement(
      C5RiskOutcome.expiry,
      expiryR.clamp(-1.0, config.rewardMultiple).toDouble(),
    );
  }

  List<C5RiskWindowResult> evaluateFiveWindows(
    List<C5RiskPath> input,
    C5RiskConfiguration config,
  ) {
    final paths = [...input]..sort((a, b) => a.time.compareTo(b.time));
    final results = <C5RiskWindowResult>[];

    for (var window = 0; window < 5; window++) {
      final startIndex = (paths.length * window / 5).floor();
      final endIndex = (paths.length * (window + 1) / 5).floor();
      final slice = paths.sublist(startIndex, endIndex);
      if (slice.isEmpty) continue;

      final result = C5RiskWindowResult(
        window: window + 1,
        start: slice.first.time,
        end: slice.last.time,
        samples: slice.length,
      );
      for (final path in slice) {
        result.add(settle(path, config));
      }
      results.add(result);
    }
    return results;
  }
}
