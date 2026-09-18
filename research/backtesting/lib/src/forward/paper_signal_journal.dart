import 'dart:convert';
import 'dart:io';

import 'paper_signal.dart';

final class PaperSignalJournal {
  const PaperSignalJournal();

  /// Append-only and idempotent. Existing deterministic IDs are never written
  /// twice, so restarting a forward scanner cannot duplicate an opportunity.
  bool appendIfNew(File file, PaperSignal signal) {
    file.parent.createSync(recursive: true);

    if (file.existsSync()) {
      for (final line in file.readAsLinesSync()) {
        if (line.trim().isEmpty) continue;
        final json = jsonDecode(line) as Map<String, dynamic>;
        if (json['id'] == signal.id) return false;
      }
    }

    file.writeAsStringSync(
      '${jsonEncode(_toJson(signal))}\n',
      mode: FileMode.append,
      flush: true,
    );
    return true;
  }

  List<PaperSignal> readAll(File file) {
    if (!file.existsSync()) return const [];
    return [
      for (final line in file.readAsLinesSync())
        if (line.trim().isNotEmpty)
          _fromJson(jsonDecode(line) as Map<String, dynamic>),
    ];
  }

  Map<String, dynamic> _toJson(PaperSignal signal) => {
    'schemaVersion': 1,
    'id': signal.id,
    'symbol': signal.symbol,
    'strategy': signal.strategy,
    'side': signal.side.name,
    'observedAt': signal.observedAt.toUtc().toIso8601String(),
    'entry': signal.entry,
    'stopLoss': signal.stopLoss,
    'takeProfit': signal.takeProfit,
    'rewardRisk': signal.rewardRisk,
    'reason': signal.reason,
    'status': signal.status.name,
  };

  PaperSignal _fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw FormatException('Unsupported paper signal schema');
    }
    return PaperSignal(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      strategy: json['strategy'] as String,
      side: PaperSignalSide.values.byName(json['side'] as String),
      observedAt: DateTime.parse(json['observedAt'] as String),
      entry: (json['entry'] as num).toDouble(),
      stopLoss: (json['stopLoss'] as num).toDouble(),
      takeProfit: (json['takeProfit'] as num).toDouble(),
      rewardRisk: (json['rewardRisk'] as num).toDouble(),
      reason: json['reason'] as String,
      status: PaperSignalStatus.values.byName(json['status'] as String),
    );
  }
}
