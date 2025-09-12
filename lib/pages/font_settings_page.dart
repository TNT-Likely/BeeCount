import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/ui/ui.dart';
import '../providers/font_scale_provider.dart';
import '../styles/design.dart';
import '../styles/colors.dart';

class FontSettingsPage extends ConsumerWidget {
  const FontSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(fontScaleLevelProvider);
    final eff = ref.watch(effectiveFontScaleProvider);
    final options = const [
      _FontOption(label: '更小', value: -2, preview: '12.34 记账示例'),
      _FontOption(label: '小', value: -1, preview: '12.34 记账示例'),
      _FontOption(label: '标准', value: 0, preview: '12.34 记账示例'),
      _FontOption(label: '大', value: 1, preview: '12.34 记账示例'),
    ];

    return Scaffold(
      body: Column(
        children: [
          const PrimaryHeader(title: '字体设置', showBack: true, compact: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Text('当前缩放：x${eff.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                _PreviewParagraph(level: level),
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
                Text(
                    '说明：此设置在系统字体缩放基础上再微调；用于不同设备显示差异的细节修正；“更小”适合 DPI 较低且显得拥挤的机型。',
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
      case -2:
        return '更小';
      case -1:
        return '小';
      case 1:
        return '大';
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

// 滑块已移除：保留档位按钮以保持交互简单。
