import 'dart:io';

import 'biquote_live_closed_bar_pipeline.dart';
import 'biquote_market_data.dart';
import 'biquote_realtime_feed.dart';
import 'biquote_segment_paper_forward_bridge.dart';
import 'biquote_segment_paper_lifecycle.dart';
import 'biquote_unseen_paper_forward_runner.dart';
import 'live_paper_signal_runner.dart';

/// Composition root for unseen XAUUSD Paper Forward.
///
/// Frozen A/C5 keep their existing journal/lifecycle. The four frozen
/// Increment-171 research segments use a separate paper-only journal and
/// lifecycle. No broker order is sent.
final class BiQuoteLivePaperSession {
  factory BiQuoteLivePaperSession({
    required BiQuoteRealtimeFeed feed,
    required BiQuoteLiveClosedBarPipeline pipeline,
    required File signalsFile,
    required File resultsFile,
    required DateTime segmentStartAt,
    required File segmentStateFile,
    required File segmentCandidatesFile,
    required File segmentLifecycleStateFile,
    required File segmentResultsFile,
    LivePaperSignalRunner? signalRunner,
    BiQuoteSegmentPaperForwardSession? segmentSession,
  }) {
    final liveSignalRunner =
        signalRunner ??
        LivePaperSignalRunner(
          signalsFile: signalsFile,
          resultsFile: resultsFile,
        );

    final liveSegmentSession =
        segmentSession ??
        BiQuoteSegmentPaperForwardSession(
          bridge: BiQuoteSegmentPaperForwardBridge(
            startAt: segmentStartAt.toUtc(),
            stateFile: segmentStateFile,
            journalFile: segmentCandidatesFile,
          ),
          lifecycle: BiQuoteSegmentPaperLifecycle(
            candidateJournal: segmentCandidatesFile,
            stateFile: segmentLifecycleStateFile,
            resultJournal: segmentResultsFile,
          ),
        );

    late final BiQuoteLivePaperSession session;
    final runner = BiQuoteUnseenPaperForwardRunner(
      feed: feed,
      pipeline: pipeline,
      onClosedM5: (snapshot) async {
        // Keep production-frozen A/C5 and research segments isolated while
        // consuming the exact same immutable CLOSED-M5 snapshot.
        await liveSignalRunner.onClosedM5(snapshot);
        await liveSegmentSession.onClosedM5(snapshot);
        session._recordCompletedClosedM5(snapshot.observedAt);
      },
    );
    session = BiQuoteLivePaperSession._(
      feed: feed,
      signalRunner: liveSignalRunner,
      segmentSession: liveSegmentSession,
      runner: runner,
    );
    return session;
  }

  BiQuoteLivePaperSession._({
    required BiQuoteRealtimeFeed feed,
    required LivePaperSignalRunner signalRunner,
    required BiQuoteSegmentPaperForwardSession segmentSession,
    required BiQuoteUnseenPaperForwardRunner runner,
  }) : _feed = feed,
       _signalRunner = signalRunner,
       _segmentSession = segmentSession,
       _runner = runner;

  final BiQuoteRealtimeFeed _feed;
  final LivePaperSignalRunner _signalRunner;
  final BiQuoteSegmentPaperForwardSession _segmentSession;
  final BiQuoteUnseenPaperForwardRunner _runner;
  int _evaluatedM5Count = 0;
  DateTime? _lastEvaluatedAt;

  int get evaluatedM5Count => _evaluatedM5Count;
  int get warmupM5Count => _runner.warmupM5Count;
  DateTime? get lastEvaluatedAt => _lastEvaluatedAt;

  void _recordCompletedClosedM5(DateTime observedAt) {
    _evaluatedM5Count++;
    _lastEvaluatedAt = observedAt.toUtc();
  }

  LivePaperSignalRunner get signalRunner => _signalRunner;
  BiQuoteSegmentPaperForwardSession get segmentSession => _segmentSession;

  Future<void> start({int warmupPerTimeframe = 500}) async {
    await _runner.start(warmupPerTimeframe: warmupPerTimeframe);

    // Increment 191 restart recovery: bootstrap bars are context for discovery,
    // but they are valid lifecycle evidence for signals that were already
    // persisted before this process started.
    final recoveryBars = _feed.store
        .barsFor(BiQuoteTimeframe.m5)
        .toList(growable: false);
    _signalRunner.recoverFromClosedM5(recoveryBars);
    await _segmentSession.lifecycle.recoverFromClosedBars(recoveryBars);
  }

  Future<void> dispose() => _runner.dispose();
}
