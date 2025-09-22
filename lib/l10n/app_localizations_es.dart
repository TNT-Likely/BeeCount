import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Contabilidad Abeja';

  @override
  String get tabHome => 'Inicio';

  @override
  String get tabAnalytics => 'Gráficos';

  @override
  String get tabLedgers => 'Libros';

  @override
  String get tabMine => 'Mío';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonAdd => 'Agregar';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Sí';

  @override
  String get commonNo => 'No';

  @override
  String get commonLoading => 'Cargando...';

  @override
  String get commonEmpty => 'Sin datos';

  @override
  String get commonError => 'Error';

  @override
  String get commonSuccess => 'Éxito';

  @override
  String get commonFailed => 'Falló';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonBack => 'Atrás';

  @override
  String get commonNext => 'Siguiente';

  @override
  String get commonPrevious => 'Anterior';

  @override
  String get commonFinish => 'Finalizar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonCopy => 'Copiar';

  @override
  String get commonSearch => 'Buscar';

  @override
  String get commonNoteHint => 'Nota...';

  @override
  String get commonFilter => 'Filtrar';

  @override
  String get commonClear => 'Limpiar';

  @override
  String get commonSelectAll => 'Seleccionar todo';

  @override
  String get commonSettings => 'Configuración';

  @override
  String get commonHelp => 'Ayuda';

  @override
  String get commonAbout => 'Acerca de';

  @override
  String get commonLanguage => 'Idioma';

  @override
  String get commonWeekdayMonday => 'Lunes';

  @override
  String get commonWeekdayTuesday => 'Martes';

  @override
  String get commonWeekdayWednesday => 'Miércoles';

  @override
  String get commonWeekdayThursday => 'Jueves';

  @override
  String get commonWeekdayFriday => 'Viernes';

  @override
  String get commonWeekdaySaturday => 'Sábado';

  @override
  String get commonWeekdaySunday => 'Domingo';

  @override
  String get homeTitle => 'Contabilidad Abeja';

  @override
  String get homeIncome => 'Ingresos';

  @override
  String get homeExpense => 'Gastos';

  @override
  String get homeBalance => 'Balance';

  @override
  String get homeTotal => 'Total';

  @override
  String get homeAverage => 'Promedio';

  @override
  String get homeDailyAvg => 'Promedio diario';

  @override
  String get homeMonthlyAvg => 'Promedio mensual';

  @override
  String get homeNoRecords => 'No hay registros aún';

  @override
  String get homeAddRecord => 'Agregar registro tocando el botón más';

  @override
  String get homeHideAmounts => 'Ocultar montos';

  @override
  String get homeShowAmounts => 'Mostrar montos';

  @override
  String get homeSelectDate => 'Seleccionar fecha';

  @override
  String get homeAppTitle => 'Contabilidad Abeja';

  @override
  String get homeSearch => 'Buscar';

  @override
  String get homeShowAmount => 'Mostrar montos';

  @override
  String get homeHideAmount => 'Ocultar montos';

  @override
  String homeYear(int year) {
    return '$year';
  }

  @override
  String homeMonth(String month) {
    return '${month}M';
  }

  @override
  String get homeNoRecordsSubtext => 'Toca el botón más en la parte inferior para agregar un registro';

  @override
  String get searchTitle => 'Buscar';

  @override
  String get searchHint => 'Buscar notas, categorías o montos...';

  @override
  String get searchAmountRange => 'Filtro de rango de monto';

  @override
  String get searchMinAmount => 'Monto mínimo';

  @override
  String get searchMaxAmount => 'Monto máximo';

  @override
  String get searchTo => 'a';

  @override
  String get searchNoInput => 'Ingresa palabras clave para comenzar a buscar';

  @override
  String get searchNoResults => 'No se encontraron resultados coincidentes';

  @override
  String get searchResultsEmpty => 'No se encontraron resultados coincidentes';

  @override
  String get searchResultsEmptyHint => 'Prueba con otras palabras clave o ajusta las condiciones del filtro';

  @override
  String get analyticsTitle => 'Analíticas';

  @override
  String get analyticsMonth => 'Mes';

  @override
  String get analyticsYear => 'Año';

  @override
  String get analyticsAll => 'Todo';

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
  String get ledgersTitle => 'Libros de cuentas';

  @override
  String get ledgersNew => 'New Ledger';

  @override
  String get ledgersClear => 'Clear Current Ledger';

  @override
  String get ledgersClearConfirm => 'Clear current ledger?';

  @override
  String get ledgersClearMessage => 'All transaction records in this ledger will be deleted and cannot be recovered.';

  @override
  String get ledgersEdit => 'Editar libro';

  @override
  String get ledgersDelete => 'Eliminar libro';

  @override
  String get ledgersDeleteConfirm => '¿Estás seguro de que quieres eliminar este libro?';

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
  String get ledgersName => 'Nombre del libro';

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
  String get importTitle => 'Importar';

  @override
  String get importSelectFile => 'Seleccionar archivo';

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
  String get importFieldDate => 'Fecha';

  @override
  String get importFieldType => 'Tipo';

  @override
  String get importFieldAmount => 'Monto';

  @override
  String get importFieldCategory => 'Categoría';

  @override
  String get importFieldNote => 'Nota';

  @override
  String get importPreview => 'Vista previa';

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
    return 'Progreso de importación';
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
  String get importFailed => 'Importación fallida';

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
  String get mineTitle => 'Mío';

  @override
  String get mineSettings => 'Configuración';

  @override
  String get mineTheme => 'Tema';

  @override
  String get mineFont => 'Font Settings';

  @override
  String get mineReminder => 'Reminder Settings';

  @override
  String get mineData => 'Data Management';

  @override
  String get mineImport => 'Importar';

  @override
  String get mineExport => 'Exportar';

  @override
  String get mineCloud => 'Cloud Service';

  @override
  String get mineAbout => 'Acerca de';

  @override
  String get mineVersion => 'Versión';

  @override
  String get mineUpdate => 'Actualizar';

  @override
  String get mineLanguageSettings => 'Language Settings';

  @override
  String get mineLanguageSettingsSubtitle => 'Switch application language';

  @override
  String get languageTitle => 'Idioma';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystemDefault => 'Seguir sistema';

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
  String get mineCheckUpdate => 'Verificar actualizaciones';

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
  String get personalizeTitle => 'Personalizar';

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
  String get reminderTitle => 'Recordatorio de registro';

  @override
  String get reminderSubtitle => 'Establecer hora de recordatorio de registro diario';

  @override
  String get reminderDailyTitle => 'Recordatorio de registro diario';

  @override
  String get reminderDailySubtitle => 'Cuando esté habilitado, te recordará registrar a la hora especificada';

  @override
  String get reminderTimeTitle => 'Hora del recordatorio';

  @override
  String get reminderTestNotification => 'Enviar notificación de prueba';

  @override
  String get reminderTestSent => 'Notificación de prueba enviada';

  @override
  String get reminderQuickTest => 'Prueba rápida (15s después)';

  @override
  String get reminderQuickTestMessage => 'Quick test set for 15 seconds later, keep app in background';

  @override
  String get reminderFlutterTest => '🔧 Probar notificación de clic de Flutter (Dev)';

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
  String get exportTitle => 'Exportar';

  @override
  String get exportDescription => 'Haz clic en el botón de abajo para seleccionar la ubicación de guardado y exportar el libro actual a un archivo CSV.';

  @override
  String get exportButtonIOS => 'Exportar y compartir (iOS)';

  @override
  String get exportButtonAndroid => 'Seleccionar carpeta y exportar';

  @override
  String exportSavedTo(String path) {
    return 'Guardado en: $path';
  }

  @override
  String get exportSelectFolder => 'Seleccionar carpeta de exportación';

  @override
  String get exportCsvHeaderType => 'Tipo';

  @override
  String get exportCsvHeaderCategory => 'Categoría';

  @override
  String get exportCsvHeaderAmount => 'Monto';

  @override
  String get exportCsvHeaderNote => 'Nota';

  @override
  String get exportCsvHeaderTime => 'Hora';

  @override
  String get exportShareText => 'Archivo de exportación de BeeCount';

  @override
  String get exportSuccessTitle => 'Exportación exitosa';

  @override
  String exportSuccessMessageIOS(String path) {
    return 'Guardado y disponible en el historial de compartir:\n$path';
  }

  @override
  String exportSuccessMessageAndroid(String path) {
    return 'Guardado en:\n$path';
  }

  @override
  String get exportFailedTitle => 'Exportación fallida';

  @override
  String get exportTypeIncome => 'Ingreso';

  @override
  String get exportTypeExpense => 'Gasto';

  @override
  String get exportTypeTransfer => 'Transferencia';

  @override
  String get personalizeThemeHoney => 'Amarillo abeja';

  @override
  String get personalizeThemeOrange => 'Naranja llama';

  @override
  String get personalizeThemeGreen => 'Verde esmeralda';

  @override
  String get personalizeThemePurple => 'Loto púrpura';

  @override
  String get personalizeThemePink => 'Rosa cereza';

  @override
  String get personalizeThemeBlue => 'Azul cielo';

  @override
  String get personalizeThemeMint => 'Luna del bosque';

  @override
  String get personalizeThemeSand => 'Duna del atardecer';

  @override
  String get personalizeThemeLavender => 'Nieve y pino';

  @override
  String get personalizeThemeSky => 'País de las maravillas brumoso';

  @override
  String get personalizeThemeWarmOrange => 'Naranja cálido';

  @override
  String get personalizeThemeMintGreen => 'Verde menta';

  @override
  String get personalizeThemeRoseGold => 'Oro rosa';

  @override
  String get personalizeThemeDeepBlue => 'Azul profundo';

  @override
  String get personalizeThemeMapleRed => 'Rojo arce';

  @override
  String get personalizeThemeEmerald => 'Esmeralda';

  @override
  String get personalizeThemeLavenderPurple => 'Lavanda';

  @override
  String get personalizeThemeAmber => 'Ámbar';

  @override
  String get personalizeThemeRouge => 'Rojo bermellón';

  @override
  String get personalizeThemeIndigo => 'Azul índigo';

  @override
  String get personalizeThemeOlive => 'Verde oliva';

  @override
  String get personalizeThemeCoral => 'Rosa coral';

  @override
  String get personalizeThemeDarkGreen => 'Verde oscuro';

  @override
  String get personalizeThemeViolet => 'Violeta';

  @override
  String get personalizeThemeSunset => 'Naranja atardecer';

  @override
  String get personalizeThemePeacock => 'Azul pavo real';

  @override
  String get personalizeThemeLime => 'Verde lima';

  @override
  String get analyticsMonthlyAvg => 'Promedio mensual';

  @override
  String get analyticsDailyAvg => 'Promedio diario';

  @override
  String get analyticsOverallAvg => 'Promedio general';

  @override
  String get analyticsTotalIncome => 'Total de ingresos: ';

  @override
  String get analyticsTotalExpense => 'Total de gastos: ';

  @override
  String get analyticsBalance => 'Balance: ';

  @override
  String analyticsAvgIncome(String avgLabel) {
    return '$avgLabel ingresos: ';
  }

  @override
  String analyticsAvgExpense(String avgLabel) {
    return '$avgLabel gastos: ';
  }

  @override
  String get analyticsExpense => 'Gastos';

  @override
  String get analyticsIncome => 'Ingresos';

  @override
  String analyticsTotal(String type) {
    return 'Total $type: ';
  }

  @override
  String analyticsAverage(String avgLabel) {
    return '$avgLabel: ';
  }

  @override
  String get updateCheckTitle => 'Verificar actualización';

  @override
  String get updateNewVersionFound => 'Nueva versión encontrada';

  @override
  String updateNewVersionTitle(String version) {
    return 'Nueva versión $version encontrada';
  }

  @override
  String get updateNoApkFound => 'Enlace de descarga APK no encontrado';

  @override
  String get updateAlreadyLatest => 'Ya tienes la última versión';

  @override
  String get updateCheckFailed => 'Error al verificar actualización';

  @override
  String get updatePermissionDenied => 'Permiso denegado';

  @override
  String get updateUserCancelled => 'Usuario canceló';

  @override
  String get updateDownloadTitle => 'Descargar actualización';

  @override
  String updateDownloading(String percent) {
    return 'Descargando: $percent%';
  }

  @override
  String get updateDownloadBackgroundHint => 'Puedes poner la aplicación en segundo plano, la descarga continuará';

  @override
  String get updateCancelButton => 'Cancelar';

  @override
  String get updateBackgroundDownload => 'Descarga en segundo plano';

  @override
  String get updateLaterButton => 'Más tarde';

  @override
  String get updateDownloadButton => 'Descargar';

  @override
  String get updateFoundCachedTitle => 'Versión descargada encontrada';

  @override
  String updateFoundCachedMessage(String path) {
    return 'Se encontró un instalador descargado previamente, ¿instalar directamente?\\n\\nHaz clic en \"OK\" para instalar inmediatamente, haz clic en \"Cancelar\" para cerrar este diálogo.\\n\\nRuta del archivo: $path';
  }

  @override
  String get updateInstallingCachedApk => 'Instalando APK en caché';

  @override
  String get updateDownloadComplete => 'Descarga completa';

  @override
  String get updateInstallStarted => 'Descarga completa, instalador iniciado';

  @override
  String get updateInstallFailed => 'Instalación fallida';

  @override
  String get updateDownloadCompleteManual => 'Descarga completa, se puede instalar manualmente';

  @override
  String get updateDownloadCompleteException => 'Descarga completa, por favor instalar manualmente (excepción de diálogo)';

  @override
  String get updateDownloadCompleteManualContext => 'Descarga completa, por favor instalar manualmente';

  @override
  String get updateDownloadFailed => 'Descarga fallida';

  @override
  String get updateInstallTitle => 'Descarga completa';

  @override
  String get updateInstallMessage => 'Descarga del archivo APK completa, ¿instalar inmediatamente?\\n\\nNota: La aplicación irá temporalmente a segundo plano durante la instalación, esto es normal.';

  @override
  String get updateInstallNow => 'Instalar ahora';

  @override
  String get updateInstallLater => 'Instalar más tarde';

  @override
  String get updateNotificationTitle => 'Descarga de actualización de BeeCount';

  @override
  String get updateNotificationBody => 'Descargando nueva versión...';

  @override
  String get updateNotificationComplete => 'Descarga completa, toca para instalar';

  @override
  String get updateNotificationPermissionTitle => 'Permiso de notificación denegado';

  @override
  String get updateNotificationPermissionMessage => 'No se puede obtener el permiso de notificación, el progreso de descarga no se mostrará en la barra de notificaciones, pero la función de descarga funciona normalmente.';

  @override
  String get updateNotificationGuideTitle => 'Si necesitas habilitar las notificaciones, sigue estos pasos:';

  @override
  String get updateNotificationStep1 => 'Abrir configuración del sistema';

  @override
  String get updateNotificationStep2 => 'Buscar \"Gestión de aplicaciones\" o \"Configuración de aplicaciones\"';

  @override
  String get updateNotificationStep3 => 'Buscar la aplicación \"BeeCount\"';

  @override
  String get updateNotificationStep4 => 'Hacer clic en \"Gestión de permisos\" o \"Gestión de notificaciones\"';

  @override
  String get updateNotificationStep5 => 'Habilitar \"Permiso de notificación\"';

  @override
  String get updateNotificationMiuiHint => 'Usuarios de MIUI: El sistema Xiaomi tiene un control estricto de permisos de notificación, puede necesitar configuraciones adicionales en el Centro de seguridad';

  @override
  String get updateNotificationGotIt => 'Entendido';

  @override
  String get updateCheckFailedTitle => 'Error al verificar actualización';

  @override
  String get updateDownloadFailedTitle => 'Descarga fallida';

  @override
  String get updateGoToGitHub => 'Ir a GitHub';

  @override
  String get updateCannotOpenLink => 'No se puede abrir el enlace';

  @override
  String get updateManualVisit => 'Por favor visita manualmente en el navegador:\\nhttps://github.com/TNT-Likely/BeeCount/releases';

  @override
  String get updateNoLocalApkTitle => 'No se encontró paquete de actualización';

  @override
  String get updateNoLocalApkMessage => 'No se encontró archivo de paquete de actualización descargado.\\n\\nPor favor descarga primero la nueva versión a través de \"Verificar actualización\".';

  @override
  String get updateInstallPackageTitle => 'Instalar paquete de actualización';

  @override
  String get updateMultiplePackagesTitle => 'Se encontraron múltiples paquetes de actualización';

  @override
  String updateMultiplePackagesMessage(int count, String path) {
    return 'Se encontraron $count archivos de paquete de actualización.\\n\\nSe recomienda usar la versión descargada más reciente, o instalar manualmente en el administrador de archivos.\\n\\nUbicación del archivo: $path';
  }

  @override
  String get updateSearchFailedTitle => 'Búsqueda fallida';

  @override
  String updateSearchFailedMessage(String error) {
    return 'Ocurrió un error al buscar paquetes de actualización locales: $error';
  }

  @override
  String get updateFoundCachedPackageTitle => 'Paquete de actualización descargado encontrado';

  @override
  String updateFoundCachedPackageMessage(String fileName, String fileSize) {
    return 'Se detectó un paquete de actualización descargado previamente:\\n\\nNombre del archivo: $fileName\\nTamaño: ${fileSize}MB\\n\\n¿Instalar inmediatamente?';
  }

  @override
  String get updateIgnoreButton => 'Ignorar';

  @override
  String get updateInstallFailedTitle => 'Instalación fallida';

  @override
  String get updateInstallFailedMessage => 'No se puede iniciar el instalador APK, por favor verifica los permisos del archivo.';

  @override
  String get updateErrorTitle => 'Error';

  @override
  String updateReadCacheFailedMessage(String error) {
    return 'Error al leer el paquete de actualización en caché: $error';
  }

  @override
  String get updateCheckingPermissions => 'Verificando permisos...';

  @override
  String get updateCheckingCache => 'Verificando caché local...';

  @override
  String get updatePreparingDownload => 'Preparando descarga...';

  @override
  String get updateUserCancelledDownload => 'Usuario canceló la descarga';

  @override
  String get updateStartingInstaller => 'Iniciando instalador...';

  @override
  String get updateInstallerStarted => 'Instalador iniciado';

  @override
  String get updateInstallationFailed => 'Instalación fallida';

  @override
  String get updateDownloadCompleted => 'Descarga completada';

  @override
  String get updateDownloadCompletedManual => 'Descarga completada, se puede instalar manualmente';

  @override
  String get updateDownloadCompletedDialog => 'Descarga completada, por favor instalar manualmente (excepción de diálogo)';

  @override
  String get updateDownloadCompletedContext => 'Descarga completada, por favor instalar manualmente';

  @override
  String get updateDownloadFailedGeneric => 'Descarga fallida';

  @override
  String get updateCheckingUpdate => 'Verificando actualizaciones...';

  @override
  String get updateCurrentLatestVersion => 'Ya tienes la última versión';

  @override
  String get updateCheckFailedGeneric => 'Error al verificar actualización';

  @override
  String updateDownloadProgress(String percent) {
    return 'Descargando: $percent%';
  }

  @override
  String get updateNoApkFoundError => 'Enlace de descarga APK no encontrado';

  @override
  String updateCheckingUpdateError(String error) {
    return 'Error al verificar actualización: $error';
  }

  @override
  String get updateNotificationChannelName => 'Descarga de actualización';

  @override
  String get updateNotificationDownloadingIndeterminate => 'Descargando nueva versión...';

  @override
  String updateNotificationDownloadingProgress(String progress) {
    return 'Progreso de descarga: $progress%';
  }

  @override
  String get updateNotificationDownloadCompleteTitle => 'Descarga completa';

  @override
  String get updateNotificationDownloadCompleteMessage => 'Nueva versión descargada, toca para instalar';

  @override
  String get updateUserCancelledDownloadDialog => 'Usuario canceló la descarga';

  @override
  String get updateCannotOpenLinkError => 'No se puede abrir el enlace';

  @override
  String get updateNoLocalApkFoundMessage => 'No se encontró archivo de paquete de actualización descargado.\\n\\nPor favor descarga primero la nueva versión a través de \"Verificar actualización\".';

  @override
  String updateInstallPackageFoundMessage(String fileName, String fileSize, String time) {
    return 'Paquete de actualización encontrado:\\n\\nNombre del archivo: $fileName\\nTamaño: ${fileSize}MB\\nHora de descarga: $time\\n\\n¿Instalar inmediatamente?';
  }

  @override
  String updateMultiplePackagesFoundMessage(int count, String path) {
    return 'Se encontraron $count archivos de paquete de actualización.\\n\\nSe recomienda usar la versión descargada más reciente, o instalar manualmente en el administrador de archivos.\\n\\nUbicación del archivo: $path';
  }

  @override
  String updateSearchLocalApkError(String error) {
    return 'Ocurrió un error al buscar paquetes de actualización locales: $error';
  }

  @override
  String updateCachedPackageFoundMessage(String fileName, String fileSize) {
    return 'Se detectó un paquete de actualización descargado previamente:\\n\\nNombre del archivo: $fileName\\nTamaño: ${fileSize}MB\\n\\n¿Instalar inmediatamente?';
  }

  @override
  String updateReadCachedPackageError(String error) {
    return 'Error al leer el paquete de actualización en caché: $error';
  }

  @override
  String get reminderQuickTestSent => 'Prueba rápida configurada para 15 segundos después, por favor mantén la aplicación en segundo plano';

  @override
  String get reminderFlutterTestSent => 'Notificación de prueba de Flutter enviada, haz clic para ver si abre la aplicación';

  @override
  String get reminderAlarmTestSent => 'Notificación de prueba de AlarmManager configurada (1 segundo después), haz clic para ver si abre la aplicación';

  @override
  String get updateOk => 'OK';

  @override
  String get updateCannotOpenLinkTitle => 'No se puede abrir el enlace';

  @override
  String get updateCachedVersionTitle => 'Versión descargada encontrada';

  @override
  String get updateCachedVersionMessage => 'Se encontró un paquete de instalación descargado previamente... Haz clic en \\\"OK\\\" para instalar inmediatamente, haz clic en \\\"Cancelar\\\" para cerrar...';

  @override
  String get updateConfirmDownload => 'Descargar e instalar ahora';

  @override
  String get updateDownloadCompleteTitle => 'Descarga completa';

  @override
  String get updateInstallConfirmMessage => 'Nueva versión descargada. ¿Instalar ahora?';

  @override
  String get updateNotificationPermissionGuideText => 'Las notificaciones de progreso de descarga están deshabilitadas, pero esto no afecta la funcionalidad de descarga. Para ver el progreso:';

  @override
  String get updateNotificationGuideStep1 => 'Ir a Configuración del sistema > Gestión de aplicaciones';

  @override
  String get updateNotificationGuideStep2 => 'Buscar la aplicación \\\"BeeCount\\\"';

  @override
  String get updateNotificationGuideStep3 => 'Habilitar permisos de notificación';

  @override
  String get updateNotificationGuideInfo => 'Las descargas continuarán normalmente en segundo plano incluso sin notificaciones';

  @override
  String get currencyCNY => 'Yuan chino';

  @override
  String get currencyUSD => 'Dólar estadounidense';

  @override
  String get currencyEUR => 'Euro';

  @override
  String get currencyJPY => 'Yen japonés';

  @override
  String get currencyHKD => 'Dólar de Hong Kong';

  @override
  String get currencyTWD => 'Nuevo dólar taiwanés';

  @override
  String get currencyGBP => 'Libra esterlina';

  @override
  String get currencyAUD => 'Dólar australiano';

  @override
  String get currencyCAD => 'Dólar canadiense';

  @override
  String get currencyKRW => 'Won surcoreano';

  @override
  String get currencySGD => 'Dólar de Singapur';

  @override
  String get currencyTHB => 'Baht tailandés';

  @override
  String get currencyIDR => 'Rupia indonesia';

  @override
  String get currencyINR => 'Rupia india';

  @override
  String get currencyRUB => 'Rublo ruso';

  @override
  String get cloudDefaultServiceDisplayName => 'Servicio de nube predeterminado';

  @override
  String get cloudNotConfiguredDisplay => 'No configurado';

  @override
  String get syncNotConfiguredMessage => 'Nube no configurada';

  @override
  String get syncNotLoggedInMessage => 'No conectado';

  @override
  String get syncCloudBackupCorruptedMessage => 'El contenido de la copia de seguridad en la nube está corrupto, posiblemente debido a problemas de codificación de versiones anteriores. Por favor haz clic en \'Subir libro actual a la nube\' para sobrescribir y corregir.';

  @override
  String get syncNoCloudBackupMessage => 'Sin copia de seguridad en la nube';

  @override
  String get syncAccessDeniedMessage => '403 Acceso denegado (verificar política RLS de almacenamiento y ruta)';
}
