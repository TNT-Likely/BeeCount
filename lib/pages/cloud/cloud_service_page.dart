import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' hide SyncStatus;
import 'package:flutter_cloud_sync_icloud/flutter_cloud_sync_icloud.dart';
import '../../providers/sync_providers.dart';
import '../../providers/database_providers.dart';
import '../../services/system/logger_service.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/ui/capsule_switcher.dart';
import '../../widgets/biz/section_card.dart';
import '../../styles/tokens.dart';
import '../../l10n/app_localizations.dart';

// GitHub配置教程链接
const _kSupabaseGuideUrl = 'https://github.com/TNT-Likely/BeeCount/wiki/Supabase-%E4%BA%91%E5%90%8C%E6%AD%A5%E9%85%8D%E7%BD%AE';
const _kWebdavGuideUrl = 'https://github.com/TNT-Likely/BeeCount/wiki/WebDAV-%E4%BA%91%E5%90%8C%E6%AD%A5%E9%85%8D%E7%BD%AE';

class CloudServicePage extends ConsumerStatefulWidget {
  const CloudServicePage({super.key});
  @override
  ConsumerState<CloudServicePage> createState() => _CloudServicePageState();
}

class _CloudServicePageState extends ConsumerState<CloudServicePage> {
  bool _testingConnection = false;
  final Map<String, bool> _connectionTestResults = {};
  bool _hasAutoTested = false;
  String _selectedTab = 'offline'; // 'offline' | 'backup' | 'cloud'

