import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// TODO(phase-2): Implement real PIN verification state check
class PinGuard {
  const PinGuard();

  String? call(BuildContext context, GoRouterState state) {
    // TODO(phase-2): Check if active profile requires PIN
    // If PIN not verified, redirect to PIN entry
    // return RouteNames.pinEntry;
    return null;
  }
}
