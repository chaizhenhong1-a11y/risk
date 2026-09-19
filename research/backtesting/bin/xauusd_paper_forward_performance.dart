import 'dart:convert';
import 'dart:io';

import 'package:tradeforge_backtesting/src/analytics/paper_forward_performance_adapter.dart';
import 'package:tradeforge_backtesting/src/analytics/performance_sample_formatter.dart';

void main(List<String> args) {
  final root = args.isEmpty ? '.paper_forward' : args.first;
  final c5File = File('$root${Platform.pathSeparator}xauusd_results.jsonl');
  final segmentFile = File(
    '$root${Platform.pathSeparator}segments'
    '${Platform.pathSeparator}segment_results.jsonl',
  );

  if (!c5File.existsSync() && !segmentFile.existsSync()) {
    stderr.writeln('No paper-forward result files found under: $root');
    exitCode = 66;
    return;
  }

  if (c5File.existsSync()) {
    final c5 = _readC5(c5File);
    _printReport(
      'C5 PAPER FORWARD',
      const PaperForwardPerformanceAdapter().analyze(c5),
    );
  }

  if (segmentFile.existsSync()) {
    final segments = _readSegments(segmentFile);
    _printReport(
      'SEGMENT PAPER FORWARD',
      const PaperForwardPerformanceAdapter().analyze(segments),
    );
  }
}

List<PaperForwardResult> _readC5(File file) {
  final results = <PaperForwardResult>[];
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final json = jsonDecode(line) as Map<String, dynamic>;
    final grossR = (json['grossR'] as num?)?.toDouble();
    final signalId = json['signalId'] as String?;
    if (grossR == null || signalId == null) continue;

    final parts = signalId.split('|');
    if (parts.length < 4) {
      throw FormatException('Invalid C5 signalId: $signalId');
    }

    final observedAt = DateTime.parse(parts[1]).toUtc();
    final strategy = (json['strategy'] as String? ?? parts[2]).trim();
    final side = parts[3].trim().toUpperCase();
    if (side != 'BUY' && side != 'SELL') {
      throw FormatException('Invalid C5 side in signalId: $signalId');
    }

    results.add(
      PaperForwardResult(
        strategy: strategy,
        side: side,
        observedAt: observedAt,
        realizedR: grossR,
      ),
    );
  }
  return results;
}

List<PaperForwardResult> _readSegments(File file) {
  final results = <PaperForwardResult>[];
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final json = jsonDecode(line) as Map<String, dynamic>;
    final realizedR = (json['realizedR'] as num?)?.toDouble();
    final observedAtRaw = json['observedAt'] as String?;
    final segmentId = json['segmentId'] as String?;
    final side = (json['side'] as String?)?.trim().toUpperCase();
    if (realizedR == null ||
        observedAtRaw == null ||
        segmentId == null ||
        side == null) {
      continue;
    }
    if (side != 'BUY' && side != 'SELL') {
      throw FormatException('Invalid segment side: $side');
    }

    final strategy = segmentId.split('|').first.trim();
    results.add(
      PaperForwardResult(
        strategy: strategy,
        side: side,
        observedAt: DateTime.parse(observedAtRaw).toUtc(),
        realizedR: realizedR,
      ),
    );
  }
  return results;
}

void _printReport(String title, dynamic report) {
  stdout.writeln('');
  stdout.writeln('=== $title ===');
  _printMetrics('OVERALL', report.overall);

  for (final entry in report.byStrategy.entries) {
    _printMetrics(entry.key, entry.value);
    final sides = report.byStrategyAndSide[entry.key] ?? const {};
    for (final side in sides.entries) {
      _printMetrics('  ${side.key}', side.value);
    }
  }
}

void _printMetrics(String label, dynamic m) {
  stdout.writeln('');
  stdout.writeln(label);
  stdout.writeln(
    '  sample=${formatPerformanceSampleQuality(m.tradeCount as int)}',
  );
  stdout.writeln(
    '  trades=${m.tradeCount} W=${m.winCount} L=${m.lossCount} '
    'BE=${m.breakEvenCount}',
  );
  stdout.writeln(
    '  win=${m.winRate == null ? "n/a" : "${(m.winRate * 100).toStringAsFixed(2)}%"} '
    'E=${m.expectancyR == null ? "n/a" : "${m.expectancyR.toStringAsFixed(3)}R"} '
    'PF=${m.profitFactor == null
        ? "n/a"
        : m.profitFactor.isInfinite
        ? "inf"
        : m.profitFactor.toStringAsFixed(3)}',
  );
  stdout.writeln(
    '  total=${m.totalR.toStringAsFixed(3)}R '
    'maxDD=${m.maxDrawdownR.toStringAsFixed(3)}R',
  );
}