  @override
  void initState() {
    super.initState();

    // 根据当前激活的配置决定初始 Tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeAsync = ref.read(activeCloudConfigProvider);
      if (activeAsync.hasValue) {
        final active = activeAsync.value!;
        if (active.type == CloudBackendType.beecountCloud) {
          setState(() => _selectedTab = 'cloud');
        } else if (active.type != CloudBackendType.local) {
          setState(() => _selectedTab = 'backup');
        }
      }
      _autoTestActiveConnection();
    });
  }

  Future<void> _autoTestActiveConnection() async {
    if (_hasAutoTested) return;
    _hasAutoTested = true;

    // 多设备同步关闭时，跳过自动测试
    final prefs = await SharedPreferences.getInstance();
    final multiDevice = prefs.getBool('multi_device_sync') ?? false;
    if (!multiDevice) return;

    final activeAsync = ref.read(activeCloudConfigProvider);
    if (!activeAsync.hasValue) return;

    final active = activeAsync.value!;
    if (active.type == CloudBackendType.local || !active.valid) return;

    // 自动测试当前激活的云服务连接（静默测试，不显示对话框）
    await _testConnection(active, showDialog: false);
  }

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(activeCloudConfigProvider);
    final beecountCloudAsync = ref.watch(beecountCloudConfigProvider);
    final supabaseAsync = ref.watch(supabaseConfigProvider);
    final webdavAsync = ref.watch(webdavConfigProvider);
    final s3Async = ref.watch(s3ConfigProvider);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          activeAsync.when(
            loading: () => PrimaryHeader(
              title: AppLocalizations.of(context).mineCloudService,
              showBack: true,
            ),
            error: (e, _) => PrimaryHeader(
              title: AppLocalizations.of(context).mineCloudService,
              showBack: true,
            ),
            data: (active) => PrimaryHeader(
              title: AppLocalizations.of(context).mineCloudService,
              showBack: true,
              actions: active.type != CloudBackendType.local && active.valid
                  ? [
                      IconButton(
                        icon: _testingConnection
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_find),
                        onPressed: _testingConnection ? null : () => _testConnection(active),
                        tooltip: AppLocalizations.of(context).cloudTestConnection,
                      ),
                    ]
                  : null,
              content: active.type != CloudBackendType.local
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: _buildConnectionStatus(active),
                    )
                  : null,
            ),
          ),
          // 胶囊切换器
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: CapsuleSwitcher<String>(
              selectedValue: _selectedTab,
              options: [
                CapsuleOption(value: 'offline', label: AppLocalizations.of(context).cloudTabOffline),
                CapsuleOption(value: 'backup', label: AppLocalizations.of(context).cloudTabBackup),
                CapsuleOption(value: 'cloud', label: AppLocalizations.of(context).cloudTabCloudSync),
              ],
              onChanged: (value) => setState(() => _selectedTab = value),
            ),
          ),
          Expanded(
            child: activeAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('${AppLocalizations.of(context).commonError}: $e')),
              data: (active) {
                if (_selectedTab == 'offline') {
                  // ===== 离线模式 =====
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildServiceCard(
                        context: context,
                        icon: Icons.phone_android,
                        iconColor: BeeTokens.brandLocal,
                        title: AppLocalizations.of(context).cloudLocalStorageTitle,
                        subtitle: AppLocalizations.of(context).cloudLocalStorageSubtitle,
                        isSelected: active.type == CloudBackendType.local,
                        isDisabled: false,
                        onTap: () => _switchService(CloudBackendType.local),
                      ),
                    ],
                  );
                } else if (_selectedTab == 'backup') {
                  // ===== 备份同步 =====
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 多设备同步警告
                      if (active.type != CloudBackendType.local &&
                          active.type != CloudBackendType.beecountCloud) ...[
                        _buildMultiDeviceWarning(context),
                        const SizedBox(height: 12),
                      ],

                      // iCloud (仅 iOS)
                      if (!kIsWeb && Platform.isIOS) ...[
                        _buildICloudCard(context, active, isDisabled: false),
                        const SizedBox(height: 12),
                      ],

                      // WebDAV
                      webdavAsync.when(
                        loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                        error: (e, _) => const SizedBox.shrink(),
                        data: (webdavCfg) => _buildServiceCard(
                          context: context,
                          icon: Icons.folder_shared,
                          iconColor: BeeTokens.brandWebdav,
                          title: AppLocalizations.of(context).cloudCustomWebdavTitle,
                          subtitle: webdavCfg?.valid == true
                              ? webdavCfg!.obfuscatedUrl()
                              : AppLocalizations.of(context).cloudCustomWebdavSubtitle,
                          isSelected: active.type == CloudBackendType.webdav,
                          isConfigured: webdavCfg?.valid == true,
                          isDisabled: false,
                          onTap: () => webdavCfg?.valid == true
                              ? _switchService(CloudBackendType.webdav)
                              : _configureService(CloudBackendType.webdav),
                          onConfigure: webdavCfg?.valid == true
                              ? () => _configureService(CloudBackendType.webdav)
                              : null,
                          onShowGuide: _showWebdavHelpDialog,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // S3
                      s3Async.when(
                        loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                        error: (e, _) => const SizedBox.shrink(),
                        data: (s3Cfg) => _buildServiceCard(
                          context: context,
                          icon: Icons.storage,
                          iconColor: BeeTokens.brandS3,
                          title: AppLocalizations.of(context).cloudCustomS3Title,
                          subtitle: s3Cfg?.valid == true
                              ? s3Cfg!.obfuscatedUrl()
                              : AppLocalizations.of(context).cloudCustomS3Subtitle,
                          isSelected: active.type == CloudBackendType.s3,
                          isConfigured: s3Cfg?.valid == true,
                          isDisabled: false,
                          onTap: () => s3Cfg?.valid == true
                              ? _switchService(CloudBackendType.s3)
                              : _configureService(CloudBackendType.s3),
                          onConfigure: s3Cfg?.valid == true
                              ? () => _configureService(CloudBackendType.s3)
                              : null,
                          onShowGuide: _showS3HelpDialog,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Supabase
                      supabaseAsync.when(
                        loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                        error: (e, _) => const SizedBox.shrink(),
                        data: (supabaseCfg) => _buildServiceCard(
                          context: context,
                          icon: Icons.cloud,
                          iconColor: BeeTokens.brandSupabase,
                          title: AppLocalizations.of(context).cloudCustomSupabaseTitle,
                          subtitle: supabaseCfg?.valid == true
                              ? supabaseCfg!.obfuscatedUrl()
                              : AppLocalizations.of(context).cloudCustomSupabaseSubtitle,
                          isSelected: active.type == CloudBackendType.supabase,
                          isConfigured: supabaseCfg?.valid == true,
                          isDisabled: false,
                          onTap: () => supabaseCfg?.valid == true
                              ? _switchService(CloudBackendType.supabase)
                              : _configureService(CloudBackendType.supabase),
                          onConfigure: supabaseCfg?.valid == true
                              ? () => _configureService(CloudBackendType.supabase)
                              : null,
                          onShowGuide: _showSupabaseHelpDialog,
                        ),
                      ),
                    ],
                  );
                } else {
                  // ===== 云端协同 (BeeCount Cloud) =====
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      beecountCloudAsync.when(
                        loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                        error: (e, _) => const SizedBox.shrink(),
                        data: (bcCfg) => _buildServiceCard(
                          context: context,
                          icon: Icons.cloud_circle,
                          iconColor: BeeTokens.brandCloud,
                          title: AppLocalizations.of(context).cloudBeeCountCloudTitle,
                          subtitle: bcCfg?.valid == true
                              ? bcCfg!.obfuscatedUrl()
                              : AppLocalizations.of(context).cloudBeeCountCloudSubtitle,
                          isSelected: active.type == CloudBackendType.beecountCloud,
                          isConfigured: bcCfg?.valid == true,
                          isDisabled: false,
                          onTap: () => bcCfg?.valid == true
                              ? _switchService(CloudBackendType.beecountCloud)
                              : _configureService(CloudBackendType.beecountCloud),
                          onConfigure: bcCfg?.valid == true
                              ? () => _configureService(CloudBackendType.beecountCloud)
                              : null,
                          onShowGuide: _showBeeCountCloudHelpDialog,
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(CloudServiceConfig config) {
    final testResult = _connectionTestResults[config.id];
    final Color statusColor;
    final IconData statusIcon;
    final String statusText;

    if (testResult == null) {
      // 未测试
      statusColor = BeeTokens.warning(context);
      statusIcon = Icons.help_outline;
      statusText = AppLocalizations.of(context).cloudStatusNotTested;
    } else if (testResult) {
      // 测试成功
      statusColor = BeeTokens.success(context);
      statusIcon = Icons.check_circle_outline;
      statusText = AppLocalizations.of(context).cloudStatusNormal;
    } else {
      // 测试失败
      statusColor = BeeTokens.error(context);
      statusIcon = Icons.error_outline;
      statusText = AppLocalizations.of(context).cloudStatusFailed;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${AppLocalizations.of(context).commonCurrent}: ${_getTypeName(config.type)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          config.obfuscatedUrl(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: BeeTokens.textSecondary(context),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildMultiDeviceWarning(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: () => _showMultiDeviceDetailDialog(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BeeTokens.warning(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: BeeTokens.warning(context).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: BeeTokens.warning(context),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.cloudMultiDeviceWarningTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: BeeTokens.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.cloudMultiDeviceWarningMessage,
                    style: TextStyle(
                      fontSize: 12,
                      color: BeeTokens.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.info_outline,
              color: BeeTokens.warning(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showMultiDeviceDetailDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryText = BeeTokens.textPrimary(context);
    final secondaryText = BeeTokens.textSecondary(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BeeTokens.surfaceElevated(context),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.cloudSyncGuideTitle,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 工作原理
                _buildGuideSection(
                  context,
                  icon: Icons.sync,
                  title: l10n.cloudSyncGuideHowItWorks,
                  items: [
                    l10n.cloudSyncGuideHowItem1,
                    l10n.cloudSyncGuideHowItem2,
                    l10n.cloudSyncGuideHowItem3,
                  ],
                ),
                const SizedBox(height: 16),
                // 正确用法
                _buildGuideSection(
                  context,
                  icon: Icons.check_circle_outline,
                  iconColor: Colors.green,
                  title: l10n.cloudSyncGuideCorrect,
                  items: [
                    l10n.cloudSyncGuideCorrectItem1,
                    l10n.cloudSyncGuideCorrectItem2,
                    l10n.cloudSyncGuideCorrectItem3,
                    l10n.cloudSyncGuideCorrectItem4,
                  ],
                ),
                const SizedBox(height: 16),
                // 错误用法
                _buildGuideSection(
                  context,
                  icon: Icons.cancel_outlined,
                  iconColor: Colors.red,
                  title: l10n.cloudSyncGuideWrong,
                  items: [
                    l10n.cloudSyncGuideWrongItem1,
                    l10n.cloudSyncGuideWrongItem2,
                    l10n.cloudSyncGuideWrongItem3,
                  ],
                ),
                const SizedBox(height: 16),
                // 已知限制
                _buildGuideSection(
                  context,
                  icon: Icons.warning_amber_rounded,
                  iconColor: BeeTokens.warning(context),
                  title: l10n.cloudSyncGuideLimitations,
                  items: [
                    l10n.cloudSyncGuideLimitItem1,
                    l10n.cloudSyncGuideLimitItem2,
                    l10n.cloudSyncGuideLimitItem3,
                    l10n.cloudSyncGuideLimitItem4,
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cloudSyncGuideGotIt,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideSection(
    BuildContext context, {
    required IconData icon,
    Color? iconColor,
    required String title,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: iconColor ?? BeeTokens.textSecondary(context)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: BeeTokens.textPrimary(context),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: BeeTokens.textSecondary(context), fontSize: 13)),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: BeeTokens.textSecondary(context),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildServiceCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isSelected,
    bool isConfigured = true,
    bool isDisabled = false,
    required VoidCallback onTap,
    VoidCallback? onConfigure,
    VoidCallback? onShowGuide,
  }) {
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          border: isSelected ? Border.all(color: BeeTokens.success(context), width: 2) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SectionCard(
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: isDisabled ? null : onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // 图标
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: iconColor, size: 24),
                      ),
                      const SizedBox(width: 16),

                      // 文字信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (isDisabled)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: BeeTokens.textTertiary(context).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '不可用',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: BeeTokens.textTertiary(context),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: BeeTokens.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 选中标记
                      if (isSelected && !isDisabled)
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: BeeTokens.success(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check, color: BeeTokens.textOnPrimary(context), size: 18),
                        ),
                    ],
                  ),

                  // 底部按钮行
                  if (!isDisabled && ((isConfigured && onConfigure != null) || onShowGuide != null))
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (onShowGuide != null)
                            TextButton.icon(
                              onPressed: onShowGuide,
                              icon: const Icon(Icons.help_outline, size: 16),
                              label: Text(AppLocalizations.of(context).commonTutorial, style: const TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          if (isConfigured && onConfigure != null) ...[
                            if (onShowGuide != null) const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: onConfigure,
                              icon: const Icon(Icons.settings, size: 16),
                              label: Text(AppLocalizations.of(context).commonConfigure, style: const TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildICloudCard(BuildContext context, CloudServiceConfig active, {bool isDisabled = false}) {
    final isSelected = active.type == CloudBackendType.icloud;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          border: isSelected ? Border.all(color: BeeTokens.success(context), width: 2) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SectionCard(
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: isDisabled ? null : () => _switchService(CloudBackendType.icloud),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // 图标
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: BeeTokens.brandIcloud.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.cloud, color: BeeTokens.brandIcloud, size: 24),
                      ),
                      const SizedBox(width: 16),

                      // 文字信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'iCloud',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (isDisabled)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: BeeTokens.textTertiary(context).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '不可用',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: BeeTokens.textTertiary(context),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isSelected
                                  ? 'iCloud Drive'
                                  : AppLocalizations.of(context).cloudIcloudSubtitle,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: BeeTokens.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 选中标记
                      if (isSelected && !isDisabled)
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: BeeTokens.success(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check, color: BeeTokens.textOnPrimary(context), size: 18),
                        ),
                    ],
                  ),

                  // 底部帮助按钮
                  if (!isDisabled)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: _showICloudHelpDialog,
                            icon: const Icon(Icons.help_outline, size: 16),
                            label: Text(AppLocalizations.of(context).commonTutorial, style: const TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  void _showSupabaseHelpDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cloud, color: BeeTokens.brandSupabase),
            const SizedBox(width: 8),
            Text(l10n.cloudSupabaseHelpTitle),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(
                l10n.cloudSupabaseHelpIntro,
                [
                  l10n.cloudSupabaseHelpIntro1,
                  l10n.cloudSupabaseHelpIntro2,
                  l10n.cloudSupabaseHelpIntro3,
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                l10n.cloudSupabaseHelpSteps,
                [
                  l10n.cloudSupabaseHelpStep1,
                  l10n.cloudSupabaseHelpStep2,
                  l10n.cloudSupabaseHelpStep3,
                  l10n.cloudSupabaseHelpStep4,
                  l10n.cloudSupabaseHelpStep5,
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                l10n.cloudSupabaseHelpFaq,
                [
                  '• ${l10n.cloudSupabaseHelpFaq1}',
                  '• ${l10n.cloudSupabaseHelpFaq2}',
                  '• ${l10n.cloudSupabaseHelpFaq3}',
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BeeTokens.brandSupabase.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: BeeTokens.brandSupabase, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.cloudSupabaseHelpNote,
                        style: TextStyle(
                          fontSize: 13,
                          color: BeeTokens.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _openGuide(_kSupabaseGuideUrl),
            child: Text(l10n.cloudDetailedTutorial),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
  }

  void _showBeeCountCloudHelpDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cloud_circle, color: BeeTokens.brandCloud),
            const SizedBox(width: 8),
            Text(l10n.cloudTutorialTitle),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 介绍
              Text(
                l10n.cloudTutorialIntro,
                style: TextStyle(
                  fontSize: 13,
                  color: BeeTokens.textSecondary(context),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // 4 步教程
              _buildBeeCloudStep('1', l10n.cloudTutorialStep1Title, l10n.cloudTutorialStep1Desc),
              _buildBeeCloudStep('2', l10n.cloudTutorialStep2Title, l10n.cloudTutorialStep2Desc),
              _buildBeeCloudStep('3', l10n.cloudTutorialStep3Title, l10n.cloudTutorialStep3Desc),
              _buildBeeCloudStep('4', l10n.cloudTutorialStep4Title, l10n.cloudTutorialStep4Desc),
              const SizedBox(height: 4),
              // 特色功能 —— 强调 Web + 多设备协同 + 多用户 + 共享账本
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BeeTokens.brandCloud.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.cloudTutorialFeaturesTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: BeeTokens.brandCloud,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(l10n.cloudTutorialFeature1, style: const TextStyle(fontSize: 12.5, height: 1.7)),
                    Text(l10n.cloudTutorialFeature2, style: const TextStyle(fontSize: 12.5, height: 1.7)),
                    Text(l10n.cloudTutorialFeature3, style: const TextStyle(fontSize: 12.5, height: 1.7)),
                    Text(l10n.cloudTutorialFeature4, style: const TextStyle(fontSize: 12.5, height: 1.7)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Tip
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BeeTokens.brandCloud.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: BeeTokens.brandCloud, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${l10n.cloudTutorialTipTitle}: ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: BeeTokens.textSecondary(context),
                              ),
                            ),
                            TextSpan(
                              text: l10n.cloudTutorialTipDesc,
                              style: TextStyle(
                                fontSize: 13,
                                color: BeeTokens.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cloudTutorialGotIt),
          ),
        ],
      ),
    );
  }

  Widget _buildBeeCloudStep(String num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: BeeTokens.brandCloud,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              num,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    )),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: BeeTokens.textSecondary(context),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showWebdavHelpDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.folder_shared, color: BeeTokens.brandWebdav),
            const SizedBox(width: 8),
            Text(l10n.cloudWebdavHelpTitle),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(
                l10n.cloudWebdavHelpIntro,
                [
                  l10n.cloudWebdavHelpIntro1,
                  l10n.cloudWebdavHelpIntro2,
                  l10n.cloudWebdavHelpIntro3,
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                l10n.cloudWebdavHelpProviders,
                [
                  l10n.cloudWebdavHelpProvider1,
                  l10n.cloudWebdavHelpProvider2,
                  l10n.cloudWebdavHelpProvider3,
                  l10n.cloudWebdavHelpProvider4,
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                l10n.cloudWebdavHelpSteps,
                [
                  l10n.cloudWebdavHelpStep1,
                  l10n.cloudWebdavHelpStep2,
                  l10n.cloudWebdavHelpStep3,
                  l10n.cloudWebdavHelpStep4,
                  l10n.cloudWebdavHelpStep5,
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BeeTokens.brandWebdav.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: BeeTokens.brandWebdav, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.cloudWebdavHelpNote,
                        style: TextStyle(
                          fontSize: 13,
                          color: BeeTokens.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
  }

  void _showICloudHelpDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cloud, color: BeeTokens.brandIcloud),
            const SizedBox(width: 8),
            Text(l10n.cloudIcloudHelpTitle),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(
                l10n.cloudIcloudHelpPrerequisites,
                [
                  l10n.cloudIcloudHelpPrereq1,
                  l10n.cloudIcloudHelpPrereq2,
                  l10n.cloudIcloudHelpPrereq3,
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                l10n.cloudIcloudHelpCheckTitle,
                [
                  l10n.cloudIcloudHelpCheck1,
                  l10n.cloudIcloudHelpCheck2,
                  l10n.cloudIcloudHelpCheck3,
                  l10n.cloudIcloudHelpCheck4,
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                l10n.cloudIcloudHelpFaqTitle,
                [
                  '• ${l10n.cloudIcloudHelpFaq1}',
                  '• ${l10n.cloudIcloudHelpFaq2}',
                  '• ${l10n.cloudIcloudHelpFaq3}',
                  '• ${l10n.cloudIcloudHelpFaq4}',
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BeeTokens.brandIcloud.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: BeeTokens.brandIcloud, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.cloudIcloudHelpNote,
                        style: TextStyle(
                          fontSize: 13,
                          color: BeeTokens.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
  }

  void _showS3HelpDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.storage, color: BeeTokens.brandS3),
            const SizedBox(width: 8),
            Text(l10n.cloudS3HelpTitle),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(
                l10n.cloudS3HelpIntro,
                [
                  l10n.cloudS3HelpIntro1,
                  l10n.cloudS3HelpIntro2,
                  l10n.cloudS3HelpIntro3,
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                l10n.cloudS3HelpProviders,
                [
                  l10n.cloudS3HelpProvider1,
                  l10n.cloudS3HelpProvider2,
                  l10n.cloudS3HelpProvider3,
                  l10n.cloudS3HelpProvider4,
                  l10n.cloudS3HelpProvider5,
                  l10n.cloudS3HelpProvider6,
                  l10n.cloudS3HelpProvider7,
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                l10n.cloudS3HelpSteps,
                [
                  l10n.cloudS3HelpStep1,
                  l10n.cloudS3HelpStep2,
                  l10n.cloudS3HelpStep3,
                  l10n.cloudS3HelpStep4,
                  l10n.cloudS3HelpStep5,
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BeeTokens.brandS3.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: BeeTokens.brandS3, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.cloudS3HelpNote,
                        style: TextStyle(
                          fontSize: 13,
                          color: BeeTokens.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: BeeTokens.textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Text(
            item,
            style: TextStyle(
              fontSize: 13,
              color: BeeTokens.textSecondary(context),
            ),
          ),
        )),
      ],
    );
  }

  Future<void> _openGuide(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        showToast(context, AppLocalizations.of(context).cloudCannotOpenLink);
      }
    }
  }

  Future<void> _switchService(CloudBackendType type) async {
    final store = ref.read(cloudServiceStoreProvider);
    final active = await ref.read(activeCloudConfigProvider.future);

    if (active.type == type) return; // 已经是当前类型

    // iCloud: 先检查可用性
    if (type == CloudBackendType.icloud) {
      logger.info('CloudService', '========== 开始 iCloud 诊断 ==========');
      final icloudProvider = ICloudProvider();
      try {
        // 获取详细诊断信息
        final diagnostics = await icloudProvider.getDiagnostics();
        logger.info('CloudService', 'iCloud 诊断信息:');
        diagnostics.forEach((key, value) {
          logger.info('CloudService', '  $key: $value');
        });

        final isAvailable = await icloudProvider.isAvailable();
        logger.info('CloudService', 'iCloud 可用性: $isAvailable');
        logger.info('CloudService', '========== iCloud 诊断结束 ==========');

        if (!isAvailable) {
          if (mounted) {
            // 显示更详细的错误信息
            final cloudKitStatus = diagnostics['cloudKitStatus'] ?? 'unknown';
            final containerAvailable = diagnostics['containerAvailable'] ?? false;
            var detailMessage = AppLocalizations.of(context).cloudIcloudNotAvailableMessage;
            if (cloudKitStatus == 'noAccount') {
              detailMessage = '请在设置中登录 iCloud 账号';
            } else if (!containerAvailable) {
              detailMessage = 'iCloud 容器不可用，请确保 iCloud Drive 已开启';
            }
            await AppDialog.error(
              context,
              title: AppLocalizations.of(context).cloudIcloudNotAvailableTitle,
              message: detailMessage,
            );
          }
          return;
        }
      } catch (e, stack) {
        logger.error('CloudService', 'iCloud 可用性检查失败', e, stack);
        if (mounted) {
          await AppDialog.error(
            context,
            title: AppLocalizations.of(context).cloudIcloudNotAvailableTitle,
            message: 'iCloud 检查失败: $e',
          );
        }
        return;
      }
    }

    // 确认切换
    if (!mounted) return;
    final confirmed = await AppDialog.confirm(
      context,
      title: AppLocalizations.of(context).cloudSwitchConfirmTitle,
      message: AppLocalizations.of(context).cloudSwitchConfirmMessage,
    );
    if (!confirmed || !mounted) return;

    try {
      // 登出（iCloud 使用系统账号，跳过登出）
      if (active.type != CloudBackendType.icloud && active.type != CloudBackendType.local) {
        try {
          final authService = await ref.read(authServiceProvider.future);
          await authService.signOut();
        } catch (_) {
          // 忽略登出错误
        }
      }

      // 激活新配置
      final success = await store.activate(type);
      if (!success && type != CloudBackendType.local && type != CloudBackendType.icloud) {
        if (mounted) {
          await AppDialog.error(context, title: AppLocalizations.of(context).cloudSwitchFailedTitle, message: AppLocalizations.of(context).cloudSwitchFailedConfigMissing);
        }
        return;
      }

      // 延迟刷新 providers，避免在 build 阶段触发 setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.invalidate(activeCloudConfigProvider);
        ref.invalidate(supabaseConfigProvider);
        ref.invalidate(webdavConfigProvider);
        ref.invalidate(authServiceProvider);
        ref.invalidate(syncServiceProvider);
      });

      if (mounted) {
        showToast(context, AppLocalizations.of(context).cloudSwitchedTo(_getTypeName(type)));
      }
    } catch (e) {
      if (mounted) {
        await AppDialog.error(context, title: AppLocalizations.of(context).cloudSwitchFailedTitle, message: '$e');
      }
    }
  }

  Future<void> _configureService(CloudBackendType type) async {
    // 根据类型显示配置对话框
    if (type == CloudBackendType.beecountCloud) {
      await _showBeeCountCloudConfigDialog();
    } else if (type == CloudBackendType.supabase) {
      await _showSupabaseConfigDialog();
    } else if (type == CloudBackendType.webdav) {
      await _showWebdavConfigDialog();
    } else if (type == CloudBackendType.s3) {
      await _showS3ConfigDialog();
    }
  }

  Future<void> _showBeeCountCloudConfigDialog() async {
    final existing = await ref.read(beecountCloudConfigProvider.future);

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) => _BeeCountCloudConfigDialog(
        initialUrl: existing?.beecountCloudBaseUrl ?? '',
        initialApiPrefix: existing?.beecountCloudApiPrefix ?? '/api/v1',
        initialEmail: existing?.beecountCloudEmail ?? '',
        initialPassword: existing?.beecountCloudPassword ?? '',
      ),
    );

    if (result != null) {
      final url = result['url'] as String;
      final apiPrefix = result['apiPrefix'] as String;
      final email = result['email'] as String;
      final password = result['password'] as String;

      if (url.isEmpty) {
        if (mounted) {
          await AppDialog.error(context, title: AppLocalizations.of(context).cloudConfigInvalidTitle, message: AppLocalizations.of(context).cloudConfigInvalidMessage);
        }
        return;
      }

      final cfg = CloudServiceConfig(
        type: CloudBackendType.beecountCloud,
        name: AppLocalizations.of(context).cloudBeeCountCloudTitle,
        beecountCloudBaseUrl: url,
        beecountCloudApiPrefix: apiPrefix.isEmpty ? '/api/v1' : apiPrefix,
        beecountCloudEmail: email.isNotEmpty ? email : null,
        beecountCloudPassword: password.isNotEmpty ? password : null,
      );

      if (!cfg.valid) {
        if (mounted) {
          await AppDialog.error(context, title: AppLocalizations.of(context).cloudConfigInvalidTitle, message: AppLocalizations.of(context).cloudConfigInvalidMessage);
        }
        return;
      }

      try {
        await ref.read(cloudServiceStoreProvider).saveOnly(cfg);
        ref.invalidate(beecountCloudConfigProvider);
        ref.invalidate(activeCloudConfigProvider);
        if (mounted) showToast(context, AppLocalizations.of(context).cloudConfigSaved);

        // 如果提供了邮箱和密码，尝试登录（恢复旧行为）
        if (email.isNotEmpty && password.isNotEmpty) {
          try {
            final services = await createCloudServices(cfg);
            if (services.auth != null) {
              await services.auth!.signInWithEmail(
                email: email,
                password: password,
              );
              ref.invalidate(authServiceProvider);
              ref.invalidate(syncServiceProvider);

              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('auto_sync', true);
              ref.invalidate(autoSyncValueProvider);

              Future(() async {
                try {
                  final sync = ref.read(syncServiceProvider);
                  final ledgerId = ref.read(currentLedgerIdProvider);
                  await sync.uploadCurrentLedger(ledgerId: ledgerId);
                  ref.read(syncStatusRefreshProvider.notifier).state++;
                  ref.read(ledgerListRefreshProvider.notifier).state++;
                } catch (e) {
                  logger.error('CloudServicePage', 'BeeCount Cloud 首次同步失败', e);
                }
              });

              if (mounted) {
                showToast(context, AppLocalizations.of(context).cloudBeeCountCloudLoginSuccess);
              }
            }
          } catch (e) {
            if (mounted) {
              await AppDialog.error(
                context,
                title: AppLocalizations.of(context).cloudBeeCountCloudLoginFailed,
                message: e.toString(),
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          await AppDialog.error(context, title: AppLocalizations.of(context).cloudSaveFailed, message: e.toString());
        }
      }
    }
  }

  Future<void> _showSupabaseConfigDialog() async {
    final existing = await ref.read(supabaseConfigProvider.future);

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) => _SupabaseConfigDialog(
        initialUrl: existing?.supabaseUrl ?? '',
        initialKey: existing?.supabaseAnonKey ?? '',
        initialBucket: existing?.supabaseBucket ?? '',
      ),
    );

    if (result != null) {
      final url = result['url'] as String;
      final key = result['key'] as String;
      final bucket = result['bucket'] as String;

      if (url.isEmpty || key.isEmpty) {
        if (mounted) {
          await AppDialog.error(context, title: AppLocalizations.of(context).cloudConfigInvalidTitle, message: AppLocalizations.of(context).cloudConfigInvalidMessage);
        }
        return;
      }

      final cfg = CloudServiceConfig(
        type: CloudBackendType.supabase,
        name: AppLocalizations.of(context).cloudCustomSupabaseTitle,
        supabaseUrl: url,
        supabaseAnonKey: key,
        supabaseBucket: bucket.isEmpty ? 'beecount-backups' : bucket,  // 业务层提供默认值
      );

      if (!cfg.valid) {
        if (mounted) {
          await AppDialog.error(context, title: AppLocalizations.of(context).cloudConfigInvalidTitle, message: AppLocalizations.of(context).cloudConfigInvalidMessage);
        }
        return;
      }

      try {
        await ref.read(cloudServiceStoreProvider).saveOnly(cfg);
        ref.invalidate(supabaseConfigProvider);
        // 刷新激活配置，确保同步服务使用最新配置
        ref.invalidate(activeCloudConfigProvider);
        if (mounted) showToast(context, AppLocalizations.of(context).cloudConfigSaved);
      } catch (e) {
        if (mounted) {
          await AppDialog.error(context, title: AppLocalizations.of(context).cloudSaveFailed, message: e.toString());
        }
      }
    }
  }

  Future<void> _showWebdavConfigDialog() async {
    final existing = await ref.read(webdavConfigProvider.future);

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) => _WebdavConfigDialog(
        initialUrl: existing?.webdavUrl ?? '',
        initialUsername: existing?.webdavUsername ?? '',
        initialPassword: existing?.webdavPassword ?? '',
        initialPath: existing?.webdavRemotePath ?? '/',
      ),
    );

    if (result != null) {
      final url = result['url'] as String;
      final username = result['username'] as String;
      final password = result['password'] as String;
      final path = result['path'] as String;

      if (url.isEmpty || username.isEmpty || password.isEmpty) {
        if (mounted) {
          await AppDialog.error(context, title: AppLocalizations.of(context).cloudConfigInvalidTitle, message: AppLocalizations.of(context).cloudConfigInvalidMessage);
        }
        return;
      }

      final cfg = CloudServiceConfig(
        type: CloudBackendType.webdav,
        name: AppLocalizations.of(context).cloudCustomWebdavTitle,
        webdavUrl: url,
        webdavUsername: username,
        webdavPassword: password,
        webdavRemotePath: path.isEmpty ? '/' : path,
      );

      if (!cfg.valid) {
        if (mounted) {
          await AppDialog.error(context, title: AppLocalizations.of(context).cloudConfigInvalidTitle, message: AppLocalizations.of(context).cloudConfigInvalidMessage);
        }
        return;
      }

      try {
        await ref.read(cloudServiceStoreProvider).saveOnly(cfg);
        ref.invalidate(webdavConfigProvider);
        // 刷新激活配置，确保同步服务使用最新配置
        ref.invalidate(activeCloudConfigProvider);
        if (mounted) showToast(context, AppLocalizations.of(context).cloudConfigSaved);
      } catch (e) {
        if (mounted) {
          await AppDialog.error(context, title: AppLocalizations.of(context).cloudSaveFailed, message: e.toString());
        }
      }
    }
  }

  Future<void> _showS3ConfigDialog() async {
    final existing = await ref.read(s3ConfigProvider.future);

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) => _S3ConfigDialog(
        initialEndpoint: existing?.s3Endpoint ?? '',
        initialRegion: existing?.s3Region ?? 'us-east-1',
        initialAccessKey: existing?.s3AccessKey ?? '',
        initialSecretKey: existing?.s3SecretKey ?? '',
        initialBucket: existing?.s3Bucket ?? '',
        initialUseSSL: existing?.s3UseSSL ?? true,
        initialPort: existing?.s3Port,
      ),
    );

    if (result != null) {
      var endpoint = result['endpoint'] as String;
      final region = result['region'] as String;
      final accessKey = result['accessKey'] as String;
      final secretKey = result['secretKey'] as String;
      final bucket = result['bucket'] as String;
      final useSSL = result['useSSL'] as bool;
      final port = result['port'] as int?;

      if (endpoint.isEmpty || accessKey.isEmpty || secretKey.isEmpty || bucket.isEmpty) {
        if (mounted) {
          await AppDialog.error(context, title: AppLocalizations.of(context).cloudConfigInvalidTitle, message: AppLocalizations.of(context).cloudConfigInvalidMessage);
        }
        return;
      }

      // 自动去除 endpoint 中的 http:// 或 https:// 前缀
      endpoint = endpoint.replaceFirst(RegExp(r'^https?://'), '');

      final cfg = CloudServiceConfig(
        type: CloudBackendType.s3,
        name: AppLocalizations.of(context).cloudCustomS3Title,
        s3Endpoint: endpoint,
        s3Region: region.isEmpty ? 'us-east-1' : region,
        s3AccessKey: accessKey,
        s3SecretKey: secretKey,
        s3Bucket: bucket,
        s3UseSSL: useSSL,
        s3Port: port,
      );

      if (!cfg.valid) {
        if (mounted) {
          await AppDialog.error(context, title: AppLocalizations.of(context).cloudConfigInvalidTitle, message: AppLocalizations.of(context).cloudConfigInvalidMessage);
        }
        return;
      }

      try {
        await ref.read(cloudServiceStoreProvider).saveOnly(cfg);
        ref.invalidate(s3ConfigProvider);
        // 刷新激活配置，确保同步服务使用最新配置
        ref.invalidate(activeCloudConfigProvider);
        if (mounted) showToast(context, AppLocalizations.of(context).cloudConfigSaved);
      } catch (e) {
        if (mounted) {
          await AppDialog.error(context, title: AppLocalizations.of(context).cloudSaveFailed, message: e.toString());
        }
      }
    }
  }

  String _getTypeName(CloudBackendType type) {
    switch (type) {
      case CloudBackendType.local:
        return AppLocalizations.of(context).cloudLocalStorageTitle;
      case CloudBackendType.supabase:
        return 'Supabase';
      case CloudBackendType.webdav:
        return 'WebDAV';
      case CloudBackendType.icloud:
        return 'iCloud';
      case CloudBackendType.s3:
        return 'S3';
      case CloudBackendType.beecountCloud:
        return 'BeeCount Cloud';
    }
  }

  // 测试连接
  Future<void> _testConnection(CloudServiceConfig config, {bool showDialog = true}) async {
    if (!config.valid || config.type == CloudBackendType.local) return;

    setState(() => _testingConnection = true);
    try {
      bool connectionSuccess = false;
      String? errorDetail;

      try {
        switch (config.type) {
          case CloudBackendType.local:
            break;

          case CloudBackendType.supabase:
            // Supabase 连接测试 - 查询不存在的表验证 URL 和 anon key
            // 200 或 404 表示连接正常且 key 有效，401/403 表示 key 无效
            final testUrl = Uri.parse('${config.supabaseUrl}/rest/v1/_beecount_health_check?select=id&limit=1');
            final response = await http.get(
              testUrl,
              headers: {
                'apikey': config.supabaseAnonKey!,
                'Authorization': 'Bearer ${config.supabaseAnonKey}',
              },
            ).timeout(const Duration(seconds: 10));

            if (response.statusCode == 200 || response.statusCode == 404 || response.statusCode == 406) {
              connectionSuccess = true;
            } else if (response.statusCode == 401 || response.statusCode == 403) {
              throw Exception(AppLocalizations.of(context).cloudErrorAuthFailed);
            } else {
              throw Exception(AppLocalizations.of(context).cloudErrorServerStatus('${response.statusCode}'));
            }
            break;

          case CloudBackendType.webdav:
            // WebDAV 连接测试 - 发送 OPTIONS 请求
            final testUrl = Uri.parse(config.webdavUrl!);
            final credentials = base64Encode(
              utf8.encode('${config.webdavUsername}:${config.webdavPassword}'),
            );

            final request = http.Request('OPTIONS', testUrl);
            request.headers['Authorization'] = 'Basic $credentials';

            final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
            final response = await http.Response.fromStream(streamedResponse);

            if (response.statusCode == 200 || response.statusCode == 204) {
              final davHeader = response.headers['dav'];
              if (davHeader != null || response.headers.containsKey('allow')) {
                connectionSuccess = true;
              } else {
                throw Exception(AppLocalizations.of(context).cloudErrorWebdavNotSupported);
              }
            } else if (response.statusCode == 401) {
              throw Exception(AppLocalizations.of(context).cloudErrorAuthFailedCredentials);
            } else if (response.statusCode == 403) {
              throw Exception(AppLocalizations.of(context).cloudErrorAccessDenied);
            } else if (response.statusCode == 404) {
              throw Exception(AppLocalizations.of(context).cloudErrorPathNotFound(testUrl.path));
            } else {
              throw Exception(AppLocalizations.of(context).cloudErrorServerStatus('${response.statusCode}'));
            }
            break;

          case CloudBackendType.icloud:
            // iCloud 连接测试
            final icloudProvider = ICloudProvider();
            final isAvailable = await icloudProvider.isAvailable();
            if (isAvailable) {
              // 尝试初始化容器
              try {
                await icloudProvider.initialize({});
                connectionSuccess = true;
              } catch (e) {
                throw Exception('iCloud 容器初始化失败: $e');
              }
            } else {
              throw Exception('iCloud 不可用，请检查设备是否已登录 iCloud 并开启 iCloud Drive');
            }
            break;

          case CloudBackendType.beecountCloud:
            // BeeCount Cloud 连接测试 - 调用健康检查接口
            try {
              final services = await createCloudServices(config);
              if (services.provider == null) {
                throw Exception('BeeCount Cloud provider 初始化失败');
              }
              // 尝试列出文件验证连接
              await services.provider!.storage.list(path: '');
              connectionSuccess = true;
            } catch (e) {
              String errorMsg = e.toString();
              if (errorMsg.contains('Exception:')) {
                errorMsg = errorMsg.replaceFirst('Exception: ', '');
              }
              throw Exception(errorMsg);
            }
            break;

          case CloudBackendType.s3:
            // S3 连接测试 - 尝试列出对象（ListObjects）
            try {
              // 确保 endpoint 不包含协议前缀（兼容旧配置）
              final cleanedConfig = CloudServiceConfig(
                type: config.type,
                name: config.name,
                s3Endpoint: config.s3Endpoint?.replaceFirst(RegExp(r'^https?://'), ''),
                s3Region: config.s3Region,
                s3AccessKey: config.s3AccessKey,
                s3SecretKey: config.s3SecretKey,
                s3Bucket: config.s3Bucket,
                s3UseSSL: config.s3UseSSL,
                s3Port: config.s3Port,
              );

              logger.info('CloudServicePage', 'S3 连接测试开始: endpoint=${cleanedConfig.s3Endpoint}, bucket=${cleanedConfig.s3Bucket}');

              final services = await createCloudServices(cleanedConfig);

              logger.info('CloudServicePage', 'S3 provider 创建结果: ${services.provider != null ? "成功" : "失败"}');

              if (services.provider == null) {
                throw Exception('S3 provider 初始化失败 - createCloudServices 返回 null');
              }

              // 实际测试连接：尝试列出 bucket 中的文件
              // 这会触发真正的 S3 API 调用，验证凭证和连接
              logger.info('CloudServicePage', 'S3 开始测试列出文件');
              await services.provider!.storage.list(path: '');

              logger.info('CloudServicePage', 'S3 连接测试成功');
              connectionSuccess = true;
            } catch (e, stackTrace) {
              logger.error('CloudServicePage', 'S3 连接测试失败: $e', e, stackTrace);
              // 提取最有用的错误信息
              String errorMsg = e.toString();
              if (errorMsg.contains('CloudConfigurationException:')) {
                errorMsg = errorMsg.replaceFirst('CloudConfigurationException: ', '');
              } else if (errorMsg.contains('Exception:')) {
                errorMsg = errorMsg.replaceFirst('Exception: ', '');
              }
              throw Exception(errorMsg);
            }
            break;
        }
      } on http.ClientException catch (e) {
        connectionSuccess = false;
        errorDetail = AppLocalizations.of(context).cloudErrorNetwork(e.message);
      } on Exception catch (e) {
        connectionSuccess = false;
        errorDetail = e.toString().replaceFirst('Exception: ', '');
      } catch (e) {
        connectionSuccess = false;
        errorDetail = e.toString();
      }

      setState(() {
        _connectionTestResults[config.id] = connectionSuccess;
      });

      // 只在手动测试时显示对话框
      if (mounted && showDialog) {
        if (connectionSuccess) {
          await AppDialog.info(context,
              title: AppLocalizations.of(context).cloudTestSuccessTitle,
              message: AppLocalizations.of(context).cloudTestSuccessMessage);
        } else {
          await AppDialog.error(context,
              title: AppLocalizations.of(context).cloudTestFailedTitle,
              message: errorDetail ?? AppLocalizations.of(context).cloudTestFailedMessage);
        }
      }
    } catch (e) {
      setState(() {
        _connectionTestResults[config.id] = false;
      });
      // 只在手动测试时显示错误对话框
      if (mounted && showDialog) {
        await AppDialog.error(context,
            title: AppLocalizations.of(context).cloudTestErrorTitle,
            message: e.toString());
      }
    } finally {
      if (mounted) setState(() => _testingConnection = false);
    }
  }
}

// Supabase配置对话框(独立Widget,避免controller生命周期问题)
class _BeeCountCloudConfigDialog extends StatefulWidget {
  final String initialUrl;
  final String initialApiPrefix;
  final String initialEmail;
  final String initialPassword;

  const _BeeCountCloudConfigDialog({
    required this.initialUrl,
    required this.initialApiPrefix,
    this.initialEmail = '',
    this.initialPassword = '',
  });

  @override
  State<_BeeCountCloudConfigDialog> createState() => _BeeCountCloudConfigDialogState();
}

class _BeeCountCloudConfigDialogState extends State<_BeeCountCloudConfigDialog> {
  late final TextEditingController urlController;
  late final TextEditingController apiPrefixController;
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();
    urlController = TextEditingController(text: widget.initialUrl);
    apiPrefixController = TextEditingController(text: widget.initialApiPrefix);
    emailController = TextEditingController(text: widget.initialEmail);
    passwordController = TextEditingController(text: widget.initialPassword);
  }

  @override
  void dispose() {
    urlController.dispose();
    apiPrefixController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).cloudConfigureBeeCountCloudTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudBeeCountCloudUrlLabel,
                hintText: AppLocalizations.of(context).cloudBeeCountCloudUrlHint,
              ),
              keyboardType: TextInputType.url,
            ),
            // API Prefix 输入框移除 —— 后端固定 /api/v1,前端用户没有配置场景;
            // 保留 apiPrefixController(默认 /api/v1)让 save 流程不破。
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudBeeCountCloudEmailLabel,
                hintText: AppLocalizations.of(context).cloudBeeCountCloudEmailHint,
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudBeeCountCloudPasswordLabel,
                hintText: AppLocalizations.of(context).cloudBeeCountCloudPasswordHint,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                ),
              ),
              obscureText: obscurePassword,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop({
              'url': urlController.text.trim(),
              'apiPrefix': apiPrefixController.text.trim(),
              'email': emailController.text.trim(),
              'password': passwordController.text.trim(),
            });
          },
          child: Text(AppLocalizations.of(context).commonSave),
        ),
      ],
    );
  }
}

