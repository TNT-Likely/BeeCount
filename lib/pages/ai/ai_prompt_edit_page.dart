import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/ui/ui.dart';
import '../../widgets/biz/section_card.dart';
import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../providers/theme_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ai/core/prompt_builder.dart';
import '../../ai/providers/ai_constants.dart';
import '../../ai/providers/ai_provider_manager.dart';

/// AI提示词编辑页面
class AIPromptEditPage extends ConsumerStatefulWidget {
  const AIPromptEditPage({super.key});

  @override
  ConsumerState<AIPromptEditPage> createState() => _AIPromptEditPageState();
}

class _AIPromptEditPageState extends ConsumerState<AIPromptEditPage> {
  late TextEditingController _promptController;
  bool _loading = true;
  bool _hasChanges = false;
  String _savedPrompt = '';

  /// 使用 PromptBuilder 中定义的默认模板
  static String get defaultPrompt => PromptBuilder.defaultTemplate;

  /// 变量说明列表 —— 从 [PromptBuilder.placeholders] 登记表生成,不再手工维护
  /// (以前手写导致 `{{BILL_GUARD}}` 一直漏列)。
  List<Map<String, String>> _getVariables(AppLocalizations l10n) => [
        for (final p in PromptBuilder.placeholders)
          {'name': p.token, 'desc': _placeholderDesc(p.token, l10n)},
      ];

  String _placeholderDesc(String token, AppLocalizations l10n) => switch (token) {
        '{{BILL_GUARD}}' => l10n.aiPromptVarBillGuard,
        '{{INPUT_SOURCE}}' => l10n.aiPromptVarInputSource,
        '{{CURRENT_TIME}}' => l10n.aiPromptVarCurrentTime,
        '{{CURRENT_DATE}}' => l10n.aiPromptVarCurrentDate,
        '{{OCR_TEXT}}' => l10n.aiPromptVarOcrText,
        '{{CATEGORIES}}' => l10n.aiPromptVarCategories,
        '{{ACCOUNTS}}' => l10n.aiPromptVarAccounts,
        '{{CURRENCIES}}' => l10n.aiPromptVarCurrencies,
        _ => token,
      };

