import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
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

  // 发布版仅使用 dart-define；非发布（调试/本地）可尝试从 assets 读取作为方便。
  static Future<void> init() async {
    logI('Config', '开始初始化 AppConfig，kReleaseMode=$kReleaseMode');
    
    // 非发布构建尝试读取 assets/config.json，失败则忽略
    if (!kReleaseMode) {
      try {
        logI('Config', '非Release模式，尝试读取 assets/config.json');
        final txt = await rootBundle.loadString('assets/config.json');
        final map = jsonDecode(txt) as Map<String, dynamic>;
        _supabaseUrl = (map['supabaseUrl'] as String?)?.trim() ?? '';
        _supabaseAnonKey = (map['supabaseAnonKey'] as String?)?.trim() ?? '';
        logI('Config', '成功从 assets/config.json 加载配置，URL长度=${_supabaseUrl.length}，Key长度=${_supabaseAnonKey.length}');
      } catch (e) {
        logE('Config', '读取 assets/config.json 失败', e);
      }
    } else {
      logI('Config', 'Release模式，跳过 assets/config.json，仅依赖 --dart-define');
    }

    // 若通过 --dart-define 提供了变量，则优先生效覆盖
    logI('Config', '--dart-define 环境变量：URL长度=${_envUrl.length}，Key长度=${_envAnon.length}');
    if (_envUrl.isNotEmpty) {
      _supabaseUrl = _envUrl;
      logI('Config', '使用 --dart-define 的 SUPABASE_URL');
    }
    if (_envAnon.isNotEmpty) {
      _supabaseAnonKey = _envAnon;
      logI('Config', '使用 --dart-define 的 SUPABASE_ANON_KEY');
    }
    
    logI('Config', '最终配置：URL=${_supabaseUrl.isEmpty ? "空" : "已设置(${_supabaseUrl.length}字符)"}，Key=${_supabaseAnonKey.isEmpty ? "空" : "已设置(${_supabaseAnonKey.length}字符)"}，hasSupabase=$hasSupabase');
    
    if (!hasSupabase) {
      logE('Config', 'Supabase 配置缺失！这会导致登录功能无法使用');
    }
  }
}
