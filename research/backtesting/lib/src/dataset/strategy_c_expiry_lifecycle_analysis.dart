import 'dart:convert';

final class C5ExpiryBar {
  const C5ExpiryBar({
    required this.high,
    required this.low,
    required this.close,
  });

  final double high;
  final double low;
  final double close;

  factory C5ExpiryBar.fromJson(Map<String, dynamic> json) => C5ExpiryBar(
    high: (json['high'] as num).toDouble(),
    low: (json['low'] as num).toDouble(),
    close: (json['close'] as num).toDouble(),
  );
}

final class C5ExpiryPath {
  const C5ExpiryPath({required this.entryClose, required this.bars});

  final double entryClose;
  final List<C5ExpiryBar> bars;

  factory C5ExpiryPath.fromJsonLine(String line) {
    final json = jsonDecode(line) as Map<String, dynamic>;
    final entry = json['entry'] as Map<String, dynamic>;
    return C5ExpiryPath(
      entryClose: (entry['close'] as num).toDouble(),
      bars: (json['forwardBars'] as List<dynamic>)
          .map((e) => C5ExpiryBar.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

enum C5ExpiryOutcome { target, stop, expiry, ambiguous }

final class C5SettledTrade {
  const C5SettledTrade(this.outcome, this.r);

  final C5ExpiryOutcome outcome;
  final double? r;
}

final class C5ExpiryLifecycleResult {
  C5ExpiryLifecycleResult({
    required this.stopDistance,
    required this.rewardMultiple,
  });

  final double stopDistance;
  final double rewardMultiple;
  int target = 0;
  int stop = 0;
  int expiry = 0;
  int ambiguous = 0;
  double settledRSum = 0;
  int settled = 0;

  double get expectancyR => settled == 0 ? 0 : settledRSum / settled;
  double get settledPositiveRate => settled == 0 ? 0 : _positive / settled;
  int _positive = 0;

  void add(C5SettledTrade trade) {
    switch (trade.outcome) {
      case C5ExpiryOutcome.target:
        target++;
      case C5ExpiryOutcome.stop:
        stop++;
      case C5ExpiryOutcome.expiry:
        expiry++;
      case C5ExpiryOutcome.ambiguous:
        ambiguous++;
    }
    if (trade.r != null) {
      settled++;
      settledRSum += trade.r!;
      if (trade.r! > 0) _positive++;
    }
  }
}

final class C5ExpiryLifecycleAnalysis {
  const C5ExpiryLifecycleAnalysis();

  C5SettledTrade settle(
    C5ExpiryPath path, {
    required double stopDistance,
    required double rewardMultiple,
  }) {
    final stop = path.entryClose - stopDistance;
    final target = path.entryClose + stopDistance * rewardMultiple;

    for (final bar in path.bars) {
      final hitStop = bar.low <= stop;
      final hitTarget = bar.high >= target;
      if (hitStop && hitTarget) {
        return const C5SettledTrade(C5ExpiryOutcome.ambiguous, null);
      }
      if (hitStop) return const C5SettledTrade(C5ExpiryOutcome.stop, -1);
      if (hitTarget) {
        return C5SettledTrade(C5ExpiryOutcome.target, rewardMultiple);
      }
    }

    final expiryR = (path.bars.last.close - path.entryClose) / stopDistance;
    final boundedR = expiryR.clamp(-1.0, rewardMultiple).toDouble();
    return C5SettledTrade(C5ExpiryOutcome.expiry, boundedR);
  }

  C5ExpiryLifecycleResult evaluate(
    List<C5ExpiryPath> paths, {
    required double stopDistance,
    required double rewardMultiple,
  }) {
    final result = C5ExpiryLifecycleResult(
      stopDistance: stopDistance,
      rewardMultiple: rewardMultiple,
    );
    for (final path in paths) {
      result.add(
        settle(
          path,
          stopDistance: stopDistance,
          rewardMultiple: rewardMultiple,
        ),
      );
    }
    return result;
  }
}
