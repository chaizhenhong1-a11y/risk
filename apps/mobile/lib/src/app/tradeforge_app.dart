import 'package:flutter/material.dart';

import '../presentation/shell/tradeforge_shell.dart';
import '../theme/tradeforge_theme.dart';

class TradeForgeApp extends StatelessWidget {
  const TradeForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TradeForge',
      debugShowCheckedModeBanner: false,
      theme: TradeForgeTheme.dark,
      home: const TradeForgeShell(),
    );
  }
}
