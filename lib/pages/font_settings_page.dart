import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/ui/ui.dart';
import '../providers/font_scale_provider.dart';
import '../styles/design.dart';
import '../styles/colors.dart';
import '../utils/ui_scale_extensions.dart';
import '../services/ui_scale_service.dart';

class FontSettingsPage extends ConsumerWidget {
  const FontSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(fontScaleLevelProvider);
    final eff = ref.watch(effectiveFontScaleProvider);
    final options = const [
      _FontOption(label: '极小', value: -3, preview: '12.34 记账示例'),
      _FontOption(label: '很小', value: -2, preview: '12.34 记账示例'),
      _FontOption(label: '较小', value: -1, preview: '12.34 记账示例'),
      _FontOption(label: '标准', value: 0, preview: '12.34 记账示例'),
      _FontOption(label: '较大', value: 1, preview: '12.34 记账示例'),
      _FontOption(label: '大', value: 2, preview: '12.34 记账示例'),
      _FontOption(label: '很大', value: 3, preview: '12.34 记账示例'),
      _FontOption(label: '极大', value: 4, preview: '12.34 记账示例'),
    ];

    return Scaffold(
      body: Column(
        children: [
          const PrimaryHeader(title: '显示缩放', showBack: true, compact: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                // 显示缩放设置部分
                Text('显示缩放',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('当前缩放：x${eff.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                _PreviewParagraph(level: level),
                const SizedBox(height: 12),
                _UIScaleInfo(),
                const SizedBox(height: 12),
                _MultiStylePreview(),
                const SizedBox(height: 20),
                Text('快速档位',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...options.map((o) => _buildOption(context, ref, o, level)),
                const SizedBox(height: 24),
                Text('自定义调整',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _CustomScaleSlider(),
                const SizedBox(height: 24),
                Text(
                    '说明：此设置确保所有设备在1.0倍时显示效果一致，设备差异已自动补偿；调整数值可在一致基础上进行个性化缩放。',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
      BuildContext context, WidgetRef ref, _FontOption o, int current) {
    final active = o.value == current;
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        );
    return Card(
      elevation: 0,
      child: ListTile(
        title: Text(o.label, style: style),
        subtitle: Text(o.preview, style: Theme.of(context).textTheme.bodySmall),
        trailing:
            active ? const Icon(Icons.check_circle, color: Colors.green) : null,
        onTap: () => ref.read(fontScaleLevelProvider.notifier).state = o.value,
      ),
    );
  }
}

class _FontOption {
  final String label;
  final int value;
  final String preview;
  const _FontOption(
      {required this.label, required this.value, required this.preview});
}

class _PreviewParagraph extends ConsumerWidget {
  final int level;
  const _PreviewParagraph({required this.level});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(effectiveFontScaleProvider);
    final theme = Theme.of(context).textTheme;
    final lineStyle = theme.bodyMedium;
    final sample = '今天吃饭花了 23.50 元，记一笔；\n本月已记账 45 天，共 320 条记录；\n坚持就是胜利！';
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('实时预览', style: theme.titleMedium),
            const SizedBox(height: 8),
            Transform.scale(
              scale: 1.0, // 视觉不再二次放大，仅展示换档后真实文本
              child: Text(sample,
                  style: lineStyle, textAlign: TextAlign.left, softWrap: true),
            ),
            const SizedBox(height: 8),
            Text('当前档位：${_levelName(level)}  (倍率 x${scale.toStringAsFixed(2)})',
                style: theme.bodySmall?.copyWith(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  String _levelName(int l) {
    switch (l) {
      case -3:
        return '极小';
      case -2:
        return '很小';
      case -1:
        return '较小';
      case 1:
        return '较大';
      case 2:
        return '大';
      case 3:
        return '很大';
      case 4:
        return '极大';
      default:
        return '标准';
    }
  }
}

// 多样文本风格预览：标题/副标题/正文/标签/强调数字/列表示例
class _MultiStylePreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('更多风格', style: theme.titleMedium),
            const SizedBox(height: 10),
            _kv('页面标题', '月度统计与分析', theme.titleLarge),
            const SizedBox(height: 6),
            _kv('区块标题', '最近记账', theme.titleMedium),
            const SizedBox(height: 6),
            _kv('正文示例', '今天早餐：豆浆 + 包子 6.50 元', theme.bodyMedium),
            const SizedBox(height: 6),
            _kv('标签说明', '隐藏金额已开启', theme.labelMedium),
            const SizedBox(height: 6),
            _kv('强调数字', '1234.56',
                AppTextTokens.strongTitle(context).copyWith(fontSize: 18)),
            const Divider(height: 20),
            _ListTileMock(),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v, TextStyle? style) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(k,
              style: style != null
                  ? style.copyWith(
                      fontSize: (style.fontSize ?? 14) - 1,
                      color: Colors.black54,
                    )
                  : const TextStyle(fontSize: 12, color: Colors.black54)),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            v,
            style: style != null
                ? style.copyWith(color: BeeColors.primaryText)
                : const TextStyle(fontSize: 14, color: BeeColors.primaryText),
          ),
        )
      ],
    );
  }
}

class _ListTileMock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final title = AppTextTokens.title(context);
    final label = AppTextTokens.label(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.brush_outlined,
                color: Theme.of(context).colorScheme.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('列表项标题',
                    style: title, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('辅助说明文本',
                    style: label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('123.45', style: AppTextTokens.strongTitle(context)),
        ],
      ),
    );
  }
}

