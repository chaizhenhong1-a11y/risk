import 'dart:convert';
import 'dart:io';

import 'paper_signal.dart';
import 'paper_trade_result.dart';

final class PaperTradeResultJournal {
  const PaperTradeResultJournal();

  bool appendIfNew(File file, PaperTradeResult result) {
    file.parent.createSync(recursive: true);
    if (file.existsSync()) {
      for (final line in file.readAsLinesSync()) {
        if (line.trim().isEmpty) continue;
        final json = jsonDecode(line) as Map<String, dynamic>;
        if (json['signalId'] == result.signalId) return false;
      }
    }

    file.writeAsStringSync(
      '${jsonEncode({'schemaVersion': 1, 'signalId': result.signalId, 'strategy': result.strategy, 'status': result.status.name, 'resolvedAt': result.resolvedAt.toUtc().toIso8601String(), 'grossR': result.grossR})}\n',
      mode: FileMode.append,
      flush: true,
    );
    return true;
  }

  List<PaperTradeResult> readAll(File file) {
    if (!file.existsSync()) return const [];
    return [
      for (final line in file.readAsLinesSync())
        if (line.trim().isNotEmpty)
          _fromJson(jsonDecode(line) as Map<String, dynamic>),
    ];
  }

  PaperTradeResult _fromJson(Map<String, dynamic> json) => PaperTradeResult(
    signalId: json['signalId'] as String,
    strategy: json['strategy'] as String,
    status: PaperSignalStatus.values.byName(json['status'] as String),
    resolvedAt: DateTime.parse(json['resolvedAt'] as String),
    grossR: (json['grossR'] as num?)?.toDouble(),
  );
}
