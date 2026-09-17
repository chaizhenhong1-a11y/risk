import 'dart:io';

import 'package:technical_analysis/technical_analysis.dart';
import 'package:tradeforge_backtesting/src/cache/market_structure_research_cache.dart';
import 'package:tradeforge_backtesting/src/diagnostics/g4_reversal_risk_diagnostics.dart';

const _riskRewards = <double>[1.5, 2.0, 2.5, 3.0];
const _expiryBars = 48;

// Research-only stop proxy. This is deliberately frozen for this validation:
// use the adverse excursion of the 12 cached M5 observations immediately
// preceding G4 entry. No parameter search is performed.
const _lookbackBars = 12;

void main() {
  final cacheFile = File(
    '.research_cache${Platform.pathSeparator}market_structure'
    '${Platform.pathSeparator}xauusd_market_structure.jsonl',
  );

  if (!cacheFile.existsSync()) {
    stderr.writeln('Missing cache: ${cacheFile.path}');
    exitCode = 66;
    return;
  }

  final rows = const MarketStructureResearchCache().read(cacheFile);
  stdout.writeln('Loaded cached rows: ${rows.length}');

  final episodes = <_Episode>[];
  var wasG4 = false;

  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final isG4 =
        row.h4 == MarketStructure.neutral &&
        row.h1 == MarketStructure.bearish &&
        row.m15 == MarketStructure.bearish;

    if (!isG4) {
      wasG4 = false;
      continue;
    }
    if (wasG4) continue;
    wasG4 = true;

    if (i < _lookbackBars || i + _expiryBars >= rows.length) continue;

    // BUY reversal hypothesis. With structure-only cache available, freeze a
    // causal stop proxy from the preceding 12 M5 closes. The next step must
    // replace this with candle/structural invalidation before production use.
    var priorLowClose = rows[i - _lookbackBars].close;
    for (var j = i - _lookbackBars + 1; j < i; j++) {
      if (rows[j].close < priorLowClose) priorLowClose = rows[j].close;
    }

    final entry = row.close;
    final risk = entry - priorLowClose;
    if (!risk.isFinite || risk <= 0) continue;

    episodes.add(
      _Episode(index: i, entry: entry, stop: priorLowClose, risk: risk),
    );
  }

  stdout.writeln('');
  stdout.writeln('TradeForge V2 — Increment 133 G4 Reversal Risk Validation');
  stdout.writeln(
    'G4 = H4 neutral / H1 bearish / M15 bearish; hypothesis = BUY reversal.',
  );
  stdout.writeln(
    'Research stop proxy = lowest prior 12 M5 cached closes; expiry=48 M5.',
  );
  stdout.writeln(
    'IMPORTANT: cache contains closes only, so this is not yet a production '
    'structural SL validation.',
  );
  stdout.writeln('Eligible independent G4 episodes: ${episodes.length}');
  stdout.writeln('');

  for (final rr in _riskRewards) {
    final outcomes = <_Outcome>[];

    for (final episode in episodes) {
      final target = episode.entry + episode.risk * rr;
      _Outcome outcome = _Outcome.expired;

      for (var j = episode.index + 1; j <= episode.index + _expiryBars; j++) {
        final close = rows[j].close;

        // Close-only cache cannot determine intrabar ordering. A close cannot
        // simultaneously be <= stop and >= target for valid positive risk.
        if (close <= episode.stop) {
          outcome = _Outcome.loss;
          break;
        }
        if (close >= target) {
          outcome = _Outcome.win;
          break;
        }
      }
      outcomes.add(outcome);
    }

    final resolved = <G4ResolvedTrade>[];
    for (final outcome in outcomes) {
      if (outcome == _Outcome.win) {
        resolved.add(G4ResolvedTrade(riskReward: rr, isWin: true));
      } else if (outcome == _Outcome.loss) {
        resolved.add(G4ResolvedTrade(riskReward: rr, isWin: false));
      }
    }

    final split = outcomes.length ~/ 2;
    final firstResolved = _resolved(outcomes.sublist(0, split), rr);
    final secondResolved = _resolved(outcomes.sublist(split), rr);

    const diagnostics = G4ReversalRiskDiagnostics();
    final wins = outcomes.where((e) => e == _Outcome.win).length;
    final losses = outcomes.where((e) => e == _Outcome.loss).length;
    final expired = outcomes.where((e) => e == _Outcome.expired).length;

    stdout.writeln('RR ${rr.toStringAsFixed(1)}');
    stdout.writeln(
      '  resolved=${wins + losses} wins=$wins losses=$losses '
      'expired=$expired',
    );
    stdout.writeln(
      '  resolved win rate=${_pct(wins + losses == 0 ? 0 : wins / (wins + losses))}',
    );
    stdout.writeln(
      '  expectancy=${diagnostics.expectancy(resolved).toStringAsFixed(3)}R',
    );
    stdout.writeln(
      '  chronological expectancy: '
      'first=${diagnostics.expectancy(firstResolved).toStringAsFixed(3)}R '
      'second=${diagnostics.expectancy(secondResolved).toStringAsFixed(3)}R',
    );
  }

  stdout.writeln('');
  stdout.writeln(
    'Interpretation rule: do not productionize from this result. Positive '
    'close-only expectancy only earns a stricter candle/structure lifecycle '
    'validation with costs.',
  );
}

List<G4ResolvedTrade> _resolved(List<_Outcome> outcomes, double rr) {
  return [
    for (final outcome in outcomes)
      if (outcome == _Outcome.win)
        G4ResolvedTrade(riskReward: rr, isWin: true)
      else if (outcome == _Outcome.loss)
        G4ResolvedTrade(riskReward: rr, isWin: false),
  ];
}

String _pct(double value) => '${(value * 100).toStringAsFixed(2)}%';

enum _Outcome { win, loss, expired }

final class _Episode {
  const _Episode({
    required this.index,
    required this.entry,
    required this.stop,
    required this.risk,
  });

  final int index;
  final double entry;
  final double stop;
  final double risk;
}
