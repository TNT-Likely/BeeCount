import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/ui/ui.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';
import '../../widgets/posters/app_promo_poster.dart';
import '../../widgets/posters/year_summary_poster.dart';
import '../../widgets/posters/month_summary_poster.dart';
import '../../widgets/posters/ledger_summary_poster.dart';
import '../../widgets/posters/user_profile_poster.dart';
import 'share_poster_types.dart';
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
  static Future<void> sharePoster(Uint8List imageBytes) async {
    try {
      // 获取临时目录
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/beecount_share_${DateTime.now().millisecondsSinceEpoch}.png');

      // 写入文件
      await file.writeAsBytes(imageBytes);

      // 分享文件
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'BeeCount - 蜜蜂记账',
      );
    } catch (e) {
      // 忽略错误
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

      return await _generatePosterFromWidgetStatic(
        context,
        YearSummaryPoster(
            data: data, primaryColor: primaryColor, hideIncome: hideIncome),
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

      return await _generatePosterFromWidgetStatic(
        context,
        MonthSummaryPoster(
            data: data, primaryColor: primaryColor, hideIncome: hideIncome),
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

      return await _generatePosterFromWidgetStatic(
        context,
        LedgerSummaryPoster(
            data: data, primaryColor: primaryColor, hideIncome: hideIncome),
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
      builder: (context) => _PosterCarouselPreviewDialog(
        year: year,
        month: month,
      ),
    );
  }

  /// 显示海报预览对话框
  static Future<void> showPosterPreview(
      BuildContext context, Uint8List imageBytes) async {
    final l10n = AppLocalizations.of(context);

    await showDialog(
      context: context,
      builder: (context) => _PosterPreviewDialog(
        imageBytes: imageBytes,
        l10n: l10n,
      ),
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
      builder: (context) => _DynamicPosterPreviewDialog(
        ref: ref,
        type: type,
        ledgerId: ledgerId,
        year: year,
        month: month,
      ),
    );
  }
}

/// 海报预览对话框
class _PosterPreviewDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final AppLocalizations l10n;

  const _PosterPreviewDialog({
    required this.imageBytes,
    required this.l10n,
  });

  @override
  State<_PosterPreviewDialog> createState() => _PosterPreviewDialogState();
}

class _PosterPreviewDialogState extends State<_PosterPreviewDialog> {
  bool _isSaving = false;

  Future<void> _savePoster() async {
    setState(() => _isSaving = true);

    final result =
        await SharePosterService.savePosterToGallery(widget.imageBytes);

    if (!mounted) return;

    setState(() => _isSaving = false);

    switch (result) {
      case SavePosterResult.success:
        showToast(context, widget.l10n.sharePosterSaveSuccess);
        Navigator.pop(context);
        break;
      case SavePosterResult.accessDenied:
        // 权限被拒绝
        showToast(context, widget.l10n.sharePosterPermissionDenied);
        break;
      case SavePosterResult.failed:
        // 保存失败
        showToast(context, widget.l10n.sharePosterSaveFailed);
        break;
    }
  }