class _SupabaseConfigDialog extends StatefulWidget {
  final String initialUrl;
  final String initialKey;
  final String initialBucket;

  const _SupabaseConfigDialog({
    required this.initialUrl,
    required this.initialKey,
    required this.initialBucket,
  });

  @override
  State<_SupabaseConfigDialog> createState() => _SupabaseConfigDialogState();
}

class _SupabaseConfigDialogState extends State<_SupabaseConfigDialog> {
  late final TextEditingController urlController;
  late final TextEditingController keyController;
  late final TextEditingController bucketController;

  @override
  void initState() {
    super.initState();
    urlController = TextEditingController(text: widget.initialUrl);
    keyController = TextEditingController(text: widget.initialKey);
    bucketController = TextEditingController(text: widget.initialBucket);
  }

  @override
  void dispose() {
    urlController.dispose();
    keyController.dispose();
    bucketController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).cloudConfigureSupabaseTitle),
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
            ),
            const SizedBox(height: 16),
            TextField(
              controller: keyController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudAnonKeyLabel,
                hintText: AppLocalizations.of(context).cloudSupabaseAnonKeyHintLong,
              ),
              keyboardType: TextInputType.text,
              minLines: 1,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bucketController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudSupabaseBucketLabel,
                hintText: AppLocalizations.of(context).cloudSupabaseBucketHint,
              ),
              keyboardType: TextInputType.text,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop({
              'url': urlController.text.trim(),
              'key': keyController.text.trim(),
              'bucket': bucketController.text.trim(),
            });
          },
          child: Text(AppLocalizations.of(context).commonSave),
        ),
      ],
    );
  }
}

