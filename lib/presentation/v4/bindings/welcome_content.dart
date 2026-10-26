part of '../../../pages/auth/welcome_page.dart';

mixin _WelcomeContent on ConsumerState<WelcomePage>, _WelcomeActions {
  set _isRestoreConfigFlow(bool value);
  Widget _step(
      {required int step,
      required String title,
      required String description,
      required Widget options,
      Widget? footer,
      Widget? helper,
      int total = 5});

  Widget _languageStep(AppLocalizations l) {
    final notifier = ref.read(languageProvider.notifier);
    final selected = ref.watch(languageProvider);
    const locales = [
      null,
      Locale('zh'),
      Locale('zh', 'TW'),
      Locale('en'),
      Locale('ko')
    ];
    const details = [
      'System default',
      'Chinese · Simplified',
      'Chinese · Traditional',
      'English',
      'Korean'
    ];
    return _step(
        step: 0,
        title: l.welcomeTitle,
        description: l.welcomeDescription,
        options:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text('${l.commonLanguage} · Language',
                  style: const TextStyle(fontSize: 12))),
          BeeSurface(
              padding: const EdgeInsets.all(7),
              child: Column(children: [
                for (var i = 0; i < locales.length; i++)
                  BeeOnboardingChoice(
                      title:
                          notifier.getLanguageDisplayName(context, locales[i]),
                      subtitle: details[i],
                      selected: selected == locales[i],
                      onTap: () => notifier.setLanguage(locales[i])),
              ])),
        ]));
  }

  Widget _currencyStep(AppLocalizations l) {
    final common = ['CNY', 'USD', 'EUR', 'HKD', 'JPY', 'KRW'];
    if (!common.contains(_selectedCurrency)) common[5] = _selectedCurrency;
    final all = getCurrencies(context);
    Widget choice(String code) {
      final currency = all.firstWhere((c) => c.code == code);
      final symbol = getCurrencySymbol(code);
      return BeeOnboardingChoice(
          title: currency.name,
          subtitle: code,
          selected: _selectedCurrency == code,
          minHeight: 73,
          compact: true,
          showUnselectedCheck: false,
          leading: Text(symbol,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: symbol.length > 1 ? 14 : 20)),
          onTap: () => setState(() => _selectedCurrency = code));
    }

    return _step(
        step: 1,
        title: l.ledgersCurrency,
        description: l.welcomeCurrencyDescription,
        options:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BeeSurface(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Column(children: [
                for (var i = 0; i < 3; i++) ...[
                  IntrinsicHeight(
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        Expanded(child: choice(common[i * 2])),
                        const SizedBox(width: 6),
                        Expanded(child: choice(common[i * 2 + 1])),
                      ])),
                  if (i < 2) const SizedBox(height: 6),
                ],
                const SizedBox(height: 6),
                const Divider(height: 1),
                BeeMenuRow(
                    title: l.ledgersSelectCurrency,
                    leading: const BeeLineIcon('Globe', size: 16),
                    onTap: () async {
                      final code = await showCurrencyPickerSheet(context,
                          selected: _selectedCurrency,
                          primaryColor: Theme.of(context).colorScheme.primary);
                      if (code != null && mounted) {
                        setState(() => _selectedCurrency = code);
                      }
                    }),
              ])),
          const SizedBox(height: 12),
          BeeSurface(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
              child: BeeCheckTile(
                  label: l.welcomeCreateDefaultLedger,
                  subtitle:
                      '${all.firstWhere((c) => c.code == _selectedCurrency).name} · $_selectedCurrency',
                  value: _createDefaultLedger,
                  onChanged: (v) => setState(() => _createDefaultLedger = v))),
        ]));
  }

  Widget _categoryStep(AppLocalizations l) => _step(
      step: 2,
      title: l.welcomeCategoryModeTitle,
      description: l.welcomeCategoryModeDescription,
      options: Column(children: [
        _mode('flat', l.welcomeCategoryModeFlatTitle,
            l.welcomeCategoryModeFlatDescription, 'Grid2x2', [
          l.welcomeCategoryModeFlatFeature1,
          l.welcomeCategoryModeFlatFeature2,
          l.welcomeCategoryModeFlatFeature3
        ]),
        const SizedBox(height: 10),
        _mode('hierarchical', l.welcomeCategoryModeHierarchicalTitle,
            l.welcomeCategoryModeHierarchicalDescription, 'Network', [
          l.welcomeCategoryModeHierarchicalFeature1,
          l.welcomeCategoryModeHierarchicalFeature2,
          l.welcomeCategoryModeHierarchicalFeature3
        ]),
        const SizedBox(height: 10),
        _mode('none', l.welcomeCategoryModeNoneTitle,
            l.welcomeCategoryModeNoneDescription, 'Plus', [
          l.welcomeCategoryModeNoneFeature1,
          l.welcomeCategoryModeNoneFeature2,
          l.welcomeCategoryModeNoneFeature3
        ]),
      ]));

  Widget _mode(String mode, String title, String description, String icon,
          List<String> features) =>
      BeeOnboardingModeCard(
          title: title,
          description: description,
          icon: BeeLineIcon(icon, size: 20),
          selected: _categoryMode == mode,
          onTap: () => setState(() => _categoryMode = mode),
          preview: Text(features.join(' · '),
              style: TextStyle(
                  fontSize: 10,
                  height: 1.6,
                  color: Theme.of(context).hintColor)));

  Widget _cloudStep(AppLocalizations l) => _step(
      step: 3,
      title: l.welcomeCloudSyncTitle,
      description: l.welcomeCloudSyncDescription,
      options:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BeeSurface(
            child: BeeMenuRow(
                title: l.welcomeCloudSyncFeature1,
                leading: const BeeLineIcon('HardDrive', size: 21))),
        const SizedBox(height: 12),
        BeeSurface(
            child: Column(children: [
          BeeMenuRow(
              title: 'BeeCount Cloud',
              subtitle: l.welcomeCloudSyncFeature2,
              leading: const BeeLineIcon('Database', size: 21)),
          const Divider(height: 1),
          BeeMenuRow(
              title: l.welcomeCloudSyncFeature3,
              leading: const BeeLineIcon('Cloud', size: 21)),
        ])),
        const SizedBox(height: 12),
        Text(l.welcomeCloudLater,
            style: TextStyle(
                fontSize: 11,
                height: 1.85,
                color: Theme.of(context).hintColor)),
      ]));

  Widget _privacyStep(AppLocalizations l) => _step(
      step: 4,
      title: l.welcomePrivacyTitle,
      description: l.welcomeReadyDescription,
      options: Column(children: [
        BeeSurface(
            child: Column(children: [
          BeeMenuRow(
              title: l.welcomePrivacyFeature1,
              leading: const BeeLineIcon('Code', size: 21)),
          BeeMenuRow(
              title: l.welcomePrivacyFeature2,
              leading: const BeeLineIcon('ShieldCheck', size: 21)),
          BeeMenuRow(
              title: l.welcomeOpenSourceFeature1,
              leading: const BeeLineIcon('Users', size: 21)),
        ])),
        const SizedBox(height: 12),
        BeeSurface(
            child: Column(children: [
          BeeMenuRow(
              title: l.welcomeViewGitHub,
              leading: const BeeLineIcon('ExternalLink', size: 20),
              onTap: () => _launchGitHub(context)),
          const Divider(height: 1),
          BeeMenuRow(
              title: l.aboutPrivacyPolicy,
              leading: const BeeLineIcon('FileText', size: 20),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const PrivacyPolicyPage()))),
        ])),
      ]));

  Widget _configStep(AppLocalizations l) => _step(
      step: 0,
      total: 2,
      title: l.welcomeRestoreTitle,
      description: l.welcomeRestoreDescription,
      options: Column(children: [
        BeeBackupFileCard(
            title: l.configImportTitle,
            description: l.configImportSubtitle,
            fileName: _configFileName,
            icon: const BeeLineIcon('FileCode2', size: 20),
            actionLabel: l.welcomeSelectBackup,
            onChoose: _isImporting ? null : () => _chooseConfig(context)),
        const SizedBox(height: 12),
        BeeSurface(
            child: Column(children: [
          BeeMenuRow(
              title: l.welcomeRestoreLedgersAccounts,
              leading: const BeeLineIcon('BookOpen')),
          BeeMenuRow(
              title: l.welcomeRestoreCategoriesTags,
              leading: const BeeLineIcon('Shapes')),
          BeeMenuRow(
              title: l.welcomeRestoreSettings,
              subtitle: l.configImportExportSubtitle,
              leading: const BeeLineIcon('Settings2')),
        ])),
      ]),
      footer: SizedBox(
          height: 48,
          child: BeeButton(
              label: l.welcomeRestoreContinue,
              loading: _isImporting,
              onPressed: _configFilePath == null || _isImporting
                  ? null
                  : () => _importConfig(context))),
      helper: BeeButton(
          label: l.commonCancel,
          kind: BeeButtonKind.quiet,
          onPressed: _isImporting
              ? null
              : () => setState(() => _isRestoreConfigFlow = false)));

  Widget _attachmentStep(AppLocalizations l) => _step(
      step: 1,
      total: 2,
      title: l.welcomeAttachmentRestoreTitle,
      description: l.welcomeAttachmentRestoreDescription,
      options: BeeBackupFileCard(
          title: l.welcomeImportAttachmentTitle,
          description: l.welcomeAttachmentBackupDescription,
          fileName: _attachmentFileName,
          icon: const BeeLineIcon('Archive', size: 20),
          actionLabel: l.welcomeSelectBackup,
          onChoose:
              _isImportingAttachment ? null : () => _chooseAttachment(context)),
      footer: SizedBox(
          height: 48,
          child: BeeButton(
              label: l.welcomeImportAttachmentsContinue,
              loading: _isImportingAttachment,
              onPressed: _isImportingAttachment || _attachmentFilePath == null
                  ? null
                  : () => _importAttachments(context))),
      helper: BeeButton(
          label: l.welcomeImportAttachmentSkip,
          kind: BeeButtonKind.quiet,
          onPressed: _isImportingAttachment ? null : _finishExistingUserFlow));
}
