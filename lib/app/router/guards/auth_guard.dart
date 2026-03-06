import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// TODO(phase-2): Implement real Firebase Auth state check
class AuthGuard {
  const AuthGuard();

  String? call(BuildContext context, GoRouterState state) {
    // TODO(phase-2): Check FirebaseAuth.instance.currentUser
    // If unauthenticated, redirect to sign-in
    // return RouteNames.signIn;
    return null;
  }
}