// WebDAV配置对话框(独立Widget,避免controller生命周期问题)
class _WebdavConfigDialog extends StatefulWidget {
  final String initialUrl;
  final String initialUsername;
  final String initialPassword;
  final String initialPath;

  const _WebdavConfigDialog({
    required this.initialUrl,
    required this.initialUsername,
    required this.initialPassword,
    required this.initialPath,
  });

  @override
  State<_WebdavConfigDialog> createState() => _WebdavConfigDialogState();
}

class _WebdavConfigDialogState extends State<_WebdavConfigDialog> {
  late final TextEditingController urlController;
  late final TextEditingController usernameController;
  late final TextEditingController passwordController;
  late final TextEditingController pathController;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();
    urlController = TextEditingController(text: widget.initialUrl);
    usernameController = TextEditingController(text: widget.initialUsername);
    passwordController = TextEditingController(text: widget.initialPassword);
    pathController = TextEditingController(text: widget.initialPath);
  }

  @override
  void dispose() {
    urlController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).cloudConfigureWebdavTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudWebdavUrlLabel,
                hintText: AppLocalizations.of(context).cloudWebdavUrlHint,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: usernameController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudWebdavUsernameLabel,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudWebdavPasswordLabel,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                ),
              ),
              obscureText: obscurePassword,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pathController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudWebdavRemotePathLabel,
                hintText: AppLocalizations.of(context).cloudWebdavPathHint,
                helperText: AppLocalizations.of(context).cloudWebdavRemotePathHelperText,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop({
              'url': urlController.text.trim(),
              'username': usernameController.text.trim(),
              'password': passwordController.text.trim(),
              'path': pathController.text.trim(),
            });
          },
          child: Text(AppLocalizations.of(context).commonSave),
        ),
      ],
    );
  }
}

