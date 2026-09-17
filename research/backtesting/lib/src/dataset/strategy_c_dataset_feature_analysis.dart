import 'dart:convert';

final class StrategyCDatasetRow {
  const StrategyCDatasetRow({
    required this.h4,
    required this.h1,
    required this.m15,
    required this.sweep,
    required this.return12,
    required this.return24,
    required this.return48,
    required this.mfe48,
    required this.mae48,
  });

  final String h4;
  final String h1;
  final String m15;
  final String sweep;
  final double? return12;
  final double? return24;
  final double? return48;
  final double? mfe48;
  final double? mae48;

  factory StrategyCDatasetRow.fromJsonLine(String line) {
    final json = jsonDecode(line) as Map<String, dynamic>;
    final sweeps = <String>[
      if (json['supportSweep'] == true) 'support',
      if (json['resistanceSweep'] == true) 'resistance',
      if (json['equalLowSweep'] == true) 'equalLow',
      if (json['equalHighSweep'] == true) 'equalHigh',
    ];
    double? number(String key) => (json[key] as num?)?.toDouble();

    return StrategyCDatasetRow(
      h4: json['h4Structure'] as String,
      h1: json['h1Structure'] as String,
      m15: json['m15Structure'] as String,
      sweep: sweeps.isEmpty ? 'none' : sweeps.join('+'),
      return12: number('return12'),
      return24: number('return24'),
      return48: number('return48'),
      mfe48: number('mfe48'),
      mae48: number('mae48'),
    );
  }
}

final class StrategyCFeatureGroup {
  StrategyCFeatureGroup({
    required this.h4,
    required this.h1,
    required this.m15,
    required this.sweep,
  });

  final String h4;
  final String h1;
  final String m15;
  final String sweep;
  int samples = 0;
  int bullish12 = 0;
  int resolved12 = 0;
  int bullish24 = 0;
  int resolved24 = 0;
  int bullish48 = 0;
  int resolved48 = 0;
  double mfeSum = 0;
  double maeSum = 0;
  int excursionCount = 0;

  double bullishShare(int bullish, int resolved) =>
      resolved == 0 ? 0 : bullish / resolved;

  double get avgMfe => excursionCount == 0 ? 0 : mfeSum / excursionCount;
  double get avgMae => excursionCount == 0 ? 0 : maeSum / excursionCount;

  String get key => '$h4|$h1|$m15|$sweep';
}

final class StrategyCDatasetFeatureAnalyzer {
  const StrategyCDatasetFeatureAnalyzer();

  List<StrategyCFeatureGroup> analyze(Iterable<StrategyCDatasetRow> rows) {
    final groups = <String, StrategyCFeatureGroup>{};

    for (final row in rows) {
      final key = '${row.h4}|${row.h1}|${row.m15}|${row.sweep}';
      final group = groups.putIfAbsent(
        key,
        () => StrategyCFeatureGroup(
          h4: row.h4,
          h1: row.h1,
          m15: row.m15,
          sweep: row.sweep,
        ),
      );
      group.samples++;

      void add(double? value, void Function(bool bullish) sink) {
        if (value != null) sink(value > 0);
      }

      add(row.return12, (bullish) {
        group.resolved12++;
        if (bullish) group.bullish12++;
      });
      add(row.return24, (bullish) {
        group.resolved24++;
        if (bullish) group.bullish24++;
      });
      add(row.return48, (bullish) {
        group.resolved48++;
        if (bullish) group.bullish48++;
      });

      if (row.mfe48 != null && row.mae48 != null) {
        group.mfeSum += row.mfe48!;
        group.maeSum += row.mae48!;
        group.excursionCount++;
      }
    }

    final result = groups.values.toList()
      ..sort((a, b) => b.samples.compareTo(a.samples));
    return result;
  }
}
