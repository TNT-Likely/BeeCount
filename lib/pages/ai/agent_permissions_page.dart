import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agent/permission/agent_tool_permission.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/ai_chat_providers.dart';
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
            context, AppLocalizations.of(context).agentPermissionWriteFailed);
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
            context, AppLocalizations.of(context).agentPermissionWriteFailed);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final permissions = _permissions;
    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.agentPermissionsTitle,
            showBack: true,
            actions: [
              TextButton(
                onPressed: permissions == null ? null : _restoreDefaults,
                child: Text(l10n.agentPermissionsRestoreDefaults),
              ),
            ],
          ),
          Expanded(
            child: permissions == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: AgentToolPermissionCatalog.descriptors.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final descriptor =
                          AgentToolPermissionCatalog.descriptors[index];
                      final permission = permissions[descriptor.toolName] ??
                          descriptor.defaultPermission;
                      final isWriting = _writing.contains(descriptor.toolName);
                      return ListTile(
                        title: Text(
                          AgentToolPresentation.label(
                              l10n, descriptor.toolName),
                        ),
                        subtitle: Text(
                          AgentToolPresentation.description(
                            l10n,
                            descriptor.toolName,
                          ),
                        ),
                        trailing: isWriting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : DropdownButton<AgentToolPermission>(
                                key: ValueKey(
                                  'permission-${descriptor.toolName}',
                                ),
                                value: permission,
                                onChanged: (value) => value == null
                                    ? null
                                    : _setPermission(
                                        descriptor.toolName,
                                        value,
                                      ),
                                items: [
                                  for (final option
                                      in AgentToolPermission.values)
                                    DropdownMenuItem(
                                      value: option,
                                      child: Text(
                                        AgentToolPresentation.permissionLabel(
                                          l10n,
                                          option,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
