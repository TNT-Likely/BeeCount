import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show kReleaseMode;

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

  // 发布版仅使用 dart-define；非发布（调试/本地）可尝试从 assets 读取作为方便。
  static Future<void> init() async {
    // 非发布构建尝试读取 assets/config.json，失败则忽略
    if (!kReleaseMode) {
      try {
        final txt = await rootBundle.loadString('assets/config.json');
        final map = jsonDecode(txt) as Map<String, dynamic>;
        _supabaseUrl = (map['supabaseUrl'] as String?)?.trim() ?? '';
        _supabaseAnonKey = (map['supabaseAnonKey'] as String?)?.trim() ?? '';
      } catch (_) {
        // ignore, keep defaults and let env fill below
      }
    }

    // 若通过 --dart-define 提供了变量，则优先生效覆盖
    if (_envUrl.isNotEmpty) {
      _supabaseUrl = _envUrl;
    }
    if (_envAnon.isNotEmpty) {
      _supabaseAnonKey = _envAnon;
    }
  }
}
