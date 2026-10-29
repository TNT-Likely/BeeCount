import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/ai_advanced.dart';
import '../../../../agent/permission/agent_tool_permission.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/ai_chat_providers.dart';
import '../../agent_tool_presentation.dart';
import '../../../shared/scaffold/widgets/page_scaffold.dart';

class AIAdvancedPermissionsControls extends ConsumerStatefulWidget {
  const AIAdvancedPermissionsControls({super.key});
  @override
  ConsumerState<AIAdvancedPermissionsControls> createState() =>
      _PermissionsState();
}

class _PermissionsState extends ConsumerState<AIAdvancedPermissionsControls> {
  Map<String, AgentToolPermission>? _permissions;
  final _writing = <String>{};
  bool _restoring = false, _sheetOpen = false, _confirmingRestore = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    try {
      final values = await ref.read(agentToolPermissionStoreProvider).readAll();
      if (mounted) {
        setState(() {
          _permissions = values;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = AppLocalizations.of(context).agentPermissionWriteFailed);
      }
    }
  }

  Future<void> _setPermission(
      String name, AgentToolPermission permission) async {
    if (_writing.contains(name) || _restoring) return;
    setState(() => _writing.add(name));
    try {
      await ref
          .read(agentToolPermissionStoreProvider)
          .setPermission(name, permission);
      if (mounted) {
        setState(() => _permissions = {...?_permissions, name: permission});
      }
    } catch (_) {
      if (mounted) {
        showBeeToast(
            context, AppLocalizations.of(context).agentPermissionWriteFailed);
      }
    } finally {
      if (mounted) setState(() => _writing.remove(name));
    }
  }

  Future<void> _restoreDefaults() async {
    if (_restoring || _confirmingRestore || _writing.isNotEmpty || _sheetOpen) {
      return;
    }
    final l = AppLocalizations.of(context),
        store = ref.read(agentToolPermissionStoreProvider);
    setState(() => _confirmingRestore = true);
    try {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => BeeDialog(
                  showClose: false,
                  title: Text(l.agentPermissionsRestoreTitle),
                  content: Text(l.agentPermissionsRestoreDescription),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l.commonCancel)),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l.agentPermissionsRestoreConfirm))
                  ]));
      if (confirmed != true || !mounted) return;
      setState(() {
        _confirmingRestore = false;
        _restoring = true;
      });
      await store.restoreDefaults();
      if (mounted) await _load();
    } catch (_) {
      if (mounted) showBeeToast(context, l.agentPermissionWriteFailed);
    } finally {
      if (mounted) {
        setState(() {
          _restoring = false;
          _confirmingRestore = false;
        });
      }
    }
  }

  Future<void> _showPermissionSheet(AgentToolPermissionDescriptor descriptor,
      AgentToolPermission current) async {
    if (_restoring ||
        _confirmingRestore ||
        _writing.contains(descriptor.toolName) ||
        _sheetOpen) {
      return;
    }
    _sheetOpen = true;
    final l = AppLocalizations.of(context);
    try {
      final selected = await showModalBottomSheet<AgentToolPermission>(
          context: context,
          showDragHandle: true,
          backgroundColor: BeeCardTheme.of(context).surface,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
          builder: (ctx) => SafeArea(
              child: SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                                AgentToolPresentation.label(
                                    l, descriptor.toolName),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text(
                                AgentToolPresentation.description(
                                    l, descriptor.toolName),
                                style: TextStyle(
                                    fontSize: 12,
                                    height: 1.6,
                                    color: Theme.of(ctx).hintColor)),
                            const SizedBox(height: 16),
                            for (final option
                                in AgentToolPermission.values) ...[
                              BeeAIAdvancedPermissionOption(
                                  label: AgentToolPresentation.permissionLabel(
                                      l, option),
                                  ask: option == AgentToolPermission.ask,
                                  selected: option == current,
                                  onTap: () => Navigator.pop(ctx, option)),
                              const SizedBox(height: 8)
                            ],
                          ])))));
      if (selected != null && selected != current && mounted) {
        await _setPermission(descriptor.toolName, selected);
      }
    } finally {
      _sheetOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), permissions = _permissions;
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.agentPermissionsTitle, leading: const BackButton()),
      Expanded(
          child: permissions == null && _error == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  cacheExtent: 0,
                  padding: const EdgeInsets.fromLTRB(17, 16, 17, 28),
                  children: [
                      BeeAIAdvancedNotice(
                          contentKey: const ValueKey('agent-permissions-intro'),
                          text: l.agentPermissionsIntro,
                          icon: const BeeLineIcon('Info', size: 22)),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        BeeStatus(label: _error!, tone: BeeTone.error),
                        const SizedBox(height: 10),
                        BeeButton(
                            label: l.v4RecordingRetry,
                            kind: BeeButtonKind.secondary,
                            onPressed: _load)
                      ],
                      if (permissions != null) ...[
                        const SizedBox(height: 16),
                        _section(
                            l.agentPermissionsReadOnlySection,
                            l.agentPermissionsReadOnlySectionDescription,
                            false,
                            permissions,
                            l),
                        const SizedBox(height: 12),
                        _section(
                            l.agentPermissionsWriteSection,
                            l.agentPermissionsWriteSectionDescription,
                            true,
                            permissions,
                            l),
                        const SizedBox(height: 12),
                        BeeAIAdvancedDefaults(
                            summary: AgentToolPermissionCatalog.descriptors
                                    .where((d) =>
                                        (permissions[d.toolName] ??
                                            d.defaultPermission) !=
                                        d.defaultPermission)
                                    .isEmpty
                                ? l.agentPermissionsDefaultsActive
                                : l.agentPermissionsModifiedCount(
                                    AgentToolPermissionCatalog.descriptors
                                        .where((d) =>
                                            (permissions[d.toolName] ??
                                                d.defaultPermission) !=
                                            d.defaultPermission)
                                        .length),
                            restoreLabel: l.agentPermissionsRestoreDefaults,
                            restoreKey:
                                const ValueKey('restore-agent-permissions'),
                            busy: _restoring,
                            onRestore:
                                _writing.isNotEmpty ? null : _restoreDefaults),
                      ],
                    ]))
    ]));
  }

  Widget _section(String title, String subtitle, bool writes,
          Map<String, AgentToolPermission> permissions, AppLocalizations l) =>
      BeeAIAdvancedPermissionSection(
          title: title,
          subtitle: subtitle,
          icon: BeeLineIcon(writes ? 'PencilLine' : 'Eye', size: 22),
          rows: [
            for (final d in AgentToolPermissionCatalog.descriptors
                .where((d) => d.mutatesLocalData == writes))
              BeeAIAdvancedPermissionRow(
                  title: AgentToolPresentation.label(l, d.toolName),
                  description: AgentToolPresentation.description(l, d.toolName),
                  status: AgentToolPresentation.permissionLabel(
                      l, permissions[d.toolName] ?? d.defaultPermission),
                  ask: (permissions[d.toolName] ?? d.defaultPermission) ==
                      AgentToolPermission.ask,
                  busy: _writing.contains(d.toolName) || _restoring,
                  statusKey: ValueKey('permission-status-${d.toolName}'),
                  onTap: _confirmingRestore
                      ? null
                      : () => _showPermissionSheet(
                          d, permissions[d.toolName] ?? d.defaultPermission)),
          ]);
}
