import 'package:technical_analysis/technical_analysis.dart';

import '../bias/multi_timeframe_bias.dart';

enum MarketStructureEvidenceType { directionalM15Structure }

final class MarketStructureEvidence {
  const MarketStructureEvidence({required this.type, required this.present});

  final MarketStructureEvidenceType type;
  final bool present;
}

/// Converts M15 market structure into SOFT strategy evidence.
///
/// BUY benefits from bullish M15 structure.
/// SELL benefits from bearish M15 structure.
/// Neutral, unknown, or opposite structure simply means the evidence is absent;
/// it does not block an otherwise eligible setup.
final class MarketStructureEvidenceEvaluator {
  const MarketStructureEvidenceEvaluator();

  MarketStructureEvidence evaluate({
    required TradingBias bias,
    required MarketStructure m15Structure,
  }) {
    final present = switch (bias) {
      TradingBias.buy => m15Structure == MarketStructure.bullish,
      TradingBias.sell => m15Structure == MarketStructure.bearish,
      TradingBias.noTrade => false,
    };

    return MarketStructureEvidence(
      type: MarketStructureEvidenceType.directionalM15Structure,
      present: present,
    );
  }
}
