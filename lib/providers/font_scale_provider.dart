import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ui_scale_service.dart';

/// 字体缩放档位：-3~4 八档调整
final fontScaleLevelProvider = StateProvider<int>((ref) => 0); // 允许 -3,-2,-1,0,1,2,3,4

/// 自定义缩放系数 (0.7~1.5)
final customFontScaleProvider = StateProvider<double>((ref) => 1.0);

/// 实际缩放系数：档位缩放 或 自定义缩放
final effectiveFontScaleProvider = Provider<double>((ref) {
  final level = ref.watch(fontScaleLevelProvider);
  final customScale = ref.watch(customFontScaleProvider);

  // 如果自定义缩放不是1.0，优先使用自定义缩放
  if ((customScale - 1.0).abs() > 0.01) {
    return customScale;
  }

  // 否则使用档位缩放
  switch (level) {
    case -3:
      return 0.80; // 极小
    case -2:
      return 0.86; // 很小
    case -1:
      return 0.92; // 较小
    case 1:
      return 1.08; // 较大
    case 2:
      return 1.16; // 大
    case 3:
      return 1.24; // 很大
    case 4:
      return 1.32; // 极大
    default:
      return 1.0; // 标准
  }
});

/// UI缩放Provider - 基于设备自适应 + 用户偏好
final uiScaleProvider = Provider.family<double, BuildContext>((ref, context) {
  final userScale = ref.watch(effectiveFontScaleProvider);
  return UIScaleService.getFinalScaleFactor(context, userScale);
});

/// UI缩放调试信息Provider
final uiScaleDebugProvider = Provider.family<Map<String, double>, BuildContext>((ref, context) {
  final userScale = ref.watch(effectiveFontScaleProvider);
  return UIScaleService.getDebugInfo(context, userScale);
});

/// 初始化: 读取并监听写回
final fontScaleInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();

  // 读取档位设置
  final savedLevel = prefs.getInt('fontScaleLevel');
  if (savedLevel != null) {
    ref.read(fontScaleLevelProvider.notifier).state = savedLevel.clamp(-3, 4);
  }

  // 读取自定义缩放设置
  final savedCustom = prefs.getDouble('customFontScale');
  if (savedCustom != null) {
    ref.read(customFontScaleProvider.notifier).state = savedCustom.clamp(0.7, 1.5);
  }

  // 监听档位变化并保存
  ref.listen<int>(fontScaleLevelProvider, (prev, next) async {
    await prefs.setInt('fontScaleLevel', next);
    // 当选择档位时，重置自定义缩放
    if (next != 0 || (ref.read(customFontScaleProvider) - 1.0).abs() > 0.01) {
      ref.read(customFontScaleProvider.notifier).state = 1.0;
      await prefs.setDouble('customFontScale', 1.0);
    }
  });

  // 监听自定义缩放变化并保存
  ref.listen<double>(customFontScaleProvider, (prev, next) async {
    await prefs.setDouble('customFontScale', next);
    // 当使用自定义缩放时，重置档位到标准
    if ((next - 1.0).abs() > 0.01 && ref.read(fontScaleLevelProvider) != 0) {
      ref.read(fontScaleLevelProvider.notifier).state = 0;
      await prefs.setInt('fontScaleLevel', 0);
    }
  });
});
