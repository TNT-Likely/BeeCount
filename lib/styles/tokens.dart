import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_providers.dart';

/// BeeCount Design Token 系统
///
/// 设计理念：类似 CSS Design Tokens，通过语义化命名统一管理颜色。
/// 所有 UI 组件都应该使用 Token 而非直接使用颜色值。
///
/// Token 分类：
/// 1. Surface（背景色）- 页面、卡片、弹窗等背景
/// 2. Text（文字颜色）- 标题、正文、提示、禁用等
/// 3. Icon（图标颜色）- 主要、次要、提示图标
/// 4. Border（边框/分割线）- 卡片边框、列表分割线
/// 5. Semantic（语义色）- 成功、警告、错误、信息
/// 6. Interactive（交互色）- 按钮、链接、选中状态
/// 7. Brand（品牌图标色）- 各服务品牌固定色
///
/// 使用示例：
/// ```dart
/// Container(
///   color: BeeTokens.surface(context),
///   child: Text(
///     'Hello',
///     style: TextStyle(color: BeeTokens.textPrimary(context)),
///   ),
/// )
/// ```
class BeeTokens {
  // ========== 背景色 Token (Surface) ==========

  /// 页面背景色（Scaffold 背景）
  /// - 亮色模式：#FAFAFA (灰50)
  /// - 暗黑模式：#000000 (纯黑)
  static Color scaffoldBackground(BuildContext context) =>
      isDark(context) ? Colors.black : Colors.grey.shade50;

  /// 卡片背景色（贴在页面上的卡片）
  /// - 亮色模式：#FFFFFF (白色)
  /// - 暗黑模式：#1C1C1E (深灰，与纯黑背景形成对比)
  static Color surface(BuildContext context) =>
      isDark(context) ? const Color(0xFF1C1C1E) : Colors.white;

