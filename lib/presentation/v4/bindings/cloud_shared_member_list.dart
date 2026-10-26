// 成员管理页 — 列出账本成员,Owner 可踢人,任意 member 可退出。
// 成员收支统计独立到 MemberStatsPage,从账本动作菜单单独入口。
// (MVP 不实现转让 owner,留 Phase 3)
import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/shared_ledger_providers.dart';
import '../../../providers/sync_providers.dart'
    show beecountCloudProviderInstance;
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/cloud_shared.dart';
import 'page_scaffold.dart';
import '../../../widgets/ui/ui.dart';
import '../../../pages/cloud/invite_page.dart';
import 'cloud_shared_actions.dart';

class CloudSharedMembersControls extends ConsumerStatefulWidget {
  const CloudSharedMembersControls({
    super.key,
    required this.ledgerExternalId,
    required this.ledgerName,
  });

  final String ledgerExternalId;
  final String ledgerName;

  @override
  ConsumerState<CloudSharedMembersControls> createState() =>
      _CloudSharedMembersControlsState();
}

class _CloudSharedMembersControlsState
    extends ConsumerState<CloudSharedMembersControls> {
  bool _busy = false;
  String get ledgerExternalId => widget.ledgerExternalId;
  String get ledgerName => widget.ledgerName;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final membersAsync = ref.watch(ledgerMembersProvider(ledgerExternalId));

    return V4PageScaffold(
      body: Column(
        children: [
          BeePageHeader(
            title: l10n.sharedMembersPageTitle,
            subtitle: ledgerName,
            leading: const BackButton(),
            actions: [
              BeeIconButton(
                label: l10n.v4RecordingRetry,
                icon: const BeeLineIcon('RefreshCw', size: 21),
                onPressed: () =>
                    ref.invalidate(ledgerMembersProvider(ledgerExternalId)),
              ),
            ],
          ),
          Expanded(
            child: membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => BeeEmptyState(
                  title: '${l10n.commonError}: $e',
                  action: BeeButton(
                      label: l10n.v4RecordingRetry,
                      onPressed: () => ref.invalidate(
                          ledgerMembersProvider(ledgerExternalId)))),
              data: (members) => _buildList(context, ref, members, l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<BeeCountCloudLedgerMember> members,
    AppLocalizations l10n,
  ) {
    final me = members.where((m) => m.isSelf).firstOrNull;
    final amOwner = me?.role == 'owner';
    return ListView(
      padding: const EdgeInsets.all(17),
      children: [
        BeeCloudSharedCard(
          child: Column(
            children: [
              for (final m in members) ...[
                _MemberTile(
                  member: m,
                  amOwner: amOwner,
                  busy: _busy,
                  onChangeRole: amOwner && !m.isSelf
                      ? () => _confirmTransfer(context, ref, m, l10n)
                      : null,
                  onRemove: amOwner && !m.isSelf
                      ? () => _confirmRemove(context, ref, m, l10n)
                      : null,
                ),
                if (m != members.last) const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (amOwner)
          BeeCloudSharedAction(
              title: l10n.sharedMembersInviteCta,
              icon: const BeeLineIcon('UserPlus', size: 21),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => InvitePage(
                      ledgerExternalId: ledgerExternalId,
                      ledgerName: ledgerName)))),
        const SizedBox(height: 8),
        if (me != null && !amOwner)
          BeeCloudSharedAction(
              title: l10n.sharedMembersLeaveCta,
              icon: const BeeLineIcon('LogOut', size: 21),
              destructive: true,
              busy: _busy,
              onTap: () => _confirmLeave(context, ref, me, l10n)),
      ],
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    BeeCountCloudLedgerMember target,
    AppLocalizations l10n,
  ) async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => BeeDialog(
          showClose: false,
          title: Text(l10n.sharedMembersRemoveTitle),
          content: Text(l10n
              .sharedMembersRemoveConfirm(target.displayName ?? target.email)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.commonRemove),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      try {
        await cloudSharedRemoveMember(
          ref,
          ledgerId: ledgerExternalId,
          active: () => mounted,
          userId: target.userId,
        );
        if (context.mounted) showToast(context, l10n.sharedMembersRemoved);
      } catch (e) {
        if (context.mounted) showToast(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmTransfer(
    BuildContext context,
    WidgetRef ref,
    BeeCountCloudLedgerMember target,
    AppLocalizations l10n,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.sharedMembersTransferTitle),
        content: Text(l10n
            .sharedMembersTransferConfirm(target.displayName ?? target.email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.sharedMembersTransferConfirmCta),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // MVP 不实现转让(留 Phase 3)。这个 confirm dialog 不会被触发到这里,
    // 因为 PopupMenu 已经不再展示 transfer 选项。保留这个 stub 避免删一大段。
    if (context.mounted) {
      showToast(context, 'Transfer ownership: Phase 3 only');
    }
  }

  Future<void> _confirmLeave(
    BuildContext context,
    WidgetRef ref,
    BeeCountCloudLedgerMember me,
    AppLocalizations l10n,
  ) async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => BeeDialog(
          showClose: false,
          title: Text(l10n.sharedMembersLeaveTitle),
          content: Text(l10n.sharedMembersLeaveConfirm(ledgerName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.sharedMembersLeaveCta),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      try {
        await cloudSharedRemoveMember(
          ref,
          ledgerId: ledgerExternalId,
          active: () => mounted,
          userId: me.userId,
        );
        // 退出后由 server 广播 member_change.removed 触发本地清理(详见
        // sync_engine_realtime._handleMemberChange),这里不做 self-trigger。
        if (context.mounted) {
          showToast(context, l10n.sharedMembersLeaveDone);
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (context.mounted) showToast(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.member,
    required this.amOwner,
    required this.busy,
    this.onChangeRole,
    this.onRemove,
  });

  final BeeCountCloudLedgerMember member;
  final bool amOwner, busy;
  final VoidCallback? onChangeRole;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final displayName = member.displayName?.isNotEmpty == true
        ? member.displayName!
        : member.email.split('@').first;
    final isOwner = member.role == 'owner';
    return BeeCloudSharedMemberRow(
      avatar: _MemberAvatar(member: member, displayName: displayName),
      name: displayName,
      email: member.email,
      role: isOwner ? l10n.sharedRoleOwner : l10n.sharedRoleEditor,
      selfLabel: member.isSelf ? l10n.sharedMembersYou : null,
      removeLabel: l10n.sharedMembersRemoveCta,
      onRemove: amOwner && !member.isSelf && !isOwner ? onRemove : null,
      busy: busy,
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

/// 共享账本成员头像 — server avatar_url 拼上 cloudProvider.baseUrl 用 NetworkImage,
/// 缺失 / 加载失败 fallback 到首字母 CircleAvatar。
class _MemberAvatar extends ConsumerWidget {
  const _MemberAvatar({required this.member, required this.displayName});

  final BeeCountCloudLedgerMember member;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final letter = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final relativeUrl = member.avatarUrl;
    if (relativeUrl == null || relativeUrl.isEmpty) {
      return CircleAvatar(child: Text(letter));
    }
    final cloudAsync = ref.watch(beecountCloudProviderInstance);
    final cloud = cloudAsync.valueOrNull;
    final base = cloud?.baseUrl;
    if (base == null || base.isEmpty) {
      return CircleAvatar(child: Text(letter));
    }
    final absoluteUrl =
        relativeUrl.startsWith('http') ? relativeUrl : '$base$relativeUrl';
    return CircleAvatar(
      backgroundImage: NetworkImage(absoluteUrl),
      onBackgroundImageError: (_, __) {/* fallback child 显示 */},
      child: Text(letter),
    );
  }
}