// UI缩放信息显示组件
class _UIScaleInfo extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debugInfo = ref.watch(uiScaleDebugProvider(context));
    final theme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(12.0.scaled(context, ref)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('屏幕适配信息', style: theme.titleMedium),
            SizedBox(height: 8.0.scaled(context, ref)),
            _infoRow('屏幕密度', debugInfo['devicePixelRatio']!.toStringAsFixed(2)),
            _infoRow('屏幕宽度', '${debugInfo['screenWidth']!.toStringAsFixed(0)}dp'),
            _infoRow('设备缩放', 'x${debugInfo['deviceScaleFactor']!.toStringAsFixed(2)}'),
            _infoRow('用户缩放', 'x${debugInfo['userScaleFactor']!.toStringAsFixed(2)}'),
            _infoRow('最终缩放', 'x${debugInfo['finalScaleFactor']!.toStringAsFixed(2)}'),
            _infoRow('基准设备', debugInfo['isBaseDevice']! > 0.5 ? '是' : '否'),
            _infoRow('推荐缩放', 'x${debugInfo['recommendedUserScale']!.toStringAsFixed(2)}'),
            SizedBox(height: 8.0.scaled(context, ref)),
            Container(
              padding: EdgeInsets.all(8.0.scaled(context, ref)),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.0.scaled(context, ref)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24.0.scaled(context, ref),
                    height: 24.0.scaled(context, ref),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8.0.scaled(context, ref)),
                  Expanded(
                    child: Text(
                      '此方框和间距会根据设备自动缩放',
                      style: theme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// 自定义缩放滑块组件
class _CustomScaleSlider extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customScale = ref.watch(customFontScaleProvider);
    final effectiveScale = ref.watch(effectiveFontScaleProvider);
    final theme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('精确调整', style: theme.titleMedium),
                Text('x${effectiveScale.toStringAsFixed(2)}',
                    style: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Theme.of(context).colorScheme.primary,
                inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
                thumbColor: Theme.of(context).colorScheme.primary,
                overlayColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: Slider(
                value: customScale,
                min: 0.7,
                max: 1.5,
                divisions: 80, // 0.01 精度
                onChanged: (value) {
                  ref.read(customFontScaleProvider.notifier).state = value;
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0.7x', style: theme.bodySmall),
                Text('1.0x', style: theme.bodySmall),
                Text('1.5x', style: theme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(customFontScaleProvider.notifier).state = 1.0;
                    },
                    child: const Text('重置到1.0x'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final recommendedScale = UIScaleService.getRecommendedUserScale(context);
                      ref.read(customFontScaleProvider.notifier).state = recommendedScale;
                    },
                    child: const Text('适配基准'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
