import '../../../../core/utils/result.dart';

abstract class PinRepository {
  Future<Result<void>> setPin({
    required String memberId,
    required String pin,
  });

  Future<Result<bool>> verifyPin({
    required String memberId,
    required String pin,
  });

  Future<Result<bool>> hasPin(String memberId);

  Future<Result<void>> clearPin(String memberId);

  Future<Result<bool>> getBiometricEnabled(String memberId);

  Future<Result<void>> setBiometricEnabled({
    required String memberId,
    required bool enabled,
  });

  Future<Result<bool>> isBiometricAvailable();

  Future<Result<bool>> authenticateWithBiometric();
}
