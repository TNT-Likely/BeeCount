import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:beecount/pages/main/mine/widgets/mine_avatar.dart';
import 'package:beecount/pages/shared/branding/bee_artwork.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

final _photo = Uint8List.fromList(base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='));

void main() {
  for (final size in [const Size(398, 844), const Size(320, 568)]) {
    for (final scale in [1.0, 1.4]) {
      for (final dark in [false, true]) {
        for (final photo in [false, true]) {
          testWidgets('A轻量顶部 ${size.width} $scale dark=$dark photo=$photo',
              (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(MaterialApp(
                theme: beeTheme(
                    brightness: dark ? Brightness.dark : Brightness.light,
                    accent: photo
                        ? const Color(0xff28a399)
                        : const Color(0xfffacb16)),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!),
                home: Scaffold(
                    body: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 17),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              BeeProfile(
                                  nickname: '认真记录每一天的小满和非常长的昵称',
                                  greeting: '早上好',
                                  subtitle: '简单记录，安心生活',
                                  avatar: photo
                                      ? Image.memory(_photo, fit: BoxFit.cover)
                                      : const MineDefaultAvatar(),
                                  onEdit: () {},
                                  onTap: () {}),
                              const SizedBox(height: 12),
                              BeeLedgerBalance(
                                  ledger: '认真生活的每一天与旅行的美元账本',
                                  amount: '12,860.50',
                                  prefix: 'US\$',
                                  currencyLabel: 'USD',
                                  balanceLabel: '当前余额',
                                  stats: '',
                                  days: '268',
                                  count: '1,268',
                                  daysLabel: '天',
                                  countLabel: '笔',
                                  privacyLabel: '隐藏金额',
                                  onLedgerTap: () {},
                                  onCountTap: () {},
                                  onPrivacyTap: () {})
                            ])))));
            await tester.pumpAndSettle();
            final profile = find.byType(BeeProfile);
            final avatar = find.descendant(
                of: profile,
                matching: find.byWidgetPredicate((widget) =>
                    widget is SizedBox &&
                    widget.key == const ValueKey('profile-avatar')));
            expect(avatar, findsOneWidget);
            expect(tester.getSize(avatar), const Size(48, 48));
            expect(
                find.descendant(of: avatar, matching: find.byType(Container)),
                findsNothing,
                reason: '头像不能再增加带底色的外层容器');
            if (photo) {
              final image =
                  find.descendant(of: avatar, matching: find.byType(Image));
              expect(tester.getSize(image), const Size(48, 48));
              expect(tester.widget<Image>(image).fit, BoxFit.cover);
              expect(
                  find.descendant(of: avatar, matching: find.byType(ClipOval)),
                  findsOneWidget);
              expect(
                  find.descendant(of: avatar, matching: find.byType(ClipRRect)),
                  findsNothing);
            } else {
              final svg = tester.widget<SvgPicture>(find.descendant(
                  of: avatar, matching: find.byType(SvgPicture)));
              expect(
                  (svg.bytesLoader as SvgAssetLoader).assetName,
                  dark
                      ? 'assets/images/bee_profile_dark.svg'
                      : 'assets/bee.svg');
            }
            final total =
                tester.getBottomLeft(find.byType(BeeLedgerBalance)).dy -
                    tester.getTopLeft(profile).dy;
            expect(total, lessThan(scale == 1 ? 175 : 210));
            expect(find.text('USD'), findsOneWidget);
            expect(find.text('268'), findsOneWidget);
            expect(find.text('1,268'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          });
        }
      }
    }
  }

  testWidgets('默认我的头像不使用其它品牌位置的暗色圆形遮罩', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(brightness: Brightness.dark),
        home: const Scaffold(
            body: Row(children: [
          MineDefaultAvatar(),
          BeeIcon(color: Colors.amber, size: 32)
        ]))));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(MineDefaultAvatar),
            matching: find.byType(Container)),
        findsNothing);
    expect(
        find.descendant(
            of: find.byType(BeeIcon), matching: find.byType(Container)),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('仅我的暗色SVG适配线色，原品牌素材保持原字节', () {
    final original = File('assets/bee.svg').readAsStringSync();
    final dark = File('assets/images/bee_profile_dark.svg').readAsStringSync();
    expect(
        dark,
        original
            .replaceAll('#000000', '#DCE2E6')
            .replaceAll('#000', '#DCE2E6')
            .replaceAll('#fff', '#202529'));
    expect(dark, isNot(contains('<mask')));
    expect(dark, isNot(contains('r="128"')));
  });
}
