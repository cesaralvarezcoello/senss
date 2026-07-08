import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'features/feed/feed_screen.dart';

class SenssApp extends StatelessWidget {
  const SenssApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const FeedScreen(),
    );
  }
}
