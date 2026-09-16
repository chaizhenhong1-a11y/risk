import 'package:market_models/market_models.dart';

import '../bias/multi_timeframe_bias.dart';
import '../pullback/pullback_detector.dart';

enum PullbackConfirmationState { notApplicable, waiting, confirmed }

enum PullbackConfirmationReason {
  noTradeBias,
  pullbackNotInZone,
  waitingForBullishRejection,
  waitingForBearishRejection,
  bullishRejectionConfirmed,
  bearishRejectionConfirmed,
}

final class PullbackConfirmation {
  const PullbackConfirmation({required this.state, required this.reason});

  final PullbackConfirmationState state;
  final PullbackConfirmationReason reason;

  bool get isConfirmed => state == PullbackConfirmationState.confirmed;
}

/// Baseline price-action confirmation after a directional pullback.
///
/// This first confirmation rule is deliberately small and deterministic:
/// - BUY: price must have entered support, close bullish, and close back above
///   the matched support zone.
/// - SELL: price must have entered resistance, close bearish, and close back
///   below the matched resistance zone.
///
/// This is evidence that price rejected the pullback zone. It is not yet a
/// final trade trigger and does not calculate Entry, SL, TP, RR, or score.
final class PullbackConfirmationAnalyzer {
  const PullbackConfirmationAnalyzer();

  PullbackConfirmation analyze({
    required TradingBias bias,
    required PullbackAnalysis pullback,
    required Candle closedCandle,
  }) {
    if (bias == TradingBias.noTrade) {
      return const PullbackConfirmation(
        state: PullbackConfirmationState.notApplicable,
        reason: PullbackConfirmationReason.noTradeBias,
      );
    }

    if (!pullback.hasPullback || pullback.matchedLevel == null) {
      return const PullbackConfirmation(
        state: PullbackConfirmationState.waiting,
        reason: PullbackConfirmationReason.pullbackNotInZone,
      );
    }

    final level = pullback.matchedLevel!;

    if (bias == TradingBias.buy) {
      final confirmed =
          closedCandle.isBullish && closedCandle.close > level.upperBound;

      return PullbackConfirmation(
        state: confirmed
            ? PullbackConfirmationState.confirmed
            : PullbackConfirmationState.waiting,
        reason: confirmed
            ? PullbackConfirmationReason.bullishRejectionConfirmed
            : PullbackConfirmationReason.waitingForBullishRejection,
      );
    }

    final confirmed =
        closedCandle.isBearish && closedCandle.close < level.lowerBound;

    return PullbackConfirmation(
      state: confirmed
          ? PullbackConfirmationState.confirmed
          : PullbackConfirmationState.waiting,
      reason: confirmed
          ? PullbackConfirmationReason.bearishRejectionConfirmed
          : PullbackConfirmationReason.waitingForBearishRejection,
    );
  }
}
