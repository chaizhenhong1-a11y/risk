import 'signal_history_view.dart';

enum PerformanceEvidenceLayer { productionForward, paperForward, historical }

class PerformanceMetricsView {
  const PerformanceMetricsView({
    required this.trades,
    required this.wins,
    required this.losses,
    required this.breakEven,
    required this.totalR,
    required this.maxDrawdownR,
  });

  final int trades;
  final int wins;
  final int losses;
  final int breakEven;
  final double totalR;
  final double maxDrawdownR;

  int get decidedTrades => wins + losses;
  double? get winRate => decidedTrades == 0 ? null : wins / decidedTrades * 100;
  double? get expectancyR => trades == 0 ? null : totalR / trades;

  static PerformanceMetricsView fromHistory(
    Iterable<SignalHistoryView> history,
  ) {
    final resolved = history
        .where(
          (item) =>
              item.independentEvidence &&
              !item.isSameExposure &&
              item.realizedR != null &&
              item.realizedR!.isFinite,
        )
        .toList()
      ..sort((a, b) => a.observedAt.compareTo(b.observedAt));

    var wins = 0;
    var losses = 0;
    var breakEven = 0;
    var totalR = 0.0;
    var equity = 0.0;
    var peak = 0.0;
    var maxDrawdown = 0.0;

    for (final item in resolved) {
      final r = item.realizedR!;
      if (r > 0) {
        wins++;
      } else if (r < 0) {
        losses++;
      } else {
        breakEven++;
      }
      totalR += r;
      equity += r;
      if (equity > peak) peak = equity;
      final drawdown = peak - equity;
      if (drawdown > maxDrawdown) maxDrawdown = drawdown;
    }

    return PerformanceMetricsView(
      trades: resolved.length,
      wins: wins,
      losses: losses,
      breakEven: breakEven,
      totalR: totalR,
      maxDrawdownR: maxDrawdown,
    );
  }
}

class HistoricalPerformanceSnapshot {
  const HistoricalPerformanceSnapshot({
    required this.strategy,
    required this.trades,
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.expectancyR,
    required this.profitFactor,
    required this.note,
  });

  final String strategy;
  final int trades;
  final int wins;
  final int losses;
  final double winRate;
  final double expectancyR;
  final double profitFactor;
  final String note;
}

/// Frozen values from the already-completed 2024–2026 historical audits.
/// They are display-only baseline evidence and are never merged with forward
/// performance.
const historicalPerformanceBaseline = <HistoricalPerformanceSnapshot>[
  HistoricalPerformanceSnapshot(
    strategy: 'A',
    trades: 87,
    wins: 35,
    losses: 52,
    winRate: 40.23,
    expectancyR: 0.455,
    profitFactor: 1.762,
    note: 'PASS',
  ),
  HistoricalPerformanceSnapshot(
    strategy: 'B',
    trades: 4,
    wins: 0,
    losses: 4,
    winRate: 0,
    expectancyR: -1,
    profitFactor: 0,
    note: 'RESEARCH · 样本不足',
  ),
  HistoricalPerformanceSnapshot(
    strategy: 'C5',
    trades: 108,
    wins: 44,
    losses: 64,
    winRate: 40.74,
    expectancyR: 0.222,
    profitFactor: 1.375,
    note: 'PASS · 另有 49 expired',
  ),
];

class HistoricalPaperYearSnapshot {
  const HistoricalPaperYearSnapshot({
    required this.year,
    required this.trades,
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.expectancyR,
    required this.profitFactor,
    required this.totalR,
    required this.maxDrawdownR,
  });

  final int year;
  final int trades;
  final int wins;
  final int losses;
  final double winRate;
  final double expectancyR;
  final double profitFactor;
  final double totalR;
  final double maxDrawdownR;
}

class HistoricalPaperSegmentSnapshot {
  const HistoricalPaperSegmentSnapshot({
    required this.strategy,
    required this.side,
    required this.regime,
    required this.trades,
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.expectancyR,
    required this.profitFactor,
    required this.totalR,
    required this.maxDrawdownR,
    required this.yearly,
  });

