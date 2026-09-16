import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';

enum TargetCandidateStatus { unavailable, available }

enum TargetCandidateUnavailableReason {
  noDirectionalBias,
  noOpposingActiveLevelAhead,
}

/// First structure-derived take-profit candidate.
///
/// BUY targets the nearest active resistance ahead of the reference price.
/// SELL targets the nearest active support ahead of the reference price.
///
/// The target price uses the near edge of the opposing zone instead of its
/// midpoint/far edge, avoiding an assumption that price must fully traverse
/// the zone.
final class TargetCandidate {
  const TargetCandidate({
    required this.price,
    required this.bias,
    required this.sourceLevel,
  });

  final double price;
  final TradingBias bias;
  final KeyLevel sourceLevel;
}

final class TargetCandidateAnalysis {
  const TargetCandidateAnalysis._({
    required this.status,
    this.target,
    this.unavailableReason,
  });

  const TargetCandidateAnalysis.available(TargetCandidate target)
    : this._(status: TargetCandidateStatus.available, target: target);

  const TargetCandidateAnalysis.unavailable(
    TargetCandidateUnavailableReason reason,
  ) : this._(
        status: TargetCandidateStatus.unavailable,
        unavailableReason: reason,
      );

  final TargetCandidateStatus status;
  final TargetCandidate? target;
  final TargetCandidateUnavailableReason? unavailableReason;

  bool get isAvailable => status == TargetCandidateStatus.available;
}

/// Finds the nearest opposing active Key Level in the trade direction.
///
/// [referencePrice] is explicit. A later integration increment can decide
/// whether that reference should be Entry Zone midpoint, edge, or an actual
/// user execution price.
final class TargetCandidatePlanner {
  const TargetCandidatePlanner();

  TargetCandidateAnalysis plan({
    required TradingBias bias,
    required double referencePrice,
    required Iterable<KeyLevel> keyLevels,
  }) {
    if (!referencePrice.isFinite) {
      throw ArgumentError.value(
        referencePrice,
        'referencePrice',
        'Reference price must be finite.',
      );
    }

    if (bias == TradingBias.noTrade) {
      return const TargetCandidateAnalysis.unavailable(
        TargetCandidateUnavailableReason.noDirectionalBias,
      );
    }

    KeyLevel? nearest;

    for (final level in keyLevels) {
      if (!level.isActive) continue;

      final isCandidate = switch (bias) {
        TradingBias.buy =>
          level.type == KeyLevelType.resistance &&
              level.lowerBound > referencePrice,
        TradingBias.sell =>
          level.type == KeyLevelType.support &&
              level.upperBound < referencePrice,
        TradingBias.noTrade => false,
      };

      if (!isCandidate) continue;

      if (nearest == null) {
        nearest = level;
        continue;
      }

      final candidatePrice = _targetPrice(bias, level);
      final nearestPrice = _targetPrice(bias, nearest);

      final isCloser = switch (bias) {
        TradingBias.buy => candidatePrice < nearestPrice,
        TradingBias.sell => candidatePrice > nearestPrice,
        TradingBias.noTrade => false,
      };

      if (isCloser ||
          (candidatePrice == nearestPrice &&
              level.createdAtCandleIndex > nearest.createdAtCandleIndex)) {
        nearest = level;
      }
    }

    if (nearest == null) {
      return const TargetCandidateAnalysis.unavailable(
        TargetCandidateUnavailableReason.noOpposingActiveLevelAhead,
      );
    }

    return TargetCandidateAnalysis.available(
      TargetCandidate(
        price: _targetPrice(bias, nearest),
        bias: bias,
        sourceLevel: nearest,
      ),
    );
  }

  double _targetPrice(TradingBias bias, KeyLevel level) {
    return switch (bias) {
      TradingBias.buy => level.lowerBound,
      TradingBias.sell => level.upperBound,
      TradingBias.noTrade => throw StateError('NO TRADE has no target price.'),
    };
  }
}
