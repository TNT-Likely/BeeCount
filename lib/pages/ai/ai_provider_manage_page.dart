import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/ui/ui.dart';
import '../../widgets/biz/section_card.dart';
import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../providers/theme_providers.dart';
import '../../ai/providers/ai_provider_config.dart';
import '../../ai/providers/ai_provider_manager.dart';
import '../../ai/providers/ai_provider_factory.dart';
import '../../ai/providers/ai_constants.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/website_urls.dart';

/// AI 服务商管理刷新 Provider
final aiProviderListRefreshProvider = StateProvider<int>((ref) => 0);

/// AI 服务商列表 Provider
final aiProvidersProvider = FutureProvider<List<AIServiceProviderConfig>>((ref) async {
  ref.watch(aiProviderListRefreshProvider);
  return AIProviderManager.getProviders();
});

/// AI 服务商管理页面
class AIProviderManagePage extends ConsumerStatefulWidget {
  const AIProviderManagePage({super.key});

  @override
  ConsumerState<AIProviderManagePage> createState() => _AIProviderManagePageState();
}

class _AIProviderManagePageState extends ConsumerState<AIProviderManagePage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final providersAsync = ref.watch(aiProvidersProvider);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.aiProviderManageTitle,
            subtitle: l10n.aiProviderManageSubtitle,
            showBack: true,
            actions: [
              IconButton(
                icon: Icon(Icons.add, color: BeeTokens.iconPrimary(context)),
                onPressed: () => _addProvider(context),
                tooltip: l10n.aiProviderAdd,
              ),
            ],
          ),
          Expanded(
            child: providersAsync.when(
              data: (providers) => _buildProviderList(providers),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderList(List<AIServiceProviderConfig> providers) {
    final l10n = AppLocalizations.of(context);

    if (providers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: BeeTokens.textTertiary(context),
            ),
            SizedBox(height: 16.0.scaled(context, ref)),
            Text(
              l10n.aiProviderEmpty,
              style: TextStyle(color: BeeTokens.textSecondary(context)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: 12.0.scaled(context, ref),
        vertical: 8.0.scaled(context, ref),
      ),
      itemCount: providers.length,
      itemBuilder: (context, index) {
        final provider = providers[index];
        return Padding(
          padding: EdgeInsets.only(bottom: 8.0.scaled(context, ref)),
          child: _buildProviderCard(provider),
        );
      },
    );
  }

  Widget _buildProviderCard(AIServiceProviderConfig provider) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);

    return SectionCard(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _editProvider(context, provider),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Icon(
                    provider.isBuiltIn ? Icons.verified : Icons.cloud_outlined,
                    color: provider.isBuiltIn ? primaryColor : BeeTokens.textSecondary(context),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (provider.isBuiltIn)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l10n.aiProviderBuiltIn,
                        style: TextStyle(fontSize: 11, color: primaryColor),
                      ),
                    )
                  else
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: BeeTokens.textTertiary(context),
                      ),
                      onPressed: () => _deleteProvider(context, provider),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // 配置状态
              Row(
                children: [
                  _buildCapabilityChip(
                    l10n.aiCapabilityText,
                    provider.supportsText,
                    Icons.chat_outlined,
                  ),
                  const SizedBox(width: 8),
                  _buildCapabilityChip(
                    l10n.aiCapabilityVision,
                    provider.supportsVision,
                    Icons.image_outlined,
                  ),
                  const SizedBox(width: 8),
                  _buildCapabilityChip(
                    l10n.aiCapabilitySpeech,
                    provider.supportsSpeech,
                    Icons.mic_outlined,
                  ),
                ],
              ),

              // API Key 状态
              if (!provider.isValid) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 6),
                      Text(
                        l10n.aiProviderNoApiKey,
                        style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                      ),
                    ],
                  ),
                ),
              ],

              // 底部操作提示
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    l10n.aiProviderTapToEdit,
                    style: TextStyle(
                      fontSize: 12,
                      color: BeeTokens.textTertiary(context),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: BeeTokens.textTertiary(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCapabilityChip(String label, bool enabled, IconData icon) {
    final primaryColor = ref.watch(primaryColorProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: enabled
            ? primaryColor.withValues(alpha: 0.1)
            : BeeTokens.textTertiary(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: enabled ? primaryColor : BeeTokens.textTertiary(context),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: enabled ? primaryColor : BeeTokens.textTertiary(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addProvider(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const AIProviderEditPage(),
      ),
    );

    if (result == true) {
      ref.read(aiProviderListRefreshProvider.notifier).state++;
    }
  }

  Future<void> _editProvider(BuildContext context, AIServiceProviderConfig provider) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AIProviderEditPage(provider: provider),
      ),
    );

    if (result == true) {
      ref.read(aiProviderListRefreshProvider.notifier).state++;
    }
  }

  Future<void> _deleteProvider(BuildContext context, AIServiceProviderConfig provider) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.aiProviderDeleteTitle),
        content: Text(l10n.aiProviderDeleteConfirm(provider.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final deletedMessage = l10n.aiProviderDeleted;
      final success = await AIProviderManager.deleteProvider(provider.id);
      if (success) {
        ref.read(aiProviderListRefreshProvider.notifier).state++;
        if (mounted) {
          showToast(context, deletedMessage);
        }
      }
    }
  }
}

