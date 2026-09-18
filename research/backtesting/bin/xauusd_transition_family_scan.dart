import 'dart:convert';
import 'dart:io';

import 'package:tradeforge_backtesting/src/research/transition_family_scanner.dart';

void main(List<String> arguments) {
  final cachePath = arguments.isEmpty
      ? '.research_cache${Platform.pathSeparator}market_structure'
            '${Platform.pathSeparator}xauusd_market_structure.jsonl'
      : arguments.single;

  if (arguments.length > 1) {
    stderr.writeln(
      'Usage: dart run bin/xauusd_transition_family_scan.dart '
      '[market-structure-cache.jsonl]',
    );
    exitCode = 64;
    return;
  }

  final file = File(cachePath);
  if (!file.existsSync()) {
    stderr.writeln('Market-structure cache not found: ${file.path}');
    stderr.writeln('This scanner never rebuilds the 100k replay.');
    exitCode = 66;
    return;
  }

  const scanner = TransitionFamilyScanner();
  final observations = <(CachedStructure, CachedStructure)>[];
  var rows = 0;
  var skipped = 0;

  for (final line in file.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    rows++;
    final json = jsonDecode(line) as Map<String, dynamic>;
    final h4 = _read(json, const ['h4Structure', 'h4_structure', 'h4']);
    final h1 = _read(json, const ['h1Structure', 'h1_structure', 'h1']);
    if (h4 == null || h1 == null) {
      skipped++;
      continue;
    }
    if (scanner.classify(h4: h4, h1: h1) != null) {
      observations.add((h4, h1));
    }
  }

  final ranked = scanner.rank(observations);
  final total = ranked.fold<int>(0, (sum, row) => sum + row.observations);

  stdout.writeln('TradeForge V2 — Increment 146 Transition Family Scan');
  stdout.writeln('Cache-first: no 100,049-candle replay.');
  stdout.writeln(
    'Purpose: locate large transition families for NEW independent '
    'positive-expectancy research; do not loosen C5.',
  );
  stdout.writeln('');
  stdout.writeln('Family                    | Observations | Share');
  stdout.writeln('--------------------------|--------------|--------');
  for (final row in ranked) {
    if (row.observations == 0) continue;
    final share = total == 0 ? 0.0 : row.observations / total * 100;
    stdout.writeln(
      '${_label(row.family).padRight(25)} | '
      '${row.observations.toString().padLeft(12)} | '
      '${share.toStringAsFixed(2).padLeft(6)}%',
    );
  }
  stdout.writeln('');
  stdout.writeln('Transition observations: $total');
  stdout.writeln('Cache rows: $rows');
  stdout.writeln('Skipped malformed rows: $skipped');
  stdout.writeln('');
  stdout.writeln(
    'Next research should start with the largest family, then test directional '
    'forward-path hypotheses. Frequency alone is not evidence of edge.',
  );
}

String _label(TransitionFamily family) => switch (family) {
  TransitionFamily.h4BullishH1Neutral => 'H4 bullish / H1 neutral',
  TransitionFamily.h4BearishH1Neutral => 'H4 bearish / H1 neutral',
  TransitionFamily.h4NeutralH1Bullish => 'H4 neutral / H1 bullish',
  TransitionFamily.h4NeutralH1Bearish => 'H4 neutral / H1 bearish',
  TransitionFamily.h4NeutralH1Neutral => 'H4 neutral / H1 neutral',
};

CachedStructure? _read(Map<String, dynamic> json, List<String> candidateKeys) {
  for (final key in candidateKeys) {
    if (json.containsKey(key)) {
      final parsed = _parse(json[key]);
      if (parsed != null) return parsed;
    }
  }
  for (final wrapperKey in const [
    'structure',
    'structures',
    'marketStructure',
  ]) {
    final wrapper = json[wrapperKey];
    if (wrapper is! Map) continue;
    final map = Map<String, dynamic>.from(wrapper);
    for (final key in candidateKeys) {
      if (map.containsKey(key)) {
        final parsed = _parse(map[key]);
        if (parsed != null) return parsed;
      }
    }
  }
  return null;
}

CachedStructure? _parse(dynamic value) {
  if (value is Map) {
    for (final key in const ['structure', 'value', 'name', 'state']) {
      if (value.containsKey(key)) {
        final parsed = _parse(value[key]);
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
    'bullish' || 'bull' => CachedStructure.bullish,
    'bearish' || 'bear' => CachedStructure.bearish,
    'neutral' || 'range' || 'ranging' => CachedStructure.neutral,
    'unknown' => CachedStructure.unknown,
    _ => null,
  };
}
