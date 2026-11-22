import 'package:beecount/main.dart' show runBeeCount;
import 'package:beecount/skins/premium_skins.dart';
import 'package:beecount_commercial/beecount_commercial.dart';
import 'package:beecount_skins/beecount_skins.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OfficialRuntime.prepare();
  await runBeeCount(premiumSkins: _AppStoreSkins(OfficialRuntime.instance));
}

class _AppStoreSkins extends PremiumSkins {
  _AppStoreSkins(this._runtime) {
    _runtime.addListener(notifyListeners);
  }

  final OfficialRuntime _runtime;
  late final _skins = [
    for (final skin in autumnCollection)
      if (autumnArtworks[skin.id] case final artwork?)
        PremiumSkin(
          id: skin.id,
          name: skin.name,
          englishName: skin.englishName,
          colors: (brightness) {
            final colors = autumnMaterial(skin.id, brightness);
            return (accent: colors.accent, onAccent: colors.onAccent);
          },
          preview: (context) => SkinArtworkHost(
            artwork: artwork,
            brightness: Theme.of(context).brightness,
            display: const SkinDisplay(motionEnabled: false),
            child: const SizedBox.expand(),
          ),
          scene: (context, settings, child, topInset) =>
              _scene(context, skin.id, artwork, settings, child, topInset),
        ),
  ];

  StoreProduct? get _product => _runtime.commerce?.products
      .where((product) =>
          product.id == officialPackProductId &&
          product.kind == ProductKind.nonConsumable)
      .firstOrNull;

  @override
  List<PremiumSkin> get skins => _runtime.paidSkinsEnabled ? _skins : const [];
  @override
  bool get owned => _runtime.owned;
  @override
  String? get price => _product?.localizedPrice;
  @override
  bool get salesEnabled => _runtime.commerce?.salesEnabled == true;
  @override
  bool get canMakePayments => _runtime.gateway?.canMakePayments == true;
  @override
  bool get busy => _runtime.commerce?.busy == true;

  @override
  SkinAppearance get appearance => _toUi(_runtime.appearance);
  @override
  SkinAppearance appearanceFor(String id) => _toUi(_runtime.appearanceFor(id));

  SkinAppearance _toUi(OfficialAppearance value) => SkinAppearance(
        skinId: value.skinId,
        transparency: value.transparency,
        blur: value.blur,
        scene: value.scene,
        motion: value.motion,
        animated: value.animated,
      );

  @override
  Future<bool> select(String id, SkinAppearance value) => _runtime.select(
        id,
        OfficialAppearance(
          skinId: value.skinId,
          transparency: value.transparency,
          blur: value.blur,
          scene: value.scene,
          motion: value.motion,
          animated: value.animated,
        ),
      );

  @override
  Future<void> clearSelection() => _runtime.clearSelection();

  @override
  Future<SkinPurchaseResult> purchase() async {
    final product = _product;
    final commerce = _runtime.commerce;
    if (product == null || commerce == null) {
      return SkinPurchaseResult.unavailable;
    }
    final result = await commerce.purchase(product);
    return switch (result) {
      PurchaseLaunchResult.launched => SkinPurchaseResult.launched,
      PurchaseLaunchResult.pending => SkinPurchaseResult.pending,
      PurchaseLaunchResult.cancelled => SkinPurchaseResult.cancelled,
      _ => SkinPurchaseResult.unavailable,
    };
  }

  @override
  Future<bool> restore() async {
    final commerce = _runtime.commerce;
    if (commerce == null) return false;
    await commerce.restore();
    return commerce.errorCode == null;
  }

  @override
  Future<bool> redeem() async {
    final gateway = _runtime.gateway;
    final commerce = _runtime.commerce;
    if (gateway == null || commerce == null) return false;
    await gateway.redeem();
    await commerce.refresh();
    return true;
  }

  @override
  Future<void> refresh() async {
    await _runtime.commerce?.refresh();
  }

  @override
  Widget navigationArtwork(BuildContext context) =>
      const SkinNavigationArtwork();

  @override
  void dispose() {
    _runtime.removeListener(notifyListeners);
    super.dispose();
  }
}

Widget _scene(
  BuildContext context,
  String id,
  SkinArtwork artwork,
  SkinAppearance settings,
  Widget child,
  double topInset,
) {
  final base = Theme.of(context);
  final material = autumnMaterial(id, base.brightness);
  final opacity = 1 - settings.transparency;
  final surfaces = BeeCardTheme.of(context).copyWith(
    canvas: Colors.transparent,
    surface: material.surface.withValues(alpha: opacity),
    soft: material.soft.withValues(alpha: opacity),
    divider: material.line.withValues(alpha: .7),
    surfaceBlur: settings.blur,
  );
  final theme = base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    cardTheme: base.cardTheme.copyWith(color: surfaces.surface),
    colorScheme: base.colorScheme.copyWith(
      primary: material.accent,
      onPrimary: material.onAccent,
      surface: material.surface,
      onSurface: material.ink,
      onSurfaceVariant: material.muted,
    ),
    textTheme: base.textTheme
        .apply(bodyColor: material.ink, displayColor: material.ink),
    iconTheme: base.iconTheme.copyWith(color: material.ink),
    hintColor: material.muted,
    dividerColor: material.line,
    extensions: [
      ...base.extensions.values
          .where((extension) => extension is! BeeCardTheme),
      surfaces,
    ],
  );
  return Theme(
    data: theme,
    child: ColoredBox(
      color: material.canvas,
      child: SkinArtworkHost(
        artwork: artwork,
        display: SkinDisplay(
          sceneStrength: settings.scene,
          motionIntensity: settings.motion,
          motionEnabled: settings.animated,
        ),
        brightness: theme.brightness,
        measureSurfaces: true,
        topInset: topInset,
        child: BeeSurfaceScope(
          wrap: (context, child) {
            final geometry = SkinGeometryScope.of(context);
            return geometry == null
                ? child
                : SkinRegionReporter(
                    geometry: geometry,
                    kind: SkinRegionKind.surface,
                    child: child);
          },
          child: child,
        ),
      ),
    ),
  );
}
