import 'dart:io';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/ui_state_providers.dart';
import '../../providers/language_provider.dart';
import '../../providers/database_providers.dart';
import '../../providers/theme_providers.dart';
import '../../providers/font_scale_provider.dart';
import '../../providers/currency_providers.dart';
import '../../services/system/logger_service.dart';
import '../../services/export/config_export_service.dart';
import '../../services/attachment_export_import_service.dart';
import '../../utils/currencies.dart';
import '../../utils/file_picker_helper.dart';
import '../../widgets/biz/bee_icon.dart';
import '../../widgets/currency/currency_picker_sheet.dart';
import '../../widgets/ui/ui.dart';
import '../settings/privacy_policy_page.dart';

part '../../presentation/v4/bindings/welcome_actions.dart';
part '../../presentation/v4/bindings/welcome_content.dart';

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});
  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage>
    with _WelcomeActions, _WelcomeContent {
  final PageController _pageController = PageController();
  @override
  String _selectedCurrency = 'CNY';
  @override
  bool _createDefaultLedger = true;
  @override
  String _categoryMode = 'flat';
  @override
  bool _isInitializing = false, _isImporting = false;
  @override
  bool _completed = false;
  @override
  bool _isExistingUserFlow = false, _isImportingAttachment = false;
  @override
  String? _configFilePath, _configFileName;
  @override
  String? _attachmentFilePath, _attachmentFileName;
  @override
  bool _isRestoreConfigFlow = false;
  bool get _busy =>
      _completed || _isInitializing || _isImporting || _isImportingAttachment;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _go(int page) {
    if (_busy) return;
    _pageController.animateToPage(page,
        duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pages = _isExistingUserFlow
        ? [_attachmentStep(l)]
        : _isRestoreConfigFlow
            ? [_configStep(l)]
            : [
                _languageStep(l),
                _currencyStep(l),
                _categoryStep(l),
                _cloudStep(l),
                _privacyStep(l)
              ];
    return Scaffold(
        backgroundColor: BeeCardTheme.of(context).canvas,
        body: SafeArea(
            child: PageView(
          controller: _pageController,
          physics: _busy || _isExistingUserFlow || _isRestoreConfigFlow
              ? const NeverScrollableScrollPhysics()
              : null,
          children: pages,
        )));
  }

  @override
  Widget _step(
      {required int step,
      required String title,
      required String description,
      required Widget options,
      Widget? footer,
      Widget? helper,
      int total = 5}) {
    final l = AppLocalizations.of(context);
    return BeeOnboardingStep(
      step: step,
      total: total,
      title: title,
      description: description,
      brandTitle: l.appTitle,
      illustration:
          BeeIcon(size: 27, color: Theme.of(context).colorScheme.primary),
      options: options,
      busy: _busy,
      onStep: total == 5 ? _go : null,
      next: footer ??
          Row(children: [
            if (step > 0) ...[
              BeeButton(
                  label: l.commonPrevious,
                  kind: BeeButtonKind.secondary,
                  onPressed: _busy ? null : () => _go(step - 1)),
              const SizedBox(width: 12),
            ],
            Expanded(
                child: SizedBox(
                    height: 48,
                    child: BeeButton(
                      label: step == 4 ? l.commonFinish : l.commonNext,
                      loading: _isInitializing,
                      onPressed: _busy
                          ? null
                          : () => step < 4
                              ? _go(step + 1)
                              : _finishWelcome(context),
                    ))),
          ]),
      restore: helper ??
          SizedBox(
              height: 48,
              child: Center(
                  child: step == 0
                      ? BeeButton(
                          label:
                              '${l.welcomeExistingUserTitle} ${l.welcomeExistingUserButton}',
                          kind: BeeButtonKind.quiet,
                          compact: true,
                          onPressed: _busy
                              ? null
                              : () =>
                                  setState(() => _isRestoreConfigFlow = true))
                      : Text(l.welcomePreferencesLater,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).hintColor)))),
    );
  }
}
