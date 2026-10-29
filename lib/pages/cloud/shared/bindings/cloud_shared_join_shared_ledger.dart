// 加入共享账本页 — 输入 6 位邀请码 → preview → accept。
// Phase 1 不做 QR 扫码 / 短链 deeplink;两者都推到 Phase 3。MVP 只支持手动
// 输入邀请码。accept 成功后 sync engine 走 onInviteAccepted 拉 shared-resources。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../cloud/sync/sync_engine.dart'; // for onInviteAccepted extension method
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/shared_ledger_providers.dart';
import '../../../../providers/sync_providers.dart';
import '../../../../providers/statistics_providers.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/cloud_shared.dart';
import '../../../shared/scaffold/widgets/page_scaffold.dart';
import '../../../../services/system/logger_service.dart';

class CloudSharedJoinControls extends ConsumerStatefulWidget {
  const CloudSharedJoinControls({super.key, this.prefilledCode});

  /// 从 deeplink 跳过来时,自动填好的邀请码。
  final String? prefilledCode;

  @override
  ConsumerState<CloudSharedJoinControls> createState() =>
      _CloudSharedJoinControlsState();
}

class _CloudSharedJoinControlsState
    extends ConsumerState<CloudSharedJoinControls> {
  final TextEditingController _codeController = TextEditingController();
  BeeCountCloudInvitePreview? _preview;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledCode != null && widget.prefilledCode!.isNotEmpty) {
      _codeController.text = _normalizeForInput(widget.prefilledCode!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _doPreview();
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// 输入框显示 "ABC 123",发送 server 时 strip 空格。
  String _normalizeForInput(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
    if (cleaned.length == 6) {
      return '${cleaned.substring(0, 3)} ${cleaned.substring(3)}';
    }
    return cleaned;
  }

  String _normalizeForApi(String raw) =>
      raw.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();

  Future<void> _doPreview() async {
    if (_busy || !mounted) return;
    final code = _normalizeForApi(_codeController.text);
    if (code.length != 6) {
      setState(() =>
          _error = AppLocalizations.of(context).sharedJoinCodeFormatError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview = await previewInvite(ref, code: code);
      if (!mounted) return;
      setState(() => _preview = preview);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _formatError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doAccept() async {
    if (_busy || !mounted) return;
    final preview = _preview;
    if (preview == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await acceptInvite(ref, code: preview.code);
      if (!mounted) return;
      // 触发同步:用 onInviteAccepted 一站式 — 拉 ledger 元数据 +
      // fetchSharedResources 全量灌进 SharedLedger* 镜像 + 拉历史 tx。失败
      // 不阻塞"加入成功"体验,下次启动会自动 sync。
      try {
        final runtime = await ref.read(activeCloudRuntimeProvider.future);
        final engine = runtime?.syncEngine;
        if (engine != null) {
          await engine.onInviteAccepted(preview.ledgerExternalId);
        }
        if (!mounted) return;
        // 强力 invalidate 所有 ledger 相关 provider,确保下一帧 UI 立即重渲染
        // (单纯 state++ 在 cached FutureProvider 上偶发不触发 reCompute,
        // invalidate 是无条件 dispose + 下次 watch 重新 build)
        ref.invalidate(localLedgersProvider);
        ref.invalidate(remoteLedgersProvider);
        ref.read(ledgerListRefreshProvider.notifier).state++;
        ref.read(syncGenerationProvider.notifier).state++;
        ref.read(statsRefreshProvider.notifier).state++;
      } catch (e) {
        // 静默,UI 自己刷不到下次 sync 再补;但 log 出来便于诊断
        logger.warning('JoinSharedLedger', 'accept 后 sync/刷新失败 — 下次启动会兜底', e);
      }
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      showBeeToast(
        context,
        l10n.sharedJoinSuccess(result.ledgerName ?? preview.ledgerExternalId),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _formatError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatError(Object error) {
    final raw = error.toString();
    if (raw.contains('Already a member')) {
      return AppLocalizations.of(context).sharedJoinAlreadyMember;
    }
    if (raw.contains('Invalid or expired')) {
      return AppLocalizations.of(context).sharedJoinInvalidOrExpired;
    }
    if (raw.contains('member limit')) {
      return AppLocalizations.of(context).sharedJoinMemberLimit;
    }
    return raw;
  }

  String _formatRoleLabel(String role, AppLocalizations l10n) {
    switch (role) {
      case 'owner':
        return l10n.sharedRoleOwner;
      case 'editor':
        return l10n.sharedRoleEditor;
      default:
        return role;
    }
  }

  String _formatExpiry(DateTime expiresAt, AppLocalizations l10n) {
    final now = DateTime.now().toUtc();
    final delta = expiresAt.difference(now);
    if (delta.inMinutes <= 0) return l10n.sharedJoinInvalidOrExpired;
    if (delta.inHours < 1) {
      return l10n.sharedJoinExpiresInMinutes(delta.inMinutes);
    }
    if (delta.inHours < 24) {
      return l10n.sharedJoinExpiresInHours(delta.inHours);
    }
    return l10n.sharedJoinExpiresInDays(delta.inDays);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preview = _preview;

    return V4PageScaffold(
      body: Column(
        children: [
          BeePageHeader(
            title: l10n.sharedJoinPageTitle,
            subtitle: l10n.sharedJoinPageSubtitle,
            leading: const BackButton(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(17),
              children: [
                const SizedBox(height: 8),
                if (preview != null)
                  _buildPreviewCard(preview, l10n)
                else
                  _buildInputCard(l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard(AppLocalizations l10n) => BeeCloudSharedJoinForm(
        title: l10n.sharedJoinEnterCode,
        hint: l10n.sharedJoinEnterCodeHint,
        input: TextField(
          controller: _codeController,
          autofocus: true,
          enabled: !_busy,
          textAlign: TextAlign.center,
          maxLength: 7, // 6 chars + 1 space
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(
            fontSize: 28,
            letterSpacing: 6,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'ABC 123',
            border: const OutlineInputBorder(),
            counterText: '',
            errorText: _error,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'[A-Za-z2-9\s]'),
            ),
          ],
          onChanged: (raw) {
            final normalized = _normalizeForInput(raw);
            if (normalized != raw) {
              _codeController.value = TextEditingValue(
                text: normalized,
                selection: TextSelection.collapsed(offset: normalized.length),
              );
            }
            if (_error != null) {
              setState(() => _error = null);
            }
          },
          onSubmitted: (_) {
            if (mounted) _doPreview();
          },
        ),
        previewLabel: l10n.sharedJoinPreviewButton,
        onPreview: _doPreview,
        busy: _busy,
      );

  Widget _buildPreviewCard(
          BeeCountCloudInvitePreview preview, AppLocalizations l10n) =>
      BeeCloudSharedJoinPreview(
        inviter: l10n.sharedJoinInvitedBy(preview.invitedByDisplay),
        ledger: preview.ledgerName ?? preview.ledgerExternalId,
        role:
            l10n.sharedJoinRoleLine(_formatRoleLabel(preview.targetRole, l10n)),
        expiry: _formatExpiry(preview.expiresAt, l10n),
        expiryDate:
            DateFormat('yyyy-MM-dd HH:mm').format(preview.expiresAt.toLocal()),
        error: _error,
        busy: _busy,
        cancelLabel: l10n.commonCancel,
        acceptLabel: l10n.sharedJoinAcceptButton,
        onCancel: () => setState(() {
          _preview = null;
          _error = null;
        }),
        onAccept: _doAccept,
      );
}
