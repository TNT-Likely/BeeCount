import 'package:beecount/cloud/sync_diff_service.dart';
import 'package:beecount/data/db.dart' as db;
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/cloud/sync_preview_dialog.dart';
import 'package:beecount/services/data_import_service.dart';
import 'package:beecount/widgets/ui/dialog.dart';
import 'package:beecount_business_ui/auto_billing.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _PopOrder extends NavigatorObserver {
  final events = <String>[];

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    events.add('pop');
    super.didPop(route, previousRoute);
  }
}

Future<BuildContext> host(WidgetTester t,
    {double width = 406,
    double height = 800,
    double scale = 1,
    Brightness brightness = Brightness.light,
    Locale locale = const Locale('zh'),
    NavigatorObserver? observer,
    Widget? child,
    bool galleryTheme = false,
    bool settle = true}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, height);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  late BuildContext context;
  final theme = beeTheme(brightness: brightness);
  await t.pumpWidget(MaterialApp(
    theme: galleryTheme ? theme : applyBeeCardTheme(theme),
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('zh'), Locale('en')],
    navigatorObservers: observer == null ? [] : [observer],
    builder: (context, child) => MediaQuery(
      data:
          MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Builder(builder: (ctx) {
      context = ctx;
      return Scaffold(
          body: child == null
              ? const SizedBox.expand()
              : Padding(padding: const EdgeInsets.all(17), child: child));
    }),
  ));
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump(const Duration(milliseconds: 300));
  }
  return context;
}

db.Transaction local(int id, String note) => db.Transaction(
    id: id,
    ledgerId: 1,
    type: 'expense',
    amount: id.toDouble(),
    happenedAt: DateTime(2026, 10, 20),
    note: note,
    excludeFromStats: false,
    excludeFromBudget: false);

List<SyncChange> changes({int perGroup = 1}) => [
      for (var i = 0; i < perGroup; i++)
        SyncChange(
            type: SyncChangeType.added,
            cloudTransaction: ImportTransaction(
                type: 'expense',
                amount: i + .25,
                happenedAt: DateTime(2026, 10, 20),
                note: 'QA added-$i')),
      for (var i = 0; i < perGroup; i++)
        SyncChange(
            type: SyncChangeType.modified,
            cloudTransaction: ImportTransaction(
                type: 'income',
                amount: i + .5,
                happenedAt: DateTime(2026, 10, 20),
                note: 'QA modified-$i'),
            localTransaction: local(i + 1, 'QA previous-$i'),
            diffDetails: ['QA difference-$i']),
      for (var i = 0; i < perGroup; i++)
        SyncChange(
            type: SyncChangeType.deleted,
            localTransaction: local(i + 20, 'QA deleted-$i')),
    ];