  Future<void> _sharePoster() async {
    await SharePosterService.sharePoster(widget.imageBytes);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final primaryColor = ref.watch(primaryColorProvider);
        final isDark = BeeTokens.isDark(context);

        // 按钮背景色：暗黑模式用深灰卡片色，亮色模式用白色
        final secondaryButtonBg =
            isDark ? BeeTokens.surface(context) : Colors.white;
        final secondaryButtonFg =
            isDark ? BeeTokens.textPrimary(context) : primaryColor;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
          elevation: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 海报预览 - 占据大部分空间
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 600),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.memory(
                      widget.imageBytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 操作按钮
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _sharePoster,
                        icon: Icon(Icons.share_outlined,
                            color: secondaryButtonFg),
                        label: Text(widget.l10n.sharePosterShare),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: secondaryButtonFg,
                          backgroundColor: secondaryButtonBg,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isDark
                                ? BorderSide(color: BeeTokens.border(context))
                                : BorderSide.none,
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _savePoster,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Icon(Icons.download_outlined,
                                color: Colors.white),
                        label: Text(widget.l10n.sharePosterSave),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 海报轮播预览对话框
class _PosterCarouselPreviewDialog extends ConsumerStatefulWidget {
  final int? year;
  final int? month;

  const _PosterCarouselPreviewDialog({
    this.year,
    this.month,
  });

  @override
  ConsumerState<_PosterCarouselPreviewDialog> createState() =>
      _PosterCarouselPreviewDialogState();
}

class _PosterCarouselPreviewDialogState
    extends ConsumerState<_PosterCarouselPreviewDialog> {
  late PageController _pageController;
  int _currentPage = 0; // 默认从第一个海报开始

  // 海报类型列表（根据传入参数动态决定）
  late List<PosterType> _posterTypes;

  // 缓存已生成的海报
  final Map<int, Uint8List?> _posterCache = {};

  // 记录正在生成的海报索引
  final Set<int> _generating = {};

  bool _isSaving = false;
  bool _hideIncome = false; // 是否隐藏收入和结余

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

    // 根据传入参数决定海报类型
    if (widget.month != null) {
      // 传入了月份，显示月度报告
      _posterTypes = [PosterType.monthSummary];
    } else if (widget.year != null) {
      // 只传入年份，显示年度报告
      _posterTypes = [PosterType.yearSummary];
    } else {
      // 都没传入，显示用户档案和应用分享
      _posterTypes = [PosterType.userProfile, PosterType.appPromo];
    }

    // 打开时立即开始生成默认海报
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generatePosterAtIndex(_currentPage);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 生成指定索引的海报
  Future<void> _generatePosterAtIndex(int index) async {
    // 如果已经缓存或正在生成，则跳过
    if (_posterCache.containsKey(index) || _generating.contains(index)) {
      return;
    }

    // 标记为正在生成
    setState(() {
      _generating.add(index);
    });

    try {
      final posterType = _posterTypes[index];
      final primaryColor = ref.read(primaryColorProvider);

      Uint8List? imageBytes;

      switch (posterType) {
        case PosterType.yearSummary:
          imageBytes = await _generateYearSummary(primaryColor, _hideIncome);
          break;
        case PosterType.monthSummary:
          imageBytes = await _generateMonthSummary(primaryColor, _hideIncome);
          break;
        case PosterType.ledgerSummary:
          imageBytes = await _generateLedgerSummary(primaryColor, _hideIncome);
          break;
        case PosterType.appPromo:
          imageBytes =
              await SharePosterService.generatePoster(context, primaryColor);
          break;
        case PosterType.userProfile:
          imageBytes = await _generateUserProfile(primaryColor);
          break;
      }

      if (mounted) {
        setState(() {
          _posterCache[index] = imageBytes;
          _generating.remove(index);
        });

        // 如果生成失败，显示错误提示
        if (imageBytes == null) {
          final l10n = AppLocalizations.of(context);
          showToast(context, l10n.sharePosterGenerateFailed);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _generating.remove(index);
        });
        final l10n = AppLocalizations.of(context);
        showToast(context, l10n.sharePosterGenerateFailed);
      }
    }
  }

  /// 生成年度总结海报
  Future<Uint8List?> _generateYearSummary(
      Color primaryColor, bool hideIncome) async {
    final ledgerId = ref.read(currentLedgerIdProvider);
    if (ledgerId == 0) {
      final l10n = AppLocalizations.of(context);
      showToast(context, l10n.sharePosterNoLedger);
      return null;
    }

    final repository = ref.read(repositoryProvider);
    final dataService = SharePosterDataService(repository);

    // 使用传入的年份，如果没有传入则使用当前年份
    final now = DateTime.now();
    final targetYear = widget.year ?? now.year;

    final data = await dataService.calculateYearSummary(
      ledgerId: ledgerId,
      year: targetYear,
    );

    return await _generatePosterFromWidget(
      YearSummaryPoster(
          data: data, primaryColor: primaryColor, hideIncome: hideIncome),
    );
  }

  /// 生成月度总结海报
  Future<Uint8List?> _generateMonthSummary(
      Color primaryColor, bool hideIncome) async {
    final ledgerId = ref.read(currentLedgerIdProvider);
    if (ledgerId == 0) {
      final l10n = AppLocalizations.of(context);
      showToast(context, l10n.sharePosterNoLedger);
      return null;
    }

    final repository = ref.read(repositoryProvider);
    final dataService = SharePosterDataService(repository);

    // 使用传入的年月，如果没有传入则使用当前年月
    final now = DateTime.now();
    final targetYear = widget.year ?? now.year;
    final targetMonth = widget.month ?? now.month;

    final data = await dataService.calculateMonthSummary(
      ledgerId: ledgerId,
      year: targetYear,
      month: targetMonth,
    );

    return await _generatePosterFromWidget(
      MonthSummaryPoster(
          data: data, primaryColor: primaryColor, hideIncome: hideIncome),
    );
  }

  /// 生成账本总结海报
  Future<Uint8List?> _generateLedgerSummary(
      Color primaryColor, bool hideIncome) async {
    final ledgerId = ref.read(currentLedgerIdProvider);
    if (ledgerId == 0) {
      final l10n = AppLocalizations.of(context);
      showToast(context, l10n.sharePosterNoLedger);
      return null;
    }

    final repository = ref.read(repositoryProvider);
    final dataService = SharePosterDataService(repository);

    final data = await dataService.calculateLedgerSummary(
      ledgerId: ledgerId,
    );

    return await _generatePosterFromWidget(
      LedgerSummaryPoster(
          data: data, primaryColor: primaryColor, hideIncome: hideIncome),
    );
  }

  /// 生成用户档案海报
  Future<Uint8List?> _generateUserProfile(Color primaryColor) async {
    final ledgerId = ref.read(currentLedgerIdProvider);
    if (ledgerId == 0) {
      final l10n = AppLocalizations.of(context);
      showToast(context, l10n.sharePosterNoLedger);
      return null;
    }

    final repository = ref.read(repositoryProvider);
    final dataService = SharePosterDataService(repository);
    final l10n = AppLocalizations.of(context);

    final data = await dataService.calculateUserProfile(
      ledgerId: ledgerId,
    );

    return await _generatePosterFromWidget(
      UserProfilePoster(data: data, l10n: l10n, primaryColor: primaryColor),
    );
  }

  /// 从Widget生成海报图片
  Future<Uint8List?> _generatePosterFromWidget(Widget posterWidget) async {
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

  Future<void> _savePoster() async {
    final currentPoster = _posterCache[_currentPage];
    if (currentPoster == null) return;

    setState(() => _isSaving = true);

    final result = await SharePosterService.savePosterToGallery(currentPoster);

    if (!mounted) return;

    setState(() => _isSaving = false);

    final l10n = AppLocalizations.of(context);
    switch (result) {
      case SavePosterResult.success:
        showToast(context, l10n.sharePosterSaveSuccess);
        Navigator.pop(context);
        break;
      case SavePosterResult.accessDenied:
        showToast(context, l10n.sharePosterPermissionDenied);
        break;
      case SavePosterResult.failed:
        showToast(context, l10n.sharePosterSaveFailed);
        break;
    }
  }

  Future<void> _sharePoster() async {
    final currentPoster = _posterCache[_currentPage];
    if (currentPoster == null) return;

    await SharePosterService.sharePoster(currentPoster);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);
    final isDark = BeeTokens.isDark(context);

    final secondaryButtonBg =
        isDark ? BeeTokens.surface(context) : Colors.white;
    final secondaryButtonFg =
        isDark ? BeeTokens.textPrimary(context) : primaryColor;

    final cachedPoster = _posterCache[_currentPage];
    final isGenerating = _generating.contains(_currentPage);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 海报轮播预览
          Flexible(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                // 根据滑动速度判断方向
                if (details.primaryVelocity! > 0) {
                  // 向右滑动，显示上一张
                  if (_currentPage > 0) {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                } else if (details.primaryVelocity! < 0) {
                  // 向左滑动，显示下一张
                  if (_currentPage < _posterTypes.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                }
              },
              child: Container(
                constraints: const BoxConstraints(maxHeight: 600),
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // 禁用默认滑动
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                    // 切换页面时自动生成新海报
                    _generatePosterAtIndex(index);
                  },
                  itemCount: _posterTypes.length,
                  itemBuilder: (context, index) {
                    final poster = _posterCache[index];
                    final generating = _generating.contains(index);

                    return Center(
                      child: AspectRatio(
                        aspectRatio: 750 / 1334, // 海报的宽高比
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Stack(
                            children: [
                              // 海报内容
                              if (poster != null)
                                Image.memory(
                                  poster,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                )
                              else
                                Container(
                                  color: Colors.grey[100],
                                  child: Center(
                                    child: Icon(
                                      Icons.image_outlined,
                                      size: 80,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ),

                              // 生成中的加载指示器
                              if (generating)
                                Container(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 50,
                                          height: 50,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            valueColor: AlwaysStoppedAnimation(
                                                Colors.white),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        Text(
                                          l10n.sharePosterGenerating,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              // 隐藏收入按钮（只在年度/月度/账本总结海报显示）
                              if (_posterTypes[index] != PosterType.appPromo &&
                                  _posterTypes[index] !=
                                      PosterType.userProfile &&
                                  !generating)
                                Positioned(
                                  top: 16,
                                  right: 16,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () async {
                                        setState(() {
                                          _hideIncome = !_hideIncome;
                                          // 清除所有海报缓存以便重新生成
                                          _posterCache.clear();
                                        });
                                        // 重新生成当前海报
                                        await _generatePosterAtIndex(index);
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.5),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _hideIncome
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _hideIncome
                                                  ? l10n.sharePosterShowIncome
                                                  : l10n.sharePosterHideIncome,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 页面指示器
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _posterTypes.length,
              (index) {
                final isActive = _currentPage == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? primaryColor
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // 操作按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        (cachedPoster == null || isGenerating || _isSaving)
                            ? null
                            : _sharePoster,
                    icon: Icon(Icons.share_outlined, color: secondaryButtonFg),
                    label: Text(l10n.sharePosterShare),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: secondaryButtonFg,
                      backgroundColor: secondaryButtonBg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isDark
                            ? BorderSide(color: BeeTokens.border(context))
                            : BorderSide.none,
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        (cachedPoster == null || isGenerating || _isSaving)
                            ? null
                            : _savePoster,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.download_outlined,
                            color: Colors.white),
                    label: Text(l10n.sharePosterSave),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 动态海报预览对话框（支持隐藏收入）
class _DynamicPosterPreviewDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final String type; // 'year', 'month', 'ledger'
  final int ledgerId;
  final int? year;
  final int? month;

  const _DynamicPosterPreviewDialog({
    required this.ref,
    required this.type,
    required this.ledgerId,
    this.year,
    this.month,
  });

  @override
  ConsumerState<_DynamicPosterPreviewDialog> createState() =>
      _DynamicPosterPreviewDialogState();
}

class _DynamicPosterPreviewDialogState
    extends ConsumerState<_DynamicPosterPreviewDialog> {
  Uint8List? _posterImage;
  bool _isGenerating = false;
  bool _isSaving = false;
  bool _hideIncome = false;

  @override
  void initState() {
    super.initState();
    _generatePoster();
  }

  Future<void> _generatePoster() async {
    setState(() => _isGenerating = true);

    try {
      final primaryColor = ref.read(primaryColorProvider);
      Uint8List? imageBytes;

      switch (widget.type) {
        case 'year':
          imageBytes = await SharePosterService.generateYearSummaryPoster(
            context,
            widget.ref,
            ledgerId: widget.ledgerId,
            year: widget.year ?? DateTime.now().year,
            primaryColor: primaryColor,
            hideIncome: _hideIncome,
          );
          break;
        case 'month':
          imageBytes = await SharePosterService.generateMonthSummaryPoster(
            context,
            widget.ref,
            ledgerId: widget.ledgerId,
            year: widget.year ?? DateTime.now().year,
            month: widget.month ?? DateTime.now().month,
            primaryColor: primaryColor,
            hideIncome: _hideIncome,
          );
          break;
        case 'ledger':
          imageBytes = await SharePosterService.generateLedgerSummaryPoster(
            context,
            widget.ref,
            ledgerId: widget.ledgerId,
            primaryColor: primaryColor,
            hideIncome: _hideIncome,
          );
          break;
      }

      if (mounted) {
        setState(() {
          _posterImage = imageBytes;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        final l10n = AppLocalizations.of(context);
        showToast(context, l10n.sharePosterGenerateFailed);
      }
    }
  }

  Future<void> _toggleHideIncome() async {
    setState(() => _hideIncome = !_hideIncome);
    await _generatePoster();
  }

  Future<void> _savePoster() async {
    if (_posterImage == null) return;

    setState(() => _isSaving = true);

    final result = await SharePosterService.savePosterToGallery(_posterImage!);

    if (!mounted) return;

    setState(() => _isSaving = false);

    final l10n = AppLocalizations.of(context);
    switch (result) {
      case SavePosterResult.success:
        showToast(context, l10n.sharePosterSaveSuccess);
        Navigator.pop(context);
        break;
      case SavePosterResult.accessDenied:
        showToast(context, l10n.sharePosterPermissionDenied);
        break;
      case SavePosterResult.failed:
        showToast(context, l10n.sharePosterSaveFailed);
        break;
    }
  }

  Future<void> _sharePoster() async {
    if (_posterImage == null) return;
    await SharePosterService.sharePoster(_posterImage!);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);
    final isDark = BeeTokens.isDark(context);

    final secondaryButtonBg =
        isDark ? BeeTokens.surface(context) : Colors.white;
    final secondaryButtonFg =
        isDark ? BeeTokens.textPrimary(context) : primaryColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 海报预览
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 600),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    // 海报图片
                    if (_posterImage != null && !_isGenerating)
                      Image.memory(
                        _posterImage!,
                        fit: BoxFit.contain,
                      )
                    else
                      Container(
                        color: Colors.grey[100],
                        child: Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),

                    // 生成中的加载指示器
                    if (_isGenerating)
                      Container(
                        color: Colors.black.withValues(alpha: 0.3),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 50,
                                height: 50,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                l10n.sharePosterGenerating,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // 隐藏收入按钮
                    if (!_isGenerating)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _toggleHideIncome,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _hideIncome
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _hideIncome
                                        ? l10n.sharePosterShowIncome
                                        : l10n.sharePosterHideIncome,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 操作按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        (_posterImage == null || _isGenerating || _isSaving)
                            ? null
                            : _sharePoster,
                    icon: Icon(Icons.share_outlined, color: secondaryButtonFg),
                    label: Text(l10n.sharePosterShare),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: secondaryButtonFg,
                      backgroundColor: secondaryButtonBg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isDark
                            ? BorderSide(color: BeeTokens.border(context))
                            : BorderSide.none,
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        (_posterImage == null || _isGenerating || _isSaving)
                            ? null
                            : _savePoster,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.download_outlined,
                            color: Colors.white),
                    label: Text(l10n.sharePosterSave),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
