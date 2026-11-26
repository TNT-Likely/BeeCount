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
    required this.traditionalName,
    required this.englishName,
    required this.preview,
    required this.colors,
    required this.scene,
  });

  final String id, name, traditionalName, englishName;
  final WidgetBuilder preview;
  final ({Color accent, Color onAccent}) Function(Brightness brightness) colors;
  final Widget Function(BuildContext context, SkinAppearance appearance,
      Widget child, double topInset) scene;
}

class PremiumSkinCollection {
  const PremiumSkinCollection({
    required this.id,
    required this.name,
    required this.traditionalName,
    required this.englishName,
    required this.skins,
  });

  final String id, name, traditionalName, englishName;
  final List<PremiumSkin> skins;

  PremiumSkin? skin(String? id) =>
      skins.where((skin) => skin.id == id).firstOrNull;

  String nameOf(BuildContext context) =>
      _localizedSkinName(context, name, traditionalName, englishName);
}

enum SkinPurchaseResult { launched, pending, cancelled, unavailable }

/// Optional skin services. The normal App starts with just the free selection.
class PremiumSkins extends ChangeNotifier {
  List<PremiumSkinCollection> get collections => const [];
  SkinAppearance get appearance => const SkinAppearance();
  SkinAppearance appearanceFor(String id) => SkinAppearance(skinId: id);

  PremiumSkinCollection? collectionForSkin(String? id) => id == null
      ? null
      : collections.where((pack) => pack.skin(id) != null).firstOrNull;

  PremiumSkin? get selectedSkin {
    final id = appearance.skinId;
    final pack = collectionForSkin(id);
    return pack != null && ownsPack(pack.id) ? pack.skin(id) : null;
  }

  bool get active => selectedSkin != null;
  bool ownsPack(String packId) => false;
  String? priceForPack(String packId) => null;
  bool salesEnabledForPack(String packId) => false;
  bool get canMakePayments => false;
  bool get busy => false;

  bool canPurchasePack(PremiumSkinCollection pack) =>
      pack.skins.isNotEmpty &&
      !ownsPack(pack.id) &&
      salesEnabledForPack(pack.id) &&
      priceForPack(pack.id) != null &&
      canMakePayments &&
      !busy;

  Future<bool> select(String id, SkinAppearance value) async => false;
  Future<void> clearSelection() async {}
  Future<SkinPurchaseResult> purchasePack(String packId) async =>
      SkinPurchaseResult.unavailable;
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
    _localizedSkinName(
        context, skin.name, skin.traditionalName, skin.englishName);

String _localizedSkinName(
    BuildContext context, String zh, String hant, String en) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode != 'zh') return en;
  final traditional = locale.scriptCode == 'Hant' ||
      const {'TW', 'HK', 'MO'}.contains(locale.countryCode);
  return traditional ? hant : zh;
}
