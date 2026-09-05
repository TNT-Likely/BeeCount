import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agent/permission/agent_tool_permission.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/ai_chat_providers.dart';
import '../../providers/theme_providers.dart';
import '../../styles/tokens.dart';
import '../../widgets/ui/primary_header.dart';
import '../../widgets/ui/toast.dart';
import 'agent_tool_presentation.dart';

final class AgentPermissionsPage extends ConsumerStatefulWidget {
  const AgentPermissionsPage({super.key});

  @override
  ConsumerState<AgentPermissionsPage> createState() =>
      _AgentPermissionsPageState();
}

final class _AgentPermissionsPageState
    extends ConsumerState<AgentPermissionsPage> {
  Map<String, AgentToolPermission>? _permissions;
  final Set<String> _writing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await ref.read(agentToolPermissionStoreProvider).readAll();
      if (mounted) setState(() => _permissions = values);
    } on Object {
      if (mounted) {
        showToast(
          context,
          AppLocalizations.of(context).agentPermissionWriteFailed,
        );
      }
    }
  }

  Future<void> _setPermission(
    String toolName,
    AgentToolPermission permission,
  ) async {
    setState(() => _writing.add(toolName));
    try {
      await ref
          .read(agentToolPermissionStoreProvider)
          .setPermission(toolName, permission);
      if (mounted) {
        setState(() => _permissions = {...?_permissions, toolName: permission});
      }
    } on Object {
      if (mounted) {
        showToast(
          context,
          AppLocalizations.of(context).agentPermissionWriteFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _writing.remove(toolName));
    }
  }

  Future<void> _restoreDefaults() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.agentPermissionsRestoreTitle),
        content: Text(l10n.agentPermissionsRestoreDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.agentPermissionsRestoreConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(agentToolPermissionStoreProvider).restoreDefaults();
      await _load();
    } on Object {
      if (mounted) showToast(context, l10n.agentPermissionWriteFailed);
    }
  }

  Future<void> _showPermissionSheet(
    AgentToolPermissionDescriptor descriptor,
    AgentToolPermission current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<AgentToolPermission>(
      context: context,
      showDragHandle: true,
      backgroundColor: BeeTokens.surfaceSheet(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AgentToolPresentation.label(l10n, descriptor.toolName),
                style: BeeTextTokens.boldTitle(context),
              ),
              const SizedBox(height: 4),
              Text(
                AgentToolPresentation.description(l10n, descriptor.toolName),
                style: BeeTextTokens.label(context),
              ),
              const SizedBox(height: 16),
              for (final option in AgentToolPermission.values) ...[
                _PermissionOption(
                  permission: option,
                  selected: option == current,
                  label: AgentToolPresentation.permissionLabel(l10n, option),
                  onTap: () => Navigator.of(sheetContext).pop(option),
                ),
                if (option != AgentToolPermission.values.last)
                  const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected != current && mounted) {
      await _setPermission(descriptor.toolName, selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final permissions = _permissions;
    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.agentPermissionsTitle,
            showBack: true,
          ),
          Expanded(
            child: permissions == null
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(permissions, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    Map<String, AgentToolPermission> permissions,
    AppLocalizations l10n,
  ) {
    final readOnly = AgentToolPermissionCatalog.descriptors
        .where((descriptor) => !descriptor.mutatesLocalData)
        .toList();
    final writeTools = AgentToolPermissionCatalog.descriptors
        .where((descriptor) => descriptor.mutatesLocalData)
        .toList();
    final changedCount = AgentToolPermissionCatalog.descriptors.where((d) {
      final value = permissions[d.toolName] ?? d.defaultPermission;
      return value != d.defaultPermission;
    }).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _buildIntroCard(l10n),
        const SizedBox(height: 18),
        _buildToolSection(
          title: l10n.agentPermissionsReadOnlySection,
          subtitle: l10n.agentPermissionsReadOnlySectionDescription,
          icon: Icons.visibility_outlined,
          color: BeeTokens.info(context),
          descriptors: readOnly,
          permissions: permissions,
          l10n: l10n,
        ),
        const SizedBox(height: 14),
        _buildToolSection(
          title: l10n.agentPermissionsWriteSection,
          subtitle: l10n.agentPermissionsWriteSectionDescription,
          icon: Icons.edit_note_outlined,
          color: BeeTokens.warning(context),
          descriptors: writeTools,
          permissions: permissions,
          l10n: l10n,
        ),
        const SizedBox(height: 18),
        _buildRestoreCard(changedCount, l10n),
      ],
    );
  }

  Widget _buildIntroCard(AppLocalizations l10n) {
    final primary = ref.watch(primaryColorProvider);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: BeeTokens.isDark(context) ? 0.24 : 0.12),
            BeeTokens.surface(context),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: primary.withValues(alpha: 0.18)),
        boxShadow: BeeTokens.isDark(context) ? null : BeeShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shield_outlined, color: primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                l10n.agentPermissionsIntro,
                style: BeeTextTokens.body(context).copyWith(height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<AgentToolPermissionDescriptor> descriptors,
    required Map<String, AgentToolPermission> permissions,
    required AppLocalizations l10n,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: BeeTokens.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: BeeTokens.isDark(context) ? null : BeeShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 17, 18, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: BeeTextTokens.strongTitle(context)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: BeeTextTokens.label(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < descriptors.length; index++) ...[
            if (index > 0) BeeTokens.cardDivider(context, indent: 70),
            _buildPermissionRow(descriptors[index], permissions, l10n),
          ],
        ],
      ),
    );
  }

  Widget _buildPermissionRow(
    AgentToolPermissionDescriptor descriptor,
    Map<String, AgentToolPermission> permissions,
    AppLocalizations l10n,
  ) {
    final permission =
        permissions[descriptor.toolName] ?? descriptor.defaultPermission;
    final isWriting = _writing.contains(descriptor.toolName);
    final statusColor = permission == AgentToolPermission.ask
        ? BeeTokens.warning(context)
        : BeeTokens.success(context);

    return InkWell(
      onTap:
          isWriting ? null : () => _showPermissionSheet(descriptor, permission),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 13, 14, 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AgentToolPresentation.label(l10n, descriptor.toolName),
                    style: BeeTextTokens.body(context),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    AgentToolPresentation.description(
                        l10n, descriptor.toolName),
                    style: BeeTextTokens.label(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (isWriting)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: statusColor,
                ),
              )
            else
              _PermissionPill(
                key: ValueKey('permission-status-${descriptor.toolName}'),
                permission: permission,
                label: AgentToolPresentation.permissionLabel(l10n, permission),
                color: statusColor,
                onTap: () => _showPermissionSheet(descriptor, permission),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestoreCard(int changedCount, AppLocalizations l10n) {
    final color = BeeTokens.textSecondary(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: BeeTokens.surfaceSecondary(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.restart_alt_rounded, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              changedCount == 0
                  ? l10n.agentPermissionsDefaultsActive
                  : l10n.agentPermissionsModifiedCount(changedCount),
              style: BeeTextTokens.label(context),
            ),
          ),
          TextButton(
            key: const ValueKey('restore-agent-permissions'),
            onPressed: _restoreDefaults,
            child: Text(l10n.agentPermissionsRestoreDefaults),
          ),
        ],
      ),
    );
  }
}

final class _PermissionPill extends StatelessWidget {
  const _PermissionPill({
    super.key,
    required this.permission,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final AgentToolPermission permission;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                permission == AgentToolPermission.ask
                    ? Icons.help_outline_rounded
                    : Icons.check_circle_outline_rounded,
                size: 15,
                color: color,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _PermissionOption extends StatelessWidget {
  const _PermissionOption({
    required this.permission,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final AgentToolPermission permission;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = permission == AgentToolPermission.ask
        ? BeeTokens.warning(context)
        : BeeTokens.success(context);
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(
                permission == AgentToolPermission.ask
                    ? Icons.help_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: BeeTextTokens.body(context)),
              ),
              if (selected) Icon(Icons.check_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
