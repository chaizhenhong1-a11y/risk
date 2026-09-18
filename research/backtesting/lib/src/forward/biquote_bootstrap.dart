import 'biquote_closed_bar_store.dart';
import 'biquote_market_data.dart';
import 'biquote_rest_client.dart';

final class BiQuoteBootstrapReport {
  const BiQuoteBootstrapReport({
    required this.receivedClosedBars,
    required this.ignoredOpenBars,
    required this.addedClosedBars,
    required this.duplicates,
  });

  final int receivedClosedBars;
  final int ignoredOpenBars;
  final int addedClosedBars;
  final int duplicates;
}

/// Loads a bounded closed-candle warmup for the four TradeForge timeframes.
///
/// This is intentionally bounded; it does not replay the old 100k-candle
/// research history on every startup.
final class BiQuoteBootstrap {
  const BiQuoteBootstrap();

  Future<BiQuoteBootstrapReport> load({
    required BiQuoteRestClient client,
    required BiQuoteClosedBarStore store,
    String symbol = 'XAUUSD',
    int limitPerTimeframe = 500,
  }) async {
    var received = 0;
    var ignoredOpen = 0;
    var added = 0;

    for (final timeframe in BiQuoteTimeframe.values) {
      final response = await client.closedBars(
        symbol: symbol,
        timeframe: timeframe,
        limit: limitPerTimeframe,
      );
      received += response.closedBars.length;
      ignoredOpen += response.openBars;
      added += store.addAll(response.closedBars);
    }

    return BiQuoteBootstrapReport(
      receivedClosedBars: received,
      ignoredOpenBars: ignoredOpen,
      addedClosedBars: added,
      duplicates: received - added,
    );
  }
}
