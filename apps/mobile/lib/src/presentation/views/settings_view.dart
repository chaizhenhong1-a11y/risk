import 'package:flutter/material.dart';

import '../../theme/tradeforge_theme.dart';
import '../widgets/app_section.dart';
import '../widgets/page_header.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
      children: [
        const PageHeader(
          title: '设置',
          subtitle: '保持简单，只保留必要选项',
        ),
        const SizedBox(height: 22),
        AppSection(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              const _SettingRow(
                icon: Icons.notifications_outlined,
                title: '交易机会通知',
                trailing: Text('开启'),
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              const _SettingRow(
                icon: Icons.cloud_outlined,
                title: '行情来源',
                trailing: Text('BiQuote'),
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              const _SettingRow(
                icon: Icons.info_outline_rounded,
                title: '模式',
                trailing: Text('Paper Forward'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'TradeForge 提供交易决策辅助，不会自动替你下单。',
          style: TextStyle(
            color: TradeForgeTheme.muted,
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Icon(icon, size: 20, color: TradeForgeTheme.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          DefaultTextStyle(
            style: const TextStyle(
              color: TradeForgeTheme.muted,
              fontSize: 13,
            ),
            child: trailing,
          ),
        ],
      ),
    );
  }
}
