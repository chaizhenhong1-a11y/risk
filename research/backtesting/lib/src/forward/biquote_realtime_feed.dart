import 'biquote_bootstrap.dart';
import 'biquote_closed_bar_store.dart';
import 'biquote_feed_guard.dart';
import 'biquote_market_data.dart';
import 'biquote_rest_client.dart';
import 'biquote_signalr_client.dart';

final class BiQuoteRealtimeFeed {
  BiQuoteRealtimeFeed({
    BiQuoteRestClient? restClient,
    BiQuoteSignalRClient? streamClient,
    BiQuoteClosedBarStore? store,
    this.guard = const BiQuoteTickGuard(),
  }) : restClient = restClient ?? BiQuoteRestClient(),
       streamClient = streamClient ?? BiQuoteSignalRClient(),
       store = store ?? BiQuoteClosedBarStore();

  final BiQuoteRestClient restClient;
  final BiQuoteSignalRClient streamClient;
  final BiQuoteClosedBarStore store;
  final BiQuoteTickGuard guard;

  Stream<BiQuoteTick> get ticks => streamClient.ticks;
  Stream<BiQuoteStreamState> get states => streamClient.states;
  Stream<BiQuoteSignalRDiagnostic> get diagnostics => streamClient.diagnostics;

  Future<BiQuoteBootstrapReport> start({
    String symbol = 'XAUUSD',
    int warmupPerTimeframe = 500,
  }) async {
    // REST is authoritative for market-open/stale metadata before the stream
    // is allowed to feed TradeForge.
    final restTick = await restClient.latestTick(symbol);
    final restHealth = guard.evaluate(restTick);
    streamClient.setRestHealthAllowed(restHealth == BiQuoteTickHealth.healthy);

    final report = await const BiQuoteBootstrap().load(
      client: restClient,
      store: store,
      symbol: symbol,
      limitPerTimeframe: warmupPerTimeframe,
    );
    await streamClient.start();
    return report;
  }

  Future<BiQuoteBootstrapReport> recover({
    String symbol = 'XAUUSD',
    int barsPerTimeframe = 100,
  }) async {
    final restTick = await restClient.latestTick(symbol);
    final restHealth = guard.evaluate(restTick);
    streamClient.setRestHealthAllowed(restHealth == BiQuoteTickHealth.healthy);

    return const BiQuoteBootstrap().load(
      client: restClient,
      store: store,
      symbol: symbol,
      limitPerTimeframe: barsPerTimeframe,
    );
  }

  Future<void> dispose() async {
    await streamClient.dispose();
    restClient.close();
  }
}
