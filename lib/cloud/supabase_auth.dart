import 'package:supabase_flutter/supabase_flutter.dart' as s;
import '../utils/logger.dart';

import 'auth.dart';

class SupabaseAuthService implements AuthService {
  final s.SupabaseClient client;
  SupabaseAuthService(this.client);

  @override
  Stream<AuthUser?> authStateChanges() {
    return client.auth.onAuthStateChange.map((event) {
      final u = event.session?.user;
      return u != null ? AuthUser(id: u.id, email: u.email) : null;
    });
  }

  @override
  Future<AuthUser?> currentUser() async {
    final u = client.auth.currentUser;
    if (u == null) return null;
    return AuthUser(id: u.id, email: u.email);
  }

  @override
  Future<void> signOut() => client.auth.signOut();

  @override
  Future<AuthUser> signInWithEmail(
      {required String email, required String password}) async {
    logI('Auth', 'signIn email=$email');
    final res =
        await client.auth.signInWithPassword(email: email, password: password);
    final u = res.user!;
    logI('Auth', 'signIn success uid=${u.id}');
    return AuthUser(id: u.id, email: u.email);
  }

  @override
  Future<AuthUser> signUpWithEmail(
      {required String email, required String password}) async {
    logI('Auth', 'signUp email=$email');
    try {
      final res = await client.auth.signUp(email: email, password: password);
      final u = res.user!;
      logI('Auth',
          'signUp success uid=${u.id} emailConfirmed=${u.emailConfirmedAt != null}');
      return AuthUser(id: u.id, email: u.email);
    } catch (e, st) {
      logE('Auth', 'signUp failed', e, st);
      rethrow;
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    logI('Auth', 'resetPassword email=$email');
    // 直接使用 Supabase Project 配置中的重置回调（不在客户端覆盖 redirect）
    await client.auth.resetPasswordForEmail(email);
  }

  @override
  Future<void> resendEmailVerification({required String email}) async {
    // 使用 Supabase 的 resend 接口重发验证邮件（signup 类型）
    logI('Auth', 'resendVerify email=$email');
    await client.auth.resend(
      type: s.OtpType.signup,
      email: email,
    );
  }
}
