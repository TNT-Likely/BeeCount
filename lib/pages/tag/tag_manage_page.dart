import 'dart:async';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../presentation/v4/bindings/page_scaffold.dart';
import '../../presentation/v4/bindings/tag_detail.dart' show tagDetailColor;
import '../../presentation/v4/bindings/tag_library_data.dart';
import '../../presentation/v4/bindings/tag_library_files.dart';
import '../../services/billing/post_processor.dart';
import '../../services/export/config_export_service.dart';
import '../../services/system/logger_service.dart';
import 'tag_detail_page.dart';
import 'tag_edit_page.dart';

part '../../presentation/v4/bindings/tag_library_actions.dart';

class TagManagePage extends ConsumerStatefulWidget {
  const TagManagePage({super.key, this.files = const TagLibraryFiles()});
  final TagLibraryFiles files;
  @override
  ConsumerState<TagManagePage> createState() => _TagManagePageState();
}

class _TagManagePageState extends ConsumerState<TagManagePage>
    with _TagLibraryActions {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _open(Tag? tag) async {
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => tag == null
                ? const TagEditPage()
                : TagDetailPage(
                    tagId: tag.id, tagName: tag.name, allLedgers: true)));
  }

  Widget _tools(AppLocalizations l, {bool guide = false}) =>
      Builder(builder: (anchor) {
        Future<void> show() async {
          final box = anchor.findRenderObject()! as RenderBox;
          final action = await showBeeContextMenu<String>(context,
              anchor:
                  box.localToGlobal(Offset(box.size.width, box.size.height)),
              items: [
                BeeMenuAction(
                    value: 'add',
                    label: l.tagAddTitle,
                    icon: const BeeLineIcon('Plus', size: 18)),
                BeeMenuAction(
                    value: 'generate',
                    label: l.tagManageGenerateDefault,
                    icon: const BeeLineIcon('Sparkles', size: 18)),
                BeeMenuAction(
                    value: 'import',
                    label: l.tagImport,
                    icon: const BeeLineIcon('Download', size: 18)),
                BeeMenuAction(
                    value: 'clear',
                    label: l.tagClearUnused,
                    icon: const BeeLineIcon('Trash2', size: 18),
                    danger: true)
              ]);
          if (!mounted || action == null || _busy) return;
          switch (action) {
            case 'add':
              await _open(null);
            case 'generate':
              await _generate();
            case 'import':
              await _import();
            case 'clear':
              await _clear();
          }
        }

        return guide
            ? BeeMenuRow(
                title: l.v4TagToolsTitle,
                subtitle: l.v4TagToolsHint,
                leading: const BeeLineIcon('Settings2'),
                onTap: _busy ? null : show)
            : BeeIconButton(
                label: l.commonMore,
                icon: const BeeLineIcon('Ellipsis'),
                onPressed: _busy ? null : show);
      });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        tags = ref.watch(tagsWithStatsProvider);
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.tagManageTitle,
          leading: const BackButton(),
          actions: [
            BeeIconButton(
                label: l.tagShare,
                icon: const BeeLineIcon('Share2'),
                onPressed: _busy ? null : _share),
            _tools(l)
          ]),
      SizedBox(
          height: 2,
          child: _working ? const LinearProgressIndicator(minHeight: 2) : null),
      Expanded(
          child: tags.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                  child: BeeStatus(
                      label: l.commonError,
                      tone: BeeTone.error,
                      action: BeeButton(
                          label: l.v4RecordingRetry,
                          onPressed: () =>
                              ref.invalidate(tagsWithStatsProvider)))),
              data: (rows) {
                if (rows.isEmpty) {
                  return ListView(padding: const EdgeInsets.all(17), children: [
                    BeeEmptyState(
                        title: l.tagManageEmpty,
                        message: l.tagManageEmptyHint,
                        action: BeeButton(
                            label: l.tagManageGenerateDefault,
                            onPressed: _busy ? null : _generate)),
                    _tools(l, guide: true)
                  ]);
                }
                Tag? item(String id) =>
                    rows.where((r) => '${r.tag.id}' == id).firstOrNull?.tag;
                return BeeTagLibrary(
                    key: const PageStorageKey('v4-tag-management-grid'),
                    controller: _scroll,
                    items: [
                      for (final row in rows)
                        BeeTagLibraryItem(
                            tag: BeeTagData(
                                '${row.tag.id}',
                                row.tag.name,
                                tagDetailColor(row.tag.color,
                                    Theme.of(context).colorScheme.primary)),
                            count: l.tagTransactionCount(row.transactionCount))
                    ],
                    deleteLabel: l.commonDelete,
                    enabled: !_busy,
                    footer: _tools(l, guide: true),
                    onOpen: (id) {
                      final tag = item(id);
                      if (tag != null) _open(tag);
                    },
                    onDelete: (id) {
                      final tag = item(id);
                      if (tag != null) _delete(tag);
                    });
              })),
    ]));
  }
}
