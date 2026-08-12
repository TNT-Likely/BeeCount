/// issue #429 —— 日历页年月快捷跳转 + firstDay 硬编码修复
/// 设计: .docs/issue-429-calendar-month-jump.md
///
///   - 头部标题「20xx年xx月 ▾」可点,弹出复用的年月滚轮(WheelDatePickerMode.ym),
///     不再只能靠左右箭头一个月一个月翻
///   - 可浏览下界从硬编码 2020-01-01 放宽到 2000-01-01;选择器 min/max 与
///     TableCalendar 的 firstDay/lastDay 绑同一份 —— 否则跳到下界之前会踩
///     table_calendar_base.dart:77 的 assert
///   - 跳月语义与滑动切月(_onPageChanged)一致:清空选中日 → 下方当日交易列表收起
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/calendar/calendar_page.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/widgets/ui/wheel_date_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
  });

  tearDown(() async => db.close());

  Ledger cnyLedger() => Ledger(
        id: 1,
        name: 'L',
        currency: 'CNY',
        type: 'personal',
        createdAt: DateTime(2026, 1, 1),
        myRole: 'owner',
        memberCount: 1,
        isShared: false,
        monthStartDay: 1,
      );

  /// 默认 800x600 测试视口装不下「日历卡(约 520)+ 当日交易列表」,
  /// ListView 懒构建会让下半屏的列表压根不 build。撑高到手机比例,
  /// 让「跳月后列表收起」这条断言测的是状态而不是滚动位置。
  void useTallPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget host() {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerProvider
            .overrideWith((ref) => Stream<Ledger?>.value(cnyLedger())),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const CalendarPage(),
      ),
    );
  }

  /// 头部标题文案格式必须与 table_calendar 内置实现一致
  /// (calendar_header.dart:42 用的就是 DateFormat.yMMMM(locale))
  String monthTitle(DateTime month) => DateFormat.yMMMM('zh').format(month);

  DateTime thisMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  /// TableCalendar 构造时会对 firstDay/lastDay 跑 normalizeDate() 转成 UTC,
  /// 而传进选择器的是本地时间 —— 边界是否「同一份」看的是同一个日历日,
  /// 不是 DateTime 实例相等。
  Matcher sameCalendarDay(DateTime expected) => predicate<DateTime?>(
        (v) =>
            v != null &&
            v.year == expected.year &&
            v.month == expected.month &&
            v.day == expected.day,
        '与 ${expected.year}-${expected.month}-${expected.day} 同一日历日',
      );

  TableCalendar calendarOf(WidgetTester tester) {
    // TableCalendar 是泛型,页面里没显式给类型实参,用谓词匹配避开 byType 对
    // runtimeType 的精确比较
    final finder = find.byWidgetPredicate((w) => w is TableCalendar);
    return tester.widgetList(finder).single as TableCalendar;
  }

  testWidgets('点头部月份标题 → 弹出年月滚轮选择器', (tester) async {
    useTallPhoneViewport(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text(monthTitle(thisMonth())), findsOneWidget);

    await tester.tap(find.text(monthTitle(thisMonth())));
    await tester.pumpAndSettle();

    expect(find.byType(WheelDatePicker), findsOneWidget);
    final picker = tester.widget<WheelDatePicker>(find.byType(WheelDatePicker));
    expect(picker.mode, WheelDatePickerMode.ym);
  });

  testWidgets('日历下界放宽到 2000-01-01,选择器 min/max 与日历边界同一份', (tester) async {
    useTallPhoneViewport(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final cal = calendarOf(tester);
    expect(cal.firstDay, sameCalendarDay(DateTime(2000, 1, 1)));

    await tester.tap(find.text(monthTitle(thisMonth())));
    await tester.pumpAndSettle();

    final picker = tester.widget<WheelDatePicker>(find.byType(WheelDatePicker));
    // 绑同一份边界:选择器能选到的 == 日历能显示的,结构上不可能越界触发 assert
    expect(picker.minDate, sameCalendarDay(cal.firstDay));
    expect(picker.maxDate, sameCalendarDay(cal.lastDay));
  });

  testWidgets('滚轮选到 2000-01 → 日历跳过去,并清空选中日收起当日列表', (tester) async {
    useTallPhoneViewport(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // initState 默认选中今天 → 下方当日交易列表(含「在该日记账」按钮)可见
    expect(find.text('在该日记账'), findsOneWidget);

    await tester.tap(find.text(monthTitle(thisMonth())));
    await tester.pumpAndSettle();

    // 年、月两个滚轮各向下猛拖:越界被 FixedExtentScrollPhysics 钳到首项,
    // 确定性地落在 年=2000(下界) / 月=1
    final wheels = find.byType(CupertinoPicker);
    await tester.drag(wheels.at(0), const Offset(0, 6000));
    await tester.pumpAndSettle();
    await tester.drag(wheels.at(1), const Offset(0, 6000));
    await tester.pumpAndSettle();

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    // 改造前 firstDay 硬编码 2020-01-01,跳到 2000-01 会直接踩 assert
    expect(find.text(monthTitle(DateTime(2000, 1, 1))), findsOneWidget);
    // 与滑动切月一致:选中日清空 → 当日列表整块收起
    expect(find.text('在该日记账'), findsNothing);
  });
}
