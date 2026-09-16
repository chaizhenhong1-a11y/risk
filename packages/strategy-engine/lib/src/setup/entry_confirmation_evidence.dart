import 'package:market_models/market_models.dart';

import '../bias/multi_timeframe_bias.dart';

enum EntryConfirmationEvidenceType { directionalM5Confirmation }

final class EntryConfirmationEvidence {
  const EntryConfirmationEvidence({required this.type, required this.present});

  final EntryConfirmationEvidenceType type;
  final bool present;
}

/// Baseline M5 entry-confirmation evidence.
///
/// BUY receives positive evidence from a closed bullish M5 candle.
/// SELL receives positive evidence from a closed bearish M5 candle.
///
/// This is intentionally SOFT evidence. It is not a final trigger and does not
/// authorize an entry by itself. More precise M5 structure/rejection logic can
/// replace or enrich this baseline after backtesting.
final class EntryConfirmationEvidenceEvaluator {
  const EntryConfirmationEvidenceEvaluator();

  EntryConfirmationEvidence evaluate({
    required TradingBias bias,
    required Candle closedM5Candle,
  }) {
    final present = switch (bias) {
      TradingBias.buy => closedM5Candle.isBullish,
      TradingBias.sell => closedM5Candle.isBearish,
      TradingBias.noTrade => false,
    };

    return EntryConfirmationEvidence(
      type: EntryConfirmationEvidenceType.directionalM5Confirmation,
      present: present,
    );
  }
}
