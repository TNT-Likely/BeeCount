import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class AppConfig {
  // CI 构建时通过 --dart-define 注入
  static const _envUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const _envAnon =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static String _supabaseUrl = '';
  static String _supabaseAnonKey = '';

  static String get supabaseUrl => _supabaseUrl;
  static String get supabaseAnonKey => _supabaseAnonKey;
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  // 优先从本地 assets/config.json 读取；失败则退回 dart-define
  static Future<void> init() async {
    try {
      final txt = await rootBundle.loadString('assets/config.json');
      final map = jsonDecode(txt) as Map<String, dynamic>;
      _supabaseUrl = (map['supabaseUrl'] as String?)?.trim() ?? '';
      _supabaseAnonKey = (map['supabaseAnonKey'] as String?)?.trim() ?? '';
    } catch (_) {
      // ignore, keep defaults and let env fill below
    }

    // 若通过 --dart-define 提供了变量，则优先生效覆盖 assets 值。
    if (_envUrl.isNotEmpty) {
      _supabaseUrl = _envUrl;
    }
    if (_envAnon.isNotEmpty) {
      _supabaseAnonKey = _envAnon;
    }
  }
}
