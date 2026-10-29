import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../transactions/transaction_presentation.dart';

class BeeTagLibraryItem {
  const BeeTagLibraryItem({required this.tag, required this.count});
  final BeeTagData tag;
  final String count;
}

/// Controlled library grid. The host supplies live counts, navigation and writes.
class BeeTagLibrary extends StatelessWidget {
  const BeeTagLibrary(
      {super.key,
      required this.items,
      required this.deleteLabel,
      required this.onOpen,
      required this.onDelete,
      this.controller,
      this.footer,
      this.enabled = true});
  final List<BeeTagLibraryItem> items;
  final String deleteLabel;
  final ValueChanged<String> onOpen, onDelete;
  final ScrollController? controller;
  final Widget? footer;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final line = MediaQuery.textScalerOf(context).scale(14) / 14;
    return CustomScrollView(controller: controller, slivers: [
      SliverPadding(
          padding: const EdgeInsets.fromLTRB(17, 4, 17, 12),
          sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisExtent: 78 + 42 * line,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12),
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = items[index];
                return BeeSurface(
                    padding: EdgeInsets.zero,
                    child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: enabled ? () => onOpen(item.tag.id) : null,
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                      child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Container(
                                            width: 10,
                                            height: 10,
                                            margin:
                                                const EdgeInsets.only(top: 5),
                                            decoration: BoxDecoration(
                                                color: item.tag.color,
                                                shape: BoxShape.circle)),
                                        const SizedBox(width: 7),
                                        Expanded(
                                            child: Text(item.tag.label,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w600)))
                                      ])),
                                  Row(children: [
                                    Expanded(
                                        child: Text(item.count,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(context)
                                                    .hintColor))),
                                    BeeIconButton(
                                        label: '$deleteLabel ${item.tag.label}',
                                        icon: const BeeLineIcon('Trash2',
                                            size: 17),
                                        onPressed: enabled
                                            ? () => onDelete(item.tag.id)
                                            : null)
                                  ])
                                ]))));
              }, childCount: items.length))),
      if (footer != null)
        SliverPadding(
            padding: const EdgeInsets.fromLTRB(17, 0, 17, 24),
            sliver: SliverToBoxAdapter(child: footer)),
    ]);
  }
}
