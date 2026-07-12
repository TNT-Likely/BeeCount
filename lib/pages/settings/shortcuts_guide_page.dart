import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../../styles/tokens.dart';
import '../../providers.dart';
import '../../services/platform/app_link_service.dart';

/// 快捷方式引导页面
class ShortcutsGuidePage extends ConsumerWidget {
  const ShortcutsGuidePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final primaryColor = ref.watch(primaryColorProvider);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.shortcutsGuide,
            showBack: true,
            leadingIcon: Icons.app_shortcut,
            leadingPlain: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 简介
                _buildIntroSection(context, l10n, theme),
                const SizedBox(height: 16),

                // 可用快捷方式列表
                _buildShortcutsSection(context, ref, l10n, theme, primaryColor),
                const SizedBox(height: 16),

                // 自动记账 API 说明
                _buildAutoAddSection(context, l10n, theme),
                const SizedBox(height: 16),

                // 添加指引
                _buildAddGuideSection(context, l10n, theme),
                const SizedBox(height: 16),

                // 说明文字
                _buildDescriptionSection(context, l10n, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroSection(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return SectionCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bolt,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.shortcutsIntroTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.shortcutsIntroDesc,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutsSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ThemeData theme,
    Color primaryColor,
  ) {
    final shortcuts = [
      _ShortcutItem(
        icon: Icons.mic,
        title: l10n.shortcutVoice,
        description: l10n.shortcutVoiceDesc,
        url: AppLinkBuilder.voice(),
        color: Colors.orange,
      ),
      _ShortcutItem(
        icon: Icons.photo_library,
        title: l10n.shortcutImage,
        description: l10n.shortcutImageDesc,
        url: AppLinkBuilder.image(),
        color: Colors.green,
      ),
      _ShortcutItem(
        icon: Icons.camera_alt,
        title: l10n.shortcutCamera,
        description: l10n.shortcutCameraDesc,
        url: AppLinkBuilder.camera(),
        color: Colors.blue,
      ),
      _ShortcutItem(
        icon: Icons.remove_circle_outline,
        title: l10n.shortcutNewExpense,
        description: l10n.shortcutNewExpenseDesc,
        url: AppLinkBuilder.newExpense(),
        color: Colors.red,
      ),
      _ShortcutItem(
        icon: Icons.add_circle_outline,
        title: l10n.shortcutNewIncome,
        description: l10n.shortcutNewIncomeDesc,
        url: AppLinkBuilder.newIncome(),
        color: Colors.green,
      ),
      _ShortcutItem(
        icon: Icons.swap_horiz,
        title: l10n.shortcutNewTransfer,
        description: l10n.shortcutNewTransferDesc,
        url: AppLinkBuilder.newTransfer(),
        color: Colors.purple,
      ),
    ];

    return SectionCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.availableShortcuts,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...shortcuts.map((shortcut) => _buildShortcutTile(
                  context,
                  ref,
                  l10n,
                  theme,
                  shortcut,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutTile(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ThemeData theme,
    _ShortcutItem shortcut,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: shortcut.url));
          showToast(context, l10n.shortcutUrlCopied);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: shortcut.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  shortcut.icon,
                  color: shortcut.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shortcut.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shortcut.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shortcut.url,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.copy,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoAddSection(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return SectionCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Colors.amber,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.shortcutAutoAdd,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.shortcutAutoAddDesc,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            // 示例 URL
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.shortcutAutoAddExample,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    'beecount://add?amount=100&type=expense&category=餐饮&note=午餐',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 参数说明
            Text(
              l10n.shortcutAutoAddParams,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildParamRow(theme, 'amount', l10n.shortcutParamAmount, true),
            _buildParamRow(theme, 'type', l10n.shortcutParamType, false),
            _buildParamRow(
                theme, 'category', l10n.shortcutParamCategory, false),
            _buildParamRow(theme, 'note', l10n.shortcutParamNote, false),
            _buildParamRow(theme, 'account', l10n.shortcutParamAccount, false),
            _buildParamRow(theme, 'tags', l10n.shortcutParamTags, false),
            _buildParamRow(theme, 'date', l10n.shortcutParamDate, false),
          ],
        ),
      ),
    );
  }

  Widget _buildParamRow(
      ThemeData theme, String param, String desc, bool required) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: required
                  ? Colors.red.withValues(alpha: 0.1)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              param,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: required ? Colors.red : theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              desc,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddGuideSection(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return SectionCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.howToAddShortcut,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (Platform.isIOS)
              _buildIOSGuide(context, l10n, theme)
            else
              _buildAndroidGuide(context, l10n, theme),

            // iOS 快捷指令 App 入口
            if (Platform.isIOS) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openShortcutsApp(),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.shortcutOpenShortcutsApp),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openShortcutsApp() async {
    // iOS 快捷指令 App 的 URL Scheme
    final uri = Uri.parse('shortcuts://');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _buildIOSGuide(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final steps = [
      l10n.iosShortcutStep1,
      l10n.iosShortcutStep2,
      l10n.iosShortcutStep3,
      l10n.iosShortcutStep4,
      l10n.iosShortcutStep5,
    ];

    return _buildStepsList(steps, theme);
  }

  Widget _buildAndroidGuide(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final steps = [
      l10n.androidShortcutStep1,
      l10n.androidShortcutStep2,
      l10n.androidShortcutStep3,
      l10n.androidShortcutStep4,
    ];

    return _buildStepsList(steps, theme);
  }

  Widget _buildStepsList(List<String> steps, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDescriptionSection(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return SectionCard(
      margin: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.shortcutsTip,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.shortcutsTipDesc,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutItem {
  final IconData icon;
  final String title;
  final String description;
  final String url;
  final Color color;

  const _ShortcutItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.url,
    required this.color,
  });
}
