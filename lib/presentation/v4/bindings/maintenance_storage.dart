import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/maintenance.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/ui/ui.dart' show AppDialog, showToast;
import 'maintenance_access.dart';
import 'page_scaffold.dart';

class MaintenanceStorageControls extends ConsumerStatefulWidget {
  const MaintenanceStorageControls({super.key});
  @override
  ConsumerState<MaintenanceStorageControls> createState() => _StorageState();
}

class _StorageState extends ConsumerState<MaintenanceStorageControls> {
  bool _scanning = true, _scanActive = false, _busy = false;
  int _modelsSize = 0, _apkSize = 0;
  List<FileSystemEntity> _models = [], _apks = [];
  String? _error;
  late MaintenanceStorageAccess _access;
  @override
  void initState() {
    super.initState();
    _access = ref.read(maintenanceStorageAccessProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scan();
    });
  }

  Future<void> _scan() async {
    if (_scanActive) return;
    _scanActive = true;
    setState(() {
      _scanning = true;
      _error = null;
    });
    final android =
        ref.read(maintenancePlatformProvider) == TargetPlatform.android;
    try {
      await _scanModels();
      if (android) await _scanApks();
    } catch (e) {
      _error = e.toString();
    } finally {
      _scanActive = false;
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _scanModels() async {
    try {
      final docs = await _access.documents();
      final dir = Directory('${docs.path}/ai_models');
      if (await dir.exists()) {
        final files = dir
            .listSync()
            .where((e) => e is File && e.path.endsWith('.tflite'))
            .toList();
        var size = 0;
        for (final file in files) {
          if (file is File) size += await file.length();
        }
        _models = files;
        _modelsSize = size;
      } else {
        _models = [];
        _modelsSize = 0;
      }
    } catch (e) {
      _models = [];
      _modelsSize = 0;
      _error = e.toString();
    }
  }

  Future<void> _scanApks() async {
    try {
      final dir = await _access.external();
      if (dir == null) {
        _apks = [];
        _apkSize = 0;
        return;
      }
      final files = dir
          .listSync()
          .where((e) =>
              e is File &&
              e.path.contains('BeeCount_') &&
              e.path.endsWith('.apk'))
          .toList();
      var size = 0;
      for (final file in files) {
        if (file is File) size += await file.length();
      }
      _apks = files;
      _apkSize = size;
    } catch (e) {
      _apks = [];
      _apkSize = 0;
      _error = e.toString();
    }
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _clear(bool models) async {
    if (_busy || _scanActive) return;
    setState(() => _busy = true);
    final l = AppLocalizations.of(context),
        files = List<FileSystemEntity>.of(models ? _models : _apks);
    try {
      final confirmed = await AppDialog.confirm(context,
          title: l.storageClearConfirmTitle,
          message: models
              ? l.storageClearAIModelsMessage(_size(_modelsSize))
              : l.storageClearAPKMessage(_size(_apkSize)));
      if (confirmed != true || !mounted) return;
      for (final file in files) {
        if (file is File && await file.exists()) await _access.deleteFile(file);
      }
      if (!mounted) return;
      showToast(context, l.storageClearSuccess);
      await _scan();
    } catch (e) {
      if (mounted) {
        showToast(context, '${l.commonError}: $e');
        await _scan();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        android =
            ref.watch(maintenancePlatformProvider) == TargetPlatform.android;
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.storageManagementTitle,
          subtitle: l.storageManagementSubtitle,
          leading: const BackButton()),
      Expanded(
          child: _scanning
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(17), children: [
                  if (_error != null) ...[
                    BeeStatus(
                        label: '${l.commonError}: $_error',
                        tone: BeeTone.error),
                    const SizedBox(height: 10),
                    BeeButton(
                        label: l.v4RecordingRetry,
                        kind: BeeButtonKind.secondary,
                        onPressed: _busy ? null : _scan),
                    const SizedBox(height: 12)
                  ],
                  BeeMaintenanceAction(
                      key: const ValueKey('maintenance-clear-models'),
                      title: l.storageAIModels,
                      subtitle: _models.isEmpty
                          ? l.storageNoData
                          : '${_models.length} ${l.storageFiles}',
                      value: _size(_modelsSize),
                      icon: const BeeLineIcon('Brain', size: 22),
                      busy: _busy,
                      onTap: _modelsSize > 0 ? () => _clear(true) : null),
                  if (android) ...[
                    const SizedBox(height: 12),
                    BeeMaintenanceAction(
                        key: const ValueKey('maintenance-clear-apks'),
                        title: l.storageAPKFiles,
                        subtitle: _apks.isEmpty
                            ? l.storageNoData
                            : '${_apks.length} ${l.storageFiles}',
                        value: _size(_apkSize),
                        icon: const BeeLineIcon('Package', size: 22),
                        busy: _busy,
                        onTap: _apkSize > 0 ? () => _clear(false) : null)
                  ],
                  const SizedBox(height: 16),
                  Text(l.storageHint,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: Theme.of(context).hintColor)),
                ]))
    ]));
  }
}
