// seed 默认分类契约测试:① 无 (name,kind) 重复 ② 无 fallback(段数错位会
// 让名字 fallback 成 snake_case key)。锁死三语言(简/繁/英)seed 二级分类质量。
//
// 历史坑(均已修,见 #118):
//  1. 英文词内连字符(Part-time / Year-end / Ride-hailing)被 split('-') 拆碎 → 改空格。
//  2. 三语言部分分类缺「父分类名」致段数错位、fallback 成 key → 补父名,对齐
//     「子类数 + 1」段。

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/services/data/seed_service.dart';
import 'package:beecount/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // seed 过程中 logger 会把日志持久化到 SharedPreferences,测试环境需 mock 掉。
  SharedPreferences.setMockInitialValues({});

  const locales = [
    Locale('zh'),
    Locale('zh', 'TW'),
    Locale('en'),
  ];
  // seed 解析失败会 `return key`(snake_case),正常分类名不会是全小写下划线串。
  final fallbackPattern = RegExp(r'^[a-z][a-z_]*$');

  for (final locale in locales) {
    final tag = locale.toLanguageTag();
    test('seed 二级分类无重复、无 fallback [$tag]', () async {
      final l10n = await AppLocalizations.delegate.load(locale);
      final db = BeeDatabase.forTesting(NativeDatabase.memory());
      try {
        await SeedService.createHierarchicalCategories(db, l10n);
        final cats = await db.select(db.categories).get();

        // ① 无 (name,kind) 重复
        final seen = <String>{};
        final dups = <String>[];
        for (final c in cats) {
          if (!seen.add('${c.name}|${c.kind}')) {
            dups.add('${c.name}|${c.kind} (L${c.level})');
          }
        }
        expect(dups, isEmpty, reason: '重复分类: $dups');

        // ② 无 fallback(段数错位会让名字 fallback 成 snake_case key)
        final fallbacks = cats
            .where((c) => fallbackPattern.hasMatch(c.name))
            .map((c) => c.name)
            .toList();
        expect(fallbacks, isEmpty, reason: 'fallback 成 key(段数错位): $fallbacks');
      } finally {
        await db.close();
      }
    });
  }
}
