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
          subtitle: '独立机会 · AI Review · Paper Forward / A/C5',
        ),
        const SizedBox(height: 22),
        if (groups.isEmpty)
          const AppSection(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Column(children: [
                Icon(Icons.history_rounded,
                    size: 36, color: TradeForgeTheme.muted),
                SizedBox(height: 10),
                Text('暂无历史记录',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text('新的独立候选会在这里显示 AI 基本面 Review',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: TradeForgeTheme.muted)),
              ]),
            ),
          )
        else
          ...groups.map((group) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppSection(child: _ExposureGroupCard(group: group)),
              )),
      ],
    );
  }
}

class _ExposureGroupCard extends StatelessWidget {
  const _ExposureGroupCard({required this.group});
  final SignalExposureGroup group;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HistoryCard(item: group.root),
          if (group.suppressedTriggerCount > 0) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: TradeForgeTheme.border),
            const SizedBox(height: 10),
            Text('同 Exposure 另外触发 ${group.suppressedTriggerCount} 次',
                style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('原始 Trigger 已保留 · 不计独立交易 / Confidence / Lot · 不重复调用 AI',
                style: TextStyle(color: TradeForgeTheme.muted, fontSize: 11.5)),
          ],
        ],
      );
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text('${item.side} · ${item.strategy}',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800))),
        Text(result,
            style: TextStyle(
                fontWeight: FontWeight.w800, color: _statusColor(item.status))),
      ]),
      const SizedBox(height: 6),
      Text(source + (item.regime == null ? '' : ' · ${item.regime}'),
          style: const TextStyle(color: TradeForgeTheme.muted, fontSize: 12)),
      const SizedBox(height: 8),
      _ExposureBadge(item: item),
      const SizedBox(height: 10),
      Text('Entry ${item.entry.toStringAsFixed(3)}  ·  '
          'SL ${item.stopLoss.toStringAsFixed(3)}  ·  '
          'TP ${item.takeProfit.toStringAsFixed(3)}'),
      const SizedBox(height: 6),
      Text('${item.riskReward.toStringAsFixed(2)}R · ${_time(item.observedAt)}',
          style: const TextStyle(color: TradeForgeTheme.muted)),
      if (item.fundamentalReview != null && item.independentEvidence) ...[
        const SizedBox(height: 14),
        _AiReviewCard(review: item.fundamentalReview!),
      ],
      if (item.resolvedAt != null) ...[
        const SizedBox(height: 6),
        Text('结束 ${_time(item.resolvedAt!)}',
            style: const TextStyle(color: TradeForgeTheme.muted, fontSize: 12)),
      ],
    ]);
  }

  static String _time(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

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

class _AiReviewCard extends StatelessWidget {
  const _AiReviewCard({required this.review});
  final FundamentalReviewView review;

  @override
  Widget build(BuildContext context) {
    final risk = switch (review.risk) {
      FundamentalRiskView.normal => 'NORMAL',
      FundamentalRiskView.caution => 'CAUTION',
      FundamentalRiskView.highRisk => 'HIGH RISK',
      FundamentalRiskView.unknown => 'UNKNOWN',
    };
    final riskColor = switch (review.risk) {
      FundamentalRiskView.normal => TradeForgeTheme.primary,
      FundamentalRiskView.caution => Colors.amberAccent,
      FundamentalRiskView.highRisk => Colors.orangeAccent,
      FundamentalRiskView.unknown => TradeForgeTheme.muted,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TradeForgeTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: riskColor.withValues(alpha: .28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.psychology_alt_rounded,
              size: 18, color: TradeForgeTheme.primary),
          const SizedBox(width: 7),
          const Text('AI REVIEW',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          const Spacer(),
          Text(risk,
              style: TextStyle(
                  color: riskColor, fontWeight: FontWeight.w900, fontSize: 11)),
        ]),
        const SizedBox(height: 10),
        Text('Confidence · ${review.confidenceLabel}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(
            review.confidenceCalibrated
                ? 'CALIBRATED · 仍然不是自动入场指令'
                : 'UNCALIBRATED · 不是胜率，也不是自动入场指令',
            style:
                const TextStyle(color: TradeForgeTheme.muted, fontSize: 10.5)),
        const SizedBox(height: 10),
        Text(
            review.aiAvailable
                ? (review.summary.isEmpty ? 'AI 未提供额外摘要。' : review.summary)
                : 'AI Review 暂不可用；策略 Candidate 仍然保留。',
            style: const TextStyle(height: 1.4)),
        if (review.confidenceReasons.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('为什么值得考虑',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          for (final reason in review.confidenceReasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('✓ $reason',
                  style: const TextStyle(
                      color: TradeForgeTheme.primary, fontSize: 11.5)),
            ),
        ],
        if (review.confidenceCautions.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('需要谨慎',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          for (final caution in review.confidenceCautions)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('⚠ $caution',
                  style: const TextStyle(
                      color: Colors.orangeAccent, fontSize: 11.5)),
            ),
        ],
        if (review.relevantFactors.isNotEmpty) ...[
          const SizedBox(height: 9),
          for (final factor in review.relevantFactors.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $factor',
                  style: const TextStyle(
                      color: TradeForgeTheme.muted, fontSize: 12)),
            ),
        ],
        const SizedBox(height: 8),
        Text('Gold bias · ${review.goldBias.toUpperCase()}',
            style: const TextStyle(
                color: TradeForgeTheme.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('最终是否跟单：由你决定',
            style: TextStyle(
                color: TradeForgeTheme.primary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _ExposureBadge extends StatelessWidget {
  const _ExposureBadge({required this.item});
  final SignalHistoryView item;

  @override
  Widget build(BuildContext context) {
    final (label, detail, icon) = switch (item.exposureStatus) {
      'same_exposure' => (
          'SAME EXPOSURE',
          '同策略同方向重叠 · 不计独立证据',
          Icons.content_copy_rounded
        ),
      'portfolio_overlap' => (
          'PORTFOLIO OVERLAP',
          '不同策略同方向重叠 · 保留机会',
          Icons.call_merge_rounded
        ),
      _ => ('INDEPENDENT', '独立机会', Icons.check_circle_outline_rounded),
    };
    final color = item.isSameExposure
        ? Colors.orangeAccent
        : item.isPortfolioOverlap
            ? Colors.amberAccent
            : TradeForgeTheme.primary;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 6),
      Expanded(
          child: RichText(
              text: TextSpan(
        style: const TextStyle(fontSize: 11.5),
        children: [
          TextSpan(
              text: label,
              style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          TextSpan(
              text: ' · $detail',
              style: const TextStyle(color: TradeForgeTheme.muted)),
        ],
      ))),
    ]);
  }
}