/// AI 服务商编辑页面
class AIProviderEditPage extends ConsumerStatefulWidget {
  final AIServiceProviderConfig? provider;

  const AIProviderEditPage({super.key, this.provider});

  @override
  ConsumerState<AIProviderEditPage> createState() => _AIProviderEditPageState();
}

/// 测试结果状态
enum TestStatus { idle, testing, success, failed }

class _AIProviderEditPageState extends ConsumerState<AIProviderEditPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _textModelController;
  late final TextEditingController _visionModelController;
  late final TextEditingController _audioModelController;

  bool _obscureApiKey = true;
  bool _saving = false;

  // 逐项测试状态
  TestStatus _textTestStatus = TestStatus.idle;
  TestStatus _visionTestStatus = TestStatus.idle;
  TestStatus _speechTestStatus = TestStatus.idle;
  String? _textTestError;
  String? _visionTestError;
  String? _speechTestError;

  bool get _isEditing => widget.provider != null;
  bool get _isBuiltIn => widget.provider?.isBuiltIn ?? false;
  bool get _isTesting =>
      _textTestStatus == TestStatus.testing ||
      _visionTestStatus == TestStatus.testing ||
      _speechTestStatus == TestStatus.testing;

  @override
  void initState() {
    super.initState();
    final p = widget.provider;
    _nameController = TextEditingController(text: p?.name ?? '');
    _apiKeyController = TextEditingController(text: p?.apiKey ?? '');
    _baseUrlController = TextEditingController(text: p?.baseUrl ?? '');
    _textModelController = TextEditingController(text: p?.textModel ?? '');
    _visionModelController = TextEditingController(text: p?.visionModel ?? '');
    _audioModelController = TextEditingController(text: p?.audioModel ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _textModelController.dispose();
    _visionModelController.dispose();
    _audioModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: _isEditing ? l10n.aiProviderEditTitle : l10n.aiProviderAddTitle,
            showBack: true,
            actions: [
              TextButton(
                onPressed: _saving || _isTesting ? null : _saveProvider,
                child: _saving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: BeeTokens.iconPrimary(context),
                        ),
                      )
                    : Text(
                        l10n.commonSave,
                        style: TextStyle(
                          color: BeeTokens.iconPrimary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                // 基本信息
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.aiProviderBasicInfo,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 名称
                        TextField(
                          controller: _nameController,
                          enabled: !_isBuiltIn,
                          decoration: InputDecoration(
                            labelText: l10n.aiProviderName,
                            hintText: l10n.aiProviderNameHint,
                            border: const OutlineInputBorder(),
                            isDense: true,
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: primaryColor, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Base URL（内置服务商不可编辑）
                        TextField(
                          controller: _baseUrlController,
                          enabled: !_isBuiltIn,
                          decoration: InputDecoration(
                            labelText: 'Base URL',
                            hintText: 'https://api.example.com/v1',
                            helperText: _isBuiltIn ? null : l10n.aiCustomBaseUrlHelper,
                            border: const OutlineInputBorder(),
                            isDense: true,
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: primaryColor, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // API Key 标题行（带测试按钮）
                        Row(
                          children: [
                            const Text(
                              'API Key',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            _buildInlineTestButton(
                              status: _textTestStatus,
                              onTest: _testTextCapability,
                              enabled: _apiKeyController.text.isNotEmpty,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _apiKeyController,
                          obscureText: _obscureApiKey,
                          decoration: InputDecoration(
                            hintText: l10n.aiCloudApiKeyHintCustom,
                            border: const OutlineInputBorder(),
                            isDense: true,
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: primaryColor, width: 2),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureApiKey ? Icons.visibility_off : Icons.visibility,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() => _obscureApiKey = !_obscureApiKey);
                              },
                            ),
                          ),
                        ),

                        // 文本测试错误信息
                        if (_textTestStatus == TestStatus.failed && _textTestError != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _textTestError!,
                              style: const TextStyle(fontSize: 12, color: Colors.red),
                            ),
                          ),
                        ],

                        // 内置服务商显示获取Key和教程链接
                        if (_isBuiltIn) ...[
                          const SizedBox(height: 8),
                          Text(
                            l10n.aiCloudApiKeyHelper,
                            style: TextStyle(
                              fontSize: 12,
                              color: BeeTokens.textTertiary(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: _openGlmWebsite,
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: Text(l10n.aiCloudApiGetKey),
                                style: TextButton.styleFrom(
                                  foregroundColor: primaryColor,
                                  textStyle: const TextStyle(fontSize: 13),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _openTutorial,
                                icon: const Icon(Icons.help_outline, size: 16),
                                label: Text(l10n.aiCloudApiTutorial),
                                style: TextButton.styleFrom(
                                  foregroundColor: primaryColor,
                                  textStyle: const TextStyle(fontSize: 13),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 8.0.scaled(context, ref)),

                // 模型配置
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.aiProviderModels,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.aiProviderModelsHint,
                          style: TextStyle(
                            fontSize: 12,
                            color: BeeTokens.textTertiary(context),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 文本模型
                        _buildModelInputWithTest(
                          controller: _textModelController,
                          label: l10n.aiTextModelTitle,
                          hintText: _isBuiltIn ? AIConstants.defaultGlmModel : 'gpt-4o-mini',
                          testStatus: _textTestStatus,
                          testError: _textTestError,
                          onTest: _testTextCapability,
                        ),
                        const SizedBox(height: 16),

                        // 视觉模型
                        _buildModelInputWithTest(
                          controller: _visionModelController,
                          label: l10n.aiVisionModelTitle,
                          hintText: _isBuiltIn ? AIConstants.defaultGlmVisionModel : 'gpt-4o',
                          testStatus: _visionTestStatus,
                          testError: _visionTestError,
                          onTest: _testVisionCapability,
                        ),
                        const SizedBox(height: 16),

                        // 语音模型
                        _buildModelInputWithTest(
                          controller: _audioModelController,
                          label: l10n.aiAudioModelTitle,
                          hintText: _isBuiltIn ? AIConstants.defaultGlmAudioModel : 'whisper-1',
                          testStatus: _speechTestStatus,
                          testError: _speechTestError,
                          onTest: _testSpeechCapability,
                        ),

                        // 一键测试按钮
                        const SizedBox(height: 16),
                        _buildTestAllButton(),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 32.0.scaled(context, ref)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 获取当前配置
  AIServiceProviderConfig _getCurrentConfig() {
    return AIServiceProviderConfig(
      id: widget.provider?.id ?? 'test',
      name: _nameController.text,
      isBuiltIn: _isBuiltIn,
      apiKey: _apiKeyController.text,
      baseUrl: _baseUrlController.text,
      textModel: _textModelController.text,
      visionModel: _visionModelController.text,
      audioModel: _audioModelController.text,
      createdAt: widget.provider?.createdAt ?? DateTime.now(),
    );
  }

  /// 测试文本能力
  Future<void> _testTextCapability() async {
    final l10n = AppLocalizations.of(context);

    if (_apiKeyController.text.isEmpty) {
      showToast(context, l10n.aiProviderNoApiKey);
      return;
    }

    setState(() {
      _textTestStatus = TestStatus.testing;
      _textTestError = null;
    });

    try {
      final config = _getCurrentConfig();
      final (success, error) = await AIProviderFactory.validateTextCapability(config);

      if (mounted) {
        setState(() {
          _textTestStatus = success ? TestStatus.success : TestStatus.failed;
          _textTestError = error;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _textTestStatus = TestStatus.failed;
          _textTestError = '$e';
        });
      }
    }
  }

  /// 测试视觉能力
  Future<void> _testVisionCapability() async {
    final l10n = AppLocalizations.of(context);

    if (_apiKeyController.text.isEmpty) {
      showToast(context, l10n.aiProviderNoApiKey);
      return;
    }

    setState(() {
      _visionTestStatus = TestStatus.testing;
      _visionTestError = null;
    });

    try {
      final config = _getCurrentConfig();
      final (success, error) = await AIProviderFactory.validateVisionCapability(config);

      if (mounted) {
        setState(() {
          _visionTestStatus = success ? TestStatus.success : TestStatus.failed;
          _visionTestError = error;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _visionTestStatus = TestStatus.failed;
          _visionTestError = '$e';
        });
      }
    }
  }

  /// 测试语音能力
  Future<void> _testSpeechCapability() async {
    final l10n = AppLocalizations.of(context);

    if (_apiKeyController.text.isEmpty) {
      showToast(context, l10n.aiProviderNoApiKey);
      return;
    }

    setState(() {
      _speechTestStatus = TestStatus.testing;
      _speechTestError = null;
    });

    try {
      final config = _getCurrentConfig();
      final (success, error) = await AIProviderFactory.validateSpeechCapability(config);

      if (mounted) {
        setState(() {
          _speechTestStatus = success ? TestStatus.success : TestStatus.failed;
          _speechTestError = error;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _speechTestStatus = TestStatus.failed;
          _speechTestError = '$e';
        });
      }
    }
  }

  Future<void> _saveProvider() async {
    final l10n = AppLocalizations.of(context);

    // 验证必填项
    if (!_isBuiltIn) {
      if (_nameController.text.trim().isEmpty) {
        showToast(context, l10n.aiProviderNameRequired);
        return;
      }
      if (_baseUrlController.text.trim().isEmpty) {
        showToast(context, l10n.aiProviderBaseUrlRequired);
        return;
      }
    }

    setState(() => _saving = true);

    try {
      if (_isEditing) {
        // 更新现有服务商
        final updated = widget.provider!.copyWith(
          name: _isBuiltIn ? null : _nameController.text.trim(),
          apiKey: _apiKeyController.text.trim(),
          baseUrl: _isBuiltIn ? null : _baseUrlController.text.trim(),
          textModel: _textModelController.text.trim(),
          visionModel: _visionModelController.text.trim(),
          audioModel: _audioModelController.text.trim(),
        );
        await AIProviderManager.updateProvider(updated);
      } else {
        // 添加新服务商
        await AIProviderManager.addProvider(
          name: _nameController.text.trim(),
          apiKey: _apiKeyController.text.trim(),
          baseUrl: _baseUrlController.text.trim(),
          textModel: _textModelController.text.trim(),
          visionModel: _visionModelController.text.trim(),
          audioModel: _audioModelController.text.trim(),
        );
      }

      if (mounted) {
        showToast(context, l10n.commonSaved);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, '$e');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// 构建带测试按钮的模型输入框
  Widget _buildModelInputWithTest({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required TestStatus testStatus,
    String? testError,
    required VoidCallback onTest,
  }) {
    final primaryColor = ref.watch(primaryColorProvider);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行（带测试按钮）
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            _buildInlineTestButton(
              status: testStatus,
              onTest: onTest,
              enabled: _apiKeyController.text.isNotEmpty && controller.text.isNotEmpty,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 输入框
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            helperText: controller.text.isEmpty ? l10n.aiModelInputHelper : null,
            border: const OutlineInputBorder(),
            isDense: true,
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        // 错误信息
        if (testStatus == TestStatus.failed && testError != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              testError,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
        ],
      ],
    );
  }

  /// 构建一键测试按钮
  Widget _buildTestAllButton() {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);

    final allTesting = _textTestStatus == TestStatus.testing ||
        _visionTestStatus == TestStatus.testing ||
        _speechTestStatus == TestStatus.testing;

    final allSuccess = _textTestStatus == TestStatus.success &&
        _visionTestStatus == TestStatus.success &&
        _speechTestStatus == TestStatus.success;

    final anyFailed = _textTestStatus == TestStatus.failed ||
        _visionTestStatus == TestStatus.failed ||
        _speechTestStatus == TestStatus.failed;

    Color buttonColor;
    String buttonText;
    IconData buttonIcon;

    if (allTesting) {
      buttonColor = primaryColor;
      buttonText = l10n.aiProviderTestRunning;
      buttonIcon = Icons.sync;
    } else if (allSuccess) {
      buttonColor = Colors.green;
      buttonText = l10n.aiProviderTestSuccess;
      buttonIcon = Icons.check_circle;
    } else if (anyFailed) {
      buttonColor = Colors.orange;
      buttonText = l10n.aiProviderTestAllRetry;
      buttonIcon = Icons.refresh;
    } else {
      buttonColor = primaryColor;
      buttonText = l10n.aiProviderTestAll;
      buttonIcon = Icons.play_arrow;
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: allTesting || _apiKeyController.text.isEmpty
            ? null
            : _testAllCapabilities,
        icon: allTesting
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: buttonColor,
                ),
              )
            : Icon(buttonIcon, size: 18),
        label: Text(buttonText),
        style: OutlinedButton.styleFrom(
          foregroundColor: buttonColor,
          side: BorderSide(color: buttonColor.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  /// 一键测试所有能力
  Future<void> _testAllCapabilities() async {
    // 并行测试所有能力
    await Future.wait([
      _testTextCapability(),
      _testVisionCapability(),
      _testSpeechCapability(),
    ]);
  }

  /// 构建内联测试按钮
  Widget _buildInlineTestButton({
    required TestStatus status,
    required VoidCallback onTest,
    required bool enabled,
  }) {
    final primaryColor = ref.watch(primaryColorProvider);
    final l10n = AppLocalizations.of(context);

    Color getColor() {
      switch (status) {
        case TestStatus.idle:
          return enabled ? primaryColor : BeeTokens.textTertiary(context);
        case TestStatus.testing:
          return primaryColor;
        case TestStatus.success:
          return Colors.green;
        case TestStatus.failed:
          return Colors.red;
      }
    }

    String getText() {
      switch (status) {
        case TestStatus.idle:
          return l10n.aiCloudApiTestKey;
        case TestStatus.testing:
          return l10n.aiProviderTestRunning;
        case TestStatus.success:
          return l10n.aiProviderTestSuccess;
        case TestStatus.failed:
          return l10n.aiProviderTestFailed;
      }
    }

    return TextButton.icon(
      onPressed: enabled && status != TestStatus.testing ? onTest : null,
      icon: status == TestStatus.testing
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
            )
          : Icon(
              status == TestStatus.success
                  ? Icons.check_circle
                  : status == TestStatus.failed
                      ? Icons.error
                      : Icons.play_circle_outline,
              size: 16,
              color: getColor(),
            ),
      label: Text(getText()),
      style: TextButton.styleFrom(
        foregroundColor: getColor(),
        textStyle: const TextStyle(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  /// 打开智谱 GLM 网站
  Future<void> _openGlmWebsite() async {
    final uri = Uri.parse('https://open.bigmodel.cn/usercenter/proj-mgmt/apikeys');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// 打开教程
  Future<void> _openTutorial() async {
    final locale = Localizations.localeOf(context);
    final uri = Uri.parse(WebsiteUrls.docsAi('overview', locale));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
