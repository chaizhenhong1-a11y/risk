import 'package:technical_analysis/technical_analysis.dart';

enum TransitionStructurePair {
  bullishNeutral,
  bearishNeutral,
  neutralBullish,
  neutralBearish,
  neutralNeutral,
  other,
}

final class TransitionRegimeResearchDiagnostics {
  final Map<TransitionStructurePair, int> _observations = {
    for (final value in TransitionStructurePair.values) value: 0,
  };
  final Map<TransitionStructurePair, Map<MarketStructure, int>> _m15 = {
    for (final value in TransitionStructurePair.values)
      value: {for (final structure in MarketStructure.values) structure: 0},
  };
  final List<int> _episodeLengths = [];
  final Map<String, int> _exits = {};
  TransitionStructurePair? _activePair;
  int _activeLength = 0;

  void observeTransition({
    required MarketStructure h4,
    required MarketStructure h1,
    required MarketStructure m15,
  }) {
    final pair = classifyPair(h4, h1);
    _observations[pair] = _observations[pair]! + 1;
    _m15[pair]![m15] = _m15[pair]![m15]! + 1;

    if (_activePair == null) {
      _activePair = pair;
      _activeLength = 1;
    } else {
      _activeLength++;
    }
  }

  void observeExit(String exitName) {
    if (_activePair == null) return;
    _episodeLengths.add(_activeLength);
    final key = '${_activePair!.name}->$exitName';
    _exits[key] = (_exits[key] ?? 0) + 1;
    _activePair = null;
    _activeLength = 0;
  }

  void finishOpenEpisode() {
    if (_activePair == null) return;
    _episodeLengths.add(_activeLength);
    final key = '${_activePair!.name}->datasetEnd';
    _exits[key] = (_exits[key] ?? 0) + 1;
    _activePair = null;
    _activeLength = 0;
  }

  TransitionRegimeResearchReport report() => TransitionRegimeResearchReport(
    observations: _observations,
    m15Structures: _m15,
    episodeLengths: _episodeLengths,
    exits: _exits,
  );

  static TransitionStructurePair classifyPair(
    MarketStructure h4,
    MarketStructure h1,
  ) {
    if (h4 == MarketStructure.bullish && h1 == MarketStructure.neutral) {
      return TransitionStructurePair.bullishNeutral;
    }
    if (h4 == MarketStructure.bearish && h1 == MarketStructure.neutral) {
      return TransitionStructurePair.bearishNeutral;
    }
    if (h4 == MarketStructure.neutral && h1 == MarketStructure.bullish) {
      return TransitionStructurePair.neutralBullish;
    }
    if (h4 == MarketStructure.neutral && h1 == MarketStructure.bearish) {
      return TransitionStructurePair.neutralBearish;
    }
    if (h4 == MarketStructure.neutral && h1 == MarketStructure.neutral) {
      return TransitionStructurePair.neutralNeutral;
    }
    return TransitionStructurePair.other;
  }
}

final class TransitionRegimeResearchReport {
  TransitionRegimeResearchReport({
    required Map<TransitionStructurePair, int> observations,
    required Map<TransitionStructurePair, Map<MarketStructure, int>>
    m15Structures,
    required List<int> episodeLengths,
    required Map<String, int> exits,
  }) : observations = Map<TransitionStructurePair, int>.unmodifiable(
         observations,
       ),
       m15Structures =
           Map<TransitionStructurePair, Map<MarketStructure, int>>.unmodifiable(
             m15Structures
                 .map<TransitionStructurePair, Map<MarketStructure, int>>(
                   (key, value) => MapEntry(
                     key,
                     Map<MarketStructure, int>.unmodifiable(value),
                   ),
                 ),
           ),
       episodeLengths = List<int>.unmodifiable(episodeLengths),
       exits = Map<String, int>.unmodifiable(exits);

  final Map<TransitionStructurePair, int> observations;
  final Map<TransitionStructurePair, Map<MarketStructure, int>> m15Structures;
  final List<int> episodeLengths;
  final Map<String, int> exits;

  int get totalObservations =>
      observations.values.fold(0, (sum, value) => sum + value);

  double share(TransitionStructurePair pair) => totalObservations == 0
      ? 0
      : (observations[pair] ?? 0) / totalObservations;

  double get averageEpisodeLength => episodeLengths.isEmpty
      ? 0
      : episodeLengths.fold<int>(0, (sum, value) => sum + value) /
            episodeLengths.length;

  double get medianEpisodeLength {
    if (episodeLengths.isEmpty) return 0;
    final values = [...episodeLengths]..sort();
    final middle = values.length ~/ 2;
    if (values.length.isOdd) return values[middle].toDouble();
    return (values[middle - 1] + values[middle]) / 2;
  }
}
