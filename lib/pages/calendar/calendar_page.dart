import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/v4/bindings/calendar_month_view.dart';
import '../../presentation/v4/bindings/calendar_transactions.dart';
import '../../presentation/v4/bindings/page_scaffold.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';
import '../../providers/calendar_providers.dart';
import '../../widgets/ui/wheel_date_picker.dart';
import '../transaction/transaction_editor_page.dart';
part '../../presentation/v4/bindings/calendar_actions.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});
  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage>
    with _CalendarActions {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        ledgerId = ref.watch(currentLedgerIdProvider),
        key = (
          ledgerId: ref.watch(currentLedgerIdProvider),
          month: _focusedMonth
        ),
        totals = ref.watch(dailyTotalsByMonthProvider(
            (ledgerId: ledgerId, month: _focusedMonth)));
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.calendarTitle,
          leading: const BackButton(),
          actions: [
            TextButton(onPressed: _jumpToToday, child: Text(l.calendarToday))
          ]),
      Expanded(
          child: BeePageBody(eager: true, children: [
        totals.when(
            skipLoadingOnReload: true,
            loading: () => const BeeSurface(
                child: SizedBox(
                    height: 458,
                    child: Center(child: CircularProgressIndicator()))),
            error: (error, _) => BeeEmptyState(
                title: 'Error: $error',
                action: BeeButton(
                    label: l.v4RecordingRetry,
                    onPressed: () =>
                        ref.invalidate(dailyTotalsByMonthProvider(key)))),
            data: (values) => CalendarMonthView(
                incomeColor: BeeTokens.incomeColor(context, ref),
                expenseColor: BeeTokens.expenseColor(context, ref),
                focusedMonth: _focusedMonth,
                firstDay: _CalendarActions._calFirstDay,
                lastDay: _calLastDay,
                selectedDay: _selectedDay,
                totals: values,
                onSelect: _onDaySelected,
                onPage: _onPageChanged,
                onMonth: _showMonthJumpPicker,
                onJump: _jumpToMonth)),
        if (_selectedDay != null)
          CalendarTransactions(
              ledgerId: ledgerId,
              date: _selectedDay!,
              onAdd: _addTransactionForSelectedDate)
      ]))
    ]));
  }
}
