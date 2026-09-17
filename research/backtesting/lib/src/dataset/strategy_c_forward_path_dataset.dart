import 'dart:convert';

final class StrategyCForwardBar {
  const StrategyCForwardBar({
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

  Map<String, Object> toJson() => {
    'offset': offset,
    'open': open,
    'high': high,
    'low': low,
    'close': close,
  };
}

final class StrategyCForwardPathEpisode {
  const StrategyCForwardPathEpisode({
    required this.time,
    required this.entryOpen,
    required this.entryHigh,
    required this.entryLow,
    required this.entryClose,
    required this.forwardBars,
  });

  final DateTime time;
  final double entryOpen;
  final double entryHigh;
  final double entryLow;
  final double entryClose;
  final List<StrategyCForwardBar> forwardBars;

  String toJsonLine() => jsonEncode({
    'time': time.toIso8601String(),
    'entry': {
      'open': entryOpen,
      'high': entryHigh,
      'low': entryLow,
      'close': entryClose,
    },
    'forwardBars': forwardBars.map((bar) => bar.toJson()).toList(),
  });
}
