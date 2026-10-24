import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../providers/feature_highlight_providers.dart';
import '../../presentation/v4/bindings/appearance_dialogs.dart';
import '../../presentation/v4/bindings/page_scaffold.dart';
import '../../styles/header_skins.dart';
import '../../utils/currencies.dart';
import '../../widgets/currency/currency_picker_sheet.dart';
import '../../widgets/ui/feature_dot.dart';
import '../currency/exchange_rate_page.dart';
import 'app_lock_settings_page.dart';
import 'font_settings_page.dart';
import 'header_skin_page.dart';
import 'language_settings_page.dart';
import 'personalize_page.dart';
import 'widget_management_page.dart';

/// Original preference providers and routes; only presentation is replaced.
class AppearanceSettingsPage extends ConsumerStatefulWidget {
  const AppearanceSettingsPage({super.key});
  @override
  ConsumerState<AppearanceSettingsPage> createState() =>
      _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState
    extends ConsumerState<AppearanceSettingsPage> {
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) markAnchorVisited(ref, 'personalize');
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        language = ref.watch(languageProvider),
        mode = ref.watch(themeModeProvider),
        skinId = ref.watch(headerSkinProvider);
    final modeNames = [
      l.appearanceThemeModeSystem,
      l.appearanceThemeModeLight,
      l.appearanceThemeModeDark
    ];
    final languageName = language == null
        ? l.languageSystemDefault
        : switch (language.languageCode) {
            'zh' => l.languageChinese,
            'en' => l.languageEnglish,
            'ko' => '한국어',
            _ => language.languageCode,
          };
    void open(Widget page) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    Widget entry(
            String icon, String title, String subtitle, VoidCallback action,
            {bool dot = false}) =>
        BeeMenuRow(
            title: title,
            subtitle: subtitle,
            leading: dot
                ? FeatureDot(anchor: 'header_skin', child: BeeLineIcon(icon))
                : BeeLineIcon(icon),
            onTap: action);
    Widget group(List<Widget> rows) => BeeSurface(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const BeeDivider(inset: 12),
            rows[i]
          ]
        ]));
    Future<void> choose<T>(
        String title,
        T selected,
        List<({T value, String title, String? subtitle, String icon})> options,
        ValueChanged<T> save) async {
      final value = await showAppearanceChoice<T>(context,
          title: title, selected: selected, options: options);
      if (mounted && value != null) save(value);
    }

    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.appearanceSettingsPageTitle, leading: const BackButton()),
      Expanded(
          child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(17),
              children: [
            Text(l.appearanceSettingsPageSubtitle,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).hintColor)),
            const SizedBox(height: 12),
            group([
              entry(
                  'SunMoon',
                  l.appearanceThemeMode,
                  modeNames[mode.index],
                  () => choose(
                      l.appearanceThemeMode,
                      mode,
                      [
                        for (final value in ThemeMode.values)
                          (
                            value: value,
                            title: modeNames[value.index],
                            subtitle: null,
                            icon: ['Settings2', 'Sun', 'Moon'][value.index]
                          )
                      ],
                      (v) => ref.read(themeModeProvider.notifier).state = v)),
              entry('Palette', l.personalizeTitle, l.personalizeSubtitle,
                  () => open(const PersonalizePage())),
              entry(
                  'Image',
                  l.headerSkinTitle,
                  skinId == kHeaderSkinNone
                      ? l.headerSkinNone
                      : headerSkinById(skinId)?.nameOf(l) ?? l.headerSkinNone,
                  () => open(const HeaderSkinPage()),
                  dot: true),
              BeeToggleRow(
                  title: l.appearanceSkinAnimation,
                  leading: const BeeLineIcon('Sparkles'),
                  subtitle: l.appearanceSkinAnimationDesc,
                  value: ref.watch(skinAnimationEnabledProvider),
                  onChanged: (v) => ref
                      .read(skinAnimationEnabledProvider.notifier)
                      .state = v),
              entry('Maximize', l.mineDisplayScale, l.mineDisplayScaleSubtitle,
                  () => open(const FontSettingsPage())),
            ]),
            const SizedBox(height: 16),
            group([
              entry(
                  'Banknote',
                  l.appearanceAmountFormat,
                  ref.watch(compactAmountProvider)
                      ? l.appearanceAmountFormatCompact
                      : l.appearanceAmountFormatFull,
                  () => choose(
                      l.appearanceAmountFormat,
                      ref.read(compactAmountProvider),
                      [
                        (
                          value: false,
                          title: l.appearanceAmountFormatFull,
                          subtitle: l.appearanceAmountFormatFullDesc,
                          icon: 'List'
                        ),
                        (
                          value: true,
                          title: l.appearanceAmountFormatCompact,
                          subtitle: l.appearanceAmountFormatCompactDesc,
                          icon: 'Minimize'
                        )
                      ],
                      (v) =>
                          ref.read(compactAmountProvider.notifier).state = v)),
              BeeToggleRow(
                  title: l.appearanceShowTransactionTime,
                  leading: const BeeLineIcon('Clock'),
                  subtitle: l.appearanceShowTransactionTimeDesc,
                  value: ref.watch(showTransactionTimeProvider),
                  onChanged: (v) =>
                      ref.read(showTransactionTimeProvider.notifier).state = v),
              entry(
                  'PencilLine',
                  l.appearanceNoteDisplay,
                  ref.watch(noteDisplayModeProvider) == 'note'
                      ? l.appearanceNoteDisplayNote
                      : l.appearanceNoteDisplayCategory,
                  () => choose(
                      l.appearanceNoteDisplay,
                      ref.read(noteDisplayModeProvider),
                      [
                        (
                          value: 'category',
                          title: l.appearanceNoteDisplayCategory,
                          subtitle: l.appearanceNoteDisplayCategoryDesc,
                          icon: 'Tag'
                        ),
                        (
                          value: 'note',
                          title: l.appearanceNoteDisplayNote,
                          subtitle: l.appearanceNoteDisplayNoteDesc,
                          icon: 'PencilLine'
                        )
                      ],
                      (v) => ref.read(noteDisplayModeProvider.notifier).state =
                          v)),
              entry(
                  'History',
                  l.appearanceNoteHistory,
                  noteHistorySummary(ref, l),
                  () => showNoteHistoryPreferences(context)),
              entry(
                  'Palette',
                  l.appearanceColorScheme,
                  ref.watch(incomeExpenseColorSchemeProvider)
                      ? l.appearanceColorSchemeOn
                      : l.appearanceColorSchemeOff,
                  () => choose(
                      l.appearanceColorScheme,
                      ref.read(incomeExpenseColorSchemeProvider),
                      [
                        (
                          value: true,
                          title: l.appearanceColorSchemeOn,
                          subtitle: l.appearanceColorSchemeOnDesc,
                          icon: 'TrendingUp'
                        ),
                        (
                          value: false,
                          title: l.appearanceColorSchemeOff,
                          subtitle: l.appearanceColorSchemeOffDesc,
                          icon: 'TrendingDown'
                        )
                      ],
                      (v) => ref
                          .read(incomeExpenseColorSchemeProvider.notifier)
                          .state = v)),
            ]),
            const SizedBox(height: 16),
            group([
              entry(
                  'Coins',
                  l.baseCurrencyLabel,
                  displayCurrency(
                      ref.watch(baseCurrencyProvider).toUpperCase(), context),
                  _pickCurrency),
              entry(
                  'ArrowLeftRight',
                  l.exchangeRatePageTitle,
                  l.exchangeRateEntrySubtitle,
                  () => open(const ExchangeRatePage())),
            ]),
            const SizedBox(height: 16),
            group([
              entry('Languages', l.mineLanguageSettings, languageName,
                  () => open(const LanguageSettingsPage())),
              entry('Grid2x2', l.widgetManagement, l.widgetManagementDesc,
                  () => open(const WidgetManagementPage())),
              entry('Lock', l.appLockTitle, l.appLockDesc,
                  () => open(const AppLockSettingsPage())),
            ]),
          ])),
    ]));
  }

  Future<void> _pickCurrency() async {
    final selected = await showCurrencyPickerSheet(context,
        selected: ref.read(baseCurrencyProvider).toUpperCase(),
        primaryColor: ref.read(primaryColorProvider));
    if (selected != null && mounted) {
      await applyBaseCurrencySelection(context, ref, selected);
    }
  }
}
