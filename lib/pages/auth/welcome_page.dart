import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import '../../widgets/currency/currency_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/biz/bee_icon.dart';
import 'dart:io';
import '../../l10n/app_localizations.dart';
import '../../utils/file_picker_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/ui_state_providers.dart';
import '../../providers/language_provider.dart';
import '../../providers/database_providers.dart';
import '../../providers/theme_providers.dart';
import '../../providers/font_scale_provider.dart';
import '../../providers/currency_providers.dart';
import '../../services/system/logger_service.dart';
import '../../services/export/config_export_service.dart';
import '../../services/attachment_export_import_service.dart';
import '../../utils/currencies.dart';
import '../../widgets/ui/ui.dart';

/// 首次启动欢迎页面
/// 展示应用的独特价值：隐私保护、开源透明、数据自主
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String _selectedCurrency = 'CNY'; // 默认货币
  bool _createDefaultLedger = true; // 是否创建默认账本(币种页复选框)
  // 分类模式: 'flat' = 一级分类, 'hierarchical' = 二级分类, 'none' = 不创建分类
  String _categoryMode = 'flat'; // 默认使用一级分类
  bool _isInitializing = false; // 初始化状态
  bool _isImporting = false; // 导入状态
  bool _isExistingUserFlow = false; // 老用户流程
  bool _isImportingAttachment = false; // 附件导入状态

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final pages = _isExistingUserFlow
        ? [_buildAttachmentImportPage(context, theme, l10n)]
        : [
            _buildWelcomePage(context, theme, l10n),
            _buildCurrencyPage(context, theme, l10n),
            _buildCategoryModePage(context, theme, l10n),
            _buildCloudSyncPage(context, theme, l10n),
            _buildPrivacyAndOpenSourcePage(context, theme, l10n)
          ];
    return Scaffold(
        backgroundColor: BeeCardTheme.of(context).canvas,
        body: SafeArea(
            child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
              child: Row(children: [
                BeeIcon(color: theme.colorScheme.primary, size: 26),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(l10n.appTitle,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                Text('${_currentPage + 1} / ${pages.length}',
                    style: TextStyle(fontSize: 11, color: theme.hintColor))
              ])),
          Expanded(
              child: PageView(
                  controller: _pageController,
                  physics: _isExistingUserFlow
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  onPageChanged: (v) => setState(() => _currentPage = v),
                  children: pages)),
          if (!_isExistingUserFlow)
            Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Row(children: [
                  if (_currentPage > 0) ...[
                    BeeButton(
                        label: l10n.commonPrevious,
                        kind: BeeButtonKind.secondary,
                        onPressed: _isInitializing
                            ? null
                            : () => _pageController.previousPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut)),
                    const SizedBox(width: 10)
                  ],
                  Expanded(
                      child: BeeButton(
                          label: _currentPage < 4
                              ? l10n.commonNext
                              : l10n.commonFinish,
                          loading: _isInitializing,
                          onPressed: _isInitializing
                              ? null
                              : () {
                                  if (_currentPage < 4) {
                                    _pageController.nextPage(
                                        duration:
                                            const Duration(milliseconds: 250),
                                        curve: Curves.easeInOut);
                                  } else {
                                    _finishWelcome(context);
                                  }
                                })),
                ])),
        ])));
  }

  Widget _step(
          {required String title,
          required String description,
          required Widget options,
          required int step}) =>
      LayoutBuilder(
          builder: (context, bounds) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: BeeOnboardingStep(
                          step: step,
                          total: _isExistingUserFlow ? 1 : 5,
                          title: title,
                          description: description,
                          illustration: BeeBrandMark(
                              size: 56,
                              corner: 19,
                              mark: BeeIcon(
                                  size: 34,
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                          options: options,
                          next: const SizedBox.shrink(),
                          restore: const SizedBox.shrink())))));

  /// 第1页：欢迎
  Widget _buildWelcomePage(
      BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final notifier = ref.read(languageProvider.notifier);
    final current = ref.watch(languageProvider);
    const locales = [
      null,
      Locale('zh'),
      Locale('zh', 'TW'),
      Locale('en'),
      Locale('ko')
    ];
    return _step(
        step: 0,
        title: l10n.welcomeTitle,
        description: l10n.welcomeDescription,
        options:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BeeSurface(
              padding: const EdgeInsets.all(6),
              child: Column(
                  children: locales
                      .map((locale) => BeeMenuRow(
                          title:
                              notifier.getLanguageDisplayName(context, locale),
                          selected: current == locale,
                          onTap: () => notifier.setLanguage(locale)))
                      .toList())),
          const SizedBox(height: 12),
          BeeButton(
              label: _isImporting
                  ? l10n.welcomeImportingConfig
                  : '${l10n.welcomeExistingUserTitle} ${l10n.welcomeExistingUserButton}',
              kind: BeeButtonKind.quiet,
              loading: _isImporting,
              onPressed: _isImporting ? null : () => _importConfig(context)),
        ]));
  }

  /// 第2页：货币选择
  Widget _buildCurrencyPage(
      BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final codes = {'CNY', 'USD', 'EUR', 'HKD', 'JPY', 'KRW', _selectedCurrency};
    final currencies =
        getCurrencies(context).where((c) => codes.contains(c.code)).toList();
    return _step(
        step: 1,
        title: l10n.ledgersCurrency,
        description: l10n.welcomeCurrencyDescription,
        options:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BeeSurface(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.5,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 8,
                    children: currencies
                        .map((currency) => BeeChoiceChip(
                            label: '${currency.name} ${currency.code}',
                            selected: _selectedCurrency == currency.code,
                            leading: Text(getCurrencySymbol(currency.code)),
                            onSelected: (_) => setState(
                                () => _selectedCurrency = currency.code)))
                        .toList()),
                BeeMenuRow(
                    title: l10n.ledgersSelectCurrency,
                    leading: const BeeLineIcon('Globe', size: 18),
                    onTap: () async {
                      final currency = await showCurrencyPickerSheet(context,
                          selected: _selectedCurrency,
                          primaryColor: theme.colorScheme.primary);
                      if (currency != null && mounted) {
                        setState(() => _selectedCurrency = currency);
                      }
                    }),
              ])),
          const SizedBox(height: 12),
          BeeSurface(
              padding: const EdgeInsets.all(6),
              child: CheckboxListTile(
                  title: Text(l10n.welcomeCreateDefaultLedger,
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text(_selectedCurrency,
                      style: const TextStyle(fontSize: 11)),
                  value: _createDefaultLedger,
                  onChanged: (v) =>
                      setState(() => _createDefaultLedger = v ?? false))),
        ]));
  }

  /// 第5页：开源透明与社群驱动
  Widget _buildPrivacyAndOpenSourcePage(
          BuildContext context, ThemeData theme, AppLocalizations l10n) =>
      _step(
          step: 4,
          title: l10n.welcomePrivacyTitle,
          description: l10n.welcomeDescription,
          options: BeeSurface(
              padding: const EdgeInsets.all(10),
              child: Column(children: [
                BeeMenuRow(
                    title: l10n.welcomePrivacyFeature1,
                    leading: const BeeLineIcon('Code', size: 21)),
                BeeMenuRow(
                    title: l10n.welcomePrivacyFeature2,
                    leading: const BeeLineIcon('ShieldCheck', size: 21)),
                BeeMenuRow(
                    title: l10n.welcomeOpenSourceFeature1,
                    leading: const BeeLineIcon('Users', size: 21)),
                BeeMenuRow(
                    title: l10n.welcomeViewGitHub,
                    leading: const BeeLineIcon('ExternalLink', size: 21),
                    onTap: () => _launchGitHub(context)),
              ])));

  /// 第4页：云同步说明
  Widget _buildCloudSyncPage(
          BuildContext context, ThemeData theme, AppLocalizations l10n) =>
      _step(
          step: 3,
          title: l10n.welcomeCloudSyncTitle,
          description: l10n.welcomeCloudSyncDescription,
          options: BeeSurface(
              padding: const EdgeInsets.all(10),
              child: Column(children: [
                BeeMenuRow(
                    title: l10n.welcomeCloudSyncFeature1,
                    leading: const BeeLineIcon('HardDrive', size: 21)),
                BeeMenuRow(
                    title: l10n.welcomeCloudSyncFeature2,
                    leading: const BeeLineIcon('Database', size: 21)),
                BeeMenuRow(
                    title: l10n.welcomeCloudSyncFeature3,
                    leading: const BeeLineIcon('Cloud', size: 21)),
              ])));

  /// 打开GitHub链接
  Future<void> _launchGitHub(BuildContext context) async {
    final url = Uri.parse('https://github.com/TNT-Likely/BeeCount');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          showToast(
              context, AppLocalizations.of(context).privacyOpenSourceUrlError);
        }
      }
    } catch (e) {
      if (context.mounted) {
        showToast(
            context, AppLocalizations.of(context).privacyOpenSourceUrlError);
      }
    }
  }

  /// 完成欢迎页面
  Future<void> _finishWelcome(BuildContext context) async {
    // 设置初始化状态
    setState(() {
      _isInitializing = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('welcome_shown', true);
      // 保存用户选择的分类模式
      await prefs.setString('category_mode', _categoryMode);
      // 保存用户选择的货币
      await prefs.setString('selected_currency', _selectedCurrency);
      // 多币种 MVP:主币种随初始化选币一并落定,新装用户开箱即正确
      await prefs.setString('baseCurrency', _selectedCurrency);
      // 同步 provider:splash init 已先行兜底 CNY,这里用用户所选币种即时纠正(首会话即正确)
      ref.read(baseCurrencyProvider.notifier).state =
          _selectedCurrency.toUpperCase();

      // 初始化数据库（使用用户选择的语言和设置）
      if (context.mounted) {
        logger.info('welcome', '开始初始化数据库');
        logger.info('welcome', '货币: $_selectedCurrency');
        final categoryModeText = _categoryMode == 'hierarchical'
            ? '二级分类'
            : _categoryMode == 'flat'
                ? '一级分类'
                : '不创建分类';
        logger.info('welcome', '分类模式: $categoryModeText');

        final l10n = AppLocalizations.of(context);
        final db = ref.read(databaseProvider);

        // 根据用户选择创建分类
        // 注意: 使用 databaseProvider 直接访问数据库，因为 ensureSeed 是数据库初始化方法
        if (_categoryMode != 'none') {
          await db.ensureSeed(
            l10n: l10n,
            currency: _selectedCurrency,
            useHierarchicalCategories: _categoryMode == 'hierarchical',
            createDefaultLedger: _createDefaultLedger,
          );
        } else {
          // 只创建默认账本，不创建分类
          await db.ensureSeed(
            l10n: l10n,
            currency: _selectedCurrency,
            skipCategories: true,
            createDefaultLedger: _createDefaultLedger,
          );
        }

        logger.info('welcome', '数据库初始化完成');
      }

      if (context.mounted) {
        // 首次启动的情况，标记欢迎页面已完成，触发重新构建
        // 这将显示启屏页面（如果初始化未完成）或主应用（如果已完成）
        ref.read(shouldShowWelcomeProvider.notifier).state = false;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  /// 导入配置文件（老用户）
  Future<void> _importConfig(BuildContext context) async {
    final l10n = AppLocalizations.of(context);

    setState(() {
      _isImporting = true;
    });

    try {
      // 选择文件（使用 FilePickerHelper 处理部分设备不支持扩展名过滤的问题）
      final result = await FilePickerHelper.pickYamlFile();

      if (result == null || result.files.isEmpty) {
        if (context.mounted) {
          showToast(context, l10n.welcomeImportNoFile);
        }
        return;
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        if (context.mounted) {
          showToast(context, l10n.welcomeImportNoFile);
        }
        return;
      }

      // 读取文件内容
      final file = File(filePath);
      final yamlContent = await file.readAsString();

      logger.info('welcome', '开始导入配置文件');

      // 不再调 ensureSeed:删了"配置无账本时自动创建默认账本"后 db 变量没用了。
      final repo = ref.read(repositoryProvider);

      // 导入配置
      await ConfigExportService.importFromYaml(
        yamlContent,
        repository: repo,
      );

      logger.info('welcome', '配置文件导入成功');

      // 不再自动创建默认账本 — 即使配置不含账本也尊重用户意图(可能就是想从
      // 空状态开始)。没账本时进入应用,LedgersPage 空态会引导新建。
      final ledgers = await repo.getAllLedgers();
      logger.info('welcome', '配置包含 ${ledgers.length} 个账本');

      // 标记欢迎页面已完成
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('welcome_shown', true);

      // 刷新所有配置相关的 providers，使导入的配置立即生效
      ref.invalidate(primaryColorInitProvider);
      ref.invalidate(themeModeInitProvider);
      ref.invalidate(compactAmountInitProvider);
      ref.invalidate(skinAnimationInitProvider);
      ref.invalidate(showTransactionTimeInitProvider);
      ref.invalidate(noteDisplayModeInitProvider);
      ref.invalidate(fontScaleInitProvider);
      ref.invalidate(languageProvider);

      if (context.mounted) {
        showToast(context, l10n.welcomeImportSuccess);
        // 切换到老用户流程（附件导入页面）
        setState(() {
          _isExistingUserFlow = true;
          _currentPage = 0;
        });
      }
    } catch (e, st) {
      logger.error('welcome', '导入配置文件失败', e, st);
      if (context.mounted) {
        showToast(context, l10n.welcomeImportFailed(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  /// 附件导入页面（老用户流程）
  Widget _buildAttachmentImportPage(
          BuildContext context, ThemeData theme, AppLocalizations l10n) =>
      _step(
          step: 0,
          title: l10n.welcomeImportAttachmentTitle,
          description: l10n.welcomeImportAttachmentDesc,
          options: BeeSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const Icon(Icons.photo_library_outlined, size: 38),
                const SizedBox(height: 18),
                BeeButton(
                    label: _isImportingAttachment
                        ? l10n.welcomeImportingAttachment
                        : l10n.welcomeImportAttachmentButton,
                    loading: _isImportingAttachment,
                    onPressed: _isImportingAttachment
                        ? null
                        : () => _importAttachments(context)),
                const SizedBox(height: 10),
                BeeButton(
                    label: l10n.welcomeImportAttachmentSkip,
                    kind: BeeButtonKind.quiet,
                    onPressed: _isImportingAttachment
                        ? null
                        : _finishExistingUserFlow),
              ])));

  /// 完成老用户流程
  void _finishExistingUserFlow() {
    ref.read(shouldShowWelcomeProvider.notifier).state = false;
  }

  /// 导入附件
  Future<void> _importAttachments(BuildContext context) async {
    final l10n = AppLocalizations.of(context);

    try {
      // 选择附件归档文件（使用 FilePickerHelper 处理部分设备不支持扩展名过滤的问题）
      final result = await FilePickerHelper.pickArchiveFile();

      if (result == null || result.files.isEmpty) {
        return;
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        return;
      }

      if (!context.mounted) return;

      // 显示加载状态
      setState(() {
        _isImportingAttachment = true;
      });

      // 执行导入
      final importService = ref.read(attachmentExportImportServiceProvider);
      final importResult = await importService.importAttachments(
        archivePath: filePath,
        conflictStrategy: AttachmentExportImportService.conflictSkip,
      );

      if (!context.mounted) return;

      if (importResult.success) {
        showToast(context,
            l10n.welcomeImportAttachmentSuccess(importResult.imported));
        // 导入成功，完成流程
        _finishExistingUserFlow();
      } else {
        showToast(context,
            l10n.welcomeImportAttachmentFailed(importResult.message ?? ''));
      }
    } catch (e, st) {
      logger.error('welcome', '导入附件失败', e, st);
      if (context.mounted) {
        showToast(context, l10n.welcomeImportAttachmentFailed(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImportingAttachment = false;
        });
      }
    }
  }

  /// 第5页：分类模式选择
  Widget _buildCategoryModePage(
          BuildContext context, ThemeData theme, AppLocalizations l10n) =>
      _step(
          step: 2,
          title: l10n.welcomeCategoryModeTitle,
          description: l10n.welcomeCategoryModeDescription,
          options: Column(children: [
            _buildCategoryModeOption(context, theme, l10n,
                mode: 'flat',
                title: l10n.welcomeCategoryModeFlatTitle,
                description: l10n.welcomeCategoryModeFlatDescription,
                features: [
                  l10n.welcomeCategoryModeFlatFeature1,
                  l10n.welcomeCategoryModeFlatFeature2,
                  l10n.welcomeCategoryModeFlatFeature3
                ]),
            const SizedBox(height: 10),
            _buildCategoryModeOption(context, theme, l10n,
                mode: 'hierarchical',
                title: l10n.welcomeCategoryModeHierarchicalTitle,
                description: l10n.welcomeCategoryModeHierarchicalDescription,
                features: [
                  l10n.welcomeCategoryModeHierarchicalFeature1,
                  l10n.welcomeCategoryModeHierarchicalFeature2,
                  l10n.welcomeCategoryModeHierarchicalFeature3
                ]),
            const SizedBox(height: 10),
            _buildCategoryModeOption(context, theme, l10n,
                mode: 'none',
                title: l10n.welcomeCategoryModeNoneTitle,
                description: l10n.welcomeCategoryModeNoneDescription,
                features: [
                  l10n.welcomeCategoryModeNoneFeature1,
                  l10n.welcomeCategoryModeNoneFeature2,
                  l10n.welcomeCategoryModeNoneFeature3
                ]),
          ]));

  Widget _buildCategoryModeOption(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n, {
    required String mode,
    required String title,
    required String description,
    required List<String> features,
  }) =>
      BeeSurface(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            BeeMenuRow(
                title: title,
                subtitle: description,
                leading: BeeLineIcon(
                    mode == 'hierarchical'
                        ? 'Network'
                        : mode == 'none'
                            ? 'Plus'
                            : 'Grid2X2',
                    size: 20),
                selected: _categoryMode == mode,
                onTap: () => setState(() => _categoryMode = mode)),
            Padding(
                padding: const EdgeInsets.only(left: 12, right: 8, bottom: 8),
                child: Text(features.join(' · '),
                    style: TextStyle(fontSize: 11, color: theme.hintColor))),
          ]));
}
