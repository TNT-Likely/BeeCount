import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 保活开关（默认关闭）
final keepAliveProvider = StateProvider<bool>((ref) => false);

/// 保活开关持久化初始化
final keepAliveInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getBool('keep_alive_enabled');
  if (saved != null) {
    ref.read(keepAliveProvider.notifier).state = saved;
  }
  ref.listen<bool>(keepAliveProvider, (prev, next) async {
    await prefs.setBool('keep_alive_enabled', next);
  });
});
