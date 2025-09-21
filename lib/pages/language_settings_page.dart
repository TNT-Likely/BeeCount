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

                // 中文
                _LanguageOption(
                  title: l10n.languageChinese,
                  locale: const Locale('zh'),
                  currentLanguage: currentLanguage,
                  onTap: () => ref.read(languageProvider.notifier).setLanguage(const Locale('zh')),
                ),
                const SizedBox(height: 8),

                // English
                _LanguageOption(
                  title: l10n.languageEnglish,
                  locale: const Locale('en'),
                  currentLanguage: currentLanguage,
                  onTap: () => ref.read(languageProvider.notifier).setLanguage(const Locale('en')),
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
        (locale != null && currentLanguage != null && locale!.languageCode == currentLanguage!.languageCode);

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