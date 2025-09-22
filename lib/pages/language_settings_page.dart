import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/language_provider.dart';
import '../widgets/ui/ui.dart';
import '../l10n/app_localizations.dart';

class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(languageProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.languageTitle,
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 跟随系统
                _LanguageOption(
                  title: l10n.languageSystemDefault,
                  locale: null,
                  currentLanguage: currentLanguage,
                  onTap: () => ref.read(languageProvider.notifier).setLanguage(null),
                ),
                const SizedBox(height: 8),

                // 简体中文
                _LanguageOption(
                  title: l10n.languageChinese,
                  locale: const Locale('zh'),
                  currentLanguage: currentLanguage,
                  onTap: () => ref.read(languageProvider.notifier).setLanguage(const Locale('zh')),
                ),
                const SizedBox(height: 8),

                // 繁體中文
                _LanguageOption(
                  title: '繁體中文',
                  locale: const Locale('zh', 'TW'),
                  currentLanguage: currentLanguage,
                  onTap: () => ref.read(languageProvider.notifier).setLanguage(const Locale('zh', 'TW')),
                ),
                const SizedBox(height: 8),

                // English
                _LanguageOption(
                  title: l10n.languageEnglish,
                  locale: const Locale('en'),
                  currentLanguage: currentLanguage,
                  onTap: () => ref.read(languageProvider.notifier).setLanguage(const Locale('en')),
                ),
                const SizedBox(height: 8),

                // 日本語
                _LanguageOption(
                  title: '日本語',
                  locale: const Locale('ja'),
                  currentLanguage: currentLanguage,
                  onTap: () => ref.read(languageProvider.notifier).setLanguage(const Locale('ja')),
                ),
                const SizedBox(height: 8),

                // 한국어
                _LanguageOption(
                  title: '한국어',
                  locale: const Locale('ko'),
                  currentLanguage: currentLanguage,
                  onTap: () => ref.read(languageProvider.notifier).setLanguage(const Locale('ko')),
                ),
                const SizedBox(height: 8),

                // Español
                _LanguageOption(
                  title: 'Español',
                  locale: const Locale('es'),
                  currentLanguage: currentLanguage,
                  onTap: () => ref.read(languageProvider.notifier).setLanguage(const Locale('es')),
                ),
                const SizedBox(height: 8),

                // Français
                _LanguageOption(
                  title: 'Français',
                  locale: const Locale('fr'),
                  currentLanguage: currentLanguage,
                  onTap: () => ref.read(languageProvider.notifier).setLanguage(const Locale('fr')),
                ),
                const SizedBox(height: 8),

                // Deutsch
                _LanguageOption(
                  title: 'Deutsch',
                  locale: const Locale('de'),
                  currentLanguage: currentLanguage,
                  onTap: () => ref.read(languageProvider.notifier).setLanguage(const Locale('de')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String title;
  final Locale? locale;
  final Locale? currentLanguage;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.title,
    required this.locale,
    required this.currentLanguage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = (locale == null && currentLanguage == null) ||
        (locale != null && currentLanguage != null &&
         locale!.languageCode == currentLanguage!.languageCode &&
         locale!.countryCode == currentLanguage!.countryCode);

    return Card(
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}