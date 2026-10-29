import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/theme_providers.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
import 'appearance/bindings/theme_color_options.dart';
import 'appearance/widgets/theme_color_dialog.dart';
import '../../styles/header_skins.dart';
import 'header_skin_page.dart';

// Compatibility with original imports.
final headerStyleProvider = StateProvider<String>((ref) => 'primary');

class PersonalizePage extends ConsumerStatefulWidget {
  const PersonalizePage({super.key});
  @override
  ConsumerState<PersonalizePage> createState() => _PersonalizePageState();
}

class _PersonalizePageState extends ConsumerState<PersonalizePage> {
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void select(Color color, {bool remember = true}) {
    if (headerSkinById(ref.read(headerSkinProvider))?.hasFixedPalette ??
        false) {
      return;
    }
    ref.read(primaryColorProvider.notifier).state = color;
    // Original presets remember user choice; custom confirms write primary only.
    if (remember) ref.read(userChosenPrimaryProvider.notifier).state = color;
  }

  Future<void> custom() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final color = await showDialog<Color>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .26),
        builder: (_) => const ThemeColorDialog());
    if (mounted && color != null) {
      // Persist the same RGB bytes shown by the HSV preview.
      final rgb =
          int.parse(BeeHsvColorPicker.hex(color).substring(1), radix: 16);
      select(Color(0xff000000 | rgb), remember: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        primary = ref.watch(primaryColorProvider),
        skin = headerSkinById(ref.watch(headerSkinProvider));
    final locked = skin?.hasFixedPalette ?? false;
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(title: l.personalizeTitle, leading: const BackButton()),
      Expanded(
          child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(17),
              children: [
            if (locked) ...[
              BeeSurface(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    BeeStatus(
                        label: l.personalizeLockedBySkin(skin!.nameOf(l)),
                        icon: const BeeLineIcon('Lock'),
                        tone: BeeTone.warning),
                    const SizedBox(height: 8),
                    Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) => const HeaderSkinPage())),
                            child: Text(l.personalizeFixedSkinAction))),
                  ])),
              const SizedBox(height: 16),
            ],
            BeeSurface(
                child: BeeColorPalette<String>(
                    items: [
                  for (final option in themeColorOptions(l))
                    BeeColorOption(
                        value: BeeHsvColorPicker.hex(option.color),
                        color: option.color,
                        label: option.label)
                ],
                    value: BeeHsvColorPicker.hex(primary),
                    showLabels: true,
                    onChanged: locked
                        ? null
                        : (hex) => select(themeColorOptions(l)
                            .firstWhere((option) =>
                                BeeHsvColorPicker.hex(option.color) == hex)
                            .color))),
            const SizedBox(height: 16),
            Semantics(
                enabled: !locked,
                child: Opacity(
                    opacity: locked ? .42 : 1,
                    child: BeeSurface(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: BeeMenuRow(
                            title: l.personalizeCustomColor,
                            subtitle: BeeHsvColorPicker.hex(primary),
                            leading: const BeeLineIcon('Palette'),
                            onTap: locked ? null : custom)))),
          ])),
    ]));
  }
}
