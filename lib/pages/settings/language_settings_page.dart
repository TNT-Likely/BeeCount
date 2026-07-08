import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/language_provider.dart';
import '../../providers/widget_provider.dart';
import '../../widgets/ui/ui.dart';
import '../../l10n/app_localizations.dart';
import '../../styles/tokens.dart';

class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(languageProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
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
                  onTap: () {
                    ref.read(languageProvider.notifier).setLanguage(null);
                    // 延迟更新widget,等待locale变化生效
                    Future.delayed(const Duration(milliseconds: 100), () {
                      updateAppWidget(ref, context);
                    });
                  },
                ),
                const SizedBox(height: 8),

                // 简体中文
                _LanguageOption(
                  title: l10n.languageChinese,
                  locale: const Locale('zh'),
                  currentLanguage: currentLanguage,
                  onTap: () {
                    ref.read(languageProvider.notifier).setLanguage(const Locale('zh'));
                    Future.delayed(const Duration(milliseconds: 100), () {
                      updateAppWidget(ref, context);
                    });
                  },
                ),
                const SizedBox(height: 8),

                // 繁體中文
                _LanguageOption(
                  title: '繁體中文',
                  locale: const Locale('zh', 'TW'),
                  currentLanguage: currentLanguage,
                  onTap: () {
                    ref.read(languageProvider.notifier).setLanguage(const Locale('zh', 'TW'));
                    Future.delayed(const Duration(milliseconds: 100), () {
                      updateAppWidget(ref, context);
                    });
                  },
                ),
                const SizedBox(height: 8),

                // English
                _LanguageOption(
                  title: l10n.languageEnglish,
                  locale: const Locale('en'),
                  currentLanguage: currentLanguage,
                  onTap: () {
                    ref.read(languageProvider.notifier).setLanguage(const Locale('en'));
                    Future.delayed(const Duration(milliseconds: 100), () {
                      updateAppWidget(ref, context);
                    });
                  },
                ),
                const SizedBox(height: 8),

                // 한국어
                _LanguageOption(
                  title: '한국어',
                  locale: const Locale('ko'),
                  currentLanguage: currentLanguage,
                  onTap: () {
                    ref.read(languageProvider.notifier).setLanguage(const Locale('ko'));
                    Future.delayed(const Duration(milliseconds: 100), () {
                      updateAppWidget(ref, context);
                    });
                  },
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

    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: BeeTokens.textPrimary(context),
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onTap: onTap,
    );
  }
}