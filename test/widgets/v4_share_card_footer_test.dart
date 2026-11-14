import 'package:beecount_business_ui/share_card.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _save = ValueKey('share-card-save');
const _share = ValueKey('share-card-share');

BeeShareCard _card({
  required VoidCallback? onSave,
  required ValueChanged<Rect>? onShare,
  bool busy = false,
  bool sharing = false,
  bool generating = false,
  bool english = false,
}) =>
    BeeShareCard(
        title: '分享卡片',
        closeLabel: '关闭',
        saveLabel: english ? 'Save to gallery' : '保存到相册',
        shareLabel: english ? 'Share' : '分享',
        generatingLabel: '生成中',
        retryLabel: '重试',
        preview: const SizedBox(width: 120, height: 200),
        templates: const [],
        selected: '',
        onSave: onSave,
        onShare: onShare,
        busy: busy,
        sharing: sharing,
        generating: generating);

Finder _filled(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(FilledButton));

void main() {
  for (final dark in [false, true]) {
    for (final narrow in [false, true]) {
      testWidgets('分享footer规范色/矩形圆角/堆叠与真实Rect $dark/$narrow', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(narrow ? 320 : 406, 568);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final theme = beeTheme(
            brightness: dark ? Brightness.dark : Brightness.light,
            accent: narrow ? const Color(0xff219c9c) : const Color(0xfffacb16));
        var saves = 0;
        Rect? anchor;
        await tester.pumpWidget(MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(narrow ? 1.4 : 1)),
                child: child!),
            home: Scaffold(
                body: Padding(
                    padding: const EdgeInsets.fromLTRB(13, 25, 13, 7),
                    child: _card(
                        english: narrow,
                        onSave: () => saves++,
                        onShare: (value) => anchor = value)))));
        await tester.pumpAndSettle();
        expect(tester.widget<BeeButton>(find.byKey(_save)).kind,
            BeeButtonKind.secondary);
        expect(tester.widget<BeeButton>(find.byKey(_share)).kind,
            BeeButtonKind.primary);
        expect(find.byType(OutlinedButton), findsNothing);
        for (final key in [_save, _share]) {
          final button = tester.widget<FilledButton>(_filled(key));
          final style = button.style!;
          expect(
              style.backgroundColor!.resolve({}),
              key == _save
                  ? BeeCardTheme.of(tester.element(_filled(key))).soft
                  : theme.colorScheme.primary);
          expect(
              style.foregroundColor!.resolve({}),
              key == _save
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onPrimary);
          final shape = style.shape!.resolve({})! as RoundedRectangleBorder;
          expect(shape.borderRadius, BorderRadius.circular(15));
          expect(
              tester.getSize(find.byKey(key)).height, greaterThanOrEqualTo(44));
        }
        final saveRect = tester.getRect(find.byKey(_save));
        final shareRect = tester.getRect(find.byKey(_share));
        if (narrow) {
          expect(shareRect.top, saveRect.bottom + 6);
          expect(shareRect.left, saveRect.left);
          expect(shareRect.width, saveRect.width);
        } else {
          expect(shareRect.top, saveRect.top);
          expect(shareRect.left, saveRect.right + 10);
        }
        await tester.tap(find.byKey(_share));
        await tester.pump();
        expect(anchor, shareRect);
        expect(anchor!.left, greaterThan(13));
        expect(anchor!.top, greaterThan(25));
        await tester.tap(find.byKey(_save));
        expect(saves, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('分享footer忙碌指示归属、生成禁用与原null回调保持', (tester) async {
    var busy = false, sharing = false, generating = false, callbacks = true;
    var saves = 0, shares = 0;
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
          update = setState;
          return _card(
              onSave: callbacks ? () => saves++ : null,
              onShare: callbacks ? (_) => shares++ : null,
              busy: busy,
              sharing: sharing,
              generating: generating);
        }))));
    await tester.pumpAndSettle();
    for (final state in ['generating', 'saving', 'sharing', 'null']) {
      update(() {
        generating = state == 'generating';
        busy = state == 'saving' || state == 'sharing';
        sharing = state == 'sharing';
        callbacks = state != 'null';
      });
      await tester.pump(const Duration(milliseconds: 100));
      for (final key in [_save, _share]) {
        final button = tester.widget<FilledButton>(_filled(key));
        expect(button.onPressed, isNull);
        expect(tester.widget<BeeButton>(find.byKey(key)).loading,
            state == (key == _save ? 'saving' : 'sharing'));
        expect(
            find.descendant(
                of: find.byKey(key),
                matching: find.byType(CircularProgressIndicator)),
            state == (key == _save ? 'saving' : 'sharing')
                ? findsOneWidget
                : findsNothing);
        await tester.tap(find.byKey(key));
      }
      expect(saves, 0);
      expect(shares, 0);
    }
    update(() {
      callbacks = true;
      busy = sharing = generating = false;
    });
    await tester.pump();
    await tester.tap(find.byKey(_save));
    await tester.tap(find.byKey(_share));
    expect(saves, 1);
    expect(shares, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