  /// 次级背景色（嵌套卡片、输入框背景）
  /// - 亮色模式：#F5F5F5 (灰100)
  /// - 暗黑模式：#2C2C2E (更深的灰)
  static Color surfaceSecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFF2C2C2E) : Colors.grey.shade100;

  /// 悬浮卡片背景色（Dialog、BottomSheet、Dropdown 等）
  /// - 亮色模式：#FFFFFF (白色)
  /// - 暗黑模式：#2C2C2E (略亮于普通卡片)
  static Color surfaceElevated(BuildContext context) =>
      isDark(context) ? const Color(0xFF2C2C2E) : Colors.white;

  /// PrimaryHeader 背景色
  /// - 亮色模式：用户选择的主题色
  /// - 暗黑模式：#000000 (纯黑)
  static Color surfaceHeader(BuildContext context) =>
      isDark(context) ? Colors.black : Theme.of(context).colorScheme.primary;

  /// BottomSheet 背景色（金额输入等弹窗）
  /// - 亮色模式：#FFFFFF (白色)
  /// - 暗黑模式：#000000 (纯黑)
  static Color surfaceSheet(BuildContext context) =>
      isDark(context) ? Colors.black : Colors.white;

  /// 键盘按钮背景色
  /// - 亮色模式：#FFFFFF (白色)
  /// - 暗黑模式：#000000 (纯黑)
  static Color surfaceKey(BuildContext context) =>
      isDark(context) ? Colors.black : Colors.white;

  /// 键盘次级按钮背景色（日期、+/-等）
  /// - 亮色模式：#F5F5F5 (灰100)
  /// - 暗黑模式：#2C2C2E (深灰)
  static Color surfaceKeySecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFF2C2C2E) : Colors.grey.shade100;

  /// 禁用按钮背景色
  /// - 亮色模式：#E0E0E0 (灰300)
  /// - 暗黑模式：#1C1C1E (更深的灰)
  static Color surfaceDisabled(BuildContext context) =>
      isDark(context) ? const Color(0xFF1C1C1E) : Colors.grey.shade300;

  /// 输入框背景色
  /// - 亮色模式：#F3F4F6 (浅灰)
  /// - 暗黑模式：#2C2C2E (深灰)
  static Color surfaceInput(BuildContext context) =>
      isDark(context) ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6);

  /// 标签/Chip 背景色（未选中状态）
  /// - 亮色模式：#EEEEEE (灰200)
  /// - 暗黑模式：#2C2C2E (深灰)
  static Color surfaceChip(BuildContext context) =>
      isDark(context) ? const Color(0xFF2C2C2E) : Colors.grey.shade200;

  /// 胶囊切换器背景色
  /// - 亮色模式：rgba(0,0,0,0.06) (浅灰透明)
  /// - 暗黑模式：#2C2C2E (深灰)
  static Color surfaceCapsule(BuildContext context) =>
      isDark(context) ? const Color(0xFF2C2C2E) : Colors.black.withValues(alpha: 0.06);

  /// 弹出层/浮层内卡片背景色（如二级分类选择）
  /// - 亮色模式：#FFFFFF (白色)
  /// - 暗黑模式：#3A3A3C (中灰)
  static Color surfacePopoverCard(BuildContext context) =>
      isDark(context) ? const Color(0xFF3A3A3C) : Colors.white;

  /// 分类图标背景色（未选中状态）
  /// - 亮色模式：#EEEEEE (灰200)
  /// - 暗黑模式：#48484A (中灰)
  static Color surfaceCategoryIcon(BuildContext context) =>
      isDark(context) ? const Color(0xFF48484A) : Colors.grey.shade200;

  /// 分类图标背景色 - 浅色版（二级分类用）
  /// - 亮色模式：#F5F5F5 (灰100)
  /// - 暗黑模式：#3A3A3C (深灰)
  static Color surfaceCategoryIconLight(BuildContext context) =>
      isDark(context) ? const Color(0xFF3A3A3C) : Colors.grey.shade100;

  /// 分类图标颜色（未选中状态）
  /// - 亮色模式：#616161 (灰700)
  /// - 暗黑模式：#AEAEB2 (浅灰)
  static Color iconCategory(BuildContext context) =>
      isDark(context) ? const Color(0xFFAEAEB2) : Colors.grey.shade700;

  /// 选中状态背景色（列表项选中、高亮）
  /// - 亮色模式：主题色 8% 透明度
  /// - 暗黑模式：主题色 15% 透明度
  static Color surfaceSelected(BuildContext context) =>
      isDark(context)
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);

  /// 悬停/按压状态背景色
  /// - 亮色模式：rgba(0,0,0,0.04)
  /// - 暗黑模式：rgba(255,255,255,0.08)
  static Color surfaceHover(BuildContext context) =>
      isDark(context)
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.04);

  // ========== 文字颜色 Token (Text) ==========

  /// 主要文字颜色（标题、正文）
  /// - 亮色模式：#111827 (灰900)
  /// - 暗黑模式：#FFFFFF (白色)
  static Color textPrimary(BuildContext context) =>
      isDark(context) ? Colors.white : const Color(0xFF111827);

  /// 次要文字颜色（副标题、说明文字）
  /// - 亮色模式：rgba(0,0,0,0.54) 即 Colors.black54
  /// - 暗黑模式：rgba(255,255,255,0.7)
  static Color textSecondary(BuildContext context) =>
      isDark(context)
          ? Colors.white.withValues(alpha: 0.7)
          : const Color(0x8A000000);

  /// 提示文字颜色（placeholder、hint、辅助说明）
  /// - 亮色模式：#9CA3AF (灰400)
  /// - 暗黑模式：rgba(255,255,255,0.54)
  static Color textTertiary(BuildContext context) =>
      isDark(context)
          ? Colors.white.withValues(alpha: 0.54)
          : const Color(0xFF9CA3AF);

  /// 禁用文字颜色
  /// - 亮色模式：rgba(0,0,0,0.26)
  /// - 暗黑模式：rgba(255,255,255,0.38)
  static Color textDisabled(BuildContext context) =>
      isDark(context)
          ? Colors.white.withValues(alpha: 0.38)
          : Colors.black.withValues(alpha: 0.26);

  /// 反色文字（用于深色背景上的白色文字）
  /// - 亮色模式：#FFFFFF
  /// - 暗黑模式：#FFFFFF
  static Color textOnPrimary(BuildContext context) => Colors.white;

  /// 链接文字颜色
  /// - 亮色模式：#3B82F6 (蓝色)
  /// - 暗黑模式：#60A5FA (亮蓝色)
  static Color textLink(BuildContext context) =>
      isDark(context) ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);

  /// Header 内主要文字颜色（用于 PrimaryHeader 内的内容）
  /// - 亮色模式：#FFFFFF（在主题色背景上）
  /// - 暗黑模式：#FFFFFF（在黑色背景上）
  static Color textOnHeader(BuildContext context) => Colors.white;

  /// Header 内次要文字颜色（用于 PrimaryHeader 内的副标题）
  /// - 亮色模式：rgba(255,255,255,0.8)（在主题色背景上）
  /// - 暗黑模式：rgba(255,255,255,0.7)（在黑色背景上）
  static Color textOnHeaderSecondary(BuildContext context) =>
      isDark(context)
          ? Colors.white.withValues(alpha: 0.7)
          : Colors.white.withValues(alpha: 0.8);

  // ========== 图标颜色 Token (Icon) ==========

  /// 主要图标颜色
  /// - 亮色模式：#000000 (87% opacity)
  /// - 暗黑模式：#FFFFFF (白色)
  static Color iconPrimary(BuildContext context) =>
      isDark(context) ? Colors.white : Colors.black87;

  /// 次要图标颜色
  /// - 亮色模式：rgba(0,0,0,0.54)
  /// - 暗黑模式：rgba(255,255,255,0.7)
  static Color iconSecondary(BuildContext context) =>
      isDark(context)
          ? Colors.white.withValues(alpha: 0.7)
          : Colors.black.withValues(alpha: 0.54);

  /// 提示图标颜色
  /// - 亮色模式：rgba(0,0,0,0.38)
  /// - 暗黑模式：rgba(255,255,255,0.54)
  static Color iconTertiary(BuildContext context) =>
      isDark(context)
          ? Colors.white.withValues(alpha: 0.54)
          : Colors.black.withValues(alpha: 0.38);

  // ========== 边框/分割线 Token (Border) ==========

  /// 分割线颜色
  /// - 亮色模式：rgba(0,0,0,0.06)
  /// - 暗黑模式：主题色 30% 透明度
  static Color divider(BuildContext context) =>
      isDark(context)
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.06);

  /// 边框颜色（卡片边框）
  /// - 亮色模式：transparent（使用阴影）
  /// - 暗黑模式：主题色 30% 透明度
  static Color border(BuildContext context) =>
      isDark(context)
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
          : Colors.transparent;

  /// 强调边框颜色
  /// - 亮色模式：rgba(0,0,0,0.12)
  /// - 暗黑模式：主题色 30% 透明度
  static Color borderStrong(BuildContext context) =>
      isDark(context)
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.12);

  /// 主题色边框（用于卡片等）
  /// - 亮色模式：transparent
  /// - 暗黑模式：主题色 30% 透明度
  static Color borderThemed(BuildContext context) =>
      isDark(context)
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
          : Colors.transparent;

  // ========== 卡片边框 Token (Card Border) ==========

  /// 卡片外边框颜色
  /// - 亮色模式：transparent（使用阴影）
  /// - 暗黑模式：transparent（去掉边框）
  static Color cardOuterBorderColor(BuildContext context) =>
      Colors.transparent;

  /// 卡片外边框宽度
  /// - 亮色模式：0
  /// - 暗黑模式：0
  static double cardOuterBorderWidth(BuildContext context) => 0;

  /// 卡片内部分割线颜色
  /// - 亮色模式：rgba(0,0,0,0.06)
  /// - 暗黑模式：transparent（去掉分割线）
  static Color cardInnerDividerColor(BuildContext context) =>
      isDark(context)
          ? Colors.transparent
          : Colors.black.withValues(alpha: 0.06);

  /// 卡片内部分割线高度
  /// - 亮色模式：1
  /// - 暗黑模式：0（去掉分割线）
  static double cardInnerDividerHeight(BuildContext context) =>
      isDark(context) ? 0 : 1;

  /// 明细列表「天」之间的分隔线。区别于卡片内 item 分隔(cardInnerDivider
  /// 暗黑不显示):明细 day 分隔亮暗都显示细线(暗黑 white 8% / 亮 black 6%)。
  static double listDayDividerHeight(BuildContext context) => 1;
  static Color listDayDividerColor(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.06);

  /// 卡片内部分割线组件
  /// 封装了 height、thickness、color 三个属性
  /// 设置项分割线。默认左缩进 48(对齐 AppListTile 内容:icon 容器 36 + 间距 12),
  /// 让线避开左侧 icon。section 顶部 / 卡片外等需要全宽的场景传 indent: 0。
  static Widget cardDivider(BuildContext context, {double indent = 48}) =>
      Divider(
        height: cardInnerDividerHeight(context),
        thickness: cardInnerDividerHeight(context),
        color: cardInnerDividerColor(context),
        indent: indent,
      );

  // ========== 主题色 Token (Theme) ==========

  /// 主题色（自动适配用户选择的颜色）
  /// - 亮色模式：用户选择的主题色（如 #F8C91C）
  /// - 暗黑模式：深色版本（如 #C49A15）
  static Color primary(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  /// 辅助色
  static Color secondary(BuildContext context) =>
      Theme.of(context).colorScheme.secondary;

  // ========== 语义色 Token (Semantic) ==========

  /// 成功状态颜色
  /// - 亮色模式：#22C55E
  /// - 暗黑模式：#34D399
  static Color success(BuildContext context) =>
      isDark(context) ? const Color(0xFF34D399) : const Color(0xFF22C55E);

  /// 警告状态颜色
  /// - 亮色模式：#F59E0B
  /// - 暗黑模式：#FBBF24
  static Color warning(BuildContext context) =>
      isDark(context) ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);

  /// 错误状态颜色
  /// - 亮色模式：#EF4444
  /// - 暗黑模式：#F87171
  static Color error(BuildContext context) =>
      isDark(context) ? const Color(0xFFF87171) : const Color(0xFFEF4444);

  /// 信息提示颜色
  /// - 亮色模式：#3B82F6
  /// - 暗黑模式：#60A5FA
  static Color info(BuildContext context) =>
      isDark(context) ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);

  // ========== 交互色 Token (Interactive) ==========

  /// 主按钮背景色
  /// - 亮色模式：主题色
  /// - 暗黑模式：主题色
  static Color buttonPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  /// 次要按钮背景色
  /// - 亮色模式：transparent
  /// - 暗黑模式：transparent
  static Color buttonSecondary(BuildContext context) => Colors.transparent;

  /// 主按钮文字颜色
  /// - 亮色模式：#FFFFFF
  /// - 暗黑模式：#FFFFFF
  static Color buttonPrimaryText(BuildContext context) => Colors.white;

  /// 次要按钮文字颜色
  /// - 亮色模式：主题色
  /// - 暗黑模式：主题色
  static Color buttonSecondaryText(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  /// 禁用按钮背景色
  /// - 亮色模式：#E5E7EB (灰200)
  /// - 暗黑模式：#3C3C3E
  static Color buttonDisabled(BuildContext context) =>
      isDark(context) ? const Color(0xFF3C3C3E) : const Color(0xFFE5E7EB);

  /// Switch 开启状态轨道颜色
  /// - 亮色模式：主题色
  /// - 暗黑模式：主题色
  static Color switchActiveTrack(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  /// Switch 关闭状态轨道颜色
  /// - 亮色模式：#E5E7EB
  /// - 暗黑模式：#3C3C3E
  static Color switchInactiveTrack(BuildContext context) =>
      isDark(context) ? const Color(0xFF3C3C3E) : const Color(0xFFE5E7EB);

  // ========== 品牌图标色 Token (Brand Icons) ==========
  // 这些颜色是各服务的品牌色，在亮暗模式下保持一致

  /// 本地存储图标色（灰色）
  static const Color brandLocal = Color(0xFF9E9E9E);

  /// Supabase 品牌色（绿色）
  static const Color brandSupabase = Color(0xFF3ECF8E);

  /// WebDAV 品牌色（橙色）
  static const Color brandWebdav = Color(0xFFFF9800);

  /// iCloud 品牌色（苹果蓝）
  static const Color brandIcloud = Color(0xFF007AFF);

  /// S3 存储品牌色（紫色）
  static const Color brandS3 = Color(0xFF8B5CF6);

  /// 云服务通用图标色（蓝色）
  static const Color brandCloud = Color(0xFF2196F3);

  // ========== 状态指示器 Token (Status Indicators) ==========

  /// 在线/连接成功指示色
  /// - 亮色模式：#22C55E
  /// - 暗黑模式：#34D399
  static Color statusOnline(BuildContext context) => success(context);

  /// 离线/断开连接指示色
  /// - 亮色模式：#9CA3AF
  /// - 暗黑模式：rgba(255,255,255,0.38)
  static Color statusOffline(BuildContext context) =>
      isDark(context) ? Colors.white.withValues(alpha: 0.38) : const Color(0xFF9CA3AF);

  /// 待处理/等待中指示色
  /// - 亮色模式：#F59E0B
  /// - 暗黑模式：#FBBF24
  static Color statusPending(BuildContext context) => warning(context);

  // ========== 图表/统计色 Token (Chart Colors) ==========

  /// 收入颜色
  /// - 亮色模式：#22C55E
  /// - 暗黑模式：#34D399
  static Color chartIncome(BuildContext context) => success(context);

  /// 支出颜色
  /// - 亮色模式：#EF4444
  /// - 暗黑模式：#F87171
  static Color chartExpense(BuildContext context) => error(context);

  /// 转账颜色
  /// - 亮色模式：#3B82F6
  /// - 暗黑模式：#60A5FA
  static Color chartTransfer(BuildContext context) => info(context);

  /// 收入颜色（动态方案，根据用户设置）
  /// - true：红色
  /// - false：绿色
  static Color incomeColor(BuildContext context, WidgetRef ref) {
    final redForIncome = ref.watch(incomeExpenseColorSchemeProvider);
    return redForIncome ? error(context) : success(context);
  }

  /// 支出颜色（动态方案，根据用户设置）
  /// - true：绿色
  /// - false：红色
  static Color expenseColor(BuildContext context, WidgetRef ref) {
    final redForIncome = ref.watch(incomeExpenseColorSchemeProvider);
    return redForIncome ? success(context) : error(context);
  }

  // ========== 遮罩层 Token (Overlay) ==========

  /// 模态遮罩层颜色
  /// - 亮色模式：rgba(0,0,0,0.5)
  /// - 暗黑模式：rgba(0,0,0,0.7)
  static Color overlay(BuildContext context) =>
      isDark(context)
          ? Colors.black.withValues(alpha: 0.7)
          : Colors.black.withValues(alpha: 0.5);

  /// 轻量遮罩层颜色（用于下拉刷新等）
  /// - 亮色模式：rgba(0,0,0,0.05)
  /// - 暗黑模式：rgba(255,255,255,0.05)
  static Color overlayLight(BuildContext context) =>
      isDark(context)
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.05);

  // ========== 悬浮 Tab 栏 Token (Floating Tab Bar) ==========

  /// 悬浮 Tab 栏背景色
  /// - 亮色模式：白色 95% 不透明
  /// - 暗黑模式：深灰 95% 不透明
  static Color tabBarBackground(BuildContext context) =>
      isDark(context)
          ? const Color(0xFF1C1C1E).withValues(alpha: 0.95)
          : Colors.white.withValues(alpha: 0.95);

  /// 悬浮 Tab 栏阴影
  static List<BoxShadow> get tabBarShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

  // ========== 辅助方法 ==========

  /// 判断当前是否为暗黑模式
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// 根据语义获取颜色（用于动态状态）
  static Color semantic(BuildContext context, String type) {
    switch (type) {
      case 'success':
        return success(context);
      case 'warning':
        return warning(context);
      case 'error':
        return error(context);
      case 'info':
        return info(context);
      default:
        return textPrimary(context);
    }
  }

  // ========== 静态常量（用于无 context 场景，如 CustomPainter、主题定义） ==========
  // 注意：这些是亮色模式下的值，暗黑模式请使用带 context 的方法

  /// 主要文字颜色（亮色模式）
  static const Color primaryTextStatic = Color(0xFF111827);

  /// 次要文字颜色（亮色模式）
  static const Color secondaryTextStatic = Color(0xFF6B7280);

  /// 提示文字颜色（亮色模式）
  static const Color hintTextStatic = Color(0xFF9CA3AF);

  /// 54% 黑色（亮色模式，兼容 Colors.black54）
  static const Color black54Static = Color(0x8A000000);

  /// 分割线颜色（亮色模式）
  static Color get dividerStatic => Colors.black.withValues(alpha: 0.06);
}

