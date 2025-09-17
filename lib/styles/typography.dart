import 'package:flutter/material.dart';

/// Stage C: Centralized typography tokens with planned bundled fonts.
///
/// How to fully enable bundled fonts (after you place font files under assets/fonts):
/// 1. Download Inter (Regular, Medium(500), SemiBold(600)) & NotoSansSC (Regular, Medium, SemiBold)
/// 2. Place them: assets/fonts/Inter-Regular.ttf, Inter-Medium.ttf, Inter-SemiBold.ttf
///                assets/fonts/NotoSansSC-Regular.otf, NotoSansSC-Medium.otf, NotoSansSC-SemiBold.otf
/// 3. Add to pubspec.yaml (example snippet below) then run `flutter pub get`
///
/// flutter:
///   fonts:
///     - family: Inter
///       fonts:
///         - asset: assets/fonts/Inter-Regular.ttf
///         - asset: assets/fonts/Inter-Medium.ttf
///           weight: 500
///         - asset: assets/fonts/Inter-SemiBold.ttf
///           weight: 600
///     - family: NotoSansSC
///       fonts:
///         - asset: assets/fonts/NotoSansSC-Regular.otf
///         - asset: assets/fonts/NotoSansSC-Medium.otf
///           weight: 500
///         - asset: assets/fonts/NotoSansSC-SemiBold.otf
///           weight: 600
///
/// 4. Set [AppTypography.useBundledFonts] = true (can be wired to a provider / settings later).
/// 5. Rebuild. If fonts missing, leave `useBundledFonts` false to fall back gracefully.
class AppTypography {
  static bool useBundledFonts = false; // 已禁用打包字体，使用系统字体

  // Primary Latin family when bundled; fallback to system if not available.
  static const String bundledLatin = 'Inter';
  // Primary Chinese family when bundled.
  static const String bundledCJK = 'NotoSansSC';

  // iOS system Chinese font (PingFang SC). Keep for platform consistency when not bundling.
  static const String systemCJKiOS = 'PingFang SC';

  // Build a base set of text styles independent of platform scaling.
  static TextTheme buildBase(TextTheme base, {required bool isIOS}) {
    // Scheme A: iOS(含 macOS) 用 500 提升细度可读性；Android 回落到 400 避免视觉过粗
    final bodyW = FontWeight.w400;
    // Keep main large titles at 600, but medium titles降一级避免看起来整体变粗
    final titleW = FontWeight.w600;
    // iOS 保持系统平方（PingFang SC），不使用打包中文字体；避免破坏原生渲染与 hinting。
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
      // titleMedium 下调到 500，避免在卡片/设置项里显得过重
      titleMedium: merge(base.titleMedium, 15, FontWeight.w500),
      titleLarge: merge(base.titleLarge, 18, titleW, height: 1.3),
      headlineSmall: merge(base.headlineSmall, 20, titleW, height: 1.3),
    );
  }
}
