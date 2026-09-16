import 'package:technical_analysis/technical_analysis.dart';

import '../bias/multi_timeframe_bias.dart';

enum D1ContextAlignment { unavailable, aligned, neutral, opposed }

final class D1ContextEvidence {
  const D1ContextEvidence({required this.alignment});

  final D1ContextAlignment alignment;

  bool get present => alignment == D1ContextAlignment.aligned;
}

/// Converts D1 market context into SOFT strategy evidence.
///
/// D1 is deliberately not a direction gate in the current baseline.
/// Alignment adds evidence; neutral, unknown, or opposed D1 context does not
/// block an otherwise eligible setup.
final class D1ContextEvidenceEvaluator {
  const D1ContextEvidenceEvaluator();

  D1ContextEvidence evaluate({
    required TradingBias bias,
    required MarketStructure d1Structure,
  }) {
    if (bias == TradingBias.noTrade || d1Structure == MarketStructure.unknown) {
      return const D1ContextEvidence(alignment: D1ContextAlignment.unavailable);
    }

    if (d1Structure == MarketStructure.neutral) {
      return const D1ContextEvidence(alignment: D1ContextAlignment.neutral);
    }

    final aligned = switch (bias) {
      TradingBias.buy => d1Structure == MarketStructure.bullish,
      TradingBias.sell => d1Structure == MarketStructure.bearish,
      TradingBias.noTrade => false,
    };

    return D1ContextEvidence(
      alignment: aligned
          ? D1ContextAlignment.aligned
          : D1ContextAlignment.opposed,
    );
  }
}
