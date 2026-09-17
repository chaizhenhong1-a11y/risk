import 'dart:convert';

final class C5PathBar {
  const C5PathBar({
    required this.offset,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  final int offset;
  final double open;
  final double high;
  final double low;
  final double close;

  factory C5PathBar.fromJson(Map<String, dynamic> json) => C5PathBar(
    offset: (json['offset'] as num).toInt(),
    open: (json['open'] as num).toDouble(),
    high: (json['high'] as num).toDouble(),
    low: (json['low'] as num).toDouble(),
    close: (json['close'] as num).toDouble(),
  );
}

final class C5ForwardPath {
  const C5ForwardPath({
    required this.time,
    required this.entryClose,
    required this.bars,
  });

  final DateTime time;
  final double entryClose;
  final List<C5PathBar> bars;

  factory C5ForwardPath.fromJsonLine(String line) {
    final json = jsonDecode(line) as Map<String, dynamic>;
    final entry = json['entry'] as Map<String, dynamic>;
    return C5ForwardPath(
      time: DateTime.parse(json['time'] as String),
      entryClose: (entry['close'] as num).toDouble(),
      bars: (json['forwardBars'] as List<dynamic>)
          .map((e) => C5PathBar.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

final class C5TimingStats {
  const C5TimingStats({
    required this.horizon,
    required this.samples,
    required this.bullishCloseRate,
    required this.averageCloseReturn,
    required this.averageMfe,
    required this.averageMae,
    required this.medianMfe,
    required this.medianMae,
    required this.maeBeforeFirstPositiveCloseMedian,
    required this.firstPositiveCloseMedianOffset,
    required this.noPositiveCloseCount,
  });

  final int horizon;
  final int samples;
  final double bullishCloseRate;
  final double averageCloseReturn;
  final double averageMfe;
  final double averageMae;
  final double medianMfe;
  final double medianMae;
  final double maeBeforeFirstPositiveCloseMedian;
  final double firstPositiveCloseMedianOffset;
  final int noPositiveCloseCount;
}

final class C5EntryTimingAnalysis {
  const C5EntryTimingAnalysis();

  C5TimingStats analyze(List<C5ForwardPath> paths, int horizon) {
    final returns = <double>[];
    final mfes = <double>[];
    final maes = <double>[];
    final firstPositiveOffsets = <double>[];
    final prePositiveMaes = <double>[];
    var bullish = 0;
    var noPositive = 0;

    for (final path in paths) {
      final bars = path.bars.where((b) => b.offset <= horizon).toList();
      if (bars.length < horizon) continue;

      final origin = path.entryClose;
      final closeReturn = bars.last.close - origin;
      returns.add(closeReturn);
      if (closeReturn > 0) bullish++;

      var maxHigh = bars.first.high;
      var minLow = bars.first.low;
      for (final bar in bars) {
        if (bar.high > maxHigh) maxHigh = bar.high;
        if (bar.low < minLow) minLow = bar.low;
      }
      mfes.add(maxHigh - origin);
      maes.add(origin - minLow);

      C5PathBar? firstPositive;
      for (final bar in bars) {
        if (bar.close > origin) {
          firstPositive = bar;
          break;
        }
      }

      if (firstPositive == null) {
        noPositive++;
      } else {
        firstPositiveOffsets.add(firstPositive.offset.toDouble());
        var preMin = origin;
        for (final bar in bars) {
          if (bar.offset > firstPositive.offset) break;
          if (bar.low < preMin) preMin = bar.low;
        }
        prePositiveMaes.add(origin - preMin);
      }
    }

    double avg(List<double> xs) =>
        xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
    double median(List<double> xs) {
      if (xs.isEmpty) return 0;
      final sorted = [...xs]..sort();
      final middle = sorted.length ~/ 2;
      return sorted.length.isOdd
          ? sorted[middle]
          : (sorted[middle - 1] + sorted[middle]) / 2;
    }

    return C5TimingStats(
      horizon: horizon,
      samples: returns.length,
      bullishCloseRate: returns.isEmpty ? 0 : bullish / returns.length,
      averageCloseReturn: avg(returns),
      averageMfe: avg(mfes),
      averageMae: avg(maes),
      medianMfe: median(mfes),
      medianMae: median(maes),
      maeBeforeFirstPositiveCloseMedian: median(prePositiveMaes),
      firstPositiveCloseMedianOffset: median(firstPositiveOffsets),
      noPositiveCloseCount: noPositive,
    );
  }
}