// ============================================================================
// 设计基准令牌 (Design Tokens)
// ============================================================================

/// 间距、圆角等尺寸令牌
class BeeDimens {
  static const double p8 = 8;
  static const double p12 = 12;
  static const double p16 = 16;
  static const double radius12 = 12;
  static const double radius16 = 16;
  // 列表相关：分组头与行的统一垂直内边距
  static const double listHeaderVertical = 6;
  static const double listRowVertical = 8;
}

/// 阴影令牌
class BeeShadows {
  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    )
  ];
}

/// 分割线组件令牌
class BeeDivider {
  static Divider thin({EdgeInsetsGeometry? padding}) => Divider(
        height: 1,
        thickness: 1,
        color: BeeTokens.dividerStatic,
      );

  static Divider short({double indent = 0, double endIndent = 0}) => Divider(
        height: 1,
        thickness: 1,
        indent: indent,
        endIndent: endIndent,
        color: BeeTokens.dividerStatic,
      );
}

/// 图表令牌：统一折线图的视觉参数
class BeeChartTokens {
  static const double lineWidth = 2.0;
  static const double dotRadius = 2.5;
  static const double cornerRadius = 12.0;
  static const double xLabelFontSize = 10.0;
  static const double yLabelFontSize = 10.0;
}

/// 文本样式令牌：全局统一字号与字重
class BeeTextTokens {
  // 标题：用于列表主标题、条目标题
  static TextStyle title(BuildContext ctx) =>
      Theme.of(ctx).textTheme.bodyLarge?.copyWith(
            color: BeeTokens.textPrimary(ctx),
          ) ??
      TextStyle(
          fontSize: 15, color: BeeTokens.textPrimary(ctx), fontWeight: FontWeight.w400);

