// 邀请新成员页 — Owner 用,生成 6 位邀请码 + 复制 / 分享短链。
// Phase 1 不生成 QR(短链 + 输入码已能覆盖主要分享路径)。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/shared_ledger_providers.dart';
import '../../styles/tokens.dart';
import '../../widgets/biz/biz.dart';
import '../../widgets/ui/ui.dart';

class InvitePage extends ConsumerStatefulWidget {
  const InvitePage({
    super.key,
    required this.ledgerExternalId,
    required this.ledgerName,
  });

  /// Server external_id(本地 syncId)。
  final String ledgerExternalId;
  final String ledgerName;

  @override
  ConsumerState<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends ConsumerState<InvitePage> {
  static const _expiryOptions = <int>[24, 72, 168]; // 1d / 3d / 7d
  int _expiresInHours = 24;
  BeeCountCloudInvite? _generated;
  bool _busy = false;
  String? _error;

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final invite = await createInviteAndRefresh(
        ref,
        ledgerId: widget.ledgerExternalId,
        role: 'editor',
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
    showToast(context, l10n.commonCopied);
  }

  Future<void> _share(BeeCountCloudInvite invite, AppLocalizations l10n) async {
    final message = l10n.sharedInviteShareText(
      widget.ledgerName,
      invite.formattedCode,
      invite.shareUrl,
    );
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
    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.sharedInvitePageTitle,
            subtitle: widget.ledgerName,
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
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

  Widget _buildForm(AppLocalizations l10n) {
    return SectionCard(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.sharedInviteFormRole,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.sharedRoleEditor),
                  selected: true,
                  onSelected: (_) {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.sharedInviteFormExpiry,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final h in _expiryOptions)
                  ChoiceChip(
                    label: Text(_expiryLabel(h, l10n)),
                    selected: _expiresInHours == h,
                    onSelected: _busy
                        ? null
                        : (sel) {
                            if (sel) setState(() => _expiresInHours = h);
                          },
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _generate,
              icon: const Icon(Icons.qr_code_2_outlined),
              label: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.sharedInviteGenerate),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            Text(
              l10n.sharedInviteWarning,
              style: TextStyle(
                color: BeeTokens.textTertiary(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildShareView(BeeCountCloudInvite invite, AppLocalizations l10n) {
    return SectionCard(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: SelectableText(
                invite.formattedCode,
                style: const TextStyle(
                  fontSize: 36,
                  letterSpacing: 6,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                l10n.sharedInviteExpiresAt(
                  invite.expiresAt.toLocal().toString().split('.').first,
                ),
                style: TextStyle(
                    color: BeeTokens.textTertiary(context), fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy_outlined),
                    label: Text(l10n.sharedInviteCopyCode),
                    onPressed: () => _copy(invite.code, l10n),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.share_outlined),
                    label: Text(l10n.sharedInviteShareLink),
                    onPressed: () => _share(invite, l10n),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.link),
              label: Text(l10n.sharedInviteCopyLink),
              onPressed: () => _copy(invite.shareUrl, l10n),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.sharedInviteInstruction,
              style: TextStyle(color: BeeTokens.textSecondary(context)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _generated = null;
                  _error = null;
                });
              },
              child: Text(l10n.sharedInviteGenerateAnother),
            ),
          ],
        ),
    );
  }
}
