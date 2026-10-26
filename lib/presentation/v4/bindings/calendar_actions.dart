part of '../../../pages/calendar/calendar_page.dart';

mixin _CalendarActions on ConsumerState<CalendarPage> {
  late DateTime _focusedMonth;
  DateTime? _selectedDay;

  // 日历可浏览范围。下界与 WheelDatePicker 默认 minDate 对齐(2000-01-01),
  // 导入了 2020 年前账单的用户也能翻到(#429:此前硬编码 2020-01-01);
  // 上界沿用「今天 + 1 年」以覆盖未来记账/周期记账。
  //
  // TableCalendar 与年月选择器必须绑同一份边界 —— focusedDay 落到界外会踩
  // table_calendar 内部 assert(table_calendar_base.dart:77)。
  static final DateTime _calFirstDay = DateTime(2000, 1, 1);

  // 取整到「日」:同一天内多次读取结果恒等,避免 TableCalendar 与选择器
  // 各自 DateTime.now() 差出微秒级不一致。
  DateTime get _calLastDay {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 365));
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = now;

    // 同步到 Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(calendarSelectedMonthProvider.notifier).state = _focusedMonth;
      ref.read(calendarSelectedDateProvider.notifier).state = _selectedDay;
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
    });
    ref.read(calendarSelectedDateProvider.notifier).state = selectedDay;
  }

  void _onPageChanged(DateTime focusedMonth) {
    setState(() {
      _focusedMonth = focusedMonth;
      // 切换月份时，清空选中日期
      _selectedDay = null;
    });
    ref.read(calendarSelectedMonthProvider.notifier).state = focusedMonth;
    ref.read(calendarSelectedDateProvider.notifier).state = null;
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(now.year, now.month, 1);
      _selectedDay = now;
    });
    ref.read(calendarSelectedMonthProvider.notifier).state = _focusedMonth;
    ref.read(calendarSelectedDateProvider.notifier).state = _selectedDay;
  }

  // 点头部「20xx年xx月 ▾」跳转指定年月(#429)。复用全 App 通用的年月滚轮,
  // 与首页(home_page.dart)、统计页(analytics_page.dart)同一范式。
  Future<void> _showMonthJumpPicker() async {
    // 上界故意跟随日历的 _calLastDay 而非 DateTime.now():日历本身能横滑到
    // 未来一年,若选择器卡在今天就会出现「手能滑到、选择器跳不到」的割裂。
    final picked = await showWheelDatePicker(
      context,
      initial: _focusedMonth,
      mode: WheelDatePickerMode.ym,
      minDate: _calFirstDay,
      maxDate: _calLastDay,
    );
    if (picked == null || !mounted) return;
    _jumpToMonth(picked);
  }

  void _jumpToMonth(DateTime target) {
    // 选择器已按 min/max 限制返回值,这里只是兜底,防止将来改动边界后越界崩溃。
    // 钳制同样落到月初 —— _focusedMonth 恒为月初是本页各处共同的前置假设。
    var month = DateTime(target.year, target.month, 1);
    if (month.isBefore(_calFirstDay)) {
      month = DateTime(_calFirstDay.year, _calFirstDay.month, 1);
    }
    final lastDay = _calLastDay;
    if (month.isAfter(lastDay)) {
      month = DateTime(lastDay.year, lastDay.month, 1);
    }

    setState(() {
      _focusedMonth = month;
      // 与滑动切月(_onPageChanged)保持同一语义:清空选中日,下方当日列表收起
      _selectedDay = null;
    });
    // 程序化跳转时 table_calendar 会置 _pageCallbackDisabled(table_calendar_
    // base.dart:165),onPageChanged 不会回调,两个 provider 必须手动同步
    ref.read(calendarSelectedMonthProvider.notifier).state = month;
    ref.read(calendarSelectedDateProvider.notifier).state = null;
  }

  Future<void> _addTransactionForSelectedDate() async {
    // 优先使用当前选中日期，未选中时回退到今天。
    // 把时间锁到中午,避开 UTC 边界导致跨日的问题(交易列表按日期分组,
    // 凌晨 00:00 在某些时区可能被算作前一天)。
    final base = _selectedDay ?? DateTime.now();
    final initialDate = DateTime(base.year, base.month, base.day, 12, 0, 0);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionEditorPage(
          initialKind: 'expense',
          quickAdd: true,
          initialDate: initialDate,
        ),
      ),
    );

    // 编辑器关闭后,主动刷新日历的统计与当日交易列表
    // (FutureProvider 不会因 Drift 写入自动重算)
    if (mounted) {
      ref.read(calendarRefreshProvider.notifier).state++;
    }
  }
}
