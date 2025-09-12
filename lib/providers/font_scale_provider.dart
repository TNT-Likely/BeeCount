import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 字体缩放档位：-1 小, 0 标准, 1 大
final fontScaleLevelProvider = StateProvider<int>((ref) => 0); // 允许 -2,-1,0,1

/// 实际缩放系数：与 clamp 后的系统 textScaleFactor 相乘
final effectiveFontScaleProvider = Provider<double>((ref) {
  final level = ref.watch(fontScaleLevelProvider);
  switch (level) {
    case -2:
      return 0.86; // 更小
    case -1:
      return 0.92; // 小
    case 1:
      return 1.08; // 大
    default:
      return 1.0; // 标准
  }
});

/// 初始化: 读取并监听写回
final fontScaleInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getInt('fontScaleLevel');
  if (saved != null) {
    ref.read(fontScaleLevelProvider.notifier).state = saved.clamp(-2, 1);
  }
  ref.listen<int>(fontScaleLevelProvider, (prev, next) async {
    await prefs.setInt('fontScaleLevel', next);
  });
});
