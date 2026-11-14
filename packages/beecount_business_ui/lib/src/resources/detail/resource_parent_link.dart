import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// One parent reference inside a resource's summary, rather than a duplicate
/// standalone title. Full name remains available to accessibility and tooltip.
class BeeResourceParentLink extends StatelessWidget {
  const BeeResourceParentLink({
    super.key,
    required this.label,
    required this.name,
    required this.onPressed,
  });
  final String label, name;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
          message: '$label · $name',
          child: InkWell(
              onTap: onPressed,
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 32),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    BeeLineIcon('CornerUpLeft',
                        size: 13, color: Theme.of(context).hintColor),
                    const SizedBox(width: 5),
                    Text(label,
                        style: TextStyle(
                            fontSize: 10, color: Theme.of(context).hintColor)),
                    const SizedBox(width: 5),
                    Flexible(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11))),
                    const SizedBox(width: 3),
                    BeeLineIcon('ChevronRight',
                        size: 10, color: Theme.of(context).hintColor),
                  ])))));
}
