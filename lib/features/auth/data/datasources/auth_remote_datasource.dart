import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/app_user.dart';

abstract class AuthRemoteDataSource {
  Stream<AppUser?> get currentUser;

  AppUser? get currentUserSync;

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AppUser> signInWithGoogle();

  Future<void> signOut();
}

@LazySingleton(as: AuthRemoteDataSource)
class FirebaseAuthRemoteDataSource implements AuthRemoteDataSource {
  FirebaseAuthRemoteDataSource(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;
  GoogleSignIn? _googleSignIn;

  GoogleSignIn get _nativeGoogleSignIn =>
      _googleSignIn ??= GoogleSignIn.standard();

  @override
  Stream<AppUser?> get currentUser =>
      _firebaseAuth.userChanges().map(_mapUserOrNull);

  @override
  AppUser? get currentUserSync => _mapUserOrNull(_firebaseAuth.currentUser);

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _mapUser(credential.user);
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'null-user',
        message: 'Firebase returned a null user after sign-up.',
      );
    }

    await user.updateDisplayName(displayName);
    await user.reload();

    return _mapUser(_firebaseAuth.currentUser);
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    if (kIsWeb) {
      final userCredential = await _firebaseAuth.signInWithPopup(
        GoogleAuthProvider(),
      );
      return _mapUser(userCredential.user);
    }

    final googleUser = await _nativeGoogleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'cancelled',
        message: 'The Google sign-in flow was cancelled.',
      );
    }

    final authentication = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: authentication.accessToken,
      idToken: authentication.idToken,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    return _mapUser(userCredential.user);
  }

  @override
  Future<void> signOut() async {
    if (kIsWeb) {
      await _firebaseAuth.signOut();
      return;
    }

    await Future.wait<void>([
      _firebaseAuth.signOut(),
      _nativeGoogleSignIn.signOut(),
    ]);
  }

  AppUser _mapUser(User? user) {
    if (user == null) {
      throw FirebaseAuthException(
        code: 'null-user',
        message: 'Firebase returned a null user.',
      );
    }

    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
      createdAt: user.metadata.creationTime,
      lastSignInAt: user.metadata.lastSignInTime,
    );
  }

  AppUser? _mapUserOrNull(User? user) {
    if (user == null) {
      return null;
    }
    return _mapUser(user);
  }
}
