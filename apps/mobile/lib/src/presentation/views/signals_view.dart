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
          subtitle: '独立机会 · Candidate AI Review · Paper Forward / A/C5',
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
              '同 Exposure 另外触发 ${group.suppressedTriggerCount} 次',
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '不计独立交易 / Confidence / Lot · 不重复调用 AI',
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
        ? item.status.name.toUpperCase()
        : '${item.realizedR! >= 0 ? '+' : ''}${item.realizedR!.toStringAsFixed(2)}R';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(
              '${item.side} · ${item.strategy}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          Text(result, style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        Text(
          '${item.isPaperForward ? 'PAPER FORWARD' : 'A/C5 FROZEN'}'
          '${item.regime == null ? '' : ' · ${item.regime}'}',
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
        if (item.fundamentalReview != null && item.independentEvidence) ...[
          const SizedBox(height: 14),
          _FinalReviewCard(review: item.fundamentalReview!),
        ],
      ],
    );
  }

  static String _time(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _FinalReviewCard extends StatelessWidget {
  const _FinalReviewCard({required this.review});
  final FundamentalReviewView review;

  @override
  Widget build(BuildContext context) {
    final risk = switch (review.risk) {
      FundamentalRiskView.normal => 'NORMAL',
      FundamentalRiskView.caution => 'CAUTION',
      FundamentalRiskView.highRisk => 'HIGH RISK',
      FundamentalRiskView.unknown => 'UNKNOWN',
    };
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
          Row(children: [
            const Icon(
              Icons.fact_check_outlined,
              size: 18,
              color: TradeForgeTheme.primary,
            ),
            const SizedBox(width: 7),
            const Text(
              'FINAL REVIEW',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
            const Spacer(),
            Text(
              review.executionIntegrityOk ? 'INTEGRITY OK' : 'INTEGRITY BLOCK',
              style: TextStyle(
                color: review.executionIntegrityOk
                    ? TradeForgeTheme.primary
                    : Colors.redAccent,
                fontWeight: FontWeight.w900,
                fontSize: 10.5,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            '${review.confidenceLabel} · '
            '${review.confidenceCalibrated ? 'CALIBRATED' : 'UNCALIBRATED'}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          const Text(
            'Confidence 不是胜率，也不是自动入场指令',
            style: TextStyle(color: TradeForgeTheme.muted, fontSize: 10.5),
          ),
          const SizedBox(height: 14),
          const _Heading(Icons.psychology_alt_rounded, 'AI CANDIDATE REVIEW'),
          const SizedBox(height: 7),
          Text(
            review.aiAvailable
                ? (review.candidateSummary.isEmpty
                    ? 'Gemini 没有返回 Candidate-specific 摘要。'
                    : review.candidateSummary)
                : 'Gemini 当前不可用；策略 Candidate 仍然保留。',
            style: const TextStyle(height: 1.4),
          ),
          for (final value in review.technicalReasons)
            _Reason(value, positive: true),
          for (final value in review.riskReasons)
            _Reason(value, positive: false),
          const SizedBox(height: 14),
          const _Heading(Icons.public_rounded, 'FUNDAMENTAL / NEWS'),
          const SizedBox(height: 7),
          Text(
            '$risk · Gold bias ${review.goldBias.toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(review.summary.isEmpty ? '没有额外基本面摘要。' : review.summary),
          for (final value in review.relevantFactors.take(4))
            Text(
              '• $value',
              style: const TextStyle(color: TradeForgeTheme.muted),
            ),
          const SizedBox(height: 14),
          const _Heading(Icons.shield_outlined, 'EXECUTION INTEGRITY'),
          const SizedBox(height: 7),
          for (final value in review.executionIntegrityReasons)
            _Reason(value, positive: review.executionIntegrityOk),
          if (review.confidenceCautions.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              '系统提醒',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            for (final value in review.confidenceCautions)
              _Reason(value, positive: false),
          ],
          const SizedBox(height: 10),
          const Text(
            '最终是否入场：由你决定',
            style: TextStyle(
              color: TradeForgeTheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
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
        ? 'SAME EXPOSURE'
        : item.isPortfolioOverlap
            ? 'PORTFOLIO OVERLAP'
            : 'INDEPENDENT';
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
