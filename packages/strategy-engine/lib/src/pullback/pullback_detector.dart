import 'package:market_models/market_models.dart';
import 'package:technical_analysis/technical_analysis.dart';

import '../bias/multi_timeframe_bias.dart';

enum PullbackState { notApplicable, waiting, inZone }

enum PullbackReason {
  noTradeBias,
  noActiveDirectionalLevel,
  priceNotAtDirectionalLevel,
  priceAtSupport,
  priceAtResistance,
}

final class PullbackAnalysis {
  const PullbackAnalysis({
    required this.state,
    required this.reason,
    this.matchedLevel,
  });

  final PullbackState state;
  final PullbackReason reason;
  final KeyLevel? matchedLevel;

  bool get hasPullback => state == PullbackState.inZone;
}

/// Baseline pullback detector for the Trend + Pullback strategy.
///
/// BUY bias may only pull back into an ACTIVE support zone.
/// SELL bias may only pull back into an ACTIVE resistance zone.
///
/// A candle touching a directional level is evidence of a pullback only.
/// It is deliberately NOT an entry confirmation.
final class PullbackDetector {
  const PullbackDetector();

  PullbackAnalysis analyze({
    required TradingBias bias,
    required Candle closedCandle,
    required Iterable<KeyLevel> keyLevels,
  }) {
    if (bias == TradingBias.noTrade) {
      return const PullbackAnalysis(
        state: PullbackState.notApplicable,
        reason: PullbackReason.noTradeBias,
      );
    }

    final directionalType = bias == TradingBias.buy
        ? KeyLevelType.support
        : KeyLevelType.resistance;

    final candidates = keyLevels
        .where((level) => level.isActive && level.type == directionalType)
        .toList(growable: false);

    if (candidates.isEmpty) {
      return const PullbackAnalysis(
        state: PullbackState.waiting,
        reason: PullbackReason.noActiveDirectionalLevel,
      );
    }

    final touched = candidates.where(
      (level) =>
          closedCandle.high >= level.lowerBound &&
          closedCandle.low <= level.upperBound,
    );

    if (touched.isEmpty) {
      return const PullbackAnalysis(
        state: PullbackState.waiting,
        reason: PullbackReason.priceNotAtDirectionalLevel,
      );
    }

    final matchedLevel = _nearestToClose(touched, closedCandle.close);

    return PullbackAnalysis(
      state: PullbackState.inZone,
      reason: bias == TradingBias.buy
          ? PullbackReason.priceAtSupport
          : PullbackReason.priceAtResistance,
      matchedLevel: matchedLevel,
    );
  }

  KeyLevel _nearestToClose(Iterable<KeyLevel> levels, double close) {
    return levels.reduce((best, candidate) {
      final bestDistance = (best.midpoint - close).abs();
      final candidateDistance = (candidate.midpoint - close).abs();

      if (candidateDistance < bestDistance) {
        return candidate;
      }

      if (candidateDistance == bestDistance &&
          candidate.createdAtCandleIndex > best.createdAtCandleIndex) {
        return candidate;
      }

      return best;
    });
  }
}
