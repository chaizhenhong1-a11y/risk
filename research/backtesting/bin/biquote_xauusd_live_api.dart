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
import 'package:tradeforge_backtesting/src/forward/independent_candidate_fundamental_coordinator.dart';
import 'package:tradeforge_backtesting/src/fundamentals/alpha_vantage_news_client.dart';
import 'package:tradeforge_backtesting/src/fundamentals/candidate_fundamental_review_service.dart';
import 'package:tradeforge_backtesting/src/fundamentals/finance_calendar_client.dart';
import 'package:tradeforge_backtesting/src/fundamentals/gemini_fundamental_review_client.dart';

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

  final news = AlphaVantageNewsClient();
  final calendar = FinanceCalendarClient();
  final gemini = GeminiFundamentalReviewClient();
  final fundamentalService = CandidateFundamentalReviewService(
    loadNews: (nowUtc) => news.loadGoldNews(nowUtc: nowUtc),
    loadEvents: (nowUtc) => calendar.loadGoldContext(nowUtc: nowUtc),
    review: (candidate, economicCalendar, newsContext) => gemini.review(
      candidate: candidate,
      economicCalendar: economicCalendar,
      newsContext: newsContext,
    ),
  );
  final fundamentalCoordinator = IndependentCandidateFundamentalCoordinator(
    fundamentalService,
    marketStore: store,
  );

  final liveApi = BiQuoteUnifiedLiveApiServer(
    feed: feed,
    session: session,
    segmentCandidateJournal: segmentCandidatesFile,
    fundamentalCoordinator: fundamentalCoordinator,
  );

  stdout.writeln('TradeForge V2 — UNIFIED LIVE UI + Paper Forward');
  stdout.writeln('A/C5 signals=${signalsFile.path}');
  stdout.writeln('A/C5 results=${resultsFile.path}');
  stdout.writeln('segment start=${segmentStartAt.toIso8601String()}');
  stdout.writeln('segment candidates=${segmentCandidatesFile.path}');
  stdout.writeln('segment results=${segmentResultsFile.path}');
  stdout.writeln('Flutter API=http://127.0.0.1:8787/api/live');
  stdout.writeln(
    'Fundamental review=independent candidates + CLOSED M5/M15/H1/H4; fail-open',
  );
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
