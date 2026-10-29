import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../services/attachment_export_import_service.dart';
import 'attachments/bindings/attachment_library_data.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';

class AttachmentPreviewPage extends ConsumerStatefulWidget {
  const AttachmentPreviewPage(
      {super.key, this.exportData, this.archiveData, required this.title})
      : assert(
            (exportData != null && archiveData == null) ||
                (exportData == null && archiveData != null),
            'Must provide either exportData or archiveData, but not both');
  final ExportPreviewData? exportData;
  final ArchivePreviewData? archiveData;
  final String title;
  @override
  ConsumerState<AttachmentPreviewPage> createState() =>
      _AttachmentPreviewPageState();
}

class _AttachmentPreviewPageState extends ConsumerState<AttachmentPreviewPage>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 2, vsync: this)..addListener(revealTab);
  }

  final tabScroll = ScrollController();
  void revealTab() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && tabScroll.hasClients) {
        tabScroll
            .jumpTo(tabs.index == 0 ? 0 : tabScroll.position.maxScrollExtent);
      }
    });
  }

  late final data = AttachmentLibraryData(
      exportData: widget.exportData, archiveData: widget.archiveData);
  String? selectedId;
  @override
  void dispose() {
    tabs.dispose();
    tabScroll.dispose();
    super.dispose();
  }

  Future<void> open(int group, int index) async {
    final item = data.items(group)[index];
    setState(() => selectedId = item.id);
    await showAttachmentLibraryItem(context, data, group, index);
    if (mounted) setState(() => selectedId = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        attachments = data.items(0),
        icons = data.items(1),
        total = attachments.length + icons.length;
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: widget.title,
          subtitle: l.attachmentPreviewSubtitle(total),
          leading: const BackButton()),
      if (total > 0) ...[
        Padding(
            padding: const EdgeInsets.fromLTRB(17, 12, 17, 0),
            child: AnimatedBuilder(
                animation: tabs,
                builder: (context, _) => BeeSegmented<int>(
                    scrollController: tabScroll,
                    items: [
                      BeeSegment(
                          0, '${l.v4DataAttachments} (${attachments.length})'),
                      BeeSegment(1, '${l.v4CustomIcons} (${icons.length})')
                    ],
                    value: tabs.index,
                    onChanged: tabs.animateTo))),
        const SizedBox(height: 6)
      ],
      Expanded(
          child: total == 0
              ? BeeEmptyState(
                  title: l.attachmentPreviewEmpty,
                  icon: const BeeLineIcon('Images', size: 36))
              : TabBarView(controller: tabs, children: [
                  for (var group = 0; group < 2; group++)
                    BeeAttachmentLibrary(
                        key: PageStorageKey('preview-group-$group'),
                        items: group == 0 ? attachments : icons,
                        emptyLabel: l.attachmentPreviewEmpty,
                        selectedId: selectedId,
                        metadataBuilder: (index) => data.metadata(group, index),
                        onOpen: (index) => open(group, index))
                ]))
    ]));
  }
}
