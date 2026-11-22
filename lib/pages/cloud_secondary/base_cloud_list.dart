/// Cloud 二次开发列表页的通用骨架与工具。
///
/// 这些页面共享同一套模式：走 REST(非 sync) → loading/error/empty/data 四态 →
/// 列表 + 新建 + 编辑/删除动作。抽出一个基类避免 6 个页面重复样板。
library;

import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/secondary/cloud_secondary_service.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/cloud_secondary_providers.dart';

/// 列表页状态基类：管理 loading/error/rows 与 service 获取。
abstract class CloudListState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T> {
  List<Map<String, dynamic>> rows = const [];
  bool loading = true;
  String? error;

  /// 子类实现：用 service 拉列表数据。
  Future<List<Map<String, dynamic>>> fetch(CloudSecondaryService service);

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final service = await ref.read(cloudSecondaryServiceProvider.future);
      if (service == null) {
        if (mounted) setState(() {
          rows = const [];
          loading = false;
        });
        return;
      }
      final data = await fetch(service);
      if (mounted) setState(() {
        rows = data;
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        error = '$e';
        loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  /// 执行一个写动作(新建/编辑/状态变更),成功后自动刷新 + toast。
  Future<bool> act(
    Future<void> Function(CloudSecondaryService service) action, {
    String? successMessage,
  }) async {
    try {
      final service = await ref.read(cloudSecondaryServiceProvider.future);
      if (service == null) return false;
      await action(service);
      ref.read(cloudSecondaryRefreshProvider.notifier).state++;
      if (mounted && successMessage != null) {
        showBeeToast(context, successMessage, tone: BeeTone.success);
      }
      await load();
      return true;
    } catch (e) {
      if (mounted) showBeeToast(context, '$e', tone: BeeTone.error);
      return false;
    }
  }

  /// 四态 body：loading / error / empty / 自定义列表。
  Widget buildBody({
    required String emptyText,
    required Widget Function(BuildContext, int) itemBuilder,
    String? needCloudText,
  }) {
    final l = AppLocalizations.of(context);
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: BeeStatus(
          label: error!,
          tone: BeeTone.error,
          action: BeeButton(
            label: l.cloudRetry,
            kind: BeeButtonKind.quiet,
            onPressed: load,
          ),
        ),
      );
    }
    if (rows.isEmpty) {
      return Center(child: BeeEmptyState(title: emptyText));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(17, 4, 17, 24),
      itemCount: rows.length,
      itemBuilder: itemBuilder,
    );
  }

  /// 通用新建对话框：只有一个名称字段。返回输入的名称(取消/空返回 null)。
  Future<String?> askName(String title, String label) async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final ok = await showBeeDialog<bool>(
      context,
      title: title,
      child: BeeField(label: label, controller: ctrl),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel)),
        BeeButton(
            label: l.commonSave,
            onPressed: () => Navigator.pop(context, true)),
      ],
    );
    if (ok != true) return null;
    final name = ctrl.text.trim();
    return name.isEmpty ? null : name;
  }

  /// 通用删除确认。
  Future<bool> confirmDelete(String title, String message) => showBeeConfirm(
        context,
        title: title,
        message: message,
        confirmLabel: AppLocalizations.of(context).commonDelete,
        cancelLabel: AppLocalizations.of(context).commonCancel,
        danger: true,
      );

  /// 安全取 id(兼容 id / sync_id)。
  String idOf(Map<String, dynamic> row) =>
      (row['id'] ?? row['sync_id'] ?? '').toString();

  /// 安全取 name。
  String nameOf(Map<String, dynamic> row) => (row['name'] ?? '').toString();

  /// 解析 ISO 日期为本地字符串(展示用)。
  String dateText(dynamic v) {
    if (v == null) return '';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return v.toString().substring(0, 10);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
