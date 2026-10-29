part of '../../tag_manage_page.dart';

mixin _TagLibraryActions on ConsumerState<TagManagePage> {
  bool _busy = false;
  bool _working = false;
  TagLibraryData get _data => TagLibraryData(ref.read(repositoryProvider));
  void _refresh() => ref.read(tagListRefreshProvider.notifier).state++;
  void _sync() {
    final ledger = ref.read(currentLedgerIdProvider);
    if (ledger > 0) unawaited(PostProcessor.sync(ref, ledgerId: ledger));
  }

  Future<void> _run(Future<void> Function() action, String failure) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _working = true;
    });
    try {
      await action();
    } catch (e) {
      logger.error('TagManage', '标签操作失败: $e');
      if (mounted) showBeeToast(context, failure, tone: BeeTone.error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _working = false;
        });
      }
    }
  }

  Future<void> _delete(Tag tag) async {
    final l = AppLocalizations.of(context);
    final yes = await showBeeConfirm(context,
        title: l.tagDeleteConfirmTitle,
        message: l.tagDeleteConfirmMessage(tag.name),
        confirmLabel: l.commonDelete,
        cancelLabel: l.commonCancel,
        danger: true);
    if (!yes || !mounted) return;
    await _run(() async {
      await ref.read(repositoryProvider).deleteTag(tag.id);
      if (mounted) {
        _refresh();
        showBeeToast(context, l.tagDeleteSuccess, tone: BeeTone.success);
      }
    }, l.commonError);
  }

  Future<void> _generate() async {
    final l = AppLocalizations.of(context);
    final yes = await showBeeConfirm(context,
        title: l.tagManageGenerateDefault,
        message: l.tagManageGenerateDefaultConfirm,
        confirmLabel: l.commonConfirm,
        cancelLabel: l.commonCancel);
    if (!yes || !mounted) return;
    await _run(() async {
      await _data.generate(l);
      if (mounted) {
        _sync();
        _refresh();
        showBeeToast(context, l.tagManageGenerateDefaultSuccess,
            tone: BeeTone.success);
      }
    }, l.commonError);
  }

  Future<void> _share() async {
    final l = AppLocalizations.of(context);
    await _run(() async {
      final yaml = await _data.export(ref.read(currentLedgerIdProvider));
      if (!mounted) return;
      final path = await widget.files.share(yaml, l.tagShareSubject);
      if (mounted && path != null) {
        showBeeToast(context, l.tagShareSuccess(path), tone: BeeTone.success);
      }
    }, l.tagShareFailed);
  }

  Future<void> _import() async {
    final l = AppLocalizations.of(context);
    await _run(() async {
      String? path;
      try {
        path = await widget.files.pick();
      } on TagLibraryMissingPath {
        if (mounted) {
          showBeeToast(context, l.configImportNoFilePath, tone: BeeTone.error);
        }
        return;
      }
      if (path == null || !mounted) return;
      if (!path.toLowerCase().endsWith('.yml') &&
          !path.toLowerCase().endsWith('.yaml')) {
        showBeeToast(context, l.tagImportInvalidFile, tone: BeeTone.error);
        return;
      }
      final yaml = await widget.files.read(path);
      if (!mounted) return;
      if (!ConfigExportService.detectContent(yaml).hasTags) {
        showBeeToast(context, l.tagImportNoTags, tone: BeeTone.error);
        return;
      }
      setState(() => _working = false);
      final overwrite = await showBeeDialog<bool>(context,
          title: l.tagImportModeTitle,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            BeeMenuRow(
                title: l.tagImportModeMerge,
                subtitle: l.tagImportModeMergeDesc,
                leading: const BeeLineIcon('GitMerge'),
                onTap: () => Navigator.pop(context, false)),
            BeeMenuRow(
                title: l.tagImportModeOverwrite,
                subtitle: l.tagImportModeOverwriteDesc,
                leading: const BeeLineIcon('RefreshCw'),
                onTap: () => Navigator.pop(context, true))
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.commonCancel))
          ]);
      if (overwrite == null || !mounted) return;
      setState(() => _working = true);
      await _data.importYaml(yaml,
          ledgerId: ref.read(currentLedgerIdProvider), overwrite: overwrite);
      if (mounted) {
        _refresh();
        showBeeToast(context, l.tagImportSuccess, tone: BeeTone.success);
      }
    }, l.tagImportFailed);
  }

  Future<void> _clear() async {
    final l = AppLocalizations.of(context);
    await _run(() async {
      final candidates = await _data.unused();
      if (!mounted) return;
      if (candidates.isEmpty) {
        showBeeToast(context, l.tagClearUnusedEmpty);
        return;
      }
      setState(() => _working = false);
      final yes = await showBeeConfirm(context,
          title: l.tagClearUnusedTitle,
          message: l.tagClearUnusedMessage(candidates.length),
          confirmLabel: l.commonDelete,
          cancelLabel: l.commonCancel,
          danger: true);
      if (!yes || !mounted) return;
      setState(() => _working = true);
      final removed = await _data.clearUnused(candidates.map((tag) => tag.id));
      if (mounted) {
        _sync();
        _refresh();
        showBeeToast(context, l.tagClearUnusedSuccess(removed),
            tone: BeeTone.success);
      }
    }, l.tagClearUnusedFailed);
  }
}
