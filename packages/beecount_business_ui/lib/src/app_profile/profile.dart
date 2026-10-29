import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

/// Lightweight identity row. The host provides either transparent art or one
/// cropped photo; this component does not add another avatar background/frame.
class BeeProfile extends StatelessWidget {
  const BeeProfile(
      {super.key,
      required this.nickname,
      this.greeting,
      this.profileLabel,
      this.editLabel,
      required this.subtitle,
      required this.avatar,
      required this.onEdit,
      required this.onTap});
  final String nickname, subtitle;
  final String? greeting, profileLabel, editLabel;
  final Widget avatar;
  final VoidCallback onEdit, onTap;

  @override
  Widget build(BuildContext context) => Semantics(
      container: true,
      child: Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 3),
          child: Row(children: [
            Semantics(
                container: true,
                button: true,
                label: profileLabel ?? nickname,
                excludeSemantics: true,
                onTap: onTap,
                child: InkWell(
                    onTap: onTap,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                        key: const ValueKey('profile-avatar'),
                        width: 48,
                        height: 48,
                        child: ClipOval(child: avatar)))),
            const SizedBox(width: 11),
            Expanded(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  if (greeting != null)
                    Text(greeting!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10,
                            height: 1.5,
                            color: Theme.of(context).hintColor)),
                  Semantics(
                      container: true,
                      button: true,
                      label: editLabel,
                      child: InkWell(
                          onTap: onEdit,
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 29),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                        child: Text(nickname,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 19,
                                                height: 1.2,
                                                fontWeight: FontWeight.w600))),
                                    const SizedBox(width: 5),
                                    BeeLineIcon('PencilLine',
                                        size: 12,
                                        color: Theme.of(context).hintColor)
                                  ])))),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10,
                          height: 1.5,
                          color: Theme.of(context).hintColor))
                ])),
            Semantics(
                container: true,
                button: true,
                label: profileLabel ?? nickname,
                excludeSemantics: true,
                onTap: onTap,
                child: SizedBox(
                    width: 32,
                    height: 44,
                    child: IconButton(
                        tooltip: profileLabel,
                        padding: EdgeInsets.zero,
                        onPressed: onTap,
                        icon: BeeLineIcon('ChevronRight',
                            size: 16, color: Theme.of(context).hintColor))))
          ])));
}
