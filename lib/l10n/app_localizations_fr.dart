import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Comptabilité Abeille';

  @override
  String get tabHome => 'Accueil';

  @override
  String get tabAnalytics => 'Graphiques';

  @override
  String get tabLedgers => 'Livres';

  @override
  String get tabMine => 'Mon';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonAdd => 'Ajouter';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Oui';

  @override
  String get commonNo => 'Non';

  @override
  String get commonLoading => 'Chargement...';

  @override
  String get commonEmpty => 'Aucune donnée';

  @override
  String get commonError => 'Erreur';

  @override
  String get commonSuccess => 'Succès';

  @override
  String get commonFailed => 'Échec';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonNext => 'Suivant';

  @override
  String get commonPrevious => 'Précédent';

  @override
  String get commonFinish => 'Terminer';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonCopy => 'Copier';

  @override
  String get commonSearch => 'Rechercher';

  @override
  String get commonNoteHint => 'Note...';

  @override
  String get commonFilter => 'Filtrer';

  @override
  String get commonClear => 'Effacer';

  @override
  String get commonSelectAll => 'Tout sélectionner';

  @override
  String get commonSettings => 'Paramètres';

  @override
  String get commonHelp => 'Aide';

  @override
  String get commonAbout => 'À propos';

  @override
  String get commonLanguage => 'Langue';

  @override
  String get commonWeekdayMonday => 'Lundi';

  @override
  String get commonWeekdayTuesday => 'Mardi';

  @override
  String get commonWeekdayWednesday => 'Mercredi';

  @override
  String get commonWeekdayThursday => 'Jeudi';

  @override
  String get commonWeekdayFriday => 'Vendredi';

  @override
  String get commonWeekdaySaturday => 'Samedi';

  @override
  String get commonWeekdaySunday => 'Dimanche';

  @override
  String get homeTitle => 'Comptabilité Abeille';

  @override
  String get homeIncome => 'Revenus';

  @override
  String get homeExpense => 'Dépenses';

  @override
  String get homeBalance => 'Solde';

  @override
  String get homeTotal => 'Total';

  @override
  String get homeAverage => 'Moyenne';

  @override
  String get homeDailyAvg => 'Moyenne quotidienne';

  @override
  String get homeMonthlyAvg => 'Moyenne mensuelle';

  @override
  String get homeNoRecords => 'Aucun enregistrement';

  @override
  String get homeAddRecord => 'Ajouter un enregistrement en appuyant sur le bouton plus';

  @override
  String get homeHideAmounts => 'Masquer les montants';

  @override
  String get homeShowAmounts => 'Afficher les montants';

  @override
  String get homeSelectDate => 'Sélectionner la date';

  @override
  String get homeAppTitle => 'Comptabilité Abeille';

  @override
  String get homeSearch => 'Rechercher';

  @override
  String get homeShowAmount => 'Afficher les montants';

  @override
  String get homeHideAmount => 'Masquer les montants';

  @override
  String homeYear(int year) {
    return '$year';
  }

  @override
  String homeMonth(String month) {
    return '${month}M';
  }

  @override
  String get homeNoRecordsSubtext => 'Appuyez sur le bouton plus en bas pour ajouter un enregistrement';

  @override
  String get searchTitle => 'Rechercher';

  @override
  String get searchHint => 'Rechercher notes, catégories ou montants...';

  @override
  String get searchAmountRange => 'Filtre de plage de montant';

  @override
  String get searchMinAmount => 'Montant minimum';

  @override
  String get searchMaxAmount => 'Montant maximum';

  @override
  String get searchTo => 'à';

  @override
  String get searchNoInput => 'Entrez des mots-clés pour commencer la recherche';

  @override
  String get searchNoResults => 'Aucun résultat correspondant trouvé';

  @override
  String get searchResultsEmpty => 'Aucun résultat correspondant trouvé';

  @override
  String get searchResultsEmptyHint => 'Essayez d\'autres mots-clés ou ajustez les conditions de filtre';

  @override
  String get analyticsTitle => 'Analyses';

  @override
  String get analyticsMonth => 'Mois';

  @override
  String get analyticsYear => 'Année';

  @override
  String get analyticsAll => 'Tout';

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
  String get ledgersTitle => 'Livres de comptes';

  @override
  String get ledgersNew => 'New Ledger';

  @override
  String get ledgersClear => 'Clear Current Ledger';

  @override
  String get ledgersClearConfirm => 'Clear current ledger?';

  @override
  String get ledgersClearMessage => 'All transaction records in this ledger will be deleted and cannot be recovered.';

  @override
  String get ledgersEdit => 'Modifier le livre';

  @override
  String get ledgersDelete => 'Supprimer le livre';

  @override
  String get ledgersDeleteConfirm => 'Êtes-vous sûr de vouloir supprimer ce livre ?';

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
  String get ledgersName => 'Nom du livre';

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
  String get importTitle => 'Importer';

  @override
  String get importSelectFile => 'Sélectionner le fichier';

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
  String get importFieldDate => 'Date';

  @override
  String get importFieldType => 'Type';

  @override
  String get importFieldAmount => 'Montant';

  @override
  String get importFieldCategory => 'Catégorie';

  @override
  String get importFieldNote => 'Note';

  @override
  String get importPreview => 'Aperçu';

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
    return 'Progression de l\'importation';
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
  String get importFailed => 'Importation échouée';

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
  String get mineTitle => 'Mon';

  @override
  String get mineSettings => 'Paramètres';

  @override
  String get mineTheme => 'Thème';

  @override
  String get mineFont => 'Font Settings';

  @override
  String get mineReminder => 'Reminder Settings';

  @override
  String get mineData => 'Data Management';

  @override
  String get mineImport => 'Importer';

  @override
  String get mineExport => 'Exporter';

  @override
  String get mineCloud => 'Cloud Service';

  @override
  String get mineAbout => 'À propos';

  @override
  String get mineVersion => 'Version';

  @override
  String get mineUpdate => 'Mettre à jour';

  @override
  String get mineLanguageSettings => 'Language Settings';

  @override
  String get mineLanguageSettingsSubtitle => 'Switch application language';

  @override
  String get languageTitle => 'Langue';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystemDefault => 'Suivre le système';

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
  String get mineCheckUpdate => 'Vérifier les mises à jour';

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
  String get personalizeTitle => 'Personnaliser';

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
  String get reminderTitle => 'Rappel d\'enregistrement';

  @override
  String get reminderSubtitle => 'Définir l\'heure de rappel d\'enregistrement quotidien';

  @override
  String get reminderDailyTitle => 'Rappel d\'enregistrement quotidien';

  @override
  String get reminderDailySubtitle => 'Lorsqu\'activé, vous rappellera d\'enregistrer à l\'heure spécifiée';

  @override
  String get reminderTimeTitle => 'Heure du rappel';

  @override
  String get reminderTestNotification => 'Envoyer une notification de test';

  @override
  String get reminderTestSent => 'Notification de test envoyée';

  @override
  String get reminderQuickTest => 'Test rapide (15s plus tard)';

  @override
  String get reminderQuickTestMessage => 'Quick test set for 15 seconds later, keep app in background';

  @override
  String get reminderFlutterTest => '🔧 Tester la notification de clic Flutter (Dev)';

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
  String get exportTitle => 'Exporter';

  @override
  String get exportDescription => 'Cliquez sur le bouton ci-dessous pour sélectionner l\'emplacement de sauvegarde et exporter le livre actuel vers un fichier CSV.';

  @override
  String get exportButtonIOS => 'Exporter et partager (iOS)';

  @override
  String get exportButtonAndroid => 'Sélectionner le dossier et exporter';

  @override
  String exportSavedTo(String path) {
    return 'Enregistré dans : $path';
  }

  @override
  String get exportSelectFolder => 'Sélectionner le dossier d\'exportation';

  @override
  String get exportCsvHeaderType => 'Type';

  @override
  String get exportCsvHeaderCategory => 'Catégorie';

  @override
  String get exportCsvHeaderAmount => 'Montant';

  @override
  String get exportCsvHeaderNote => 'Note';

  @override
  String get exportCsvHeaderTime => 'Heure';

  @override
  String get exportShareText => 'Fichier d\'exportation BeeCount';

  @override
  String get exportSuccessTitle => 'Exportation réussie';

  @override
  String exportSuccessMessageIOS(String path) {
    return 'Enregistré et disponible dans l\'historique de partage :\n$path';
  }

  @override
  String exportSuccessMessageAndroid(String path) {
    return 'Enregistré dans :\n$path';
  }

  @override
  String get exportFailedTitle => 'Exportation échouée';

  @override
  String get exportTypeIncome => 'Revenu';

  @override
  String get exportTypeExpense => 'Dépense';

  @override
  String get exportTypeTransfer => 'Transfert';

  @override
  String get personalizeThemeHoney => 'Jaune abeille';

  @override
  String get personalizeThemeOrange => 'Orange flamme';

  @override
  String get personalizeThemeGreen => 'Vert émeraude';

  @override
  String get personalizeThemePurple => 'Lotus violet';

  @override
  String get personalizeThemePink => 'Rose cerise';

  @override
  String get personalizeThemeBlue => 'Bleu ciel';

  @override
  String get personalizeThemeMint => 'Lune de forêt';

  @override
  String get personalizeThemeSand => 'Dune du coucher de soleil';

  @override
  String get personalizeThemeLavender => 'Neige et pin';

  @override
  String get personalizeThemeSky => 'Pays des merveilles brumeux';

  @override
  String get personalizeThemeWarmOrange => 'Orange chaud';

  @override
  String get personalizeThemeMintGreen => 'Vert menthe';

  @override
  String get personalizeThemeRoseGold => 'Or rose';

  @override
  String get personalizeThemeDeepBlue => 'Bleu profond';

  @override
  String get personalizeThemeMapleRed => 'Rouge érable';

  @override
  String get personalizeThemeEmerald => 'Émeraude';

  @override
  String get personalizeThemeLavenderPurple => 'Lavande';

  @override
  String get personalizeThemeAmber => 'Ambre';

  @override
  String get personalizeThemeRouge => 'Rouge vermillon';

  @override
  String get personalizeThemeIndigo => 'Bleu indigo';

  @override
  String get personalizeThemeOlive => 'Vert olive';

  @override
  String get personalizeThemeCoral => 'Rose corail';

  @override
  String get personalizeThemeDarkGreen => 'Vert foncé';

  @override
  String get personalizeThemeViolet => 'Violet';

  @override
  String get personalizeThemeSunset => 'Orange coucher de soleil';

  @override
  String get personalizeThemePeacock => 'Bleu paon';

  @override
  String get personalizeThemeLime => 'Vert citron';

  @override
  String get analyticsMonthlyAvg => 'Moyenne mensuelle';

  @override
  String get analyticsDailyAvg => 'Moyenne quotidienne';

  @override
  String get analyticsOverallAvg => 'Moyenne générale';

  @override
  String get analyticsTotalIncome => 'Total des revenus : ';

  @override
  String get analyticsTotalExpense => 'Total des dépenses : ';

  @override
  String get analyticsBalance => 'Solde : ';

  @override
  String analyticsAvgIncome(String avgLabel) {
    return '$avgLabel revenus : ';
  }

  @override
  String analyticsAvgExpense(String avgLabel) {
    return '$avgLabel dépenses : ';
  }

  @override
  String get analyticsExpense => 'Dépenses';

  @override
  String get analyticsIncome => 'Revenus';

  @override
  String analyticsTotal(String type) {
    return 'Total $type : ';
  }

  @override
  String analyticsAverage(String avgLabel) {
    return '$avgLabel : ';
  }

  @override
  String get updateCheckTitle => 'Vérifier les mises à jour';

  @override
  String get updateNewVersionFound => 'Nouvelle version trouvée';

  @override
  String updateNewVersionTitle(String version) {
    return 'Nouvelle version $version trouvée';
  }

  @override
  String get updateNoApkFound => 'Lien de téléchargement APK non trouvé';

  @override
  String get updateAlreadyLatest => 'Vous avez déjà la dernière version';

  @override
  String get updateCheckFailed => 'Erreur lors de la vérification des mises à jour';

  @override
  String get updatePermissionDenied => 'Permission refusée';

  @override
  String get updateUserCancelled => 'Utilisateur annulé';

  @override
  String get updateDownloadTitle => 'Télécharger la mise à jour';

  @override
  String updateDownloading(String percent) {
    return 'Téléchargement : $percent%';
  }

  @override
  String get updateDownloadBackgroundHint => 'Vous pouvez mettre l\'application en arrière-plan, le téléchargement continuera';

  @override
  String get updateCancelButton => 'Annuler';

  @override
  String get updateBackgroundDownload => 'Téléchargement en arrière-plan';

  @override
  String get updateLaterButton => 'Plus tard';

  @override
  String get updateDownloadButton => 'Télécharger';

  @override
  String get updateFoundCachedTitle => 'Version téléchargée trouvée';

  @override
  String updateFoundCachedMessage(String path) {
    return 'Un installateur téléchargé précédemment a été trouvé, installer directement ?\\n\\nCliquez sur \"OK\" pour installer immédiatement, cliquez sur \"Annuler\" pour fermer cette boîte de dialogue.\\n\\nChemin du fichier : $path';
  }

  @override
  String get updateInstallingCachedApk => 'Installation de l\'APK en cache';

  @override
  String get updateDownloadComplete => 'Téléchargement terminé';

  @override
  String get updateInstallStarted => 'Téléchargement terminé, installateur démarré';

  @override
  String get updateInstallFailed => 'Installation échouée';

  @override
  String get updateDownloadCompleteManual => 'Téléchargement terminé, peut être installé manuellement';

  @override
  String get updateDownloadCompleteException => 'Téléchargement terminé, veuillez installer manuellement (exception de dialogue)';

  @override
  String get updateDownloadCompleteManualContext => 'Téléchargement terminé, veuillez installer manuellement';

  @override
  String get updateDownloadFailed => 'Téléchargement échoué';

  @override
  String get updateInstallTitle => 'Téléchargement terminé';

  @override
  String get updateInstallMessage => 'Téléchargement du fichier APK terminé, installer immédiatement ?\\n\\nNote : L\'application ira temporairement en arrière-plan pendant l\'installation, c\'est normal.';

  @override
  String get updateInstallNow => 'Installer maintenant';

  @override
  String get updateInstallLater => 'Installer plus tard';

  @override
  String get updateNotificationTitle => 'Téléchargement de mise à jour BeeCount';

  @override
  String get updateNotificationBody => 'Téléchargement de la nouvelle version...';

  @override
  String get updateNotificationComplete => 'Téléchargement terminé, appuyez pour installer';

  @override
  String get updateNotificationPermissionTitle => 'Permission de notification refusée';

  @override
  String get updateNotificationPermissionMessage => 'Impossible d\'obtenir la permission de notification, la progression du téléchargement ne s\'affichera pas dans la barre de notification, mais la fonction de téléchargement fonctionne normalement.';

  @override
  String get updateNotificationGuideTitle => 'Si vous devez activer les notifications, suivez ces étapes :';

  @override
  String get updateNotificationStep1 => 'Ouvrir les paramètres système';

  @override
  String get updateNotificationStep2 => 'Trouver \"Gestion d\'applications\" ou \"Paramètres d\'applications\"';

  @override
  String get updateNotificationStep3 => 'Trouver l\'application \"BeeCount\"';

  @override
  String get updateNotificationStep4 => 'Cliquer sur \"Gestion des permissions\" ou \"Gestion des notifications\"';

  @override
  String get updateNotificationStep5 => 'Activer \"Permission de notification\"';

  @override
  String get updateNotificationMiuiHint => 'Utilisateurs MIUI : Le système Xiaomi a un contrôle strict des permissions de notification, peut nécessiter des paramètres supplémentaires dans le Centre de sécurité';

  @override
  String get updateNotificationGotIt => 'Compris';

  @override
  String get updateCheckFailedTitle => 'Erreur lors de la vérification des mises à jour';

  @override
  String get updateDownloadFailedTitle => 'Téléchargement échoué';

  @override
  String get updateGoToGitHub => 'Aller sur GitHub';

  @override
  String get updateCannotOpenLink => 'Impossible d\'ouvrir le lien';

  @override
  String get updateManualVisit => 'Veuillez visiter manuellement dans le navigateur :\\nhttps://github.com/TNT-Likely/BeeCount/releases';

  @override
  String get updateNoLocalApkTitle => 'Aucun package de mise à jour trouvé';

  @override
  String get updateNoLocalApkMessage => 'Aucun fichier de package de mise à jour téléchargé trouvé.\\n\\nVeuillez d\'abord télécharger la nouvelle version via \"Vérifier les mises à jour\".';

  @override
  String get updateInstallPackageTitle => 'Installer le package de mise à jour';

  @override
  String get updateMultiplePackagesTitle => 'Plusieurs packages de mise à jour trouvés';

  @override
  String updateMultiplePackagesMessage(int count, String path) {
    return '$count fichiers de package de mise à jour trouvés.\\n\\nIl est recommandé d\'utiliser la version téléchargée la plus récente, ou d\'installer manuellement dans le gestionnaire de fichiers.\\n\\nEmplacement du fichier : $path';
  }

  @override
  String get updateSearchFailedTitle => 'Recherche échouée';

  @override
  String updateSearchFailedMessage(String error) {
    return 'Une erreur s\'est produite lors de la recherche de packages de mise à jour locaux : $error';
  }

  @override
  String get updateFoundCachedPackageTitle => 'Package de mise à jour téléchargé trouvé';

  @override
  String updateFoundCachedPackageMessage(String fileName, String fileSize) {
    return 'Package de mise à jour téléchargé précédemment détecté :\\n\\nNom du fichier : $fileName\\nTaille : ${fileSize}MB\\n\\nInstaller immédiatement ?';
  }

  @override
  String get updateIgnoreButton => 'Ignorer';

  @override
  String get updateInstallFailedTitle => 'Installation échouée';

  @override
  String get updateInstallFailedMessage => 'Impossible de démarrer l\'installateur APK, veuillez vérifier les permissions du fichier.';

  @override
  String get updateErrorTitle => 'Erreur';

  @override
  String updateReadCacheFailedMessage(String error) {
    return 'Erreur lors de la lecture du package de mise à jour en cache : $error';
  }

  @override
  String get updateCheckingPermissions => 'Vérification des permissions...';

  @override
  String get updateCheckingCache => 'Vérification du cache local...';

  @override
  String get updatePreparingDownload => 'Préparation du téléchargement...';

  @override
  String get updateUserCancelledDownload => 'Utilisateur a annulé le téléchargement';

  @override
  String get updateStartingInstaller => 'Démarrage de l\'installateur...';

  @override
  String get updateInstallerStarted => 'Installateur démarré';

  @override
  String get updateInstallationFailed => 'Installation échouée';

  @override
  String get updateDownloadCompleted => 'Téléchargement terminé';

  @override
  String get updateDownloadCompletedManual => 'Téléchargement terminé, peut être installé manuellement';

  @override
  String get updateDownloadCompletedDialog => 'Téléchargement terminé, veuillez installer manuellement (exception de dialogue)';

  @override
  String get updateDownloadCompletedContext => 'Téléchargement terminé, veuillez installer manuellement';

  @override
  String get updateDownloadFailedGeneric => 'Téléchargement échoué';

  @override
  String get updateCheckingUpdate => 'Vérification des mises à jour...';

  @override
  String get updateCurrentLatestVersion => 'Vous avez déjà la dernière version';

  @override
  String get updateCheckFailedGeneric => 'Erreur lors de la vérification des mises à jour';

  @override
  String updateDownloadProgress(String percent) {
    return 'Téléchargement : $percent%';
  }

  @override
  String get updateNoApkFoundError => 'Lien de téléchargement APK non trouvé';

  @override
  String updateCheckingUpdateError(String error) {
    return 'Erreur lors de la vérification des mises à jour : $error';
  }

  @override
  String get updateNotificationChannelName => 'Téléchargement de mise à jour';

  @override
  String get updateNotificationDownloadingIndeterminate => 'Téléchargement de la nouvelle version...';

  @override
  String updateNotificationDownloadingProgress(String progress) {
    return 'Progression du téléchargement : $progress%';
  }

  @override
  String get updateNotificationDownloadCompleteTitle => 'Téléchargement terminé';

  @override
  String get updateNotificationDownloadCompleteMessage => 'Nouvelle version téléchargée, appuyez pour installer';

  @override
  String get updateUserCancelledDownloadDialog => 'Utilisateur a annulé le téléchargement';

  @override
  String get updateCannotOpenLinkError => 'Impossible d\'ouvrir le lien';

  @override
  String get updateNoLocalApkFoundMessage => 'Aucun fichier de package de mise à jour téléchargé trouvé.\\n\\nVeuillez d\'abord télécharger la nouvelle version via \"Vérifier les mises à jour\".';

  @override
  String updateInstallPackageFoundMessage(String fileName, String fileSize, String time) {
    return 'Package de mise à jour trouvé :\\n\\nNom du fichier : $fileName\\nTaille : ${fileSize}MB\\nHeure de téléchargement : $time\\n\\nInstaller immédiatement ?';
  }

  @override
  String updateMultiplePackagesFoundMessage(int count, String path) {
    return '$count fichiers de package de mise à jour trouvés.\\n\\nIl est recommandé d\'utiliser la version téléchargée la plus récente, ou d\'installer manuellement dans le gestionnaire de fichiers.\\n\\nEmplacement du fichier : $path';
  }

  @override
  String updateSearchLocalApkError(String error) {
    return 'Une erreur s\'est produite lors de la recherche de packages de mise à jour locaux : $error';
  }

  @override
  String updateCachedPackageFoundMessage(String fileName, String fileSize) {
    return 'Package de mise à jour téléchargé précédemment détecté :\\n\\nNom du fichier : $fileName\\nTaille : ${fileSize}MB\\n\\nInstaller immédiatement ?';
  }

  @override
  String updateReadCachedPackageError(String error) {
    return 'Erreur lors de la lecture du package de mise à jour en cache : $error';
  }

  @override
  String get reminderQuickTestSent => 'Test rapide défini pour 15 secondes plus tard, veuillez garder l\'application en arrière-plan';

  @override
  String get reminderFlutterTestSent => 'Notification de test Flutter envoyée, cliquez pour voir si elle ouvre l\'application';

  @override
  String get reminderAlarmTestSent => 'Notification de test AlarmManager définie (1 seconde plus tard), cliquez pour voir si elle ouvre l\'application';

  @override
  String get updateOk => 'OK';

  @override
  String get updateCannotOpenLinkTitle => 'Impossible d\'ouvrir le lien';

  @override
  String get updateCachedVersionTitle => 'Version téléchargée trouvée';

  @override
  String get updateCachedVersionMessage => 'Un package d\'installation téléchargé précédemment a été trouvé... Cliquez sur \\\"OK\\\" pour installer immédiatement, cliquez sur \\\"Annuler\\\" pour fermer...';

  @override
  String get updateConfirmDownload => 'Télécharger et installer maintenant';

  @override
  String get updateDownloadCompleteTitle => 'Téléchargement terminé';

  @override
  String get updateInstallConfirmMessage => 'Nouvelle version téléchargée. Installer maintenant ?';

  @override
  String get updateNotificationPermissionGuideText => 'Les notifications de progression de téléchargement sont désactivées, mais cela n\'affecte pas la fonctionnalité de téléchargement. Pour voir la progression :';

  @override
  String get updateNotificationGuideStep1 => 'Aller dans Paramètres système > Gestion d\'applications';

  @override
  String get updateNotificationGuideStep2 => 'Trouver l\'application \\\"BeeCount\\\"';

  @override
  String get updateNotificationGuideStep3 => 'Activer les permissions de notification';

  @override
  String get updateNotificationGuideInfo => 'Les téléchargements continueront normalement en arrière-plan même sans notifications';

  @override
  String get currencyCNY => 'Yuan chinois';

  @override
  String get currencyUSD => 'Dollar américain';

  @override
  String get currencyEUR => 'Euro';

  @override
  String get currencyJPY => 'Yen japonais';

  @override
  String get currencyHKD => 'Dollar de Hong Kong';

  @override
  String get currencyTWD => 'Nouveau dollar taïwanais';

  @override
  String get currencyGBP => 'Livre sterling';

  @override
  String get currencyAUD => 'Dollar australien';

  @override
  String get currencyCAD => 'Dollar canadien';

  @override
  String get currencyKRW => 'Won sud-coréen';

  @override
  String get currencySGD => 'Dollar de Singapour';

  @override
  String get currencyTHB => 'Baht thaïlandais';

  @override
  String get currencyIDR => 'Roupie indonésienne';

  @override
  String get currencyINR => 'Roupie indienne';

  @override
  String get currencyRUB => 'Rouble russe';

  @override
  String get cloudDefaultServiceDisplayName => 'Service cloud par défaut';

  @override
  String get cloudNotConfiguredDisplay => 'Non configuré';

  @override
  String get syncNotConfiguredMessage => 'Cloud non configuré';

  @override
  String get syncNotLoggedInMessage => 'Non connecté';

  @override
  String get syncCloudBackupCorruptedMessage => 'Le contenu de la sauvegarde cloud est corrompu, possiblement dû à des problèmes d\'encodage des versions antérieures. Veuillez cliquer sur \'Télécharger le livre actuel vers le cloud\' pour écraser et corriger.';

  @override
  String get syncNoCloudBackupMessage => 'Aucune sauvegarde cloud';

  @override
  String get syncAccessDeniedMessage => '403 Accès refusé (vérifier la politique RLS de stockage et le chemin)';
}
