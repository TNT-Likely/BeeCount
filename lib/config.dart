import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class AppConfig {
  // CI 构建时通过 --dart-define 注入
  static const _envUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const _envAnon =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  static const _envRedirect =
      String.fromEnvironment('SUPABASE_REDIRECT_TO', defaultValue: '');

  static String _supabaseUrl = '';
  static String _supabaseAnonKey = '';
  static String _supabaseRedirectTo = '';

  static String get supabaseUrl => _supabaseUrl;
  static String get supabaseAnonKey => _supabaseAnonKey;
  static String get supabaseRedirectTo => _supabaseRedirectTo;
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  // 优先从本地 assets/config.json 读取；失败则退回 dart-define
  static Future<void> init() async {
    try {
      final txt = await rootBundle.loadString('assets/config.json');
      final map = jsonDecode(txt) as Map<String, dynamic>;
      _supabaseUrl = (map['supabaseUrl'] as String?)?.trim() ?? '';
      _supabaseAnonKey = (map['supabaseAnonKey'] as String?)?.trim() ?? '';
      _supabaseRedirectTo =
          (map['supabaseRedirectTo'] as String?)?.trim() ?? '';
    } catch (_) {
      // ignore, fallback to env
      _supabaseUrl = _envUrl;
      _supabaseAnonKey = _envAnon;
      _supabaseRedirectTo = _envRedirect;
    }
  }
}
