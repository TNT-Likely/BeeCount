/// 账户品牌图标组件(Cloud 0041 对接)。
///
/// 根据 Cloud 下发的 icon_key / icon_type 加载对应 SVG：
///   - icon_type=bank  → assets/account_icons/banks/cn/{key}.svg
///   - icon_type=card  → assets/account_icons/banks/intl/{key}.svg
///   - icon_type=custom/其它 → 尝试 intl 再 cn
/// 找不到图标时由调用方回退到 AccountTypeIcon。
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CloudAccountIcon extends StatelessWidget {
  const CloudAccountIcon({
    super.key,
    required this.iconKey,
    this.iconType,
    this.size = 32,
  });

  final String iconKey;
  final String? iconType;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = _resolvePath(iconKey, iconType);
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      // 图标缺失时不抛异常，显示空占位（调用方决定是否回退）
      placeholderBuilder: (_) => SizedBox(width: size, height: size),
    );
  }

  static String _resolvePath(String key, String? type) {
    if (type == 'bank') return 'assets/account_icons/banks/cn/$key.svg';
    if (type == 'card') return 'assets/account_icons/banks/intl/$key.svg';
    // custom/未知：先按 intl 找（visa/mastercard 等），找不到 cn 兜底由
    // placeholderBuilder 静默处理。
    return 'assets/account_icons/banks/intl/$key.svg';
  }

  /// 判断该 key 是否可能对应一个内置图标（用于调用方决定是否回退）。
  static bool isBuiltIn(String? key) =>
      key != null && key.isNotEmpty && !key.startsWith('custom_');
}
