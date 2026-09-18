import 'dart:io';

import 'biquote_live_market_snapshot.dart';
import 'biquote_market_data.dart';
import 'biquote_paper_candle_adapter.dart';
import 'frozen_live_a_c5_evaluator.dart';
import 'paper_candle.dart';
import 'paper_forward_coordinator.dart';
import 'paper_opportunity_detector.dart';
import 'paper_strategy_opportunity.dart';

/// One-shot detector used to hand an already-evaluated live opportunity to the
/// existing append-only Paper Forward coordinator.
final class _LiveOpportunityDetector implements PaperOpportunityDetector {
  const _LiveOpportunityDetector(this.opportunity);

  final PaperStrategyOpportunity opportunity;

  @override
  String get strategy => opportunity.strategy;

  @override
  List<PaperStrategyOpportunity> detect(List<PaperCandle> closedCandles) =>
      <PaperStrategyOpportunity>[opportunity];
}

/// Persists frozen A/C5 live opportunities and advances the existing paper
/// lifecycle against the same anti-lookahead CLOSED-M5 prefix.
///
/// Signal IDs/journal dedupe/result semantics remain owned by the existing
/// Paper Forward infrastructure; this class adds no new trade rules.
final class LivePaperSignalRunner {
  LivePaperSignalRunner({
    required this.signalsFile,
    required this.resultsFile,
    PaperForwardCoordinator? coordinator,
    FrozenLiveAC5Evaluator? evaluator,
    BiQuotePaperCandleAdapter? candleAdapter,
  }) : coordinator = coordinator ?? PaperForwardCoordinator(),
       evaluator = evaluator ?? FrozenLiveAC5Evaluator(),
       _candleAdapter = candleAdapter ?? const BiQuotePaperCandleAdapter();

  final File signalsFile;
  final File resultsFile;
  final PaperForwardCoordinator coordinator;
  final FrozenLiveAC5Evaluator evaluator;
  final BiQuotePaperCandleAdapter _candleAdapter;
  FrozenLiveAC5Evaluation? _lastEvaluation;

  FrozenLiveAC5Evaluation? get lastEvaluation => _lastEvaluation;

  PaperForwardCoordinatorReport recoverFromClosedM5(
    List<BiQuoteClosedBar> bars,
  ) {
    final candles = bars.map(_candleAdapter.convert).toList(growable: false);
    return coordinator.run(
      closedCandles: candles,
      detectors: const <PaperOpportunityDetector>[],
      signalsFile: signalsFile,
      resultsFile: resultsFile,
    );
  }

  Future<PaperForwardCoordinatorReport> onClosedM5(
    BiQuoteLiveMarketSnapshot snapshot,
  ) async {
    final evaluation = evaluator.evaluate(snapshot);
    _lastEvaluation = evaluation;
    final detectors = <PaperOpportunityDetector>[
      for (final opportunity in evaluation.opportunities)
        _LiveOpportunityDetector(opportunity),
    ];

    // Even with zero new opportunities the coordinator still receives the
    // newest closed-M5 prefix so previously-triggered paper signals can advance
    // toward TP/SL/ambiguous outcomes.
    return coordinator.run(
      closedCandles: snapshot.m5
          .map(_candleAdapter.convert)
          .toList(growable: false),
      detectors: detectors,
      signalsFile: signalsFile,
      resultsFile: resultsFile,
    );
  }
}
