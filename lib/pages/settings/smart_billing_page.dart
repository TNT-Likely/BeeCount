import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/v4/bindings/page_scaffold.dart';
import '../../presentation/v4/bindings/smart_billing_entries.dart';
import '../../presentation/v4/bindings/smart_billing_preferences.dart';

class SmartBillingPage extends ConsumerWidget {
  const SmartBillingPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.smartBillingPageTitle, leading: const BackButton()),
      Expanded(
          child: BeePageBody(eager: true, children: [
        Text(l.smartBillingPageSubtitle,
            style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
        const SmartBillingEntries(),
        const SmartBillingPreferences(),
        const SmartBillingVoicePreferences()
      ]))
    ]));
  }
}
