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
          subtitle: '独立机会 · AI 复核 · 模拟跟踪',
        ),
        const SizedBox(height: 22),
        if (groups.isEmpty)
          const AppSection(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Text('暂无历史记录'),
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
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HistoryCard(item: group.root),
          if (group.suppressedTriggerCount > 0) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: TradeForgeTheme.border),
            const SizedBox(height: 10),
            Text(
              '同一机会另外触发 ${group.suppressedTriggerCount} 次',
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '不重复计算，也不重复调用 AI',
              style: TextStyle(color: TradeForgeTheme.muted, fontSize: 11.5),
            ),
          ],
        ],
      );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});
  final SignalHistoryView item;

  @override
  Widget build(BuildContext context) {
    final result = item.realizedR == null
        ? _status(item.status)
        : '${item.realizedR! >= 0 ? '+' : ''}${item.realizedR!.toStringAsFixed(2)}R';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(
              '${_side(item.side)} · ${item.strategy}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          Text(result, style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        Text(
          '${item.isPaperForward ? '模拟跟踪' : '历史验证'}'
          '${item.regime == null ? '' : ' · ${item.regime}'}',
          style: const TextStyle(color: TradeForgeTheme.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        _ExposureBadge(item: item),
        const SizedBox(height: 10),
        Text(
          '入场 ${item.entry.toStringAsFixed(3)}  ·  '
          '止损 ${item.stopLoss.toStringAsFixed(3)}  ·  '
          '止盈 ${item.takeProfit.toStringAsFixed(3)}',
        ),
        const SizedBox(height: 6),
        Text(
          '盈亏比 ${item.riskReward.toStringAsFixed(2)}R · ${_time(item.observedAt)}',
          style: const TextStyle(color: TradeForgeTheme.muted),
        ),
        if (item.fundamentalReview != null && item.independentEvidence) ...[
          const SizedBox(height: 14),
          _FinalReviewCard(review: item.fundamentalReview!),
        ],
      ],
    );
  }

  static String _side(String side) => switch (side.toUpperCase()) {
        'BUY' => '买入',
        'SELL' => '卖出',
        _ => '方向未知',
      };

  static String _status(SignalHistoryStatus status) => switch (status) {
        SignalHistoryStatus.pending => '等待',
        SignalHistoryStatus.triggered => '已触发',
        SignalHistoryStatus.targetHit => '止盈',
        SignalHistoryStatus.stopHit => '止损',
        SignalHistoryStatus.expired => '已过期',
        SignalHistoryStatus.ambiguous => '结果不明',
        SignalHistoryStatus.rejected => '未执行',
        SignalHistoryStatus.unknown => '未知',
      };

  static String _time(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _FinalReviewCard extends StatelessWidget {
  const _FinalReviewCard({required this.review});
  final FundamentalReviewView review;

  @override
  Widget build(BuildContext context) {
    final support = review.aiSupportPercent;
    final oppose = review.aiOpposePercent;
    final hasPercent = review.aiAvailable &&
        support != null &&
        oppose != null &&
        support + oppose == 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TradeForgeTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TradeForgeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(
              Icons.psychology_alt_rounded,
              size: 18,
              color: TradeForgeTheme.primary,
            ),
            SizedBox(width: 7),
            Text(
              'AI 复核',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ]),
          const SizedBox(height: 12),
          if (hasPercent) ...[
            Row(
              children: [
                Expanded(
                  child: _PercentBox(
                    label: '支持',
                    percent: support,
                    emphasized: support >= oppose,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PercentBox(
                    label: '反对',
                    percent: oppose,
                    emphasized: oppose > support,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            const Text(
              '这是 AI 的复核倾向，不是胜率',
              style: TextStyle(color: TradeForgeTheme.muted, fontSize: 10.5),
            ),
            if (review.aiSupportExplanation.isNotEmpty ||
                review.aiOpposeExplanation.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (review.aiSupportExplanation.isNotEmpty)
                _PercentExplanation(
                  label: '为什么支持',
                  text: review.aiSupportExplanation,
                  positive: true,
                ),
              if (review.aiOpposeExplanation.isNotEmpty) ...[
                const SizedBox(height: 7),
                _PercentExplanation(
                  label: '为什么反对',
                  text: review.aiOpposeExplanation,
                  positive: false,
                ),
              ],
            ],
          ] else
            const Text(
              'AI 暂时无法给出复核比例，原策略信号仍然保留。',
              style: TextStyle(color: TradeForgeTheme.muted),
            ),
          const SizedBox(height: 14),
          const _Heading(Icons.chat_bubble_outline_rounded, 'AI 看法'),
          const SizedBox(height: 7),
          Text(
            review.aiAvailable
                ? (review.candidateSummary.isEmpty
                    ? 'AI 没有补充新的看法。'
                    : review.candidateSummary)
                : 'AI 暂时不可用，不影响原策略信号。',
            style: const TextStyle(height: 1.4),
          ),
          if (review.technicalReasons.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('支持原因', style: TextStyle(fontWeight: FontWeight.w800)),
            for (final value in review.technicalReasons)
              _Reason(value, positive: true),
          ],
          if (review.riskReasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('需要注意', style: TextStyle(fontWeight: FontWeight.w800)),
            for (final value in review.riskReasons)
              _Reason(value, positive: false),
          ],
          if (review.summary.isNotEmpty ||
              review.relevantFactors.isNotEmpty) ...[
            const SizedBox(height: 14),
            const _Heading(Icons.public_rounded, '消息与基本面'),
            const SizedBox(height: 7),
            Text(
              '${_risk(review.risk)} · 黄金${_bias(review.goldBias)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (review.summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(review.summary),
            ],
            for (final value in review.relevantFactors.take(4))
              Text(
                '• $value',
                style: const TextStyle(color: TradeForgeTheme.muted),
              ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 16),
              const SizedBox(width: 6),
              Text(
                review.executionIntegrityOk ? '执行检查正常' : '执行数据异常',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: review.executionIntegrityOk
                      ? TradeForgeTheme.primary
                      : Colors.redAccent,
                ),
              ),
            ],
          ),
          if (!review.executionIntegrityOk)
            for (final value in review.executionIntegrityReasons)
              _Reason(value, positive: false),
          const SizedBox(height: 12),
          const Text(
            '最终是否入场，由你决定',
            style: TextStyle(
              color: TradeForgeTheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  static String _risk(FundamentalRiskView risk) => switch (risk) {
        FundamentalRiskView.normal => '风险正常',
        FundamentalRiskView.caution => '需要留意',
        FundamentalRiskView.highRisk => '风险较高',
        FundamentalRiskView.unknown => '风险未知',
      };

  static String _bias(String bias) => switch (bias.toLowerCase()) {
        'bullish' => '偏强',
        'bearish' => '偏弱',
        'mixed' => '方向混合',
        _ => '方向不明',
      };
}

class _PercentExplanation extends StatelessWidget {
  const _PercentExplanation({
    required this.label,
    required this.text,
    required this.positive,
  });

  final String label;
  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label：',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: positive ? TradeForgeTheme.primary : Colors.orangeAccent,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11.5, height: 1.35),
            ),
          ),
        ],
      );
}

class _PercentBox extends StatelessWidget {
  const _PercentBox({
    required this.label,
    required this.percent,
    required this.emphasized,
  });

  final String label;
  final int percent;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                emphasized ? TradeForgeTheme.primary : TradeForgeTheme.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: TradeForgeTheme.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$percent%',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: emphasized ? TradeForgeTheme.primary : null,
              ),
            ),
          ],
        ),
      );
}

class _Heading extends StatelessWidget {
  const _Heading(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: TradeForgeTheme.primary),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w900)),
      ]);
}

class _Reason extends StatelessWidget {
  const _Reason(this.text, {required this.positive});
  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          '${positive ? '✓' : '⚠'} $text',
          style: TextStyle(
            color: positive ? TradeForgeTheme.primary : Colors.orangeAccent,
            fontSize: 11.5,
          ),
        ),
      );
}

class _ExposureBadge extends StatelessWidget {
  const _ExposureBadge({required this.item});
  final SignalHistoryView item;

  @override
  Widget build(BuildContext context) {
    final label = item.isSameExposure
        ? '同一机会'
        : item.isPortfolioOverlap
            ? '持仓重叠'
            : '独立机会';
    return Text(
      label,
      style: const TextStyle(
        color: TradeForgeTheme.primary,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
