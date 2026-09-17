import 'dart:convert';

final class StrategyCResearchSample {
  const StrategyCResearchSample({
    required this.time,
    required this.close,
    required this.h4Structure,
    required this.h1Structure,
    required this.m15Structure,
    required this.regime,
    required this.supportSweep,
    required this.resistanceSweep,
    required this.equalLowSweep,
    required this.equalHighSweep,
    required this.return12,
    required this.return24,
    required this.return48,
    required this.mfe48,
    required this.mae48,
  });

  final DateTime time;
  final double close;
  final String h4Structure;
  final String h1Structure;
  final String m15Structure;
  final String regime;
  final bool supportSweep;
  final bool resistanceSweep;
  final bool equalLowSweep;
  final bool equalHighSweep;
  final double? return12;
  final double? return24;
  final double? return48;
  final double? mfe48;
  final double? mae48;

  Map<String, Object?> toJson() => {
    'time': time.toIso8601String(),
    'close': close,
    'h4Structure': h4Structure,
    'h1Structure': h1Structure,
    'm15Structure': m15Structure,
    'regime': regime,
    'supportSweep': supportSweep,
    'resistanceSweep': resistanceSweep,
    'equalLowSweep': equalLowSweep,
    'equalHighSweep': equalHighSweep,
    'return12': return12,
    'return24': return24,
    'return48': return48,
    'mfe48': mfe48,
    'mae48': mae48,
  };

  String toJsonLine() => jsonEncode(toJson());
}

final class StrategyCResearchDatasetManifest {
  const StrategyCResearchDatasetManifest({
    required this.schemaVersion,
    required this.symbol,
    required this.sampleCount,
    required this.createdAt,
    required this.note,
  });

  final int schemaVersion;
  final String symbol;
  final int sampleCount;
  final DateTime createdAt;
  final String note;

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert({
    'schemaVersion': schemaVersion,
    'symbol': symbol,
    'sampleCount': sampleCount,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'note': note,
  });
}
