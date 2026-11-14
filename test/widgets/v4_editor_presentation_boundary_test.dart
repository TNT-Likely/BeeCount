import 'dart:typed_data';

import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(WidgetTester tester, Widget child,
      {Size size = const Size(398, 844),
      double scale = 1,
      Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: MediaQuery(
            data: MediaQueryData(
                size: size, textScaler: TextScaler.linear(scale)),
            child: Scaffold(body: child))));
    await tester.pump();
  }

  testWidgets('横向账户受控选择、不重排、历史隐藏标识、空态与加载占位', (tester) async {
    String? selected = 'second';
    final selections = <String?>[];
    await open(
        tester,
        StatefulBuilder(
            builder: (context, update) => BeeAccountStrip(
                    items: const [
                      BeeAccountStripItem(id: 'second', label: '先前选中'),
                      BeeAccountStripItem(id: 'first', label: '现金'),
                      BeeAccountStripItem(
                          id: 'hidden', label: '历史钱包', hidden: true)
                    ],
                    selected: selected,
                    unsetLabel: '无账户',
                    emptyLabel: '暂无账户',
                    hiddenLabel: '已隐藏',
                    onSelected: (id) => update(() {
                          selected = id;
                          selections.add(id);
                        }))),
        size: const Size(480, 568));
    final initial = tester.getTopLeft(find.text('先前选中'));
    await tester.tap(find.text('现金'));
    await tester.pump();
    expect(selected, 'first');
    expect(tester.getTopLeft(find.text('先前选中')), initial);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    await tester.tap(find.text('无账户'));
    expect(selections, ['first', null]);
    expect(tester.getSize(find.byType(BeeAccountStrip)).height, 32);
    await open(
        tester,
        BeeAccountStrip(
            items: const [],
            selected: null,
            loading: true,
            unsetLabel: '无账户',
            emptyLabel: '暂无账户',
            hiddenLabel: '已隐藏',
            onSelected: (_) {}));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.getSize(find.byType(BeeAccountStrip)).height, 32);
    await open(
        tester,
        BeeAccountStrip(
            items: const [],
            selected: null,
            allowUnset: false,
            unsetLabel: '无账户',
            emptyLabel: '暂无账户',
            hiddenLabel: '已隐藏',
            onSelected: (_) {}));
    expect(find.text('暂无账户'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('作者头像保留角色提示，图片损坏仍展示字形', (tester) async {
    await open(
        tester,
        RecordingAuthors(authors: [
          RecordingAuthor(
              name: '小满',
              tooltip: '小满 创建',
              image: MemoryImage(Uint8List.fromList([1, 2, 3]))),
          const RecordingAuthor(name: '林', tooltip: '林 最后编辑')
        ]));
    await tester.pumpAndSettle();
    expect(find.text('小'), findsOneWidget);
    expect(find.text('林'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNWidgets(2));
    await tester.longPress(find.text('林'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('林 最后编辑'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(398, 844)]) {
    testWidgets('固定区域不随分类滚动，内联输入与元信息可操作 ${size.width}', (tester) async {
      final note = TextEditingController(text: '午餐');
      final focus = FocusNode();
      addTearDown(note.dispose);
      addTearDown(focus.dispose);
      var dateTaps = 0, saved = 0;
      await open(
          tester,
          RecordingFrame(
              compact: true,
              narrow: size.width == 320,
              amount: RecordingAmountCard(
                  compact: true,
                  currency:
                      RecordingCurrencyControl(currency: 'USD', onTap: () {}),
                  ledger:
                      RecordingLedgerControl(name: '很长的测试账本名称', onTap: () {}),
                  amount: '12.00',
                  symbol: 'US\$',
                  hint: '',
                  conversion: RecordingConversionSummary(
                      label: '折合 CNY', value: '≈ ¥85.20', onTap: () {})),
              category: Column(
                  children: List.generate(
                      30, (i) => SizedBox(height: 44, child: Text('分类 $i')))),
              details: RecordingDetailsCard(
                  note: RecordingNoteField(
                      fieldKey: const ValueKey('note-input'),
                      controller: note,
                      focusNode: focus,
                      hint: '备注',
                      onHistory: () {},
                      historyLabel: '历史备注'),
                  account: RecordingAccountControl(label: '美元钱包', onTap: () {}),
                  date: RecordingMetaControl(
                      label: '10.26', onTap: () => dateTaps++),
                  tags: const RecordingTagSummary(first: Text('工作日'), count: 3),
                  attachment: RecordingAttachmentControl(
                      label: '附件', count: 1, onTap: () {})),
              keypad: RecordingKeypad(
                  compact: true,
                  onDigit: (_) {},
                  onOperator: (_) {},
                  onBackspace: () {},
                  onClear: () {},
                  deleteLabel: '退格'),
              actions: RecordingActions(
                  saveLabel: '保存', onEquals: () {}, onSave: () => saved++)),
          size: size,
          scale: 1.4,
          brightness: Brightness.dark);
      final before =
          tester.getRect(find.byKey(const ValueKey('recording-save')));
      await tester.drag(find.byKey(const ValueKey('recording-content')),
          const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(
          tester.getRect(find.byKey(const ValueKey('recording-save'))), before);
      expect(before.bottom, size.height - 12);
      await tester.enterText(
          find.byKey(const ValueKey('note-input')), '直接修改备注');
      expect(note.text, '直接修改备注');
      await tester.tap(find.text('10.26'));
      await tester.tap(find.byKey(const ValueKey('recording-save')));
      expect(dateTaps, 1);
      expect(saved, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('原金额键盘的双击和长按只回调切换运算，不代管计算或提交', (tester) async {
    final operators = <String>[];
    var toggles = 0, finishes = 0;
    await open(
        tester,
        RecordingLegacyKeypad(
            onDigit: (_) {},
            onBackspace: () {},
            onOperator: operators.add,
            onToggleFirst: () => toggles++,
            onToggleSecond: () {},
            onDate: () {},
            dateLabel: '2026/10/26',
            timeLabel: '12:30:00',
            onFinish: () => finishes++,
            finishLabel: '完成',
            doubleTapLabel: '双击继续'),
        size: const Size(320, 568));
    await tester.longPress(find.text('+/×'));
    await tester.pumpAndSettle();
    expect(operators, ['×']);
    expect(toggles, 1);
    expect(finishes, 0);
    await tester.tap(find.text('完成'));
    expect(finishes, 1);
    expect(tester.takeException(), isNull);
  });
}
