import 'package:beecount_business_ui/cloud_backup.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../utils/app_localizations_resolver.dart';

class CloudBackupSample extends StatefulWidget {
  const CloudBackupSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<CloudBackupSample> createState() => _CloudBackupSampleState();
}

class _CloudBackupSampleState extends State<CloudBackupSample> {
  bool automatic = false, busy = false;
  String event = '局部快照示例，不上传、恢复或删除数据';
  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeCloudBackupSummary(
          title: l.mineSyncTitle,
          status: l.mineSyncLocalNewer(27),
          icon: const BeeLineIcon('CloudUpload', size: 23),
          busy: busy,
          localSummary: l.mineSyncLocalRecords(27),
          remoteSummary: l.mineSyncCloudRecords(26),
          backupTime: l.mineSyncCloudLatest('2026-10-20 09:41:00'),
          onDetails: () => setState(() => event = '示例详情：本地27条，云端26条')),
      const SizedBox(height: 12),
      BeeCloudBackupAction(
          title: l.mineUploadTitle,
          icon: const BeeLineIcon('CloudUpload'),
          busy: busy,
          onTap: () => setState(() {
                busy = true;
                event = '示例上传忙碌状态，不发请求';
              })),
      const SizedBox(height: 12),
      BeeCloudBackupAction(
          title: l.mineDownloadTitle,
          icon: const BeeLineIcon('CloudDownload'),
          enabled: !busy,
          onTap: () => setState(() => event = '示例恢复入口；真实差异预览由App显示')),
      const SizedBox(height: 12),
      BeeCloudBackupPreference(
          title: l.mineAutoSyncTitle,
          subtitle: l.mineAutoSyncSubtitle,
          value: automatic,
          onChanged: (value) => setState(() {
                automatic = value;
                event = '示例自动同步偏好已更新，不写真实配置';
              })),
      const SizedBox(height: 12),
      BeeButton(
          label: l.v4RecordingRetry,
          kind: BeeButtonKind.secondary,
          onPressed: () => setState(() {
                busy = false;
                event = '示例已恢复';
              })),
      const SizedBox(height: 12),
      Text(event,
          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
      if (widget.liveData != null) ...[
        const SizedBox(height: 12),
        widget.liveData!
      ],
    ]);
  }
}
