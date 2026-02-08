import 'package:flutter/material.dart';

/// ライセンス一覧画面
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context),
      child: const LicensePage(
        applicationName: 'MuxPod',
        applicationVersion: '1.0.0',
        applicationLegalese: '© 2025 mox',
      ),
    );
  }
}
