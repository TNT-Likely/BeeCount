import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pages/home_page.dart';
import 'pages/analytics_page.dart';
import 'pages/ledgers_page.dart';
import 'pages/settings_page.dart';
import 'pages/category_picker.dart';
import 'pages/personalize_page.dart' show headerStyleProvider;

class BeeApp extends ConsumerStatefulWidget {
  const BeeApp({super.key});

  @override
  ConsumerState<BeeApp> createState() => _BeeAppState();
}

class _BeeAppState extends ConsumerState<BeeApp> {
  int _index = 0;

  final _pages = const [
    HomePage(),
    AnalyticsPage(),
    LedgersPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '首页'),
          BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart_outline), label: '图表'),
          BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined), label: '账本'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined), label: '设置'),
        ],
      ),
      floatingActionButton: Consumer(builder: (context, ref, _) {
        final style = ref.watch(headerStyleProvider);
        final color = Theme.of(context).colorScheme.primary;
        return FloatingActionButton(
          elevation: 0,
          backgroundColor: style == 'primary' ? color : null,
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CategoryPickerPage(
                  initialKind: 'expense',
                  quickAdd: true,
                ),
              ),
            );
          },
          child: const Icon(Icons.add, color: Colors.white),
        );
      }),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
