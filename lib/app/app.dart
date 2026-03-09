import 'package:flutter/material.dart';

import '../shared/theme/app_theme.dart';
import 'router/app_router.dart';

class FamilyChoresApp extends StatelessWidget {
  const FamilyChoresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Family Chores',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
