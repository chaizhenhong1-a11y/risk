import 'package:flutter/material.dart';

import '../../domain/signal_history_view.dart';
import '../../domain/tradeforge_live_state.dart';
import '../../theme/tradeforge_theme.dart';
import '../widgets/app_section.dart';
import '../widgets/page_header.dart';

class SignalsView extends StatelessWidget {
  const SignalsView({required this.state, super.key});

  final TradeForgeLiveState state;

  @override
  Widget build(BuildContext context) {
    final groups = state.exposureGroups;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
      children: [
        const PageHeader(
          title: '信号记录',
          subtitle: 'Paper Forward 候选与 A/C5 结果都会永久保留',
        ),
        const SizedBox(height: 22),
        if (groups.isEmpty)
          const AppSection(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 36,
                    color: TradeForgeTheme.muted,
                  ),
                  SizedBox(height: 10),
                  Text(
                    '暂无历史记录',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '新的候选触发后会保留到这里，并持续更新最终结果',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: TradeForgeTheme.muted),
                  ),
                ],
              ),
            ),
          )
        else
          ...groups.map(
            (group) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppSection(child: _ExposureGroupCard(group: group)),
            ),
          ),
      ],
    );
  }
}

class _ExposureGroupCard extends StatelessWidget {
  const _ExposureGroupCard({required this.group});

  final SignalExposureGroup group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HistoryCard(item: group.root),
        if (group.suppressedTriggerCount > 0) ...[
          const SizedBox(height: 12),
          const Divider(height: 1, color: TradeForgeTheme.border),
          const SizedBox(height: 10),
          Text(
            '同 Exposure 另外触发 ${group.suppressedTriggerCount} 次',
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '原始 Trigger 已保留 · 不计独立交易 / 独立胜负 / Confidence / Lot',
            style: TextStyle(color: TradeForgeTheme.muted, fontSize: 11.5),
          ),
        ],
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});

  final SignalHistoryView item;

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel(item.status);
    final result = item.realizedR == null
        ? status
        : '${item.realizedR! >= 0 ? '+' : ''}${item.realizedR!.toStringAsFixed(2)}R · $status';
    final source = item.isPaperForward ? 'PAPER FORWARD' : 'A/C5 FROZEN';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${item.side} · ${item.strategy}',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              result,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: _statusColor(item.status),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          source + (item.regime == null ? '' : ' · ${item.regime}'),
          style: const TextStyle(color: TradeForgeTheme.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        _ExposureBadge(item: item),
        const SizedBox(height: 10),
        Text(
          'Entry ${item.entry.toStringAsFixed(3)}  ·  '
          'SL ${item.stopLoss.toStringAsFixed(3)}  ·  '
          'TP ${item.takeProfit.toStringAsFixed(3)}',
        ),
        const SizedBox(height: 6),
        Text(
          '${item.riskReward.toStringAsFixed(2)}R · ${_time(item.observedAt)}',
          style: const TextStyle(color: TradeForgeTheme.muted),
        ),
        if (item.resolvedAt != null) ...[
          const SizedBox(height: 4),
          Text(
            '结束 ${_time(item.resolvedAt!)}',
            style: const TextStyle(color: TradeForgeTheme.muted, fontSize: 12),
          ),
        ],
      ],
    );
  }

  static String _time(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  static String _statusLabel(SignalHistoryStatus status) => switch (status) {
        SignalHistoryStatus.pending => 'PENDING',
        SignalHistoryStatus.triggered => 'TRIGGERED',
        SignalHistoryStatus.targetHit => 'TP HIT',
        SignalHistoryStatus.stopHit => 'SL HIT',
        SignalHistoryStatus.expired => 'EXPIRED',
        SignalHistoryStatus.ambiguous => 'AMBIGUOUS',
        SignalHistoryStatus.rejected => 'REJECTED',
        SignalHistoryStatus.unknown => 'UNKNOWN',
      };

  static Color _statusColor(SignalHistoryStatus status) => switch (status) {
        SignalHistoryStatus.targetHit => TradeForgeTheme.primary,
        SignalHistoryStatus.stopHit => Colors.redAccent,
        SignalHistoryStatus.ambiguous ||
        SignalHistoryStatus.rejected =>
          Colors.orangeAccent,
        _ => TradeForgeTheme.muted,
      };
}

class _ExposureBadge extends StatelessWidget {
  const _ExposureBadge({required this.item});

  final SignalHistoryView item;

  @override
  Widget build(BuildContext context) {
    final (label, detail, icon) = switch (item.exposureStatus) {
      'same_exposure' => (
          'SAME EXPOSURE',
          '同策略同方向重叠 · 不计为独立证据/独立仓位',
          Icons.content_copy_rounded,
        ),
      'portfolio_overlap' => (
          'PORTFOLIO OVERLAP',
          '不同策略同方向重叠 · 保留机会，等待组合审查',
          Icons.call_merge_rounded,
        ),
      _ => (
          'INDEPENDENT',
          '独立机会',
          Icons.check_circle_outline_rounded,
        ),
    };

    final color = item.isSameExposure
        ? Colors.orangeAccent
        : item.isPortfolioOverlap
            ? Colors.amberAccent
            : TradeForgeTheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 11.5),
              children: [
                TextSpan(
                  text: label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text: ' · $detail',
                  style: const TextStyle(color: TradeForgeTheme.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
