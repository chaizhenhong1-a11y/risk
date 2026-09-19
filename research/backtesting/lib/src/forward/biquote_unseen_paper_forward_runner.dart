import 'dart:async';
import 'dart:io';

import 'biquote_live_closed_bar_pipeline.dart';
import 'biquote_live_market_snapshot.dart';
import 'biquote_market_data.dart';
import 'biquote_realtime_feed.dart';
import 'biquote_runtime_health_monitor.dart';

typedef BiQuoteUnseenClosedM5Observer =
    FutureOr<void> Function(BiQuoteLiveMarketSnapshot snapshot);

final class SerialBiQuoteClosedM5Observer {
  SerialBiQuoteClosedM5Observer({required this.observer, this.onError});
  final BiQuoteUnseenClosedM5Observer observer;
  final void Function(Object error, StackTrace stackTrace)? onError;
  Future<void> _tail = Future<void>.value();
  Future<void> add(BiQuoteLiveMarketSnapshot snapshot) {
    final next = _tail.then((_) => Future.sync(() => observer(snapshot)));
    _tail = next.catchError((Object error, StackTrace stackTrace) {
      onError?.call(error, stackTrace);
    });
    return next;
  }

  Future<void> get idle => _tail;
}

final class BiQuoteUnseenPaperForwardRunner {
  BiQuoteUnseenPaperForwardRunner({
    required this.feed,
    required this.pipeline,
    required this.onClosedM5,
    BiQuoteRuntimeHealthMonitor? healthMonitor,
  }) : healthMonitor = healthMonitor ?? BiQuoteRuntimeHealthMonitor(),
       _serialObserver = SerialBiQuoteClosedM5Observer(observer: onClosedM5);

  final BiQuoteRealtimeFeed feed;
  final BiQuoteLiveClosedBarPipeline pipeline;
  final BiQuoteUnseenClosedM5Observer onClosedM5;
  final BiQuoteRuntimeHealthMonitor healthMonitor;
  final SerialBiQuoteClosedM5Observer _serialObserver;

  StreamSubscription<BiQuoteTick>? _tickSubscription;
  StreamSubscription<BiQuoteLiveClosedBarBatch>? _batchSubscription;
  StreamSubscription<BiQuoteRuntimeState>? _runtimeSubscription;
  DateTime? _lastQueuedM5Close;
  bool _acceptLiveClosedM5 = false;
  int _warmupM5Count = 0;

  int get warmupM5Count => _warmupM5Count;

  Future<void> start({int warmupPerTimeframe = 500}) async {
    _batchSubscription = pipeline.batches.listen((batch) {
      if (!batch.triggeredBy.contains(BiQuoteTimeframe.m5)) return;
      if (!_acceptLiveClosedM5) return;
      if (feed.runtimeState != BiQuoteRuntimeState.live) return;

      final m5 = feed.store.barsFor(BiQuoteTimeframe.m5);
      if (m5.isEmpty) {
        stdout.writeln('[M5] refresh completed but store has no CLOSED M5');
        return;
      }

      final previous = _lastQueuedM5Close;
      final pending =
          m5
              .where(
                (bar) =>
                    previous == null || bar.closeTime.toUtc().isAfter(previous),
              )
              .toList(growable: false)
            ..sort((a, b) => a.closeTime.compareTo(b.closeTime));

      if (pending.isEmpty) {
        stdout.writeln(
          '[M5] refresh completed; no newer CLOSED M5 '
          '(latest=${m5.last.closeTime.toUtc().toIso8601String()})',
        );
        return;
      }

      for (final bar in pending) {
        final observedAt = bar.closeTime.toUtc();
        final snapshot = BiQuoteLiveMarketSnapshot.fromStore(
          feed.store,
          observedAt: observedAt,
        );
        if (!snapshot.hasMinimumTimeframes) {
          stdout.writeln(
            '[M5] ${observedAt.toIso8601String()} skipped: '
            'minimum MTF snapshot unavailable',
          );
          continue;
        }
        _lastQueuedM5Close = observedAt;
        healthMonitor.onClosedM5(observedAt);
        stdout.writeln('[M5] CLOSED ${observedAt.toIso8601String()}');
        unawaited(
          _serialObserver
              .add(snapshot)
              .then((_) {
                stdout.writeln(
                  '[SCAN] COMPLETED ${observedAt.toIso8601String()}',
                );
              })
              .catchError((Object error, StackTrace stackTrace) {
                stderr.writeln(
                  '[SCAN] FAILED ${observedAt.toIso8601String()} error=$error',
                );
              }),
        );
      }
    });

    _runtimeSubscription = feed.runtimeStates.listen((state) {
      healthMonitor.onRuntimeState(state);
      stdout.writeln('[MARKET] XAUUSD=${state.name.toUpperCase()}');
    });
    healthMonitor.onRuntimeState(feed.runtimeState);

    _tickSubscription = feed.ticks.listen((tick) {
      healthMonitor.onTick(tick);
      if (feed.runtimeState == BiQuoteRuntimeState.live) {
        pipeline.onTick(tick);
      }
    });

    healthMonitor.startHeartbeat();
    await feed.start(warmupPerTimeframe: warmupPerTimeframe);
    healthMonitor.onRuntimeState(feed.runtimeState);

    final warmupM5 = feed.store.barsFor(BiQuoteTimeframe.m5);
    _warmupM5Count = warmupM5.length;
    if (warmupM5.isNotEmpty) {
      _lastQueuedM5Close = warmupM5.last.closeTime.toUtc();
      stdout.writeln(
        '[WARMUP] M5=$_warmupM5Count baseline='
        '${_lastQueuedM5Close!.toIso8601String()}',
      );
    }
    _acceptLiveClosedM5 = true;
  }

  Future<void> dispose() async {
    await _tickSubscription?.cancel();
    await _batchSubscription?.cancel();
    await _runtimeSubscription?.cancel();
    await _serialObserver.idle;
    healthMonitor.dispose();
    await pipeline.dispose();
    await feed.dispose();
  }
}
