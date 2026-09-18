import 'dart:async';

import 'biquote_closed_candle_boundary.dart';
import 'biquote_market_data.dart';

typedef BiQuoteClosedBarRefresh =
    Future<void> Function(Set<BiQuoteTimeframe> timeframes);

/// Serializes REST closed-bar refreshes requested by SignalR tick boundaries.
///
/// Multiple ticks around the same boundary are coalesced. Strategy evaluation
/// must happen downstream only after the authoritative closed-bar refresh.
final class BiQuoteClosedCandleSync {
  BiQuoteClosedCandleSync({
    required this.refresh,
    BiQuoteClosedCandleBoundary? boundary,
  }) : boundary = boundary ?? BiQuoteClosedCandleBoundary();

  final BiQuoteClosedBarRefresh refresh;
  final BiQuoteClosedCandleBoundary boundary;

  final Set<BiQuoteTimeframe> _pending = {};
  Future<void>? _running;
  bool _disposed = false;

  Future<void> onTick(BiQuoteTick tick) {
    if (_disposed) return Future.value();

    _pending.addAll(boundary.observe(tick.timestamp));
    if (_pending.isEmpty) return _running ?? Future.value();

    return _running ??= _drain();
  }

  Future<void> _drain() async {
    try {
      while (_pending.isNotEmpty && !_disposed) {
        final batch = Set<BiQuoteTimeframe>.from(_pending);
        _pending.clear();
        await refresh(batch);
      }
    } finally {
      _running = null;
    }
  }

  Future<void> flush() => _running ?? Future.value();

  Future<void> dispose() async {
    _disposed = true;
    await flush();
    _pending.clear();
  }
}
