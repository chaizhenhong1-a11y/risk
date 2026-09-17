import 'dart:convert';

final class C5StructuralRisk {
  const C5StructuralRisk({
    required this.time,
    required this.entryClose,
    required this.m15Atr14,
    required this.supportLowerBound,
    required this.bufferedStopPrice,
    required this.bufferedStopDistance,
  });

  final DateTime time;
  final double entryClose;
  final double m15Atr14;
  final double supportLowerBound;
  final double bufferedStopPrice;
  final double bufferedStopDistance;

  factory C5StructuralRisk.fromJsonLine(String line) {
    final json = jsonDecode(line) as Map<String, dynamic>;
    return C5StructuralRisk(
      time: DateTime.parse(json['time'] as String),
      entryClose: (json['entryClose'] as num).toDouble(),
      m15Atr14: (json['m15Atr14'] as num).toDouble(),
      supportLowerBound: (json['supportLowerBound'] as num).toDouble(),
      bufferedStopPrice: (json['bufferedStopPrice'] as num).toDouble(),
      bufferedStopDistance: (json['bufferedStopDistance'] as num).toDouble(),
    );
  }
}

final class C5StructuralBar {
  const C5StructuralBar({
    required this.high,
    required this.low,
    required this.close,
  });

  final double high;
  final double low;
  final double close;

  factory C5StructuralBar.fromJson(Map<String, dynamic> json) =>
      C5StructuralBar(
        high: (json['high'] as num).toDouble(),
        low: (json['low'] as num).toDouble(),
        close: (json['close'] as num).toDouble(),
      );
}

final class C5StructuralPath {
  const C5StructuralPath({
    required this.time,
    required this.entryClose,
    required this.bars,
  });

  final DateTime time;
  final double entryClose;
  final List<C5StructuralBar> bars;

  factory C5StructuralPath.fromJsonLine(String line) {
    final json = jsonDecode(line) as Map<String, dynamic>;
    final entry = json['entry'] as Map<String, dynamic>;
    return C5StructuralPath(
      time: DateTime.parse(json['time'] as String),
      entryClose: (entry['close'] as num).toDouble(),
      bars: (json['forwardBars'] as List<dynamic>)
          .map((e) => C5StructuralBar.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

final class C5StructuralCase {
  const C5StructuralCase({required this.risk, required this.path});

  final C5StructuralRisk risk;
  final C5StructuralPath path;
}

enum C5StructuralOutcome { target, stop, expiry, ambiguous }

final class C5StructuralSettlement {
  const C5StructuralSettlement(this.outcome, this.r);

  final C5StructuralOutcome outcome;
  final double? r;
}

final class C5StructuralWindowResult {
  C5StructuralWindowResult({
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

  void add(C5StructuralSettlement settlement) {
    switch (settlement.outcome) {
      case C5StructuralOutcome.target:
        target++;
      case C5StructuralOutcome.stop:
        stop++;
      case C5StructuralOutcome.expiry:
        expiry++;
      case C5StructuralOutcome.ambiguous:
        ambiguous++;
    }

    final r = settlement.r;
    if (r != null) {
      settled++;
      rSum += r;
      if (r > 0) positive++;
    }
  }
}

final class C5StructuralLifecycleValidation {
  const C5StructuralLifecycleValidation();

  List<C5StructuralCase> join({
    required List<C5StructuralRisk> risks,
    required List<C5StructuralPath> paths,
  }) {
    String key(DateTime time) => time.toIso8601String();
    final pathsByTime = {for (final path in paths) key(path.time): path};

    final result = <C5StructuralCase>[];
    for (final risk in risks) {
      final path = pathsByTime[key(risk.time)];
      if (path == null) continue;
      result.add(C5StructuralCase(risk: risk, path: path));
    }
    result.sort((a, b) => a.risk.time.compareTo(b.risk.time));
    return result;
  }

  C5StructuralSettlement settle(
    C5StructuralCase sample,
    double rewardMultiple,
  ) {
    final entry = sample.risk.entryClose;
    final distance = sample.risk.bufferedStopDistance;
    final stop = sample.risk.bufferedStopPrice;
    final target = entry + distance * rewardMultiple;

    for (final bar in sample.path.bars) {
      final hitStop = bar.low <= stop;
      final hitTarget = bar.high >= target;

      if (hitStop && hitTarget) {
        return const C5StructuralSettlement(
          C5StructuralOutcome.ambiguous,
          null,
        );
      }
      if (hitStop) {
        return const C5StructuralSettlement(C5StructuralOutcome.stop, -1);
      }
      if (hitTarget) {
        return C5StructuralSettlement(
          C5StructuralOutcome.target,
          rewardMultiple,
        );
      }
    }

    final expiryR = (sample.path.bars.last.close - entry) / distance;
    return C5StructuralSettlement(
      C5StructuralOutcome.expiry,
      expiryR.clamp(-1.0, rewardMultiple).toDouble(),
    );
  }

  List<C5StructuralWindowResult> evaluateFiveWindows(
    List<C5StructuralCase> input,
    double rewardMultiple,
  ) {
    final cases = [...input]
      ..sort((a, b) => a.risk.time.compareTo(b.risk.time));
    final results = <C5StructuralWindowResult>[];

    for (var window = 0; window < 5; window++) {
      final startIndex = (cases.length * window / 5).floor();
      final endIndex = (cases.length * (window + 1) / 5).floor();
      final slice = cases.sublist(startIndex, endIndex);
      if (slice.isEmpty) continue;

      final result = C5StructuralWindowResult(
        window: window + 1,
        start: slice.first.risk.time,
        end: slice.last.risk.time,
        samples: slice.length,
      );

      for (final sample in slice) {
        result.add(settle(sample, rewardMultiple));
      }
      results.add(result);
    }

    return results;
  }
}
