// 邀请新成员页 — Owner 用,生成 6 位邀请码 + 复制 / 分享短链。
// Phase 1 不生成 QR(短链 + 输入码已能覆盖主要分享路径)。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../l10n/app_localizations.dart';
import 'cloud_shared_actions.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/cloud_shared.dart';
import '../../../shared/scaffold/widgets/page_scaffold.dart';

class CloudSharedInviteControls extends ConsumerStatefulWidget {
  const CloudSharedInviteControls({
    super.key,
    required this.ledgerExternalId,
    required this.ledgerName,
  });

  /// Server external_id(本地 syncId)。
  final String ledgerExternalId;
  final String ledgerName;

  @override
  ConsumerState<CloudSharedInviteControls> createState() =>
      _CloudSharedInviteControlsState();
}

class _CloudSharedInviteControlsState
    extends ConsumerState<CloudSharedInviteControls> {
  static const _expiryOptions = <int>[24, 72, 168]; // 1d / 3d / 7d
  int _expiresInHours = 24;
  BeeCountCloudInvite? _generated;
  bool _busy = false;
  String? _error;

  Future<void> _generate() async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final invite = await cloudSharedCreateInvite(
        ref,
        ledgerId: widget.ledgerExternalId,
        active: () => mounted,
        expiresInHours: _expiresInHours,
      );
      if (!mounted) return;
      setState(() => _generated = invite);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String value, AppLocalizations l10n) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    showBeeToast(context, l10n.commonCopied);
  }

  Future<void> _share(BeeCountCloudInvite invite, AppLocalizations l10n) async {
    final message = l10n.sharedInviteShareText(
      widget.ledgerName,
      invite.formattedCode,
      invite.shareUrl,
    );
    // Preserve the original platform sharing contract during this UI migration.
    // ignore: deprecated_member_use
    await Share.share(message);
  }

  String _expiryLabel(int hours, AppLocalizations l10n) {
    if (hours < 24) return l10n.sharedInviteExpiryHours(hours);
    final days = hours ~/ 24;
    return l10n.sharedInviteExpiryDays(days);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return V4PageScaffold(
      body: Column(
        children: [
          BeePageHeader(
            title: l10n.sharedInvitePageTitle,
            subtitle: widget.ledgerName,
            leading: const BackButton(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(17),
              children: [
                const SizedBox(height: 8),
                if (_generated == null)
                  _buildForm(l10n)
                else
                  _buildShareView(_generated!, l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(AppLocalizations l10n) => BeeCloudSharedInviteForm(
        roleLabel: l10n.sharedInviteFormRole,
        role: l10n.sharedRoleEditor,
        expiryLabel: l10n.sharedInviteFormExpiry,
        expiryOptions: {
          for (final hours in _expiryOptions) hours: _expiryLabel(hours, l10n)
        },
        selectedHours: _expiresInHours,
        onExpiry: (hours) => setState(() => _expiresInHours = hours),
        generateLabel: l10n.sharedInviteGenerate,
        onGenerate: _generate,
        warning: l10n.sharedInviteWarning,
        busy: _busy,
        error: _error,
      );

  Widget _buildShareView(BeeCountCloudInvite invite, AppLocalizations l10n) =>
      BeeCloudSharedInviteCode(
        code: invite.formattedCode,
        expiry: l10n.sharedInviteExpiresAt(
            invite.expiresAt.toLocal().toString().split('.').first),
        copyCodeLabel: l10n.sharedInviteCopyCode,
        shareLabel: l10n.sharedInviteShareLink,
        copyLinkLabel: l10n.sharedInviteCopyLink,
        instruction: l10n.sharedInviteInstruction,
        anotherLabel: l10n.sharedInviteGenerateAnother,
        onCopyCode: () => _copy(invite.code, l10n),
        onShare: () => _share(invite, l10n),
        onCopyLink: () => _copy(invite.shareUrl, l10n),
        onAnother: () => setState(() {
          _generated = null;
          _error = null;
        }),
      );
}
