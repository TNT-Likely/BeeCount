import 'package:supabase_flutter/supabase_flutter.dart' as s;

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
    final res =
        await client.auth.signInWithPassword(email: email, password: password);
    final u = res.user!;
    return AuthUser(id: u.id, email: u.email);
  }

  @override
  Future<AuthUser> signUpWithEmail(
      {required String email, required String password}) async {
    final res = await client.auth.signUp(email: email, password: password);
    final u = res.user!;
    return AuthUser(id: u.id, email: u.email);
  }
}
