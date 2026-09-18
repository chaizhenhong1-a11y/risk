import 'dart:io';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_market_data.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_runtime_health_monitor.dart';

void main() {
  test('health monitor changes from live to stale after 30 seconds', () async {
    var now = DateTime.utc(2026, 9, 18, 2, 41, 20);
    final file = File(
      '${Directory.systemTemp.path}/tradeforge_health_monitor_test.txt',
    );
    final sink = file.openWrite();
    final monitor = BiQuoteRuntimeHealthMonitor(output: sink, clock: () => now);

    expect(monitor.snapshot().tickCount, 0);

    monitor.onTick(
      BiQuoteTick(
        symbol: 'XAUUSD',
        bid: 3660.0,
        ask: 3660.2,
        timestamp: now,
        nativeTime: now,
        source: 'test',
      ),
    );
    expect(monitor.snapshot().tickStale, isFalse);
    expect(monitor.snapshot().lastTickPrice, closeTo(3660.1, 0.0001));

    now = now.add(const Duration(seconds: 31));
    expect(monitor.snapshot().tickStale, isTrue);

    monitor.dispose();
    await sink.close();
    if (file.existsSync()) await file.delete();
  });

  test('next M5 boundary is strictly after current boundary', () async {
    final file = File(
      '${Directory.systemTemp.path}/tradeforge_health_boundary_test.txt',
    );
    final sink = file.openWrite();
    final monitor = BiQuoteRuntimeHealthMonitor(
      output: sink,
      clock: () => DateTime.utc(2026, 9, 18, 2, 45),
    );

    expect(monitor.snapshot().nextM5Boundary, DateTime.utc(2026, 9, 18, 2, 50));
    expect(monitor.snapshot().untilNextM5, const Duration(minutes: 5));

    monitor.dispose();
    await sink.close();
    if (file.existsSync()) await file.delete();
  });
}
