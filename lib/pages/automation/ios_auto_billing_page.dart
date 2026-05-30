import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/platform_info.dart';
import '../../widgets/ui/ui.dart';

/// iOS自动记账配置页面
/// 通过快捷指令实现截图自动识别
class IOSAutoBillingPage extends ConsumerStatefulWidget {
  const IOSAutoBillingPage({super.key});

  @override
  ConsumerState<IOSAutoBillingPage> createState() => _IOSAutoBillingPageState();
}

class _IOSAutoBillingPageState extends ConsumerState<IOSAutoBillingPage> {

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = ref.watch(primaryColorProvider);
    final l10n = AppLocalizations.of(context);
    final supportsAppIntents = PlatformInfo.supportsAppIntents;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.autoScreenshotBillingIosTitle,
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 视频教程（置顶）
                _buildTutorialCard(context, primaryColor, l10n),

                const SizedBox(height: 16),

                // iOS 15版本提示
                if (!supportsAppIntents) _buildVersionWarning(context, primaryColor),
                if (!supportsAppIntents) const SizedBox(height: 16),

                // 一键获取快捷指令（主推路径）
                _buildImportCard(context, primaryColor, l10n),

                const SizedBox(height: 16),

                // 功能说明
                _buildInfoCard(
                  context,
                  primaryColor,
                  icon: Icons.info_outline,
                  title: l10n.featureDescription,
                  content: l10n.iosAutoFeatureDesc,
                ),

                const SizedBox(height: 16),

                // 双击背部快速触发说明
                _buildBackTapCard(context, primaryColor, l10n),

                const SizedBox(height: 16),

                // 快捷指令配置指南
                _buildShortcutsGuide(context, primaryColor),

              ],
            ),
          ),
        ],
      ),
    );
  }

  /// iCloud 上预制好的「截屏 → 自动记账」快捷指令，用户点一下即可导入，
  /// 无需手动添加“截屏”操作和连接参数（手动 6 步降级为折叠兜底）。
  static const String _shortcutImportUrl =
      'https://www.icloud.com/shortcuts/fda5016c98eb474f840f2f91396bd241';

  Future<void> _openShortcut(BuildContext context, AppLocalizations l10n) async {
    final url = Uri.parse(_shortcutImportUrl);
    var ok = false;
    if (await canLaunchUrl(url)) {
      ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    if (!ok && context.mounted) {
      showToast(context, l10n.iosAutoImportFailed);
    }
  }

  Widget _buildImportCard(
    BuildContext context,
    Color primaryColor,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    return Card(
      color: primaryColor.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt, color: primaryColor, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.iosAutoImportTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.iosAutoImportDesc,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openShortcut(context, l10n),
                icon: const Icon(Icons.download_rounded, size: 20),
                label: Text(l10n.iosAutoImportButton),
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildBackTapCard(
    BuildContext context,
    Color primaryColor,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    return Card(
      color: primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.touch_app, color: primaryColor, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.iosAutoBackTapTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.iosAutoBackTapDesc,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    Color primaryColor, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primaryColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutsGuide(BuildContext context, Color primaryColor) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      color: primaryColor.withValues(alpha: 0.05),
      // 一键导入是主推路径，手动 6 步默认折叠，作为导入不可用时的兜底
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: Icon(Icons.tune, color: primaryColor, size: 24),
          title: Text(
            l10n.iosAutoManualConfigTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Text(
              l10n.iosAutoManualConfigDesc,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.iosAutoShortcutConfigTitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 8),
            _buildStep(context, '1', l10n.iosAutoShortcutStep1),
            _buildStep(context, '2', l10n.iosAutoShortcutStep2),
            _buildStep(context, '3', l10n.iosAutoShortcutStep3),
            _buildStep(context, '4', l10n.iosAutoShortcutStep4),
            _buildStep(context, '5', l10n.iosAutoShortcutStep5),
            _buildStep(context, '6', l10n.iosAutoShortcutStep6),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.iosAutoShortcutRecommendedTip,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, String number, String text) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTutorialCard(
    BuildContext context,
    Color primaryColor,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: () async {
          final url = Uri.parse('https://xhslink.com/o/fKlXTFfHNm');
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.play_circle_outline,
                  color: primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.iosAutoTutorialTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.iosAutoTutorialDesc,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVersionWarning(BuildContext context, Color primaryColor) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.iosVersionWarningTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.iosVersionWarningDesc,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange.shade700,
                    height: 1.4,
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
