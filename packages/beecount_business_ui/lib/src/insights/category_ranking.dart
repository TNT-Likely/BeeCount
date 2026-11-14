import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

class BeeRankItem {
  const BeeRankItem(
      {required this.id,
      required this.label,
      required this.amount,
      required this.fraction,
      required this.icon,
      this.description,
      this.children = const []});
  final String id, label, amount;
  final String? description;
  final double fraction;
  final Widget icon;
  final List<BeeRankItem> children;
}

class BeeCategoryRanking extends StatelessWidget {
  const BeeCategoryRanking(
      {super.key,
      required this.items,
      required this.expanded,
      required this.onExpand,
      required this.onDetail});
  final List<BeeRankItem> items;
  final Set<String> expanded;
  final ValueChanged<String> onExpand, onDetail;
  @override
  Widget build(BuildContext context) => Column(
      children: items
          .map((item) => Column(children: [
                Row(children: [
                  InkWell(
                      onTap: () => onDetail(item.id),
                      child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(child: item.icon))),
                  Expanded(
                      child: InkWell(
                          onTap: () => item.children.isEmpty
                              ? onDetail(item.id)
                              : onExpand(item.id),
                          child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    BeeProgress(
                                        value: item.fraction,
                                        label: item.label,
                                        trailing: item.amount),
                                    if (item.description != null)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(item.description!,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Theme.of(context)
                                                      .hintColor)))
                                  ])))),
                  if (item.children.isNotEmpty)
                    IconButton(
                        onPressed: () => onExpand(item.id),
                        icon: BeeLineIcon(
                            expanded.contains(item.id)
                                ? 'ChevronUp'
                                : 'ChevronDown',
                            size: 14))
                ]),
                if (expanded.contains(item.id))
                  Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: BeeCategoryRanking(
                          items: item.children,
                          expanded: expanded,
                          onExpand: onExpand,
                          onDetail: onDetail)),
              ]))
          .toList());
}
