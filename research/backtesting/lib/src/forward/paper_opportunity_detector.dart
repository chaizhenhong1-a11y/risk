import 'paper_candle.dart';
import 'paper_strategy_opportunity.dart';

abstract interface class PaperOpportunityDetector {
  String get strategy;

  /// Evaluates only closed candles supplied by the forward feed.
  ///
  /// Frozen A/C5 adapters implement this boundary; the coordinator itself
  /// does not score, loosen, or add strategy gates.
  List<PaperStrategyOpportunity> detect(List<PaperCandle> closedCandles);
}
