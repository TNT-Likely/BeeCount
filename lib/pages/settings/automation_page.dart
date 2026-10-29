import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
import '../transaction/recurring_transaction_page.dart';
import 'reminder_settings_page.dart';

/// Entry only: recurring rules and OS reminder settings stay in their original
/// pages, with the same Navigator stack and current Provider scope.
class AutomationPage extends StatelessWidget {
  const AutomationPage({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    void open(Widget page) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(title: l.automationPageTitle, leading: const BackButton()),
      Expanded(
          child: ListView(padding: const EdgeInsets.all(17), children: [
        Text(l.automationPageSubtitle,
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        const SizedBox(height: 12),
        BeeSurface(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              BeeMenuRow(
                  title: l.mineRecurringTransactions,
                  subtitle: l.mineRecurringTransactionsSubtitle,
                  leading: const BeeLineIcon('Repeat2'),
                  onTap: () => open(const RecurringTransactionPage())),
              const BeeDivider(),
              BeeMenuRow(
                  title: l.mineReminderSettings,
                  subtitle: l.mineReminderSettingsSubtitle,
                  leading: const BeeLineIcon('Bell'),
                  onTap: () => open(const ReminderSettingsPage())),
            ])),
      ])),
    ]));
  }
}
