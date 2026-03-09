import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/pin_repository.dart';

part 'pin_state.dart';

@singleton
class PinCubit extends Cubit<PinState> {
  PinCubit(this._pinRepository, this._sharedPreferences)
      : super(const PinInitial());

  final PinRepository _pinRepository;
  final SharedPreferences _sharedPreferences;

  DateTime? _sessionExpiresAt;
  Timer? _sessionTimer;

  static const _failedAttemptsKey = 'pin_failed_attempts';
  static const _lockoutUntilKey = 'pin_lockout_until';
  static const _lockoutLevelKey = 'pin_lockout_level';
  static const maxAttempts = 5;
  static const sessionDuration = Duration(minutes: 5);
  static const _lockouts = [
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 30),
    Duration(hours: 1),
  ];

  bool get isSessionActive =>
      _sessionExpiresAt != null && DateTime.now().isBefore(_sessionExpiresAt!);

  Future<void> authenticateWithBiometric() async {
    emit(const PinLoading());
    final result = await _pinRepository.authenticateWithBiometric();
    result.when(
      success: (authenticated) {
        if (authenticated) {
          _startSession();
          emit(const PinVerified());
        } else {
          emit(const PinInitial());
        }
      },
      failure: (_) => emit(const PinInitial()),
    );
  }

  void onAppBackground() {
    _sessionExpiresAt = null;
    _sessionTimer?.cancel();
    emit(const PinInitial());
  }

  Future<void> setPin({
    required String memberId,
    required String pin,
    required String confirmPin,
  }) async {
    if (pin != confirmPin) {
      emit(const PinSetupError("PINs don't match. Please try again."));
      return;
    }
    if (pin.length < 4 || pin.length > 6) {
      emit(const PinSetupError('PIN must be 4 to 6 digits.'));
      return;
    }

    emit(const PinLoading());
    final result = await _pinRepository.setPin(memberId: memberId, pin: pin);
    result.when(
      success: (_) {
        _startSession();
        emit(const PinSet());
      },
      failure: (failure) => emit(PinSetupError(failure.message)),
    );
  }

  Future<void> verifyPin({
    required String memberId,
    required String pin,
  }) async {
    final lockoutUntil = _getLockoutUntil();
    if (lockoutUntil != null && DateTime.now().isBefore(lockoutUntil)) {
      emit(PinLocked(lockedUntil: lockoutUntil));
      return;
    }

    emit(const PinLoading());
    final result = await _pinRepository.verifyPin(memberId: memberId, pin: pin);
    result.when(
      success: (isValid) {
        if (isValid) {
          _clearAttempts();
          _startSession();
          emit(const PinVerified());
          return;
        }
        _recordFailure();
      },
      failure: (_) => _recordFailure(),
    );
  }

  void _recordFailure() {
    final attempts = (_sharedPreferences.getInt(_failedAttemptsKey) ?? 0) + 1;
    _sharedPreferences.setInt(_failedAttemptsKey, attempts);
    final remaining = maxAttempts - attempts;
    if (remaining <= 0) {
      final level = _sharedPreferences.getInt(_lockoutLevelKey) ?? 0;
      final duration = _lockouts[level.clamp(0, _lockouts.length - 1)];
      final lockedUntil = DateTime.now().add(duration);
      _sharedPreferences.setInt(
        _lockoutUntilKey,
        lockedUntil.millisecondsSinceEpoch,
      );
      _sharedPreferences.setInt(_lockoutLevelKey, level + 1);
      _sharedPreferences.remove(_failedAttemptsKey);
      emit(PinLocked(lockedUntil: lockedUntil));
      return;
    }
    emit(PinFailed(attemptsRemaining: remaining));
  }

  void _clearAttempts() {
    _sharedPreferences.remove(_failedAttemptsKey);
    _sharedPreferences.remove(_lockoutUntilKey);
  }

  DateTime? _getLockoutUntil() {
    final millis = _sharedPreferences.getInt(_lockoutUntilKey);
    if (millis == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  void _startSession() {
    _sessionTimer?.cancel();
    _sessionExpiresAt = DateTime.now().add(sessionDuration);
    _sessionTimer = Timer(sessionDuration, () {
      _sessionExpiresAt = null;
      emit(const PinInitial());
    });
  }

  @override
  Future<void> close() async {
    _sessionTimer?.cancel();
    return super.close();
  }
}