// S3配置对话框(独立Widget,避免controller生命周期问题)
class _S3ConfigDialog extends StatefulWidget {
  final String initialEndpoint;
  final String initialRegion;
  final String initialAccessKey;
  final String initialSecretKey;
  final String initialBucket;
  final bool initialUseSSL;
  final int? initialPort;

  const _S3ConfigDialog({
    required this.initialEndpoint,
    required this.initialRegion,
    required this.initialAccessKey,
    required this.initialSecretKey,
    required this.initialBucket,
    required this.initialUseSSL,
    this.initialPort,
  });

  @override
  State<_S3ConfigDialog> createState() => _S3ConfigDialogState();
}

class _S3ConfigDialogState extends State<_S3ConfigDialog> {
  late final TextEditingController endpointController;
  late final TextEditingController regionController;
  late final TextEditingController accessKeyController;
  late final TextEditingController secretKeyController;
  late final TextEditingController bucketController;
  late final TextEditingController portController;
  late bool useSSL;
  bool obscureSecretKey = true;

  @override
  void initState() {
    super.initState();
    endpointController = TextEditingController(text: widget.initialEndpoint);
    regionController = TextEditingController(text: widget.initialRegion);
    accessKeyController = TextEditingController(text: widget.initialAccessKey);
    secretKeyController = TextEditingController(text: widget.initialSecretKey);
    bucketController = TextEditingController(text: widget.initialBucket);
    portController = TextEditingController(text: widget.initialPort?.toString() ?? '');
    useSSL = widget.initialUseSSL;
  }

