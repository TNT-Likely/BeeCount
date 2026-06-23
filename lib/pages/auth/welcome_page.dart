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

    // 老用户流程：只有1页（附件导入）
    final existingUserPages = [
      _buildAttachmentImportPage(context, theme, l10n),
    ];

    // 新用户流程：5页
    final newUserPages = [
      _buildWelcomePage(context, theme, l10n), // 第1屏：语言选择
      _buildCurrencyPage(context, theme, l10n), // 第2屏：货币选择
      _buildCategoryModePage(context, theme, l10n), // 第3屏：分类模式
      _buildCloudSyncPage(context, theme, l10n), // 第4屏：云同步
      _buildPrivacyAndOpenSourcePage(context, theme, l10n), // 第5屏：隐私保护+开源透明
    ];

    final pages = _isExistingUserFlow ? existingUserPages : newUserPages;
    final pageCount = pages.length;

    return Scaffold(
      backgroundColor: theme.primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            // 页面指示器
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  pageCount,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // 页面内容
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: _isExistingUserFlow ? const NeverScrollableScrollPhysics() : null,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: pages,
              ),
            ),

            // 底部按钮（老用户流程不显示，由页面内自带按钮处理）
            if (!_isExistingUserFlow)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      TextButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: Text(l10n.commonPrevious),
                      ),
                    const Spacer(),
                    if (_currentPage < 4)
                      FilledButton(
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: theme.primaryColor,
                        ),
                        child: Text(l10n.commonNext),
                      )
                    else
                      FilledButton(
                        onPressed: _isInitializing ? null : () => _finishWelcome(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: theme.primaryColor,
                        ),
                        child: _isInitializing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.commonFinish),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 第1页：欢迎
  Widget _buildWelcomePage(
      BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final languageNotifier = ref.read(languageProvider.notifier);
    final currentLocale = ref.watch(languageProvider);

    // 可选语言列表
    final availableLocales = [
      null, // 跟随系统
      const Locale('zh'),
      const Locale('zh', 'TW'),
      const Locale('en'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 应用图标
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              // 用主题色填充 SVG 的 currentColor(肚子/翅膀等),传 Colors.white
              // 会让整个蜜蜂变成纯白与背景圆几乎融为一体。
              child: BeeIcon(
                color: theme.colorScheme.primary,
                size: 72,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // 欢迎标题
          Text(
            l10n.welcomeTitle,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // 欢迎描述
          Text(
            l10n.welcomeDescription,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 48),

          // 语言选择
          Text(
            l10n.commonLanguage,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // 语言选择列表
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: availableLocales.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              itemBuilder: (context, index) {
                final locale = availableLocales[index];
                final isSelected = currentLocale == locale;
                final displayName = languageNotifier.getLanguageDisplayName(context, locale);

                return InkWell(
                  onTap: () {
                    languageNotifier.setLanguage(locale);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 老用户导入配置（紧凑样式）
          const SizedBox(height: 24),
          TextButton(
            onPressed: _isImporting ? null : () => _importConfig(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isImporting)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                else
                  Icon(
                    Icons.file_upload_outlined,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                const SizedBox(width: 6),
                Text(
                  _isImporting
                      ? l10n.welcomeImportingConfig
                      : '${l10n.welcomeExistingUserTitle} ${l10n.welcomeExistingUserButton}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 第2页：货币选择
  Widget _buildCurrencyPage(
      BuildContext context, ThemeData theme, AppLocalizations l10n) {
    // 从工具类获取货币列表
    final currencies = getCurrencies(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // 货币图标
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.attach_money,
              size: 64,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),

          // 标题
          Text(
            l10n.ledgersCurrency,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // 描述
          Text(
            l10n.welcomeCurrencyDescription,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // 货币选择列表占满"上方文字 + 底部复选框"之外的剩余空间。Expanded
          // + Column 不指定 mainAxisAlignment,让 ListView 内部自己滚动。
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                itemCount: currencies.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                itemBuilder: (context, index) {
                  final currency = currencies[index];
                  final isSelected = _selectedCurrency == currency.code;
                  final symbol = getCurrencySymbol(currency.code);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCurrency = currency.code;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          // 选中标记
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 12),

                          // 货币符号
                          SizedBox(
                            width: 40,
                            child: Text(
                              symbol,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 货币名称
                          Expanded(
                            child: Text(
                              '${currency.name} (${currency.code})',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 创建默认账本复选框
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _createDefaultLedger = !_createDefaultLedger;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      _createDefaultLedger
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.welcomeCreateDefaultLedger,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 第5页：开源透明与社群驱动
  Widget _buildPrivacyAndOpenSourcePage(
      BuildContext context, ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 开源与社群图标
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_outline,
              size: 64,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),

          // 标题
          Text(
            l10n.welcomePrivacyTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // 特性列表
          Center(
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 开源代码
                  _buildFeatureItem(
                    context,
                    Icons.code_outlined,
                    Colors.white,
                    l10n.welcomePrivacyFeature1,
                  ),
                  const SizedBox(height: 12),
                  // 隐私保护
                  _buildFeatureItem(
                    context,
                    Icons.shield_outlined,
                    Colors.white,
                    l10n.welcomePrivacyFeature2,
                  ),
                  const SizedBox(height: 12),
                  // 社群驱动
                  _buildFeatureItem(
                    context,
                    Icons.groups_outlined,
                    Colors.white,
                    l10n.welcomeOpenSourceFeature1,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // GitHub链接按钮
          OutlinedButton.icon(
            onPressed: () => _launchGitHub(context),
            icon: const Icon(Icons.open_in_new, size: 18, color: Colors.white),
            label: Text(l10n.welcomeViewGitHub,
                style: const TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 第4页：云同步说明
  Widget _buildCloudSyncPage(
      BuildContext context, ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 云同步图标
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_outlined,
              size: 64,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),

          // 标题
          Text(
            l10n.welcomeCloudSyncTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // 描述
          Text(
            l10n.welcomeCloudSyncDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // 特性列表
          Center(
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFeatureItem(
                    context,
                    Icons.offline_bolt_outlined,
                    Colors.white,
                    l10n.welcomeCloudSyncFeature1,
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    context,
                    Icons.dns_outlined,
                    Colors.white,
                    l10n.welcomeCloudSyncFeature2,
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    context,
                    Icons.cloud_upload_outlined,
                    Colors.white,
                    l10n.welcomeCloudSyncFeature3,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建特性条目
  Widget _buildFeatureItem(
    BuildContext context,
    IconData icon,
    Color color,
    String text,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: color,
                ),
          ),
        ),
      ],
    );
  }

  /// 打开GitHub链接
  Future<void> _launchGitHub(BuildContext context) async {
    final url = Uri.parse('https://github.com/TNT-Likely/BeeCount');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          showToast(context, AppLocalizations.of(context).privacyOpenSourceUrlError);
        }
      }
    } catch (e) {
      if (context.mounted) {
        showToast(context, AppLocalizations.of(context).privacyOpenSourceUrlError);
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
      ref.read(baseCurrencyProvider.notifier).state = _selectedCurrency.toUpperCase();

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
      BuildContext context, ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 图标
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.image_outlined,
              size: 64,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),

          // 标题
          Text(
            l10n.welcomeImportAttachmentTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // 描述
          Text(
            l10n.welcomeImportAttachmentDesc,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // 导入按钮
          FilledButton.icon(
            onPressed: _isImportingAttachment ? null : () => _importAttachments(context),
            icon: _isImportingAttachment
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.file_upload_outlined),
            label: Text(
              _isImportingAttachment
                  ? l10n.welcomeImportingAttachment
                  : l10n.welcomeImportAttachmentButton,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: theme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),

          // 跳过按钮
          TextButton(
            onPressed: _isImportingAttachment ? null : _finishExistingUserFlow,
            child: Text(
              l10n.welcomeImportAttachmentSkip,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                decoration: TextDecoration.underline,
                decorationColor: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
        showToast(context, l10n.welcomeImportAttachmentSuccess(importResult.imported));
        // 导入成功，完成流程
        _finishExistingUserFlow();
      } else {
        showToast(context, l10n.welcomeImportAttachmentFailed(importResult.message ?? ''));
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
      BuildContext context, ThemeData theme, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 图标
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.category_outlined,
              size: 64,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),

          // 标题
          Text(
            l10n.welcomeCategoryModeTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // 描述
          Text(
            l10n.welcomeCategoryModeDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // 一级分类选项
          _buildCategoryModeOption(
            context,
            theme,
            l10n,
            mode: 'flat',
            title: l10n.welcomeCategoryModeFlatTitle,
            description: l10n.welcomeCategoryModeFlatDescription,
            features: [
              l10n.welcomeCategoryModeFlatFeature1,
              l10n.welcomeCategoryModeFlatFeature2,
              l10n.welcomeCategoryModeFlatFeature3,
            ],
          ),

          const SizedBox(height: 16),

          // 二级分类选项
          _buildCategoryModeOption(
            context,
            theme,
            l10n,
            mode: 'hierarchical',
            title: l10n.welcomeCategoryModeHierarchicalTitle,
            description: l10n.welcomeCategoryModeHierarchicalDescription,
            features: [
              l10n.welcomeCategoryModeHierarchicalFeature1,
              l10n.welcomeCategoryModeHierarchicalFeature2,
              l10n.welcomeCategoryModeHierarchicalFeature3,
            ],
          ),

          const SizedBox(height: 16),

          // 不创建分类选项
          _buildCategoryModeOption(
            context,
            theme,
            l10n,
            mode: 'none',
            title: l10n.welcomeCategoryModeNoneTitle,
            description: l10n.welcomeCategoryModeNoneDescription,
            features: [
              l10n.welcomeCategoryModeNoneFeature1,
              l10n.welcomeCategoryModeNoneFeature2,
              l10n.welcomeCategoryModeNoneFeature3,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryModeOption(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n, {
    required String mode, // 'flat', 'hierarchical', or 'none'
    required String title,
    required String description,
    required List<String> features,
  }) {
    final isSelected = _categoryMode == mode;

    return InkWell(
      onTap: () {
        setState(() {
          _categoryMode = mode;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
