import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../styles/tokens.dart';
import '../../providers.dart';
import 'format_money.dart';

class AmountText extends ConsumerWidget {
  final double value;
  final bool? hide; // 改为可选,null时使用全局状态
  final bool signed; // 是否显示正负号
  final int decimals;
  final TextStyle? style;
  final bool showCurrency; // 是否显示币种符号(¥/$等),默认false
  final bool useCompactFormat; // 是否使用大金额缩写(万/千/k/M等),默认false
  final String? currencyCode; // 指定币种代码,null时自动获取当前账本币种
  final bool colorizeIncome; // 是否给收入添加绿色,默认false

  const AmountText({
    super.key,
    required this.value,
    this.hide,
    this.signed = true,
    this.decimals = 2,
    this.style,
    this.showCurrency = false,
    this.useCompactFormat = false,
    this.currencyCode,
    this.colorizeIncome = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 优先使用传入的hide,否则使用全局状态
    final shouldHide = hide ?? ref.watch(hideAmountsProvider);

    if (shouldHide == true) {
      return Text('****',
          style: style ??
              Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: BeeTokens.textPrimary(context)));
    }

    String? effectiveCurrency;
    var isChinese = true;
    if (showCurrency || useCompactFormat) {
      effectiveCurrency = currencyCode ??
          ref.watch(currentLedgerProvider).asData?.value?.currency;
      if (effectiveCurrency != null) {
        final selectedLocale = ref.watch(languageProvider);
        isChinese = selectedLocale?.languageCode == 'zh' ||
            (selectedLocale == null &&
                Localizations.localeOf(context).languageCode == 'zh');
      }
    }
    final displayText = formatDisplayAmount(value,
        currencyCode: effectiveCurrency,
        showCurrency: showCurrency,
        useCompactFormat: useCompactFormat,
        isChineseLocale: isChinese,
        signed: signed,
        decimals: decimals);

    // 计算最终样式：收入且开启着色时使用绿色
    final isIncome = value > 0;
    final baseStyle = style ??
        Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: BeeTokens.textPrimary(context));

    final finalStyle = (colorizeIncome && isIncome)
        ? baseStyle?.copyWith(color: BeeTokens.incomeColor(context, ref))
        : baseStyle;

    return Text(
      displayText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      style: finalStyle,
    );
  }
}
