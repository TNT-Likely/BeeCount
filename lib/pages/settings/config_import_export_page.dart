import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/ui/ui.dart';
import '../../utils/file_picker_helper.dart';
import '../../providers/font_scale_provider.dart';
import '../../providers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/export/config_export_service.dart';
import '../../services/system/logger_service.dart';

part '../../presentation/v4/bindings/config_transfer_actions.dart';
part '../../presentation/v4/bindings/config_transfer_dialogs.dart';

class ConfigImportExportPage extends ConsumerStatefulWidget {
  const ConfigImportExportPage({super.key});
  @override
  ConsumerState<ConfigImportExportPage> createState() =>
      _ConfigImportExportPageState();
}

class _ConfigImportExportPageState extends ConsumerState<ConfigImportExportPage>
    with _ConfigTransferActions {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), busy = _isExporting || _isImporting;
    return Scaffold(
        backgroundColor: BeeCardTheme.of(context).canvas,
        body: Column(children: [
          BeePageHeader(
              title: l.configImportExportTitle, leading: const BackButton()),
          Expanded(
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(17, 4, 17, 24),
                  children: [
                BeeSurface(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Text(l.configImportExportInfoTitle,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(l.configImportExportInfoMessage,
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              color: Theme.of(context).hintColor))
                    ])),
                const SizedBox(height: 12),
                BeeSurface(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(children: [
                      BeeMenuRow(
                          title: l.configExportTitle,
                          subtitle: l.configExportSubtitle,
                          leading: const BeeLineIcon('Upload', size: 19),
                          onTap: busy ? null : _exportConfig,
                          trailing: _isExporting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5))
                              : null),
                      const Divider(height: 1, indent: 12, endIndent: 12),
                      BeeMenuRow(
                          title: l.configImportTitle,
                          subtitle: l.configImportSubtitle,
                          leading: const BeeLineIcon('Download', size: 19),
                          onTap: busy ? null : _importConfig,
                          trailing: _isImporting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5))
                              : null),
                    ])),
                if (Platform.isAndroid && _lastExportedFilePath != null) ...[
                  const SizedBox(height: 12),
                  BeeSurface(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        BeeStatus(
                            label: l.configExportSuccess,
                            detail: l.configExportSavedTo(_lastExportedFilePath!
                                .replaceAll('/storage/emulated/0/', '')),
                            tone: BeeTone.success),
                        const SizedBox(height: 8),
                        BeeButton(
                            label: l.configExportViewContent,
                            kind: BeeButtonKind.secondary,
                            onPressed: _viewExportedContent)
                      ]))
                ],
                const SizedBox(height: 12),
                BeeSurface(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Text(l.configImportExportIncludesTitle,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      for (final row in _configChoices(l))
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(children: [
                              const BeeLineIcon('Check', size: 15),
                              const SizedBox(width: 9),
                              Expanded(
                                  child: Text(row.label,
                                      style: const TextStyle(fontSize: 13)))
                            ])),
                      Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                              [
                                l.configIncludeSupabase,
                                l.configIncludeWebdav,
                                l.configIncludeS3
                              ].join(' · '),
                              style: TextStyle(
                                  fontSize: 11,
                                  height: 1.6,
                                  color: Theme.of(context).hintColor)))
                    ]))
              ]))
        ]));
  }
}
