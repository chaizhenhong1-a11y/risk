import 'dart:io';

import 'package:technical_analysis/technical_analysis.dart';
import 'package:tradeforge_backtesting/src/cache/market_structure_research_cache.dart';
import 'package:tradeforge_backtesting/src/diagnostics/opportunity_gap_batch_diagnostics.dart';

const states = <GapStateDefinition>[
  GapStateDefinition(
    id: 'G2 neutral-bearish-neutral',
    h4: MarketStructure.neutral,
    h1: MarketStructure.bearish,
    m15: MarketStructure.neutral,
    direction: GapResearchDirection.continuation,
  ),
  GapStateDefinition(
    id: 'G3 neutral-neutral-bullish',
    h4: MarketStructure.neutral,
    h1: MarketStructure.neutral,
    m15: MarketStructure.bullish,
    direction: GapResearchDirection.continuation,
  ),
  GapStateDefinition(
    id: 'G4 neutral-bearish-bearish',
    h4: MarketStructure.neutral,
    h1: MarketStructure.bearish,
    m15: MarketStructure.bearish,
    direction: GapResearchDirection.continuation,
  ),
  GapStateDefinition(
    id: 'G5 bullish-neutral-neutral',
    h4: MarketStructure.bullish,
    h1: MarketStructure.neutral,
    m15: MarketStructure.neutral,
    direction: GapResearchDirection.continuation,
  ),
  GapStateDefinition(
    id: 'G7 neutral-bullish-neutral',
    h4: MarketStructure.neutral,
    h1: MarketStructure.bullish,
    m15: MarketStructure.neutral,
    direction: GapResearchDirection.continuation,
  ),
  GapStateDefinition(
    id: 'G8 bearish-neutral-neutral',
    h4: MarketStructure.bearish,
    h1: MarketStructure.neutral,
    m15: MarketStructure.neutral,
    direction: GapResearchDirection.continuation,
  ),
  GapStateDefinition(
    id: 'G11 neutral-neutral-bearish',
    h4: MarketStructure.neutral,
    h1: MarketStructure.neutral,
    m15: MarketStructure.bearish,
    direction: GapResearchDirection.continuation,
  ),
];

void main() {
  final cacheFile = File(
    '.research_cache${Platform.pathSeparator}market_structure'
    '${Platform.pathSeparator}xauusd_market_structure.jsonl',
  );
  if (!cacheFile.existsSync()) {
    stderr.writeln('Missing cache: ${cacheFile.path}');
    stderr.writeln(
      'Run xauusd_build_market_structure_research_cache.dart first.',
    );
    exitCode = 66;
    return;
  }

  const cache = MarketStructureResearchCache();
  final rows = cache.read(cacheFile);
  stdout.writeln('Loaded cached rows: ${rows.length}');

  const diagnostics = OpportunityGapBatchDiagnostics();

  stdout.writeln('');
  stdout.writeln(
    'TradeForge V2 — Increment 132 Opportunity Gap Batch Research',
  );
  stdout.writeln(
    'Episode entry = first cached M5 observation entering the exact state.',
  );
  stdout.writeln(
    'Discovery only. Percentages are directional continuation, not win rates.',
  );
  stdout.writeln('');

  for (final state in states) {
    final samples = <GapEpisodeSample>[];
    var wasInState = false;

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final inState =
          row.h4 == state.h4 && row.h1 == state.h1 && row.m15 == state.m15;

      if (!inState) {
        wasInState = false;
        continue;
      }
      if (wasInState) continue;
      wasInState = true;

      if (i + 48 >= rows.length) continue;

      final direction = _directionFor(state);
      if (direction == null) continue;

      samples.add(
        GapEpisodeSample(
          stateId: state.id,
          startedAt: row.time,
          direction: direction,
          return12: rows[i + 12].close - row.close,
          return24: rows[i + 24].close - row.close,
          return48: rows[i + 48].close - row.close,
        ),
      );
    }

    final summary = diagnostics.summarize(state.id, samples);
    stdout.writeln(state.id);
    stdout.writeln(
      '  episodes=${summary.samples} days=${summary.days} '
      'bull=${summary.bullishSamples} bear=${summary.bearishSamples}',
    );
    stdout.writeln(
      '  continuation: 12M5=${_pct(summary.rate12)} '
      '24M5=${_pct(summary.rate24)} 48M5=${_pct(summary.rate48)}',
    );
    stdout.writeln(
      '  chronological 24M5: firstHalf=${_pct(summary.firstHalfRate24)} '
      'secondHalf=${_pct(summary.secondHalfRate24)}',
    );
  }
}

MarketStructure? _directionFor(GapStateDefinition state) {
  final directional = <MarketStructure>[state.m15, state.h1, state.h4]
      .firstWhere(
        (value) =>
            value == MarketStructure.bullish ||
            value == MarketStructure.bearish,
        orElse: () => MarketStructure.neutral,
      );

  if (directional == MarketStructure.neutral) return null;
  if (state.direction == GapResearchDirection.continuation) {
    return directional;
  }
  return directional == MarketStructure.bullish
      ? MarketStructure.bearish
      : MarketStructure.bullish;
}

String _pct(double value) => '${(value * 100).toStringAsFixed(2)}%';
