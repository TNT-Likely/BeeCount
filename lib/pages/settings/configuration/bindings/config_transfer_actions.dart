part of '../../config_import_export_page.dart';

mixin _ConfigTransferActions on ConsumerState<ConfigImportExportPage> {
  bool _isExporting = false;
  bool _isImporting = false;
  String? _lastExportedFilePath;

  /// 获取配置导出目录
  Future<Directory> _getExportDirectory() async {
    if (Platform.isAndroid) {
      // Android: 保存到公共 Download/BeeCount 目录
      final downloadPath = '/storage/emulated/0/Download/BeeCount';
      final dir = Directory(downloadPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } else {
      // iOS: 使用分享功能
      return await getTemporaryDirectory();
    }
  }

  Future<void> _exportConfig() async {
    // Step 1: 显示选择导出内容对话框
    final options = await showDialog<ExportOptions>(
      context: context,
      builder: (context) => _ExportOptionsDialog(ref: ref),
    );

    if (options == null || !mounted) return;

    setState(() {
      _isExporting = true;
      _lastExportedFilePath = null;
    });

    try {
      // 获取仓库和当前账本ID
      final repo = ref.read(repositoryProvider);
      final ledgerId = ref.read(currentLedgerIdProvider);

      // Step 2: 生成预览内容
      final yamlContent = await ConfigExportService.exportToYaml(
        repository: repo,
        ledgerId: ledgerId,
        options: options,
      );

      if (!mounted) return;

      // Step 3: 显示预览并确认导出
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => _ExportPreviewDialog(yamlContent: yamlContent),
      );

      if (confirm != true || !mounted) {
        return;
      }

      // Step 4: 执行导出
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'beecount_config_$timestamp.yml';

      if (Platform.isAndroid) {
        // Android: 直接保存到 Download/BeeCount 目录
        final exportDir = await _getExportDirectory();
        final filePath = '${exportDir.path}/$fileName';

        final file = File(filePath);
        await file.writeAsString(yamlContent);

        logger.info('ConfigExport', '配置已导出到: $filePath');

        if (!mounted) return;

        setState(() {
          _lastExportedFilePath = filePath;
        });

        showBeeToast(context, AppLocalizations.of(context).configExportSuccess);
      } else {
        // iOS: 使用分享功能
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';

        final file = File(filePath);
        await file.writeAsString(yamlContent);

        if (!mounted) return;

        final result = await SharePlus.instance.share(ShareParams(
            files: [XFile(filePath)],
            subject: AppLocalizations.of(context).configExportShareSubject));

        if (result.status == ShareResultStatus.success) {
          if (!mounted) return;
          showBeeToast(context, AppLocalizations.of(context).configExportSuccess);
        }
      }
    } catch (e) {
      logger.error('ConfigExport', '导出配置失败: $e');
      if (!mounted) return;
      await _showConfigMessage(
        title: AppLocalizations.of(context).configExportFailed,
        message: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  /// 查看配置文件内容
  Future<void> _viewExportedContent() async {
    if (_lastExportedFilePath == null) return;

    try {
      final file = File(_lastExportedFilePath!);
      final content = await file.readAsString();

      if (!mounted) return;
      final dialogContext = context;
      final l10n = AppLocalizations.of(context);

      if (!dialogContext.mounted) return;
      await showDialog(
        context: dialogContext,
        builder: (context) => _ConfigContentDialog(
          content: content,
          onCopy: () async {
            await Clipboard.setData(ClipboardData(text: content));
            if (!context.mounted || !dialogContext.mounted) return;
            Navigator.pop(context);
            showBeeToast(dialogContext, l10n.configExportContentCopied);
          },
        ),
      );
    } catch (e) {
      logger.error('ConfigExport', '读取配置文件失败: $e');
      if (!mounted) return;
      showBeeToast(
          context, AppLocalizations.of(context).configExportReadFileFailed);
    }
  }

  Future<void> _importConfig() async {
    setState(() => _isImporting = true);

    try {
      // Step 1: 选择文件（使用 FilePickerHelper 处理部分设备不支持扩展名过滤的问题）
      final result = await FilePickerHelper.pickYamlFile();

      if (result == null || result.files.isEmpty) {
        if (mounted) {
          setState(() => _isImporting = false);
        }
        return;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        if (!mounted) return;
        throw Exception(AppLocalizations.of(context).configImportNoFilePath);
      }

      // Step 2: 读取文件并检测可用内容
      if (!mounted) return;
      final file = File(filePath);
      final yamlContent = await file.readAsString();

      // 检测文件中包含哪些配置项
      final contentInfo = ConfigExportService.detectContent(yamlContent);

      // Step 3: 显示预览并选择导入内容的对话框
      if (!mounted) return;
      final options = await showDialog<ExportOptions>(
        context: context,
        builder: (context) => _ImportPreviewDialog(
          ref: ref,
          yamlContent: yamlContent,
          contentInfo: contentInfo,
        ),
      );

      if (options == null || !mounted) {
        return;
      }

      // Step 4: 执行导入
      // 注意：不传入 ledgerId，让导入逻辑使用 yml 中指定的账本名称
      // 这样预算等数据会导入到正确的账本，而不是当前账本
      final repo = ref.read(repositoryProvider);

      await ConfigExportService.importFromFile(
        filePath,
        repository: repo,
        options: options,
      );

      // 导入后立即刷新相关的 Provider 状态
      if (options.appSettings) {
        await _refreshProvidersAfterImport();
      }

      if (!mounted) return;
      showBeeToast(context, AppLocalizations.of(context).configImportSuccess);

      // 提示需要重启应用（部分设置可能仍需重启）
      if (!mounted) return;
      await _showConfigMessage(
        title: AppLocalizations.of(context).configImportRestartTitle,
        message: AppLocalizations.of(context).configImportRestartMessage,
      );
    } catch (e) {
      if (!mounted) return;
      await _showConfigMessage(
        title: AppLocalizations.of(context).configImportFailed,
        message: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _showConfigMessage({
    required String title,
    required String message,
  }) =>
      showDialog<void>(
          context: context,
          builder: (dialogContext) => BeeDialog(
                  title: Text(title),
                  content: Text(message.replaceAll(r'\n', '\n')),
                  actions: [
                    BeeButton(
                        label: AppLocalizations.of(dialogContext).commonOk,
                        onPressed: () => Navigator.pop(dialogContext))
                  ]));

  /// 导入后刷新相关的 Provider 状态
  Future<void> _refreshProvidersAfterImport() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 刷新主题色
      final primaryColor = prefs.getInt('primaryColor');
      if (primaryColor != null) {
        ref.read(primaryColorProvider.notifier).state = Color(primaryColor);
        logger.info('ConfigImport', '主题色已刷新: $primaryColor');
      }

      // 刷新主题模式
      final themeMode = prefs.getString('themeMode');
      if (themeMode != null) {
        switch (themeMode) {
          case 'light':
            ref.read(themeModeProvider.notifier).state = ThemeMode.light;
            break;
          case 'dark':
            ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
            break;
          default:
            ref.read(themeModeProvider.notifier).state = ThemeMode.system;
        }
        logger.info('ConfigImport', '主题模式已刷新: $themeMode');
      }

      // 刷新字体缩放
      final fontScaleLevel = prefs.getInt('fontScaleLevel');
      if (fontScaleLevel != null) {
        ref.read(fontScaleLevelProvider.notifier).state =
            fontScaleLevel.clamp(-3, 4);
        logger.info('ConfigImport', '字体缩放档位已刷新: $fontScaleLevel');
      }

      final customFontScale = prefs.getDouble('customFontScale');
      if (customFontScale != null) {
        ref.read(customFontScaleProvider.notifier).state =
            customFontScale.clamp(0.7, 1.5);
        logger.info('ConfigImport', '自定义字体缩放已刷新: $customFontScale');
      }

      // 刷新金额显示格式
      final compactAmount = prefs.getBool('compactAmount');
      if (compactAmount != null) {
        ref.read(compactAmountProvider.notifier).state = compactAmount;
        logger.info('ConfigImport', '金额显示格式已刷新: $compactAmount');
      }

      // 刷新交易时间显示
      final showTransactionTime = prefs.getBool('showTransactionTime');
      if (showTransactionTime != null) {
        ref.read(showTransactionTimeProvider.notifier).state =
            showTransactionTime;
        logger.info('ConfigImport', '交易时间显示已刷新: $showTransactionTime');
      }

      // 刷新头部皮肤
      final headerSkin = prefs.getString('headerSkin');
      if (headerSkin != null) {
        ref.read(headerSkinProvider.notifier).state = headerSkin;
        logger.info('ConfigImport', '头部皮肤已刷新: $headerSkin');
      }
      logger.info('ConfigImport', 'Provider 状态刷新完成');
    } catch (e) {
      logger.error('ConfigImport', '刷新 Provider 状态失败: $e');
    }
  }
}
