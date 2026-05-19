// 成员管理页 — 列出账本成员,Owner 可踢人,任意 member 可退出。
// 成员收支统计独立到 MemberStatsPage,从账本动作菜单单独入口。
// (MVP 不实现转让 owner,留 Phase 3)
import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/shared_ledger_providers.dart';
import '../../providers/sync_providers.dart' show beecountCloudProviderInstance;
import '../../styles/tokens.dart';
import '../../widgets/biz/biz.dart';
import '../../widgets/ui/ui.dart';
import 'invite_page.dart';

class MemberListPage extends ConsumerWidget {
  const MemberListPage({
    super.key,
    required this.ledgerExternalId,
    required this.ledgerName,
  });

  final String ledgerExternalId;
  final String ledgerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final membersAsync = ref.watch(ledgerMembersProvider(ledgerExternalId));

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.sharedMembersPageTitle,
            subtitle: ledgerName,
            showBack: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    ref.invalidate(ledgerMembersProvider(ledgerExternalId)),
              ),
            ],
          ),
          Expanded(
            child: membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('${l10n.commonError}: $e',
                      textAlign: TextAlign.center),
                ),
              ),
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
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 8),
        SectionCard(
          child: Column(
            children: [
              for (final m in members) ...[
                _MemberTile(
                  member: m,
                  amOwner: amOwner,
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
          SectionCard(
            child: ListTile(
              leading: const Icon(Icons.person_add_outlined),
              title: Text(l10n.sharedMembersInviteCta),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InvitePage(
                    ledgerExternalId: ledgerExternalId,
                    ledgerName: ledgerName,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (me != null && !amOwner)
          SectionCard(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: Text(
                l10n.sharedMembersLeaveCta,
                style: const TextStyle(color: Colors.redAccent),
              ),
              onTap: () => _confirmLeave(context, ref, me, l10n),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    BeeCountCloudLedgerMember target,
    AppLocalizations l10n,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.sharedMembersRemoveTitle),
        content: Text(l10n.sharedMembersRemoveConfirm(
            target.displayName ?? target.email)),
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
    if (ok != true) return;
    try {
      await removeMemberAndRefresh(
        ref,
        ledgerId: ledgerExternalId,
        userId: target.userId,
      );
      if (context.mounted) showToast(context, l10n.sharedMembersRemoved);
    } catch (e) {
      if (context.mounted) showToast(context, e.toString());
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
        content: Text(l10n.sharedMembersTransferConfirm(
            target.displayName ?? target.email)),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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
    if (ok != true) return;
    try {
      await removeMemberAndRefresh(
        ref,
        ledgerId: ledgerExternalId,
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
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.member,
    required this.amOwner,
    this.onChangeRole,
    this.onRemove,
  });

  final BeeCountCloudLedgerMember member;
  final bool amOwner;
  final VoidCallback? onChangeRole;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final displayName = member.displayName?.isNotEmpty == true
        ? member.displayName!
        : member.email.split('@').first;
    final isOwner = member.role == 'owner';
    return ListTile(
      leading: _MemberAvatar(member: member, displayName: displayName),
      title: Row(
        children: [
          Flexible(
            child: Text(
              displayName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (member.isSelf) ...[
            const SizedBox(width: 4),
            Text(
              ' (${l10n.sharedMembersYou})',
              style: TextStyle(
                color: BeeTokens.textTertiary(context),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        member.email,
        style: TextStyle(color: BeeTokens.textSecondary(context), fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(isOwner ? l10n.sharedRoleOwner : l10n.sharedRoleEditor),
          ),
          if (amOwner && !member.isSelf && !isOwner)
            IconButton(
              icon: const Icon(Icons.person_remove, size: 20),
              tooltip: l10n.sharedMembersRemoveCta,
              onPressed: onRemove,
            ),
          // Transfer ownership 推到 Phase 3,UI 不展示按钮。
        ],
      ),
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
    final absoluteUrl = relativeUrl.startsWith('http')
        ? relativeUrl
        : '$base$relativeUrl';
    return CircleAvatar(
      backgroundImage: NetworkImage(absoluteUrl),
      onBackgroundImageError: (_, __) {/* fallback child 显示 */},
      child: Text(letter),
    );
  }
}
