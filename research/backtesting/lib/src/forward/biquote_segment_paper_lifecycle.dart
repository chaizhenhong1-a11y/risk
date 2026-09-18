import 'dart:convert';
import 'dart:io';

import 'biquote_live_market_snapshot.dart';
import 'biquote_market_data.dart';
import 'biquote_segment_paper_forward_bridge.dart';

enum SegmentPaperStatus { pending, targetHit, stopHit, expired, ambiguous }

final class SegmentPaperPosition {
  const SegmentPaperPosition({
    required this.id,
    required this.segmentId,
    required this.side,
    required this.observedAt,
    required this.entry,
    required this.stop,
    required this.target,
    required this.rewardRisk,
    required this.status,
    this.resolvedAt,
  });

  final String id;
  final String segmentId;
  final String side;
  final DateTime observedAt;
  final double entry;
  final double stop;
  final double target;
  final double rewardRisk;
  final SegmentPaperStatus status;
  final DateTime? resolvedAt;

  double? get realizedR => switch (status) {
    SegmentPaperStatus.targetHit => rewardRisk,
    SegmentPaperStatus.stopHit => -1.0,
    SegmentPaperStatus.pending ||
    SegmentPaperStatus.expired ||
    SegmentPaperStatus.ambiguous => null,
  };

  SegmentPaperPosition copyWith({
    SegmentPaperStatus? status,
    DateTime? resolvedAt,
  }) => SegmentPaperPosition(
    id: id,
    segmentId: segmentId,
    side: side,
    observedAt: observedAt,
    entry: entry,
    stop: stop,
    target: target,
    rewardRisk: rewardRisk,
    status: status ?? this.status,
    resolvedAt: resolvedAt ?? this.resolvedAt,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'segmentId': segmentId,
    'side': side,
    'observedAt': observedAt.toUtc().toIso8601String(),
    'entry': entry,
    'stop': stop,
    'target': target,
    'rewardRisk': rewardRisk,
    'status': status.name,
    'resolvedAt': resolvedAt?.toUtc().toIso8601String(),
  };

  factory SegmentPaperPosition.fromJson(Map<String, dynamic> json) {
    return SegmentPaperPosition(
      id: json['id'].toString(),
      segmentId: json['segmentId'].toString(),
      side: json['side'].toString(),
      observedAt: DateTime.parse(json['observedAt'].toString()).toUtc(),
      entry: (json['entry'] as num).toDouble(),
      stop: (json['stop'] as num).toDouble(),
      target: (json['target'] as num).toDouble(),
      rewardRisk: (json['rewardRisk'] as num).toDouble(),
      status: SegmentPaperStatus.values.byName(json['status'].toString()),
      resolvedAt: json['resolvedAt'] == null
          ? null
          : DateTime.parse(json['resolvedAt'].toString()).toUtc(),
    );
  }
}

final class SegmentPaperForwardStats {
  const SegmentPaperForwardStats({
    required this.total,
    required this.pending,
    required this.wins,
    required this.losses,
    required this.ambiguous,
    required this.netR,
  });

  final int total;
  final int pending;
  final int wins;
  final int losses;
  final int ambiguous;
  final double netR;
}

/// Resolves only opportunities already persisted by the Increment-173 bridge.
///
/// A position can only be resolved by a CLOSED M5 whose closeTime is strictly
/// after the opportunity observedAt. Therefore the signal candle itself and all
/// pre-start history can never leak into forward results.
final class BiQuoteSegmentPaperLifecycle {
  BiQuoteSegmentPaperLifecycle({
    required this.candidateJournal,
    required this.stateFile,
    required this.resultJournal,
  });

  final File candidateJournal;
  final File stateFile;
  final File resultJournal;

  final Map<String, SegmentPaperPosition> _positions =
      <String, SegmentPaperPosition>{};
  bool _loaded = false;

  Iterable<SegmentPaperPosition> get positions => _positions.values;

  SegmentPaperForwardStats get stats {
    var pending = 0;
    var wins = 0;
    var losses = 0;
    var ambiguous = 0;
    var netR = 0.0;
    for (final position in _positions.values) {
      switch (position.status) {
        case SegmentPaperStatus.pending:
          pending++;
        case SegmentPaperStatus.targetHit:
          wins++;
          netR += position.rewardRisk;
        case SegmentPaperStatus.stopHit:
          losses++;
          netR -= 1.0;
        case SegmentPaperStatus.expired:
          break;
        case SegmentPaperStatus.ambiguous:
          ambiguous++;
      }
    }
    return SegmentPaperForwardStats(
      total: _positions.length,
      pending: pending,
      wins: wins,
      losses: losses,
      ambiguous: ambiguous,
      netR: netR,
    );
  }

  Future<void> onClosedM5(BiQuoteLiveMarketSnapshot snapshot) async {
    if (snapshot.m5.isEmpty) return;
    await recoverFromClosedBars(<BiQuoteClosedBar>[snapshot.m5.last]);
  }

