/// 锁账设置页(Cloud 0067 体验层)。
/// 真正的拦截在服务端(423)，这里只提供配置入口与状态展示。
library;

import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/cloud_secondary_providers.dart';
import '../shared/pickers/wheel_date_picker.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';

class LockSettingsPage extends ConsumerStatefulWidget {
  const LockSettingsPage({super.key});

  @override
  ConsumerState<LockSettingsPage> createState() => _LockSettingsPageState();
}

class _LockSettingsPageState extends ConsumerState<LockSettingsPage> {
  bool? _locked;
  String? _lockDate;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final service = await ref.read(cloudSecondaryServiceProvider.future);
    if (service == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final settings = await service.lockSettings();
      if (mounted) setState(() {
        _locked = settings['is_locked'] == true;
        _lockDate = settings['lock_date'] as String?;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(bool value) async {
    final l = AppLocalizations.of(context);
    if (value && (_lockDate == null || _lockDate!.isEmpty)) {
      showBeeToast(context, l.cloudLockPickDateFirst, tone: BeeTone.warning);
      return;
    }
    final service = await ref.read(cloudSecondaryServiceProvider.future);
    if (service == null) return;
    try {
      await service.patchLockSettings(
        isLocked: value,
        lockDate: _lockDate,
      );
      ref.read(cloudSecondaryRefreshProvider.notifier).state++;
      if (mounted) setState(() => _locked = value);
      if (mounted) {
        showBeeToast(
          context,
          value ? l.cloudLockEnabled : l.cloudLockDisabled,
          tone: BeeTone.success,
        );
      }
    } catch (e) {
      if (mounted) showBeeToast(context, '$e', tone: BeeTone.error);
    }
  }

  Future<void> _pickDate() async {
    final l = AppLocalizations.of(context);
    final initial = _lockDate != null
        ? DateTime.tryParse(_lockDate!) ?? DateTime.now()
        : DateTime.now();
    final picked = await showWheelDatePicker(context, initial: initial);
    if (picked == null) return;
    // 锁账截止时刻 = 当天 00:00 UTC(与 Cloud lock_date 对齐)
    final iso = DateTime.utc(picked.year, picked.month, picked.day)
        .toIso8601String();
    // 日期变化后若当前已锁定,直接同步;否则只存本地待锁定时用
    setState(() => _lockDate = iso);
    if (_locked == true) await _toggle(true);
    if (mounted) showBeeToast(context, l.cloudSaveSuccess, tone: BeeTone.success);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locked = _locked ?? false;
    return V4PageScaffold(
      body: Column(children: [
        BeePageHeader(title: l.cloudLockTitle, leading: const BackButton()),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(17),
                  children: [
                    BeeSurface(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(children: [
                        BeeToggleRow(
                          title: l.cloudLockTitle,
                          subtitle: locked ? l.cloudLockOn : l.cloudLockOff,
                          value: locked,
                          onChanged: _toggle,
                        ),
                        const BeeDivider(),
                        BeeMenuRow(
                          title: l.cloudLockDate,
                          subtitle: _lockDate == null
                              ? l.cloudLockNotSet
                              : _formatDate(_lockDate!),
                          leading: const BeeLineIcon('CalendarDays', size: 20),
                          onTap: _pickDate,
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Text(l.cloudLockHint,
                        style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                    if (locked && _lockDate != null) ...[
                      const SizedBox(height: 16),
                      BeeStatus(
                        label: '${l.cloudLockActive} ${_formatDate(_lockDate!)}',
                        tone: BeeTone.warning,
                      ),
                    ],
                  ],
                ),
        ),
      ]),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso.substring(0, 10);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
