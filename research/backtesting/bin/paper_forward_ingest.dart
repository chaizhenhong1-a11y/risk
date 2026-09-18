import 'dart:convert';
import 'dart:io';

import 'package:tradeforge_backtesting/src/forward/paper_signal.dart';
import 'package:tradeforge_backtesting/src/forward/paper_strategy_opportunity.dart';
import 'package:tradeforge_backtesting/src/forward/paper_strategy_recorder.dart';

void main(List<String> arguments) {
  if (arguments.isEmpty || arguments.length > 2) {
    stderr.writeln(
      'Usage: dart run bin/paper_forward_ingest.dart '
      '<opportunities.jsonl> [signals.jsonl]',
    );
    exitCode = 64;
    return;
  }

  final input = File(arguments[0]);
  if (!input.existsSync()) {
    stderr.writeln('Opportunity input not found: ${input.path}');
    exitCode = 66;
    return;
  }

  final journal = File(
    arguments.length == 2
        ? arguments[1]
        : '.research_cache${Platform.pathSeparator}paper_forward'
              '${Platform.pathSeparator}signals.jsonl',
  );

  const recorder = PaperStrategyRecorder();
  var accepted = 0;
  var duplicates = 0;

  for (final line in input.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final json = jsonDecode(line) as Map<String, dynamic>;
    final strategy = json['strategy'] as String;
    if (strategy != 'A' && strategy != 'C5') {
      throw FormatException(
        'Paper-forward Increment 148 accepts only frozen A/C5; got $strategy',
      );
    }

    final opportunity = PaperStrategyOpportunity(
      symbol: json['symbol'] as String? ?? 'XAUUSD',
      strategy: strategy,
      side: PaperSignalSide.values.byName(
        (json['side'] as String).toLowerCase(),
      ),
      observedAt: DateTime.parse(json['observedAt'] as String),
      entry: (json['entry'] as num).toDouble(),
      stopLoss: (json['stopLoss'] as num).toDouble(),
      takeProfit: (json['takeProfit'] as num).toDouble(),
      reason: json['reason'] as String? ?? 'Frozen $strategy opportunity',
    );

    final result = recorder.record(journal, opportunity);
    result.wasRecorded ? accepted++ : duplicates++;
  }

  stdout.writeln('TradeForge V2 — Increment 148 Paper Forward Ingest');
  stdout.writeln('Journal: ${journal.path}');
  stdout.writeln('New opportunities: $accepted');
  stdout.writeln('Duplicates ignored: $duplicates');
  stdout.writeln('');
  stdout.writeln(
    'No daily quota and no additional strategy-quality gate is applied here.',
  );
  stdout.writeln(
    'This remains paper-only. Broker execution is intentionally absent.',
  );
}
