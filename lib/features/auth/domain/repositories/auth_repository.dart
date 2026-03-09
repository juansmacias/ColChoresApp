import '../../../../core/utils/result.dart';
import '../entities/app_user.dart';

abstract class AuthRepository {
  Future<Result<AppUser>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Result<AppUser>> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<Result<AppUser>> signInWithGoogle();

  Future<Result<void>> signOut();

  Stream<AppUser?> get currentUser;

  AppUser? get currentUserSync;
}
