import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../../styles/tokens.dart';
import '../../utils/currencies.dart';
import '../../widgets/currency/currency_picker_sheet.dart';
import './personalize_page.dart';
import './font_settings_page.dart';
import './language_settings_page.dart';
import './widget_management_page.dart';
import './app_lock_settings_page.dart';
import './header_skin_page.dart';
import '../../styles/header_skins.dart';
import '../../l10n/app_localizations.dart';
import '../currency/exchange_rate_page.dart';

/// 外观设置二级页面
class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(languageProvider);
    final themeMode = ref.watch(themeModeProvider);
    final l10n = AppLocalizations.of(context);

    String languageDisplay;
    if (currentLanguage == null) {
      languageDisplay = l10n.languageSystemDefault;
    } else {
      switch (currentLanguage.languageCode) {
        case 'zh':
          languageDisplay = l10n.languageChinese;
          break;
        case 'en':
          languageDisplay = l10n.languageEnglish;
          break;
        default:
          languageDisplay = currentLanguage.languageCode;
      }
    }

    // 主题模式显示文本
    String themeModeDisplay;
    switch (themeMode) {
      case ThemeMode.light:
        themeModeDisplay = l10n.appearanceThemeModeLight;
        break;
      case ThemeMode.dark:
        themeModeDisplay = l10n.appearanceThemeModeDark;
        break;
      default:
        themeModeDisplay = l10n.appearanceThemeModeSystem;
    }

    // 头部皮肤显示名
    final headerSkin = ref.watch(headerSkinProvider);
    final skinDisplay = headerSkin == kHeaderSkinNone
        ? l10n.headerSkinNone
        : (headerSkinById(headerSkin)?.nameOf(l10n) ?? l10n.headerSkinNone);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.appearanceSettingsPageTitle,
            subtitle: l10n.appearanceSettingsPageSubtitle,
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 纯样式:外观模式 / 主题色 / 皮肤 / 显示缩放
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // 外观模式
                      AppListTile(
                        leading: Icons.brightness_6_outlined,
                        title: l10n.appearanceThemeMode,
                        subtitle: themeModeDisplay,
                        onTap: () => _showThemeModeDialog(context, ref, l10n),
                      ),
                      BeeTokens.cardDivider(context),
                      // 主题色设置
                      AppListTile(
                        leading: Icons.brush_outlined,
                        title: l10n.personalizeTitle,
                        subtitle: l10n.personalizeSubtitle,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PersonalizePage()),
                          );
                        },
                      ),
                      BeeTokens.cardDivider(context),
                      // 皮肤
                      AppListTile(
                        leading: Icons.wallpaper_outlined,
                        title: l10n.headerSkinTitle,
                        subtitle: skinDisplay,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const HeaderSkinPage()),
                          );
                        },
                      ),
                      BeeTokens.cardDivider(context),
                      // 显示缩放
                      AppListTile(
                        leading: Icons.zoom_out_map_outlined,
                        title: l10n.mineDisplayScale,
                        subtitle: l10n.mineDisplayScaleSubtitle,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const FontSettingsPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 功能:金额格式 / 交易时间 / 收支配色(影响数据呈现,非纯外观)
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // 金额显示格式
                      AppListTile(
                        leading: Icons.money_outlined,
                        title: l10n.appearanceAmountFormat,
                        subtitle: ref.watch(compactAmountProvider)
                            ? l10n.appearanceAmountFormatCompact
                            : l10n.appearanceAmountFormatFull,
                        onTap: () => _showAmountFormatDialog(context, ref, l10n),
                      ),
                      BeeTokens.cardDivider(context),
                      // 显示交易时间
                      AppListTile(
                        leading: Icons.schedule_outlined,
                        title: l10n.appearanceShowTransactionTime,
                        subtitle: l10n.appearanceShowTransactionTimeDesc,
                        trailing: Switch.adaptive(
                          value: ref.watch(showTransactionTimeProvider),
                          onChanged: (value) {
                            ref.read(showTransactionTimeProvider.notifier).state = value;
                          },
                          activeColor: ref.watch(primaryColorProvider),
                        ),
                        onTap: () {
                          final current = ref.read(showTransactionTimeProvider);
                          ref.read(showTransactionTimeProvider.notifier).state = !current;
                        },
                      ),
                      BeeTokens.cardDivider(context),
                      // 备注显示方式
                      AppListTile(
                        leading: Icons.notes_outlined,
                        title: l10n.appearanceNoteDisplay,
                        subtitle: ref.watch(noteDisplayModeProvider) == 'note'
                            ? l10n.appearanceNoteDisplayNote
                            : l10n.appearanceNoteDisplayCategory,
                        onTap: () => _showNoteDisplayDialog(context, ref, l10n),
                      ),
                      BeeTokens.cardDivider(context),
                      // 收支颜色方案
                      AppListTile(
                        leading: Icons.palette_outlined,
                        title: l10n.appearanceColorScheme,
                        subtitle: ref.watch(incomeExpenseColorSchemeProvider)
                            ? l10n.appearanceColorSchemeOn
                            : l10n.appearanceColorSchemeOff,
                        onTap: () => _showColorSchemeDialog(context, ref, l10n),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 多币种:主币种 / 汇率管理
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // 主币种
                      AppListTile(
                        leading: Icons.payments_outlined,
                        title: l10n.baseCurrencyLabel,
                        subtitle: displayCurrency(
                            ref.watch(baseCurrencyProvider).toUpperCase(),
                            context),
                        onTap: () => _pickBaseCurrency(context, ref),
                      ),
                      BeeTokens.cardDivider(context),
                      // 汇率管理
                      AppListTile(
                        leading: Icons.currency_exchange,
                        title: l10n.exchangeRatePageTitle,
                        subtitle: l10n.exchangeRateEntrySubtitle,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ExchangeRatePage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 通用:语言 / 桌面小组件 / 应用锁
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // 语言设置
                      AppListTile(
                        leading: Icons.language_outlined,
                        title: l10n.mineLanguageSettings,
                        subtitle: languageDisplay,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LanguageSettingsPage()),
                          );
                        },
                      ),
                      BeeTokens.cardDivider(context),
                      // 桌面小组件
                      AppListTile(
                        leading: Icons.widgets_outlined,
                        title: l10n.widgetManagement,
                        subtitle: l10n.widgetManagementDesc,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const WidgetManagementPage()),
                          );
                        },
                      ),
                      BeeTokens.cardDivider(context),
                      // 应用锁
                      AppListTile(
                        leading: Icons.lock_outline,
                        title: l10n.appLockTitle,
                        subtitle: l10n.appLockDesc,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AppLockSettingsPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 主币种选择 —— 弹 sheet 选完后应用
  Future<void> _pickBaseCurrency(BuildContext context, WidgetRef ref) async {
    final current = ref.read(baseCurrencyProvider).toUpperCase();
    final primary = ref.read(primaryColorProvider);
    final picked = await showCurrencyPickerSheet(
      context,
      selected: current,
      primaryColor: primary,
    );
    if (picked == null || !context.mounted) return;
    await applyBaseCurrencySelection(context, ref, picked);
  }

  /// 显示主题模式选择对话框
  void _showThemeModeDialog(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final currentMode = ref.read(themeModeProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BeeTokens.surfaceElevated(context),
        title: Text(
          l10n.appearanceThemeMode,
          style: TextStyle(color: BeeTokens.textPrimary(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModeOption(
              context, ref,
              title: l10n.appearanceThemeModeSystem,
              value: ThemeMode.system,
              currentValue: currentMode,
              icon: Icons.settings_suggest_outlined,
            ),
            _buildModeOption(
              context, ref,
              title: l10n.appearanceThemeModeLight,
              value: ThemeMode.light,
              currentValue: currentMode,
              icon: Icons.light_mode_outlined,
            ),
            _buildModeOption(
              context, ref,
              title: l10n.appearanceThemeModeDark,
              value: ThemeMode.dark,
              currentValue: currentMode,
              icon: Icons.dark_mode_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required ThemeMode value,
    required ThemeMode currentValue,
    required IconData icon,
  }) {
    final isSelected = value == currentValue;
    final primaryColor = ref.watch(primaryColorProvider);

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? primaryColor : BeeTokens.iconSecondary(context),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? primaryColor : BeeTokens.textPrimary(context),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: primaryColor)
          : null,
      onTap: () {
        ref.read(themeModeProvider.notifier).state = value;
        Navigator.pop(context);
      },
    );
  }

  /// 显示金额显示格式选择对话框
  void _showAmountFormatDialog(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final isCompact = ref.read(compactAmountProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BeeTokens.surfaceElevated(context),
        title: Text(
          l10n.appearanceAmountFormat,
          style: TextStyle(color: BeeTokens.textPrimary(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAmountFormatOption(
              context, ref,
              title: l10n.appearanceAmountFormatFull,
              subtitle: l10n.appearanceAmountFormatFullDesc,
              value: false,
              currentValue: isCompact,
              icon: Icons.format_list_numbered_outlined,
            ),
            _buildAmountFormatOption(
              context, ref,
              title: l10n.appearanceAmountFormatCompact,
              subtitle: l10n.appearanceAmountFormatCompactDesc,
              value: true,
              currentValue: isCompact,
              icon: Icons.compress_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountFormatOption(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String subtitle,
    required bool value,
    required bool currentValue,
    required IconData icon,
  }) {
    final isSelected = value == currentValue;
    final primaryColor = ref.watch(primaryColorProvider);

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? primaryColor : BeeTokens.iconSecondary(context),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? primaryColor : BeeTokens.textPrimary(context),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: BeeTokens.textSecondary(context),
          fontSize: 12,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: primaryColor)
          : null,
      onTap: () {
        ref.read(compactAmountProvider.notifier).state = value;
        Navigator.pop(context);
      },
    );
  }

  /// 显示备注显示方式选择对话框
  void _showNoteDisplayDialog(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final current = ref.read(noteDisplayModeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BeeTokens.surfaceElevated(context),
        title: Text(
          l10n.appearanceNoteDisplay,
          style: TextStyle(color: BeeTokens.textPrimary(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNoteDisplayOption(
              context, ref,
              title: l10n.appearanceNoteDisplayCategory,
              subtitle: l10n.appearanceNoteDisplayCategoryDesc,
              value: 'category',
              currentValue: current,
              icon: Icons.label_outline,
            ),
            _buildNoteDisplayOption(
              context, ref,
              title: l10n.appearanceNoteDisplayNote,
              subtitle: l10n.appearanceNoteDisplayNoteDesc,
              value: 'note',
              currentValue: current,
              icon: Icons.notes_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteDisplayOption(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String subtitle,
    required String value,
    required String currentValue,
    required IconData icon,
  }) {
    final isSelected = value == currentValue;
    final primaryColor = ref.watch(primaryColorProvider);
    return ListTile(
      leading: Icon(icon, color: isSelected ? primaryColor : BeeTokens.iconSecondary(context)),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? primaryColor : BeeTokens.textPrimary(context),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: BeeTokens.textSecondary(context), fontSize: 12),
      ),
      trailing: isSelected ? Icon(Icons.check, color: primaryColor) : null,
      onTap: () {
        ref.read(noteDisplayModeProvider.notifier).state = value;
        Navigator.pop(context);
      },
    );
  }

  /// 显示收支颜色方案选择对话框
  void _showColorSchemeDialog(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final currentScheme = ref.read(incomeExpenseColorSchemeProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BeeTokens.surfaceElevated(context),
        title: Text(
          l10n.appearanceColorScheme,
          style: TextStyle(color: BeeTokens.textPrimary(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildColorSchemeOption(
              context, ref,
              title: l10n.appearanceColorSchemeOn,
              subtitle: l10n.appearanceColorSchemeOnDesc,
              value: true,
              currentValue: currentScheme,
              icon: Icons.trending_up,
            ),
            _buildColorSchemeOption(
              context, ref,
              title: l10n.appearanceColorSchemeOff,
              subtitle: l10n.appearanceColorSchemeOffDesc,
              value: false,
              currentValue: currentScheme,
              icon: Icons.trending_down,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSchemeOption(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String subtitle,
    required bool value,
    required bool currentValue,
    required IconData icon,
  }) {
    final isSelected = value == currentValue;
    final primaryColor = ref.watch(primaryColorProvider);

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? primaryColor : BeeTokens.iconSecondary(context),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? primaryColor : BeeTokens.textPrimary(context),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: BeeTokens.textSecondary(context),
          fontSize: 12,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: primaryColor)
          : null,
      onTap: () {
        ref.read(incomeExpenseColorSchemeProvider.notifier).state = value;
        Navigator.pop(context);
      },
    );
  }
}
