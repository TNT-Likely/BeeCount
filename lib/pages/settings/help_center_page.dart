import 'package:flutter/material.dart';
import 'support/bindings/support_document_controls.dart';

/// Existing review fallback; mine_page still selects browser versus embedded.
const bool kHelpCenterInApp = true;

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key, this.initialUrl, this.title});
  final String? initialUrl, title;
  @override
  Widget build(BuildContext context) =>
      SupportDocumentControls(initialUrl: initialUrl, title: title);
}
