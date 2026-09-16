import 'package:strategy_engine/strategy_engine.dart';

enum PendingSignalValidityState { valid, invalidated, expired }

enum PendingSignalValidityReason {
  structureStillValid,
  buyStructureInvalidated,
  sellStructureInvalidated,
  maximumWaitingCandlesReached,
}

/// Validity of a signal that has not triggered yet.
///
/// This deliberately operates before Entry Zone trigger. It prevents TradeForge
/// from continuing to present an old READY signal after its structural
/// invalidation boundary has been crossed or its explicit waiting budget has
/// elapsed.
final class PendingSignalValidity {
  const PendingSignalValidity({required this.state, required this.reason});

  final PendingSignalValidityState state;
  final PendingSignalValidityReason reason;

  bool get canStillTrigger => state == PendingSignalValidityState.valid;
  bool get isTerminal => state != PendingSignalValidityState.valid;
}

final class PendingSignalValidityEvaluator {
  const PendingSignalValidityEvaluator();

  PendingSignalValidity evaluate({
    required TradingBias bias,
    required double structuralBoundary,
    required double candleClose,
    required int waitingCandles,
    required int maximumWaitingCandles,
  }) {
    _requireFinite(structuralBoundary, 'structuralBoundary');
    _requireFinite(candleClose, 'candleClose');

    if (bias == TradingBias.noTrade) {
      throw ArgumentError('Pending signal validity requires BUY or SELL bias.');
    }
    if (waitingCandles < 0) {
      throw ArgumentError.value(
        waitingCandles,
        'waitingCandles',
        'waitingCandles must be >= 0.',
      );
    }
    if (maximumWaitingCandles <= 0) {
      throw ArgumentError.value(
        maximumWaitingCandles,
        'maximumWaitingCandles',
        'maximumWaitingCandles must be > 0.',
      );
    }

    // Structure invalidation has priority over expiry when both become true on
    // the same closed candle, because it describes why the setup itself failed.
    if (bias == TradingBias.buy && candleClose < structuralBoundary) {
      return const PendingSignalValidity(
        state: PendingSignalValidityState.invalidated,
        reason: PendingSignalValidityReason.buyStructureInvalidated,
      );
    }

    if (bias == TradingBias.sell && candleClose > structuralBoundary) {
      return const PendingSignalValidity(
        state: PendingSignalValidityState.invalidated,
        reason: PendingSignalValidityReason.sellStructureInvalidated,
      );
    }

    if (waitingCandles >= maximumWaitingCandles) {
      return const PendingSignalValidity(
        state: PendingSignalValidityState.expired,
        reason: PendingSignalValidityReason.maximumWaitingCandlesReached,
      );
    }

    return const PendingSignalValidity(
      state: PendingSignalValidityState.valid,
      reason: PendingSignalValidityReason.structureStillValid,
    );
  }

  void _requireFinite(double value, String name) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, name, '$name must be finite.');
    }
  }
}
