import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';

import '../entry/entry_zone.dart';

enum StructuralStopStatus { unavailable, available }

enum StructuralStopUnavailableReason {
  noDirectionalBias,
  noEntryZone,
  mismatchedDirectionalLevel,
}

/// Baseline structural invalidation boundary.
///
/// This is not yet a broker-ready stop order. Phase 5 will later add an
/// explicit protective buffer (for example ATR-derived) outside this boundary.
final class StructuralStop {
  const StructuralStop({
    required this.price,
    required this.bias,
    required this.sourceLevel,
  });

  final double price;
  final TradingBias bias;
  final KeyLevel sourceLevel;

  /// True once price has crossed beyond the structural invalidation boundary.
  ///
  /// Touching the boundary itself is not treated as crossed; the later
  /// protective-stop planner may place an actual stop outside this boundary.
  bool isInvalidatedBy(double price) {
    return switch (bias) {
      TradingBias.buy => price < this.price,
      TradingBias.sell => price > this.price,
      TradingBias.noTrade => false,
    };
  }
}

final class StructuralStopAnalysis {
  const StructuralStopAnalysis._({
    required this.status,
    this.stop,
    this.unavailableReason,
  });

  const StructuralStopAnalysis.available(StructuralStop stop)
    : this._(status: StructuralStopStatus.available, stop: stop);

  const StructuralStopAnalysis.unavailable(
    StructuralStopUnavailableReason reason,
  ) : this._(
        status: StructuralStopStatus.unavailable,
        unavailableReason: reason,
      );

  final StructuralStopStatus status;
  final StructuralStop? stop;
  final StructuralStopUnavailableReason? unavailableReason;

  bool get isAvailable => status == StructuralStopStatus.available;
}

/// Plans the pure structural invalidation boundary from the Entry Zone source.
///
/// BUY  -> support lower bound
/// SELL -> resistance upper bound
///
/// No fixed-pip distance, ATR buffer, spread adjustment, position sizing, TP,
/// RR, or order execution is introduced here.
final class StructuralStopPlanner {
  const StructuralStopPlanner();

  StructuralStopAnalysis plan({
    required TradingBias bias,
    required EntryZoneAnalysis entryZoneAnalysis,
  }) {
    if (bias == TradingBias.noTrade) {
      return const StructuralStopAnalysis.unavailable(
        StructuralStopUnavailableReason.noDirectionalBias,
      );
    }

    final zone = entryZoneAnalysis.zone;
    if (!entryZoneAnalysis.isAvailable || zone == null) {
      return const StructuralStopAnalysis.unavailable(
        StructuralStopUnavailableReason.noEntryZone,
      );
    }

    final level = zone.sourceLevel;

    if (bias == TradingBias.buy && level.type != KeyLevelType.support) {
      return const StructuralStopAnalysis.unavailable(
        StructuralStopUnavailableReason.mismatchedDirectionalLevel,
      );
    }

    if (bias == TradingBias.sell && level.type != KeyLevelType.resistance) {
      return const StructuralStopAnalysis.unavailable(
        StructuralStopUnavailableReason.mismatchedDirectionalLevel,
      );
    }

    final price = switch (bias) {
      TradingBias.buy => level.lowerBound,
      TradingBias.sell => level.upperBound,
      TradingBias.noTrade => throw StateError('Unreachable no-trade bias.'),
    };

    return StructuralStopAnalysis.available(
      StructuralStop(price: price, bias: bias, sourceLevel: level),
    );
  }
}
