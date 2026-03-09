import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/sync/sync_status.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/pin_repository.dart';
import '../../domain/services/pin_hash_service.dart';

@LazySingleton(as: PinRepository)
class PinRepositoryImpl implements PinRepository {
  PinRepositoryImpl(
    this._database,
    this._pinHashService,
    this._localAuthentication,
    this._sharedPreferences,
  );

  final AppDatabase _database;
  final PinHashService _pinHashService;
  final LocalAuthentication _localAuthentication;
  final SharedPreferences _sharedPreferences;

  @override
  Future<Result<bool>> authenticateWithBiometric() async {
    try {
      final didAuthenticate = await _localAuthentication.authenticate(
        localizedReason: 'Verify your identity to continue',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return Result.success(didAuthenticate);
    } catch (error, stackTrace) {
      return Result.failure(
        UnexpectedFailure(
          message: 'Biometric authentication failed.',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> clearPin(String memberId) async {
    try {
      await (_database.update(_database.membersTable)
            ..where((t) => t.id.equals(int.parse(memberId))))
          .write(
        MembersTableCompanion(
          pinHash: const Value(null),
          pinSalt: const Value(null),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(SyncStatus.pending),
        ),
      );
      return const Result.success(null);
    } catch (error, stackTrace) {
      return Result.failure(
        DatabaseFailure(
          message: 'Failed to clear PIN.',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<bool>> getBiometricEnabled(String memberId) async {
    return Result.success(
      _sharedPreferences.getBool('biometric_enabled_$memberId') ?? false,
    );
  }

  @override
  Future<Result<bool>> hasPin(String memberId) async {
    try {
      final member = await (_database.select(_database.membersTable)
            ..where((t) => t.id.equals(int.parse(memberId))))
          .getSingleOrNull();
      return Result.success(
        member?.pinHash != null && member?.pinSalt != null,
      );
    } catch (error, stackTrace) {
      return Result.failure(
        DatabaseFailure(
          message: 'Failed to check PIN.',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<bool>> isBiometricAvailable() async {
    try {
      final canCheck = await _localAuthentication.canCheckBiometrics;
      final supported = await _localAuthentication.isDeviceSupported();
      return Result.success(canCheck && supported);
    } catch (error, stackTrace) {
      return Result.failure(
        UnexpectedFailure(
          message: 'Failed to check biometric availability.',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  @override
  Future<Result<void>> setBiometricEnabled({
    required String memberId,
    required bool enabled,
  }) async {
    await _sharedPreferences.setBool('biometric_enabled_$memberId', enabled);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> setPin({
    required String memberId,
    required String pin,
  }) async {
    try {
      final salt = _pinHashService.generateSalt();
      final hash = _pinHashService.computeHash(pin, salt);
      await (_database.update(_database.membersTable)
            ..where((t) => t.id.equals(int.parse(memberId))))
          .write(
        MembersTableCompanion(
          pinHash: Value(hash),
          pinSalt: Value(salt),
          updatedAt: Value(DateTime.now()),
          syncStatus: const Value(SyncStatus.pending),
        ),
      );
      return const Result.success(null);
    } catch (error, stackTrace) {
      return Result.failure(
        DatabaseFailure(message: 'Failed to save PIN.', stackTrace: stackTrace),
      );
    }
  }

  @override
  Future<Result<bool>> verifyPin({
    required String memberId,
    required String pin,
  }) async {
    try {
      final member = await (_database.select(_database.membersTable)
            ..where((t) => t.id.equals(int.parse(memberId))))
          .getSingleOrNull();
      if (member?.pinHash == null || member?.pinSalt == null) {
        return const Result.failure(
          PermissionFailure(message: 'No PIN set for this profile.'),
        );
      }
      return Result.success(
        _pinHashService.verify(pin, member!.pinSalt!, member.pinHash!),
      );
    } catch (error, stackTrace) {
      return Result.failure(
        DatabaseFailure(
          message: 'Failed to verify PIN.',
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
