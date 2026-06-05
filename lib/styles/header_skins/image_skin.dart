part of '../header_skins.dart';

// ====== 图片皮肤(SVG 素材,全幅铺满)======
// 整幅 BoxFit.cover 铺满 header,与代码皮肤尺寸一致;底色仅作 SVG 透明区兜底
// (亮=主题色浅染 / 暗=纯黑)。
// themed=true:用 colorFilter(srcIn)把整幅 SVG 重新着色成主题色,明暗层次靠 SVG
//   自身的 fill-opacity 表现(暗黑底为纯黑,主题色自然偏淡);themed=false(默认):
//   按 SVG 自带的内联 fill 渲染(固定配色)。
class _ImageSkin extends StatelessWidget {
  const _ImageSkin(this.asset, this.primary, this.isDark, {this.themed = false});
  final String asset;
  final Color primary;
  final bool isDark;
  final bool themed;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? Colors.black : _lighten(primary, 0.16),
      child: SvgPicture.asset(
        asset,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        colorFilter: themed ? ColorFilter.mode(primary, BlendMode.srcIn) : null,
      ),
    );
  }
}
