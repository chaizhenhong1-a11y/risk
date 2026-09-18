import 'dart:io';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/paper_mt5_history_adapter.dart';

void main() {
  test('reuses canonical split DATE TIME MT5 parsing and M5 close time', () {
    final dir = Directory.systemTemp.createTempSync('tradeforge-mt5-forward-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}XAUUSD_M5.csv')
      ..writeAsStringSync(
        '<DATE>\t<TIME>\t<OPEN>\t<HIGH>\t<LOW>\t<CLOSE>\t'
        '<TICKVOL>\t<VOL>\t<SPREAD>\n'
        '2026.09.17\t08:00:00\t3600\t3605\t3595\t3602\t100\t0\t20\n'
        '2026.09.17\t08:05:00\t3602\t3608\t3600\t3606\t120\t0\t20\n',
      );

    final candles = const PaperMt5HistoryAdapter().readM5(file);

    expect(candles, hasLength(2));
    expect(candles.first.closeTime, DateTime(2026, 9, 17, 8, 5));
    expect(candles.last.closeTime, DateTime(2026, 9, 17, 8, 10));
    expect(candles.last.close, 3606);
  });
}
