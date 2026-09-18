DateTime _parseBiQuoteNativeTime(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) {
    throw const FormatException('BiQuote native timestamp is missing');
  }

  final value = raw.trim();
  final iso = DateTime.tryParse(value);
  if (iso != null) return iso;

  final match = RegExp(
    r'^(\d{4})\.(\d{2})\.(\d{2})[ T](\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?$',
  ).firstMatch(value);
  if (match == null) {
    throw FormatException('Unsupported BiQuote native timestamp: $value');
  }

  int part(int group) => int.parse(match.group(group)!);
  final fraction = match.group(7);
  final paddedFraction = fraction == null ? null : '${fraction}000000';
  final microsecond = paddedFraction == null
      ? 0
      : int.parse(paddedFraction.substring(0, 6));

  return DateTime(
    part(1),
    part(2),
    part(3),
    part(4),
    part(5),
    part(6),
    microsecond ~/ 1000,
    microsecond % 1000,
  );
}

DateTime _parseBiQuoteUtcTimestamp(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) {
    throw const FormatException('BiQuote UTC timestamp is missing');
  }
  final parsed = DateTime.tryParse(raw.trim());
  if (parsed == null) {
    throw FormatException('Unsupported BiQuote UTC timestamp: $raw');
  }
  return parsed.toUtc();
}

final class BiQuoteTick {
  const BiQuoteTick({
    required this.symbol,
    required this.bid,
    required this.ask,
    required this.timestamp,
    required this.nativeTime,
    required this.source,
    this.marketState,
    this.stale,
    this.quoteAgeSeconds,
  });

  final String symbol;
  final double bid;
  final double ask;

  /// Canonical program timestamp supplied by BiQuote, normalized to UTC.
  final DateTime timestamp;

  /// MT5-native wall-clock value retained only for diagnostics/display.
  final DateTime nativeTime;

  final String source;

  /// REST quote-health metadata. SignalR ReceiveTick may omit these fields.
  final String? marketState;
  final bool? stale;
  final int? quoteAgeSeconds;

  bool get hasRestHealthMetadata =>
      marketState != null && stale != null && quoteAgeSeconds != null;

  double get mid => (bid + ask) / 2;

  factory BiQuoteTick.fromJson(Map<String, dynamic> json) => BiQuoteTick(
    symbol: json['symbol'] as String,
    bid: (json['bid'] as num).toDouble(),
    ask: (json['ask'] as num).toDouble(),
    timestamp: _parseBiQuoteUtcTimestamp(json['timestamp']),
    nativeTime: _parseBiQuoteNativeTime(json['time']),
    source: (json['source'] as String?) ?? 'unknown',
    marketState: json['marketState'] as String?,
    stale: json['stale'] as bool?,
    quoteAgeSeconds: (json['quoteAgeSeconds'] as num?)?.toInt(),
  );
}

enum BiQuoteTimeframe {
  m5('5m', Duration(minutes: 5)),
  m15('15m', Duration(minutes: 15)),
  h1('1h', Duration(hours: 1)),
  h4('4h', Duration(hours: 4));

  const BiQuoteTimeframe(this.apiValue, this.duration);

  final String apiValue;
  final Duration duration;
}

final class BiQuoteClosedBar {
  const BiQuoteClosedBar({
    required this.symbol,
    required this.timeframe,
    required this.openTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.tickVolume,
  });

  final String symbol;
  final BiQuoteTimeframe timeframe;
  final DateTime openTime;
  final double open;
  final double high;
  final double low;
  final double close;
  final int tickVolume;

  DateTime get closeTime => openTime.add(timeframe.duration);

  String get id =>
      '$symbol|${timeframe.apiValue}|${openTime.toIso8601String()}';
}

final class BiQuoteOhlcResponse {
  const BiQuoteOhlcResponse({required this.closedBars, required this.openBars});

  final List<BiQuoteClosedBar> closedBars;
  final int openBars;
}

final class BiQuoteOhlcParser {
  const BiQuoteOhlcParser();

  BiQuoteOhlcResponse parse(
    Map<String, dynamic> json, {
    required BiQuoteTimeframe timeframe,
  }) {
    final symbol = json['symbol'] as String;
    final rawBars = json['bars'];
    if (rawBars is! List) {
      throw const FormatException('BiQuote OHLC response is missing bars');
    }

    final closed = <BiQuoteClosedBar>[];
    var openBars = 0;
    for (final raw in rawBars) {
      if (raw is! Map) {
        throw const FormatException('Invalid BiQuote OHLC bar');
      }
      final bar = Map<String, dynamic>.from(raw);
      if (bar['isOpen'] == true) {
        openBars++;
        continue;
      }
      closed.add(
        BiQuoteClosedBar(
          symbol: symbol,
          timeframe: timeframe,
          openTime: _parseBiQuoteUtcTimestamp(bar['openTime']),
          open: (bar['open'] as num).toDouble(),
          high: (bar['high'] as num).toDouble(),
          low: (bar['low'] as num).toDouble(),
          close: (bar['close'] as num).toDouble(),
          tickVolume: ((bar['tickVolume'] as num?) ?? 0).toInt(),
        ),
      );
    }

    closed.sort((a, b) => a.openTime.compareTo(b.openTime));
    return BiQuoteOhlcResponse(closedBars: closed, openBars: openBars);
  }
}
