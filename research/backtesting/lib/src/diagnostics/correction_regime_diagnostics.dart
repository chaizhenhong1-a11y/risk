import 'package:strategy_engine/strategy_engine.dart';
import 'package:technical_analysis/technical_analysis.dart';

/// Research-only diagnostics for the H4-trend / H1-correction regime.
///
/// This collector deliberately does not produce a trading decision. It measures
/// observable evidence that can later be used to specify and independently
/// backtest a Strategy B hypothesis.
final class CorrectionRegimeDiagnostics {
  int observations = 0;
  int bullishObservations = 0;
  int bearishObservations = 0;
  int episodes = 0;
  int bullishEpisodes = 0;
  int bearishEpisodes = 0;
  int maximumEpisodeM5 = 0;
  int _activeEpisodeM5 = 0;
  MarketRegimeDirection? _activeDirection;

  final Map<MarketStructure, int> m15StructureObservations = {
    for (final structure in MarketStructure.values) structure: 0,
  };

  int m15AlignedWithH4 = 0;
  int m15OpposedToH4 = 0;
  int m15NeutralOrUnknown = 0;
  int directionalLevelSweepObservations = 0;
  int directionalPoolSweepObservations = 0;
  int anyDirectionalSweepObservations = 0;

  void observe({
    required MarketRegimeAnalysis regimeAnalysis,
    required MarketStructure m15Structure,
    required LevelLiquidityAnalysis levelLiquidityAnalysis,
  }) {
    if (regimeAnalysis.regime !=
        MarketRegime.higherTimeframeTrendLowerTimeframeCorrection) {
      _closeEpisode();
      return;
    }

    final direction = regimeAnalysis.direction;
    if (direction == MarketRegimeDirection.none) {
      throw StateError('Correction regime must retain an H4 direction.');
    }

    observations++;
    switch (direction) {
      case MarketRegimeDirection.bullish:
        bullishObservations++;
      case MarketRegimeDirection.bearish:
        bearishObservations++;
      case MarketRegimeDirection.none:
        throw StateError('Correction regime cannot have no direction.');
    }

    if (_activeDirection != direction) {
      _closeEpisode();
      episodes++;
      _activeDirection = direction;
      _activeEpisodeM5 = 1;
      if (direction == MarketRegimeDirection.bullish) {
        bullishEpisodes++;
      } else {
        bearishEpisodes++;
      }
    } else {
      _activeEpisodeM5++;
    }

    m15StructureObservations.update(m15Structure, (count) => count + 1);
    if (_isAligned(m15Structure, direction)) {
      m15AlignedWithH4++;
    } else if (_isOpposed(m15Structure, direction)) {
      m15OpposedToH4++;
    } else {
      m15NeutralOrUnknown++;
    }

    final directionalLevelSweep = levelLiquidityAnalysis.levelSweeps.any(
      (sweep) => switch (direction) {
        MarketRegimeDirection.bullish =>
          sweep.direction == LiquiditySweepDirection.belowSupport,
        MarketRegimeDirection.bearish =>
          sweep.direction == LiquiditySweepDirection.aboveResistance,
        MarketRegimeDirection.none => false,
      },
    );
    final directionalPoolSweep = levelLiquidityAnalysis.poolSweeps.any(
      (sweep) => switch (direction) {
        MarketRegimeDirection.bullish =>
          sweep.direction == LiquidityPoolSweepDirection.belowEqualLows,
        MarketRegimeDirection.bearish =>
          sweep.direction == LiquidityPoolSweepDirection.aboveEqualHighs,
        MarketRegimeDirection.none => false,
      },
    );

    if (directionalLevelSweep) directionalLevelSweepObservations++;
    if (directionalPoolSweep) directionalPoolSweepObservations++;
    if (directionalLevelSweep || directionalPoolSweep) {
      anyDirectionalSweepObservations++;
    }
  }

  void finish() => _closeEpisode();

  double share(int count) => observations == 0 ? 0 : count / observations;

  bool _isAligned(MarketStructure structure, MarketRegimeDirection direction) =>
      (direction == MarketRegimeDirection.bullish &&
          structure == MarketStructure.bullish) ||
      (direction == MarketRegimeDirection.bearish &&
          structure == MarketStructure.bearish);

  bool _isOpposed(MarketStructure structure, MarketRegimeDirection direction) =>
      (direction == MarketRegimeDirection.bullish &&
          structure == MarketStructure.bearish) ||
      (direction == MarketRegimeDirection.bearish &&
          structure == MarketStructure.bullish);

  void _closeEpisode() {
    if (_activeDirection == null) return;
    if (_activeEpisodeM5 > maximumEpisodeM5) {
      maximumEpisodeM5 = _activeEpisodeM5;
    }
    _activeDirection = null;
    _activeEpisodeM5 = 0;
  }
}
