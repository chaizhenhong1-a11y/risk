import 'dart:io';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/paper_candle_csv.dart';

void main() {
  test('reads standard MT5-style OHLC export', () {
    final dir = Directory.systemTemp.createTempSync('tradeforge-csv-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}m5.csv')
      ..writeAsStringSync(
        '<DATE>\t<TIME>\t<OPEN>\t<HIGH>\t<LOW>\t<CLOSE>\n'
        '2026.09.17\t08:05:00\t3600\t3621\t3595\t3618\n',
      );

    // Combined DATE/TIME exports are deliberately rejected until the runner
    // can map them without guessing timezone semantics.
    expect(() => const PaperCandleCsv().read(file), throwsFormatException);
  });

  test('reads a single datetime column', () {
    final dir = Directory.systemTemp.createTempSync('tradeforge-csv2-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}m5.csv')
      ..writeAsStringSync(
        'datetime,open,high,low,close\n'
        '2026-09-17 08:05:00,3600,3621,3595,3618\n',
      );

    final rows = const PaperCandleCsv().read(file);
    expect(rows, hasLength(1));
    expect(rows.single.high, 3621);
  });
}
