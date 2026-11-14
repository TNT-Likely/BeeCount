import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// No amounts, rate lookups or write actions enter this component. The host
/// provides localized query currency, missing-record and quote-date labels.
class BeeDetailCurrencyNotice extends StatelessWidget {
  const BeeDetailCurrencyNotice(
      {super.key,
      required this.scopeLabel,
      this.missingLabel,
      this.rateDateLabel,
      this.stale = false});
  final String scopeLabel;
  final String? missingLabel, rateDateLabel;
  final bool stale;
  @override
  Widget build(BuildContext context) {
    final warning = missingLabel != null || stale;
    return Semantics(
        liveRegion: true,
        child: BeeSurface(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              BeeLineIcon(warning ? 'TriangleAlert' : 'Info',
                  size: 18,
                  color: warning
                      ? const Color(0xffbc802e)
                      : Theme.of(context).hintColor),
              const SizedBox(width: 9),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(scopeLabel,
                        style: TextStyle(
                            fontSize: 11,
                            height: 1.5,
                            color: Theme.of(context).hintColor)),
                    if (missingLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(missingLabel!,
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: Color(0xffbc802e)))
                    ],
                    if (rateDateLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(rateDateLabel!,
                          style: TextStyle(
                              fontSize: 11,
                              height: 1.5,
                              color: stale
                                  ? const Color(0xffbc802e)
                                  : Theme.of(context).hintColor))
                    ],
                  ])),
            ])));
  }
}
