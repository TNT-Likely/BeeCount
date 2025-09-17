import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../widgets/ui/ui.dart';

// 兼容旧引用
final headerStyleProvider = StateProvider<String>((ref) => 'primary');

class PersonalizePage extends ConsumerStatefulWidget {
  const PersonalizePage({super.key});

  @override
  ConsumerState<PersonalizePage> createState() => _PersonalizePageState();
}

class _PersonalizePageState extends ConsumerState<PersonalizePage> {
  @override
  Widget build(BuildContext context) {
    final primary = ref.watch(primaryColorProvider);
    final options = <_ThemeOption>[
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
      // 新增注意色系
      _ThemeOption('暖阳橘', const Color(0xFFFF8A65)),
      _ThemeOption('薄荷青', const Color(0xFF4DB6AC)),
      _ThemeOption('玫瑰金', const Color(0xFFAD7A99)),
      _ThemeOption('深海蓝', const Color(0xFF1565C0)),
      _ThemeOption('枫叶红', const Color(0xFFD32F2F)),
      _ThemeOption('翡翠绿', const Color(0xFF388E3C)),
      _ThemeOption('薰衣草', const Color(0xFF9575CD)),
      _ThemeOption('琥珀黄', const Color(0xFFFFA726)),
      _ThemeOption('胭脂红', const Color(0xFFC2185B)),
      _ThemeOption('靛青蓝', const Color(0xFF3F51B5)),
      _ThemeOption('橄榄绿', const Color(0xFF689F38)),
      _ThemeOption('珊瑚粉', const Color(0xFFFF8A80)),
      _ThemeOption('墨绿色', const Color(0xFF2E7D32)),
      _ThemeOption('紫罗兰', const Color(0xFF673AB7)),
      _ThemeOption('日落橙', const Color(0xFFFF5722)),
      _ThemeOption('孔雀蓝', const Color(0xFF00ACC1)),
      _ThemeOption('柠檬绿', Colors.lime),
    ];

    return Scaffold(
      body: Column(
        children: [
          const PrimaryHeader(
            title: '个性装扮',
            showBack: true,
            leadingIcon: Icons.brush_outlined,
            leadingPlain: true,
            compact: true,
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.4,
              ),
              itemCount: options.length + 1, // +1 for custom color picker
              itemBuilder: (_, i) {
                if (i == options.length) {
                  // Custom color picker card
                  return _CustomColorCard(
                    onTap: () => _showColorPicker(context, ref),
                  );
                }
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

  void _showColorPicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择自定义颜色'),
        content: SingleChildScrollView(
          child: _ColorPicker(
            onColorSelected: (color) {
              ref.read(primaryColorProvider.notifier).state = color;
              Navigator.of(context).pop();
            },
          ),
        ),
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

// 自定义颜色卡片
class _CustomColorCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CustomColorCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, width: 2, style: BorderStyle.solid),
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
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: const Icon(
                  Icons.palette_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              alignment: Alignment.center,
              child: Text(
                '自定义',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// HSV颜色选择器
class _ColorPicker extends StatefulWidget {
  final Function(Color) onColorSelected;
  const _ColorPicker({required this.onColorSelected});

  @override
  State<_ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<_ColorPicker> {
  HSVColor currentColor = HSVColor.fromColor(Colors.blue);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 400,
      child: Column(
        children: [
          // 颜色预览
          Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              color: currentColor.toColor(),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: Center(
              child: Text(
                '#${currentColor.toColor().r.round().toRadixString(16).padLeft(2, '0')}${currentColor.toColor().g.round().toRadixString(16).padLeft(2, '0')}${currentColor.toColor().b.round().toRadixString(16).padLeft(2, '0')}'.toUpperCase(),
                style: TextStyle(
                  color: currentColor.value > 0.5 ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 色相滑块
          Text('色相 (${currentColor.hue.round()}°)', style: const TextStyle(fontWeight: FontWeight.w500)),
          Container(
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: List.generate(7, (index) => HSVColor.fromAHSV(1.0, index * 60.0, 1.0, 1.0).toColor()),
              ),
            ),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 0,
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              ),
              child: Slider(
                value: currentColor.hue,
                min: 0,
                max: 360,
                onChanged: (value) {
                  setState(() {
                    currentColor = currentColor.withHue(value);
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 饱和度滑块
          Text('饱和度 (${(currentColor.saturation * 100).round()}%)', style: const TextStyle(fontWeight: FontWeight.w500)),
          Container(
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  HSVColor.fromAHSV(1.0, currentColor.hue, 0.0, currentColor.value).toColor(),
                  HSVColor.fromAHSV(1.0, currentColor.hue, 1.0, currentColor.value).toColor(),
                ],
              ),
            ),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 0,
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              ),
              child: Slider(
                value: currentColor.saturation,
                min: 0,
                max: 1,
                onChanged: (value) {
                  setState(() {
                    currentColor = currentColor.withSaturation(value);
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 亮度滑块
          Text('亮度 (${(currentColor.value * 100).round()}%)', style: const TextStyle(fontWeight: FontWeight.w500)),
          Container(
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  HSVColor.fromAHSV(1.0, currentColor.hue, currentColor.saturation, 0.0).toColor(),
                  HSVColor.fromAHSV(1.0, currentColor.hue, currentColor.saturation, 1.0).toColor(),
                ],
              ),
            ),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 0,
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              ),
              child: Slider(
                value: currentColor.value,
                min: 0,
                max: 1,
                onChanged: (value) {
                  setState(() {
                    currentColor = currentColor.withValue(value);
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 确认按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onColorSelected(currentColor.toColor()),
              style: ElevatedButton.styleFrom(
                backgroundColor: currentColor.toColor(),
                foregroundColor: currentColor.value > 0.5 ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('选择此颜色', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
