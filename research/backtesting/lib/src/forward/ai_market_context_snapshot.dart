import 'biquote_live_market_snapshot.dart';
import 'biquote_market_data.dart';

/// Compact deterministic context for AI review. No future bars and no AI
/// inference are used to build these features.
final class AiMarketContextSnapshot {
  const AiMarketContextSnapshot({
    required this.observedAt,
    required this.timeframes,
  });

  final DateTime observedAt;
  final Map<String, Map<String, Object?>> timeframes;

  factory AiMarketContextSnapshot.fromLive(BiQuoteLiveMarketSnapshot snapshot) {
    return AiMarketContextSnapshot(
      observedAt: snapshot.observedAt.toUtc(),
      timeframes: <String, Map<String, Object?>>{
        'M5': _summarize(snapshot.m5),
        'M15': _summarize(snapshot.m15),
        'H1': _summarize(snapshot.h1),
        'H4': _summarize(snapshot.h4),
      },
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'observedAt': observedAt.toIso8601String(),
    'timeframes': timeframes,
  };

  static Map<String, Object?> _summarize(List<BiQuoteClosedBar> bars) {
    if (bars.isEmpty) return const <String, Object?>{'available': false};
    final latest = bars.last;
    final window = bars.length > 14 ? bars.sublist(bars.length - 14) : bars;
    final first = window.first.close;
    final change = first == 0 ? 0.0 : (latest.close - first) / first;
    final averageRange =
        window.fold<double>(0, (sum, bar) => sum + (bar.high - bar.low)) /
        window.length;
    final bullishBars = window.where((bar) => bar.close > bar.open).length;
    return <String, Object?>{
      'available': true,
      'bars': window.length,
      'lastCloseTime': latest.closeTime.toUtc().toIso8601String(),
      'lastOpen': latest.open,
      'lastHigh': latest.high,
      'lastLow': latest.low,
      'lastClose': latest.close,
      'windowReturn': change,
      'averageRange': averageRange,
      'bullishFraction': bullishBars / window.length,
      'tickVolume': latest.tickVolume,
    };
  }
}
