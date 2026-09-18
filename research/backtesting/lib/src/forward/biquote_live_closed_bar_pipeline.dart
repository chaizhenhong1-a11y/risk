import 'dart:async';

import 'biquote_closed_bar_store.dart';
import 'biquote_closed_candle_sync.dart';
import 'biquote_market_data.dart';
import 'biquote_rest_client.dart';

final class BiQuoteLiveClosedBarBatch {
  const BiQuoteLiveClosedBarBatch({
    required this.triggeredBy,
    required this.added,
    required this.duplicates,
    required this.openIgnored,
  });

  final Set<BiQuoteTimeframe> triggeredBy;
  final int added;
  final int duplicates;
  final int openIgnored;
}

/// Refreshes authoritative CLOSED OHLC after SignalR crosses a candle boundary.
///
/// Tick-built OHLC is deliberately forbidden from the strategy path.
/// Reconnect/boundary backfills are idempotent through the closed-bar store.
final class BiQuoteLiveClosedBarPipeline {
  BiQuoteLiveClosedBarPipeline({
    required this.client,
    required this.store,
    this.symbol = 'XAUUSD',
    this.refreshLimit = 100,
  }) : sync = BiQuoteClosedCandleSync(refresh: (timeframes) async {}) {
    sync = BiQuoteClosedCandleSync(refresh: _refresh);
  }

  final BiQuoteRestClient client;
  final BiQuoteClosedBarStore store;
  final String symbol;
  final int refreshLimit;

  BiQuoteClosedCandleSync sync;
  final StreamController<BiQuoteLiveClosedBarBatch> _batches =
      StreamController<BiQuoteLiveClosedBarBatch>.broadcast();

  Stream<BiQuoteLiveClosedBarBatch> get batches => _batches.stream;

  Future<void> onTick(BiQuoteTick tick) => sync.onTick(tick);

  Future<void> _refresh(Set<BiQuoteTimeframe> timeframes) async {
    var added = 0;
    var received = 0;
    var openIgnored = 0;

    for (final timeframe in timeframes) {
      final response = await client.closedBars(
        symbol: symbol,
        timeframe: timeframe,
        limit: refreshLimit,
      );
      received += response.closedBars.length;
      openIgnored += response.openBars;
      added += store.addAll(response.closedBars);
    }

    if (!_batches.isClosed) {
      _batches.add(
        BiQuoteLiveClosedBarBatch(
          triggeredBy: Set<BiQuoteTimeframe>.unmodifiable(timeframes),
          added: added,
          duplicates: received - added,
          openIgnored: openIgnored,
        ),
      );
    }
  }

  Future<void> dispose() async {
    await sync.dispose();
    await _batches.close();
  }
}
