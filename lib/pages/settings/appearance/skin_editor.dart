import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/theme_providers.dart';
import '../../../skins/premium_skins.dart';
import '../../../styles/header_skins.dart';
import 'bindings/skin_choices.dart';
import 'skin_store_actions.dart';

String activeSkinId(String freeId, PremiumSkins runtime) =>
    runtime.selectedSkin?.id ?? headerSkinById(freeId)?.id ?? kHeaderSkinNone;

String skinAdjustmentTitle(BuildContext context) =>
    skinText(context, '皮肤调节', 'Skin settings');

Future<void> showSkinEditor(BuildContext context, String id,
    {required bool editingActive}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    backgroundColor: BeeCardTheme.of(context).overlay,
    constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9, maxWidth: 560),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
    builder: (_) => SkinEditor(skinId: id, editingActive: editingActive),
  );
}

class SkinEditor extends ConsumerStatefulWidget {
  const SkinEditor({
    super.key,
    required this.skinId,
    required this.editingActive,
  });

  final String skinId;
  final bool editingActive;

  @override
  ConsumerState<SkinEditor> createState() => _SkinEditorState();
}

enum _SkinSection { material, artwork }

class _SkinEditorState extends ConsumerState<SkinEditor> {
  late final paid = ref.read(premiumSkinsProvider).skin(widget.skinId);
  late final free = headerSkinById(widget.skinId);
  late var _draft = paid != null
      ? ref.read(premiumSkinsProvider).appearanceFor(widget.skinId)
      : SkinAppearance(
          skinId: widget.skinId,
          transparency: 1 -
              BeePageMaterial.normalizeOpacity(
                  ref.read(skinCardOpacityProvider)),
          blur: BeePageMaterial.normalizeBlur(ref.read(skinCardBlurProvider)),
          animated: ref.read(skinAnimationEnabledProvider),
        );
  var _section = _SkinSection.material;
  Brightness? _tone;
  bool _working = false;
  String? _message;

  void _update({
    double? transparency,
    double? blur,
    double? scene,
    double? motion,
    bool? animated,
  }) {
    setState(() => _draft = SkinAppearance(
          skinId: widget.skinId,
          transparency: transparency ?? _draft.transparency,
          blur: blur ?? _draft.blur,
          scene: scene ?? _draft.scene,
          motion: motion ?? _draft.motion,
          animated: animated ?? _draft.animated,
        ));
  }

  void _reset() {
    setState(() => _draft = paid != null
        ? SkinAppearance(skinId: widget.skinId)
        : SkinAppearance(
            skinId: widget.skinId,
            transparency: 1 - BeePageMaterial.defaultOpacity,
            blur: BeePageMaterial.defaultBlur,
            animated: free?.isAnimated == true ? true : _draft.animated));
  }

  bool _canEdit(PremiumSkins runtime, String current) {
    if (widget.editingActive && current != widget.skinId) return false;
    if (paid != null) return runtime.owned;
    return widget.skinId == kHeaderSkinNone || free != null;
  }

