import 'dart:convert';
import 'dart:io';

/// Increment 145 fast fix.
///
/// This runner intentionally DOES NOT replay the 100,049 M5 candles.
/// It reuses Increment 131's persisted market-structure cache and reports
/// where A/C5 do not currently provide validated strategy coverage.
///
/// Important: this is a research-priority map, not a per-trade gate.
void main(List<String> arguments) {
  final cachePath = arguments.isEmpty
      ? '.research_cache${Platform.pathSeparator}market_structure'
            '${Platform.pathSeparator}xauusd_market_structure.jsonl'
      : arguments.single;

  if (arguments.length > 1) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_real_market_opportunity_coverage.dart '
      '[market-structure-cache.jsonl]',
    );
    exitCode = 64;
    return;
  }

  final file = File(cachePath);
  if (!file.existsSync()) {
    stderr.writeln('Market-structure cache not found: ${file.path}');
    stderr.writeln(
      'Increment 145 fast mode never silently rebuilds the 100k replay. '
      'Restore/generate the Increment 131 cache first.',
    );
    exitCode = 66;
    return;
  }

  stdout.writeln('TradeForge V2 — Increment 145 Fast Coverage Map');
  stdout.writeln('Reading cached structure only: ${file.path}');

  final counts = <_State, int>{for (final state in _State.values) state: 0};
  var rows = 0;
  var skipped = 0;

  for (final line in file.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    rows++;

    final json = jsonDecode(line) as Map<String, dynamic>;
    final h4 = _readStructure(json, const [
      'h4Structure',
      'h4_structure',
      'h4',
    ]);
    final h1 = _readStructure(json, const [
      'h1Structure',
      'h1_structure',
      'h1',
    ]);

    if (h4 == null || h1 == null) {
      skipped++;
      if (skipped == 1) {
        stderr.writeln(
          'Could not read H4/H1 structure from cache row $rows. '
          'Available keys: ${json.keys.join(", ")}',
        );
      }
      continue;
    }

    final state = _classify(h4, h1);
    counts[state] = counts[state]! + 1;
  }

  if (rows == 0 || rows == skipped) {
    stderr.writeln('No usable cached observations. Nothing was recomputed.');
    exitCode = 65;
    return;
  }

  final usable = rows - skipped;
  final ranked = _State.values.toList()
    ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

  stdout.writeln('');
  stdout.writeln('State       | Observations | Share    | Validated source');
  stdout.writeln('------------|--------------|----------|-----------------');

  for (final state in ranked) {
    final count = counts[state]!;
    if (count == 0) continue;
    final share = count / usable * 100;
    stdout.writeln(
      '${state.name.padRight(11)} | '
      '${count.toString().padLeft(12)} | '
      '${share.toStringAsFixed(2).padLeft(7)}% | '
      '${_validatedSource(state)}',
    );
  }

  stdout.writeln('');
  stdout.writeln('Cache rows: $rows');
  stdout.writeln('Usable rows: $usable');
  stdout.writeln('Skipped rows: $skipped');
  stdout.writeln('');
  stdout.writeln(
    'Research rule: prioritize large states without a historical-PASS '
    'strategy. Do not loosen A or C5 and do not turn this map into a gate.',
  );
  stdout.writeln(
    'A remains the validated trend source. C5 remains a validated '
    'transition setup, but it does not imply that all transition '
    'observations are covered.',
  );
}

enum _Structure { bullish, bearish, neutral, unknown }

enum _State { trend, correction, transition, range, unknown }

_State _classify(_Structure h4, _Structure h1) {
  if (h4 == _Structure.unknown || h1 == _Structure.unknown) {
    return _State.unknown;
  }

  if ((h4 == _Structure.bullish && h1 == _Structure.bullish) ||
      (h4 == _Structure.bearish && h1 == _Structure.bearish)) {
    return _State.trend;
  }

  if ((h4 == _Structure.bullish && h1 == _Structure.bearish) ||
      (h4 == _Structure.bearish && h1 == _Structure.bullish)) {
    return _State.correction;
  }

  // Increment 131 is a close-only structure cache. Without the live
  // classifier's explicit range evidence, neutral combinations must not be
  // mislabeled as range. Keep them in transition for research discovery.
  if (h4 == _Structure.neutral || h1 == _Structure.neutral) {
    return _State.transition;
  }

  return _State.unknown;
}

String _validatedSource(_State state) => switch (state) {
  _State.trend => 'A (historical PASS)',
  _State.transition => 'C5 subset (historical PASS)',
  _State.correction => 'none — B is research only',
  _State.range => 'none',
  _State.unknown => 'none',
};

_Structure? _readStructure(
  Map<String, dynamic> json,
  List<String> candidateKeys,
) {
  for (final key in candidateKeys) {
    if (!json.containsKey(key)) continue;
    final parsed = _parseStructure(json[key]);
    if (parsed != null) return parsed;
  }

  // Some cache revisions wrap timeframe data under "structure"/"structures".
  for (final wrapperKey in const [
    'structure',
    'structures',
    'marketStructure',
  ]) {
    final wrapper = json[wrapperKey];
    if (wrapper is! Map) continue;
    final map = Map<String, dynamic>.from(wrapper);
    for (final key in candidateKeys) {
      if (!map.containsKey(key)) continue;
      final parsed = _parseStructure(map[key]);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

_Structure? _parseStructure(dynamic value) {
  if (value is Map) {
    for (final key in const ['structure', 'value', 'name', 'state']) {
      if (value.containsKey(key)) {
        final parsed = _parseStructure(value[key]);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  if (value is! String) return null;
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll('marketstructure.', '')
      .replaceAll('_', '')
      .replaceAll('-', '');

  return switch (normalized) {
    'bullish' || 'bull' => _Structure.bullish,
    'bearish' || 'bear' => _Structure.bearish,
    'neutral' || 'range' || 'ranging' => _Structure.neutral,
    'unknown' => _Structure.unknown,
    _ => null,
  };
}
