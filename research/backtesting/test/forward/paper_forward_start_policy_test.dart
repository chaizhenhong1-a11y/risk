import 'dart:io';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/paper_forward_start_policy.dart';

void main() {
  test('unseen start watermark is immutable after initialization', () {
    final dir = Directory.systemTemp.createTempSync('tradeforge-start-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}state.json');
    const policy = PaperForwardStartPolicy();

    final first = policy.initialize(file, DateTime(2026, 9, 17, 8));
    final second = policy.initialize(file, DateTime(2020, 1, 1));

    expect(first.startAt, DateTime(2026, 9, 17, 8));
    expect(second.startAt, first.startAt);
    expect(second.schemaVersion, 1);
  });
}
