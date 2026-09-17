import 'dart:convert';
import 'dart:io';

import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';

final class MarketStructureResearchCacheRow {
  const MarketStructureResearchCacheRow({
    required this.time,
    required this.close,
    required this.h4,
    required this.h1,
    required this.m15,
    required this.regime,
  });

  final DateTime time;
  final double close;
  final MarketStructure h4;
  final MarketStructure h1;
  final MarketStructure m15;
  final MarketRegime regime;

  Map<String, Object> toJson() => {
    'time': time.toUtc().toIso8601String(),
    'close': close,
    'h4': h4.name,
    'h1': h1.name,
    'm15': m15.name,
    'regime': regime.name,
  };

  factory MarketStructureResearchCacheRow.fromJson(Map<String, dynamic> json) =>
      MarketStructureResearchCacheRow(
        time: DateTime.parse(json['time'] as String).toUtc(),
        close: (json['close'] as num).toDouble(),
        h4: MarketStructure.values.byName(json['h4'] as String),
        h1: MarketStructure.values.byName(json['h1'] as String),
        m15: MarketStructure.values.byName(json['m15'] as String),
        regime: MarketRegime.values.byName(json['regime'] as String),
      );
}

final class MarketStructureResearchCache {
  const MarketStructureResearchCache();

  void write(File file, Iterable<MarketStructureResearchCacheRow> rows) {
    file.parent.createSync(recursive: true);

    // Write synchronously so callers can immediately read the completed cache.
    final buffer = StringBuffer();
    for (final row in rows) {
      buffer.writeln(jsonEncode(row.toJson()));
    }
    file.writeAsStringSync(buffer.toString(), flush: true);
  }

  List<MarketStructureResearchCacheRow> read(File file) {
    return file
        .readAsLinesSync()
        .where((line) => line.trim().isNotEmpty)
        .map(
          (line) => MarketStructureResearchCacheRow.fromJson(
            jsonDecode(line) as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
  }
}
