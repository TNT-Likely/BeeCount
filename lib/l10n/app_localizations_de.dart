import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Bienen-Buchhaltung';

  @override
  String get tabHome => 'Startseite';

  @override
  String get tabAnalytics => 'Diagramme';

  @override
  String get tabLedgers => 'Bücher';

  @override
  String get tabMine => 'Mein';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonConfirm => 'Bestätigen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonEdit => 'Bearbeiten';

  @override
  String get commonAdd => 'Hinzufügen';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Ja';

  @override
  String get commonNo => 'Nein';

  @override
  String get commonLoading => 'Lädt...';

  @override
  String get commonEmpty => 'Keine Daten';

  @override
  String get commonError => 'Fehler';

  @override
  String get commonSuccess => 'Erfolg';

  @override
  String get commonFailed => 'Fehlgeschlagen';

  @override
  String get commonRetry => 'Wiederholen';

  @override
  String get commonBack => 'Zurück';

  @override
  String get commonNext => 'Weiter';

  @override
  String get commonPrevious => 'Zurück';

  @override
  String get commonFinish => 'Fertig';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonCopy => 'Kopieren';

  @override
  String get commonSearch => 'Suchen';

  @override
  String get commonNoteHint => 'Notiz...';

  @override
  String get commonFilter => 'Filter';

  @override
  String get commonClear => 'Löschen';

  @override
  String get commonSelectAll => 'Alle auswählen';

  @override
  String get commonSettings => 'Einstellungen';

  @override
  String get commonHelp => 'Hilfe';

  @override
  String get commonAbout => 'Über';

  @override
  String get commonLanguage => 'Sprache';

  @override
  String get commonWeekdayMonday => 'Montag';

  @override
  String get commonWeekdayTuesday => 'Dienstag';

  @override
  String get commonWeekdayWednesday => 'Mittwoch';

  @override
  String get commonWeekdayThursday => 'Donnerstag';

  @override
  String get commonWeekdayFriday => 'Freitag';

  @override
  String get commonWeekdaySaturday => 'Samstag';

  @override
  String get commonWeekdaySunday => 'Sonntag';

  @override
  String get homeTitle => 'Bienen-Buchhaltung';

  @override
  String get homeIncome => 'Einnahmen';

  @override
  String get homeExpense => 'Ausgaben';

  @override
  String get homeBalance => 'Saldo';

  @override
  String get homeTotal => 'Gesamt';

  @override
  String get homeAverage => 'Durchschnitt';

  @override
  String get homeDailyAvg => 'Täglicher Durchschnitt';

  @override
  String get homeMonthlyAvg => 'Monatlicher Durchschnitt';

  @override
  String get homeNoRecords => 'Noch keine Einträge';

  @override
  String get homeAddRecord => 'Eintrag hinzufügen durch Tippen auf das Plus-Symbol';

  @override
  String get homeHideAmounts => 'Beträge ausblenden';

  @override
  String get homeShowAmounts => 'Beträge anzeigen';

  @override
  String get homeSelectDate => 'Datum auswählen';

  @override
  String get homeAppTitle => 'Bienen-Buchhaltung';

  @override
  String get homeSearch => 'Suchen';

  @override
  String get homeShowAmount => 'Beträge anzeigen';

  @override
  String get homeHideAmount => 'Beträge ausblenden';

  @override
  String homeYear(int year) {
    return '$year';
  }

  @override
  String homeMonth(String month) {
    return '${month}M';
  }

  @override
  String get homeNoRecordsSubtext => 'Tippen Sie auf das Plus-Symbol unten, um einen Eintrag hinzuzufügen';

  @override
  String get searchTitle => 'Suchen';

  @override
  String get searchHint => 'Notizen, Kategorien oder Beträge suchen...';

  @override
  String get searchAmountRange => 'Betragsbereich-Filter';

  @override
  String get searchMinAmount => 'Mindestbetrag';

  @override
  String get searchMaxAmount => 'Höchstbetrag';

  @override
  String get searchTo => 'bis';

  @override
  String get searchNoInput => 'Geben Sie Suchbegriffe ein, um mit der Suche zu beginnen';

  @override
  String get searchNoResults => 'Keine passenden Ergebnisse gefunden';

  @override
  String get searchResultsEmpty => 'Keine passenden Ergebnisse gefunden';

  @override
  String get searchResultsEmptyHint => 'Versuchen Sie andere Suchbegriffe oder passen Sie die Filterbedingungen an';

  @override
  String get analyticsTitle => 'Analysen';

  @override
  String get analyticsMonth => 'Monat';

  @override
  String get analyticsYear => 'Jahr';

  @override
  String get analyticsAll => 'Alle';

  @override
  String get analyticsSummary => 'Summary';

  @override
  String get analyticsCategoryRanking => 'Category Ranking';

  @override
  String get analyticsCurrentPeriod => 'Current Period';

  @override
  String get analyticsNoDataSubtext => 'Swipe left/right to toggle income/expense, or use the period switcher above';

  @override
  String get analyticsSwipeHint => 'Swipe left/right to change period';

  @override
  String get analyticsTipContent => '1) Swipe left/right at the top to switch \"Month/Year/All\"\\n2) Swipe left/right in chart area to switch periods\\n3) Tap month or year to quickly select';

  @override
  String analyticsSwitchTo(String type) {
    return 'Switch to $type';
  }

  @override
  String get analyticsTipHeader => 'Tip: Top capsule can switch Month/Year/All';

  @override
  String get analyticsSwipeToSwitch => 'Swipe to switch';

  @override
  String get analyticsAllYears => 'All Years';

  @override
  String get analyticsToday => 'Today';

  @override
  String get splashAppName => 'Bee Accounting';

  @override
  String get splashSlogan => 'Record Every Drop';

  @override
  String get splashSecurityTitle => 'Open Source Data Security';

  @override
  String get splashSecurityFeature1 => '• Local data storage, complete privacy control';

  @override
  String get splashSecurityFeature2 => '• Open source code transparency, trustworthy security';

  @override
  String get splashSecurityFeature3 => '• Optional cloud sync, consistent data across devices';

  @override
  String get splashInitializing => 'Initializing data...';

  @override
  String get ledgersTitle => 'Kontenbücher';

  @override
  String get ledgersNew => 'New Ledger';

  @override
  String get ledgersClear => 'Clear Current Ledger';

  @override
  String get ledgersClearConfirm => 'Clear current ledger?';

  @override
  String get ledgersClearMessage => 'All transaction records in this ledger will be deleted and cannot be recovered.';

  @override
  String get ledgersEdit => 'Buch bearbeiten';

  @override
  String get ledgersDelete => 'Buch löschen';

  @override
  String get ledgersDeleteConfirm => 'Sind Sie sicher, dass Sie dieses Buch löschen möchten?';

  @override
  String get ledgersDeleteMessage => 'Are you sure you want to delete this ledger and all its records? This action cannot be undone.\\nIf there is a backup in the cloud, it will also be deleted.';

  @override
  String get ledgersDeleted => 'Deleted';

  @override
  String get ledgersDeleteFailed => 'Delete Failed';

  @override
  String ledgersRecordsDeleted(int count) {
    return 'Deleted $count records';
  }

  @override
  String get ledgersName => 'Buchname';

  @override
  String get ledgersDefaultLedgerName => 'Default Ledger';

  @override
  String get ledgersDefaultAccountName => 'Cash';

  @override
  String get ledgersCurrency => 'Currency';

  @override
  String get ledgersSelectCurrency => 'Select Currency';

  @override
  String get ledgersSearchCurrency => 'Search: Chinese or code';

  @override
  String get ledgersCreate => 'Create';

  @override
  String get ledgersActions => 'Actions';

  @override
  String ledgersRecords(String count) {
    return 'Records: $count';
  }

  @override
  String ledgersBalance(String balance) {
    return 'Balance: $balance';
  }

  @override
  String get categoryTitle => 'Category Management';

  @override
  String get categoryNew => 'New Category';

  @override
  String get categoryExpense => 'Expense Categories';

  @override
  String get categoryIncome => 'Income Categories';

  @override
  String get categoryEmpty => 'No categories';

  @override
  String get categoryDefault => 'Default Category';

  @override
  String categoryLoadFailed(String error) {
    return 'Load failed: $error';
  }

  @override
  String get iconPickerTitle => 'Select Icon';

  @override
  String get iconCategoryFood => 'Food';

  @override
  String get iconCategoryTransport => 'Transport';

  @override
  String get iconCategoryShopping => 'Shopping';

  @override
  String get iconCategoryEntertainment => 'Entertainment';

  @override
  String get iconCategoryLife => 'Life';

  @override
  String get iconCategoryHealth => 'Health';

  @override
  String get iconCategoryEducation => 'Education';

  @override
  String get iconCategoryWork => 'Work';

  @override
  String get iconCategoryFinance => 'Finance';

  @override
  String get iconCategoryReward => 'Reward';

  @override
  String get iconCategoryOther => 'Other';

  @override
  String get iconCategoryDining => 'Dining';

  @override
  String get importTitle => 'Importieren';

  @override
  String get importSelectFile => 'Datei auswählen';

  @override
  String get importChooseFile => 'Choose File';

  @override
  String get importNoFileSelected => 'No file selected';

  @override
  String get importHint => 'Tip: Please select a CSV/TSV file to start importing';

  @override
  String get importReading => 'Reading file…';

  @override
  String get importPreparing => 'Preparing…';

  @override
  String importColumnNumber(Object number) {
    return 'Column $number';
  }

  @override
  String get importConfirmMapping => 'Confirm Mapping';

  @override
  String get importCategoryMapping => 'Category Mapping';

  @override
  String get importNoDataParsed => 'No data parsed. Please return to previous page to check CSV content or separator.';

  @override
  String get importFieldDate => 'Datum';

  @override
  String get importFieldType => 'Typ';

  @override
  String get importFieldAmount => 'Betrag';

  @override
  String get importFieldCategory => 'Kategorie';

  @override
  String get importFieldNote => 'Notiz';

  @override
  String get importPreview => 'Vorschau';

  @override
  String importPreviewLimit(Object shown, Object total) {
    return 'Showing first $shown of $total records';
  }

  @override
  String get importCategoryNotSelected => 'Category not selected';

  @override
  String get importCategoryMappingDescription => 'Please select corresponding local categories for each category name:';

  @override
  String get importKeepOriginalName => 'Keep original name';

  @override
  String importProgress(Object fail, Object ok) {
    return 'Import-Fortschritt';
  }

  @override
  String get importCancelImport => 'Cancel Import';

  @override
  String get importCompleteTitle => 'Import Complete';

  @override
  String importCompletedCount(Object count) {
    return 'Successfully imported $count records';
  }

  @override
  String get importFailed => 'Import fehlgeschlagen';

  @override
  String importFailedMessage(Object error) {
    return 'Import failed: $error';
  }

  @override
  String get importSelectCategoryFirst => 'Please select category mapping first';

  @override
  String get importNextStep => 'Next Step';

  @override
  String get importPreviousStep => 'Previous Step';

  @override
  String get importStartImport => 'Start Import';

  @override
  String get importAutoDetect => 'Auto Detect';

  @override
  String get importInProgress => 'Import in Progress';

  @override
  String importProgressDetail(Object done, Object fail, Object ok, Object total) {
    return 'Imported $done / $total records, success $ok, failed $fail';
  }

  @override
  String get importBackgroundImport => 'Background Import';

  @override
  String get importCancelled => 'Import Cancelled';

  @override
  String importCompleted(Object cancelled, Object fail, Object ok) {
    return 'Import Completed$cancelled, success $ok, failed $fail';
  }

  @override
  String importFileOpenError(String error) {
    return 'Unable to open file picker: $error';
  }

  @override
  String get mineTitle => 'Mein';

  @override
  String get mineSettings => 'Einstellungen';

  @override
  String get mineTheme => 'Design';

  @override
  String get mineFont => 'Font Settings';

  @override
  String get mineReminder => 'Reminder Settings';

  @override
  String get mineData => 'Data Management';

  @override
  String get mineImport => 'Importieren';

  @override
  String get mineExport => 'Exportieren';

  @override
  String get mineCloud => 'Cloud Service';

  @override
  String get mineAbout => 'Über';

  @override
  String get mineVersion => 'Version';

  @override
  String get mineUpdate => 'Update';

  @override
  String get mineLanguageSettings => 'Language Settings';

  @override
  String get mineLanguageSettingsSubtitle => 'Switch application language';

  @override
  String get languageTitle => 'Sprache';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystemDefault => 'System folgen';

  @override
  String get deleteConfirmTitle => 'Delete Confirmation';

  @override
  String get deleteConfirmMessage => 'Are you sure you want to delete this record?';

  @override
  String get logCopied => 'Log copied';

  @override
  String get waitingRestore => 'Waiting for restore task to start...';

  @override
  String get restoreTitle => 'Cloud Restore';

  @override
  String get copyLog => 'Copy Log';

  @override
  String restoreProgress(Object current, Object total) {
    return 'Restoring ($current/$total)';
  }

  @override
  String get restorePreparing => 'Preparing...';

  @override
  String restoreLedgerProgress(String ledger, int done, int total) {
    return 'Ledger: $ledger  Records: $done/$total';
  }

  @override
  String get mineSlogan => 'Bee Accounting, Every Penny Counts';

  @override
  String get mineDaysCount => 'Days';

  @override
  String get mineTotalRecords => 'Records';

  @override
  String get mineCurrentBalance => 'Balance';

  @override
  String get mineCloudService => 'Cloud Service';

  @override
  String get mineCloudServiceLoading => 'Loading...';

  @override
  String mineCloudServiceError(Object error) {
    return 'Error: $error';
  }

  @override
  String get mineCloudServiceDefault => 'Default Cloud (Enabled)';

  @override
  String get mineCloudServiceOffline => 'Default Mode (Offline)';

  @override
  String get mineCloudServiceCustom => 'Custom Supabase';

  @override
  String get mineFirstFullUpload => 'First Full Upload';

  @override
  String get mineFirstFullUploadSubtitle => 'Upload all local ledgers to current Supabase';

  @override
  String get mineFirstFullUploadComplete => 'Complete';

  @override
  String get mineFirstFullUploadMessage => 'Current ledger uploaded. Switch to other ledgers to upload them.';

  @override
  String get mineFirstFullUploadFailed => 'Failed';

  @override
  String get mineSyncTitle => 'Sync';

  @override
  String get mineSyncNotLoggedIn => 'Not logged in';

  @override
  String get mineSyncNotConfigured => 'Cloud not configured';

  @override
  String get mineSyncNoRemote => 'No cloud backup';

  @override
  String mineSyncInSync(Object count) {
    return 'Synced (local $count records)';
  }

  @override
  String mineSyncLocalNewer(Object count) {
    return 'Local newer (local $count records, upload recommended)';
  }

  @override
  String get mineSyncCloudNewer => 'Cloud newer (download recommended)';

  @override
  String get mineSyncDifferent => 'Local and cloud differ';

  @override
  String get mineSyncError => 'Failed to get status';

  @override
  String get mineSyncDetailTitle => 'Sync Status Details';

  @override
  String mineSyncLocalRecords(Object count) {
    return 'Local records: $count';
  }

  @override
  String mineSyncCloudRecords(Object count) {
    return 'Cloud records: $count';
  }

  @override
  String mineSyncCloudLatest(Object time) {
    return 'Cloud latest record time: $time';
  }

  @override
  String mineSyncLocalFingerprint(Object fingerprint) {
    return 'Local fingerprint: $fingerprint';
  }

  @override
  String mineSyncCloudFingerprint(Object fingerprint) {
    return 'Cloud fingerprint: $fingerprint';
  }

  @override
  String mineSyncMessage(Object message) {
    return 'Message: $message';
  }

  @override
  String get mineUploadTitle => 'Upload';

  @override
  String get mineUploadNeedLogin => 'Login required';

  @override
  String get mineUploadInProgress => 'Uploading...';

  @override
  String get mineUploadRefreshing => 'Refreshing...';

  @override
  String get mineUploadSynced => 'Synced';

  @override
  String get mineUploadSuccess => 'Uploaded';

  @override
  String get mineUploadSuccessMessage => 'Current ledger synced to cloud';

  @override
  String get mineDownloadTitle => 'Download';

  @override
  String get mineDownloadComplete => 'Complete';

  @override
  String mineDownloadResult(Object deleted, Object inserted, Object skipped) {
    return 'New imports: $inserted\nExisting skipped: $skipped\nDuplicates cleaned: $deleted';
  }

  @override
  String get mineLoginTitle => 'Login / Register';

  @override
  String get mineLoginSubtitle => 'Only needed for sync';

  @override
  String get mineLoggedInEmail => 'Logged in';

  @override
  String get mineLogoutSubtitle => 'Tap to logout';

  @override
  String get mineLogoutConfirmTitle => 'Logout';

  @override
  String get mineLogoutConfirmMessage => 'Are you sure you want to logout?\nYou won\'t be able to use cloud sync after logout.';

  @override
  String get mineLogoutButton => 'Logout';

  @override
  String get mineAutoSyncTitle => 'Auto sync ledger';

  @override
  String get mineAutoSyncSubtitle => 'Auto upload to cloud after recording';

  @override
  String get mineAutoSyncNeedLogin => 'Login required to enable';

  @override
  String get mineImportProgressTitle => 'Importing in background...';

  @override
  String mineImportProgressSubtitle(Object done, Object fail, Object ok, Object total) {
    return 'Progress: $done/$total, Success $ok, Failed $fail';
  }

  @override
  String get mineImportCompleteTitle => 'Import complete';

  @override
  String mineImportCompleteSubtitle(Object fail, Object ok) {
    return 'Success $ok, Failed $fail';
  }

  @override
  String get mineCategoryManagement => 'Category Management';

  @override
  String get mineCategoryManagementSubtitle => 'Edit custom categories';

  @override
  String get mineCategoryMigration => 'Category Migration';

  @override
  String get mineCategoryMigrationSubtitle => 'Migrate category data to other categories';

  @override
  String get mineReminderSettings => 'Reminder Settings';

  @override
  String get mineReminderSettingsSubtitle => 'Set daily recording reminders';

  @override
  String get minePersonalize => 'Personalization';

  @override
  String get mineDisplayScale => 'Display Scale';

  @override
  String get mineDisplayScaleSubtitle => 'Adjust text and UI element sizes';

  @override
  String get mineAboutTitle => 'About';

  @override
  String mineAboutMessage(Object version) {
    return 'App: Bee Accounting\nVersion: $version\nSource: https://github.com/TNT-Likely/BeeCount\nLicense: See LICENSE in repository';
  }

  @override
  String get mineAboutOpenGitHub => 'Open GitHub';

  @override
  String get mineCheckUpdate => 'Nach Updates suchen';

  @override
  String get mineCheckUpdateInProgress => 'Checking update...';

  @override
  String get mineCheckUpdateSubtitle => 'Checking for latest version';

  @override
  String get mineUpdateDownload => 'Download Update';

  @override
  String get mineRefreshStats => 'Refresh Stats (Debug)';

  @override
  String get mineRefreshStatsSubtitle => 'Trigger global stats provider recalculation';

  @override
  String get mineRefreshSync => 'Refresh Sync Status (Debug)';

  @override
  String get mineRefreshSyncSubtitle => 'Trigger sync status provider refresh';

  @override
  String get categoryEditTitle => 'Edit Category';

  @override
  String get categoryNewTitle => 'New Category';

  @override
  String get categoryDetailTooltip => 'Category Details';

  @override
  String get categoryMigrationTooltip => 'Category Migration';

  @override
  String get categoryMigrationTitle => 'Category Migration';

  @override
  String get categoryMigrationDescription => 'Category Migration Instructions';

  @override
  String get categoryMigrationDescriptionContent => '• Migrate all transaction records from one category to another\n• After migration, all transaction data from the source category will be transferred to the target category\n• This operation cannot be undone, please choose carefully';

  @override
  String get categoryMigrationFromLabel => 'From Category';

  @override
  String get categoryMigrationFromHint => 'Select category to migrate from';

  @override
  String get categoryMigrationToLabel => 'To Category';

  @override
  String get categoryMigrationToHint => 'Select target category';

  @override
  String get categoryMigrationToHintFirst => 'Please select source category first';

  @override
  String get categoryMigrationStartButton => 'Start Migration';

  @override
  String categoryMigrationTransactionCount(int count) {
    return '$count records';
  }

  @override
  String get categoryMigrationCannotTitle => 'Cannot Migrate';

  @override
  String get categoryMigrationCannotMessage => 'Selected categories cannot be migrated, please check category status.';

  @override
  String get categoryExpenseType => 'Expense Category';

  @override
  String get categoryIncomeType => 'Income Category';

  @override
  String get categoryDefaultTitle => 'Default Category';

  @override
  String get categoryDefaultMessage => 'Default categories cannot be modified, but you can view details and migrate data';

  @override
  String get categoryNameDining => 'Dining';

  @override
  String get categoryNameTransport => 'Transport';

  @override
  String get categoryNameShopping => 'Shopping';

  @override
  String get categoryNameEntertainment => 'Entertainment';

  @override
  String get categoryNameHome => 'Home';

  @override
  String get categoryNameFamily => 'Family';

  @override
  String get categoryNameCommunication => 'Communication';

  @override
  String get categoryNameUtilities => 'Utilities';

  @override
  String get categoryNameHousing => 'Housing';

  @override
  String get categoryNameMedical => 'Medical';

  @override
  String get categoryNameEducation => 'Education';

  @override
  String get categoryNamePets => 'Pets';

  @override
  String get categoryNameSports => 'Sports';

  @override
  String get categoryNameDigital => 'Digital';

  @override
  String get categoryNameTravel => 'Travel';

  @override
  String get categoryNameAlcoholTobacco => 'Alcohol & Tobacco';

  @override
  String get categoryNameBabyCare => 'Baby Care';

  @override
  String get categoryNameBeauty => 'Beauty';

  @override
  String get categoryNameRepair => 'Repair';

  @override
  String get categoryNameSocial => 'Social';

  @override
  String get categoryNameLearning => 'Learning';

  @override
  String get categoryNameCar => 'Car';

  @override
  String get categoryNameTaxi => 'Taxi';

  @override
  String get categoryNameSubway => 'Subway';

  @override
  String get categoryNameDelivery => 'Delivery';

  @override
  String get categoryNameProperty => 'Property';

  @override
  String get categoryNameParking => 'Parking';

  @override
  String get categoryNameDonation => 'Donation';

  @override
  String get categoryNameGift => 'Gift';

  @override
  String get categoryNameTax => 'Tax';

  @override
  String get categoryNameBeverage => 'Beverage';

  @override
  String get categoryNameClothing => 'Clothing';

  @override
  String get categoryNameSnacks => 'Snacks';

  @override
  String get categoryNameRedPacket => 'Red Packet';

  @override
  String get categoryNameFruit => 'Fruit';

  @override
  String get categoryNameGame => 'Game';

  @override
  String get categoryNameBook => 'Book';

  @override
  String get categoryNameLover => 'Lover';

  @override
  String get categoryNameDecoration => 'Decoration';

  @override
  String get categoryNameDailyGoods => 'Daily Goods';

  @override
  String get categoryNameLottery => 'Lottery';

  @override
  String get categoryNameStock => 'Stock';

  @override
  String get categoryNameSocialSecurity => 'Social Security';

  @override
  String get categoryNameExpress => 'Express';

  @override
  String get categoryNameWork => 'Work';

  @override
  String get categoryNameSalary => 'Salary';

  @override
  String get categoryNameInvestment => 'Investment';

  @override
  String get categoryNameBonus => 'Bonus';

  @override
  String get categoryNameReimbursement => 'Reimbursement';

  @override
  String get categoryNamePartTime => 'Part-time';

  @override
  String get categoryNameInterest => 'Interest';

  @override
  String get categoryNameRefund => 'Refund';

  @override
  String get categoryNameSecondHand => 'Second-hand Sale';

  @override
  String get categoryNameSocialBenefit => 'Social Benefit';

  @override
  String get categoryNameTaxRefund => 'Tax Refund';

  @override
  String get categoryNameProvidentFund => 'Provident Fund';

  @override
  String get categoryNameLabel => 'Category Name';

  @override
  String get categoryNameHint => 'Enter category name';

  @override
  String get categoryNameHintDefault => 'Default category name cannot be modified';

  @override
  String get categoryNameRequired => 'Please enter category name';

  @override
  String get categoryNameTooLong => 'Category name cannot exceed 4 characters';

  @override
  String get categoryIconLabel => 'Category Icon';

  @override
  String get categoryIconDefaultMessage => 'Default category icon cannot be modified';

  @override
  String get categoryDangerousOperations => 'Dangerous Operations';

  @override
  String get categoryDeleteTitle => 'Delete Category';

  @override
  String get categoryDeleteSubtitle => 'Cannot be recovered after deletion';

  @override
  String get categoryDefaultCannotSave => 'Default category cannot be saved';

  @override
  String get categorySaveError => 'Save failed';

  @override
  String categoryUpdated(Object name) {
    return 'Category \"$name\" updated';
  }

  @override
  String categoryCreated(Object name) {
    return 'Category \"$name\" created';
  }

  @override
  String get categoryCannotDelete => 'Cannot delete';

  @override
  String categoryCannotDeleteMessage(Object count) {
    return 'This category has $count transaction records. Please handle them first.';
  }

  @override
  String get categoryDeleteConfirmTitle => 'Delete Category';

  @override
  String categoryDeleteConfirmMessage(Object name) {
    return 'Are you sure you want to delete category \"$name\"? This action cannot be undone.';
  }

  @override
  String get categoryDeleteError => 'Delete failed';

  @override
  String categoryDeleted(Object name) {
    return 'Category \"$name\" deleted';
  }

  @override
  String get personalizeTitle => 'Personalisieren';

  @override
  String get personalizeCustomColor => 'Choose custom color';

  @override
  String get personalizeCustomTitle => 'Custom';

  @override
  String personalizeHue(Object value) {
    return 'Hue ($value°)';
  }

  @override
  String personalizeSaturation(Object value) {
    return 'Saturation ($value%)';
  }

  @override
  String personalizeBrightness(Object value) {
    return 'Brightness ($value%)';
  }

  @override
  String get personalizeSelectColor => 'Select this color';

  @override
  String get fontSettingsTitle => 'Display Scale';

  @override
  String fontSettingsCurrentScale(Object scale) {
    return 'Current scale: x$scale';
  }

  @override
  String get fontSettingsPreview => 'Live Preview';

  @override
  String get fontSettingsPreviewText => 'Spent 23.50 on lunch today, record it;\nRecorded for 45 days this month, 320 entries;\nPersistence is victory!';

  @override
  String fontSettingsCurrentLevel(Object level, Object scale) {
    return 'Current level: $level (scale x$scale)';
  }

  @override
  String get fontSettingsQuickLevel => 'Quick Levels';

  @override
  String get fontSettingsCustomAdjust => 'Custom Adjustment';

  @override
  String get fontSettingsDescription => 'Note: This setting ensures consistent display at 1.0x across all devices, with device differences auto-compensated; adjust values for personalized scaling on this consistent base.';

  @override
  String get fontSettingsExtraSmall => 'Extra Small';

  @override
  String get fontSettingsVerySmall => 'Very Small';

  @override
  String get fontSettingsSmall => 'Small';

  @override
  String get fontSettingsStandard => 'Standard';

  @override
  String get fontSettingsLarge => 'Large';

  @override
  String get fontSettingsBig => 'Big';

  @override
  String get fontSettingsVeryBig => 'Very Big';

  @override
  String get fontSettingsExtraBig => 'Extra Big';

  @override
  String get fontSettingsMoreStyles => 'More Styles';

  @override
  String get fontSettingsPageTitle => 'Page Title';

  @override
  String get fontSettingsBlockTitle => 'Block Title';

  @override
  String get fontSettingsBodyExample => 'Body Text';

  @override
  String get fontSettingsLabelExample => 'Label Text';

  @override
  String get fontSettingsStrongNumber => 'Strong Number';

  @override
  String get fontSettingsListTitle => 'List Item Title';

  @override
  String get fontSettingsListSubtitle => 'Helper Text';

  @override
  String get fontSettingsScreenInfo => 'Screen Adaptation Info';

  @override
  String get fontSettingsScreenDensity => 'Screen Density';

  @override
  String get fontSettingsScreenWidth => 'Screen Width';

  @override
  String get fontSettingsDeviceScale => 'Device Scale';

  @override
  String get fontSettingsUserScale => 'User Scale';

  @override
  String get fontSettingsFinalScale => 'Final Scale';

  @override
  String get fontSettingsBaseDevice => 'Base Device';

  @override
  String get fontSettingsRecommendedScale => 'Recommended Scale';

  @override
  String get fontSettingsYes => 'Yes';

  @override
  String get fontSettingsNo => 'No';

  @override
  String get fontSettingsScaleExample => 'This box and spacing auto-scale based on device';

  @override
  String get fontSettingsPreciseAdjust => 'Precise Adjustment';

  @override
  String get fontSettingsResetTo1x => 'Reset to 1.0x';

  @override
  String get fontSettingsAdaptBase => 'Adapt to Base';

  @override
  String get reminderTitle => 'Aufzeichnungserinnerung';

  @override
  String get reminderSubtitle => 'Tägliche Aufzeichnungserinnerungszeit einstellen';

  @override
  String get reminderDailyTitle => 'Tägliche Aufzeichnungserinnerung';

  @override
  String get reminderDailySubtitle => 'Wenn aktiviert, erinnert Sie zur angegebenen Zeit an die Aufzeichnung';

  @override
  String get reminderTimeTitle => 'Erinnerungszeit';

  @override
  String get reminderTestNotification => 'Test-Benachrichtigung senden';

  @override
  String get reminderTestSent => 'Test-Benachrichtigung gesendet';

  @override
  String get reminderQuickTest => 'Schnelltest (15s später)';

  @override
  String get reminderQuickTestMessage => 'Quick test set for 15 seconds later, keep app in background';

  @override
  String get reminderFlutterTest => '🔧 Flutter-Benachrichtigung-Klick testen (Dev)';

  @override
  String get reminderFlutterTestMessage => 'Flutter test notification sent, tap to see if app opens';

  @override
  String get reminderAlarmTest => '🔧 Test AlarmManager Notification Click (Dev)';

  @override
  String get reminderAlarmTestMessage => 'AlarmManager test notification set (1s later), tap to see if app opens';

  @override
  String get reminderDirectTest => '🔧 Direct Test NotificationReceiver (Dev)';

  @override
  String get reminderDirectTestMessage => 'Directly called NotificationReceiver to create notification, check if tap works';

  @override
  String get reminderCheckStatus => '🔧 Check Notification Status (Dev)';

  @override
  String get reminderNotificationStatus => 'Notification Status';

  @override
  String reminderPendingCount(Object count) {
    return 'Pending notifications: $count';
  }

  @override
  String get reminderNoPending => 'No pending notifications';

  @override
  String get reminderCheckBattery => 'Check Battery Optimization Status';

  @override
  String get reminderBatteryStatus => 'Battery Optimization Status';

  @override
  String reminderManufacturer(Object value) {
    return 'Manufacturer: $value';
  }

  @override
  String reminderModel(Object value) {
    return 'Model: $value';
  }

  @override
  String reminderAndroidVersion(Object value) {
    return 'Android Version: $value';
  }

  @override
  String get reminderBatteryIgnored => 'Battery optimization: Ignored ✅';

  @override
  String get reminderBatteryNotIgnored => 'Battery optimization: Not ignored ⚠️';

  @override
  String get reminderBatteryAdvice => 'Recommend disabling battery optimization for proper notifications';

  @override
  String get reminderGoToSettings => 'Go to Settings';

  @override
  String get reminderCheckChannel => 'Check Notification Channel Settings';

  @override
  String get reminderChannelStatus => 'Notification Channel Status';

  @override
  String get reminderChannelEnabled => 'Channel enabled: Yes ✅';

  @override
  String get reminderChannelDisabled => 'Channel enabled: No ❌';

  @override
  String reminderChannelImportance(Object value) {
    return 'Importance: $value';
  }

  @override
  String get reminderChannelSoundOn => 'Sound: On 🔊';

  @override
  String get reminderChannelSoundOff => 'Sound: Off 🔇';

  @override
  String get reminderChannelVibrationOn => 'Vibration: On 📳';

  @override
  String get reminderChannelVibrationOff => 'Vibration: Off';

  @override
  String get reminderChannelDndBypass => 'Do Not Disturb: Can bypass';

  @override
  String get reminderChannelDndNoBypass => 'Do Not Disturb: Cannot bypass';

  @override
  String get reminderChannelAdvice => '⚠️ Recommended settings:';

  @override
  String get reminderChannelAdviceImportance => '• Importance: Urgent or High';

  @override
  String get reminderChannelAdviceSound => '• Enable sound and vibration';

  @override
  String get reminderChannelAdviceBanner => '• Allow banner notifications';

  @override
  String get reminderChannelAdviceXiaomi => '• Xiaomi phones need individual channel setup';

  @override
  String get reminderChannelGood => '✅ Notification channel well configured';

  @override
  String get reminderOpenAppSettings => 'Open App Settings';

  @override
  String get reminderAppSettingsMessage => 'Please allow notifications and disable battery optimization in settings';

  @override
  String get reminderIOSTest => '🍎 iOS Notification Debug Test';

  @override
  String get reminderIOSTestTitle => 'iOS Notification Test';

  @override
  String get reminderIOSTestMessage => 'Test notification sent.\n\n🍎 iOS Simulator limitations:\n• Notifications may not show in notification center\n• Banner alerts may not work\n• But Xcode console will show logs\n\n💡 Debug methods:\n• Check Xcode console output\n• Check Flutter log info\n• Use real device for full experience';

  @override
  String get reminderDescription => 'Tip: When recording reminder is enabled, the system will send notifications at the specified time daily to remind you to record income and expenses.';

  @override
  String get reminderIOSInstructions => '🍎 iOS notification settings:\n• Settings > Notifications > Bee Accounting\n• Enable \"Allow Notifications\"\n• Set notification style: Banner or Alert\n• Enable sound and vibration\n\n⚠️ iOS Simulator limitations:\n• Simulator notification features are limited\n• Recommend using real device\n• Check Xcode console for notification status\n\nIf testing in simulator, observe:\n• Xcode console log output\n• Flutter Debug Console info\n• In-app popups confirming notification sent';

  @override
  String get reminderAndroidInstructions => 'If notifications don\'t work properly, check:\n• App is allowed to send notifications\n• Disable battery optimization/power saving for app\n• Allow app to run in background and auto-start\n• Android 12+ needs exact alarm permission\n\n📱 Xiaomi phone special settings:\n• Settings > App Management > Bee Accounting > Notification Management\n• Tap \"Recording Reminder\" channel\n• Set importance to \"Urgent\" or \"High\"\n• Enable \"Banner notifications\", \"Sound\", \"Vibration\"\n• Security Center > App Management > Permissions > Auto-start\n\n🔒 Lock background methods:\n• Find Bee Accounting in recent tasks\n• Pull down app card to show lock icon\n• Tap lock icon to prevent cleanup';

  @override
  String get categoryDetailLoadFailed => 'Load failed';

  @override
  String get categoryDetailSummaryTitle => 'Category Summary';

  @override
  String get categoryDetailTotalCount => 'Total Count';

  @override
  String get categoryDetailTotalAmount => 'Total Amount';

  @override
  String get categoryDetailAverageAmount => 'Average Amount';

  @override
  String get categoryDetailSortTitle => 'Sort';

  @override
  String get categoryDetailSortTimeDesc => 'Time ↓';

  @override
  String get categoryDetailSortTimeAsc => 'Time ↑';

  @override
  String get categoryDetailSortAmountDesc => 'Amount ↓';

  @override
  String get categoryDetailSortAmountAsc => 'Amount ↑';

  @override
  String get categoryDetailNoTransactions => 'No transactions';

  @override
  String get categoryDetailNoTransactionsSubtext => 'No transactions in this category yet';

  @override
  String get categoryDetailDeleteFailed => 'Delete failed';

  @override
  String get categoryMigrationConfirmTitle => 'Confirm Migration';

  @override
  String categoryMigrationConfirmMessage(Object count, Object fromName, Object toName) {
    return 'Migrate $count transactions from \"$fromName\" to \"$toName\"?\n\nThis operation cannot be undone!';
  }

  @override
  String get categoryMigrationConfirmOk => 'Confirm Migration';

  @override
  String get categoryMigrationCompleteTitle => 'Migration Complete';

  @override
  String categoryMigrationCompleteMessage(Object count, Object fromName, Object toName) {
    return 'Successfully migrated $count transactions from \"$fromName\" to \"$toName\".';
  }

  @override
  String get categoryMigrationFailedTitle => 'Migration Failed';

  @override
  String categoryMigrationFailedMessage(Object error) {
    return 'Migration error: $error';
  }

  @override
  String categoryMigrationTransactionLabel(int count) {
    return '$count records';
  }

  @override
  String get categoryPickerExpenseTab => 'Expense';

  @override
  String get categoryPickerIncomeTab => 'Income';

  @override
  String get categoryPickerCancel => 'Cancel';

  @override
  String get categoryPickerEmpty => 'No categories';

  @override
  String get cloudBackupFound => 'Cloud Backup Found';

  @override
  String get cloudBackupRestoreMessage => 'Cloud and local ledgers are inconsistent. Restore from cloud?\n(Will enter restore progress page)';

  @override
  String get cloudBackupRestoreFailed => 'Restore Failed';

  @override
  String get mineCloudBackupRestoreTitle => 'Cloud Backup Found';

  @override
  String get mineAutoSyncRemoteDesc => 'Auto upload to cloud after recording';

  @override
  String get mineAutoSyncLoginRequired => 'Login required to enable';

  @override
  String get mineImportCompleteAllSuccess => 'All Success';

  @override
  String get mineImportCompleteTitleShort => 'Import Complete';

  @override
  String get mineAboutAppName => 'App: Bee Accounting';

  @override
  String mineAboutVersion(Object version) {
    return 'Version: $version';
  }

  @override
  String get mineAboutRepo => 'Source: https://github.com/TNT-Likely/BeeCount';

  @override
  String get mineAboutLicense => 'License: See LICENSE in repository';

  @override
  String get mineCheckUpdateDetecting => 'Checking update...';

  @override
  String get mineCheckUpdateSubtitleDetecting => 'Checking for latest version';

  @override
  String get mineUpdateDownloadTitle => 'Download Update';

  @override
  String get mineDebugRefreshStats => 'Refresh Stats (Debug)';

  @override
  String get mineDebugRefreshStatsSubtitle => 'Trigger global stats provider recalculation';

  @override
  String get mineDebugRefreshSync => 'Refresh Sync Status (Debug)';

  @override
  String get mineDebugRefreshSyncSubtitle => 'Trigger sync status provider refresh';

  @override
  String get cloudCurrentService => 'Current Cloud Service';

  @override
  String get cloudConnected => 'Connected';

  @override
  String get cloudOfflineMode => 'Offline Mode';

  @override
  String get cloudAvailableServices => 'Available Cloud Services';

  @override
  String get cloudReadCustomConfigFailed => 'Failed to read custom configuration';

  @override
  String get cloudFirstUploadNotComplete => 'First full upload not completed';

  @override
  String get cloudFirstUploadInstruction => 'Login and manually execute \"Upload\" in \"Mine/Sync\" to complete initialization';

  @override
  String get cloudNotConfigured => 'Not configured';

  @override
  String get cloudNotTested => 'Not tested';

  @override
  String get cloudConnectionNormal => 'Connection normal';

  @override
  String get cloudConnectionFailed => 'Connection failed';

  @override
  String get cloudAddCustomService => 'Add custom cloud service';

  @override
  String get cloudDefaultServiceName => 'Default Cloud Service';

  @override
  String get cloudUseYourSupabase => 'Use your own Supabase';

  @override
  String get cloudTest => 'Test';

  @override
  String get cloudSwitchService => 'Switch Cloud Service';

  @override
  String get cloudSwitchToBuiltinConfirm => 'Are you sure you want to switch to the default cloud service? This will log out the current session.';

  @override
  String get cloudSwitchToCustomConfirm => 'Are you sure you want to switch to the custom cloud service? This will log out the current session.';

  @override
  String get cloudSwitched => 'Switched';

  @override
  String get cloudSwitchedToBuiltin => 'Switched to default cloud service and logged out';

  @override
  String get cloudSwitchFailed => 'Switch failed';

  @override
  String get cloudActivateFailed => 'Activation failed';

  @override
  String get cloudActivateFailedMessage => 'Saved configuration is invalid';

  @override
  String get cloudActivated => 'Activated';

  @override
  String get cloudActivatedMessage => 'Switched to custom cloud service and logged out, please log in again';

  @override
  String get cloudEditCustomService => 'Edit custom cloud service';

  @override
  String get cloudAddCustomServiceTitle => 'Add custom cloud service';

  @override
  String get cloudSupabaseUrlLabel => 'Supabase URL';

  @override
  String get cloudSupabaseUrlHint => 'https://xxx.supabase.co';

  @override
  String get cloudAnonKeyLabel => 'Anon Key';

  @override
  String get cloudAnonKeyHint => 'Note: Do not fill in service_role Key; Anon Key is publicly available.';

  @override
  String get cloudInvalidInput => 'Invalid input';

  @override
  String get cloudValidationEmptyFields => 'URL and Key cannot be empty';

  @override
  String get cloudValidationHttpsRequired => 'URL must start with https://';

  @override
  String get cloudValidationKeyTooShort => 'Key length is too short, may be invalid';

  @override
  String get cloudValidationServiceRoleKey => 'service_role Key is not allowed';

  @override
  String get cloudConfigUpdated => 'Configuration updated';

  @override
  String get cloudConfigSaved => 'Configuration saved';

  @override
  String get cloudTestComplete => 'Test complete';

  @override
  String get cloudTestSuccess => 'Connection test successful!';

  @override
  String get cloudTestFailed => 'Connection test failed, please check if the configuration is correct.';

  @override
  String get cloudTestError => 'Test failed';

  @override
  String get cloudClearConfig => 'Clear configuration';

  @override
  String get cloudClearConfigConfirm => 'Are you sure you want to clear the custom cloud service configuration? (Development environment only)';

  @override
  String get cloudConfigCleared => 'Custom cloud service configuration cleared';

  @override
  String get cloudClearFailed => 'Clear failed';

  @override
  String get cloudServiceDescription => 'Built-in cloud service (free but may be unstable, recommend using your own or regular backup)';

  @override
  String get cloudServiceDescriptionNotConfigured => 'Current build does not have built-in cloud service configuration';

  @override
  String cloudServiceDescriptionCustom(String url) {
    return 'Server: $url';
  }

  @override
  String get authLogin => 'Login';

  @override
  String get authSignup => 'Sign Up';

  @override
  String get authRegister => 'Register';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authPasswordRequirement => 'Password (at least 6 characters, include letters and numbers)';

  @override
  String get authConfirmPassword => 'Confirm Password';

  @override
  String get authInvalidEmail => 'Please enter a valid email address';

  @override
  String get authPasswordRequirementShort => 'Password must contain letters and numbers, at least 6 characters';

  @override
  String get authPasswordMismatch => 'Passwords do not match';

  @override
  String get authResendVerification => 'Resend verification email';

  @override
  String get authSignupSuccess => 'Registration successful';

  @override
  String get authVerificationEmailSent => 'Verification email sent, please go to your email to complete verification before logging in.';

  @override
  String get authBackToMinePage => 'Back to My Page';

  @override
  String get authVerificationEmailResent => 'Verification email resent.';

  @override
  String get authResendAction => 'resend verification';

  @override
  String get authErrorInvalidCredentials => 'Email or password is incorrect.';

  @override
  String get authErrorEmailNotConfirmed => 'Email not verified, please complete verification in your email before logging in.';

  @override
  String get authErrorRateLimit => 'Too many attempts, please try again later.';

  @override
  String get authErrorNetworkIssue => 'Network error, please check your connection and try again.';

  @override
  String get authErrorLoginFailed => 'Login failed, please try again later.';

  @override
  String get authErrorEmailInvalid => 'Email address is invalid, please check for spelling errors.';

  @override
  String get authErrorEmailExists => 'This email is already registered, please login directly or reset password.';

  @override
  String get authErrorWeakPassword => 'Password is too simple, please include letters and numbers, at least 6 characters.';

  @override
  String get authErrorSignupFailed => 'Registration failed, please try again later.';

  @override
  String authErrorUserNotFound(String action) {
    return 'Email not registered, cannot $action.';
  }

  @override
  String authErrorEmailNotVerified(String action) {
    return 'Email not verified, cannot $action.';
  }

  @override
  String authErrorActionFailed(String action) {
    return '$action failed, please try again later.';
  }

  @override
  String get importSelectCsvFile => 'Please select CSV/TSV file to import (first row as header by default)';

  @override
  String get exportTitle => 'Exportieren';

  @override
  String get exportDescription => 'Klicken Sie auf die Schaltfläche unten, um den Speicherort auszuwählen und das aktuelle Buch in eine CSV-Datei zu exportieren.';

  @override
  String get exportButtonIOS => 'Exportieren und teilen (iOS)';

  @override
  String get exportButtonAndroid => 'Ordner auswählen und exportieren';

  @override
  String exportSavedTo(String path) {
    return 'Gespeichert in: $path';
  }

  @override
  String get exportSelectFolder => 'Export-Ordner auswählen';

  @override
  String get exportCsvHeaderType => 'Typ';

  @override
  String get exportCsvHeaderCategory => 'Kategorie';

  @override
  String get exportCsvHeaderAmount => 'Betrag';

  @override
  String get exportCsvHeaderNote => 'Notiz';

  @override
  String get exportCsvHeaderTime => 'Zeit';

  @override
  String get exportShareText => 'BeeCount Export-Datei';

  @override
  String get exportSuccessTitle => 'Export erfolgreich';

  @override
  String exportSuccessMessageIOS(String path) {
    return 'Gespeichert und verfügbar im Teilen-Verlauf:\n$path';
  }

  @override
  String exportSuccessMessageAndroid(String path) {
    return 'Gespeichert in:\n$path';
  }

  @override
  String get exportFailedTitle => 'Export fehlgeschlagen';

  @override
  String get exportTypeIncome => 'Einnahme';

  @override
  String get exportTypeExpense => 'Ausgabe';

  @override
  String get exportTypeTransfer => 'Übertragung';

  @override
  String get personalizeThemeHoney => 'Bienengelb';

  @override
  String get personalizeThemeOrange => 'Flammeorange';

  @override
  String get personalizeThemeGreen => 'Smaragdgrün';

  @override
  String get personalizeThemePurple => 'Lotuslila';

  @override
  String get personalizeThemePink => 'Kirschrosa';

  @override
  String get personalizeThemeBlue => 'Himmelblau';

  @override
  String get personalizeThemeMint => 'Waldmond';

  @override
  String get personalizeThemeSand => 'Sonnenuntergangsdüne';

  @override
  String get personalizeThemeLavender => 'Schnee und Kiefer';

  @override
  String get personalizeThemeSky => 'Nebel-Wunderland';

  @override
  String get personalizeThemeWarmOrange => 'Warmorange';

  @override
  String get personalizeThemeMintGreen => 'Minzgrün';

  @override
  String get personalizeThemeRoseGold => 'Roségold';

  @override
  String get personalizeThemeDeepBlue => 'Tiefblau';

  @override
  String get personalizeThemeMapleRed => 'Ahornrot';

  @override
  String get personalizeThemeEmerald => 'Smaragd';

  @override
  String get personalizeThemeLavenderPurple => 'Lavendel';

  @override
  String get personalizeThemeAmber => 'Bernstein';

  @override
  String get personalizeThemeRouge => 'Zinnober';

  @override
  String get personalizeThemeIndigo => 'Indigoblau';

  @override
  String get personalizeThemeOlive => 'Olivgrün';

  @override
  String get personalizeThemeCoral => 'Korallenrosa';

  @override
  String get personalizeThemeDarkGreen => 'Dunkelgrün';

  @override
  String get personalizeThemeViolet => 'Violett';

  @override
  String get personalizeThemeSunset => 'Sonnenuntergangsorange';

  @override
  String get personalizeThemePeacock => 'Pfaublau';

  @override
  String get personalizeThemeLime => 'Limonengrün';

  @override
  String get analyticsMonthlyAvg => 'Monatlicher Durchschnitt';

  @override
  String get analyticsDailyAvg => 'Täglicher Durchschnitt';

  @override
  String get analyticsOverallAvg => 'Gesamtdurchschnitt';

  @override
  String get analyticsTotalIncome => 'Gesamteinnahmen: ';

  @override
  String get analyticsTotalExpense => 'Gesamtausgaben: ';

  @override
  String get analyticsBalance => 'Saldo: ';

  @override
  String analyticsAvgIncome(String avgLabel) {
    return '$avgLabel Einnahmen: ';
  }

  @override
  String analyticsAvgExpense(String avgLabel) {
    return '$avgLabel Ausgaben: ';
  }

  @override
  String get analyticsExpense => 'Ausgaben';

  @override
  String get analyticsIncome => 'Einnahmen';

  @override
  String analyticsTotal(String type) {
    return 'Gesamt $type: ';
  }

  @override
  String analyticsAverage(String avgLabel) {
    return '$avgLabel: ';
  }

  @override
  String get updateCheckTitle => 'Nach Updates suchen';

  @override
  String get updateNewVersionFound => 'Neue Version gefunden';

  @override
  String updateNewVersionTitle(String version) {
    return 'Neue Version $version gefunden';
  }

  @override
  String get updateNoApkFound => 'APK-Download-Link nicht gefunden';

  @override
  String get updateAlreadyLatest => 'Sie haben bereits die neueste Version';

  @override
  String get updateCheckFailed => 'Update-Prüfung fehlgeschlagen';

  @override
  String get updatePermissionDenied => 'Berechtigung verweigert';

  @override
  String get updateUserCancelled => 'Benutzer abgebrochen';

  @override
  String get updateDownloadTitle => 'Update herunterladen';

  @override
  String updateDownloading(String percent) {
    return 'Herunterladen: $percent%';
  }

  @override
  String get updateDownloadBackgroundHint => 'Sie können die App in den Hintergrund legen, der Download wird fortgesetzt';

  @override
  String get updateCancelButton => 'Abbrechen';

  @override
  String get updateBackgroundDownload => 'Hintergrund-Download';

  @override
  String get updateLaterButton => 'Später';

  @override
  String get updateDownloadButton => 'Herunterladen';

  @override
  String get updateFoundCachedTitle => 'Heruntergeladene Version gefunden';

  @override
  String updateFoundCachedMessage(String path) {
    return 'Ein zuvor heruntergeladener Installer wurde gefunden, direkt installieren?\\n\\nKlicken Sie auf \"OK\" um sofort zu installieren, klicken Sie auf \"Abbrechen\" um diesen Dialog zu schließen.\\n\\nDateipfad: $path';
  }

  @override
  String get updateInstallingCachedApk => 'Installiere gecachte APK';

  @override
  String get updateDownloadComplete => 'Download abgeschlossen';

  @override
  String get updateInstallStarted => 'Download abgeschlossen, Installer gestartet';

  @override
  String get updateInstallFailed => 'Installation fehlgeschlagen';

  @override
  String get updateDownloadCompleteManual => 'Download abgeschlossen, kann manuell installiert werden';

  @override
  String get updateDownloadCompleteException => 'Download abgeschlossen, bitte manuell installieren (Dialog-Ausnahme)';

  @override
  String get updateDownloadCompleteManualContext => 'Download abgeschlossen, bitte manuell installieren';

  @override
  String get updateDownloadFailed => 'Download fehlgeschlagen';

  @override
  String get updateInstallTitle => 'Download abgeschlossen';

  @override
  String get updateInstallMessage => 'APK-Datei-Download abgeschlossen, sofort installieren?\\n\\nHinweis: Die App wird während der Installation vorübergehend in den Hintergrund gehen, das ist normal.';

  @override
  String get updateInstallNow => 'Jetzt installieren';

  @override
  String get updateInstallLater => 'Später installieren';

  @override
  String get updateNotificationTitle => 'BeeCount Update-Download';

  @override
  String get updateNotificationBody => 'Neue Version wird heruntergeladen...';

  @override
  String get updateNotificationComplete => 'Download abgeschlossen, tippen zum Installieren';

  @override
  String get updateNotificationPermissionTitle => 'Benachrichtigungsberechtigung verweigert';

  @override
  String get updateNotificationPermissionMessage => 'Benachrichtigungsberechtigung kann nicht erhalten werden, Download-Fortschritt wird nicht in der Benachrichtigungsleiste angezeigt, aber die Download-Funktion funktioniert normal.';

  @override
  String get updateNotificationGuideTitle => 'Wenn Sie Benachrichtigungen aktivieren müssen, folgen Sie diesen Schritten:';

  @override
  String get updateNotificationStep1 => 'Systemeinstellungen öffnen';

  @override
  String get updateNotificationStep2 => '\"App-Verwaltung\" oder \"App-Einstellungen\" finden';

  @override
  String get updateNotificationStep3 => '\"BeeCount\" App finden';

  @override
  String get updateNotificationStep4 => '\"Berechtigungsverwaltung\" oder \"Benachrichtigungsverwaltung\" klicken';

  @override
  String get updateNotificationStep5 => '\"Benachrichtigungsberechtigung\" aktivieren';

  @override
  String get updateNotificationMiuiHint => 'MIUI-Benutzer: Xiaomi-System hat strenge Benachrichtigungsberechtigungskontrolle, könnte zusätzliche Einstellungen im Sicherheitszentrum benötigen';

  @override
  String get updateNotificationGotIt => 'Verstanden';

  @override
  String get updateCheckFailedTitle => 'Update-Prüfung fehlgeschlagen';

  @override
  String get updateDownloadFailedTitle => 'Download fehlgeschlagen';

  @override
  String get updateGoToGitHub => 'Zu GitHub gehen';

  @override
  String get updateCannotOpenLink => 'Link kann nicht geöffnet werden';

  @override
  String get updateManualVisit => 'Bitte besuchen Sie manuell im Browser:\\nhttps://github.com/TNT-Likely/BeeCount/releases';

  @override
  String get updateNoLocalApkTitle => 'Kein Update-Paket gefunden';

  @override
  String get updateNoLocalApkMessage => 'Keine heruntergeladene Update-Paket-Datei gefunden.\\n\\nBitte laden Sie zuerst die neue Version über \"Nach Updates suchen\" herunter.';

  @override
  String get updateInstallPackageTitle => 'Update-Paket installieren';

  @override
  String get updateMultiplePackagesTitle => 'Mehrere Update-Pakete gefunden';

  @override
  String updateMultiplePackagesMessage(int count, String path) {
    return '$count Update-Paket-Dateien gefunden.\\n\\nEs wird empfohlen, die zuletzt heruntergeladene Version zu verwenden oder manuell im Dateimanager zu installieren.\\n\\nDateiort: $path';
  }

  @override
  String get updateSearchFailedTitle => 'Suche fehlgeschlagen';

  @override
  String updateSearchFailedMessage(String error) {
    return 'Fehler beim Suchen nach lokalen Update-Paketen: $error';
  }

  @override
  String get updateFoundCachedPackageTitle => 'Heruntergeladenes Update-Paket gefunden';

  @override
  String updateFoundCachedPackageMessage(String fileName, String fileSize) {
    return 'Zuvor heruntergeladenes Update-Paket erkannt:\\n\\nDateiname: $fileName\\nGröße: ${fileSize}MB\\n\\nSofort installieren?';
  }

  @override
  String get updateIgnoreButton => 'Ignorieren';

  @override
  String get updateInstallFailedTitle => 'Installation fehlgeschlagen';

  @override
  String get updateInstallFailedMessage => 'APK-Installer kann nicht gestartet werden, bitte Dateiberechtigungen überprüfen.';

  @override
  String get updateErrorTitle => 'Fehler';

  @override
  String updateReadCacheFailedMessage(String error) {
    return 'Fehler beim Lesen des gecachten Update-Pakets: $error';
  }

  @override
  String get updateCheckingPermissions => 'Berechtigungen prüfen...';

  @override
  String get updateCheckingCache => 'Lokalen Cache prüfen...';

  @override
  String get updatePreparingDownload => 'Download vorbereiten...';

  @override
  String get updateUserCancelledDownload => 'Benutzer hat Download abgebrochen';

  @override
  String get updateStartingInstaller => 'Installer starten...';

  @override
  String get updateInstallerStarted => 'Installer gestartet';

  @override
  String get updateInstallationFailed => 'Installation fehlgeschlagen';

  @override
  String get updateDownloadCompleted => 'Download abgeschlossen';

  @override
  String get updateDownloadCompletedManual => 'Download abgeschlossen, kann manuell installiert werden';

  @override
  String get updateDownloadCompletedDialog => 'Download abgeschlossen, bitte manuell installieren (Dialog-Ausnahme)';

  @override
  String get updateDownloadCompletedContext => 'Download abgeschlossen, bitte manuell installieren';

  @override
  String get updateDownloadFailedGeneric => 'Download fehlgeschlagen';

  @override
  String get updateCheckingUpdate => 'Nach Updates suchen...';

  @override
  String get updateCurrentLatestVersion => 'Sie haben bereits die neueste Version';

  @override
  String get updateCheckFailedGeneric => 'Update-Prüfung fehlgeschlagen';

  @override
  String updateDownloadProgress(String percent) {
    return 'Herunterladen: $percent%';
  }

  @override
  String get updateNoApkFoundError => 'APK-Download-Link nicht gefunden';

  @override
  String updateCheckingUpdateError(String error) {
    return 'Update-Prüfung fehlgeschlagen: $error';
  }

  @override
  String get updateNotificationChannelName => 'Update-Download';

  @override
  String get updateNotificationDownloadingIndeterminate => 'Neue Version wird heruntergeladen...';

  @override
  String updateNotificationDownloadingProgress(String progress) {
    return 'Download-Fortschritt: $progress%';
  }

  @override
  String get updateNotificationDownloadCompleteTitle => 'Download abgeschlossen';

  @override
  String get updateNotificationDownloadCompleteMessage => 'Neue Version heruntergeladen, tippen zum Installieren';

  @override
  String get updateUserCancelledDownloadDialog => 'Benutzer hat Download abgebrochen';

  @override
  String get updateCannotOpenLinkError => 'Link kann nicht geöffnet werden';

  @override
  String get updateNoLocalApkFoundMessage => 'Keine heruntergeladene Update-Paket-Datei gefunden.\\n\\nBitte laden Sie zuerst die neue Version über \"Nach Updates suchen\" herunter.';

  @override
  String updateInstallPackageFoundMessage(String fileName, String fileSize, String time) {
    return 'Update-Paket gefunden:\\n\\nDateiname: $fileName\\nGröße: ${fileSize}MB\\nDownload-Zeit: $time\\n\\nSofort installieren?';
  }

  @override
  String updateMultiplePackagesFoundMessage(int count, String path) {
    return '$count Update-Paket-Dateien gefunden.\\n\\nEs wird empfohlen, die zuletzt heruntergeladene Version zu verwenden oder manuell im Dateimanager zu installieren.\\n\\nDateiort: $path';
  }

  @override
  String updateSearchLocalApkError(String error) {
    return 'Fehler beim Suchen nach lokalen Update-Paketen: $error';
  }

  @override
  String updateCachedPackageFoundMessage(String fileName, String fileSize) {
    return 'Zuvor heruntergeladenes Update-Paket erkannt:\\n\\nDateiname: $fileName\\nGröße: ${fileSize}MB\\n\\nSofort installieren?';
  }

  @override
  String updateReadCachedPackageError(String error) {
    return 'Fehler beim Lesen des gecachten Update-Pakets: $error';
  }

  @override
  String get reminderQuickTestSent => 'Schnelltest für 15 Sekunden später eingestellt, bitte behalten Sie die App im Hintergrund';

  @override
  String get reminderFlutterTestSent => 'Flutter-Test-Benachrichtigung gesendet, klicken Sie um zu sehen, ob sie die App öffnet';

  @override
  String get reminderAlarmTestSent => 'AlarmManager-Test-Benachrichtigung eingestellt (1 Sekunde später), klicken Sie um zu sehen, ob sie die App öffnet';

  @override
  String get updateOk => 'OK';

  @override
  String get updateCannotOpenLinkTitle => 'Link kann nicht geöffnet werden';

  @override
  String get updateCachedVersionTitle => 'Heruntergeladene Version gefunden';

  @override
  String get updateCachedVersionMessage => 'Ein zuvor heruntergeladenes Installationspaket wurde gefunden... Klicken Sie auf \\\"OK\\\" um sofort zu installieren, klicken Sie auf \\\"Abbrechen\\\" um zu schließen...';

  @override
  String get updateConfirmDownload => 'Jetzt herunterladen und installieren';

  @override
  String get updateDownloadCompleteTitle => 'Download abgeschlossen';

  @override
  String get updateInstallConfirmMessage => 'Neue Version heruntergeladen. Jetzt installieren?';

  @override
  String get updateNotificationPermissionGuideText => 'Download-Fortschritt-Benachrichtigungen sind deaktiviert, aber das beeinträchtigt die Download-Funktionalität nicht. Um den Fortschritt zu sehen:';

  @override
  String get updateNotificationGuideStep1 => 'Gehen Sie zu Systemeinstellungen > App-Verwaltung';

  @override
  String get updateNotificationGuideStep2 => 'Finden Sie die \\\"BeeCount\\\" App';

  @override
  String get updateNotificationGuideStep3 => 'Benachrichtigungsberechtigungen aktivieren';

  @override
  String get updateNotificationGuideInfo => 'Downloads werden normal im Hintergrund fortgesetzt, auch ohne Benachrichtigungen';

  @override
  String get currencyCNY => 'Chinesischer Yuan';

  @override
  String get currencyUSD => 'US-Dollar';

  @override
  String get currencyEUR => 'Euro';

  @override
  String get currencyJPY => 'Japanischer Yen';

  @override
  String get currencyHKD => 'Hongkong-Dollar';

  @override
  String get currencyTWD => 'Neuer Taiwan-Dollar';

  @override
  String get currencyGBP => 'Britisches Pfund';

  @override
  String get currencyAUD => 'Australischer Dollar';

  @override
  String get currencyCAD => 'Kanadischer Dollar';

  @override
  String get currencyKRW => 'Südkoreanischer Won';

  @override
  String get currencySGD => 'Singapur-Dollar';

  @override
  String get currencyTHB => 'Thailändischer Baht';

  @override
  String get currencyIDR => 'Indonesische Rupiah';

  @override
  String get currencyINR => 'Indische Rupie';

  @override
  String get currencyRUB => 'Russischer Rubel';

  @override
  String get cloudDefaultServiceDisplayName => 'Standard-Cloud-Service';

  @override
  String get cloudNotConfiguredDisplay => 'Nicht konfiguriert';

  @override
  String get syncNotConfiguredMessage => 'Cloud nicht konfiguriert';

  @override
  String get syncNotLoggedInMessage => 'Nicht angemeldet';

  @override
  String get syncCloudBackupCorruptedMessage => 'Cloud-Backup-Inhalt ist beschädigt, möglicherweise aufgrund von Kodierungsproblemen früherer Versionen. Bitte klicken Sie auf \'Aktuelles Buch in Cloud hochladen\' um zu überschreiben und zu reparieren.';

  @override
  String get syncNoCloudBackupMessage => 'Kein Cloud-Backup';

  @override
  String get syncAccessDeniedMessage => '403 Zugriff verweigert (Speicher-RLS-Richtlinie und Pfad überprüfen)';
}
