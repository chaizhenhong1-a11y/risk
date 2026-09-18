import 'dart:io';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/paper_signal.dart';
import 'package:tradeforge_backtesting/src/forward/paper_signal_journal.dart';
import 'package:tradeforge_backtesting/src/forward/paper_strategy_opportunity.dart';
import 'package:tradeforge_backtesting/src/forward/paper_strategy_recorder.dart';

void main() {
  late Directory temp;
  late File journal;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('tradeforge-recorder-');
    journal = File('${temp.path}${Platform.pathSeparator}signals.jsonl');
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('records frozen A opportunity without adding another gate', () {
    const recorder = PaperStrategyRecorder();
    final result = recorder.record(
      journal,
      PaperStrategyOpportunity(
        symbol: 'XAUUSD',
        strategy: 'A',
        side: PaperSignalSide.buy,
        observedAt: DateTime.utc(2026, 9, 17, 8),
        entry: 3600,
        stopLoss: 3590,
        takeProfit: 3620,
        reason: 'Frozen Strategy A opportunity',
      ),
    );

    expect(result.wasRecorded, isTrue);
    expect(result.signal.strategy, 'A');
    expect(result.signal.rewardRisk, 2);
  });

  test('records frozen C5 opportunity through the same journal', () {
    const recorder = PaperStrategyRecorder();
    recorder.record(
      journal,
      PaperStrategyOpportunity(
        symbol: 'XAUUSD',
        strategy: 'C5',
        side: PaperSignalSide.buy,
        observedAt: DateTime.utc(2026, 9, 17, 9),
        entry: 3610,
        stopLoss: 3600,
        takeProfit: 3630,
        reason: 'Frozen C5 structural opportunity',
      ),
    );

    final rows = const PaperSignalJournal().readAll(journal);
    expect(rows, hasLength(1));
    expect(rows.single.strategy, 'C5');
  });

  test('A and C5 opportunities at the same time remain independent IDs', () {
    const recorder = PaperStrategyRecorder();
    final time = DateTime.utc(2026, 9, 17, 10);

    for (final strategy in const ['A', 'C5']) {
      recorder.record(
        journal,
        PaperStrategyOpportunity(
          symbol: 'XAUUSD',
          strategy: strategy,
          side: PaperSignalSide.buy,
          observedAt: time,
          entry: 3600,
          stopLoss: 3590,
          takeProfit: 3620,
          reason: '$strategy opportunity',
        ),
      );
    }

    final rows = const PaperSignalJournal().readAll(journal);
    expect(rows, hasLength(2));
    expect(rows.map((row) => row.id).toSet(), hasLength(2));
  });
}