  final String strategy;
  final String side;
  final String regime;
  final int trades;
  final int wins;
  final int losses;
  final double winRate;
  final double expectancyR;
  final double profitFactor;
  final double totalR;
  final double maxDrawdownR;
  final List<HistoricalPaperYearSnapshot> yearly;
}

/// Frozen display baseline produced by Increment 220 from
/// XAUUSD_M5_2024_2026.csv. These values are historical evidence only and are
/// never merged with Paper Forward or Production Forward performance.
const historicalPaperSegmentBaseline = <HistoricalPaperSegmentSnapshot>[
  HistoricalPaperSegmentSnapshot(
    strategy: 'ATR_EXPANSION',
    side: 'BUY',
    regime: 'TREND',
    trades: 347,
    wins: 130,
    losses: 217,
    winRate: 37.46,
    expectancyR: 0.124,
    profitFactor: 1.198,
    totalR: 43,
    maxDrawdownR: 16,
    yearly: [
      HistoricalPaperYearSnapshot(
          year: 2025,
          trades: 181,
          wins: 68,
          losses: 113,
          winRate: 37.57,
          expectancyR: 0.127,
          profitFactor: 1.204,
          totalR: 23,
          maxDrawdownR: 16),
      HistoricalPaperYearSnapshot(
          year: 2026,
          trades: 166,
          wins: 62,
          losses: 104,
          winRate: 37.35,
          expectancyR: 0.120,
          profitFactor: 1.192,
          totalR: 20,
          maxDrawdownR: 11),
    ],
  ),
  HistoricalPaperSegmentSnapshot(
    strategy: 'TREND_PULLBACK',
    side: 'SELL',
    regime: 'RANGE',
    trades: 3314,
    wins: 1200,
    losses: 2114,
    winRate: 36.21,
    expectancyR: 0.086,
    profitFactor: 1.135,
    totalR: 286,
    maxDrawdownR: 62,
    yearly: [
      HistoricalPaperYearSnapshot(
          year: 2025,
          trades: 1588,
          wins: 564,
          losses: 1024,
          winRate: 35.52,
          expectancyR: 0.065,
          profitFactor: 1.102,
          totalR: 104,
          maxDrawdownR: 36),
      HistoricalPaperYearSnapshot(
          year: 2026,
          trades: 1726,
          wins: 636,
          losses: 1090,
          winRate: 36.85,
          expectancyR: 0.105,
          profitFactor: 1.167,
          totalR: 182,
          maxDrawdownR: 38),
    ],
  ),
  HistoricalPaperSegmentSnapshot(
    strategy: 'LIQ_SWEEP',
    side: 'SELL',
    regime: 'RANGE',
    trades: 1902,
    wins: 683,
    losses: 1219,
    winRate: 35.91,
    expectancyR: 0.077,
    profitFactor: 1.121,
    totalR: 147,
    maxDrawdownR: 39,
    yearly: [
      HistoricalPaperYearSnapshot(
          year: 2025,
          trades: 986,
          wins: 350,
          losses: 636,
          winRate: 35.50,
          expectancyR: 0.065,
          profitFactor: 1.101,
          totalR: 64,
          maxDrawdownR: 39),
      HistoricalPaperYearSnapshot(
          year: 2026,
          trades: 916,
          wins: 333,
          losses: 583,
          winRate: 36.35,
          expectancyR: 0.091,
          profitFactor: 1.142,
          totalR: 83,
          maxDrawdownR: 18),
    ],
  ),
  HistoricalPaperSegmentSnapshot(
    strategy: 'ADX_TREND',
    side: 'BUY',
    regime: 'TREND',
    trades: 1743,
    wins: 621,
    losses: 1122,
    winRate: 35.63,
    expectancyR: 0.069,
    profitFactor: 1.107,
    totalR: 120,
    maxDrawdownR: 42,
    yearly: [
      HistoricalPaperYearSnapshot(
          year: 2025,
          trades: 984,
          wins: 349,
          losses: 635,
          winRate: 35.47,
          expectancyR: 0.064,
          profitFactor: 1.099,
          totalR: 63,
          maxDrawdownR: 33),
      HistoricalPaperYearSnapshot(
          year: 2026,
          trades: 759,
          wins: 272,
          losses: 487,
          winRate: 35.84,
          expectancyR: 0.075,
          profitFactor: 1.117,
          totalR: 57,
          maxDrawdownR: 42),
    ],
  ),
  HistoricalPaperSegmentSnapshot(
    strategy: 'EMA_MEAN_REVERT',
    side: 'SELL',
    regime: 'RANGE',
    trades: 1683,
    wins: 579,
    losses: 1104,
    winRate: 34.40,
    expectancyR: 0.032,
    profitFactor: 1.049,
    totalR: 54,
    maxDrawdownR: 38,
    yearly: [
      HistoricalPaperYearSnapshot(
          year: 2025,
          trades: 912,
          wins: 315,
          losses: 597,
          winRate: 34.54,
          expectancyR: 0.036,
          profitFactor: 1.055,
          totalR: 33,
          maxDrawdownR: 30),
      HistoricalPaperYearSnapshot(
          year: 2026,
          trades: 771,
          wins: 264,
          losses: 507,
          winRate: 34.24,
          expectancyR: 0.027,
          profitFactor: 1.041,
          totalR: 21,
          maxDrawdownR: 38),
    ],
  ),
  HistoricalPaperSegmentSnapshot(
    strategy: 'NR7_BREAKOUT',
    side: 'SELL',
    regime: 'RANGE',
    trades: 2091,
    wins: 721,
    losses: 1370,
    winRate: 34.48,
    expectancyR: 0.034,
    profitFactor: 1.053,
    totalR: 72,
    maxDrawdownR: 49,
    yearly: [
      HistoricalPaperYearSnapshot(
          year: 2025,
          trades: 1083,
          wins: 375,
          losses: 708,
          winRate: 34.63,
          expectancyR: 0.039,
          profitFactor: 1.059,
          totalR: 42,
          maxDrawdownR: 41),
      HistoricalPaperYearSnapshot(
          year: 2026,
          trades: 1008,
          wins: 346,
          losses: 662,
          winRate: 34.33,
          expectancyR: 0.030,
          profitFactor: 1.045,
          totalR: 30,
          maxDrawdownR: 45),
    ],
  ),
  HistoricalPaperSegmentSnapshot(
    strategy: 'ENGULFING_REVERSAL',
    side: 'SELL',
    regime: 'RANGE',
    trades: 5723,
    wins: 2016,
    losses: 3707,
    winRate: 35.23,
    expectancyR: 0.057,
    profitFactor: 1.088,
    totalR: 325,
    maxDrawdownR: 105,
    yearly: [
      HistoricalPaperYearSnapshot(
          year: 2025,
          trades: 2433,
          wins: 825,
          losses: 1608,
          winRate: 33.91,
          expectancyR: 0.017,
          profitFactor: 1.026,
          totalR: 42,
          maxDrawdownR: 105),
      HistoricalPaperYearSnapshot(
          year: 2026,
          trades: 3290,
          wins: 1191,
          losses: 2099,
          winRate: 36.20,
          expectancyR: 0.086,
          profitFactor: 1.135,
          totalR: 283,
          maxDrawdownR: 43),
    ],
  ),
  HistoricalPaperSegmentSnapshot(
    strategy: 'ENGULFING_REVERSAL',
    side: 'BUY',
    regime: 'TREND',
    trades: 926,
    wins: 337,
    losses: 589,
    winRate: 36.39,
    expectancyR: 0.092,
    profitFactor: 1.144,
    totalR: 85,
    maxDrawdownR: 22,
    yearly: [
      HistoricalPaperYearSnapshot(
          year: 2025,
          trades: 426,
          wins: 160,
          losses: 266,
          winRate: 37.56,
          expectancyR: 0.127,
          profitFactor: 1.203,
          totalR: 54,
          maxDrawdownR: 21),
      HistoricalPaperYearSnapshot(
          year: 2026,
          trades: 500,
          wins: 177,
          losses: 323,
          winRate: 35.40,
          expectancyR: 0.062,
          profitFactor: 1.096,
          totalR: 31,
          maxDrawdownR: 22),
    ],
  ),
];
