import '../../../utils/format_utils.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import '../../../utils/currencies.dart';
import '../../../widgets/biz/ledger_picker_sheet.dart';
import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount/widgets/biz/bee_icon.dart';
import '../../../providers.dart';
import '../../../widgets/ui/ui.dart';
import '../../../widgets/biz/biz.dart';
import '../../../services/system/logger_service.dart';
import '../../../services/ui/avatar_service.dart';
import '../../../providers/avatar_providers.dart';
import '../../../providers/sync_providers.dart' as sp;
import '../../../l10n/app_localizations.dart';

/// Profile edits retain the existing avatar, nickname and cloud update services.
class _EditDisplayNameDialog extends StatefulWidget {
  const _EditDisplayNameDialog({required this.initial});

  final String initial;

  @override
  State<_EditDisplayNameDialog> createState() => _EditDisplayNameDialogState();
}

class _EditDisplayNameDialogState extends State<_EditDisplayNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.mineDisplayNameEditTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 20,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(hintText: l10n.mineDisplayNameHint),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) Navigator.pop(context, v);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            final canSave = value.text.trim().isNotEmpty;
            return TextButton(
              onPressed: canSave
                  ? () => Navigator.pop(context, _controller.text)
                  : null,
              child: Text(l10n.commonSave),
            );
          },
        ),
      ],
    );
  }
}

/// 我的页面头部
class MineProfileBinding extends ConsumerStatefulWidget {
  const MineProfileBinding({super.key});

  @override
  ConsumerState<MineProfileBinding> createState() => MineProfileBindingState();
}

