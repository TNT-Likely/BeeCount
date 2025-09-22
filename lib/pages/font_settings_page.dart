import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
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
    final options = [
      _FontOption(label: AppLocalizations.of(context)!.fontSettingsExtraSmall, value: -3, preview: AppLocalizations.of(context)!.fontSettingsScaleExample),
      _FontOption(label: AppLocalizations.of(context)!.fontSettingsVerySmall, value: -2, preview: AppLocalizations.of(context)!.fontSettingsScaleExample),
      _FontOption(label: AppLocalizations.of(context)!.fontSettingsSmall, value: -1, preview: AppLocalizations.of(context)!.fontSettingsScaleExample),
      _FontOption(label: AppLocalizations.of(context)!.fontSettingsStandard, value: 0, preview: AppLocalizations.of(context)!.fontSettingsScaleExample),
      _FontOption(label: AppLocalizations.of(context)!.fontSettingsLarge, value: 1, preview: AppLocalizations.of(context)!.fontSettingsScaleExample),
      _FontOption(label: AppLocalizations.of(context)!.fontSettingsBig, value: 2, preview: AppLocalizations.of(context)!.fontSettingsScaleExample),
      _FontOption(label: AppLocalizations.of(context)!.fontSettingsVeryBig, value: 3, preview: AppLocalizations.of(context)!.fontSettingsScaleExample),
      _FontOption(label: AppLocalizations.of(context)!.fontSettingsExtraBig, value: 4, preview: AppLocalizations.of(context)!.fontSettingsScaleExample),
    ];

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(title: AppLocalizations.of(context)!.mineDisplayScale, showBack: true, compact: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                // 显示缩放设置部分
                Text(AppLocalizations.of(context)!.mineDisplayScale,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(AppLocalizations.of(context)!.fontSettingsCurrentScale(eff.toStringAsFixed(2)),
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                _PreviewParagraph(level: level),
                const SizedBox(height: 12),
                _UIScaleInfo(),
                const SizedBox(height: 12),
                _MultiStylePreview(),
                const SizedBox(height: 20),
                Text(AppLocalizations.of(context)!.fontSettingsQuickLevel,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...options.map((o) => _buildOption(context, ref, o, level)),
                const SizedBox(height: 24),
                Text(AppLocalizations.of(context)!.fontSettingsCustomAdjust,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _CustomScaleSlider(),
                const SizedBox(height: 24),
                Text(
                    AppLocalizations.of(context)!.fontSettingsDescription,
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
    final sample = AppLocalizations.of(context)!.fontSettingsPreviewText;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.fontSettingsPreview, style: theme.titleMedium),
            const SizedBox(height: 8),
            Transform.scale(
              scale: 1.0, // 视觉不再二次放大，仅展示换档后真实文本
              child: Text(sample,
                  style: lineStyle, textAlign: TextAlign.left, softWrap: true),
            ),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.fontSettingsCurrentLevel(_levelName(context, level), scale.toStringAsFixed(2)),
                style: theme.bodySmall?.copyWith(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  String _levelName(BuildContext context, int l) {
    switch (l) {
      case -3:
        return AppLocalizations.of(context)!.fontSettingsExtraSmall;
      case -2:
        return AppLocalizations.of(context)!.fontSettingsVerySmall;
      case -1:
        return AppLocalizations.of(context)!.fontSettingsSmall;
      case 1:
        return AppLocalizations.of(context)!.fontSettingsLarge;
      case 2:
        return AppLocalizations.of(context)!.fontSettingsBig;
      case 3:
        return AppLocalizations.of(context)!.fontSettingsVeryBig;
      case 4:
        return AppLocalizations.of(context)!.fontSettingsExtraBig;
      default:
        return AppLocalizations.of(context)!.fontSettingsStandard;
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
            Text(AppLocalizations.of(context)!.fontSettingsMoreStyles, style: theme.titleMedium),
            const SizedBox(height: 10),
            _kv(AppLocalizations.of(context)!.fontSettingsPageTitle, '月度统计与分析', theme.titleLarge),
            const SizedBox(height: 6),
            _kv(AppLocalizations.of(context)!.fontSettingsBlockTitle, '最近记账', theme.titleMedium),
            const SizedBox(height: 6),
            _kv(AppLocalizations.of(context)!.fontSettingsBodyExample, '今天早餐：豆浆 + 包子 6.50 元', theme.bodyMedium),
            const SizedBox(height: 6),
            _kv(AppLocalizations.of(context)!.fontSettingsLabelExample, '隐藏金额已开启', theme.labelMedium),
            const SizedBox(height: 6),
            _kv(AppLocalizations.of(context)!.fontSettingsStrongNumber, '1234.56',
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
                Text(AppLocalizations.of(context)!.fontSettingsListTitle,
                    style: title, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(AppLocalizations.of(context)!.fontSettingsListSubtitle,
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
            Text(AppLocalizations.of(context)!.fontSettingsScreenInfo, style: theme.titleMedium),
            SizedBox(height: 8.0.scaled(context, ref)),
            _infoRow(AppLocalizations.of(context)!.fontSettingsScreenDensity, debugInfo['devicePixelRatio']!.toStringAsFixed(2)),
            _infoRow(AppLocalizations.of(context)!.fontSettingsScreenWidth, '${debugInfo['screenWidth']!.toStringAsFixed(0)}dp'),
            _infoRow(AppLocalizations.of(context)!.fontSettingsDeviceScale, 'x${debugInfo['deviceScaleFactor']!.toStringAsFixed(2)}'),
            _infoRow(AppLocalizations.of(context)!.fontSettingsUserScale, 'x${debugInfo['userScaleFactor']!.toStringAsFixed(2)}'),
            _infoRow(AppLocalizations.of(context)!.fontSettingsFinalScale, 'x${debugInfo['finalScaleFactor']!.toStringAsFixed(2)}'),
            _infoRow(AppLocalizations.of(context)!.fontSettingsBaseDevice, debugInfo['isBaseDevice']! > 0.5 ? AppLocalizations.of(context)!.fontSettingsYes : AppLocalizations.of(context)!.fontSettingsNo),
            _infoRow(AppLocalizations.of(context)!.fontSettingsRecommendedScale, 'x${debugInfo['recommendedUserScale']!.toStringAsFixed(2)}'),
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
                      AppLocalizations.of(context)!.fontSettingsScaleExample,
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
                Text(AppLocalizations.of(context)!.fontSettingsPreciseAdjust, style: theme.titleMedium),
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
                    child: Text(AppLocalizations.of(context)!.fontSettingsResetTo1x),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final recommendedScale = UIScaleService.getRecommendedUserScale(context);
                      ref.read(customFontScaleProvider.notifier).state = recommendedScale;
                    },
                    child: Text(AppLocalizations.of(context)!.fontSettingsAdaptBase),
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
