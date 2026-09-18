import 'dart:io';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/paper_forward_checkpoint.dart';

void main() {
  test('persists the last closed unseen candle', () {
    final dir = Directory.systemTemp.createTempSync('tradeforge-checkpoint-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}checkpoint.json');
    final time = DateTime.utc(2026, 9, 17, 8, 5);

    const checkpoint = PaperForwardCheckpoint();
    checkpoint.write(file, time);

    expect(checkpoint.read(file), time);
  });
}
