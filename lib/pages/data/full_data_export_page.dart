import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/export/full_data_export_service.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';

final fullDataExportServiceProvider = Provider<FullDataExportService>((ref) {
  return FullDataExportService(
    ref.watch(databaseProvider),
    downloadAttachment: (id) async {
      final cloud = await ref.read(beecountCloudProviderInstance.future);
      return cloud?.downloadAttachment(fileId: id);
    },
  );
});

/// Reusable settings row. Other entry surfaces can also call [FullDataExportPage.open].
class FullDataExportEntry extends StatelessWidget {
  const FullDataExportEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BeeMenuRow(
      title: l10n.fullDataExportTitle,
      subtitle: l10n.fullDataExportSubtitle,
      leading: const BeeLineIcon('Archive', size: 20),
      onTap: () => FullDataExportPage.open(context),
    );
  }
}

class FullDataExportPage extends ConsumerStatefulWidget {
  const FullDataExportPage({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const FullDataExportPage()),
      );

  @override
  ConsumerState<FullDataExportPage> createState() => _FullDataExportPageState();
}

class _FullDataExportPageState extends ConsumerState<FullDataExportPage> {
  FullDataExportResult? _result;
  String? _error;
  bool _generating = false;
  bool _sharing = false;

  Future<void> _generate() async {
    if (_generating || _sharing) return;
    setState(() {
      _generating = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await ref.read(fullDataExportServiceProvider).export(
            l10n: AppLocalizations.of(context),
          );
      if (mounted) setState(() => _result = result);
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = AppLocalizations.of(context).fullDataExportError);
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _share() async {
    final result = _result;
    if (result == null || _sharing) return;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize && !box.size.isEmpty
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    setState(() {
      _sharing = true;
      _error = null;
    });
    try {
      await SharePlus.instance.share(ShareParams(
        files: [XFile(result.file.path, mimeType: 'application/zip')],
        sharePositionOrigin: origin,
      ));
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = AppLocalizations.of(context).fullDataExportShareError);
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = _result;
    final colors = Theme.of(context).colorScheme;
    return V4PageScaffold(
      body: Column(children: [
        BeePageHeader(
            title: l10n.fullDataExportTitle, leading: const BackButton()),
        Expanded(
          child: BeePageBody(eager: true, children: [
            Text(l10n.fullDataExportDescription,
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.5)),
            const SizedBox(height: 16),
            BeeSurface(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
              child: Column(children: [
                BeeMenuRow(
                  title: l10n.fullDataExportLedgers,
                  leading: const BeeLineIcon('BookOpen', size: 20),
                ),
                const BeeDivider(height: .6),
                BeeMenuRow(
                  title: l10n.fullDataExportAttachments,
                  leading: const BeeLineIcon('Image', size: 20),
                ),
                const BeeDivider(height: .6),
                BeeMenuRow(
                  title: l10n.fullDataExportConfiguration,
                  leading: const BeeLineIcon('FileCog', size: 20),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Text(l10n.fullDataExportPrivacy,
                style: TextStyle(
                    color: colors.onSurfaceVariant, fontSize: 12, height: 1.5)),
            if (result != null || _error != null) ...[
              const SizedBox(height: 12),
              BeeSurface(
                padding: const EdgeInsets.all(13),
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (result != null)
                          Text(l10n.fullDataExportReady(
                              result.ledgerCount, result.attachmentCount)),
                        if (result != null && result.missingFileCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                                l10n.fullDataExportMissing(
                                    result.missingFileCount),
                                style:
                                    TextStyle(color: colors.onSurfaceVariant)),
                          ),
                        if (_error case final error?)
                          Text(error, style: TextStyle(color: colors.error)),
                      ]),
                ),
              ),
            ],
            const SizedBox(height: 20),
            BeeButton(
              label: _generating
                  ? l10n.fullDataExportGenerating
                  : result != null
                      ? l10n.fullDataExportShare
                      : l10n.fullDataExportGenerate,
              onPressed: result != null ? _share : _generate,
              loading: _generating || _sharing,
            ),
            if (result != null)
              BeeButton(
                label: l10n.fullDataExportAgain,
                onPressed: _sharing ? null : _generate,
                kind: BeeButtonKind.quiet,
              ),
          ]),
        ),
      ]),
    );
  }
}
