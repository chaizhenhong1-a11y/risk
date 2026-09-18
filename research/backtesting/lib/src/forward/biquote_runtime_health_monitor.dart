import 'dart:async';
import 'dart:io';

import 'biquote_market_data.dart';

final class BiQuoteRuntimeHealthSnapshot {
  const BiQuoteRuntimeHealthSnapshot({
    required this.now,
    required this.tickCount,
    required this.lastTickAt,
    required this.lastTickPrice,
    required this.lastClosedM5,
  });

  final DateTime now;
  final int tickCount;
  final DateTime? lastTickAt;
  final double? lastTickPrice;
  final DateTime? lastClosedM5;

  Duration? get tickAge =>
      lastTickAt == null ? null : now.difference(lastTickAt!);

  bool get tickStale =>
      tickAge != null && tickAge! > const Duration(seconds: 30);

  DateTime get nextM5Boundary {
    final utc = now.toUtc();
    return DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute - (utc.minute % 5),
    ).add(const Duration(minutes: 5));
  }

  Duration get untilNextM5 => nextM5Boundary.difference(now.toUtc());
}

/// Read-only live transport health. It never changes strategy decisions.
final class BiQuoteRuntimeHealthMonitor {
  BiQuoteRuntimeHealthMonitor({IOSink? output, DateTime Function()? clock})
    : output = output ?? stdout,
      _clock = clock ?? (() => DateTime.now().toUtc());

  final IOSink output;
  final DateTime Function() _clock;

  int _tickCount = 0;
  DateTime? _lastTickAt;
  double? _lastTickPrice;
  DateTime? _lastClosedM5;
  Timer? _timer;

  void onTick(BiQuoteTick tick) {
    _tickCount++;
    _lastTickAt = _clock().toUtc();
    _lastTickPrice = tick.mid;
  }

  void onClosedM5(DateTime closeTime) {
    _lastClosedM5 = closeTime.toUtc();
  }

  BiQuoteRuntimeHealthSnapshot snapshot() => BiQuoteRuntimeHealthSnapshot(
    now: _clock().toUtc(),
    tickCount: _tickCount,
    lastTickAt: _lastTickAt,
    lastTickPrice: _lastTickPrice,
    lastClosedM5: _lastClosedM5,
  );

  void startHeartbeat({Duration interval = const Duration(seconds: 10)}) {
    _timer?.cancel();
    _print();
    _timer = Timer.periodic(interval, (_) => _print());
  }

  void _print() {
    final state = snapshot();
    final status = state.tickCount == 0
        ? 'WAITING'
        : state.tickStale
        ? 'STALE'
        : 'LIVE';

    output.writeln(
      '[HEARTBEAT] ticks=$status count=${state.tickCount} '
      'lastTick=${state.lastTickAt?.toIso8601String() ?? '-'} '
      'price=${state.lastTickPrice?.toStringAsFixed(2) ?? '-'} '
      'age=${state.tickAge?.inSeconds ?? '-'}s '
      '| lastClosedM5=${state.lastClosedM5?.toIso8601String() ?? '-'} '
      '| nextM5=${state.nextM5Boundary.toIso8601String()} '
      'in=${state.untilNextM5.inSeconds}s',
    );
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
