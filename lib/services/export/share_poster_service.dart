import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../utils/app_localizations_resolver.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../pages/report/share/bindings/share_card_controls.dart';
import '../../pages/shared/sharing/bindings/app_promo_poster.dart';
import '../../pages/shared/sharing/bindings/year_summary_poster.dart';
import '../../pages/shared/sharing/bindings/month_summary_poster.dart';
import '../../pages/shared/sharing/bindings/ledger_summary_poster.dart';
import 'share_poster_data_service.dart';

/// 保存海报结果
enum SavePosterResult {
  success,
  failed,
  accessDenied,
}

/// 分享海报生成服务
class SharePosterService {
  /// 生成分享海报图片数据
  static Future<Uint8List?> generatePoster(
      BuildContext context, Color primaryColor) async {
    try {
      final l10n = AppLocalizations.of(context);

      // 创建海报Widget的GlobalKey
      final GlobalKey posterKey = GlobalKey();

      // 构建海报Widget
      final posterWidget = RepaintBoundary(
        key: posterKey,
        child: AppPromoPoster(
          l10n: l10n,
          primaryColor: primaryColor,
        ),
      );

      // 使用OverlayEntry来渲染Widget
      final overlay = Overlay.of(context);
      late OverlayEntry overlayEntry;
      overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: -10000, // 移出屏幕外
          top: -10000,
          child: Material(
            color: Colors.transparent,
            child: posterWidget,
          ),
        ),
      );

      overlay.insert(overlayEntry);

      // 等待Widget渲染完成
      await Future.delayed(const Duration(milliseconds: 500));

      // 获取RenderRepaintBoundary
      final RenderRepaintBoundary boundary =
          posterKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      // 转换为图片
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      // 移除OverlayEntry
      overlayEntry.remove();

      return pngBytes;
    } catch (e) {
      return null;
    }
  }

  /// 保存海报到相册
  static Future<SavePosterResult> savePosterToGallery(
      Uint8List imageBytes) async {
    try {
      // 使用 Gal 保存图片，会自动处理权限
      await Gal.putImageBytes(imageBytes);
      return SavePosterResult.success;
    } on GalException catch (e) {
      // 处理 Gal 特定异常
      if (e.type == GalExceptionType.accessDenied) {
        return SavePosterResult.accessDenied;
      }
      return SavePosterResult.failed;
    } catch (e) {
      return SavePosterResult.failed;
    }
  }

  /// 分享海报
  static Future<void> sharePoster(
    Uint8List imageBytes, {
    void Function(Object error)? onError,
    void Function(ShareResult result)? onResult,
    Rect? sharePositionOrigin,
  }) async {
    try {
      // 获取临时目录
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/beecount_share_${DateTime.now().millisecondsSinceEpoch}.png');

      // 写入文件
      await file.writeAsBytes(imageBytes);

      // 分享文件
      // Keep the original system-share invocation for existing callers.
      // ignore: deprecated_member_use
      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: resolveAppLocalizations(null).sharePosterAppText,
        sharePositionOrigin: sharePositionOrigin,
      );
      onResult?.call(result);
    } catch (e) {
      // Preserve the legacy silent default; new hosts may present an error.
      onError?.call(e);
    }
  }

  /// 生成年度总结海报（静态方法）
  static Future<Uint8List?> generateYearSummaryPoster(
    BuildContext context,
    WidgetRef ref, {
    required int ledgerId,
    required int year,
    required Color primaryColor,
    bool hideIncome = false,
  }) async {
    try {
      final repository = ref.read(repositoryProvider);
      final dataService = SharePosterDataService(repository);

      final data = await dataService.calculateYearSummary(
        ledgerId: ledgerId,
        year: year,
      );

      final currency =
          (await repository.getLedgerById(ledgerId))?.currency ?? 'CNY';
      if (!context.mounted) return null;
      return await _generatePosterFromWidgetStatic(
        context,
        YearSummaryPoster(
            data: data,
            primaryColor: primaryColor,
            hideIncome: hideIncome,
            currencyCode: currency),
      );
    } catch (e) {
      return null;
    }
  }

  /// 生成月度总结海报（静态方法）
  static Future<Uint8List?> generateMonthSummaryPoster(
    BuildContext context,
    WidgetRef ref, {
    required int ledgerId,
    required int year,
    required int month,
    required Color primaryColor,
    bool hideIncome = false,
  }) async {
    try {
      final repository = ref.read(repositoryProvider);
      final dataService = SharePosterDataService(repository);

      final data = await dataService.calculateMonthSummary(
        ledgerId: ledgerId,
        year: year,
        month: month,
      );

      final currency =
          (await repository.getLedgerById(ledgerId))?.currency ?? 'CNY';
      if (!context.mounted) return null;
      return await _generatePosterFromWidgetStatic(
        context,
        MonthSummaryPoster(
            data: data,
            primaryColor: primaryColor,
            hideIncome: hideIncome,
            currencyCode: currency),
      );
    } catch (e) {
      return null;
    }
  }

  /// 生成账本总结海报（静态方法）
  static Future<Uint8List?> generateLedgerSummaryPoster(
    BuildContext context,
    WidgetRef ref, {
    required int ledgerId,
    required Color primaryColor,
    bool hideIncome = false,
  }) async {
    try {
      final repository = ref.read(repositoryProvider);
      final dataService = SharePosterDataService(repository);

      final data = await dataService.calculateLedgerSummary(
        ledgerId: ledgerId,
      );

      final currency =
          (await repository.getLedgerById(ledgerId))?.currency ?? 'CNY';
      if (!context.mounted) return null;
      return await _generatePosterFromWidgetStatic(
        context,
        LedgerSummaryPoster(
            data: data,
            primaryColor: primaryColor,
            hideIncome: hideIncome,
            currencyCode: currency),
      );
    } catch (e) {
      return null;
    }
  }

  /// 从Widget生成海报图片（静态辅助方法）
  static Future<Uint8List?> _generatePosterFromWidgetStatic(
    BuildContext context,
    Widget posterWidget,
  ) async {
    try {
      final GlobalKey posterKey = GlobalKey();

      final widget = RepaintBoundary(
        key: posterKey,
        child: posterWidget,
      );

      final overlay = Overlay.of(context);
      late OverlayEntry overlayEntry;
      overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: -10000,
          top: -10000,
          child: Material(
            color: Colors.transparent,
            child: widget,
          ),
        ),
      );

      overlay.insert(overlayEntry);

      await Future.delayed(const Duration(milliseconds: 500));

      final boundary = posterKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        overlayEntry.remove();
        return null;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      overlayEntry.remove();

      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  /// 显示海报轮播预览对话框
  ///
  /// [year] 和 [month] 用于指定时间范围，默认为当前年月
  /// 如果不传参数，默认显示当前年月的海报
  static Future<void> showPosterCarouselPreview(
    BuildContext context, {
    int? year,
    int? month,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => ShareCardDialog(
        year: year,
        month: month,
      ),
    );
  }

  /// 显示海报预览对话框
  static Future<void> showPosterPreview(
      BuildContext context, Uint8List imageBytes) async {
    await showDialog(
      context: context,
      builder: (context) => ShareCardDialog(imageBytes: imageBytes),
    );
  }

  /// 显示可动态生成的海报预览对话框（支持隐藏收入）
  static Future<void> showDynamicPosterPreview(
    BuildContext context,
    WidgetRef ref, {
    required String type, // 'year', 'month', 'ledger'
    required int ledgerId,
    int? year,
    int? month,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => ShareCardDialog(
        type: type,
        ledgerId: ledgerId,
        year: year,
        month: month,
      ),
    );
  }
}
