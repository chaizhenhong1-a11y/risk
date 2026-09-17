import 'dart:convert';

final class StrategyCStructuralRiskSample {
  const StrategyCStructuralRiskSample({
    required this.time,
    required this.entryClose,
    required this.m15Atr14,
    required this.supportLowerBound,
    required this.supportUpperBound,
    required this.structureDistance,
    required this.atrBuffer,
    required this.bufferedStopPrice,
    required this.bufferedStopDistance,
  });

  final DateTime time;
  final double entryClose;
  final double m15Atr14;
  final double? supportLowerBound;
  final double? supportUpperBound;
  final double? structureDistance;
  final double atrBuffer;
  final double? bufferedStopPrice;
  final double? bufferedStopDistance;

  bool get hasStructuralSupport =>
      supportLowerBound != null &&
      supportUpperBound != null &&
      structureDistance != null &&
      bufferedStopPrice != null &&
      bufferedStopDistance != null;

  String toJsonLine() => jsonEncode({
    'time': time.toIso8601String(),
    'entryClose': entryClose,
    'm15Atr14': m15Atr14,
    'supportLowerBound': supportLowerBound,
    'supportUpperBound': supportUpperBound,
    'structureDistance': structureDistance,
    'atrBuffer': atrBuffer,
    'bufferedStopPrice': bufferedStopPrice,
    'bufferedStopDistance': bufferedStopDistance,
    'hasStructuralSupport': hasStructuralSupport,
  });
}
