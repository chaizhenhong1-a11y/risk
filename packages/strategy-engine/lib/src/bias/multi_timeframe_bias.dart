import 'package:technical_analysis/technical_analysis.dart';

enum TradingBias { buy, sell, noTrade }

enum TradingBiasReason {
  h4H1BullishAlignment,
  h4H1BearishAlignment,
  higherTimeframeConflict,
  higherTimeframeNeutral,
  higherTimeframeUnknown,
}

final class MultiTimeframeBias {
  const MultiTimeframeBias({
    required this.bias,
    required this.reason,
    required this.h4Structure,
    required this.h1Structure,
    this.d1Context,
  });

  final TradingBias bias;
  final TradingBiasReason reason;
  final MarketStructure h4Structure;
  final MarketStructure h1Structure;

  /// D1 is retained as market context only in the Phase 4 baseline.
  /// It deliberately does not gate BUY/SELL direction yet.
  final MarketStructure? d1Context;

  bool get canLookForBuy => bias == TradingBias.buy;
  bool get canLookForSell => bias == TradingBias.sell;
  bool get shouldStandAside => bias == TradingBias.noTrade;
}

final class MultiTimeframeBiasAnalyzer {
  const MultiTimeframeBiasAnalyzer();

  MultiTimeframeBias analyze({
    required MarketStructure h4Structure,
    required MarketStructure h1Structure,
    MarketStructure? d1Context,
  }) {
    final reason = _reasonFor(
      h4Structure: h4Structure,
      h1Structure: h1Structure,
    );

    final bias = switch (reason) {
      TradingBiasReason.h4H1BullishAlignment => TradingBias.buy,
      TradingBiasReason.h4H1BearishAlignment => TradingBias.sell,
      TradingBiasReason.higherTimeframeConflict ||
      TradingBiasReason.higherTimeframeNeutral ||
      TradingBiasReason.higherTimeframeUnknown => TradingBias.noTrade,
    };

    return MultiTimeframeBias(
      bias: bias,
      reason: reason,
      h4Structure: h4Structure,
      h1Structure: h1Structure,
      d1Context: d1Context,
    );
  }

  TradingBiasReason _reasonFor({
    required MarketStructure h4Structure,
    required MarketStructure h1Structure,
  }) {
    if (h4Structure == MarketStructure.unknown ||
        h1Structure == MarketStructure.unknown) {
      return TradingBiasReason.higherTimeframeUnknown;
    }

    if (h4Structure == MarketStructure.neutral ||
        h1Structure == MarketStructure.neutral) {
      return TradingBiasReason.higherTimeframeNeutral;
    }

    if (h4Structure == MarketStructure.bullish &&
        h1Structure == MarketStructure.bullish) {
      return TradingBiasReason.h4H1BullishAlignment;
    }

    if (h4Structure == MarketStructure.bearish &&
        h1Structure == MarketStructure.bearish) {
      return TradingBiasReason.h4H1BearishAlignment;
    }

    return TradingBiasReason.higherTimeframeConflict;
  }
}
