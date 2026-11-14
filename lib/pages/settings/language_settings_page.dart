import 'dart:async';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
import '../../providers/language_provider.dart';
import '../../providers/widget_provider.dart';

class LanguageSettingsPage extends ConsumerStatefulWidget {
  const LanguageSettingsPage({super.key});
  @override
  ConsumerState<LanguageSettingsPage> createState() =>
      _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends ConsumerState<LanguageSettingsPage> {
  bool _saving = false;

  Future<void> _select(Locale? locale) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(languageProvider.notifier).setLanguage(locale);
      // Keep the original delayed widget refresh so it sees the new locale.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (mounted) unawaited(updateAppWidget(ref, context));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        selected = ref.watch(languageProvider);
    final notifier = ref.read(languageProvider.notifier);
    const options = [
      (locale: null, detail: 'System default'),
      (locale: Locale('zh'), detail: 'Chinese · Simplified'),
      (locale: Locale('zh', 'TW'), detail: 'Chinese · Traditional'),
      (locale: Locale('en'), detail: 'English'),
      (locale: Locale('ko'), detail: 'Korean'),
    ];
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(title: l.languageTitle, leading: const BackButton()),
      Expanded(
          child: ListView(padding: const EdgeInsets.all(17), children: [
        BeeSurface(
            padding: const EdgeInsets.all(7),
            child: Column(children: [
              for (final option in options)
                BeeOnboardingChoice(
                  title:
                      notifier.getLanguageDisplayName(context, option.locale),
                  subtitle: option.detail,
                  selected: selected == option.locale,
                  onTap: _saving ? null : () => _select(option.locale),
                ),
            ])),
      ])),
    ]));
  }
}
