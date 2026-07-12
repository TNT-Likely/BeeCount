import 'package:meta/meta.dart';

/// Represents an authenticated cloud user
@immutable
class CloudUser {
  /// Unique user identifier
  final String id;

  /// User email (optional, depends on provider)
  final String? email;

  /// Additional user metadata (provider-specific)
  final Map<String, dynamic>? metadata;

  const CloudUser({
    required this.id,
    this.email,
    this.metadata,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CloudUser && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CloudUser(id: $id, email: $email)';
}

/// Abstract interface for cloud authentication services
abstract class CloudAuthService {
  /// Stream of authentication state changes
  ///
  /// Emits the current user when authenticated, null when not authenticated.
  /// Perfect for use with Riverpod StreamProvider.
  Stream<CloudUser?> get authStateChanges;

  /// Get the currently authenticated user
  ///
  /// Returns null if not authenticated.
  Future<CloudUser?> get currentUser;

  /// Sign in with email and password
  ///
  /// Throws [CloudAuthException] if sign in fails.
  Future<CloudUser> signInWithEmail({
    required String email,
    required String password,
  });

  /// Sign up with email and password
  ///
  /// Throws [CloudAuthException] if sign up fails.
  /// Note: Some providers (like Supabase) require email verification.
  Future<CloudUser> signUpWithEmail({
    required String email,
    required String password,
  });

  /// Sign out the current user
  ///
  /// Throws [CloudAuthException] if sign out fails.
  Future<void> signOut();

  /// Send password reset email
  ///
  /// Throws [CloudAuthException] if operation fails.
  Future<void> sendPasswordResetEmail({required String email});

  /// Resend email verification
  ///
  /// Throws [CloudAuthException] if operation fails.
  Future<void> resendEmailVerification({required String email});
}

/// No-op implementation for providers that don't require authentication
class NoopAuthService implements CloudAuthService {
  @override
  Stream<CloudUser?> get authStateChanges => Stream.value(null);

  @override
  Future<CloudUser?> get currentUser async => null;

  @override
  Future<CloudUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    throw UnsupportedError('Auth is not configured');
  }

  @override
  Future<CloudUser> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    throw UnsupportedError('Auth is not configured');
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    throw UnsupportedError('Auth is not configured');
  }

  @override
  Future<void> resendEmailVerification({required String email}) async {
    throw UnsupportedError('Auth is not configured');
  }
}