void main() {
  for (final confirm in [false, true]) {
    testWidgets('AppDialog preserves $confirm result and pop-before-callback',
        (t) async {
      final observer = _PopOrder();
      final context = await host(t, observer: observer);
      final l = AppLocalizations.of(context);
      final future = AppDialog.confirm<bool>(context,
          title: 'QA confirm',
          message: 'first\\nsecond',
          onCancel: () => observer.events.add('cancel'),
          onOk: () => observer.events.add('confirm'));
      await t.pumpAndSettle();
      expect(find.byType(BeeDialog), findsOneWidget);
      expect(find.byType(CloseButton), findsNothing);
      expect(find.text('first\nsecond'), findsOneWidget);
      await t.tap(find.text(confirm ? l.commonConfirm : l.commonCancel));
      await t.pumpAndSettle();
      expect(await future, confirm);
      expect(observer.events, ['pop', confirm ? 'confirm' : 'cancel']);
    });
  }

  testWidgets(
      'AppDialog original info/error/warning results and barrier cancel',
      (t) async {
    final context = await host(t);
    final l = AppLocalizations.of(context);
    var callbacks = 0;
    for (final show in [
      AppDialog.info<bool>,
      AppDialog.error<bool>,
      AppDialog.warning<bool>
    ]) {
      final result = show(context,
          title: 'QA message', message: 'unchanged', onOk: () => callbacks++);
      await t.pumpAndSettle();
      await t.tap(find.text(l.commonOk));
      await t.pumpAndSettle();
      expect(await result, isTrue);
    }
    expect(callbacks, 3);
    final cancelled = AppDialog.confirm<bool>(context,
        title: 'QA outside',
        message: 'barrier contract',
        onCancel: () => callbacks++);
    await t.pumpAndSettle();
    await t.tapAt(const Offset(3, 3));
    await t.pumpAndSettle();
    expect(await cancelled, isNull);
    expect(callbacks, 3, reason: 'Barrier dismissal never calls onCancel');
  });

  for (final profile in [
    (320.0, Brightness.light, const Locale('en'), 1.4),
    (320.0, Brightness.dark, const Locale('zh'), 1.4),
    (406.0, Brightness.light, const Locale('zh'), 1.0),
    (406.0, Brightness.dark, const Locale('en'), 1.4),
  ]) {
    testWidgets('long AppDialog scroll and equal actions $profile', (t) async {
      final context = await host(t,
          width: profile.$1,
          height: 568,
          brightness: profile.$2,
          locale: profile.$3,
          scale: profile.$4);
      final l = AppLocalizations.of(context);
      final message = List.generate(80, (i) => 'QA long line $i').join('\n');
      final result = AppDialog.confirm<bool>(context,
          title: 'QA bounded dialog', message: message);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final buttons = find.byType(BeeButton);
      expect(buttons, findsNWidgets(2));
      expect(t.getSize(buttons.first).width,
          closeTo(t.getSize(buttons.last).width, .01));
      expect(t.getSize(buttons.first).height, greaterThanOrEqualTo(44));
      expect(t.getRect(buttons.last).bottom, lessThanOrEqualTo(568));
      final scroll = t.state<ScrollableState>(find.descendant(
          of: find.byType(BeeDialog), matching: find.byType(Scrollable)));
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await t.pump();
      expect(t.widget<Text>(find.text(message)).maxLines, isNull);
      await t.tap(find.text(l.commonCancel));
      await t.pumpAndSettle();
      expect(await result, isFalse);
    });
  }

  testWidgets(
      'diff dialog preserves null cancel, zero guard and selected identity',
      (t) async {
    final context = await host(t);
    final l = AppLocalizations.of(context);
    final items = changes();
    final cancelled = showSyncPreviewDialog(context,
        preview: SyncPreview(changes: items),
        primaryColor: Theme.of(context).colorScheme.primary);
    await t.pumpAndSettle();
    expect(find.text(l.syncPreviewAdded), findsOneWidget);
    expect(find.text(l.syncPreviewModified), findsOneWidget);
    expect(find.text(l.syncPreviewDeleted), findsOneWidget);
    await t.tap(find.text(l.commonCancel));
    await t.pumpAndSettle();
    expect(await cancelled, isNull);
    expect(items.every((c) => c.selected), isTrue);

    final applied = showSyncPreviewDialog(context,
        preview: SyncPreview(changes: items),
        primaryColor: Theme.of(context).colorScheme.primary);
    await t.pumpAndSettle();
    await t.tap(find.byType(Checkbox).first);
    await t.pumpAndSettle();
    expect(items.every((c) => !c.selected), isTrue);
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, l.syncPreviewApply(0)))
            .onPressed,
        isNull);
    await t.tap(find.byType(Checkbox).at(1));
    await t.pumpAndSettle();
    await t.tap(find.text(l.syncPreviewApply(1)));
    await t.pumpAndSettle();
    final selected = await applied;
    expect(selected, hasLength(1));
    expect(identical(selected!.single, items.first), isTrue);
    expect(selected.single.cloudTransaction!.note, 'QA added-0');
    expect(t.takeException(), isNull);
  });

  testWidgets('long diff keeps bounded scrolling and actions on 320/140%',
      (t) async {
    final errors = <FlutterErrorDetails>[];
    final previousError = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details);
      previousError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousError);
    final context = await host(t,
        width: 320,
        height: 568,
        scale: 1.4,
        brightness: Brightness.dark,
        locale: const Locale('en'));
    final l = AppLocalizations.of(context);
    final result = showSyncPreviewDialog(context,
        preview: SyncPreview(changes: changes(perGroup: 10)),
        primaryColor: Theme.of(context).colorScheme.primary);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull,
        reason: errors.map((e) => e.toString()).join('\n'));
    final list = find.descendant(
        of: find.byType(BeeDialog), matching: find.byType(ListView));
    final scroll = t.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)));
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    await t.scrollUntilVisible(find.textContaining('QA deleted-9'), 300,
        scrollable:
            find.descendant(of: list, matching: find.byType(Scrollable)),
        maxScrolls: 30);
    expect(find.textContaining('QA deleted-9'), findsOneWidget);
    final cancel = find.widgetWithText(TextButton, l.commonCancel);
    expect(t.getRect(cancel).bottom, lessThanOrEqualTo(568));
    await t.tap(cancel);
    await t.pumpAndSettle();
    expect(await result, isNull);
    expect(t.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
        'Auto action portable theme keeps key/busy/callback $brightness',
        (t) async {
      var calls = 0;
      Widget card(bool busy) => BeeAutoBillingActionCard(
          title: 'QA action',
          description: 'Existing platform callback remains in the host.',
          actionLabel: 'QA open',
          actionKey: const ValueKey('qa-action'),
          busy: busy,
          onAction: () => calls++);
      await host(t,
          width: 320,
          scale: 1.4,
          brightness: brightness,
          galleryTheme: true,
          child: card(false));
      final action = find.byKey(const ValueKey('qa-action'));
      expect(t.widget(action), isA<BeeButton>());
      final filled = t.widget<FilledButton>(
          find.descendant(of: action, matching: find.byType(FilledButton)));
      final shape = filled.style!.shape!.resolve({}) as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(15));
      expect(t.getSize(action).height, greaterThanOrEqualTo(44));
      await t.tap(action);
      expect(calls, 1);
      await host(t,
          width: 320,
          scale: 1.4,
          brightness: brightness,
          galleryTheme: true,
          settle: false,
          child: card(true));
      expect(t.widget<BeeButton>(action).loading, isTrue);
      expect(
          t
              .widget<FilledButton>(find.descendant(
                  of: action, matching: find.byType(FilledButton)))
              .onPressed,
          isNull);
      await t.tap(action);
      expect(calls, 1);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    });
  }
}
