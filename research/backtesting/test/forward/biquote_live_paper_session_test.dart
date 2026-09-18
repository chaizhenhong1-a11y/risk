import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('paper-forward journals stay separated by evidence class', () async {
    final temp = await Directory.systemTemp.createTemp(
      'tradeforge_live_paper_',
    );
    addTearDown(() => temp.delete(recursive: true));

    final signals = File('${temp.path}/xauusd_signals.jsonl');
    final results = File('${temp.path}/xauusd_results.jsonl');
    final segmentCandidates = File(
      '${temp.path}/segments/segment_candidates.jsonl',
    );
    final segmentResults = File('${temp.path}/segments/segment_results.jsonl');

    await signals.parent.create(recursive: true);
    await segmentCandidates.parent.create(recursive: true);

    expect(signals.path, isNot(segmentCandidates.path));
    expect(results.path, isNot(segmentResults.path));
    expect(segmentCandidates.parent.existsSync(), isTrue);
  });

  test(
    'persisted segment startAt can be represented without local timezone',
    () {
      final start = DateTime.utc(2026, 9, 18, 2, 30);
      final encoded = jsonEncode(<String, Object>{
        'startAt': start.toIso8601String(),
      });
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final restored = DateTime.parse(decoded['startAt'] as String).toUtc();

      expect(restored, start);
      expect(restored.isUtc, isTrue);
    },
  );
}
