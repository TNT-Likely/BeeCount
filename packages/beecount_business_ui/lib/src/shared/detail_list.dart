import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

class BeeDetailItem {
  const BeeDetailItem(
      {required this.label, required this.value, this.icon, this.onTap});
  final String label;
  final Widget value;
  final Widget? icon;
  final VoidCallback? onTap;
}

class BeeDetailList extends StatelessWidget {
  const BeeDetailList({super.key, required this.items});
  final List<BeeDetailItem> items;
  @override
  Widget build(BuildContext context) => BeeSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
          children: items
              .asMap()
              .entries
              .map((e) => Column(children: [
                    InkWell(
                        onTap: e.value.onTap,
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Row(children: [
                                  if (e.value.icon != null) ...[
                                    e.value.icon!,
                                    const SizedBox(width: 8)
                                  ],
                                  SizedBox(
                                      width: 60,
                                      child: Text(e.value.label,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .hintColor))),
                                  Expanded(
                                      child: Align(
                                          alignment: Alignment.centerRight,
                                          child: e.value.value)),
                                  if (e.value.onTap != null) ...[
                                    const SizedBox(width: 6),
                                    const BeeLineIcon('ChevronRight', size: 14)
                                  ]
                                ])))),
                    if (e.key < items.length - 1)
                      Divider(
                          height: 1,
                          color: Theme.of(context).dividerColor,
                          thickness: .6),
                  ]))
              .toList()));
}
