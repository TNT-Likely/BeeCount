import 'package:flutter/foundation.dart' show kReleaseMode;
import 'utils/logger.dart';

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

  // 通过 --dart-define 或 --dart-define-from-file 注入配置
  static Future<void> init() async {
    logI('Config', '开始初始化 AppConfig，kReleaseMode=$kReleaseMode');
    
    // 从 --dart-define 环境变量获取配置
    logI('Config', '--dart-define 环境变量：URL长度=${_envUrl.length}，Key长度=${_envAnon.length}');
    _supabaseUrl = _envUrl;
    _supabaseAnonKey = _envAnon;
    
    if (_envUrl.isNotEmpty) {
      logI('Config', '使用 --dart-define 的 SUPABASE_URL');
    }
    if (_envAnon.isNotEmpty) {
      logI('Config', '使用 --dart-define 的 SUPABASE_ANON_KEY');
    }
    
    logI('Config', '最终配置：URL=${_supabaseUrl.isEmpty ? "空" : "已设置(${_supabaseUrl.length}字符)"}，Key=${_supabaseAnonKey.isEmpty ? "空" : "已设置(${_supabaseAnonKey.length}字符)"}，hasSupabase=$hasSupabase');
    
    if (!hasSupabase) {
      logE('Config', 'Supabase 配置缺失！这会导致登录功能无法使用');
    }
  }
}
