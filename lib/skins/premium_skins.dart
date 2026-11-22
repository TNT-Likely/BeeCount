import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SkinAppearance {
  const SkinAppearance({
    this.skinId,
    this.transparency = .35,
    this.blur = 4,
    this.scene = .85,
    this.motion = .6,
    this.animated = true,
  });

  static const maxTransparency = .55;
  static const maxBlur = 12.0;
  final String? skinId;
  final double transparency, blur, scene, motion;
  final bool animated;
}

class PremiumSkin {
  const PremiumSkin({
    required this.id,
    required this.name,
    required this.englishName,
    required this.preview,
    required this.colors,
    required this.scene,
  });

  final String id, name, englishName;
  final WidgetBuilder preview;
  final ({Color accent, Color onAccent}) Function(Brightness brightness) colors;
  final Widget Function(BuildContext context, SkinAppearance appearance,
      Widget child, double topInset) scene;
}

enum SkinPurchaseResult { launched, pending, cancelled, unavailable }

/// Optional skin services. The normal App starts with just the free selection.
class PremiumSkins extends ChangeNotifier {
  List<PremiumSkin> get skins => const [];
  SkinAppearance get appearance => const SkinAppearance();
  SkinAppearance appearanceFor(String id) => SkinAppearance(skinId: id);

  PremiumSkin? skin(String? id) =>
      skins.where((skin) => skin.id == id).firstOrNull;

  PremiumSkin? get selectedSkin => owned ? skin(appearance.skinId) : null;
  bool get active => selectedSkin != null;
  bool get owned => false;
  String? get price => null;
  bool get salesEnabled => false;
  bool get canMakePayments => false;
  bool get busy => false;

  Future<bool> select(String id, SkinAppearance value) async => false;
  Future<void> clearSelection() async {}
  Future<SkinPurchaseResult> purchase() async => SkinPurchaseResult.unavailable;
  Future<bool> restore() async => false;
  Future<bool> redeem() async => false;
  Future<void> refresh() async {}
  void refreshColors() {
    if (active) notifyListeners();
  }

  Widget? navigationArtwork(BuildContext context) => null;
}

final premiumSkinsProvider =
    ChangeNotifierProvider<PremiumSkins>((ref) => PremiumSkins());

String skinText(BuildContext context, String zh, String en) =>
    Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

String premiumSkinName(BuildContext context, PremiumSkin skin) =>
    skinText(context, skin.name, skin.englishName);