  // 强调标题：用于统计数字等需要比普通列表标题更醒目的场景
  static TextStyle strongTitle(BuildContext ctx) =>
      Theme.of(ctx).textTheme.bodyLarge?.copyWith(
            fontSize: 15,
            color: BeeTokens.textPrimary(ctx),
            fontWeight: FontWeight.w600,
          ) ??
      TextStyle(
          fontSize: 15, color: BeeTokens.textPrimary(ctx), fontWeight: FontWeight.w600);

  // 加粗标题：用于极强强调（如大额数字/主标题）
  static TextStyle boldTitle(BuildContext ctx) =>
      Theme.of(ctx).textTheme.bodyLarge?.copyWith(
            fontSize: 18,
            color: BeeTokens.textPrimary(ctx),
            fontWeight: FontWeight.w700,
          ) ??
      TextStyle(
          fontSize: 18, color: BeeTokens.textPrimary(ctx), fontWeight: FontWeight.w700);

  // 正文：用于一般性文字
  static TextStyle body(BuildContext ctx) =>
      Theme.of(ctx).textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: BeeTokens.textPrimary(ctx),
          ) ??
      TextStyle(fontSize: 14, color: BeeTokens.textPrimary(ctx));

  // 标签/说明：用于次要说明、辅助信息
  static TextStyle label(BuildContext ctx) =>
      Theme.of(ctx).textTheme.labelMedium?.copyWith(
            fontSize: 12,
            color: BeeTokens.textSecondary(ctx),
          ) ??
      TextStyle(fontSize: 12, color: BeeTokens.textSecondary(ctx));
}

