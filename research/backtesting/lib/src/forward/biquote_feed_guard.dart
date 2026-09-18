import 'biquote_market_data.dart';

enum BiQuoteTickHealth {
  healthy,
  marketClosed,
  stale,
  invalidAge,
  invalidSpread,
  wrongSymbol,
  missingRestHealth,
}

final class BiQuoteTickGuard {
  const BiQuoteTickGuard({
    this.symbol = 'XAUUSD',
    this.maxQuoteAgeSeconds = 30,
    this.maxStreamAge = const Duration(seconds: 10),
  });

  final String symbol;
  final int maxQuoteAgeSeconds;
  final Duration maxStreamAge;

  /// Strict REST health evaluation.
  BiQuoteTickHealth evaluate(BiQuoteTick tick) {
    final mechanical = _mechanical(tick);
    if (mechanical != null) return mechanical;

    final marketState = tick.marketState;
    final stale = tick.stale;
    final quoteAgeSeconds = tick.quoteAgeSeconds;
    if (marketState == null || stale == null || quoteAgeSeconds == null) {
      return BiQuoteTickHealth.missingRestHealth;
    }
    if (marketState.toLowerCase() != 'open') {
      return BiQuoteTickHealth.marketClosed;
    }
    if (stale) return BiQuoteTickHealth.stale;
    if (quoteAgeSeconds < 0 || quoteAgeSeconds > maxQuoteAgeSeconds) {
      return BiQuoteTickHealth.invalidAge;
    }
    return BiQuoteTickHealth.healthy;
  }

  /// SignalR ReceiveTick does not necessarily carry REST-only health fields.
  ///
  /// Stream freshness is based on the server UTC timestamp. Market-open/stale
  /// authority is supplied separately by a recent healthy REST snapshot.
  BiQuoteTickHealth evaluateStream(
    BiQuoteTick tick, {
    required DateTime receivedAtUtc,
    required bool restHealthAllowsStreaming,
  }) {
    final mechanical = _mechanical(tick);
    if (mechanical != null) return mechanical;
    if (!restHealthAllowsStreaming) return BiQuoteTickHealth.stale;

    final received = receivedAtUtc.toUtc();
    final age = received.difference(tick.timestamp.toUtc());
    if (age < const Duration(seconds: -2) || age > maxStreamAge) {
      return BiQuoteTickHealth.invalidAge;
    }
    return BiQuoteTickHealth.healthy;
  }

  BiQuoteTickHealth? _mechanical(BiQuoteTick tick) {
    if (tick.symbol != symbol) return BiQuoteTickHealth.wrongSymbol;
    if (!tick.bid.isFinite ||
        !tick.ask.isFinite ||
        tick.bid <= 0 ||
        tick.ask <= tick.bid) {
      return BiQuoteTickHealth.invalidSpread;
    }
    return null;
  }
}
