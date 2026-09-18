import 'biquote_closed_bar_store.dart';
import 'biquote_market_data.dart';

/// Immutable multi-timeframe CLOSED-bar snapshot for one strategy observation.
///
/// A strategy evaluator gets one snapshot at an M5 close. It cannot see the
/// next open candle or future REST data.
final class BiQuoteLiveMarketSnapshot {
  const BiQuoteLiveMarketSnapshot({
    required this.observedAt,
    required this.m5,
    required this.m15,
    required this.h1,
    required this.h4,
  });

  final DateTime observedAt;
  final List<BiQuoteClosedBar> m5;
  final List<BiQuoteClosedBar> m15;
  final List<BiQuoteClosedBar> h1;
  final List<BiQuoteClosedBar> h4;

  factory BiQuoteLiveMarketSnapshot.fromStore(
    BiQuoteClosedBarStore store, {
    required DateTime observedAt,
  }) {
    List<BiQuoteClosedBar> visible(BiQuoteTimeframe timeframe) =>
        List<BiQuoteClosedBar>.unmodifiable(
          store
              .barsFor(timeframe)
              .where((bar) => !bar.closeTime.isAfter(observedAt.toUtc())),
        );

    return BiQuoteLiveMarketSnapshot(
      observedAt: observedAt.toUtc(),
      m5: visible(BiQuoteTimeframe.m5),
      m15: visible(BiQuoteTimeframe.m15),
      h1: visible(BiQuoteTimeframe.h1),
      h4: visible(BiQuoteTimeframe.h4),
    );
  }

  bool get hasMinimumTimeframes =>
      m5.isNotEmpty && m15.isNotEmpty && h1.isNotEmpty && h4.isNotEmpty;
}
