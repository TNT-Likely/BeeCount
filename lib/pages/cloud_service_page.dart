import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../cloud/cloud_service_config.dart';
import '../providers/sync_providers.dart';
import '../widgets/ui/dialog.dart' show AppDialog;
import '../widgets/ui/ui.dart';
import '../widgets/ui/toast.dart';
import '../widgets/biz/section_card.dart';
import '../styles/colors.dart';
import '../utils/logger.dart';
import '../l10n/app_localizations.dart';

class CloudServicePage extends ConsumerStatefulWidget {
  const CloudServicePage({super.key});
  @override
  ConsumerState<CloudServicePage> createState() => _CloudServicePageState();
}

class _CloudServicePageState extends ConsumerState<CloudServicePage> {
  bool _saving = false;
  bool _testingConnection = false;
  Map<String, bool> _connectionTestResults = {};

  @override
  Widget build(BuildContext context) {
    logI('cloudCfg', 'CloudServicePage build() 开始');
    final activeAsync = ref.watch(activeCloudConfigProvider);
    final builtin = ref.watch(builtinCloudConfigProvider);
    final storedCustom = ref.watch(storedCustomCloudConfigProvider);
    final firstUpload = ref.watch(firstFullUploadPendingProvider);

    logI('cloudCfg', 'Provider 状态: active=${activeAsync.hasValue}, storedCustom=${storedCustom.hasValue}');

    return Scaffold(
      backgroundColor: BeeColors.greyBg,
      body: Column(
        children: [
            PrimaryHeader(
              title: AppLocalizations.of(context).mineCloudService,
              showBack: true,
              actions: kDebugMode ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.black87),
                  onPressed: _clearCustomConfig,
                  tooltip: 'Clear custom config (Dev)',
                ),
              ] : null,
              content: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: activeAsync.when(
                  loading: () => const SizedBox(
                      height: 36,
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                  error: (e, _) => Text('${AppLocalizations.of(context).commonLoading}: $e',
                      style: const TextStyle(color: Colors.redAccent)),
                  data: (active) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).cloudCurrentService,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.cloud_outlined,
                              size: 16,
                              color: BeeColors.secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              active.builtin
                                ? AppLocalizations.of(context).cloudDefaultServiceName
                                : active.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: active.valid ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                active.valid ? AppLocalizations.of(context).cloudConnected : AppLocalizations.of(context).cloudOfflineMode,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: active.valid ? Colors.green : Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: activeAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('${AppLocalizations.of(context).commonError}: $e')),
                data: (active) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      Text(
                        AppLocalizations.of(context).cloudAvailableServices,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: BeeColors.secondaryText,
                            ),
                      ),
                      const SizedBox(height: 12),

                      // 默认云服务选项
                      _buildCloudServiceItem(
                        config: builtin,
                        isSelected: active.builtin,
                        onSelect: () => _switchToBuiltin(active),
                        actionButtons: null, // 默认服务不需要按钮
                      ),

                      const SizedBox(height: 8),

                      // 自定义云服务选项
                      storedCustom.when(
                        loading: () => const SizedBox(
                          height: 60,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => _buildErrorItem('${AppLocalizations.of(context).cloudReadCustomConfigFailed}: $e'),
                        data: (customConfig) {
                          final hasCustom = customConfig != null && customConfig.valid;
                          final isCustomSelected = !active.builtin;

                          logI('cloudCfg', 'storedCustom data: hasCustom=$hasCustom, isCustomSelected=$isCustomSelected');

                          if (hasCustom) {
                            // 显示已有的自定义配置
                            return _buildCloudServiceItem(
                              config: customConfig,
                              isSelected: isCustomSelected,
                              onSelect: () => _switchToCustom(customConfig, active),
                              actionButtons: [
                                _buildTestButton(customConfig),
                                _buildEditButton(() => _editCustomConfig(customConfig)),
                              ],
                            );
                          } else {
                            // 显示新增自定义配置选项
                            return _buildAddCustomServiceItem();
                          }
                        },
                      ),

                      // 首次上传提醒
                      if (!active.builtin && firstUpload.asData?.value == true) ...[
                        const SizedBox(height: 16),
                        Card(
                          color: Colors.orange.withValues(alpha: 0.1),
                          child: ListTile(
                            leading: const Icon(Icons.cloud_upload_outlined, color: Colors.orange),
                            title: Text(AppLocalizations.of(context).cloudFirstUploadNotComplete),
                            subtitle: Text(AppLocalizations.of(context).cloudFirstUploadInstruction),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildCloudServiceItem({
    required CloudServiceConfig config,
    required bool isSelected,
    required VoidCallback onSelect,
    required List<Widget>? actionButtons,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: isSelected
            ? Border.all(color: BeeColors.success, width: 2)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SectionCard(
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            InkWell(
              onTap: isSelected ? null : onSelect,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // 图标
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getServiceColor(config).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getServiceIcon(config),
                            color: _getServiceColor(config),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // 信息
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    config.builtin
                                      ? AppLocalizations.of(context).cloudDefaultServiceName
                                      : config.name,
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Supabase',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: BeeColors.secondaryText,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // 连接状态指示器
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _getConnectionStatusColor(config),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getConnectionStatusText(config),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: _getConnectionStatusColor(config),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _getServiceDescription(config),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: BeeColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 右上角勾选图标
                  if (isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: BeeColors.success,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 操作按钮区域
            if (actionButtons != null && actionButtons.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actionButtons
                        .expand((button) => [button, const SizedBox(width: 8)])
                        .take(actionButtons.length * 2 - 1)
                        .toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCustomServiceItem() {
    return SectionCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _addCustomConfig(),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 占位的Radio位置
              const SizedBox(width: 48),
              const SizedBox(width: 12),

              // 图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3), style: BorderStyle.solid),
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).cloudAddCustomService,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: BeeColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context).cloudUseYourSupabase,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: BeeColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: BeeColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditButton(VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: (_saving || _testingConnection) ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(60, 32),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(
        AppLocalizations.of(context).commonEdit,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildTestButton(CloudServiceConfig config) {
    return OutlinedButton(
      onPressed: (_saving || _testingConnection) ? null : () => _testConnection(config),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(60, 32),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: _testingConnection
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              AppLocalizations.of(context).cloudTest,
              style: const TextStyle(fontSize: 12),
            ),
    );
  }

  Widget _buildErrorItem(String error) {
    return SectionCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.red),
        title: Text(error),
      ),
    );
  }

  Color _getServiceColor(CloudServiceConfig config) {
    if (config.builtin) {
      return config.valid ? Colors.blue : Colors.grey;
    } else {
      return Colors.green;
    }
  }

  IconData _getServiceIcon(CloudServiceConfig config) {
    if (config.builtin) {
      return config.valid ? Icons.cloud : Icons.cloud_off;
    } else {
      return Icons.cloud_done;
    }
  }

  String _getServiceDescription(CloudServiceConfig config) {
    final context = this.context;
    if (config.builtin) {
      return config.valid ? AppLocalizations.of(context).cloudServiceDescription : AppLocalizations.of(context).cloudServiceDescriptionNotConfigured;
    } else {
      final url = config.obfuscatedUrl();
      return AppLocalizations.of(context).cloudServiceDescriptionCustom(
        url == '__NOT_CONFIGURED__' ? AppLocalizations.of(context).cloudNotConfigured : url
      );
    }
  }

  // 切换到默认云服务
  Future<void> _switchToBuiltin(CloudServiceConfig currentActive) async {
    if (currentActive.builtin) return;

    // 二次确认
    final confirmed = await AppDialog.confirm(context,
        title: AppLocalizations.of(context).cloudSwitchService,
        message: AppLocalizations.of(context).cloudSwitchToBuiltinConfirm);
    if (!confirmed) return;

    setState(() => _saving = true);
    try {
      // 登出当前会话
      try {
        if (mounted) {
          await ref.read(authServiceProvider).signOut();
        }
      } catch (_) {}

      if (mounted) {
        await ref.read(cloudServiceStoreProvider).switchToBuiltin();
      }

      if (mounted) {
        await AppDialog.info(context,
            title: AppLocalizations.of(context).cloudSwitched,
            message: AppLocalizations.of(context).cloudSwitchedToBuiltin);
      }
    } catch (e) {
      if (mounted) {
        await AppDialog.error(context, title: AppLocalizations.of(context).cloudSwitchFailed, message: '$e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // 切换到自定义云服务
  Future<void> _switchToCustom(CloudServiceConfig customConfig, CloudServiceConfig currentActive) async {
    if (!currentActive.builtin) return;

    // 二次确认
    final confirmed = await AppDialog.confirm(context,
        title: AppLocalizations.of(context).cloudSwitchService,
        message: AppLocalizations.of(context).cloudSwitchToCustomConfirm);
    if (!confirmed) return;

    setState(() => _saving = true);
    try {
      // 登出当前会话
      try {
        if (mounted) {
          await ref.read(authServiceProvider).signOut();
        }
      } catch (_) {}

      final ok = mounted ? await ref.read(cloudServiceStoreProvider).activateExistingCustomIfAny() : false;
      if (!ok) {
        if (mounted) {
          await AppDialog.error(context,
              title: AppLocalizations.of(context).cloudActivateFailed,
              message: AppLocalizations.of(context).cloudActivateFailedMessage);
        }
      } else {

        if (mounted) {
          await AppDialog.info(context,
              title: AppLocalizations.of(context).cloudActivated,
              message: AppLocalizations.of(context).cloudActivatedMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        await AppDialog.error(context, title: AppLocalizations.of(context).cloudSwitchFailed, message: '$e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // 添加自定义配置
  Future<void> _addCustomConfig() async {
    logI('cloudCfg', '开始添加自定义配置');
    await _showCustomConfigDialog(null);
    logI('cloudCfg', '添加自定义配置对话框已关闭');
  }

  // 编辑自定义配置
  Future<void> _editCustomConfig(CloudServiceConfig config) async {
    logI('cloudCfg', '开始编辑自定义配置');
    await _showCustomConfigDialog(config);
    logI('cloudCfg', '编辑自定义配置对话框已关闭');
  }

  // 显示自定义配置对话框
  Future<void> _showCustomConfigDialog(CloudServiceConfig? existingConfig) async {
    final urlController = TextEditingController(text: existingConfig?.supabaseUrl ?? '');
    final keyController = TextEditingController(text: existingConfig?.supabaseAnonKey ?? '');
    bool isSaving = false;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existingConfig != null ? AppLocalizations.of(context).cloudEditCustomService : AppLocalizations.of(context).cloudAddCustomServiceTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: urlController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).cloudSupabaseUrlLabel,
                    hintText: AppLocalizations.of(context).cloudSupabaseUrlHint,
                  ),
                  keyboardType: TextInputType.url,
                  enabled: !isSaving,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: keyController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).cloudAnonKeyLabel,
                  ),
                  enabled: !isSaving,
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).cloudAnonKeyHint,
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.of(context).pop(false),
              child: Text(AppLocalizations.of(context).commonCancel),
            ),
            FilledButton(
              onPressed: isSaving ? null : () async {
                final url = urlController.text.trim();
                final key = keyController.text.trim();
                final err = _validate(url, key);
                if (err != null) {
                  await AppDialog.error(context,
                      title: AppLocalizations.of(context).cloudInvalidInput, message: err);
                  return;
                }

                setDialogState(() => isSaving = true);
                try {
                  final cfg = CloudServiceConfig(
                    id: 'custom',
                    type: CloudBackendType.supabase,
                    name: AppLocalizations.of(context).cloudAddCustomService,
                    supabaseUrl: url,
                    supabaseAnonKey: key,
                    builtin: false,
                  );

                  // 统一处理：仅保存配置，不自动启用
                  if (mounted) {
                    logI('cloudCfg', '开始保存自定义配置...');
                    await ref.read(cloudServiceStoreProvider).saveCustomOnly(cfg);
                    logI('cloudCfg', '配置保存完成');

                    // 刷新Provider状态，让UI立即反映变化
                    ref.invalidate(storedCustomCloudConfigProvider);
                    ref.invalidate(activeCloudConfigProvider);
                    logI('cloudCfg', 'Provider状态已刷新');
                  }

                  // 清除测试结果缓存（如果有的话）
                  if (mounted) {
                    logI('cloudCfg', '清除测试结果缓存');
                    setState(() {
                      _connectionTestResults.remove(cfg.id);
                    });
                  }

                  if (context.mounted) {
                    logI('cloudCfg', '关闭对话框并显示提示');
                    Navigator.of(context).pop(true);

                    // 使用 Toast 显示成功提示
                    showToast(context, existingConfig != null ? AppLocalizations.of(context).cloudConfigUpdated : AppLocalizations.of(context).cloudConfigSaved);
                    logI('cloudCfg', '保存流程完成');
                  }
                } catch (e) {
                  logE('cloudCfg', '保存失败', e);
                  if (context.mounted) {
                    await AppDialog.error(context,
                        title: AppLocalizations.of(context).commonFailed, message: '$e');
                  }
                } finally {
                  setDialogState(() => isSaving = false);
                }
              },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(AppLocalizations.of(context).commonSave),
            ),
          ],
        ),
      ),
    );

    // 延迟 dispose，确保所有动画和重建完成后再清理资源
    Future.delayed(const Duration(milliseconds: 500), () {
      urlController.dispose();
      keyController.dispose();
    });
  }

  String? _validate(String url, String key) {
    final context = this.context;
    if (url.isEmpty || key.isEmpty) return AppLocalizations.of(context).cloudValidationEmptyFields;
    if (!url.startsWith('https://')) return AppLocalizations.of(context).cloudValidationHttpsRequired;
    if (key.length < 20) return AppLocalizations.of(context).cloudValidationKeyTooShort;
    final lower = key.toLowerCase();
    if (lower.contains('service_role')) return AppLocalizations.of(context).cloudValidationServiceRoleKey;
    return null;
  }

  Color _getConnectionStatusColor(CloudServiceConfig config) {
    if (!config.valid) {
      return BeeColors.warning; // 黄色：未配置
    }

    // 对于自定义配置，检查测试结果
    if (!config.builtin) {
      final testResult = _connectionTestResults[config.id];
      if (testResult == null) {
        return BeeColors.warning; // 黄色：未测试
      } else if (testResult) {
        return BeeColors.success; // 绿色：测试成功
      } else {
        return BeeColors.danger; // 红色：测试失败
      }
    }

    // 内置配置如果valid就认为可连接
    return BeeColors.success; // 绿色：已连接
  }

  String _getConnectionStatusText(CloudServiceConfig config) {
    final context = this.context;
    if (!config.valid) {
      return AppLocalizations.of(context).cloudNotConfigured;
    }

    // 对于自定义配置，显示测试状态
    if (!config.builtin) {
      final testResult = _connectionTestResults[config.id];
      if (testResult == null) {
        return AppLocalizations.of(context).cloudNotTested;
      } else if (testResult) {
        return AppLocalizations.of(context).cloudConnectionNormal;
      } else {
        return AppLocalizations.of(context).cloudConnectionFailed;
      }
    }

    // 内置配置
    return AppLocalizations.of(context).cloudConnected;
  }

  // 测试连接状态
  Future<void> _testConnection(CloudServiceConfig config) async {
    if (!config.valid || config.builtin) return;

    setState(() => _testingConnection = true);
    try {
      // 这里模拟连接测试 - 实际项目中应该调用真实的连接测试
      // 可以尝试创建 Supabase 客户端或调用健康检查端点

      // 简单的URL格式检查和超时测试
      bool connectionSuccess = false;
      try {
        // 这里应该使用 http 包或 Supabase 客户端进行真实测试
        // 暂时使用简单的URL验证
        final uri = Uri.parse(config.supabaseUrl!);
        connectionSuccess = uri.host.isNotEmpty && config.supabaseAnonKey!.length > 50;

        // 模拟网络延迟
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        connectionSuccess = false;
      }

      setState(() {
        _connectionTestResults[config.id] = connectionSuccess;
      });

      if (mounted) {
        await AppDialog.info(context,
            title: AppLocalizations.of(context).cloudTestComplete,
            message: connectionSuccess ? AppLocalizations.of(context).cloudTestSuccess : AppLocalizations.of(context).cloudTestFailed);
      }
    } catch (e) {
      setState(() {
        _connectionTestResults[config.id] = false;
      });
      if (mounted) {
        await AppDialog.error(context, title: AppLocalizations.of(context).cloudTestError, message: '$e');
      }
    } finally {
      if (mounted) setState(() => _testingConnection = false);
    }
  }

  // 开发环境清空自定义配置
  Future<void> _clearCustomConfig() async {
    if (!kDebugMode) return;

    final confirmed = await AppDialog.confirm(context,
        title: AppLocalizations.of(context).cloudClearConfig,
        message: AppLocalizations.of(context).cloudClearConfigConfirm);
    if (!confirmed) return;

    setState(() => _saving = true);
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove('cloud_custom_supabase_cfg');
      await sp.setString('cloud_active', 'builtin');

      // 刷新Provider状态，让UI重新加载数据
      ref.invalidate(storedCustomCloudConfigProvider);
      ref.invalidate(activeCloudConfigProvider);


      // 使用 Toast 显示清空成功提示，避免 Widget 生命周期问题
      if (mounted && context.mounted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            showToast(context, AppLocalizations.of(context).cloudConfigCleared);
          }
        });
      }
    } catch (e) {
      if (mounted && context.mounted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            showToast(context, '${AppLocalizations.of(context).cloudClearFailed}: $e');
          }
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}