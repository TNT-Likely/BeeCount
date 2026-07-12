import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../providers.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../../styles/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/ui_scale_extensions.dart';

/// 存储空间管理页面
class StorageManagementPage extends ConsumerStatefulWidget {
  const StorageManagementPage({super.key});

  @override
  ConsumerState<StorageManagementPage> createState() =>
      _StorageManagementPageState();
}

class _StorageManagementPageState extends ConsumerState<StorageManagementPage> {
  bool _isScanning = true;
  int _aiModelsSize = 0; // AI模型大小(字节)
  int _apkFilesSize = 0; // APK文件大小(字节)
  List<FileSystemEntity> _aiModelFiles = [];
  List<FileSystemEntity> _apkFiles = [];

  @override
  void initState() {
    super.initState();
    _scanStorage();
  }

  /// 扫描存储空间
  Future<void> _scanStorage() async {
    setState(() {
      _isScanning = true;
    });

    try {
      // 扫描AI模型
      await _scanAIModels();

      // 扫描APK文件(仅Android)
      if (Platform.isAndroid) {
        await _scanAPKFiles();
      }
    } catch (e) {
      print('扫描存储空间失败: $e');
    }

    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  /// 扫描AI模型文件
  Future<void> _scanAIModels() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/ai_models');

      if (await modelsDir.exists()) {
        final files = modelsDir
            .listSync()
            .where(
                (entity) => entity is File && entity.path.endsWith('.tflite'))
            .toList();

        int totalSize = 0;
        for (var file in files) {
          if (file is File) {
            totalSize += await file.length();
          }
        }

        _aiModelFiles = files;
        _aiModelsSize = totalSize;
      } else {
        _aiModelFiles = [];
        _aiModelsSize = 0;
      }
    } catch (e) {
      print('扫描AI模型失败: $e');
      _aiModelFiles = [];
      _aiModelsSize = 0;
    }
  }

  /// 扫描APK文件
  Future<void> _scanAPKFiles() async {
    try {
      final downloadDir = await getExternalStorageDirectory();
      if (downloadDir == null) {
        _apkFiles = [];
        _apkFilesSize = 0;
        return;
      }

      final files = downloadDir
          .listSync()
          .where((entity) =>
              entity is File &&
              entity.path.contains('BeeCount_') &&
              entity.path.endsWith('.apk'))
          .toList();

      int totalSize = 0;
      for (var file in files) {
        if (file is File) {
          totalSize += await file.length();
        }
      }

      _apkFiles = files;
      _apkFilesSize = totalSize;
    } catch (e) {
      print('扫描APK文件失败: $e');
      _apkFiles = [];
      _apkFilesSize = 0;
    }
  }

  /// 格式化文件大小
  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// 清理AI模型
  Future<void> _clearAIModels() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppDialog.confirm(
      context,
      title: l10n.storageClearConfirmTitle,
      message: l10n.storageClearAIModelsMessage(_formatSize(_aiModelsSize)),
    );

    if (confirmed != true) return;

    try {
      for (var file in _aiModelFiles) {
        if (file is File && await file.exists()) {
          await file.delete();
        }
      }

      showToast(context, l10n.storageClearSuccess);
      await _scanStorage();
    } catch (e) {
      showToast(context, '${l10n.commonError}: $e');
    }
  }

  /// 清理APK文件
  Future<void> _clearAPKFiles() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppDialog.confirm(
      context,
      title: l10n.storageClearConfirmTitle,
      message: l10n.storageClearAPKMessage(_formatSize(_apkFilesSize)),
    );

    if (confirmed != true) return;

    try {
      for (var file in _apkFiles) {
        if (file is File && await file.exists()) {
          await file.delete();
        }
      }

      showToast(context, l10n.storageClearSuccess);
      await _scanStorage();
    } catch (e) {
      showToast(context, '${l10n.commonError}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.storageManagementTitle,
            subtitle: l10n.storageManagementSubtitle,
            showBack: true,
          ),
          Expanded(
            child: _isScanning
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.0.scaled(context, ref),
                      vertical: 8.0.scaled(context, ref),
                    ),
                    children: [
                      // AI模型
                      SectionCard(
                        margin: EdgeInsets.zero,
                        child: AppListTile(
                          leading: Icons.psychology_outlined,
                          title: l10n.storageAIModels,
                          subtitle: _aiModelFiles.isEmpty
                              ? l10n.storageNoData
                              : '${_aiModelFiles.length} ${l10n.storageFiles}',
                          trailing: Text(
                            _formatSize(_aiModelsSize),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _aiModelsSize > 0
                                  ? ref.watch(primaryColorProvider)
                                  : BeeTokens.textSecondary(context),
                            ),
                          ),
                          onTap: _aiModelsSize > 0 ? _clearAIModels : null,
                        ),
                      ),

                      // APK安装包(仅Android)
                      if (Platform.isAndroid) ...[
                        SizedBox(height: 8.0.scaled(context, ref)),
                        SectionCard(
                          margin: EdgeInsets.zero,
                          child: AppListTile(
                            leading: Icons.android,
                            title: l10n.storageAPKFiles,
                            subtitle: _apkFiles.isEmpty
                                ? l10n.storageNoData
                                : '${_apkFiles.length} ${l10n.storageFiles}',
                            trailing: Text(
                              _formatSize(_apkFilesSize),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _apkFilesSize > 0
                                    ? ref.watch(primaryColorProvider)
                                    : BeeTokens.textSecondary(context),
                              ),
                            ),
                            onTap: _apkFilesSize > 0 ? _clearAPKFiles : null,
                          ),
                        ),
                      ],

                      // 提示信息
                      SizedBox(height: 16.0.scaled(context, ref)),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.0.scaled(context, ref),
                        ),
                        child: Text(
                          l10n.storageHint,
                          style: TextStyle(
                            fontSize: 12,
                            color: BeeTokens.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