  /// 当前模板缺失的、会导致能力失效的占位符(.docs/multi-currency-ai A7)。
  ///
  /// **无状态检测**:直接算「默认模板的占位符集合 − 用户模板里有的」,不引版本
  /// 号 —— 自定义模板会随 ai_config 跨设备同步,版本号会在多端间漂移;集合差在
  /// 哪台设备上算都一样。
  ///
  /// 只报**能力性**占位符(见 [PromptPlaceholder.warnIfMissing]):自定义模板与
  /// 默认模板的文本差异是天然的,把差异本身报成警告会变成一条永远消不掉的黄条。
  List<PromptPlaceholder> get _missingPlaceholders =>
      PromptBuilder.missingPlaceholdersIn(_promptController.text);

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController();
    _loadPrompt();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _loadPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AIConstants.keyAiCustomPrompt);
    // 空字符串也回退到默认，避免编辑页显示空内容
    final customPrompt =
        (saved != null && saved.trim().isNotEmpty) ? saved : defaultPrompt;

    setState(() {
      _promptController.text = customPrompt;
      _savedPrompt = customPrompt;
      _loading = false;
    });
  }

  Future<void> _savePrompt() async {
    // 走 AIProviderManager.saveCustomPrompt 而不是直接 setString,
    // 这样 onConfigChanged 能触发把整组 AI 配置推到 server,跨设备同步。
    await AIProviderManager.saveCustomPrompt(_promptController.text);

    setState(() {
      _savedPrompt = _promptController.text;
      _hasChanges = false;
    });

    if (mounted) {
      showToast(context, AppLocalizations.of(context).aiPromptSaved);
    }
  }

  Future<void> _resetToDefault() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.aiPromptResetConfirmTitle),
        content: Text(l10n.aiPromptResetConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _promptController.text = defaultPrompt;
        _hasChanges = _promptController.text != _savedPrompt;
      });
    }
  }

  /// 把某个占位符的段落追加到用户模板末尾(A7 方案 a 的一键补丁)。
  ///
  /// **不整段重置** —— 用户的定制照旧保留,只补上缺的能力;也**不自动保存**,
  /// 让用户先看一眼再点保存。只有 [PromptPlaceholder.appendSnippet] 非空的占位符
  /// 才提供这个按钮:`{{BILL_GUARD}}` 必须在最前面、`{{OCR_TEXT}}` 位置有语义,
  /// 盲目追加到末尾反而会写坏模板。
  void _insertPlaceholderSection(PromptPlaceholder p) {
    final snippet = p.appendSnippet;
    if (snippet == null) return;
    final text = _promptController.text.trimRight();
    _promptController.text = '$text\n$snippet';
    setState(() {
      _hasChanges = _promptController.text != _savedPrompt;
    });
    showToast(
        context, AppLocalizations.of(context).aiPromptVarSectionInserted(p.token));
  }

  Future<void> _pastePrompt() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _promptController.text = data.text!;
        _hasChanges = _promptController.text != _savedPrompt;
      });
      if (mounted) {
        showToast(context, AppLocalizations.of(context).aiPromptPasted);
      }
    }
  }

  /// 分享提示词
  Future<void> _sharePrompt() async {
    final l10n = AppLocalizations.of(context);
    final text = _promptController.text;
    if (text.isEmpty) return;

    await Share.share(
      text,
      subject: l10n.aiPromptEditTitle,
    );
  }

  /// 生成预览内容
  String _generatePreview() {
    final template = _promptController.text;

    // 获取当前日期时间
    final now = DateTime.now();
    final currentDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final currentHour = now.hour.toString().padLeft(2, '0');
    final currentMinute = now.minute.toString().padLeft(2, '0');
    final currentTime = '$currentDate $currentHour:$currentMinute';

    // 示例分类
    const exampleCategories = '分类列表：\n支出：餐饮、交通、购物、娱乐、居家\n收入：工资、理财、红包';

    // 示例账户(多币种:外币账户会带币种后缀)
    const exampleAccounts = '\n账户列表：微信、支付宝、现金、Chase(USD)';

    // 示例币种上下文
    const exampleCurrencies = '\n账本主币种：CNY；账本内已有外币账户：USD';

    // 示例OCR文本
    const exampleOcrText = '商品名称：星巴克拿铁咖啡\n金额：￥35.00\n支付时间：2025-01-15 14:30';

    // 示例输入源描述
    const exampleInputSource = '从以下支付账单文本中';

    // 替换变量
    return template
        .replaceAll('{{INPUT_SOURCE}}', exampleInputSource)
        .replaceAll('{{CURRENT_TIME}}', currentTime)
        .replaceAll('{{CURRENT_DATE}}', currentDate)
        .replaceAll('{{OCR_TEXT}}', exampleOcrText)
        .replaceAll('{{CATEGORIES}}', exampleCategories)
        .replaceAll('{{ACCOUNTS}}', exampleAccounts)
        .replaceAll('{{CURRENCIES}}', exampleCurrencies);
  }

  /// 显示预览对话框
  void _showPreviewDialog() {
    final l10n = AppLocalizations.of(context);
    final preview = _generatePreview();
    final primaryColor = ref.read(primaryColorProvider);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.preview, color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.aiPromptPreviewTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // 预览内容
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    preview,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              // 底部说明
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BeeTokens.surfaceHeader(context),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.aiPromptPreviewNote,
                  style: TextStyle(
                    fontSize: 12,
                    color: BeeTokens.textSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);

    if (_loading) {
      return Scaffold(
        backgroundColor: BeeTokens.scaffoldBackground(context),
        body: Column(
          children: [
            PrimaryHeader(
              title: l10n.aiPromptEditTitle,
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
            title: l10n.aiPromptEditTitle,
            subtitle: l10n.aiPromptEditSubtitle,
            showBack: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: _sharePrompt,
              ),
              IconButton(
                icon: const Icon(Icons.paste),
                onPressed: _pastePrompt,
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: 12.0.scaled(context, ref),
                vertical: 8.0.scaled(context, ref),
              ),
              children: [
                // 变量说明
                _buildVariablesSection(primaryColor),

                // 能力缺失提示(A7):默认模板新增占位符后,老的自定义模板拿不到
                // 对应能力 —— 我们不覆盖用户模板,只给提示 + 可安全追加的一键补丁。
                if (_missingPlaceholders.isNotEmpty) ...[
                  SizedBox(height: 8.0.scaled(context, ref)),
                  _buildMissingPlaceholderHint(primaryColor),
                ],

                SizedBox(height: 8.0.scaled(context, ref)),

                // 提示词编辑区
                _buildPromptEditor(primaryColor),

                SizedBox(height: 8.0.scaled(context, ref)),

                // 操作按钮
                _buildActionButtons(primaryColor),

                SizedBox(height: 16.0.scaled(context, ref)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariablesSection(Color primaryColor) {
    final l10n = AppLocalizations.of(context);
    final variables = _getVariables(l10n);

    return SectionCard(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: Icon(Icons.code, color: primaryColor, size: 20),
        title: Text(
          l10n.aiPromptVariables,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(l10n.aiPromptVariablesHint, style: const TextStyle(fontSize: 12)),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final v in variables)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            v['name']!,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            v['desc']!,
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
        ],
      ),
    );
  }

  /// 「模板缺能力」提示条:列出缺的占位符 + 可自动补的给按钮 + 恢复默认兜底。
  Widget _buildMissingPlaceholderHint(Color primaryColor) {
    final l10n = AppLocalizations.of(context);
    final missing = _missingPlaceholders;
    final insertable = missing.where((p) => p.appendSnippet != null).toList();
    return SectionCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.aiPromptMissingVarsHint(
                        missing.map((p) => p.token).join('、')),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: BeeTokens.textSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 有安全追加片段的逐个给一键补丁;位置有语义的只提示(上面的变量
            // 说明卡里有它的用途),用户自己放,或者用「恢复默认」兜底。
            for (final p in insertable) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _insertPlaceholderSection(p),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.aiPromptInsertVarSection(p.token)),
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _resetToDefault,
                icon: const Icon(Icons.restore, size: 18),
                label: Text(l10n.aiPromptResetDefault),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BeeTokens.textSecondary(context),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptEditor(Color primaryColor) {
    final l10n = AppLocalizations.of(context);

    return SectionCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  l10n.aiPromptContent,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (_hasChanges)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      l10n.aiPromptUnsaved,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _promptController,
              maxLines: 20,
              minLines: 10,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                height: 1.5,
              ),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(12),
                hintText: l10n.aiPromptInputHint,
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _hasChanges = value != _savedPrompt;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Color primaryColor) {
    final l10n = AppLocalizations.of(context);

    return SectionCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 预览和保存按钮（并排）
            Row(
              children: [
                // 预览按钮
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showPreviewDialog,
                    icon: const Icon(Icons.preview),
                    label: Text(l10n.aiPromptPreview),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 保存按钮
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _hasChanges ? _savePrompt : null,
                    icon: const Icon(Icons.save),
                    label: Text(l10n.aiPromptSave),
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 恢复默认按钮
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _resetToDefault,
                icon: const Icon(Icons.restore),
                label: Text(l10n.aiPromptResetDefault),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BeeTokens.textSecondary(context),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
