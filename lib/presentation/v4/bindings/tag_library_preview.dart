import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/tag/tag_manage_page.dart';
import '../../../providers.dart';
import 'tag_detail.dart' show tagDetailColor;

/// The gallery reads the same live repository as the production library. Writes
/// are reached through its normal page and confirmation flow.
class LiveTagLibraryPreview extends ConsumerWidget {
  const LiveTagLibraryPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        rows = ref.watch(tagsWithStatsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.tagManageTitle,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      rows.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) =>
              BeeStatus(label: l.commonError, tone: BeeTone.error),
          data: (items) => items.isEmpty
              ? BeeEmptyState(
                  title: l.tagManageEmpty, message: l.tagManageEmptyHint)
              : SizedBox(
                  height: 260,
                  child: BeeTagLibrary(
                      enabled: false,
                      items: [
                        for (final item in items)
                          BeeTagLibraryItem(
                              tag: BeeTagData(
                                  '${item.tag.id}',
                                  item.tag.name,
                                  tagDetailColor(item.tag.color,
                                      Theme.of(context).colorScheme.primary)),
                              count:
                                  l.tagTransactionCount(item.transactionCount))
                      ],
                      deleteLabel: l.commonDelete,
                      onOpen: (_) {},
                      onDelete: (_) {}))),
      const SizedBox(height: 8),
      BeeButton(
          label: l.tagManageTitle,
          onPressed: () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => const TagManagePage())))
    ]);
  }
}