  /// Replays bounded CLOSED-M5 warmup after a process restart so positions
  /// that were pending while TradeForge was offline are resolved from market
  /// data rather than user input.
  Future<void> recoverFromClosedBars(List<BiQuoteClosedBar> bars) async {
    await _load();
    await _ingestCandidates();
    if (bars.isEmpty) return;

    final ordered = bars.toList(growable: false)
      ..sort((a, b) => a.closeTime.compareTo(b.closeTime));
    final resolved = <SegmentPaperPosition>[];

    for (final current in _positions.values.toList(growable: false)) {
      if (current.status != SegmentPaperStatus.pending) continue;
      var elapsed = 0;
      SegmentPaperPosition? updated;

      for (final bar in ordered) {
        final closeTime = bar.closeTime.toUtc();
        if (!closeTime.isAfter(current.observedAt)) continue;
        elapsed++;

        final isBuy = current.side == 'BUY';
        final targetTouched = isBuy
            ? bar.high >= current.target
            : bar.low <= current.target;
        final stopTouched = isBuy
            ? bar.low <= current.stop
            : bar.high >= current.stop;

        SegmentPaperStatus? next;
        if (targetTouched && stopTouched) {
          next = SegmentPaperStatus.ambiguous;
        } else if (targetTouched) {
          next = SegmentPaperStatus.targetHit;
        } else if (stopTouched) {
          next = SegmentPaperStatus.stopHit;
        } else if (elapsed >= 48) {
          next = SegmentPaperStatus.expired;
        }

        if (next != null) {
          updated = current.copyWith(status: next, resolvedAt: closeTime);
          break;
        }
      }

      if (updated != null) {
        _positions[current.id] = updated;
        resolved.add(updated);
      }
    }

    if (resolved.isNotEmpty) {
      await resultJournal.parent.create(recursive: true);
      final existingIds = <String>{};
      if (resultJournal.existsSync()) {
        for (final line in await resultJournal.readAsLines()) {
          if (line.trim().isEmpty) continue;
          final decoded = jsonDecode(line);
          if (decoded is Map && decoded['id'] != null) {
            existingIds.add(decoded['id'].toString());
          }
        }
      }
      final sink = resultJournal.openWrite(mode: FileMode.append);
      try {
        for (final item in resolved) {
          if (!existingIds.add(item.id)) continue;
          sink.writeln(
            jsonEncode(<String, Object?>{
              'schema': 1,
              'kind': 'SEGMENT_PAPER_RESULT',
              ...item.toJson(),
              'realizedR': item.realizedR,
            }),
          );
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
    }
    await _save();
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    if (!stateFile.existsSync()) return;
    final decoded = jsonDecode(await stateFile.readAsString());
    if (decoded is! Map<String, dynamic>) return;
    final raw = decoded['positions'];
    if (raw is! List) return;
    for (final item in raw) {
      if (item is Map) {
        final position = SegmentPaperPosition.fromJson(
          Map<String, dynamic>.from(item),
        );
        _positions[position.id] = position;
      }
    }
  }

  Future<void> _ingestCandidates() async {
    if (!candidateJournal.existsSync()) return;
    final lines = await candidateJournal.readAsLines();
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final decoded = jsonDecode(line);
      if (decoded is! Map<String, dynamic> ||
          decoded['kind'] != 'SEGMENT_PAPER_FORWARD') {
        continue;
      }
      final observedAt = DateTime.parse(
        decoded['observedAt'].toString(),
      ).toUtc();
      final segmentId = decoded['segmentId'].toString();
      final id = '$segmentId|${observedAt.toIso8601String()}';
      if (_positions.containsKey(id)) continue;
      _positions[id] = SegmentPaperPosition(
        id: id,
        segmentId: segmentId,
        side: decoded['side'].toString(),
        observedAt: observedAt,
        entry: (decoded['entry'] as num).toDouble(),
        stop: (decoded['stop'] as num).toDouble(),
        target: (decoded['target'] as num).toDouble(),
        rewardRisk: (decoded['rewardRisk'] as num).toDouble(),
        status: SegmentPaperStatus.pending,
      );
    }
  }

  Future<void> _save() async {
    await stateFile.parent.create(recursive: true);
    final temp = File('${stateFile.path}.tmp');
    await temp.writeAsString(
      jsonEncode(<String, Object?>{
        'schema': 1,
        'positions': _positions.values.map((e) => e.toJson()).toList(),
      }),
      flush: true,
    );
    if (stateFile.existsSync()) await stateFile.delete();
    await temp.rename(stateFile.path);
  }
}

/// Serial observer to plug directly into BiQuoteUnseenPaperForwardRunner.
///
/// Discovery is persisted first, lifecycle resolution second. The lifecycle
/// refuses to resolve on the same CLOSED M5, preserving anti-lookahead.
final class BiQuoteSegmentPaperForwardSession {
  BiQuoteSegmentPaperForwardSession({
    required this.bridge,
    required this.lifecycle,
  });

  final BiQuoteSegmentPaperForwardBridge bridge;
  final BiQuoteSegmentPaperLifecycle lifecycle;

  Future<void> onClosedM5(BiQuoteLiveMarketSnapshot snapshot) async {
    await bridge.onClosedM5(snapshot);
    await lifecycle.onClosedM5(snapshot);
  }
}
