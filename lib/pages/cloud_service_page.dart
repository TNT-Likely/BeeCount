import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../cloud/cloud_service_config.dart';
import '../providers/sync_providers.dart';
import '../widgets/ui/dialog.dart' show AppDialog;
import '../widgets/ui/ui.dart';
import '../widgets/biz/section_card.dart';
import '../styles/colors.dart';
import '../utils/logger.dart';

class CloudServicePage extends ConsumerStatefulWidget {
  const CloudServicePage({super.key});
  @override
  ConsumerState<CloudServicePage> createState() => _CloudServicePageState();
}

class _CloudServicePageState extends ConsumerState<CloudServicePage> {
  final _url = TextEditingController();
  final _key = TextEditingController();
  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(activeCloudConfigProvider);
    final builtin = ref.watch(builtinCloudConfigProvider);
    final firstUpload = ref.watch(firstFullUploadPendingProvider);
    final storedCustom = ref.watch(storedCustomCloudConfigProvider);
    return Scaffold(
      backgroundColor: BeeColors.greyBg,
      body: SafeArea(
        child: Column(
          children: [
            PrimaryHeader(
              title: '云服务',
              showBack: true,
              content: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: activeAsync.when(
                  loading: () => const SizedBox(
                      height: 36,
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                  error: (e, _) => Text('加载失败: $e',
                      style: const TextStyle(color: Colors.redAccent)),
                  data: (active) {
                    final isCustom = !active.builtin;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '当前模式：${isCustom ? "自定义 Supabase" : "默认云服务"}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isCustom
                              ? '使用你提供的 Supabase 实例进行同步'
                              : (builtin.valid
                                  ? '使用应用内置的匿名云端服务'
                                  : '当前构建未内置云服务，处于离线模式'),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: BeeColors.secondaryText),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: activeAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Center(child: Text('加载失败: $e')),
                data: (active) {
                  final isCustom = !active.builtin;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    children: [
                      SectionCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: _buildBuiltinHint(builtin, active),
                        ),
                      ),
                      if (isCustom)
                        SectionCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: _buildCustomSummary(active),
                        )
                      else
                        storedCustom.when(
                          loading: () => const SizedBox(),
                          error: (e, _) => SectionCard(
                              child: ListTile(
                                  leading: const Icon(Icons.error_outline),
                                  title: Text('读取已保存自定义失败: $e'))),
                          data: (saved) {
                            if (saved == null || !saved.valid) {
                              return const SizedBox();
                            }
                            return SectionCard(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: const Icon(Icons.cloud_done_outlined),
                                title: const Text('已保存的自定义配置 (未启用)'),
                                subtitle: Text(
                                    'URL 长度: ${saved.supabaseUrl?.length ?? 0} / Key 长度: ${saved.supabaseAnonKey?.length ?? 0}'),
                                trailing: FilledButton(
                                  onPressed: _saving
                                      ? null
                                      : () async {
                                          setState(() => _saving = true);
                                          try {
                                            try {
                                              await ref
                                                  .read(authServiceProvider)
                                                  .signOut();
                                            } catch (_) {}
                                            final ok = await ref
                                                .read(cloudServiceStoreProvider)
                                                .activateExistingCustomIfAny();
                                            if (!ok) {
                                              if (mounted) {
                                                await AppDialog.error(context,
                                                    title: '启用失败',
                                                    message: '已保存的配置无效');
                                              }
                                            } else {
                                              ref.invalidate(
                                                  activeCloudConfigProvider);
                                              ref.invalidate(
                                                  supabaseClientProvider);
                                              ref.invalidate(
                                                  authServiceProvider);
                                              if (mounted) {
                                                await AppDialog.info(context,
                                                    title: '已启用',
                                                    message:
                                                        '已切换到自定义 Supabase 并已退出登录，请重新登录');
                                              }
                                            }
                                          } finally {
                                            if (mounted)
                                              setState(() => _saving = false);
                                          }
                                        },
                                  child: _saving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Text('启用'),
                                ),
                              ),
                            );
                          },
                        ),
                      if (!_editing)
                        FilledButton.icon(
                          onPressed: () async {
                            setState(() => _editing = true);
                            if (isCustom) {
                              _url.text = active.supabaseUrl ?? '';
                              _key.text = active.supabaseAnonKey ?? '';
                            } else {
                              // 尝试预填已保存配置
                              final saved = await ref
                                  .read(storedCustomCloudConfigProvider.future);
                              if (saved != null && saved.valid) {
                                _url.text = saved.supabaseUrl ?? '';
                                _key.text = saved.supabaseAnonKey ?? '';
                              } else {
                                _url.clear();
                                _key.clear();
                              }
                            }
                          },
                          icon: const Icon(Icons.add_link),
                          label: Text(
                              isCustom ? '修改自定义配置' : '新增 / 修改 自定义 Supabase'),
                        ),
                      if (_editing)
                        SectionCard(
                          margin: const EdgeInsets.only(top: 12),
                          child: _buildEditForm(isCustom: isCustom),
                        ),
                      if (isCustom) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () async {
                                  try {
                                    await ref
                                        .read(authServiceProvider)
                                        .signOut();
                                  } catch (_) {}
                                  await ref
                                      .read(cloudServiceStoreProvider)
                                      .switchToBuiltin();
                                  ref.invalidate(activeCloudConfigProvider);
                                  ref.invalidate(supabaseClientProvider);
                                  ref.invalidate(authServiceProvider);
                                  if (mounted) {
                                    await AppDialog.info(context,
                                        title: '已切换',
                                        message: '已切回默认云服务并已退出登录');
                                  }
                                },
                          child: const Text('切回默认'),
                        ),
                      ],
                      if (isCustom && firstUpload.asData?.value == true) ...[
                        const SizedBox(height: 12),
                        Card(
                          color: Colors.orange.withOpacity(.1),
                          child: const ListTile(
                            leading: Icon(Icons.cloud_upload_outlined,
                                color: Colors.orange),
                            title: Text('首次全量上传尚未完成'),
                            subtitle: Text('登录后在“我的/同步”中手动执行“上传”完成初始化'),
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
      ),
    );
  }

  Widget _buildBuiltinHint(
      CloudServiceConfig builtin, CloudServiceConfig active) {
    final lines = <String>[];
    if (!builtin.valid) {
      lines.add('当前构建未内置 Supabase 配置（离线模式）');
    } else {
      lines.add('默认云服务已可用');
    }
    lines.add('你可以添加自定义 Supabase：仅需 URL 与公共 Anon Key');
    return Text(lines.join('\n'));
  }

  Widget _buildCustomSummary(CloudServiceConfig cfg) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.cloud_done_outlined),
        title: const Text('自定义 Supabase 已启用'),
        subtitle: Text(
            'URL 长度: ${cfg.supabaseUrl?.length ?? 0} / Key 长度: ${cfg.supabaseAnonKey?.length ?? 0}'),
      ),
    );
  }

  Widget _buildEditForm({required bool isCustom}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: 'Supabase URL',
                hintText: 'https://xxx.supabase.co',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _key,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Anon Key',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          final url = _url.text.trim();
                          final key = _key.text.trim();
                          final err = _validate(url, key);
                          if (err != null) {
                            await AppDialog.error(context,
                                title: '无效输入', message: err);
                            return;
                          }
                          setState(() => _saving = true);
                          try {
                            final cfg = CloudServiceConfig(
                              id: 'custom',
                              type: CloudBackendType.supabase,
                              name: '自定义 Supabase',
                              supabaseUrl: url,
                              supabaseAnonKey: key,
                              builtin: false,
                            );
                            // 切换到自定义配置前先登出旧会话
                            try {
                              await ref.read(authServiceProvider).signOut();
                            } catch (_) {}
                            await ref
                                .read(cloudServiceStoreProvider)
                                .saveCustom(cfg);
                            // 使相关 Provider 失效
                            ref.invalidate(activeCloudConfigProvider);
                            ref.invalidate(firstFullUploadPendingProvider);
                            ref.invalidate(supabaseClientProvider);
                            ref.invalidate(authServiceProvider);
                            if (mounted) {
                              await AppDialog.info(context,
                                  title: '已保存',
                                  message:
                                      '自定义 Supabase 已启用并已自动登出，请重新登录后到“上传”执行首次同步。');
                            }
                          } catch (e) {
                            logE('cloudCfg', '保存失败', e);
                            if (mounted) {
                              await AppDialog.error(context,
                                  title: '失败', message: '$e');
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                _saving = false;
                                _editing = false;
                              });
                            }
                          }
                        },
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存并启用'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() => _editing = false);
                        },
                  child: const Text('取消'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('提示：不要填写 service_role Key；Anon Key 为公开可用。',
                style: TextStyle(fontSize: 12, color: Colors.orange)),
          ],
        ),
      ),
    );
  }

  String? _validate(String url, String key) {
    if (url.isEmpty || key.isEmpty) return 'URL 与 Key 均不能为空';
    if (!url.startsWith('https://')) return 'URL 需以 https:// 开头';
    if (key.length < 20) return 'Key 长度过短，可能无效';
    final lower = key.toLowerCase();
    if (lower.contains('service_role')) return '禁止使用 service_role Key';
    return null;
  }
}
