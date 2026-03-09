part of 'pin_cubit.dart';

sealed class PinState {
  const PinState();
}

final class PinInitial extends PinState {
  const PinInitial();
}

final class PinLoading extends PinState {
  const PinLoading();
}

final class PinVerified extends PinState {
  const PinVerified();
}

final class PinSet extends PinState {
  const PinSet();
}

final class PinFailed extends PinState {
  const PinFailed({required this.attemptsRemaining});

  final int attemptsRemaining;
}

final class PinLocked extends PinState {
  const PinLocked({required this.lockedUntil});

  final DateTime lockedUntil;
}

final class PinSetupError extends PinState {
  const PinSetupError(this.message);

  final String message;
}