class MineProfileBindingState extends ConsumerState<MineProfileBinding> {
  // 本地 optimistic 状态：用户自己刚选完图片时立刻更新到这里，配合 setState
  // 让 UI 零延迟响应。后台同步（BeeCountCloud 拉下来的头像）落盘后通过
  // ref.watch(avatarPathProvider) 自动传播到这里；_avatarPath 只是初始化/
  // optimistic override，渲染时 avatarPathProvider 的值优先。
  String? _avatarPath;
  bool _isLoadingAvatar = true;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final path = await AvatarService.getAvatarPath();
    if (mounted) {
      setState(() {
        _avatarPath = path;
        _isLoadingAvatar = false;
      });
    }
  }

  Future<void> _showProfileOptions() async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.mineProfileEditTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(l10n.mineDisplayNameEditTitle),
              onTap: () => Navigator.pop(context, 'nickname'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.mineAvatarFromGallery),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.mineAvatarFromCamera),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            if (_avatarPath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(l10n.mineAvatarDelete,
                    style: const TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    if (result == 'nickname') {
      await _showEditDisplayName();
      return;
    }

    try {
      if (result == 'gallery') {
        final path = await AvatarService.pickAndSaveAvatar();
        if (mounted && path != null) {
          setState(() => _avatarPath = path);
          ref.invalidate(avatarPathProvider);
          await _syncAvatarToCloud(path);
        }
      } else if (result == 'camera') {
        final path = await AvatarService.takePhotoAndSaveAvatar();
        if (mounted && path != null) {
          setState(() => _avatarPath = path);
          ref.invalidate(avatarPathProvider);
          await _syncAvatarToCloud(path);
        }
      } else if (result == 'delete') {
        await AvatarService.deleteAvatar();
        if (mounted) {
          setState(() => _avatarPath = null);
          ref.invalidate(avatarPathProvider);
        }
      }
    } catch (e) {
      if (!mounted) return;
      showToast(context, '${AppLocalizations.of(context).commonError}: $e');
    }
  }

  /// 头像同步到 BeeCount Cloud（走 /api/v1/profile/avatar）。
  /// 失败仅记日志，不阻塞用户使用本地头像；iCloud/WebDAV/Supabase 场景跳过。
  Future<void> _syncAvatarToCloud(String absolutePath) async {
    try {
      final providerInstance =
          await ref.read(sp.beecountCloudProviderInstance.future);
      if (providerInstance == null) {
        logger.debug('avatar_sync', '非 BeeCount Cloud 模式，跳过头像云同步');
        return;
      }
      final file = File(absolutePath);
      if (!file.existsSync()) {
        logger.warning(
            'avatar_sync', 'upload skipped: file missing $absolutePath');
        return;
      }
      final bytes = await file.readAsBytes();
      final name = absolutePath.split('/').last;
      logger.info('avatar_sync',
          'upload start path=$absolutePath size=${bytes.length}B');
      final result = await providerInstance.uploadMyAvatar(
        bytes: bytes,
        fileName: name,
        mimeType:
            name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg',
      );
      // 上传成功后把本地 remoteVersion 立刻推到 server 的新版本，避免下一次
      // bootstrap 再触发一次重新下载自己刚传的头像。
      await AvatarService.setStoredRemoteVersion(result.avatarVersion);
      logger.info('avatar_sync',
          'upload done server_version=${result.avatarVersion} url=${result.avatarUrl}');
    } catch (e, st) {
      logger.warning('avatar_sync', 'upload failed (non-blocking): $e', st);
    }
  }

  /// 按本地时段返回问候语 + 配图(太阳/月亮)+ 图标色:5-11 早 / 11-13 午 /
  /// 13-18 下午 / 18-23 晚 / 23-5 夜。白天用太阳(暖色 amber→orange),晚上 / 夜里
  /// 用月亮(violet / indigo);图标色不随主题变。
  ({String text, IconData icon, Color color}) _greeting(AppLocalizations l10n) {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 11) {
      return (
        text: l10n.mineGreetingMorning,
        icon: Icons.wb_twilight,
        color: const Color(0xFFF59E0B),
      );
    }
    if (h >= 11 && h < 13) {
      return (
        text: l10n.mineGreetingNoon,
        icon: Icons.wb_sunny,
        color: const Color(0xFFF59E0B),
      );
    }
    if (h >= 13 && h < 18) {
      return (
        text: l10n.mineGreetingAfternoon,
        icon: Icons.wb_sunny,
        color: const Color(0xFFF97316),
      );
    }
    if (h >= 18 && h < 23) {
      return (
        text: l10n.mineGreetingEvening,
        icon: Icons.nights_stay,
        color: const Color(0xFF8B5CF6),
      );
    }
    return (
      text: l10n.mineGreetingNight,
      icon: Icons.nightlight_round,
      color: const Color(0xFF818CF8),
    );
  }

  /// 编辑用户昵称。保存写入 displayNameProvider —— 本地持久化与(仅 BeeCount
  /// Cloud 模式)云推送由 provider 的 listener 自动完成。v1 不支持清空已设昵称:
  /// trim 为空则不改动。
  ///
  /// controller 由弹窗 [_EditDisplayNameDialog] 自己持有/释放,不在本异步方法里
  /// `finally { controller.dispose() }` —— 否则取消时弹窗退场动画未结束、TextField
  /// 仍挂载就释放 controller,会触发 "used after disposed" 红屏。
  Future<void> _showEditDisplayName() async {
    final current = ref.read(displayNameProvider);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _EditDisplayNameDialog(initial: current),
    );
    if (result == null || !mounted) return;
    final name = result.trim();
    if (name.isEmpty || name == current) return; // v1 不清空;无变化不写
    ref.read(displayNameProvider.notifier).state = name;
    showToast(context, AppLocalizations.of(context).mineDisplayNameSaved);
  }

  @override
  Widget build(BuildContext context) {
    final avatar = ref.watch(avatarPathProvider).valueOrNull ?? _avatarPath;
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final ledger = ref.watch(currentLedgerProvider).valueOrNull;
    final counts = ref.watch(countsForLedgerProvider(ledgerId)).valueOrNull;
    final balance =
        ref.watch(currentBalanceProvider(ledgerId)).valueOrNull ?? 0.0;
    final hidden = ref.watch(hideAmountsProvider);
    final name = ref.watch(displayNameProvider);
    final l10n = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeProfile(
          nickname: name.isEmpty ? l10n.appTitle : name,
          greeting: name.isEmpty ? null : _greeting(l10n).text,
          subtitle: l10n.mineSlogan,
          avatar: _isLoadingAvatar
              ? const CircularProgressIndicator(strokeWidth: 2)
              : avatar == null
                  ? BeeIcon(
                      color: Theme.of(context).colorScheme.primary, size: 32)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(avatar),
                          key: ValueKey(avatar),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => BeeIcon(
                              color: Theme.of(context).colorScheme.primary,
                              size: 32))),
          onEdit: _showEditDisplayName,
          onTap: _showProfileOptions),
      const SizedBox(height: 12),
      BeeLedgerBalance(
        ledger: ledger == null
            ? l10n.ledgersNew
            : translateLedgerName(context, ledger.name),
        amount: formatMoneyCompact(balance),
        prefix: getCurrencySymbol(ledger?.currency ?? 'CNY'),
        stats: '',
        balanceLabel: l10n.mineCurrentBalance,
        days: '${counts?.dayCount ?? 0}',
        count: '${counts?.txCount ?? 0}',
        daysLabel: l10n.mineDaysCount,
        countLabel: l10n.mineTotalRecords,
        hidden: hidden,
        privacyLabel: l10n.mineCurrentBalance,
        onLedgerTap: () => showLedgerPicker(context),
        onPrivacyTap: () =>
            ref.read(hideAmountsProvider.notifier).state = !hidden,
      ),
    ]);
  }
}
