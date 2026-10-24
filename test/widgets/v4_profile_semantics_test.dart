import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('资料头像和昵称有独立的按钮名称，不合并下方账本金额', (tester) async {
    final handle = tester.ensureSemantics();
    var profiles = 0, nicknames = 0;
    try {
      await tester.pumpWidget(MaterialApp(
          theme: beeTheme(),
          home: Scaffold(
              body: Column(children: [
            BeeProfile(
                nickname: '小满',
                greeting: '早上好',
                subtitle: '简单记录',
                profileLabel: '编辑资料',
                editLabel: '设置昵称',
                avatar: Image.asset('assets/logo2.png'),
                onTap: () => profiles++,
                onEdit: () => nicknames++),
            const Text('账本结余 ¥12,860.50')
          ]))));
      await tester.pumpAndSettle();
      final avatar = find.bySemanticsLabel('编辑资料').first;
      final name = find.bySemanticsLabel(RegExp(r'^设置昵称')).first;
      final avatarNode = tester.getSemantics(avatar),
          nameNode = tester.getSemantics(name);
      expect(avatarNode.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(avatarNode.hasFlag(SemanticsFlag.isImage), isFalse);
      expect(nameNode.label, contains('小满'));
      expect(nameNode.label, isNot(contains('账本结余')));
      expect(nameNode.rect.height, lessThan(80));
      await tester.tap(avatar);
      await tester.pump();
      await tester.tap(name);
      await tester.pump();
      expect(profiles, 1);
      expect(nicknames, 1);
      expect(tester.takeException(), isNull);
    } finally {
      handle.dispose();
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