  @override
  void dispose() {
    endpointController.dispose();
    regionController.dispose();
    accessKeyController.dispose();
    secretKeyController.dispose();
    bucketController.dispose();
    portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).cloudConfigureS3Title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: endpointController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudS3EndpointLabel,
                hintText: AppLocalizations.of(context).cloudS3EndpointHint,
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: regionController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudS3RegionLabel,
                hintText: AppLocalizations.of(context).cloudS3RegionHint,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: accessKeyController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudS3AccessKeyLabel,
                hintText: AppLocalizations.of(context).cloudS3AccessKeyHint,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: secretKeyController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudS3SecretKeyLabel,
                hintText: AppLocalizations.of(context).cloudS3SecretKeyHint,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureSecretKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      obscureSecretKey = !obscureSecretKey;
                    });
                  },
                ),
              ),
              obscureText: obscureSecretKey,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bucketController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudS3BucketLabel,
                hintText: AppLocalizations.of(context).cloudS3BucketHint,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(AppLocalizations.of(context).cloudS3UseSSLLabel),
                ),
                Switch(
                  value: useSSL,
                  onChanged: (value) {
                    setState(() {
                      useSSL = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: portController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).cloudS3PortLabel,
                hintText: AppLocalizations.of(context).cloudS3PortHint,
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final portText = portController.text.trim();
            final port = portText.isEmpty ? null : int.tryParse(portText);

            Navigator.of(context).pop({
              'endpoint': endpointController.text.trim(),
              'region': regionController.text.trim(),
              'accessKey': accessKeyController.text.trim(),
              'secretKey': secretKeyController.text.trim(),
              'bucket': bucketController.text.trim(),
              'useSSL': useSSL,
              'port': port,
            });
          },
          child: Text(AppLocalizations.of(context).commonSave),
        ),
      ],
    );
  }
}
