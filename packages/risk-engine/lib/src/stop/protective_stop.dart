import 'package:strategy_engine/strategy_engine.dart';

import 'structural_stop.dart';

enum ProtectiveStopStatus { unavailable, available }

enum ProtectiveStopUnavailableReason { noStructuralStop, invalidBuffer }

/// Explicit distance placed outside the structural invalidation boundary.
///
/// This is intentionally a value object. The source of the distance is not
/// decided here; a later increment can derive it from ATR/volatility while
/// preserving the protective-stop planner.
final class StopBuffer {
  StopBuffer(this.distance) {
    if (!distance.isFinite || distance <= 0) {
      throw ArgumentError.value(
        distance,
        'distance',
        'Stop buffer must be finite and greater than zero.',
      );
    }
  }

  final double distance;
}

/// Protective stop price derived from structure plus an explicit buffer.
///
/// BUY  -> structural boundary - buffer
/// SELL -> structural boundary + buffer
///
/// This remains planning data and is not an order-execution instruction.
final class ProtectiveStop {
  const ProtectiveStop({
    required this.price,
    required this.structuralBoundary,
    required this.bufferDistance,
    required this.bias,
  });

  final double price;
  final double structuralBoundary;
  final double bufferDistance;
  final TradingBias bias;

  bool get isOutsideStructure => switch (bias) {
    TradingBias.buy => price < structuralBoundary,
    TradingBias.sell => price > structuralBoundary,
    TradingBias.noTrade => false,
  };
}

final class ProtectiveStopAnalysis {
  const ProtectiveStopAnalysis._({
    required this.status,
    this.stop,
    this.unavailableReason,
  });

  const ProtectiveStopAnalysis.available(ProtectiveStop stop)
    : this._(status: ProtectiveStopStatus.available, stop: stop);

  const ProtectiveStopAnalysis.unavailable(
    ProtectiveStopUnavailableReason reason,
  ) : this._(
        status: ProtectiveStopStatus.unavailable,
        unavailableReason: reason,
      );

  final ProtectiveStopStatus status;
  final ProtectiveStop? stop;
  final ProtectiveStopUnavailableReason? unavailableReason;

  bool get isAvailable => status == ProtectiveStopStatus.available;
}

/// Converts a structural invalidation boundary into a buffered protective stop.
///
/// The planner does not decide the buffer magnitude. That value must be
/// supplied explicitly so future ATR logic can be swapped in independently.
final class ProtectiveStopPlanner {
  const ProtectiveStopPlanner();

  ProtectiveStopAnalysis plan({
    required StructuralStopAnalysis structuralStopAnalysis,
    required StopBuffer buffer,
  }) {
    final structuralStop = structuralStopAnalysis.stop;
    if (!structuralStopAnalysis.isAvailable || structuralStop == null) {
      return const ProtectiveStopAnalysis.unavailable(
        ProtectiveStopUnavailableReason.noStructuralStop,
      );
    }

    final price = switch (structuralStop.bias) {
      TradingBias.buy => structuralStop.price - buffer.distance,
      TradingBias.sell => structuralStop.price + buffer.distance,
      TradingBias.noTrade => throw StateError(
        'Available structural stop cannot have NO TRADE bias.',
      ),
    };

    if (!price.isFinite) {
      return const ProtectiveStopAnalysis.unavailable(
        ProtectiveStopUnavailableReason.invalidBuffer,
      );
    }

    return ProtectiveStopAnalysis.available(
      ProtectiveStop(
        price: price,
        structuralBoundary: structuralStop.price,
        bufferDistance: buffer.distance,
        bias: structuralStop.bias,
      ),
    );
  }
}
