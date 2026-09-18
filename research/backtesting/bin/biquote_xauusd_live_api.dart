import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tradeforge_backtesting/src/forward/biquote_closed_bar_store.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_live_closed_bar_pipeline.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_live_paper_session.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_realtime_feed.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_rest_client.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_signalr_client.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_unified_live_api_server.dart';

Future<void> main(List<String> args) async {
  final root = Directory(args.isNotEmpty ? args[0] : '.paper_forward');
  final signalsFile = File('${root.path}/xauusd_signals.jsonl');
  final resultsFile = File('${root.path}/xauusd_results.jsonl');

  final segmentStateFile = File(
    '${root.path}/segments/segment_bridge_state.json',
  );
  final segmentCandidatesFile = File(
    '${root.path}/segments/segment_candidates.jsonl',
  );
  final segmentLifecycleStateFile = File(
    '${root.path}/segments/segment_lifecycle_state.json',
  );
  final segmentResultsFile = File(
    '${root.path}/segments/segment_results.jsonl',
  );

  await root.create(recursive: true);
  await segmentCandidatesFile.parent.create(recursive: true);

  // The first run freezes "now". Restarts reuse the persisted startAt instead
  // of silently resetting the unseen-forward observation window.
  final segmentStartAt = await _resolveImmutableSegmentStart(
    segmentStateFile,
    DateTime.now().toUtc(),
  );

  final store = BiQuoteClosedBarStore();
  final rest = BiQuoteRestClient();
  final signalR = BiQuoteSignalRClient();
  final feed = BiQuoteRealtimeFeed(
    restClient: rest,
    streamClient: signalR,
    store: store,
  );
  final pipeline = BiQuoteLiveClosedBarPipeline(client: rest, store: store);
  final session = BiQuoteLivePaperSession(
    feed: feed,
    pipeline: pipeline,
    signalsFile: signalsFile,
    resultsFile: resultsFile,
    segmentStartAt: segmentStartAt,
    segmentStateFile: segmentStateFile,
    segmentCandidatesFile: segmentCandidatesFile,
    segmentLifecycleStateFile: segmentLifecycleStateFile,
    segmentResultsFile: segmentResultsFile,
  );

  final liveApi = BiQuoteUnifiedLiveApiServer(
    feed: feed,
    session: session,
    segmentCandidateJournal: segmentCandidatesFile,
  );

  stdout.writeln('TradeForge V2 — UNIFIED LIVE UI + Paper Forward');
  stdout.writeln('A/C5 signals=${signalsFile.path}');
  stdout.writeln('A/C5 results=${resultsFile.path}');
  stdout.writeln('segment start=${segmentStartAt.toIso8601String()}');
  stdout.writeln('segment candidates=${segmentCandidatesFile.path}');
  stdout.writeln('segment results=${segmentResultsFile.path}');
  stdout.writeln('Flutter API=http://127.0.0.1:8787/api/live');
  stdout.writeln('No broker orders are sent. Ctrl+C to stop.');

  ProcessSignal.sigint.watch().listen((_) async {
    await liveApi.dispose();
    await session.dispose();
    exit(0);
  });

  await liveApi.start();
  await session.start();
  await Completer<void>().future;
}

Future<DateTime> _resolveImmutableSegmentStart(
  File stateFile,
  DateTime proposed,
) async {
  if (!stateFile.existsSync()) return proposed.toUtc();
  final decoded = jsonDecode(await stateFile.readAsString());
  if (decoded is Map<String, dynamic>) {
    final persisted = DateTime.tryParse(decoded['startAt']?.toString() ?? '');
    if (persisted != null) return persisted.toUtc();
  }
  throw StateError(
    'Existing segment state has no valid startAt: ${stateFile.path}',
  );
}