  Future<void> _save(PremiumSkins runtime) async {
    final current = activeSkinId(ref.read(headerSkinProvider), runtime);
    if (_working ||
        !ref.read(headerSkinsEnabledProvider) ||
        !_canEdit(runtime, current)) {
      return;
    }
    setState(() {
      _working = true;
      _message = null;
    });
    bool saved;
    try {
      if (paid != null) {
        saved = await runtime.select(widget.skinId, _draft);
      } else {
        if (!widget.editingActive) {
          await runtime.clearSelection();
          if (!mounted) return;
          applyHeaderSkin(ref, widget.skinId);
        }
        ref.read(skinCardOpacityProvider.notifier).state =
            1 - _draft.transparency;
        ref.read(skinCardBlurProvider.notifier).state = _draft.blur;
        if (free?.isAnimated == true) {
          ref.read(skinAnimationEnabledProvider.notifier).state =
              _draft.animated;
        }
        await saveSkinCardMaterial(ref);
        saved = true;
      }
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _working = false;
        _message = skinText(context, '暂时无法保存皮肤，请稍后重试。',
            'Unable to save the skin. Try again later.');
      });
    }
  }

  Future<void> _buy(PremiumSkins runtime) async {
    if (_working ||
        !ref.read(headerSkinsEnabledProvider) ||
        !canBuySkinPack(runtime)) {
      return;
    }
    setState(() {
      _working = true;
      _message = null;
    });
    var result = SkinPurchaseResult.unavailable;
    try {
      result = await runtime.purchase();
    } catch (_) {
      // Show the retry message and re-enable the controls.
    }
    if (!mounted) return;
    setState(() {
      _working = false;
      _message = skinPurchaseFeedback(context, result, runtime.owned);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final runtime = ref.watch(premiumSkinsProvider);
    final freeId = ref.watch(headerSkinProvider);
    final enabled = ref.watch(headerSkinsEnabledProvider);
    final current = activeSkinId(freeId, runtime);
    final locked = paid != null && !runtime.owned;
    final base = Theme.of(context);
    final skin = paid;
    final palette = skin?.colors(base.brightness);
    final name = skin == null
        ? free?.nameOf(l) ?? l.headerSkinNone
        : premiumSkinName(context, skin);
    final details = widget.editingActive
        ? skinText(context, '当前皮肤设置', 'Current skin settings')
        : skinText(context, '皮肤试穿', 'Skin preview');
    final accent = palette == null
        ? base.colorScheme
        : base.colorScheme
            .copyWith(primary: palette.accent, onPrimary: palette.onAccent);

    return PopScope(
      canPop: !_working,
      child: Theme(
        data: base.copyWith(colorScheme: accent),
        child: BeeSheet(
          title: name,
          onClose: _working ? () {} : null,
          footer: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(_message!,
                        key: const ValueKey('official-purchase-message')),
                  ),
                ),
              Row(children: [
                TextButton(
                  onPressed: _working ? null : _reset,
                  child: Text(skinText(context, '恢复默认', 'Reset')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: ValueKey(
                        locked ? 'official-buy-pack' : 'official-apply'),
                    onPressed: !enabled || _working
                        ? null
                        : locked
                            ? canBuySkinPack(runtime)
                                ? () => _buy(runtime)
                                : null
                            : _canEdit(runtime, current)
                                ? () => _save(runtime)
                                : null,
                    child: Text(locked
                        ? skinPurchaseLabel(context, runtime)
                        : widget.editingActive
                            ? skinText(context, '保存设置', 'Save settings')
                            : skinText(context, '应用皮肤', 'Apply skin')),
                  ),
                ),
              ]),
              if (locked)
                Row(children: [
                  Expanded(
                    child: Text(skinText(context, '一次购买', 'One-time purchase'),
                        style: base.textTheme.bodySmall),
                  ),
                  const SkinStoreActions(fromPreview: true),
                ]),
            ],
          ),
          child: SingleChildScrollView(
            key: const ValueKey('skin-editor-scroll'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(details, style: base.textTheme.bodySmall),
                const SizedBox(height: 8),
                SizedBox(
                  height: (MediaQuery.sizeOf(context).height * .29)
                      .clamp(145.0, 248.0),
                  child: _sample(context, _tone ?? base.brightness, freeId),
                ),
                const SizedBox(height: 12),
                _controls(context, l),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sample(BuildContext context, Brightness brightness, String freeId) {
    final theme =
        brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
    final ledger = Builder(builder: (sampleContext) {
      final text = Theme.of(sampleContext).textTheme;
      return Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(builder: (context, bounds) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: bounds.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(skinText(context, '账本预览', 'Ledger preview'),
                          style: text.titleSmall),
                    ),
                    SizedBox(
                      width: 124,
                      child: BeeSegmented<Brightness>(
                        dense: true,
                        value: brightness,
                        items: [
                          BeeSegment(Brightness.light,
                              skinText(context, '浅色', 'Light')),
                          BeeSegment(
                              Brightness.dark, skinText(context, '深色', 'Dark')),
                        ],
                        onChanged: (tone) => setState(() => _tone = tone),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Column(children: [
                    _ledgerLine(skinText(context, '本月支出', 'Monthly spending'),
                        '¥ 1,286.50', text.titleLarge ?? const TextStyle()),
                    const SizedBox(height: 5),
                    _ledgerLine(skinText(context, '午餐', 'Lunch'), '¥ 28.00',
                        text.bodyMedium ?? const TextStyle()),
                  ]),
                ],
              ),
            ),
          );
        }),
      );
    });
    final skin = paid;
    if (skin != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Theme(
          data: theme,
          child: Builder(
              builder: (context) => skin.scene(context, _draft, ledger, 0)),
        ),
      );
    }
    final primary = boundPrimaryOf(freeId) == null
        ? ref.watch(primaryColorProvider)
        : ref.watch(userChosenPrimaryProvider);
    return ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: Theme(
        data: BeePageMaterial.theme(theme,
            opacity: 1 - _draft.transparency, blur: _draft.blur),
        child: Stack(fit: StackFit.expand, children: [
          Builder(builder: (context) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                  disableAnimations:
                      media.disableAnimations || !_draft.animated),
              child: skinChoice(context, id: widget.skinId, primary: primary)
                  .preview,
            );
          }),
          ledger,
        ]),
      ),
    );
  }

  Widget _ledgerLine(String label, String amount, TextStyle style) =>
      BeeSurface(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        borderRadius: BorderRadius.circular(10),
        child: Row(children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Flexible(
            fit: FlexFit.tight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(amount,
                  style: style.copyWith(fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      );

  Widget _controls(BuildContext context, AppLocalizations l) {
    final isPaid = paid != null;
    final hasMotion = isPaid || free?.isAnimated == true;
    final material = skinText(context, '卡片材质', 'Card material');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasMotion)
          BeeSegmented<_SkinSection>(
            dense: true,
            value: _section,
            items: [
              BeeSegment(_SkinSection.material, material),
              BeeSegment(
                  _SkinSection.artwork,
                  isPaid
                      ? skinText(context, '景物与动效', 'Scenery and motion')
                      : skinText(context, '动效', 'Motion')),
            ],
            onChanged: (value) => setState(() => _section = value),
          )
        else
          Text(material, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        if (_section == _SkinSection.material) ...[
          BeeSliderField(
            label: l.appearanceCardTransparency,
            value: _draft.transparency,
            max: isPaid
                ? SkinAppearance.maxTransparency
                : 1 - BeePageMaterial.minOpacity,
            valueLabel: _percent(_draft.transparency),
            onChanged: (value) => _update(transparency: value),
          ),
          BeeSliderField(
            label: l.appearanceCardBlur,
            value: _draft.blur,
            max: isPaid ? SkinAppearance.maxBlur : BeePageMaterial.maxBlur,
            valueLabel: _draft.blur.round() == 0
                ? l.appearanceCardBlurOff
                : '${_draft.blur.round()}',
            onChanged: (value) => _update(blur: value),
          ),
        ] else ...[
          if (isPaid)
            BeeSliderField(
              label: skinText(context, '景物浓度', 'Scenery intensity'),
              value: _draft.scene,
              valueLabel: _percent(_draft.scene),
              onChanged: (value) => _update(scene: value),
            ),
          BeeToggleRow(
            title: l.appearanceSkinAnimation,
            value: _draft.animated,
            onChanged: (value) => _update(animated: value),
          ),
          if (isPaid)
            BeeSliderField(
              label: skinText(context, '动态强度', 'Motion intensity'),
              value: _draft.motion,
              valueLabel: _percent(_draft.motion),
              onChanged:
                  _draft.animated ? (value) => _update(motion: value) : null,
            ),
        ],
      ],
    );
  }

  String _percent(double value) => '${(value * 100).round()}%';
}
