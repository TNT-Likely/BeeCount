import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../../styles/tokens.dart';
import '../../providers/smart_billing_providers.dart';
import '../../providers/theme_providers.dart';
import '../ai/ai_settings_page.dart';
import '../automation/auto_billing_settings_page.dart';
import 'shortcuts_guide_page.dart';
import '../../l10n/app_localizations.dart';

/// Google Play 版本(CI 注入)。截屏自动记账依赖 READ_MEDIA_IMAGES,在 Google
/// Play 渠道被砍掉,这里用来隐藏入口。详见 release.yml 的临时 manifest 配置。
const _isGooglePlayBuild = bool.fromEnvironment('GOOGLE_PLAY', defaultValue: false);

/// 智能记账二级页面
class SmartBillingPage extends ConsumerWidget {
  const SmartBillingPage({super.key});

  /// 显示功能引导弹窗
  void _showFeatureGuideDialog(
    BuildContext context,
    String title,
    String description,
    String aiRequirement,
    bool requiresAI, {
    String? actionHint,
  }) {
    final l10n = AppLocalizations.of(context);
    final hint = actionHint ?? l10n.smartBillingGuideHint;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: requiresAI
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: requiresAI ? Colors.orange : Colors.blue,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    requiresAI ? Icons.warning_amber : Icons.psychology,
                    color: requiresAI ? Colors.orange : Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      aiRequirement,
                      style: TextStyle(
                        fontSize: 13,
                        color: requiresAI ? Colors.orange[900] : Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hint,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonKnow),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.smartBillingPageTitle,
            subtitle: l10n.smartBillingPageSubtitle,
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // AI设置卡片
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // AI智能识别设置
                      AppListTile(
                        leading: Icons.psychology_outlined,
                        title: l10n.aiSettingsTitle,
                        subtitle: l10n.aiSettingsSubtitle,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AISettingsPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 快速记账功能引导
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // 图片记账
                      AppListTile(
                        leading: Icons.photo_library_outlined,
                        title: l10n.smartBillingImageBilling,
                        subtitle: l10n.smartBillingImageBillingDesc,
                        onTap: () {
                          _showFeatureGuideDialog(
                            context,
                            l10n.smartBillingImageBilling,
                            l10n.smartBillingImageBillingGuide,
                            l10n.smartBillingVisionAIRequired,
                            true,
                          );
                        },
                      ),
                      BeeTokens.cardDivider(context),

                      // 拍照记账
                      AppListTile(
                        leading: Icons.camera_alt_outlined,
                        title: l10n.smartBillingCameraBilling,
                        subtitle: l10n.smartBillingCameraBillingDesc,
                        onTap: () {
                          _showFeatureGuideDialog(
                            context,
                            l10n.smartBillingCameraBilling,
                            l10n.smartBillingCameraBillingGuide,
                            l10n.smartBillingVisionAIRequired,
                            true,
                          );
                        },
                      ),
                      BeeTokens.cardDivider(context),

                      // 语音记账
                      AppListTile(
                        leading: Icons.mic_outlined,
                        title: l10n.smartBillingVoiceBilling,
                        subtitle: l10n.smartBillingVoiceBillingDesc,
                        onTap: () {
                          _showFeatureGuideDialog(
                            context,
                            l10n.smartBillingVoiceBilling,
                            l10n.smartBillingVoiceBillingGuide,
                            l10n.smartBillingAIRequired,
                            true,
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 截图自动记账
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // 分享记账（Android：门槛低、GP 版唯一截图类入口，置顶）
                      if (Platform.isAndroid) ...[
                        AppListTile(
                          leading: Icons.share_outlined,
                          title: l10n.shareBilling,
                          subtitle: l10n.shareBillingDesc,
                          onTap: () {
                            _showFeatureGuideDialog(
                              context,
                              l10n.shareBilling,
                              l10n.shareBillingGuide,
                              l10n.smartBillingVisionAIRequired,
                              true,
                              actionHint: l10n.shareBillingActionHint,
                            );
                          },
                        ),
                        BeeTokens.cardDivider(context),
                      ],
                      // 截图自动记账
                      if (!(Platform.isAndroid && _isGooglePlayBuild)) ...[
                        AppListTile(
                          leading: Icons.auto_fix_high,
                          title: Platform.isAndroid
                              ? l10n.autoScreenshotBilling
                              : l10n.autoScreenshotBillingIosTitle,
                          subtitle: Platform.isAndroid
                              ? l10n.autoScreenshotBillingDesc
                              : l10n.autoScreenshotBillingIosDesc,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AutoBillingSettingsPage()),
                            );
                          },
                        ),
                        BeeTokens.cardDivider(context),
                      ],
                      // 快捷指令
                      AppListTile(
                        leading: Icons.app_shortcut,
                        title: l10n.shortcutsGuide,
                        subtitle: l10n.shortcutsGuideDesc,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ShortcutsGuidePage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 智能记账通用设置
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // 自动关联标签
                      AppListTile(
                        leading: Icons.label_outline,
                        title: l10n.smartBillingAutoTags,
                        subtitle: l10n.smartBillingAutoTagsDesc,
                        trailing: Switch.adaptive(
                          value: ref.watch(smartBillingAutoTagsProvider),
                          activeColor: ref.watch(primaryColorProvider),
                          onChanged: (value) {
                            ref.read(smartBillingAutoTagsProvider.notifier).state = value;
                          },
                        ),
                      ),
                      BeeTokens.cardDivider(context),
                      // 自动添加附件
                      AppListTile(
                        leading: Icons.attachment_outlined,
                        title: l10n.smartBillingAutoAttachment,
                        subtitle: l10n.smartBillingAutoAttachmentDesc,
                        trailing: Switch.adaptive(
                          value: ref.watch(smartBillingAutoAttachmentProvider),
                          activeColor: ref.watch(primaryColorProvider),
                          onChanged: (value) {
                            ref.read(smartBillingAutoAttachmentProvider.notifier).state = value;
                          },
                        ),
                      ),
                    ],
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
