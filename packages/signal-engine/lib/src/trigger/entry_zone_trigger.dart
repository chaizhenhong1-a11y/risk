import 'package:risk_engine/risk_engine.dart';
import 'package:strategy_engine/strategy_engine.dart';

enum EntryZoneTriggerState { notApplicable, waiting, triggered }

enum EntryZoneTriggerReason {
  noDirectionalBias,
  noEntryZone,
  candleDidNotReachEntryZone,
  candleReachedEntryZone,
}

/// Deterministic observation of whether a closed candle reached the planned
/// Entry Zone.
///
/// This is deliberately only trigger evidence. It does not mutate lifecycle
/// state, execute an order, or decide a fill price.
final class EntryZoneTriggerAnalysis {
  const EntryZoneTriggerAnalysis({required this.state, required this.reason});

  final EntryZoneTriggerState state;
  final EntryZoneTriggerReason reason;

  bool get isTriggered => state == EntryZoneTriggerState.triggered;
}

final class EntryZoneTriggerDetector {
  const EntryZoneTriggerDetector();

  EntryZoneTriggerAnalysis detect({
    required TradingBias bias,
    required EntryZoneAnalysis entryZoneAnalysis,
    required double candleLow,
    required double candleHigh,
  }) {
    if (!candleLow.isFinite || !candleHigh.isFinite) {
      throw ArgumentError('Candle prices must be finite.');
    }
    if (candleLow > candleHigh) {
      throw ArgumentError('candleLow must be <= candleHigh.');
    }

    if (bias == TradingBias.noTrade) {
      return const EntryZoneTriggerAnalysis(
        state: EntryZoneTriggerState.notApplicable,
        reason: EntryZoneTriggerReason.noDirectionalBias,
      );
    }

    final zone = entryZoneAnalysis.zone;
    if (!entryZoneAnalysis.isAvailable || zone == null) {
      return const EntryZoneTriggerAnalysis(
        state: EntryZoneTriggerState.notApplicable,
        reason: EntryZoneTriggerReason.noEntryZone,
      );
    }

    // Inclusive range intersection: touching either Entry Zone boundary counts
    // as market contact with the zone.
    final reached =
        candleHigh >= zone.lowerBound && candleLow <= zone.upperBound;

    if (!reached) {
      return const EntryZoneTriggerAnalysis(
        state: EntryZoneTriggerState.waiting,
        reason: EntryZoneTriggerReason.candleDidNotReachEntryZone,
      );
    }

    return const EntryZoneTriggerAnalysis(
      state: EntryZoneTriggerState.triggered,
      reason: EntryZoneTriggerReason.candleReachedEntryZone,
    );
  }
}
