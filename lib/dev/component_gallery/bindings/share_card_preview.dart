import 'package:flutter/material.dart';
import '../../../pages/report/share/bindings/share_card_controls.dart';

/// Production month data and original artwork, with native exports disabled.
class ShareCardPreview extends StatelessWidget {
  const ShareCardPreview({super.key});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SizedBox(
        height: 680,
        child: ShareCardControls(
          year: now.year,
          month: now.month,
          previewOnly: true,
        ));
  }
}
