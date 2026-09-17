import 'dart:convert';

final class C5CostRisk {
  const C5CostRisk({
    required this.time,
    required this.entryClose,
    required this.stopPrice,
    required this.stopDistance,
  });

  final DateTime time;
  final double entryClose;
  final double stopPrice;
  final double stopDistance;

  factory C5CostRisk.fromJsonLine(String line) {
    final json = jsonDecode(line) as Map<String, dynamic>;
    return C5CostRisk(
      time: DateTime.parse(json['time'] as String),
      entryClose: (json['entryClose'] as num).toDouble(),
      stopPrice: (json['bufferedStopPrice'] as num).toDouble(),
      stopDistance: (json['bufferedStopDistance'] as num).toDouble(),
    );
  }
}

final class C5CostBar {
  const C5CostBar({required this.high, required this.low, required this.close});

  final double high;
  final double low;
  final double close;

  factory C5CostBar.fromJson(Map<String, dynamic> json) => C5CostBar(
    high: (json['high'] as num).toDouble(),
    low: (json['low'] as num).toDouble(),
    close: (json['close'] as num).toDouble(),
  );
}

final class C5CostPath {
  const C5CostPath({required this.time, required this.bars});

  final DateTime time;
  final List<C5CostBar> bars;

  factory C5CostPath.fromJsonLine(String line) {
    final json = jsonDecode(line) as Map<String, dynamic>;
    return C5CostPath(
      time: DateTime.parse(json['time'] as String),
      bars: (json['forwardBars'] as List<dynamic>)
          .map((e) => C5CostBar.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

final class C5CostCase {
  const C5CostCase({required this.risk, required this.path});
  final C5CostRisk risk;
  final C5CostPath path;
}

enum C5CostOutcome { target, stop, expiry, ambiguous }

final class C5CostSettlement {
  const C5CostSettlement(this.outcome, this.netR);
  final C5CostOutcome outcome;
  final double? netR;
}

final class C5CostWindow {
  C5CostWindow({
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

  void add(C5CostSettlement result) {
    switch (result.outcome) {
      case C5CostOutcome.target:
        target++;
      case C5CostOutcome.stop:
        stop++;
      case C5CostOutcome.expiry:
        expiry++;
      case C5CostOutcome.ambiguous:
        ambiguous++;
    }
    final r = result.netR;
    if (r != null) {
      settled++;
      rSum += r;
      if (r > 0) positive++;
    }
  }
}

/// Frozen C5 cost stress model.
///
/// The Increment 118 trading geometry is not changed:
/// structural M15 support - ATR14*0.50 stop, 2R target, +48 M5 expiry.
///
/// [roundTripCostPrice] is a broker-agnostic adverse price-equivalent cost
/// covering spread + slippage + commission. It is converted to R separately
/// for every episode, so wider structural stops naturally absorb less cost-R.
final class C5CostStressValidation {
  const C5CostStressValidation();

  List<C5CostCase> join({
    required List<C5CostRisk> risks,
    required List<C5CostPath> paths,
  }) {
    String key(DateTime time) => time.toIso8601String();
    final byTime = {for (final path in paths) key(path.time): path};
    final joined = <C5CostCase>[];
    for (final risk in risks) {
      final path = byTime[key(risk.time)];
      if (path != null) joined.add(C5CostCase(risk: risk, path: path));
    }
    joined.sort((a, b) => a.risk.time.compareTo(b.risk.time));
    return joined;
  }

  C5CostSettlement settle(
    C5CostCase sample, {
    required double roundTripCostPrice,
  }) {
    if (!roundTripCostPrice.isFinite || roundTripCostPrice < 0) {
      throw ArgumentError.value(roundTripCostPrice, 'roundTripCostPrice');
    }

    const rewardMultiple = 2.0;
    final entry = sample.risk.entryClose;
    final risk = sample.risk.stopDistance;
    final stop = sample.risk.stopPrice;
    final target = entry + risk * rewardMultiple;
    final costR = roundTripCostPrice / risk;

    for (final bar in sample.path.bars) {
      final hitStop = bar.low <= stop;
      final hitTarget = bar.high >= target;
      if (hitStop && hitTarget) {
        return const C5CostSettlement(C5CostOutcome.ambiguous, null);
      }
      if (hitStop) {
        return C5CostSettlement(C5CostOutcome.stop, -1 - costR);
      }
      if (hitTarget) {
        return C5CostSettlement(C5CostOutcome.target, rewardMultiple - costR);
      }
    }

    final grossR = ((sample.path.bars.last.close - entry) / risk)
        .clamp(-1.0, rewardMultiple)
        .toDouble();
    return C5CostSettlement(C5CostOutcome.expiry, grossR - costR);
  }

  List<C5CostWindow> evaluateFiveWindows(
    List<C5CostCase> input, {
    required double roundTripCostPrice,
  }) {
    final cases = [...input]
      ..sort((a, b) => a.risk.time.compareTo(b.risk.time));
    final output = <C5CostWindow>[];

    for (var window = 0; window < 5; window++) {
      final startIndex = (cases.length * window / 5).floor();
      final endIndex = (cases.length * (window + 1) / 5).floor();
      final slice = cases.sublist(startIndex, endIndex);
      if (slice.isEmpty) continue;

      final result = C5CostWindow(
        window: window + 1,
        start: slice.first.risk.time,
        end: slice.last.risk.time,
        samples: slice.length,
      );
      for (final sample in slice) {
        result.add(settle(sample, roundTripCostPrice: roundTripCostPrice));
      }
      output.add(result);
    }
    return output;
  }

  double overallExpectancy(
    List<C5CostCase> cases, {
    required double roundTripCostPrice,
  }) {
    var total = 0.0;
    var settled = 0;
    for (final sample in cases) {
      final result = settle(sample, roundTripCostPrice: roundTripCostPrice);
      if (result.netR != null) {
        total += result.netR!;
        settled++;
      }
    }
    return settled == 0 ? 0 : total / settled;
  }

  double breakEvenRoundTripCostPrice(List<C5CostCase> cases) {
    final zeroCost = overallExpectancy(cases, roundTripCostPrice: 0);
    if (zeroCost <= 0) return 0;

    var low = 0.0;
    var high = 1.0;
    while (overallExpectancy(cases, roundTripCostPrice: high) > 0 &&
        high < 1000) {
      high *= 2;
    }

    for (var i = 0; i < 80; i++) {
      final mid = (low + high) / 2;
      if (overallExpectancy(cases, roundTripCostPrice: mid) > 0) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return (low + high) / 2;
  }
}
