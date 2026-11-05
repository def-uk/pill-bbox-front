import 'package:flutter/material.dart';

import '../common/app_notices.dart';
import '../common/theme.dart';
import '../common/widgets.dart';

/// 더 보기 → 앱 안내. 처음 열 때 본 안내를 다시 본다.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('앱 안내')),
      body: ListView(
        padding: pagePadding(context, top: AppSpacing.md),
        children: const [AppNotices()],
      ),
    );
  }
}
