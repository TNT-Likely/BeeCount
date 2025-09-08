import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../widgets/ui/ui.dart';

// 兼容旧引用
final headerStyleProvider = StateProvider<String>((ref) => 'primary');

class PersonalizePage extends ConsumerWidget {
  const PersonalizePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = ref.watch(primaryColorProvider);
    final options = <_ThemeOption>[
      _ThemeOption('默认', const Color(0xFFFFB300)),
      _ThemeOption('蜜蜂黄', const Color(0xFFF8C91C)),
      _ThemeOption('火焰橙', const Color(0xFFFF7043)),
      _ThemeOption('琉璃绿', const Color(0xFF26A69A)),
      _ThemeOption('青莲紫', const Color(0xFF7E57C2)),
      _ThemeOption('樱绯红', const Color(0xFFE91E63)),
      _ThemeOption('晴空蓝', const Color(0xFF2196F3)),
      _ThemeOption('林间月', const Color(0xFF80CBC4)),
      _ThemeOption('黄昏沙丘', const Color(0xFFFFCC80)),
      _ThemeOption('雪与松', const Color(0xFFB39DDB)),
      _ThemeOption('迷雾仙境', const Color(0xFF90CAF9)),
    ];

    return Scaffold(
      body: Column(
        children: [
          const PrimaryHeader(title: '个性装扮'),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.4,
              ),
              itemCount: options.length,
              itemBuilder: (_, i) {
                final o = options[i];
                final selected = o.color == primary;
                return _ThemeCard(
                  option: o,
                  selected: selected,
                  onTap: () =>
                      ref.read(primaryColorProvider.notifier).state = o.color,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption {
  final String name;
  final Color color;
  _ThemeOption(this.name, this.color);
}

class _ThemeCard extends StatelessWidget {
  final _ThemeOption option;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeCard(
      {required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: option.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: selected
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.check_circle, color: Colors.white),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              alignment: Alignment.center,
              child: Text(option.name,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ],
        ),
      ),
    );
  }
}
