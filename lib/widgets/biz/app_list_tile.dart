import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../ui/feature_dot.dart';

class AppListTile extends StatelessWidget {
  final IconData leading;
  final Widget? leadingWidget;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool enabled;
  final Widget? trailing;

  /// 新功能红点的锚点 id。给了就在图标右上角挂红点,该锚点下没有未读功能时
  /// 不渲染。放在这里而不是让调用方自己包 [FeatureDot],是因为默认图标那个
  /// 36×36 圆形容器的样式在这个文件里 —— 让每个调用点去复刻一遍必然走样。
  final String? dotAnchor;

  const AppListTile(
      {super.key,
      required this.leading,
      this.leadingWidget,
      required this.title,
      this.subtitle,
      this.onTap,
      this.enabled = true,
      this.trailing,
      this.dotAnchor});

  Widget _withDot(Widget icon) =>
      dotAnchor == null ? icon : FeatureDot(anchor: dotAnchor!, child: icon);

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : .45,
        child: BeeMenuRow(
          title: title,
          subtitle: subtitle,
          leading: _withDot(leadingWidget ??
              Icon(leading,
                  size: 21, color: Theme.of(context).colorScheme.onSurface)),
          trailing: trailing,
          onTap: enabled ? onTap : null,
        ),
      );
}
