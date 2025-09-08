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
    // 将 4 个页面映射到 5 槽位（中间为“+”）：
    // 页面索引 0,1,2,3 对应视觉槽位 0,1,3,4（槽位 2 为 +）。
    final visualActiveIndex = _index >= 2 ? _index + 1 : _index;

    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 4,
        elevation: 8,
        child: SizedBox(
          height: 54,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(5, (i) {
              if (i == 2) {
                // 中间预留给 FAB 的槽位，确保 5 等分
                return const Expanded(child: SizedBox());
              }
              // 槽位转页面索引
              final pageIndex = i > 2 ? i - 1 : i;
              final active = visualActiveIndex == i;
              Color color = active
                  ? Theme.of(context).colorScheme.primary
                  : Colors.black54;
              IconData icon;
              String label;
              switch (pageIndex) {
                case 0:
                  icon = Icons.list_alt_rounded;
                  label = '明细';
                  break;
                case 1:
                  icon = Icons.pie_chart_rounded;
                  label = '图表';
                  break;
                case 2:
                  icon = Icons.menu_book_rounded;
                  label = '账本';
                  break;
                default:
                  icon = Icons.settings_rounded;
                  label = '我的';
              }
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _index = pageIndex),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: color),
                        const SizedBox(height: 4),
                        Text(label,
                            style: TextStyle(
                                fontSize: 11,
                                color: color,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.w400)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
      floatingActionButton: Consumer(builder: (context, ref, _) {
        final style = ref.watch(headerStyleProvider);
        final color = Theme.of(context).colorScheme.primary;
        return SizedBox(
          width: 58,
          height: 58,
          child: FloatingActionButton(
            heroTag: 'addFab',
            elevation: 8,
            shape: const CircleBorder(),
            backgroundColor: style == 'primary' ? color : color,
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
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        );
      }),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
