import 'dart:convert';

final class StrategyCTriggerResearchSample {
  const StrategyCTriggerResearchSample({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.previousClose,
    required this.previous2Close,
    required this.previous3Close,
    required this.h4Structure,
    required this.h1Structure,
    required this.m15Structure,
    required this.resistanceSweep,
    required this.return12,
    required this.return24,
    required this.return48,
    required this.mfe48,
    required this.mae48,
  });

  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double previousClose;
  final double previous2Close;
  final double previous3Close;
  final String h4Structure;
  final String h1Structure;
  final String m15Structure;
  final bool resistanceSweep;
  final double? return12;
  final double? return24;
  final double? return48;
  final double? mfe48;
  final double? mae48;

  double get body => (close - open).abs();
  double get range => high - low;
  double get upperWick => high - (open > close ? open : close);
  double get lowerWick => (open < close ? open : close) - low;
  bool get bullish => close > open;
  bool get reclaimPreviousClose => close > previousClose;
  bool get momentum3 =>
      close > previousClose &&
      previousClose > previous2Close &&
      previous2Close > previous3Close;

  String toJsonLine() => jsonEncode({
    'time': time.toIso8601String(),
    'open': open,
    'high': high,
    'low': low,
    'close': close,
    'previousClose': previousClose,
    'previous2Close': previous2Close,
    'previous3Close': previous3Close,
    'body': body,
    'range': range,
    'upperWick': upperWick,
    'lowerWick': lowerWick,
    'bullish': bullish,
    'reclaimPreviousClose': reclaimPreviousClose,
    'momentum3': momentum3,
    'h4Structure': h4Structure,
    'h1Structure': h1Structure,
    'm15Structure': m15Structure,
    'resistanceSweep': resistanceSweep,
    'return12': return12,
    'return24': return24,
    'return48': return48,
    'mfe48': mfe48,
    'mae48': mae48,
  });
}
