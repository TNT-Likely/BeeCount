import 'package:flutter/foundation.dart';

@immutable
class AuthUser {
  final String id;
  final String? email;
  const AuthUser({required this.id, this.email});
}

abstract class AuthService {
  Stream<AuthUser?> authStateChanges();
  Future<AuthUser?> currentUser();
  Future<AuthUser> signInWithEmail(
      {required String email, required String password});
  Future<AuthUser> signUpWithEmail(
      {required String email, required String password});
  Future<void> signOut();
  Future<void> sendPasswordResetEmail({required String email});
  Future<void> resendEmailVerification({required String email});
}

class NoopAuthService implements AuthService {
  @override
  Stream<AuthUser?> authStateChanges() async* {}

  @override
  Future<AuthUser?> currentUser() async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthUser> signInWithEmail(
      {required String email, required String password}) async {
    throw UnsupportedError('Auth is not configured');
  }

  @override
  Future<AuthUser> signUpWithEmail(
      {required String email, required String password}) async {
    throw UnsupportedError('Auth is not configured');
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    throw UnsupportedError('Auth is not configured');
  }

  @override
  Future<void> resendEmailVerification({required String email}) async {
    throw UnsupportedError('Auth is not configured');
  }
}
