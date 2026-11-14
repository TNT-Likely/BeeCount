import 'package:flutter/material.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
import 'share/bindings/share_card_controls.dart';

/// Optional standalone route; production share entry points remain dialogs.
class ShareCardPage extends StatelessWidget {
  const ShareCardPage(
      {super.key, this.year, this.month, this.ledgerId, this.type});
  final int? year, month, ledgerId;
  final String? type;
  @override
  Widget build(BuildContext context) => V4PageScaffold(
          body: SafeArea(
        child: ShareCardControls(
            year: year, month: month, ledgerId: ledgerId, type: type),
      ));
}
