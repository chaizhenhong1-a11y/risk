import 'dart:io';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/paper_signal.dart';
import 'package:tradeforge_backtesting/src/forward/paper_trade_result.dart';
import 'package:tradeforge_backtesting/src/forward/paper_trade_result_journal.dart';

void main() {
  test('result journal is append-only and deduplicated by signal ID', () {
    final dir = Directory.systemTemp.createTempSync('tradeforge-results-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}results.jsonl');

    final result = PaperTradeResult(
      signalId: 'XAUUSD|time|A|BUY',
      strategy: 'A',
      status: PaperSignalStatus.targetHit,
      resolvedAt: DateTime.utc(2026, 9, 17, 10),
      grossR: 2,
    );

    const journal = PaperTradeResultJournal();
    expect(journal.appendIfNew(file, result), isTrue);
    expect(journal.appendIfNew(file, result), isFalse);
    expect(journal.readAll(file), hasLength(1));
  });
}
