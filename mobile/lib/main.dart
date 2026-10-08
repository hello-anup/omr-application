import 'package:flutter/material.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';

void main() {
  runApp(const OmrApplication());
}

class OmrApplication extends StatelessWidget {
  const OmrApplication({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}
