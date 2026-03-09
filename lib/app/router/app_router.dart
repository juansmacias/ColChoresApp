import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'route_names.dart';

// TODO(phase-2): Add auth and PIN redirect logic via guards
final GoRouter appRouter = GoRouter(
  initialLocation: RouteNames.home,
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: RouteNames.home,
      builder: (context, state) => const _PlaceholderScreen(title: 'Home'),
    ),
    GoRoute(
      path: RouteNames.signIn,
      builder: (context, state) => const _PlaceholderScreen(title: 'Sign In'),
    ),
    GoRoute(
      path: RouteNames.taskList,
      builder: (context, state) => const _PlaceholderScreen(title: 'Tasks'),
    ),
  ],
);

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title — coming soon')),
    );
  }
}
