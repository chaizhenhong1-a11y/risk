import '../dataset/strategy_c_structural_lifecycle_validation.dart';
import 'paper_signal.dart';
import 'paper_strategy_opportunity.dart';

/// Converts the already-frozen C5 structural risk geometry into a paper trade.
///
/// C5 is BUY-only in the validated hypothesis:
/// entry = episode close
/// SL = nearest active M15 support lower bound - M15 ATR14 x 0.50
/// TP = 2R
///
/// Discovery of a NEW C5 episode remains the responsibility of the existing
/// frozen market-structure/liquidity pipeline; this class does not recreate or
/// loosen that setup definition.
final class FrozenC5PaperAdapter {
  const FrozenC5PaperAdapter();

  PaperStrategyOpportunity convert(
    C5StructuralRisk risk, {
    String symbol = 'XAUUSD',
  }) {
    final entry = risk.entryClose;
    final stop = risk.bufferedStopPrice;
    final distance = entry - stop;

    if (!entry.isFinite ||
        !stop.isFinite ||
        !distance.isFinite ||
        distance <= 0) {
      throw ArgumentError('Invalid frozen C5 structural risk geometry.');
    }

    final target = entry + (distance * 2);

    return PaperStrategyOpportunity(
      symbol: symbol,
      strategy: 'C5',
      side: PaperSignalSide.buy,
      observedAt: risk.time,
      entry: entry,
      stopLoss: stop,
      takeProfit: target,
      reason:
          'C5 transition sweep reversal; structural M15 support stop '
          'with ATR14 x 0.50 buffer; frozen 2R target.',
    );
  }
}
