import 'dart:io';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/paper_forward_engine.dart';
import 'package:tradeforge_backtesting/src/forward/paper_signal.dart';
import 'package:tradeforge_backtesting/src/forward/paper_signal_journal.dart';

void main() {
  late Directory temp;
  late File journal;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('tradeforge-paper-');
    journal = File('${temp.path}${Platform.pathSeparator}signals.jsonl');
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('records a valid BUY opportunity with calculated RR', () {
    const engine = PaperForwardEngine();
    final result = engine.record(
      journalFile: journal,
      symbol: 'XAUUSD',
      strategy: 'A',
      side: PaperSignalSide.buy,
      observedAt: DateTime.utc(2026, 9, 17, 8),
      entry: 3600,
      stopLoss: 3590,
      takeProfit: 3620,
      reason: 'Frozen Strategy A opportunity',
    );

    expect(result.wasRecorded, isTrue);
    expect(result.signal.rewardRisk, 2);
    expect(result.signal.status, PaperSignalStatus.pending);
  });

  test('deterministic ID prevents duplicate paper opportunities', () {
    const engine = PaperForwardEngine();

    PaperForwardDecision write() => engine.record(
      journalFile: journal,
      symbol: 'XAUUSD',
      strategy: 'C5',
      side: PaperSignalSide.buy,
      observedAt: DateTime.utc(2026, 9, 17, 9),
      entry: 3600,
      stopLoss: 3590,
      takeProfit: 3620,
      reason: 'Frozen C5 opportunity',
    );

    expect(write().wasRecorded, isTrue);
    expect(write().wasRecorded, isFalse);
    expect(const PaperSignalJournal().readAll(journal), hasLength(1));
  });

  test('rejects mechanically invalid BUY geometry', () {
    const engine = PaperForwardEngine();

    expect(
      () => engine.record(
        journalFile: journal,
        symbol: 'XAUUSD',
        strategy: 'A',
        side: PaperSignalSide.buy,
        observedAt: DateTime.utc(2026, 9, 17),
        entry: 3600,
        stopLoss: 3610,
        takeProfit: 3620,
        reason: 'invalid',
      ),
      throwsArgumentError,
    );
  });

  test('supports SELL geometry without adding a strategy gate', () {
    const engine = PaperForwardEngine();
    final result = engine.record(
      journalFile: journal,
      symbol: 'XAUUSD',
      strategy: 'A',
      side: PaperSignalSide.sell,
      observedAt: DateTime.utc(2026, 9, 17, 10),
      entry: 3600,
      stopLoss: 3610,
      takeProfit: 3580,
      reason: 'Frozen Strategy A opportunity',
    );

    expect(result.signal.rewardRisk, 2);
  });
}
