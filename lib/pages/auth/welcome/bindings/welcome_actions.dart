part of '../../welcome_page.dart';

/// Original local initialization and restore services remain in the App.
mixin _WelcomeActions on ConsumerState<WelcomePage> {
  String get _selectedCurrency;
  set _selectedCurrency(String value);
  String get _categoryMode;
  set _categoryMode(String value);
  bool get _createDefaultLedger;
  set _createDefaultLedger(bool value);
  bool get _isInitializing;
  set _isInitializing(bool value);
  bool get _completed;
  set _completed(bool value);
  bool get _isImporting;
  set _isImporting(bool value);
  set _isExistingUserFlow(bool value);
  bool get _isImportingAttachment;
  set _isImportingAttachment(bool value);
  String? get _attachmentFilePath;
  set _attachmentFilePath(String? value);
  String? get _attachmentFileName;
  set _attachmentFileName(String? value);
  String? get _configFilePath;
  set _configFilePath(String? value);
  String? get _configFileName;
  set _configFileName(String? value);

  /// 打开GitHub链接
  Future<void> _launchGitHub(BuildContext context) async {
    final url = Uri.parse('https://github.com/TNT-Likely/BeeCount');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          showBeeToast(
              context, AppLocalizations.of(context).privacyOpenSourceUrlError);
        }
      }
    } catch (e) {
      if (context.mounted) {
        showBeeToast(
            context, AppLocalizations.of(context).privacyOpenSourceUrlError);
      }
    }
  }

  /// Seed rules are unchanged; a failed setup must remain retryable and must
  /// not leave a half-created default ledger behind.
  Future<void> _finishWelcome(BuildContext context) async {
    if (_isInitializing || _completed) return;
    setState(() => _isInitializing = true);
    final currency = _selectedCurrency;
    final mode = _categoryMode;
    final createLedger = _createDefaultLedger;
    final l = AppLocalizations.of(context);
    try {
      final db = ref.read(databaseProvider);
      await db.transaction(() => db.ensureSeed(
            l10n: l,
            currency: currency,
            useHierarchicalCategories: mode == 'hierarchical',
            skipCategories: mode == 'none',
            createDefaultLedger: createLedger,
          ));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('category_mode', mode);
      await prefs.setString('selected_currency', currency);
      await prefs.setString('baseCurrency', currency);
      ref.read(baseCurrencyProvider.notifier).state = currency.toUpperCase();
      await prefs.setBool('welcome_shown', true);
      if (!mounted) return;
      setState(() => _completed = true);
      ref.read(shouldShowWelcomeProvider.notifier).state = false;
    } catch (error, stack) {
      logger.error('welcome', '初始化失败', error, stack);
      if (context.mounted) showBeeToast(context, l.commonError);
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _chooseConfig(BuildContext context) =>
      _chooseBackup(context, attachment: false);
  Future<void> _chooseAttachment(BuildContext context) =>
      _chooseBackup(context, attachment: true);
  Future<void> _chooseBackup(BuildContext context,
      {required bool attachment}) async {
    if (_completed || _isImporting || _isImportingAttachment) return;
    try {
      final selected = attachment
          ? await FilePickerHelper.pickArchiveFile()
          : await FilePickerHelper.pickYamlFile();
      if (!mounted || selected == null || selected.files.isEmpty) return;
      final file = selected.files.single;
      if (file.path == null) return;
      setState(() {
        if (attachment) {
          _attachmentFilePath = file.path;
          _attachmentFileName = file.name;
        } else {
          _configFilePath = file.path;
          _configFileName = file.name;
        }
      });
    } catch (error, stack) {
      logger.error('welcome', '选择备份失败', error, stack);
      if (context.mounted) {
        showBeeToast(context,
            AppLocalizations.of(context).welcomeImportFailed(error.toString()));
      }
    }
  }

  /// 导入配置文件（老用户）
  Future<void> _importConfig(BuildContext context) async {
    if (_completed || _isImporting) return;
    final l10n = AppLocalizations.of(context);

    setState(() {
      _isImporting = true;
    });

    try {
      final filePath = _configFilePath;
      if (filePath == null) return;

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
        showBeeToast(context, l10n.welcomeImportSuccess);
        // 切换到老用户流程（附件导入页面）
        setState(() {
          _isExistingUserFlow = true;
        });
      }
    } catch (e, st) {
      logger.error('welcome', '导入配置文件失败', e, st);
      if (context.mounted) {
        showBeeToast(context, l10n.welcomeImportFailed(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  /// 完成老用户流程
  void _finishExistingUserFlow() {
    if (_completed) return;
    setState(() => _completed = true);
    ref.read(shouldShowWelcomeProvider.notifier).state = false;
  }

  /// 导入附件
  Future<void> _importAttachments(BuildContext context) async {
    if (_completed || _isImportingAttachment) return;
    final l10n = AppLocalizations.of(context);

    try {
      final filePath = _attachmentFilePath;
      if (filePath == null) return;

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
        showBeeToast(context,
            l10n.welcomeImportAttachmentSuccess(importResult.imported));
        // 导入成功，完成流程
        _finishExistingUserFlow();
      } else {
        showBeeToast(context,
            l10n.welcomeImportAttachmentFailed(importResult.message ?? ''));
      }
    } catch (e, st) {
      logger.error('welcome', '导入附件失败', e, st);
      if (context.mounted) {
        showBeeToast(context, l10n.welcomeImportAttachmentFailed(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImportingAttachment = false;
        });
      }
    }
  }
}