// ============================================================================
// 字体令牌 (Typography Tokens)
// ============================================================================

/// 字体配置令牌
class BeeTypography {
  static bool useBundledFonts = false; // 已禁用打包字体，使用系统字体

  // Primary Latin family when bundled
  static const String bundledLatin = 'Inter';
  // Primary Chinese family when bundled
  static const String bundledCJK = 'NotoSansSC';
  // iOS system Chinese font
  static const String systemCJKiOS = 'PingFang SC';

  /// 构建基础文本主题
  static TextTheme buildBase(TextTheme base, {required bool isIOS}) {
    final bodyW = FontWeight.w400;
    final titleW = FontWeight.w600;
    final useBundledHere = useBundledFonts && !isIOS;
    final latin =
        useBundledHere ? bundledLatin : (isIOS ? 'Helvetica Neue' : 'Roboto');
    final cjk =
        useBundledHere ? bundledCJK : (isIOS ? systemCJKiOS : 'NotoSans');
    final familyFallback = <String>{
      latin,
      cjk,
      'PingFang SC',
      'Helvetica Neue',
      'Roboto',
      'Arial'
    };

    TextStyle merge(TextStyle? src, double size, FontWeight w,
        {double? height}) {
      return (src ?? const TextStyle()).copyWith(
        fontSize: size,
        fontWeight: w,
        height: height ?? 1.25,
        fontFamily: latin,
        fontFamilyFallback: familyFallback.toList(),
      );
    }

    return base.copyWith(
      bodySmall: merge(base.bodySmall, 12, bodyW),
      bodyMedium: merge(base.bodyMedium, 14, bodyW),
      bodyLarge: merge(base.bodyLarge, 15, bodyW, height: 1.28),
      labelLarge: merge(base.labelLarge, 13, FontWeight.w600),
      titleMedium: merge(base.titleMedium, 15, FontWeight.w500),
      titleLarge: merge(base.titleLarge, 18, titleW, height: 1.3),
      headlineSmall: merge(base.headlineSmall, 20, titleW, height: 1.3),
    );
  }
}

