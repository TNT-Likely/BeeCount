import 'package:beecount/utils/ui_scale_extensions.dart';
import 'package:beecount/widgets/biz/section_card.dart';
import 'package:beecount/widgets/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../styles/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/theme_providers.dart';
import '../../ai/providers/ai_constants.dart';

/// AI模型选择页
class AIModelSelectionPage extends ConsumerStatefulWidget {
  const AIModelSelectionPage({super.key});

  @override
  ConsumerState<AIModelSelectionPage> createState() => _AIModelSelectionPageState();
}

class _AIModelSelectionPageState extends ConsumerState<AIModelSelectionPage> {
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  bool _loading = true;
  String _glmModel = AIConstants.defaultGlmModel;
  String _glmVisionModel = AIConstants.defaultGlmVisionModel;

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _glmModel = prefs.getString(AIConstants.keyGlmModel) ?? _glmModel;
      _glmVisionModel = prefs.getString(AIConstants.keyGlmVisionModel) ?? _glmVisionModel;
      _loading = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: BeeTokens.scaffoldBackground(context),
        body: Column(
          children: [
            PrimaryHeader(
              title: l10n.aiSettingsTitle,
              showBack: true,
            ),
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.aiSettingsTitle,
            subtitle: l10n.aiSettingsSubtitle,
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: 12.0.scaled(context, ref),
                vertical: 8.0.scaled(context, ref),
              ),
              children: [
                // AI模型选择
                _buildModelSection(),

                SizedBox(height: 8.0.scaled(context, ref))
              ],
            ),
          ),
        ],
      ),
    );
  }



  /// 获取文本模型的显示名称
  String _getModelDisplayName(String modelId, AppLocalizations l10n) {
    switch (modelId) {
      case 'glm-4.6':
        return 'GLM-4.6 (${l10n.aiModelAccurate})';
      case 'glm-4-flash':
        return 'GLM-4-Flash (${l10n.aiModelFast})';
      default:
        return modelId;
    }
  }

  /// 获取视觉模型的显示名称
  String _getVisionModelDisplayName(String modelId, AppLocalizations l10n) {
    switch (modelId) {
      case 'glm-4.6v':
        return 'GLM-4.6V (${l10n.aiModelAccurate})';
      case 'glm-4v-flash':
        return 'GLM-4V-Flash (${l10n.aiModelFast})';
      default:
        return modelId;
    }
  }

  /// 显示文本模型选择弹窗
  void _showModelDialog() {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.read(primaryColorProvider);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.aiModelTitle),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModelDialogOption(
              dialogContext,
              'glm-4.6',
              'GLM-4.6',
              l10n.aiModelAccurate,
              Icons.psychology,
              primaryColor,
              isText: true,
            ),
            _buildModelDialogOption(
              dialogContext,
              'glm-4-flash',
              'GLM-4-Flash',
              l10n.aiModelFast,
              Icons.bolt,
              primaryColor,
              isText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );
  }

  /// 显示视觉模型选择弹窗
  void _showVisionModelDialog() {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.read(primaryColorProvider);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.aiVisionModelTitle),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModelDialogOption(
              dialogContext,
              'glm-4.6v',
              'GLM-4.6V',
              l10n.aiModelAccurate,
              Icons.psychology,
              primaryColor,
              isText: false,
            ),
            _buildModelDialogOption(
              dialogContext,
              'glm-4v-flash',
              'GLM-4V-Flash',
              l10n.aiModelFast,
              Icons.bolt,
              primaryColor,
              isText: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );
  }

  Widget _buildModelDialogOption(
    BuildContext dialogContext,
    String value,
    String title,
    String subtitle,
    IconData icon,
    Color primaryColor, {
    required bool isText,
  }) {
    final l10n = AppLocalizations.of(context);
    final isSelected = isText ? _glmModel == value : _glmVisionModel == value;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? primaryColor : BeeTokens.textTertiary(context),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isSelected ? primaryColor : BeeTokens.textPrimary(context),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: BeeTokens.textSecondary(context),
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: primaryColor)
          : null,
      onTap: () async {
        Navigator.pop(dialogContext);

        setState(() {
          if (isText) {
            _glmModel = value;
          } else {
            _glmVisionModel = value;
          }
        });

        // 立即保存选择
        final prefs = await SharedPreferences.getInstance();
        if (isText) {
          await prefs.setString(AIConstants.keyGlmModel, value);
        } else {
          await prefs.setString(AIConstants.keyGlmVisionModel, value);
        }

        if (mounted) {
          showToast(context, l10n.aiModelSwitched(title));
        }
      },
    );
  }

  Widget _buildModelSection() {
    final l10n = AppLocalizations.of(context);

    return SectionCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.chat_outlined,
              color: ref.watch(primaryColorProvider),
            ),
            title: Text(
              l10n.aiModelTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(_getModelDisplayName(_glmModel, l10n)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showModelDialog,
          ),
          BeeTokens.cardDivider(context),
          ListTile(
            leading: Icon(
              Icons.image_search,
              color: ref.watch(primaryColorProvider),
            ),
            title: Text(
              l10n.aiVisionModelTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(_getVisionModelDisplayName(_glmVisionModel, l10n)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showVisionModelDialog,
          ),
        ],
      ),
    );
  }
}