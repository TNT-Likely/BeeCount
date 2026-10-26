import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../../providers/budget_providers.dart';
import '../../../utils/month_range.dart';

/// Retains the original reminder windows and preference keys across V4.
class HomeReminderPolicy {
  HomeReminderPolicy(this.now, this.preferences);
  final DateTime now;
  final SharedPreferences preferences;
  static const monthlyKey = 'last_month_reminder_dismissed';
  static const annualKey = 'annual_report_reminder_dismissed';
  static const budgetKey = 'budget_setup_hint_dismissed';
  String get monthKey => '${now.year}-${now.month}';
  int get reportYear => now.month == 1 ? now.year - 1 : now.year;
  bool get monthly =>
      now.day <= 7 && preferences.getString(monthlyKey) != monthKey;
  bool get annual =>
      ((now.month == 12 && now.day >= 15) || now.month == 1) &&
      preferences.getInt(annualKey) != reportYear;
  bool get budget => !(preferences.getBool(budgetKey) ?? false);
  Future<void> dismissMonthly() => preferences.setString(monthlyKey, monthKey);
  Future<void> dismissAnnual() => preferences.setInt(annualKey, reportYear);
  Future<void> dismissBudget() => preferences.setBool(budgetKey, true);
}

/// Preferences, budget visibility and month boundaries belong to the App.
/// The reusable UI only renders the status, actions and dismiss control.
class HomeReminders extends ConsumerStatefulWidget {
  const HomeReminders(
      {super.key,
      required this.onMonthly,
      required this.onAnnual,
      required this.onBudget,
      this.now});
  final ValueChanged<DateTime> onMonthly;
  final ValueChanged<int> onAnnual;
  final VoidCallback onBudget;
  final DateTime? now;
  @override
  ConsumerState<HomeReminders> createState() => _HomeRemindersState();
}

class _HomeRemindersState extends ConsumerState<HomeReminders> {
  HomeReminderPolicy? policy;
  bool monthly = false, annual = false, budget = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    final loaded =
        HomeReminderPolicy(widget.now ?? DateTime.now(), preferences);
    setState(() {
      policy = loaded;
      monthly = loaded.monthly;
      annual = loaded.annual;
      budget = loaded.budget;
    });
  }

  Future<void> _dismiss(
      Future<void> Function() persist, VoidCallback hide) async {
    await persist();
    if (mounted) setState(hide);
  }

  @override
  Widget build(BuildContext context) {
    final current = policy;
    if (current == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final overview = ref.watch(budgetOverviewProvider);
    final showBudget = budget &&
        overview.hasValue &&
        !overview.hasError &&
        overview.valueOrNull?.totalBudget == null;
    final label =
        labelForDate(current.now, ref.watch(currentMonthStartDayProvider));
    final lastMonth = DateTime(label.year, label.month - 1);
    final cards = <Widget>[
      if (monthly)
        _notice(context,
            icon: 'Sparkles',
            label:
                '${DateFormat.MMMM(l10n.localeName).format(lastMonth)} ${l10n.homeLastMonthReportSubtitle}',
            action: l10n.homeLastMonthReportView,
            onOpen: () {
              widget.onMonthly(lastMonth);
              setState(() => monthly = false);
            },
            onDismiss: () =>
                _dismiss(current.dismissMonthly, () => monthly = false)),
      if (annual)
        _notice(context,
            icon: 'ChartNoAxesCombined',
            label: l10n.homeAnnualReportReminder(current.reportYear),
            action: l10n.homeAnnualReportView,
            onOpen: () {
              widget.onAnnual(current.reportYear);
              setState(() => annual = false);
            },
            onDismiss: () =>
                _dismiss(current.dismissAnnual, () => annual = false)),
      if (showBudget)
        _notice(context,
            icon: 'ChartPie',
            label: l10n.budgetSetupHint,
            action: l10n.budgetSetupAction,
            onOpen: widget.onBudget,
            onDismiss: () =>
                _dismiss(current.dismissBudget, () => budget = false)),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(mainAxisSize: MainAxisSize.min, children: cards);
  }

  Widget _notice(BuildContext context,
          {required String icon,
          required String label,
          required String action,
          required VoidCallback onOpen,
          required VoidCallback onDismiss}) =>
      Padding(
          padding: const EdgeInsets.fromLTRB(17, 0, 17, 8),
          child: BeeSurface(
              padding: const EdgeInsets.fromLTRB(12, 4, 2, 4),
              child: BeeStatus(
                  label: label,
                  icon: BeeLineIcon(icon,
                      size: 20, color: Theme.of(context).hintColor),
                  action: TextButton(
                      onPressed: onOpen,
                      child:
                          Text(action, style: const TextStyle(fontSize: 12))),
                  onDismiss: onDismiss)));
}
