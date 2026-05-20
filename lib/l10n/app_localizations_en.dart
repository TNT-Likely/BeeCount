import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Bee Accounting';

  @override
  String get tabHome => 'Home';

  @override
  String get tabInsights => 'Stats';

  @override
  String get tabAssets => 'Assets';

  @override
  String get tabRecord => 'Record';

  @override
  String get tabMine => 'Mine';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonMore => 'More';

  @override
  String get commonOk => 'OK';

  @override
  String get commonKnow => 'Got it';

  @override
  String get commonNo => 'No';

  @override
  String get commonEmpty => 'No data';

  @override
  String get commonError => 'Error';

  @override
  String get commonSuccess => 'Success';

  @override
  String get commonFailed => 'Failed';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get fabActionCamera => 'Camera';

  @override
  String get fabActionGallery => 'Gallery';

  @override
  String get fabActionVoice => 'Voice';

  @override
  String get fabActionVoiceDisabled => 'AI enabled & API Key required';

  @override
  String get voiceRecordingTitle => 'Voice Billing';

  @override
  String get voiceRecordingPreparing => 'Preparing...';

  @override
  String get voiceRecordingInProgress => 'Recording...';

  @override
  String get voiceRecordingProcessing => 'Recognizing...';

  @override
  String voiceRecordingDuration(int duration) {
    return 'Duration: ${duration}s';
  }

  @override
  String get voiceRecordingSuccess => 'Voice billing successful';

  @override
  String get voiceRecordingNoLedger => 'No ledger found';

  @override
  String get voiceRecordingNoInfo => 'No billing information recognized';

  @override
  String get voiceRecordingPermissionDenied => 'Microphone permission required';

  @override
  String get voiceRecordingPermissionDeniedTitle => 'Microphone Permission Required';

  @override
  String get voiceRecordingPermissionDeniedMessage => 'Voice billing requires microphone permission. Please allow BeeCount to access the microphone in System Settings.';

  @override
  String voiceRecordingStartFailed(String error) {
    return 'Failed to start recording: $error';
  }

  @override
  String voiceRecordingFailed(String error) {
    return 'Recording failed: $error';
  }

  @override
  String voiceRecordingRecognizeFailed(String error) {
    return 'Recognition failed: $error';
  }

  @override
  String voiceRecordingNoInfoDetected(String text) {
    return 'Unable to extract bill info: $text';
  }

  @override
  String get voiceRecordingNoSpeech => 'No speech detected';

  @override
  String get commonPrevious => 'Previous';

  @override
  String get commonFinish => 'Finish';

  @override
  String get commonClose => 'Close';

  @override
  String get commonOther => 'Other';

  @override
  String get commonYesterday => 'Yesterday';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonNoteHint => 'Note...';

  @override
  String get commonSettings => 'Settings';

  @override
  String get commonGoSettings => 'Go to Settings';

  @override
  String get commonLanguage => 'Language';

  @override
  String get commonCurrent => 'Current';

  @override
  String get commonTutorial => 'Tutorial';

  @override
  String get commonConfigure => 'Configure';

  @override
  String get commonPressAgainToExit => 'Press again to exit';

  @override
  String get commonWeekdayMonday => 'Monday';

  @override
  String get commonWeekdayTuesday => 'Tuesday';

  @override
  String get commonWeekdayWednesday => 'Wednesday';

  @override
  String get commonWeekdayThursday => 'Thursday';

  @override
  String get commonWeekdayFriday => 'Friday';

  @override
  String get commonWeekdaySaturday => 'Saturday';

  @override
  String get commonWeekdaySunday => 'Sunday';

  @override
  String get homeIncome => 'Income';

  @override
  String get homeExpense => 'Expense';

  @override
  String get homeBalance => 'Balance';

  @override
  String get homeNoRecords => 'No records yet';

  @override
  String get homeSelectDate => 'Select date';

  @override
  String get homeAppTitle => 'Bee Accounting';

  @override
  String get homeSearch => 'Search';

  @override
  String homeYear(int year) {
    return '$year';
  }

  @override
  String homeMonth(String month) {
    return '${month}M';
  }

  @override
  String get homeNoRecordsSubtext => 'Tap the plus button at the bottom to add a record';

  @override
  String get homeLastMonthReportSubtitle => 'View and share last month\'s report';

  @override
  String get homeLastMonthReportView => 'View';

  @override
  String homeAnnualReportReminder(int year) {
    return 'Your $year Annual Report is ready';
  }

  @override
  String get homeAnnualReportView => 'View';

  @override
  String get widgetTodayExpense => 'Today\'s Expense';

  @override
  String get widgetTodayIncome => 'Today\'s Income';

  @override
  String get widgetMonthExpense => 'Month\'s Expense';

  @override
  String get widgetMonthIncome => 'Month\'s Income';

  @override
  String get widgetMonthSuffix => '';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Search notes, categories or amounts...';

  @override
  String get searchCategoryHint => 'Search category name...';

  @override
  String get searchMinAmount => 'Min amount';

  @override
  String get searchMaxAmount => 'Max amount';

  @override
  String get searchNoInput => 'Enter keywords to start searching';

  @override
  String get searchNoResults => 'No matching results found';

  @override
  String get searchBatchMode => 'Batch Operations';

  @override
  String searchBatchModeWithCount(Object selected, Object total) {
    return 'Batch Operations ($selected/$total)';
  }

  @override
  String get searchExitBatchMode => 'Exit Batch Mode';

  @override
  String get searchSelectAll => 'Select All';

  @override
  String get searchDeselectAll => 'Deselect All';

  @override
  String searchSelectedCount(Object count) {
    return '$count selected';
  }

  @override
  String get searchBatchSetNote => 'Set Note';

  @override
  String get searchBatchChangeCategory => 'Change Category';

  @override
  String get searchBatchDeleteConfirmTitle => 'Confirm Delete';

  @override
  String searchBatchDeleteConfirmMessage(Object count) {
    return 'Are you sure you want to delete the selected $count transactions?\nThis action cannot be undone.';
  }

  @override
  String get searchBatchSetNoteTitle => 'Batch Set Note';

  @override
  String searchBatchSetNoteMessage(Object count) {
    return 'Set the same note for the selected $count transactions';
  }

  @override
  String get searchBatchSetNoteHint => 'Enter note content (leave empty to clear notes)';

  @override
  String searchBatchDeleteSuccess(Object count) {
    return 'Successfully deleted $count transactions';
  }

  @override
  String searchBatchDeleteFailed(Object error) {
    return 'Delete failed: $error';
  }

  @override
  String searchBatchSetNoteSuccess(Object count) {
    return 'Successfully set note for $count transactions';
  }

  @override
  String searchBatchSetNoteFailed(Object error) {
    return 'Set note failed: $error';
  }

  @override
  String searchBatchChangeCategorySuccess(Object count) {
    return 'Successfully changed category for $count transactions';
  }

  @override
  String searchBatchChangeCategoryFailed(Object error) {
    return 'Change category failed: $error';
  }

  @override
  String searchResultsCount(Object count) {
    return '$count results';
  }

  @override
  String get searchFilterTitle => 'Filter';

  @override
  String get searchAmountFilter => 'Amount Filter';

  @override
  String get searchDateFilter => 'Date Filter';

  @override
  String get searchStartDate => 'Start Date';

  @override
  String get searchEndDate => 'End Date';

  @override
  String get searchNotSet => 'Not Set';

  @override
  String get searchClearFilter => 'Clear Filter';

  @override
  String get searchBatchCategoryTransferError => 'Selected transactions contain transfers, cannot change category';

  @override
  String get searchBatchCategoryTypeError => 'Selected transactions have different types, please select all income or all expense';

  @override
  String get searchDateStart => 'Start';

  @override
  String get searchDateEnd => 'End';

  @override
  String get analyticsMonth => 'Month';

  @override
  String get analyticsYear => 'Year';

  @override
  String get analyticsAll => 'All';

  @override
  String get analyticsCategoryRanking => 'Category Ranking';

  @override
  String get analyticsTotalAmount => 'Total';

  @override
  String get analyticsNoDataSubtext => 'Swipe left/right to switch periods, or tap button to toggle income/expense';

  @override
  String get analyticsSwipeHint => 'Swipe left/right to change period';

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
  String get ledgersTitle => 'Ledger Management';

  @override
  String get ledgersNew => 'New Ledger';

  @override
  String get ledgersClear => 'Clear Ledger';

  @override
  String ledgersClearMessage(Object name) {
    return 'Are you sure to clear all transactions in ledger \"$name\"? This action cannot be undone.\\nThe ledger will be kept, only transaction data will be deleted.';
  }

  @override
  String get ledgerDefaultName => 'Default Ledger';

  @override
  String get ledgersEdit => 'Edit Ledger';

  @override
  String get ledgersDelete => 'Delete Ledger';

  @override
  String get ledgersDeleteConfirm => 'Delete Ledger';

  @override
  String get ledgersDeleteMessage => 'Are you sure you want to delete this ledger and all its records? This action cannot be undone.\\nIf there is a backup in the cloud, it will also be deleted.';

  @override
  String get ledgersDeleted => 'Deleted';

  @override
  String get ledgersDeleteFailed => 'Delete Failed';

  @override
  String get ledgersClearTitle => 'Clear Ledger';

  @override
  String get ledgersClearSuccess => 'Ledger cleared';

  @override
  String get ledgersDeleteLocal => 'Delete Local Ledger Only';

  @override
  String get ledgersDeleteLocalTitle => 'Delete Local Ledger';

  @override
  String ledgersDeleteLocalMessage(Object name) {
    return 'Are you sure to delete local ledger \"$name\"?\\nCloud backup will be kept and you can restore it anytime.';
  }

  @override
  String get ledgersDeleteLocalSuccess => 'Local ledger deleted';

  @override
  String get ledgersName => 'Name';

  @override
  String get ledgersDefaultLedgerName => 'Default Ledger';

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
  String get ledgerCardDownloadCloud => 'Download from Cloud';

  @override
  String get ledgersLocal => 'Local Ledgers';

  @override
  String get ledgersRemote => 'Cloud Ledgers';

  @override
  String get ledgersEmpty => 'No ledgers';

  @override
  String get ledgersRestoreAll => 'Restore All';

  @override
  String ledgersSwitched(String name) {
    return 'Switched to ledger \"$name\"';
  }

  @override
  String get ledgersDownloadTitle => 'Download Ledger';

  @override
  String ledgersDownloadMessage(String name) {
    return 'Confirm download ledger \"$name\" to local?';
  }

  @override
  String get ledgersDownloading => 'Downloading...';

  @override
  String ledgersDownloadSuccess(String name) {
    return 'Ledger \"$name\" downloaded successfully';
  }

  @override
  String get ledgersDownload => 'Download';

  @override
  String get ledgersDeleteRemote => 'Delete Cloud Ledger';

  @override
  String get ledgersDeleteRemoteConfirm => 'Delete Cloud Ledger';

  @override
  String ledgersDeleteRemoteMessage(String name) {
    return 'Confirm delete cloud ledger \"$name\"? This action cannot be undone.';
  }

  @override
  String get ledgersDeleting => 'Deleting...';

  @override
  String get ledgersDeleteRemoteSuccess => 'Cloud ledger deleted';

  @override
  String get ledgersCannotDeleteLastOne => 'Cannot delete the last ledger';

  @override
  String get ledgersRestoreAllTitle => 'Batch Restore';

  @override
  String ledgersRestoreAllMessage(int count) {
    return 'Confirm restore all cloud ledgers? Total $count.';
  }

  @override
  String get ledgersRestoring => 'Restoring...';

  @override
  String get ledgersRestoreComplete => 'Restore Complete';

  @override
  String ledgersRestoreResult(int success, int failed) {
    return 'Success: $success, Failed: $failed';
  }

  @override
  String get categoryTitle => 'Category Management';

  @override
  String get categoryNew => 'New Category';

  @override
  String get categoryExpense => 'Expense';

  @override
  String get categoryIncome => 'Income';

  @override
  String get categoryEmpty => 'No categories';

  @override
  String get categoryDefault => 'Default Category';

  @override
  String get categoryReorderTip => 'Long press to drag and reorder categories';

  @override
  String categoryLoadFailed(String error) {
    return 'Load failed: $error';
  }

  @override
  String get iconPickerTitle => 'Select Icon';

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
  String get importTitle => 'Import Bills';

  @override
  String get importBillType => 'Bill Type';

  @override
  String get importBillTypeGeneric => 'Generic CSV';

  @override
  String get importBillTypeAlipay => 'Alipay';

  @override
  String get importBillTypeWechat => 'WeChat';

  @override
  String get importChooseFile => 'Choose File';

  @override
  String get importNoFileSelected => 'No file selected';

  @override
  String get importHint => 'Tip: Please select a file to start importing (CSV/TSV/XLSX)';

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
  String get importFieldAmount => 'Amount';

  @override
  String get importFieldCategory => 'Category';

  @override
  String get importFieldAccount => 'Account';

  @override
  String get importFieldNote => 'Note';

  @override
  String get importPreview => 'Data Preview';

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
    return 'Importing, success: $ok, failed: $fail';
  }

  @override
  String get importCancelImport => 'Cancel Import';

  @override
  String get importCompleteTitle => 'Import Complete';

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
  String importSkippedNonTransactionTypes(Object count) {
    return 'Skipped $count non-transaction records (debts, etc.)';
  }

  @override
  String importTransactionFailed(Object error) {
    return 'Import failed, all changes have been rolled back: $error';
  }

  @override
  String importFileOpenError(String error) {
    return 'Unable to open file picker: $error';
  }

  @override
  String get mineTitle => 'Mine';

  @override
  String get mineReminder => 'Reminder Settings';

  @override
  String get mineImport => 'Import Data';

  @override
  String get mineExport => 'Export Data';

  @override
  String get mineCloud => 'Cloud Service';

  @override
  String get mineUpdate => 'Check for Updates';

  @override
  String get mineLanguageSettings => 'Language Settings';

  @override
  String get languageTitle => 'Language Settings';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystemDefault => 'Follow System';

  @override
  String get deleteConfirmTitle => 'Delete Confirmation';

  @override
  String get deleteConfirmMessage => 'Are you sure you want to delete this record?';

  @override
  String get mineSlogan => 'Bee Accounting, Every Penny Counts';

  @override
  String get mineAvatarTitle => 'Avatar Settings';

  @override
  String get mineAvatarFromGallery => 'Choose from Gallery';

  @override
  String get mineAvatarFromCamera => 'Take Photo';

  @override
  String get mineAvatarDelete => 'Delete Avatar';

  @override
  String get annualReportTitle => 'Annual Report';

  @override
  String annualReportSubtitle(int year) {
    return 'Review your $year financial journey';
  }

  @override
  String get annualReportEntrySubtitle => 'Create your personalized annual report to share';

  @override
  String annualReportNoData(int year) {
    return 'No data for $year';
  }

  @override
  String get annualReportPage1Title => 'Annual Overview';

  @override
  String annualReportPage1Subtitle(int year) {
    return 'Your $year bookkeeping journey';
  }

  @override
  String get annualReportTotalDays => 'Days Tracked';

  @override
  String get annualReportTotalRecords => 'Total Records';

  @override
  String get annualReportTotalIncome => 'Total Income';

  @override
  String get annualReportTotalExpense => 'Total Expense';

  @override
  String get annualReportNetSavings => 'Net Savings';

  @override
  String get annualReportPage2Title => 'Expense Analysis';

  @override
  String get annualReportPage2Subtitle => 'Where your money went';

  @override
  String get annualReportPage3Title => 'Monthly Trends';

  @override
  String get annualReportPage3Subtitle => '12 months of income & expense';

  @override
  String get annualReportHighestMonth => 'Highest Spending Month';

  @override
  String get annualReportLowestMonth => 'Lowest Spending Month';

  @override
  String get annualReportPage4Title => 'Special Moments';

  @override
  String get annualReportPage4Subtitle => 'Memorable transactions';

  @override
  String get annualReportLargestExpense => 'Largest Expense';

  @override
  String get annualReportLargestIncome => 'Largest Income';

  @override
  String get annualReportFirstRecord => 'First Record';

  @override
  String get annualReportPage5Title => 'Achievements';

  @override
  String get annualReportPage5Subtitle => 'Your bookkeeping badges';

  @override
  String get annualReportAchievementConsistent => 'Consistent';

  @override
  String annualReportAchievementConsistentDesc(int days) {
    return 'Tracked for over $days days straight';
  }

  @override
  String get annualReportAchievementSaver => 'Saver';

  @override
  String get annualReportAchievementSaverDesc => 'Positive net savings this year';

  @override
  String get annualReportAchievementDetail => 'Detail-Oriented';

  @override
  String annualReportAchievementDetailDesc(int count) {
    return 'Over $count records tracked';
  }

  @override
  String get annualReportShareButton => 'Generate Share Poster';

  @override
  String get annualReportGenerating => 'Generating annual report...';

  @override
  String get annualReportSaveSuccess => 'Annual report poster saved';

  @override
  String get mineShareApp => 'Share App';

  @override
  String get mineShareWithFriends => 'Share BeeCount with friends';

  @override
  String get mineCopyPromoText => 'Copy Promo Text';

  @override
  String get mineCopyPromoSubtitle => 'Copy and share with friends';

  @override
  String get mineShareGenerating => 'Generating share poster...';

  @override
  String get sharePosterAppName => 'BeeCount';

  @override
  String get sharePosterSlogan => 'Smart Accounting, Beautiful Life';

  @override
  String get sharePosterFeature1 => 'Data Security·You Control';

  @override
  String get sharePosterFeature2 => 'Open Source·Auditable';

  @override
  String get sharePosterFeature3 => 'AI Smart·Photo & Voice';

  @override
  String get sharePosterFeature4 => 'Photo Accounting·Auto Recognition';

  @override
  String get sharePosterFeature5 => 'Multi Ledger·Dark Mode';

  @override
  String get sharePosterFeature6 => 'Self-Hosted Cloud·Free Forever';

  @override
  String get sharePosterScanText => 'Scan to visit open source project';

  @override
  String get appPromoTagOpenSource => 'Open Source';

  @override
  String get appPromoTagFree => 'Free';

  @override
  String get appPromoFooterText => 'Track every penny, trace every moment';

  @override
  String userProfileJourneyYears(int years) {
    return 'Bookkeeping Pro $years Years';
  }

  @override
  String get userProfileJourneyOneYear => 'One Year of Bookkeeping';

  @override
  String get userProfileJourneyHalfYear => 'Six Months Strong';

  @override
  String get userProfileJourneyThreeMonths => 'Three Months In';

  @override
  String get userProfileJourneyOneMonth => 'One Month Milestone';

  @override
  String get userProfileJourneyOneWeek => 'First Week Done';

  @override
  String get userProfileJourneyStart => 'Starting the Journey';

  @override
  String get userProfileDailyAverage => 'Daily Average';

  @override
  String get sharePosterSave => 'Save to Gallery';

  @override
  String get sharePosterShare => 'Share';

  @override
  String get sharePosterHideIncome => 'Hide Income';

  @override
  String get sharePosterShowIncome => 'Show Income';

  @override
  String get sharePosterSaveSuccess => 'Saved to gallery';

  @override
  String get shareGuidanceCopyText => 'Track my expenses with BeeCount - open source, free & ad-free! 🐝 Download: https://github.com/TNT-Likely/BeeCount';

  @override
  String get shareGuidanceCopied => 'Text copied';

  @override
  String get sharePosterSaveFailed => 'Failed to save';

  @override
  String get sharePosterPermissionDenied => 'Gallery permission denied, please enable in settings';

  @override
  String get sharePosterGenerating => 'Generating...';

  @override
  String get sharePosterGenerateFailed => 'Failed to generate poster, please try again';

  @override
  String get sharePosterNoLedger => 'Please select a ledger first';

  @override
  String get sharePosterYearTitle => 'My Annual Bookkeeping Report';

  @override
  String get sharePosterYearSubtitle => 'Record life with data, plan future with reason';

  @override
  String get sharePosterMonthTitle => 'Monthly Bill Report';

  @override
  String get sharePosterMonthSubtitle => 'Budget Wisely, Spend Rationally';

  @override
  String get sharePosterLedgerTitle => 'Ledger Statistics Report';

  @override
  String get sharePosterRecordDays => 'Record Days';

  @override
  String get sharePosterRecordCount => 'Record Count';

  @override
  String get sharePosterTotalExpense => 'Total Expense';

  @override
  String get sharePosterTotalIncome => 'Total Income';

  @override
  String get sharePosterYearBalance => 'Annual Balance';

  @override
  String get sharePosterYearDeficit => 'Annual Deficit';

  @override
  String get sharePosterMonthBalance => 'Monthly Balance';

  @override
  String get sharePosterBalance => 'Total Balance';

  @override
  String get sharePosterAvgMonthlyExpense => 'Avg. Monthly Expense';

  @override
  String get sharePosterAvgMonthlyIncome => 'Avg. Monthly Income';

  @override
  String get sharePosterAvgDailyExpense => 'Avg. Daily Expense';

  @override
  String get sharePosterMaxExpenseMonth => 'Highest Expense Month';

  @override
  String get sharePosterTopExpense => 'TOP 3 Expenses';

  @override
  String get sharePosterCompareLastMonth => 'vs Last Month';

  @override
  String get sharePosterIncreaseRate => 'Increase';

  @override
  String get sharePosterDecreaseRate => 'Decrease';

  @override
  String get sharePosterSavedMoneyTitle => 'Congrats! You saved this month';

  @override
  String get sharePosterLedgerName => 'Ledger Name';

  @override
  String get sharePosterUnitDay => 'days';

  @override
  String get sharePosterUnitCount => '';

  @override
  String get sharePosterUnitYuan => '';

  @override
  String userProfilePosterStartDate(String date) {
    return 'Bookkeeping since $date';
  }

  @override
  String get userProfilePosterRecordDays => 'Days';

  @override
  String get userProfilePosterDaysUnit => 'days';

  @override
  String get userProfilePosterRecordCount => 'Records';

  @override
  String get userProfilePosterCountUnit => '';

  @override
  String get userProfilePosterLedgerCount => 'Ledgers';

  @override
  String get userProfilePosterLedgerUnit => '';

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
  String get mineCloudServiceOffline => 'Default Mode (Offline)';

  @override
  String get mineCloudServiceCustom => 'Custom Supabase';

  @override
  String get mineCloudServiceWebDAV => 'Custom Cloud Service (WebDAV)';

  @override
  String get mineSyncTitle => 'Sync';

  @override
  String get mineSyncNotLoggedIn => 'Not logged in';

  @override
  String get mineSyncNotConfigured => 'Cloud not configured';

  @override
  String get mineSyncNoRemote => 'No cloud data';

  @override
  String mineSyncInSync(Object count) {
    return 'Synced (local $count records)';
  }

  @override
  String get mineSyncInSyncSimple => 'Synced';

  @override
  String mineSyncLocalNewer(Object count) {
    return 'Local updated ($count records, upload recommended)';
  }

  @override
  String get mineSyncLocalNewerSimple => 'Local updated';

  @override
  String get mineSyncCloudNewer => 'Cloud updated (download to sync)';

  @override
  String get mineSyncCloudNewerSimple => 'Cloud updated';

  @override
  String get mineSyncDifferent => 'Local and cloud differ, download to compare';

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
  String get mineUploadNeedCloudService => 'Available in cloud service mode only';

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
  String get mineDownloadTitle => 'Download & Sync';

  @override
  String get mineDownloadNeedCloudService => 'Available in cloud service mode only';

  @override
  String get mineDownloadComplete => 'Sync Complete';

  @override
  String mineDownloadResult(Object inserted) {
    return 'Imported: $inserted records';
  }

  @override
  String get mineLoginTitle => 'Login';

  @override
  String get mineLoginSubtitle => 'Only needed for sync';

  @override
  String get cloudReloginTitle => 'Re-login';

  @override
  String get cloudReloginSuccess => 'Re-logged in';

  @override
  String get cloudReloginFailed => 'Re-login failed';

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
  String get mineCategoryManagement => 'Category Management';

  @override
  String get mineCategoryManagementSubtitle => 'Edit custom categories';

  @override
  String get mineCategoryMigration => 'Category Migration';

  @override
  String get mineCategoryMigrationSubtitle => 'Migrate category data to other categories';

  @override
  String get mineRecurringTransactions => 'Recurring Bills';

  @override
  String get mineRecurringTransactionsSubtitle => 'Manage recurring bills';

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
  String get mineCheckUpdate => 'Check Update';

  @override
  String get mineCheckUpdateSubtitle => 'Checking for latest version';

  @override
  String get mineUpdateDownload => 'Download Update';

  @override
  String get mineFeedback => 'Feedback';

  @override
  String get mineFeedbackSubtitle => 'Report issues or suggestions';

  @override
  String get mineHelp => 'Help';

  @override
  String get mineHelpSubtitle => 'View documentation and FAQ';

  @override
  String get mineSupportAuthor => 'Star the Project ⭐️';

  @override
  String mineSupportAuthorSubtitle(String count) {
    return 'Open source, $count stars';
  }

  @override
  String get githubStarGuideTitle => 'How to Star the Project';

  @override
  String get githubStarGuideContent => 'After tapping the button below to open GitHub, tap the area marked in the image to complete the Star';

  @override
  String get githubStarGuideButton => 'Go to GitHub';

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
  String get categoryMigrationTypeLabel => 'Select Type';

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
  String get categoryNameLabel => 'Category Name';

  @override
  String get categoryNameHint => 'Enter category name';

  @override
  String get categoryNameRequired => 'Please enter category name';

  @override
  String get categoryNameTooLong => 'Category name cannot exceed 4 characters';

  @override
  String get categoryNameDuplicate => 'Category name already exists';

  @override
  String get categoryIconLabel => 'Category Icon';

  @override
  String get categoryCustomIconTitle => 'Custom Icon';

  @override
  String get categoryCustomIconTapToSelect => 'Tap to select image';

  @override
  String get categoryCustomIconTapToChange => 'Tap to change image';

  @override
  String get categoryCustomIconError => 'Error selecting image';

  @override
  String get categoryCustomIconRequired => 'Please select a custom icon image';

  @override
  String get categoryCustomIconCrop => 'Crop Icon';

  @override
  String get categoryDangerousOperations => 'Dangerous Operations';

  @override
  String get categoryDeleteTitle => 'Delete Category';

  @override
  String get categoryDeleteSubtitle => 'Cannot be recovered after deletion';

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
  String get categoryShare => 'Share Categories';

  @override
  String get categoryImport => 'Import Categories';

  @override
  String get categoryClearUnused => 'Clear Unused Categories';

  @override
  String get categoryClearUnusedTitle => 'Clear Unused Categories';

  @override
  String categoryClearUnusedMessage(Object count) {
    return 'Are you sure you want to delete $count unused categories? This action cannot be undone.';
  }

  @override
  String get categoryClearUnusedListTitle => 'Categories to be deleted:';

  @override
  String get categoryClearUnusedEmpty => 'No unused categories';

  @override
  String categoryClearUnusedSuccess(Object count) {
    return 'Deleted $count categories';
  }

  @override
  String get categoryClearUnusedFailed => 'Clear failed';

  @override
  String get categoryShareScopeTitle => 'Select Scope';

  @override
  String get categoryShareScopeExpense => 'Expense categories only';

  @override
  String get categoryShareScopeIncome => 'Income categories only';

  @override
  String get categoryShareScopeAll => 'All categories';

  @override
  String categoryShareSuccess(Object path) {
    return 'Saved to $path';
  }

  @override
  String get categoryShareSubject => 'BeeCount Category Configuration';

  @override
  String get categoryShareFailed => 'Share failed';

  @override
  String get categoryImportInvalidFile => 'Please select a category package file (.zip)';

  @override
  String get categoryImportModeTitle => 'Select Import Mode';

  @override
  String get categoryImportModeMerge => 'Merge';

  @override
  String get categoryImportModeMergeDesc => 'Keep existing, add new ones';

  @override
  String get categoryImportModeOverwrite => 'Overwrite';

  @override
  String get categoryImportModeOverwriteDesc => 'Clear unused categories then import';

  @override
  String get categoryImportSuccess => 'Import successful';

  @override
  String categoryImportSuccessDetail(int imported, int skipped, int icons) {
    return 'Imported $imported categories, skipped $skipped, imported $icons icons';
  }

  @override
  String get categoryImportFailed => 'Import failed';

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
  String get categorySubCategoryTitle => 'Subcategory';

  @override
  String get categorySubCategoryDescriptionEnabled => 'This category belongs to a parent category';

  @override
  String get categorySubCategoryDescriptionDisabled => 'This is an independent top-level category';

  @override
  String get categoryParentCategoryTitle => 'Parent Category';

  @override
  String get categoryParentCategoryHint => 'Please select parent category';

  @override
  String get categorySelectParentTitle => 'Select Parent Category';

  @override
  String categorySubCategoryCreated(Object name) {
    return 'Subcategory added: $name';
  }

  @override
  String get categoryParentRequired => 'Please select parent category';

  @override
  String get categoryParentRequiredTitle => 'Error';

  @override
  String get categoryExpenseList => 'Dining-Transport-Shopping-Entertainment-Home-Family-Communication-Utilities-Housing-Medical-Education-Pets-Sports-Digital-Travel-Alcohol & Tobacco-Baby Care-Beauty-Repair-Social-Learning-Car-Taxi-Subway-Delivery-Property-Parking-Donation-Give Gift-Tax-Beverage-Clothing-Snacks-Send Red Packet-Fruit-Game-Book-Lover-Decoration-Daily Goods-Lottery-Stock-Social Security-Express-Work';

  @override
  String get categoryIncomeList => 'Salary-Investment-Receive Red Packet-Bonus-Reimbursement-Part-time-Receive Gift-Interest-Refund-Investment Income-Second-hand-Social Benefit-Tax Refund-Provident Fund';

  @override
  String get categoryExpenseDining => 'Dining-Breakfast-Lunch-Dinner-Meituan Delivery-Ele.me Delivery-JD Delivery-Restaurant-Food';

  @override
  String get categoryExpenseSnacks => 'Cookies-Chips-Candy-Chocolate-Nuts';

  @override
  String get categoryExpenseFruit => 'Fruit-Apple-Banana-Orange-Grape-Watermelon-Other Fruits';

  @override
  String get categoryExpenseBeverage => 'Beverage-Milk Tea-Coffee-Juice-Soda-Mineral Water';

  @override
  String get categoryExpensePastry => 'Pastry-Cake-Bread-Dessert-Pastry';

  @override
  String get categoryExpenseCooking => 'Cooking Ingredients-Vegetables-Meat-Seafood-Seasoning-Grain & Oil';

  @override
  String get categoryExpenseShopping => 'Clothing-Shoes & Hats-Bags-Accessories-Daily Necessities';

  @override
  String get categoryExpensePets => 'Pets-Pet Food-Pet Supplies-Pet Medical-Pet Grooming';

  @override
  String get categoryExpenseTransport => 'Transport-Subway-Bus-Taxi-Ride-hailing-Parking Fee-Fuel';

  @override
  String get categoryExpenseCar => 'Car-Car Maintenance-Car Repair-Car Insurance-Car Wash-Traffic Fine';

  @override
  String get categoryExpenseClothing => 'Top-Pants-Dress-Shoes-Accessories';

  @override
  String get categoryExpenseDailyGoods => 'Daily Goods-Personal Care-Paper Products-Cleaning Supplies-Kitchen Supplies';

  @override
  String get categoryExpenseEducation => 'Tuition-Training Fee-Books-Stationery-Office Supplies';

  @override
  String get categoryExpenseInvestLoss => 'Investment Loss-Stock Loss-Fund Loss-Other Investment Loss';

  @override
  String get categoryExpenseEntertainment => 'Entertainment-Movie-KTV-Amusement Park-Bar-Other Entertainment';

  @override
  String get categoryExpenseGame => 'Game-Game Top-up-Game Equipment-Game Membership';

  @override
  String get categoryExpenseHealthProducts => 'Health Products-Vitamins-Health Food-Nutritional Supplements';

  @override
  String get categoryExpenseSubscription => 'Subscription-Video Membership-Music Membership-Cloud Storage-Other Subscription';

  @override
  String get categoryExpenseSports => 'Sports-Gym-Sports Equipment-Sports Course-Outdoor Activity';

  @override
  String get categoryExpenseHousing => 'Housing-Rent-Property Fee-Mortgage-Renovation';

  @override
  String get categoryExpenseHome => 'Home-Furniture-Appliances-Decorations-Bedding';

  @override
  String get categoryExpenseBeauty => 'Beauty-Skincare-Cosmetics-Beauty Salon-Nail Care';

  @override
  String get categoryIncomeSalary => 'Base Salary-Performance Bonus-Year-end Bonus-Overtime Pay';

  @override
  String get categoryIncomeInvestment => 'Fund Earnings-Stock Dividend-Wealth Management-Other Wealth Management';

  @override
  String get categoryIncomeRedPacket => 'Red Packet-Holiday Red Packet-Birthday Red Packet-Return Gift';

  @override
  String get categoryIncomeBonus => 'Bonus-Year-end Bonus-Quarterly Bonus-Project Bonus-Other Bonus';

  @override
  String get categoryIncomeReimbursement => 'Reimbursement-Travel Reimbursement-Meal Reimbursement-Other Reimbursement';

  @override
  String get categoryIncomePartTime => 'Part-time-Part-time Income-Side Income';

  @override
  String get categoryIncomeGift => 'Gift-Wedding Gift-Birthday Gift-Other Gift';

  @override
  String get categoryIncomeInterest => 'Interest-Bank Interest-Other Interest';

  @override
  String get categoryIncomeRefund => 'Refund-Shopping Refund-Service Refund-Other Refund';

  @override
  String get categoryIncomeInvestIncome => 'Investment Income-Stock Earnings-Fund Earnings-Other Investment Income';

  @override
  String get categoryIncomeSecondHand => 'Second-hand-Idle Items-Second-hand Goods';

  @override
  String get categoryIncomeSocialBenefit => 'Social Benefit-Unemployment Insurance-Maternity Subsidy-Other Subsidy';

  @override
  String get categoryIncomeTaxRefund => 'Tax Refund-Individual Tax Refund-Other Refund';

  @override
  String get categoryIncomeProvidentFund => 'Provident Fund-Provident Fund Withdrawal-Provident Fund Interest';

  @override
  String get personalizeTitle => 'Personalize';

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
  String get appearanceThemeMode => 'Appearance';

  @override
  String get appearanceThemeModeSystem => 'Follow System';

  @override
  String get appearanceThemeModeLight => 'Light Mode';

  @override
  String get appearanceThemeModeDark => 'Dark Mode';

  @override
  String get appearanceDarkModePattern => 'Dark Mode Header Pattern';

  @override
  String get appearancePatternNone => 'None';

  @override
  String get appearancePatternIcons => 'Icon Tiling';

  @override
  String get appearancePatternParticles => 'Particles';

  @override
  String get appearancePatternHoneycomb => 'Honeycomb';

  @override
  String get appearanceAmountFormat => 'Balance Display Format';

  @override
  String get appearanceAmountFormatFull => 'Full Amount';

  @override
  String get appearanceAmountFormatFullDesc => 'Show full amount, e.g. 123,456.78';

  @override
  String get appearanceAmountFormatCompact => 'Compact';

  @override
  String get appearanceAmountFormatCompactDesc => 'Abbreviate large amounts, e.g. 12.3K (only affects account balance)';

  @override
  String get appearanceShowTransactionTime => 'Show Transaction Time';

  @override
  String get appearanceShowTransactionTimeDesc => 'Display time in transaction list, allow time selection when editing';

  @override
  String get appearanceColorScheme => 'Income/Expense Color Scheme';

  @override
  String get appearanceColorSchemeOn => 'Red for income · Green for expense';

  @override
  String get appearanceColorSchemeOff => 'Red for expense · Green for income';

  @override
  String get appearanceColorSchemeOnDesc => 'Red represents income, green represents expense';

  @override
  String get appearanceColorSchemeOffDesc => 'Red represents expense, green represents income';

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
  String get reminderTitle => 'Recording Reminder';

  @override
  String get reminderSubtitle => 'Set daily recording reminder time';

  @override
  String get reminderDailyTitle => 'Daily Recording Reminder';

  @override
  String get reminderDailySubtitle => 'When enabled, will remind you to record at specified time';

  @override
  String get reminderTimeTitle => 'Reminder Time';

  @override
  String get commonSelectTime => 'Select Time';

  @override
  String get reminderTestNotification => 'Send Test Notification';

  @override
  String get reminderTestSent => 'Test notification sent';

  @override
  String get reminderTestTitle => 'Test Notification';

  @override
  String get reminderTestBody => 'This is a test notification, tap to see the effect';

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
  String get reminderDescription => 'Tip: When recording reminder is enabled, the system will send notifications at the specified time daily to remind you to record income and expenses.';

  @override
  String get reminderIOSInstructions => '🍎 iOS notification settings:\n• Settings > Notifications > Bee Accounting\n• Enable \"Allow Notifications\"\n• Set notification style: Banner or Alert\n• Enable sound and vibration\n\n⚠️ Important Note:\n• iOS local notifications depend on app process\n• Do not force quit app from task manager\n• Notifications work when app is in background or foreground\n• Force quitting will disable notifications\n\n💡 Usage Tips:\n• Simply press Home button to exit app\n• iOS will manage background apps automatically\n• Keep app in background to receive reminders';

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
  String get mineImportCompleteAllSuccess => 'All Success';

  @override
  String get mineCheckUpdateDetecting => 'Checking update...';

  @override
  String get mineCheckUpdateSubtitleDetecting => 'Checking for latest version';

  @override
  String get mineUpdateDownloadTitle => 'Download Update';

  @override
  String get cloudTest => 'Test';

  @override
  String get cloudSwitched => 'Switched';

  @override
  String get cloudSwitchFailed => 'Switch failed';

  @override
  String get cloudSupabaseUrlLabel => 'Supabase URL';

  @override
  String get cloudSupabaseUrlHint => 'https://xxx.supabase.co';

  @override
  String get cloudAnonKeyLabel => 'Anon Key';

  @override
  String get cloudSelectServiceType => 'Select Cloud Service Type';

  @override
  String get cloudMultiDeviceWarningTitle => 'Multi-Device Tips';

  @override
  String get cloudMultiDeviceWarningMessage => 'Upload before switching devices, download on the new device before editing. Don\'t edit the same ledger on two devices at once. Tap for details →';

  @override
  String get cloudWebdavUrlLabel => 'WebDAV Server URL';

  @override
  String get cloudWebdavUrlHint => 'https://dav.jianguoyun.com/dav/';

  @override
  String get cloudWebdavUsernameLabel => 'Username';

  @override
  String get cloudWebdavPasswordLabel => 'Password';

  @override
  String get cloudWebdavPathHint => '/BeeCount';

  @override
  String get cloudS3EndpointLabel => 'Endpoint';

  @override
  String get cloudS3EndpointHint => 's3.amazonaws.com or custom endpoint';

  @override
  String get cloudS3RegionLabel => 'Region';

  @override
  String get cloudS3RegionHint => 'us-east-1 (leave blank for auto)';

  @override
  String get cloudS3AccessKeyLabel => 'Access Key';

  @override
  String get cloudS3AccessKeyHint => 'Your Access Key ID';

  @override
  String get cloudS3SecretKeyLabel => 'Secret Key';

  @override
  String get cloudS3SecretKeyHint => 'Your Secret Access Key';

  @override
  String get cloudS3BucketLabel => 'Bucket Name';

  @override
  String get cloudS3BucketHint => 'beecount-data';

  @override
  String get cloudS3UseSSLLabel => 'Use HTTPS';

  @override
  String get cloudS3PortLabel => 'Port (optional)';

  @override
  String get cloudS3PortHint => 'Leave blank for default';

  @override
  String get cloudSupabaseBucketLabel => 'Storage Bucket Name';

  @override
  String get cloudSupabaseBucketHint => 'Leave blank for default: beecount-backups';

  @override
  String get authRememberAccount => 'Remember account';

  @override
  String get authRememberAccountHint => 'Auto-fill on next login (Supabase only)';

  @override
  String get cloudConfigSaved => 'Configuration saved';

  @override
  String get cloudTestSuccess => 'Connection test successful!';

  @override
  String get cloudTestFailed => 'Connection test failed, please check if the configuration is correct.';

  @override
  String get cloudTestError => 'Test failed';

  @override
  String get authLogin => 'Login';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authInvalidEmail => 'Please enter a valid email address';

  @override
  String get authPasswordRequirementShort => 'Password must contain letters and numbers, at least 6 characters';

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
  String get authErrorWeakPassword => 'Password is too simple, please include letters and numbers, at least 6 characters.';

  @override
  String get importSelectCsvFile => 'Please select a file to import (CSV/TSV/XLSX supported)';

  @override
  String get exportTitle => 'Export';

  @override
  String get exportDescription => 'Supported export types:\n• Transactions (Income/Expense/Transfer)\n• Categories\n• Accounts\n\nClick the button below to select save location and export current ledger to CSV file.';

  @override
  String get exportButtonIOS => 'Export and Share';

  @override
  String get exportButtonAndroid => 'Export Data';

  @override
  String exportSavedTo(String path) {
    return 'Saved to: $path';
  }

  @override
  String get exportCsvHeaderType => 'Type';

  @override
  String get exportCsvHeaderCategory => 'Category';

  @override
  String get exportCsvHeaderSubCategory => 'Subcategory';

  @override
  String get exportCsvHeaderAmount => 'Amount';

  @override
  String get exportCsvHeaderAccount => 'Account';

  @override
  String get exportCsvHeaderFromAccount => 'From Account';

  @override
  String get exportCsvHeaderToAccount => 'To Account';

  @override
  String get exportCsvHeaderNote => 'Note';

  @override
  String get exportCsvHeaderTime => 'Time';

  @override
  String get exportCsvHeaderTags => 'Tags';

  @override
  String get exportCsvHeaderAttachments => 'Attachments';

  @override
  String get exportShareText => 'BeeCount Export File';

  @override
  String get exportSuccessTitle => 'Export Successful';

  @override
  String exportSuccessMessageIOS(String path) {
    return 'Saved and available in share history:\n$path';
  }

  @override
  String exportSuccessMessageAndroid(String path) {
    return 'Saved to:\n$path';
  }

  @override
  String get exportFailedTitle => 'Export Failed';

  @override
  String get exportTypeIncome => 'Income';

  @override
  String get exportTypeExpense => 'Expense';

  @override
  String get exportTypeTransfer => 'Transfer';

  @override
  String get personalizeThemeHoney => 'Bee Yellow';

  @override
  String get personalizeThemeOrange => 'Flame Orange';

  @override
  String get personalizeThemeGreen => 'Emerald Green';

  @override
  String get personalizeThemePurple => 'Purple Lotus';

  @override
  String get personalizeThemePink => 'Cherry Pink';

  @override
  String get personalizeThemeBlue => 'Sky Blue';

  @override
  String get personalizeThemeMint => 'Forest Moon';

  @override
  String get personalizeThemeSand => 'Sunset Dune';

  @override
  String get personalizeThemeLavender => 'Snow & Pine';

  @override
  String get personalizeThemeSky => 'Misty Wonderland';

  @override
  String get personalizeThemeWarmOrange => 'Warm Orange';

  @override
  String get personalizeThemeMintGreen => 'Mint Green';

  @override
  String get personalizeThemeRoseGold => 'Rose Gold';

  @override
  String get personalizeThemeDeepBlue => 'Deep Blue';

  @override
  String get personalizeThemeMapleRed => 'Maple Red';

  @override
  String get personalizeThemeEmerald => 'Emerald';

  @override
  String get personalizeThemeLavenderPurple => 'Lavender';

  @override
  String get personalizeThemeAmber => 'Amber';

  @override
  String get personalizeThemeRouge => 'Rouge Red';

  @override
  String get personalizeThemeIndigo => 'Indigo Blue';

  @override
  String get personalizeThemeOlive => 'Olive Green';

  @override
  String get personalizeThemeCoral => 'Coral Pink';

  @override
  String get personalizeThemeDarkGreen => 'Dark Green';

  @override
  String get personalizeThemeViolet => 'Violet';

  @override
  String get personalizeThemeSunset => 'Sunset Orange';

  @override
  String get personalizeThemePeacock => 'Peacock Blue';

  @override
  String get personalizeThemeLime => 'Lime Green';

  @override
  String get analyticsMonthlyAvg => 'Monthly Avg';

  @override
  String get analyticsDailyAvg => 'Daily Avg';

  @override
  String get analyticsOverallAvg => 'Overall Avg';

  @override
  String get analyticsTotalIncome => 'Total Income: ';

  @override
  String get analyticsTotalExpense => 'Total Expense: ';

  @override
  String get analyticsBalance => 'Balance: ';

  @override
  String analyticsAvgIncome(String avgLabel) {
    return '$avgLabel Income: ';
  }

  @override
  String analyticsAvgExpense(String avgLabel) {
    return '$avgLabel Expense: ';
  }

  @override
  String get analyticsExpense => 'Expense';

  @override
  String get analyticsIncome => 'Income';

  @override
  String analyticsTotal(String type) {
    return 'Total $type: ';
  }

  @override
  String analyticsAverage(String avgLabel) {
    return '$avgLabel: ';
  }

  @override
  String get updateCheckTitle => 'Check Update';

  @override
  String updateNewVersionTitle(String version) {
    return 'New Version $version Found';
  }

  @override
  String get updateNoApkFound => 'APK download link not found';

  @override
  String get updateAlreadyLatest => 'Already latest version';

  @override
  String get updateCheckFailed => 'Update check failed';

  @override
  String get updatePermissionDenied => 'Permission denied';

  @override
  String get updateUserCancelled => 'User cancelled';

  @override
  String get updateDownloadTitle => 'Download Update';

  @override
  String updateDownloading(String percent) {
    return 'Downloading: $percent%';
  }

  @override
  String get updateDownloadBackgroundHint => 'You can switch the app to background, download will continue';

  @override
  String get updateCancelButton => 'Cancel';

  @override
  String get updateBackgroundDownload => 'Background Download';

  @override
  String get updateLaterButton => 'Later';

  @override
  String get updateDownloadButton => 'Download';

  @override
  String get updateInstallingCachedApk => 'Installing cached APK';

  @override
  String get updateDownloadComplete => 'Download Complete';

  @override
  String get updateInstallStarted => 'Download complete, installer started';

  @override
  String get updateInstallFailed => 'Installation failed';

  @override
  String get updateDownloadFailed => 'Download failed';

  @override
  String get updateInstallNow => 'Install Now';

  @override
  String get updateNotificationPermissionTitle => 'Notification Permission Denied';

  @override
  String get updateCheckFailedTitle => 'Update Check Failed';

  @override
  String get updateDownloadFailedTitle => 'Download Failed';

  @override
  String get updateGoToGitHub => 'Go to GitHub';

  @override
  String get updateCannotOpenLink => 'Cannot open link';

  @override
  String get updateManualVisit => 'Please manually visit in browser:\\nhttps://github.com/TNT-Likely/BeeCount/releases';

  @override
  String get updateNoLocalApkTitle => 'No Update Package Found';

  @override
  String get updateInstallPackageTitle => 'Install Update Package';

  @override
  String get updateMultiplePackagesTitle => 'Found Multiple Update Packages';

  @override
  String get updateSearchFailedTitle => 'Search Failed';

  @override
  String get updateFoundCachedPackageTitle => 'Found Downloaded Update Package';

  @override
  String get updateIgnoreButton => 'Ignore';

  @override
  String get updateInstallFailedTitle => 'Installation Failed';

  @override
  String get updateInstallFailedMessage => 'Cannot start APK installer, please check file permissions.';

  @override
  String get updateErrorTitle => 'Error';

  @override
  String get updateCheckingPermissions => 'Checking permissions...';

  @override
  String get updateCheckingCache => 'Checking local cache...';

  @override
  String get updatePreparingDownload => 'Preparing download...';

  @override
  String get updateUserCancelledDownload => 'User cancelled download';

  @override
  String get updateStartingInstaller => 'Starting installer...';

  @override
  String get updateInstallerStarted => 'Installer started';

  @override
  String get updateInstallationFailed => 'Installation failed';

  @override
  String get updateDownloadCompleted => 'Download completed';

  @override
  String get updateDownloadCompletedManual => 'Download completed, can install manually';

  @override
  String get updateDownloadCompletedDialog => 'Download completed, please install manually (dialog exception)';

  @override
  String get updateDownloadCompletedContext => 'Download completed, please install manually';

  @override
  String get updateDownloadFailedGeneric => 'Download failed';

  @override
  String get updateCheckingUpdate => 'Checking for updates...';

  @override
  String get updateCurrentLatestVersion => 'Already latest version';

  @override
  String get updateCheckFailedGeneric => 'Update check failed';

  @override
  String updateDownloadProgress(String percent) {
    return 'Downloading: $percent%';
  }

  @override
  String updateCheckingUpdateError(String error) {
    return 'Update check failed: $error';
  }

  @override
  String get updateNoLocalApkFoundMessage => 'No downloaded update package file found.\\n\\nPlease first download new version through \"Check Update\".';

  @override
  String updateInstallPackageFoundMessage(String fileName, String fileSize, String time) {
    return 'Found update package:\\n\\nFile name: $fileName\\nSize: ${fileSize}MB\\nDownload time: $time\\n\\nInstall immediately?';
  }

  @override
  String updateMultiplePackagesFoundMessage(int count, String path) {
    return 'Found $count update package files.\\n\\nRecommend using the latest downloaded version, or manually install in file manager.\\n\\nFile location: $path';
  }

  @override
  String updateSearchLocalApkError(String error) {
    return 'Error occurred while searching for local update packages: $error';
  }

  @override
  String updateCachedPackageFoundMessage(String fileName, String fileSize) {
    return 'Detected previously downloaded update package:\\n\\nFile name: $fileName\\nSize: ${fileSize}MB\\n\\nInstall immediately?';
  }

  @override
  String updateReadCachedPackageError(String error) {
    return 'Failed to read cached update package: $error';
  }

  @override
  String get updateOk => 'OK';

  @override
  String get updateCannotOpenLinkTitle => 'Cannot Open Link';

  @override
  String get updateCachedVersionTitle => 'Found Downloaded Version';

  @override
  String get updateCachedVersionMessage => 'Found previously downloaded installation package... Click \\\"OK\\\" to install immediately, click \\\"Cancel\\\" to close...';

  @override
  String get updateConfirmDownload => 'Download and Install Now';

  @override
  String get updateDownloadCompleteTitle => 'Download Complete';

  @override
  String get updateInstallConfirmMessage => 'New version has been downloaded. Install now?';

  @override
  String get updateMirrorSelectTitle => 'Select Download Accelerator';

  @override
  String get updateMirrorSelectHint => 'If download is slow, select an accelerated mirror. Click \"Test\" to check latency.';

  @override
  String get updateMirrorTestButton => 'Test';

  @override
  String updateMirrorTesting(int completed, int total) {
    return 'Testing $completed/$total...';
  }

  @override
  String get updateMirrorDirectHint => 'For users with good network';

  @override
  String updateDownloadMirror(String mirror) {
    return 'Source: $mirror';
  }

  @override
  String get updateMirrorSettingTitle => 'Download Accelerator';

  @override
  String get updateNotificationPermissionGuideText => 'Download progress notifications are disabled, but this doesn\'t affect download functionality. To view progress:';

  @override
  String get updateNotificationGuideStep1 => 'Go to System Settings > App Management';

  @override
  String get updateNotificationGuideStep2 => 'Find \\\"BeeCount\\\" app';

  @override
  String get updateNotificationGuideStep3 => 'Enable notification permissions';

  @override
  String get updateNotificationGuideInfo => 'Downloads will continue normally in the background even without notifications';

  @override
  String get currencyCNY => 'Chinese Yuan';

  @override
  String get currencyUSD => 'US Dollar';

  @override
  String get currencyEUR => 'Euro';

  @override
  String get currencyJPY => 'Japanese Yen';

  @override
  String get currencyHKD => 'Hong Kong Dollar';

  @override
  String get currencyTWD => 'New Taiwan Dollar';

  @override
  String get currencyGBP => 'British Pound';

  @override
  String get currencyAUD => 'Australian Dollar';

  @override
  String get currencyCAD => 'Canadian Dollar';

  @override
  String get currencyKRW => 'South Korean Won';

  @override
  String get currencySGD => 'Singapore Dollar';

  @override
  String get currencyMYR => 'Malaysian Ringgit';

  @override
  String get currencyTHB => 'Thai Baht';

  @override
  String get currencyIDR => 'Indonesian Rupiah';

  @override
  String get currencyPHP => 'Philippine Peso';

  @override
  String get currencyVND => 'Vietnamese Dong';

  @override
  String get currencyINR => 'Indian Rupee';

  @override
  String get currencyRUB => 'Russian Ruble';

  @override
  String get currencyBYN => 'Belarusian Ruble';

  @override
  String get currencyNZD => 'New Zealand Dollar';

  @override
  String get currencyCHF => 'Swiss Franc';

  @override
  String get currencySEK => 'Swedish Krona';

  @override
  String get currencyNOK => 'Norwegian Krone';

  @override
  String get currencyDKK => 'Danish Krone';

  @override
  String get currencyBRL => 'Brazilian Real';

  @override
  String get currencyMXN => 'Mexican Peso';

  @override
  String get currencyTRY => 'Turkish Lira';

  @override
  String get currencyZAR => 'South African Rand';

  @override
  String get currencyAED => 'UAE Dirham';

  @override
  String get currencySAR => 'Saudi Riyal';

  @override
  String get currencyPLN => 'Polish Zloty';

  @override
  String get currencyCZK => 'Czech Koruna';

  @override
  String get currencyHUF => 'Hungarian Forint';

  @override
  String get currencyARS => 'Argentine Peso';

  @override
  String get currencyCLP => 'Chilean Peso';

  @override
  String get currencyCOP => 'Colombian Peso';

  @override
  String get currencyPEN => 'Peruvian Sol';

  @override
  String get currencyEGP => 'Egyptian Pound';

  @override
  String get currencyNGN => 'Nigerian Naira';

  @override
  String get currencyKZT => 'Kazakhstani Tenge';

  @override
  String get currencyUAH => 'Ukrainian Hryvnia';

  @override
  String get currencyILS => 'Israeli New Shekel';

  @override
  String get currencyPKR => 'Pakistani Rupee';

  @override
  String get currencyBDT => 'Bangladeshi Taka';

  @override
  String get currencyLKR => 'Sri Lankan Rupee';

  @override
  String get currencyMMK => 'Myanmar Kyat';

  @override
  String get webdavConfiguredTitle => 'WebDAV Cloud Service Configured';

  @override
  String get webdavConfiguredMessage => 'WebDAV cloud service uses the credentials provided during configuration, no additional login required.';

  @override
  String get recurringTransactionTitle => 'Recurring Bills';

  @override
  String get recurringTransactionAdd => 'Add Recurring Bill';

  @override
  String get recurringTransactionEdit => 'Edit Recurring Bill';

  @override
  String get recurringTransactionFrequency => 'Frequency';

  @override
  String get recurringTransactionDaily => 'Daily';

  @override
  String get recurringTransactionWeekly => 'Weekly';

  @override
  String get recurringTransactionMonthly => 'Monthly';

  @override
  String get recurringTransactionYearly => 'Yearly';

  @override
  String get recurringTransactionInterval => 'Interval';

  @override
  String get recurringTransactionDayOfMonth => 'Day of Month';

  @override
  String get recurringTransactionStartDate => 'Start Date';

  @override
  String get recurringTransactionEndDate => 'End Date';

  @override
  String get recurringTransactionNoEndDate => 'Perpetual';

  @override
  String get recurringTransactionDeleteConfirm => 'Are you sure you want to delete this recurring bill?';

  @override
  String get recurringTransactionEmpty => 'No Recurring Bills';

  @override
  String get recurringTransactionEmptyHint => 'Tap the + button in the top right corner to add';

  @override
  String recurringTransactionEveryNDays(int n) {
    return 'Every $n day(s)';
  }

  @override
  String recurringTransactionEveryNWeeks(int n) {
    return 'Every $n week(s)';
  }

  @override
  String recurringTransactionEveryNMonths(int n) {
    return 'Every $n month(s)';
  }

  @override
  String recurringTransactionEveryNYears(int n) {
    return 'Every $n year(s)';
  }

  @override
  String get recurringTransactionUsageTitle => 'Usage Guide';

  @override
  String get recurringTransactionUsageContent => 'Recurring transactions are automatically scanned and generated when the app cold starts. After setting a date, the system will create corresponding bills on the first startup after that date. For example: if set to Nov 27, bills will be auto-recorded on the first launch after Nov 27.';

  @override
  String get ledgerSelectTitle => 'Select Ledger';

  @override
  String get ledgerSelect => 'Select Ledger';

  @override
  String get syncNotConfiguredMessage => 'Cloud not configured';

  @override
  String get syncNotLoggedInMessage => 'Not logged in';

  @override
  String get syncCloudBackupCorruptedMessage => 'Cloud backup content is corrupted, possibly due to encoding issues from earlier versions. Please click \'Upload Current Ledger to Cloud\' to overwrite and fix.';

  @override
  String get syncNoCloudBackupMessage => 'No cloud backup';

  @override
  String get syncAccessDeniedMessage => '403 Access denied (check storage RLS policy and path)';

  @override
  String get cloudTestConnection => 'Test Connection';

  @override
  String get cloudLocalStorageTitle => 'Local Storage';

  @override
  String get cloudLocalStorageSubtitle => 'Data is only saved on local device';

  @override
  String get cloudCustomSupabaseTitle => 'Custom Supabase';

  @override
  String get cloudCustomSupabaseSubtitle => 'Click to configure self-hosted Supabase';

  @override
  String get cloudCustomWebdavTitle => 'Custom WebDAV';

  @override
  String get cloudCustomWebdavSubtitle => 'Click to configure Nutstore/Nextcloud etc.';

  @override
  String get cloudCustomS3Title => 'S3 Protocol Storage';

  @override
  String get cloudCustomS3Subtitle => 'AWS S3 / Cloudflare R2 / MinIO';

  @override
  String get cloudBeeCountCloudTitle => 'BeeCount Cloud';

  @override
  String get cloudBeeCountCloudSubtitle => 'Self-hosted · Incremental sync · Multi-device';

  @override
  String get cloudConfigureBeeCountCloudTitle => 'Configure BeeCount Cloud';

  @override
  String get cloudBeeCountCloudUrlLabel => 'Server URL';

  @override
  String get cloudBeeCountCloudUrlHint => 'https://your-server.com';

  @override
  String get cloudBeeCountCloudApiPrefixLabel => 'API Prefix';

  @override
  String get cloudBeeCountCloudApiPrefixHint => '/api/v1';

  @override
  String get cloudBeeCountCloudEmailLabel => 'Email';

  @override
  String get cloudBeeCountCloudEmailHint => 'your@email.com';

  @override
  String get cloudBeeCountCloudPasswordLabel => 'Password';

  @override
  String get cloudBeeCountCloudPasswordHint => 'Enter password';

  @override
  String get cloudBeeCountCloudLoginSuccess => 'Login successful';

  @override
  String get cloudBeeCountCloudLoginFailed => 'Login failed';

  @override
  String get cloudBeeCountCloudSyncSubtitle => 'Incremental sync · Multi-device';

  @override
  String get cloudBeeCountCloudConnected => 'Connected';

  @override
  String get cloudBeeCountCloudNotConnected => 'Not connected';

  @override
  String get cloudBeeCountCloudNotConnectedHint => 'Configure and login in cloud service settings';

  @override
  String get cloudBeeCountCloudAutoSync => 'Incremental Sync';

  @override
  String get cloudBeeCountCloudAutoSyncHint => 'Changes sync to cloud automatically';

  @override
  String get cloudBeeCountCloudMultiDevice => 'Multi-device Sync';

  @override
  String get cloudBeeCountCloudMultiDeviceHint => 'Keep data consistent across devices';

  @override
  String get cloudBeeCountCloudAttachment => 'Attachment Sync';

  @override
  String get cloudBeeCountCloudAttachmentHint => 'Receipt images backed up to cloud automatically';

  @override
  String get cloudTabOffline => 'Offline';

  @override
  String get cloudTabBackup => 'Backup';

  @override
  String get cloudTabCloudSync => 'Cloud Sync';

  @override
  String get cloudIcloudSubtitle => 'Auto sync with Apple ID';

  @override
  String get cloudIcloudNotAvailableTitle => 'iCloud Not Available';

  @override
  String get cloudIcloudNotAvailableMessage => 'Please sign in to iCloud in Settings and try again';

  @override
  String get cloudIcloudHelpTitle => 'iCloud Instructions';

  @override
  String get cloudIcloudHelpPrerequisites => 'Prerequisites';

  @override
  String get cloudIcloudHelpPrereq1 => '1. Device is signed in with Apple ID';

  @override
  String get cloudIcloudHelpPrereq2 => '2. iCloud Drive is enabled';

  @override
  String get cloudIcloudHelpPrereq3 => '3. Device is connected to internet';

  @override
  String get cloudIcloudHelpCheckTitle => 'How to Check iCloud Drive';

  @override
  String get cloudIcloudHelpCheck1 => '1. Open Settings';

  @override
  String get cloudIcloudHelpCheck2 => '2. Tap your Apple ID at the top';

  @override
  String get cloudIcloudHelpCheck3 => '3. Tap iCloud';

  @override
  String get cloudIcloudHelpCheck4 => '4. Make sure iCloud Drive is enabled';

  @override
  String get cloudIcloudHelpFaqTitle => 'FAQ';

  @override
  String get cloudIcloudHelpFaq1 => 'If not available, check if iCloud Drive is enabled';

  @override
  String get cloudIcloudHelpFaq2 => 'First time use may take a few seconds to initialize';

  @override
  String get cloudIcloudHelpFaq3 => 'Data is stored in your private iCloud space';

  @override
  String get cloudIcloudHelpFaq4 => 'Devices with same Apple ID sync automatically';

  @override
  String get cloudIcloudHelpNote => 'iCloud sync uses your Apple ID, no extra configuration needed';

  @override
  String get cloudSupabaseHelpTitle => 'Supabase Setup Guide';

  @override
  String get cloudSupabaseHelpIntro => 'What is Supabase';

  @override
  String get cloudSupabaseHelpIntro1 => 'Supabase is an open-source backend-as-a-service platform';

  @override
  String get cloudSupabaseHelpIntro2 => 'Offers a free tier, sufficient for personal use';

  @override
  String get cloudSupabaseHelpIntro3 => 'You have full control over your data';

  @override
  String get cloudSupabaseHelpSteps => 'Setup Steps';

  @override
  String get cloudSupabaseHelpStep1 => '1. Visit supabase.com to create an account';

  @override
  String get cloudSupabaseHelpStep2 => '2. Create a new project (select free tier)';

  @override
  String get cloudSupabaseHelpStep3 => '3. Go to Project Settings > API';

  @override
  String get cloudSupabaseHelpStep4 => '4. Copy Project URL and anon key';

  @override
  String get cloudSupabaseHelpStep5 => '5. Paste them into the app configuration';

  @override
  String get cloudSupabaseHelpFaq => 'FAQ';

  @override
  String get cloudSupabaseHelpFaq1 => 'Free tier includes 500MB storage';

  @override
  String get cloudSupabaseHelpFaq2 => 'Data is encrypted and secure';

  @override
  String get cloudSupabaseHelpFaq3 => 'Supports multi-device sync';

  @override
  String get cloudSupabaseHelpNote => 'After configuration, you need to register/login to use sync';

  @override
  String get cloudDetailedTutorial => 'Detailed Tutorial';

  @override
  String get cloudWebdavHelpTitle => 'WebDAV Setup Guide';

  @override
  String get cloudWebdavHelpIntro => 'What is WebDAV';

  @override
  String get cloudWebdavHelpIntro1 => 'WebDAV is a network file protocol';

  @override
  String get cloudWebdavHelpIntro2 => 'Supported by many cloud storage and NAS devices';

  @override
  String get cloudWebdavHelpIntro3 => 'Data is stored on your own server';

  @override
  String get cloudWebdavHelpProviders => 'Supported Providers';

  @override
  String get cloudWebdavHelpProvider1 => '- Nutstore (recommended for China users)';

  @override
  String get cloudWebdavHelpProvider2 => '- Nextcloud / ownCloud';

  @override
  String get cloudWebdavHelpProvider3 => '- Synology / QNAP NAS';

  @override
  String get cloudWebdavHelpProvider4 => '- Other WebDAV-compatible services';

  @override
  String get cloudWebdavHelpSteps => 'Setup Steps (Nutstore example)';

  @override
  String get cloudWebdavHelpStep1 => '1. Login to Nutstore web version';

  @override
  String get cloudWebdavHelpStep2 => '2. Click account name > Account Info';

  @override
  String get cloudWebdavHelpStep3 => '3. Select Security Options tab';

  @override
  String get cloudWebdavHelpStep4 => '4. Add application password (for third-party apps)';

  @override
  String get cloudWebdavHelpStep5 => '5. Copy server address, account, and app password';

  @override
  String get cloudWebdavHelpNote => 'Use an app-specific password instead of your account password';

  @override
  String get cloudS3HelpTitle => 'S3 Storage Setup Guide';

  @override
  String get cloudS3HelpIntro => 'What is S3';

  @override
  String get cloudS3HelpIntro1 => 'S3 is a standard object storage protocol';

  @override
  String get cloudS3HelpIntro2 => 'Supported by many cloud providers';

  @override
  String get cloudS3HelpIntro3 => 'Data is stored on your chosen cloud service';

  @override
  String get cloudS3HelpProviders => 'Supported Providers';

  @override
  String get cloudS3HelpProvider1 => '- AWS S3 (Amazon Web Services)';

  @override
  String get cloudS3HelpProvider2 => '- Cloudflare R2 (free 10GB/month)';

  @override
  String get cloudS3HelpProvider3 => '- Backblaze B2 (free 10GB)';

  @override
  String get cloudS3HelpProvider4 => '- MinIO (self-hosted)';

  @override
  String get cloudS3HelpProvider5 => '- Alibaba Cloud OSS';

  @override
  String get cloudS3HelpProvider6 => '- Tencent Cloud COS';

  @override
  String get cloudS3HelpProvider7 => '- Qiniu Kodo';

  @override
  String get cloudS3HelpSteps => 'Setup Steps (Cloudflare R2 example)';

  @override
  String get cloudS3HelpStep1 => '1. Login to Cloudflare Dashboard';

  @override
  String get cloudS3HelpStep2 => '2. Go to R2 > Create Bucket';

  @override
  String get cloudS3HelpStep3 => '3. Go to R2 > Manage R2 API Tokens';

  @override
  String get cloudS3HelpStep4 => '4. Create API Token and copy credentials';

  @override
  String get cloudS3HelpStep5 => '5. Paste endpoint, access key, secret key, and bucket name';

  @override
  String get cloudS3HelpNote => 'Recommended: Cloudflare R2 offers 10GB free storage without egress fees';

  @override
  String get cloudStatusNotTested => 'Not tested';

  @override
  String get cloudStatusNormal => 'Connection normal';

  @override
  String get cloudStatusFailed => 'Connection failed';

  @override
  String get cloudCannotOpenLink => 'Cannot open link';

  @override
  String get cloudErrorAuthFailed => 'Authentication failed: Invalid API Key';

  @override
  String cloudErrorServerStatus(String code) {
    return 'Server returned status code $code';
  }

  @override
  String get cloudErrorWebdavNotSupported => 'Server does not support WebDAV protocol';

  @override
  String get cloudErrorAuthFailedCredentials => 'Authentication failed: Incorrect username or password';

  @override
  String get cloudErrorAccessDenied => 'Access denied: Please check permissions';

  @override
  String cloudErrorPathNotFound(String path) {
    return 'Server path not found: $path';
  }

  @override
  String cloudErrorNetwork(String message) {
    return 'Network error: $message';
  }

  @override
  String get cloudTestSuccessTitle => 'Test Successful';

  @override
  String get cloudTestSuccessMessage => 'Connection normal, configuration valid';

  @override
  String get cloudTestFailedTitle => 'Test Failed';

  @override
  String get cloudTestFailedMessage => 'Connection failed';

  @override
  String get cloudTestErrorTitle => 'Test Error';

  @override
  String get cloudSwitchConfirmTitle => 'Switch Cloud Service';

  @override
  String get cloudSwitchConfirmMessage => 'Switching cloud service will log out current account. Confirm switch?';

  @override
  String get cloudSwitchFailedTitle => 'Switch Failed';

  @override
  String get cloudSwitchFailedConfigMissing => 'Please configure this cloud service first';

  @override
  String get cloudConfigInvalidTitle => 'Invalid Configuration';

  @override
  String get cloudConfigInvalidMessage => 'Please fill in complete information';

  @override
  String get cloudSaveFailed => 'Save Failed';

  @override
  String cloudSwitchedTo(String type) {
    return 'Switched to $type';
  }

  @override
  String get cloudConfigureSupabaseTitle => 'Configure Supabase';

  @override
  String get cloudConfigureWebdavTitle => 'Configure WebDAV';

  @override
  String get cloudConfigureS3Title => 'Configure S3';

  @override
  String get cloudSupabaseAnonKeyHintLong => 'Paste complete anon key';

  @override
  String get cloudWebdavRemotePathHelp => 'Remote directory path for data storage';

  @override
  String get cloudWebdavRemotePathLabel => 'Remote Path';

  @override
  String get cloudWebdavRemotePathHelperText => 'Remote directory path for data storage';

  @override
  String get accountsTitle => 'Asset Management';

  @override
  String get accountsEmptyMessage => 'No accounts yet, tap the top right to add';

  @override
  String get accountAddTooltip => 'Add Account';

  @override
  String get accountAddButton => 'Add Account';

  @override
  String get accountBalance => 'Balance';

  @override
  String get accountEditTitle => 'Edit Account';

  @override
  String get accountNewTitle => 'New Account';

  @override
  String get accountNameLabel => 'Account Name';

  @override
  String get accountNameHint => 'e.g.: ICBC, Alipay, etc.';

  @override
  String get accountNameRequired => 'Please enter account name';

  @override
  String get accountNameDuplicate => 'Account name already exists, please use a different name';

  @override
  String get accountTypeLabel => 'Account Type';

  @override
  String get accountTypeCash => 'Cash';

  @override
  String get accountTypeBankCard => 'Bank Card';

  @override
  String get accountTypeCreditCard => 'Credit Card';

  @override
  String get accountTypeAlipay => 'Alipay';

  @override
  String get accountTypeWechat => 'WeChat';

  @override
  String get accountTypeOther => 'Other';

  @override
  String get accountInitialBalance => 'Initial Balance';

  @override
  String get accountInitialBalanceHint => 'Enter initial balance (optional)';

  @override
  String get accountDeleteWarningTitle => 'Confirm Delete';

  @override
  String accountDeleteWarningMessage(int count) {
    return 'This account has $count related transactions. After deletion, account information in transaction records will be cleared. Confirm deletion?';
  }

  @override
  String get accountDeleteConfirm => 'Confirm to delete this account?';

  @override
  String get accountSelectTitle => 'Select Account';

  @override
  String get accountNone => 'No Account';

  @override
  String get accountsEnableFeature => 'Enable Account Feature';

  @override
  String get privacyOpenSourceUrlError => 'Cannot open link';

  @override
  String get updateCorruptedFileTitle => 'Corrupted Installation Package';

  @override
  String get updateCorruptedFileMessage => 'The previously downloaded installation package is incomplete or corrupted. Delete and re-download?';

  @override
  String get welcomeTitle => 'Welcome to BeeCount';

  @override
  String get welcomeDescription => 'An accounting app that truly respects your privacy';

  @override
  String get welcomeCurrencyDescription => 'Choose your preferred currency, you can change it anytime in settings';

  @override
  String get welcomePrivacyTitle => 'Open Source · Community Driven';

  @override
  String get welcomePrivacyFeature1 => '100% open source code, supervised by community';

  @override
  String get welcomePrivacyFeature2 => 'No privacy concerns, data stored locally';

  @override
  String get welcomeOpenSourceFeature1 => 'Active developer community, continuous improvement';

  @override
  String get welcomeViewGitHub => 'Visit GitHub Repository';

  @override
  String get welcomeCloudSyncTitle => 'Optional Cloud Sync';

  @override
  String get welcomeCloudSyncDescription => 'BeeCount supports multiple sync methods - your data, your control';

  @override
  String get welcomeCloudSyncFeature1 => 'Completely offline usage, no cloud needed';

  @override
  String get welcomeCloudSyncFeature2 => 'BeeCount Cloud self-hosted (real-time multi-device + Web UI)';

  @override
  String get welcomeCloudSyncFeature3 => 'Or pick iCloud / WebDAV / Supabase / S3';

  @override
  String get widgetManagement => 'Home Screen Widget';

  @override
  String get widgetManagementDesc => 'Quick view of income and expenses on home screen';

  @override
  String get widgetPreview => 'Widget Preview';

  @override
  String get widgetPreviewDesc => 'Widget automatically displays actual data from current ledger, theme color follows app settings';

  @override
  String get howToAddWidget => 'How to Add Widget';

  @override
  String get iosWidgetStep1 => 'Long press on home screen blank area to enter edit mode';

  @override
  String get iosWidgetStep2 => 'Tap the \"+\" button in upper left corner';

  @override
  String get iosWidgetStep3 => 'Search and select \"BeeCount\"';

  @override
  String get iosWidgetStep4 => 'Select medium widget and add to home screen';

  @override
  String get androidWidgetStep1 => 'Long press on home screen blank area';

  @override
  String get androidWidgetStep2 => 'Select \"Widgets\"';

  @override
  String get androidWidgetStep3 => 'Find and long press \"BeeCount\" widget';

  @override
  String get androidWidgetStep4 => 'Drag to suitable position on home screen';

  @override
  String get aboutWidget => 'About Widget';

  @override
  String get widgetDescription => 'Widget automatically syncs to display today\'s and this month\'s income and expense data, refreshing every 30 minutes. Data updates immediately when app is opened.';

  @override
  String get widgetQuickEntryTitle => 'Quick Entry';

  @override
  String get widgetQuickEntryDesc => 'Tap the left side of the widget to quickly add an expense, or tap the right side to add an income. You can also use beecount://new?type=transfer via Shortcuts to quickly start a transfer.';

  @override
  String get appName => 'BeeCount';

  @override
  String get monthSuffix => '';

  @override
  String get todayExpense => 'Today\'s Expense';

  @override
  String get todayIncome => 'Today\'s Income';

  @override
  String get monthExpense => 'Month\'s Expense';

  @override
  String get monthIncome => 'Month\'s Income';

  @override
  String get autoScreenshotBilling => 'Auto Screenshot Billing';

  @override
  String get autoScreenshotBillingDesc => 'Auto-recognize payment info from screenshots';

  @override
  String get autoScreenshotBillingTitle => 'Auto Screenshot Billing';

  @override
  String get featureDescription => 'Feature Description';

  @override
  String get featureDescriptionContent => 'After taking a screenshot of payment page, the system will automatically recognize amount and merchant info, and create expense record.\n\n⚡ Recognition speed: 2-3 seconds (may be longer on some devices)\n🤖 Smart category matching\n📝 Auto-fill notes\n\n⚠️ Note:\n• Different devices have different screenshot save speeds, delay may be 5-10 seconds\n• May not work on some devices, depending on system implementation\n• Recognized screenshots will be skipped automatically\n• Due to Android Scoped Storage restrictions (Android 10+), apps cannot delete system screenshots. Manual cleanup required';

  @override
  String get autoBilling => 'Auto Billing';

  @override
  String get enabled => 'Enabled';

  @override
  String get disabled => 'Disabled';

  @override
  String get photosPermissionRequired => 'Photos permission required for screenshot monitoring';

  @override
  String get enableSuccess => 'Auto billing enabled';

  @override
  String get disableSuccess => 'Auto billing disabled';

  @override
  String get autoBillingBatteryTitle => 'Keep Running in Background';

  @override
  String get autoBillingBatteryGuideTitle => 'Battery Optimization Settings';

  @override
  String get autoBillingBatteryDesc => 'Auto billing requires the app to keep running in the background. Some phones automatically clean background apps when locked, which may cause auto billing to fail. It is recommended to disable battery optimization to ensure proper functionality.';

  @override
  String get autoBillingCheckBattery => 'Check Battery Optimization';

  @override
  String get autoBillingBatteryWarning => '⚠️ Battery optimization is not disabled. The app may be automatically cleaned by the system, causing auto billing to fail. Please tap the \"Settings\" button above to disable battery optimization.';

  @override
  String get enableFailed => 'Enable failed';

  @override
  String get disableFailed => 'Disable failed';

  @override
  String get iosAutoFeatureDesc => 'Use iOS \"Shortcuts\" app to automatically identify payment information from screenshots and create transactions. Once set up, it will automatically trigger on every screenshot.';

  @override
  String get iosAutoShortcutConfigTitle => 'Configuration Steps:';

  @override
  String get iosAutoShortcutStep1 => 'Open \"Shortcuts\" app, tap \"+\" in top right to create new shortcut';

  @override
  String get iosAutoShortcutStep2 => 'Add \"Take Screenshot\" action';

  @override
  String get iosAutoShortcutStep3 => 'Search and add \"BeeCount - Auto Billing\" action';

  @override
  String get iosAutoShortcutStep4 => 'Set the screenshot parameter of \"BeeCount\" to the previous \"Screenshot\"';

  @override
  String get iosAutoShortcutStep5 => '(Optional) Go to Settings > Accessibility > Touch > Back Tap, bind this shortcut';

  @override
  String get iosAutoShortcutStep6 => 'Done! Double tap phone back during payment for quick billing';

  @override
  String get iosAutoShortcutRecommendedTip => '✅ Recommended: After binding the shortcut to \"Back Tap\", double tap phone back during payment to auto-screenshot and recognize billing, no manual screenshot needed.';

  @override
  String get iosAutoBackTapTitle => '💡 Double Tap Back to Trigger (Recommended)';

  @override
  String get iosAutoBackTapDesc => 'Settings > Accessibility > Touch > Back Tap\n• Select \"Double Tap\" or \"Triple Tap\"\n• Choose the shortcut you just created\n• After setup, double tap phone back during payment to auto-record, no screenshot needed';

  @override
  String get iosAutoTutorialTitle => 'Video Tutorial';

  @override
  String get iosAutoTutorialDesc => 'Watch detailed setup video tutorial';

  @override
  String get aiSettingsTitle => 'AI Assistant';

  @override
  String get aiSettingsSubtitle => 'Configure AI models and recognition strategy';

  @override
  String get aiEnableTitle => 'Enable AI Assistant';

  @override
  String get aiEnableSubtitle => 'Use AI to enhance OCR accuracy, extract amount, merchant, time, and support natural language conversation';

  @override
  String get aiEnableToastOn => 'AI Assistant enabled';

  @override
  String get aiEnableToastOff => 'AI Assistant disabled';

  @override
  String get aiStrategyTitle => 'Execution Strategy';

  @override
  String get aiStrategyLocalFirst => 'Local First (Recommended)';

  @override
  String get aiStrategyCloudFirst => 'Cloud First';

  @override
  String get aiStrategyCloudFirstDesc => 'Use cloud API first, downgrade to local if failed';

  @override
  String get aiStrategyLocalOnly => 'Local Only';

  @override
  String get aiStrategyCloudOnly => 'Cloud Only';

  @override
  String get aiStrategyCloudOnlyDesc => 'Use cloud API only, no model download';

  @override
  String get aiStrategyUnavailable => 'Local model in training, coming soon';

  @override
  String aiStrategySwitched(String strategy) {
    return 'Switched to: $strategy';
  }

  @override
  String get aiCloudApiKeyHint => 'Enter your Zhipu AI API Key';

  @override
  String get aiCloudApiKeyHintCustom => 'Enter API Key';

  @override
  String get aiCloudApiKeyHelper => 'GLM-*-Flash model is completely free';

  @override
  String get aiCloudApiGetKey => 'Get API Key';

  @override
  String get aiCloudApiTutorial => 'Tutorial';

  @override
  String get aiCloudApiTestKey => 'Test Connection';

  @override
  String get aiChatConfigWarning => 'AI provider not configured. Please add and bind one in Settings';

  @override
  String get aiChatGoToSettings => 'Go to Settings';

  @override
  String get aiLocalModelTitle => 'Local Model';

  @override
  String get aiLocalModelTraining => 'Training';

  @override
  String get aiLocalModelUnavailable => 'Local model in training, not available yet';

  @override
  String get aiOcrRecognizing => 'Recognizing bill...';

  @override
  String get aiOcrNoAmount => 'No valid amount recognized, please add manually';

  @override
  String get aiOcrNoLedger => 'Ledger not found';

  @override
  String aiOcrSuccess(String type, String amount) {
    return '✅ $type bill created ¥$amount';
  }

  @override
  String aiOcrFailed(String error) {
    return 'Recognition failed: $error';
  }

  @override
  String get aiOcrCreateFailed => 'Failed to create bill';

  @override
  String get aiTypeIncome => 'Income';

  @override
  String get aiTypeExpense => 'Expense';

  @override
  String get cloudSyncPageTitle => 'Cloud Sync';

  @override
  String get cloudSyncPageSubtitle => 'Manual upload and download ledger data';

  @override
  String get cloudTutorialTitle => 'Getting Started';

  @override
  String get cloudTutorialIntro => 'BeeCount Cloud is a self-hosted sync server that supports real-time multi-device collaboration. The flow is simple:';

  @override
  String get cloudTutorialStep1Title => 'Step 1: Deploy or join a server';

  @override
  String get cloudTutorialStep1Desc => 'Self-host with one Docker command (see the Docker guide in GitHub README). Or join an existing BeeCount Cloud server run by a friend / team.';

  @override
  String get cloudTutorialStep2Title => 'Step 2: Get an account';

  @override
  String get cloudTutorialStep2Desc => 'BeeCount Cloud does NOT offer self-registration (to prevent abuse on public servers). If you self-host: the first Docker boot prints a random admin email + password to the logs — use that. Joining someone else\'s server: ask the admin to create an account for you in Web → Users.';

  @override
  String get cloudTutorialStep3Title => 'Step 3: Login + enable sync';

  @override
  String get cloudTutorialStep3Desc => 'In the app, pick BeeCount Cloud, enter the server URL and the account you got in step 2. First login uploads your entire local ledger; every subsequent edit is pushed in real time.';

  @override
  String get cloudTutorialStep4Title => 'Step 4: Login from other devices';

  @override
  String get cloudTutorialStep4Desc => 'Phone / tablet / Web — same account, instant shared state. Edits propagate within seconds.';

  @override
  String get cloudTutorialTipTitle => 'Tip';

  @override
  String get cloudTutorialTipDesc => 'The Web UI lives at the server URL. Open it in a browser to manage ledgers, members, and view logs.';

  @override
  String get cloudTutorialFeaturesTitle => 'Features';

  @override
  String get cloudTutorialFeature1 => '📱 Real-time multi-device: phone A + phone B + Web on one account, sub-second sync';

  @override
  String get cloudTutorialFeature2 => '🌐 Web UI included: one Docker image ships server + Web, browser ready';

  @override
  String get cloudTutorialFeature3 => '👥 Multi-user isolation: multiple users on one server, data fully separated';

  @override
  String get cloudTutorialFeature4 => '🤝 Shared ledgers: invite family / team into one book with seconds-level sync';

  @override
  String get cloudTutorialGotIt => 'Got it';

  @override
  String get cloudSyncHint => 'Downloads automatically compare differences for selective preview. Not real-time — avoid editing the same ledger on multiple devices simultaneously. Sync scope covers ledger data (including associated accounts, categories, and tags), excluding attachments.';

  @override
  String get cloudSyncNow => 'Sync Now';

  @override
  String get cloudSyncNowHint => 'Push local changes and pull remote updates';

  @override
  String get cloudSyncInProgress => 'Syncing...';

  @override
  String cloudSyncComplete(int pushed, int pulled) {
    return 'Sync complete: pushed $pushed, pulled $pulled';
  }

  @override
  String get cloudAutoSyncHint => 'Auto-sync to cloud after data changes';

  @override
  String get dataManagement => 'Data Management';

  @override
  String get dataManagementDesc => 'Import, export, categories and accounts';

  @override
  String get dataManagementPageTitle => 'Data Management';

  @override
  String get dataManagementPageSubtitle => 'Manage transaction data and categories';

  @override
  String get dataManagementAttachmentHint => 'When restoring data, please import the attachment package first, then import ledger data (CSV or cloud sync) to ensure attachments are correctly associated.';

  @override
  String get smartBilling => 'Smart Billing';

  @override
  String get smartBillingDesc => 'AI Assistant, OCR scan, auto billing';

  @override
  String get smartBillingPageTitle => 'Smart Billing';

  @override
  String get smartBillingPageSubtitle => 'AI and automation billing features';

  @override
  String get smartBillingGuideHint => 'Long press the + button at the bottom center of the home page to quickly access these features';

  @override
  String get smartBillingImageBilling => 'Image Billing';

  @override
  String get smartBillingImageBillingDesc => 'Select payment screenshots from gallery for recognition';

  @override
  String get smartBillingImageBillingGuide => 'Long press the + button at the bottom center of the home page and select \'Gallery\' to use image billing. With AI configured, it can intelligently recognize bill information; without AI, it can still extract text via OCR.';

  @override
  String get smartBillingAIOptional => 'AI recognition is optional, configuration can improve recognition accuracy';

  @override
  String get smartBillingCameraBilling => 'Camera Billing';

  @override
  String get smartBillingCameraBillingDesc => 'Capture payment screenshots for recognition';

  @override
  String get smartBillingCameraBillingGuide => 'Long press the + button at the bottom center of the home page and select \'Camera\' to use camera billing. With AI configured, it can intelligently recognize bill information; without AI, it can still extract text via OCR.';

  @override
  String get smartBillingVoiceBilling => 'Voice Billing';

  @override
  String get smartBillingVoiceBillingDesc => 'Quick billing through voice input';

  @override
  String get smartBillingVoiceBillingGuide => 'Long press the + button at the bottom center of the home page and select \'Voice\' to use voice billing. Voice billing requires AI to convert speech to text and extract bill information.';

  @override
  String get smartBillingAIRequired => 'Voice billing requires AI configuration (Zhipu GLM API), please configure AI settings above first';

  @override
  String get smartBillingAutoTags => 'Auto-associate Tags';

  @override
  String get smartBillingAutoTagsDesc => 'Automatically associate frequently used tags based on category';

  @override
  String get smartBillingAutoAttachment => 'Auto-add Attachment';

  @override
  String get smartBillingAutoAttachmentDesc => 'Automatically add original image as attachment for photo billing';

  @override
  String get autoScreenshotBillingIosDesc => 'Auto-recognize payment screenshots via Shortcuts';

  @override
  String get automation => 'Automation';

  @override
  String get automationDesc => 'Recurring transactions and reminders';

  @override
  String get automationPageTitle => 'Automation';

  @override
  String get automationPageSubtitle => 'Recurring transactions and reminder settings';

  @override
  String get appearanceSettings => 'Appearance';

  @override
  String get appearanceSettingsDesc => 'Theme, font and language settings';

  @override
  String get appearanceSettingsPageTitle => 'Appearance';

  @override
  String get appearanceSettingsPageSubtitle => 'Personalize appearance and display';

  @override
  String get about => 'About';

  @override
  String get aboutDesc => 'Version info, help and feedback';

  @override
  String get mineRateApp => 'Rate the App';

  @override
  String get mineRateAppSubtitle => 'Rate us on the App Store';

  @override
  String get aboutPageTitle => 'About';

  @override
  String get aboutPageSubtitle => 'App information and help';

  @override
  String get aboutPageLoadingVersion => 'Loading version...';

  @override
  String get aboutWebsite => 'Official Website';

  @override
  String get aboutGitHubRepo => 'GitHub Repository';

  @override
  String get aboutXiaohongshu => 'Xiaohongshu';

  @override
  String get aboutDouyin => 'Douyin';

  @override
  String get aboutSupportDevelopment => 'Support Development';

  @override
  String get aboutSupportDevelopmentSubtitle => 'Buy me a coffee';

  @override
  String get aboutDeveloperStoryTitle => 'From the Developer';

  @override
  String get aboutDeveloperStory => 'I started tracking my expenses in 2015 as an intern, and I\'ve kept the habit for over a decade. Concerned about ads, paywalls, privacy risks, and apps shutting down, I decided to build my own — first as a small tool for myself and my family.\n\nIn September 2025, BeeCount launched its first version. Honestly, I had no idea if anyone would use it. But gradually, feedback started coming in — someone said they finally found a clean budgeting app, others offered great suggestions, and some quietly left five-star reviews. Every single message reminded me this was worth continuing.\n\nBeeCount is ad-free, subscription-free, and fully open source. All your data stays on your device and is never uploaded to any third-party server. But publishing and maintaining an app isn\'t free — developer accounts, servers, and other costs are currently covered by community donations, and every system update, bug fix, and new feature is built outside of my day job.\n\nIf BeeCount has been helpful to you, a rating, a share, or a donation would help this little project go further. Thank you for your trust.';

  @override
  String get aboutRelatedProducts => 'More Products';

  @override
  String get aboutBeeAssets => 'BeeAssets';

  @override
  String get aboutBeeAssetsSubtitle => 'Visualize your full asset portfolio';

  @override
  String get aboutBeeAssetsIntro => 'BeeCount focuses on daily cash flow; BeeAssets is its sibling product, focused on asset portfolio visualization: net worth trends across accounts, property / investment / crypto classification, returns, holding period, and allocation breakdown.';

  @override
  String get aboutBeeDNS => 'BeeDNS';

  @override
  String get aboutBeeDNSSubtitle => 'Simple and efficient DNS management tool';

  @override
  String get aboutBeeDNSIntro => 'Got domains across Cloudflare and Aliyun? BeeDNS unifies them in one place: batch edit records, A/AAAA toggles, resolution migration, subdomain bulk management — no more switching between provider consoles.';

  @override
  String get productPromoAndroidTitle => 'Request Beta Access';

  @override
  String get productPromoAndroidMessage => 'This app is still in closed testing on Google Play — invitation only.\n\nHow to apply: email us with your Google account address (required) and a brief use case (optional). We\'ll reply within 1-3 days and add you to the beta whitelist.';

  @override
  String get productPromoOpenStore => 'Open in App Store';

  @override
  String get productPromoTestFlight => 'TestFlight beta';

  @override
  String get productPromoLearnMore => 'Pro';

  @override
  String get productPromoEmailLabel => 'Application Email (tap to copy)';

  @override
  String get productPromoCopiedToast => 'Email copied to clipboard';

  @override
  String get productPromoMailUnavailable => 'No email app detected. The address has been copied — paste it into any mail app to send.';

  @override
  String get productPromoEmailButton => 'Send Email';

  @override
  String get productPromoWebsiteButton => 'Visit Website';

  @override
  String productPromoEmailSubject(String productName) {
    return 'Beta access request - $productName';
  }

  @override
  String productPromoEmailBody(String productName) {
    return 'Hi,\n\nI\'d like to join the closed beta for $productName on Google Play. My Google account email is:\n\n(please fill in your Gmail / Google account email)\n\nThanks!';
  }

  @override
  String get logCenterTitle => 'Log Center';

  @override
  String get logCenterSubtitle => 'View app runtime logs';

  @override
  String get logCenterSearchHint => 'Search log content or tags...';

  @override
  String get logCenterFilterLevel => 'Log Level';

  @override
  String get logCenterFilterPlatform => 'Platform';

  @override
  String get logCenterTotal => 'Total';

  @override
  String get logCenterFiltered => 'Filtered';

  @override
  String get logCenterEmpty => 'No logs';

  @override
  String get logCenterExport => 'Export';

  @override
  String get logCenterClear => 'Clear';

  @override
  String get logCenterExportFailed => 'Export failed';

  @override
  String get logCenterClearConfirmTitle => 'Clear Logs';

  @override
  String get logCenterClearConfirmMessage => 'Are you sure you want to clear all logs? This action cannot be undone.';

  @override
  String get logCenterCleared => 'Logs cleared';

  @override
  String get logCenterCopied => 'Copied to clipboard';

  @override
  String get configImportExportTitle => 'Config Import/Export';

  @override
  String get configImportExportSubtitle => 'Backup and restore app configurations';

  @override
  String get configImportExportInfoTitle => 'Feature Description';

  @override
  String get configImportExportInfoMessage => 'This feature is used to export and import app configurations, including cloud service settings, AI settings, etc. The config file uses YAML format for easy viewing and editing.\n\n⚠️ Config files contain sensitive information (such as API keys, passwords, etc.), please keep them safe.';

  @override
  String get configExportTitle => 'Export Config';

  @override
  String get configExportSubtitle => 'Export current config to YAML file';

  @override
  String get configExportShareSubject => 'BeeCount Config File';

  @override
  String get configExportSuccess => 'Config exported successfully';

  @override
  String get configExportFailed => 'Config export failed';

  @override
  String get configImportTitle => 'Import Config';

  @override
  String get configImportSubtitle => 'Restore config from YAML file';

  @override
  String get configImportNoFilePath => 'No file selected';

  @override
  String get configImportConfirmTitle => 'Confirm Import';

  @override
  String get configImportSuccess => 'Config imported successfully';

  @override
  String get configImportFailed => 'Config import failed';

  @override
  String get configImportRestartTitle => 'Restart Required';

  @override
  String get configImportRestartMessage => 'Config has been imported. Some settings will take effect after restarting the app.';

  @override
  String get configImportExportIncludesTitle => 'Included Configurations';

  @override
  String configExportSavedTo(String path) {
    return 'Saved to: $path';
  }

  @override
  String get configExportViewContent => 'View Content';

  @override
  String get configExportCopyContent => 'Copy Content';

  @override
  String get configExportContentCopied => 'Copied to clipboard';

  @override
  String get configExportReadFileFailed => 'Failed to read file';

  @override
  String get configIncludeLedgers => 'Ledgers';

  @override
  String get configIncludeSupabase => 'Supabase cloud service config';

  @override
  String get configIncludeWebdav => 'WebDAV cloud service config';

  @override
  String get configIncludeS3 => 'S3 cloud service config';

  @override
  String get configIncludeAI => 'AI smart recognition config';

  @override
  String get configIncludeAISubtitle => 'Providers, capability binding, model settings, etc.';

  @override
  String get configIncludeAppSettings => 'App settings (language, appearance, reminder, default account, etc.)';

  @override
  String get configIncludeRecurringTransactions => 'Recurring transactions';

  @override
  String get configIncludeAccounts => 'Accounts';

  @override
  String get configIncludeCategories => 'Categories';

  @override
  String get configIncludeTags => 'Tags';

  @override
  String get configIncludeBudgets => 'Budgets';

  @override
  String get configIncludeOtherSettings => 'Other Settings';

  @override
  String get configIncludeOtherSettingsSubtitle => 'Including cloud service, AI config, app settings, etc.';

  @override
  String get configExportSelectTitle => 'Select Export Content';

  @override
  String get configExportPreviewTitle => 'Export Preview';

  @override
  String get configExportConfirmTitle => 'Confirm Export';

  @override
  String get configImportSelectTitle => 'Select Import Content';

  @override
  String get configImportPreviewTitle => 'Import Preview';

  @override
  String get ledgersConflictTitle => 'Sync Conflict';

  @override
  String get ledgersConflictMessage => 'Local and cloud ledger data are inconsistent, please choose an action:';

  @override
  String ledgersConflictLocalInfo(int count) {
    return 'Local: $count transactions';
  }

  @override
  String ledgersConflictRemoteInfo(int count) {
    return 'Cloud: $count transactions';
  }

  @override
  String ledgersConflictRemoteUpdated(String time) {
    return 'Cloud updated: $time';
  }

  @override
  String ledgersConflictLocalFingerprint(String fp) {
    return 'Local fingerprint: $fp';
  }

  @override
  String ledgersConflictRemoteFingerprint(String fp) {
    return 'Cloud fingerprint: $fp';
  }

  @override
  String get ledgersConflictUpload => 'Upload to Cloud';

  @override
  String get ledgersConflictDownload => 'Download to Local';

  @override
  String get ledgersConflictUploading => 'Uploading...';

  @override
  String get ledgersConflictDownloading => 'Downloading...';

  @override
  String get ledgersConflictUploadSuccess => 'Upload successful';

  @override
  String ledgersConflictDownloadSuccess(int inserted) {
    return 'Download successful, merged $inserted transactions';
  }

  @override
  String get storageManagementTitle => 'Storage Management';

  @override
  String get storageManagementSubtitle => 'Clear cache to free up space';

  @override
  String get storageAIModels => 'AI Models';

  @override
  String get storageAPKFiles => 'Installation Packages';

  @override
  String get storageNoData => 'No Data';

  @override
  String get storageFiles => 'files';

  @override
  String get storageHint => 'Tap items to clear corresponding cache files';

  @override
  String get storageClearConfirmTitle => 'Confirm Clear';

  @override
  String storageClearAIModelsMessage(String size) {
    return 'Are you sure you want to clear all AI models? Size: $size';
  }

  @override
  String storageClearAPKMessage(String size) {
    return 'Are you sure you want to clear all installation packages? Size: $size';
  }

  @override
  String get storageClearSuccess => 'Cleared successfully';

  @override
  String get accountNoTransactions => 'No transactions';

  @override
  String get accountTransactionHistory => 'Transaction History';

  @override
  String get accountTotalBalance => 'Net Assets';

  @override
  String get accountCurrencyLocked => 'This account has transactions and cannot change currency';

  @override
  String get accountDefaultIncomeTitle => 'Default Income Account';

  @override
  String get accountDefaultExpenseTitle => 'Default Expense Account';

  @override
  String get accountDefaultNone => 'Not Set';

  @override
  String get commonNotice => 'Notice';

  @override
  String get transferTitle => 'Transfer';

  @override
  String get transferIconSettings => 'Transfer Icon Settings';

  @override
  String get transferIconSettingsDesc => 'Customize the display icon for transfer records';

  @override
  String get transferFromAccount => 'From Account';

  @override
  String get transferToAccount => 'To Account';

  @override
  String get transferSelectAccount => 'Select Account';

  @override
  String get transferCreateSuccess => 'Transfer created successfully';

  @override
  String get transferUpdateSuccess => 'Transfer updated successfully';

  @override
  String get transferDifferentCurrencyError => 'Transfer only supports accounts with the same currency';

  @override
  String get transferToPrefix => 'To';

  @override
  String get transferFromPrefix => 'From';

  @override
  String get welcomeCategoryModeTitle => 'Choose Category Mode';

  @override
  String get welcomeCategoryModeDescription => 'Select the category structure that suits your needs';

  @override
  String get welcomeCategoryModeFlatTitle => 'Flat Categories';

  @override
  String get welcomeCategoryModeFlatDescription => 'Simple and fast';

  @override
  String get welcomeCategoryModeFlatFeature1 => 'Flat structure, easy to use';

  @override
  String get welcomeCategoryModeFlatFeature2 => 'Perfect for simple categorization';

  @override
  String get welcomeCategoryModeFlatFeature3 => 'Quick selection, efficient tracking';

  @override
  String get welcomeCategoryModeHierarchicalTitle => 'Hierarchical Categories';

  @override
  String get welcomeCategoryModeHierarchicalDescription => 'Detailed management';

  @override
  String get welcomeCategoryModeHierarchicalFeature1 => 'Support parent-child category levels';

  @override
  String get welcomeCategoryModeHierarchicalFeature2 => 'More detailed transaction classification';

  @override
  String get welcomeCategoryModeHierarchicalFeature3 => 'Perfect for detailed management';

  @override
  String get welcomeCategoryModeNoneTitle => 'No Categories';

  @override
  String get welcomeCategoryModeNoneDescription => 'Fully customizable, add as needed';

  @override
  String get welcomeCategoryModeNoneFeature1 => 'No preset categories';

  @override
  String get welcomeCategoryModeNoneFeature2 => 'Create categories based on your needs';

  @override
  String get welcomeCategoryModeNoneFeature3 => 'Perfect for custom classification needs';

  @override
  String get welcomeExistingUserTitle => 'Existing User?';

  @override
  String get welcomeExistingUserButton => 'Import Config';

  @override
  String get welcomeImportingConfig => 'Importing configuration...';

  @override
  String get welcomeImportSuccess => 'Configuration imported successfully';

  @override
  String welcomeImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get welcomeImportNoFile => 'No file selected';

  @override
  String get welcomeImportAttachmentTitle => 'Import Attachments';

  @override
  String get welcomeImportAttachmentDesc => 'Would you like to import attachment files as well?';

  @override
  String get welcomeImportAttachmentButton => 'Select Attachment File';

  @override
  String get welcomeImportAttachmentSkip => 'Skip';

  @override
  String welcomeImportAttachmentSuccess(int imported) {
    return 'Attachments imported: $imported';
  }

  @override
  String welcomeImportAttachmentFailed(String error) {
    return 'Attachment import failed: $error';
  }

  @override
  String get welcomeImportingAttachment => 'Importing attachments...';

  @override
  String get iosVersionWarningTitle => 'Requires iOS 16.0 or later';

  @override
  String get iosVersionWarningDesc => 'Screenshot auto-billing feature uses the App Intents framework introduced in iOS 16. Your device is running an older version and does not support this feature.\n\nPlease upgrade to iOS 16 or later to use this feature.';

  @override
  String get aiChatTitle => 'AI Assistant';

  @override
  String get aiChatClearHistory => 'Clear History';

  @override
  String get aiChatClearHistoryDialogTitle => 'Clear Conversation History';

  @override
  String get aiChatClearHistoryDialogContent => 'Are you sure you want to clear all conversation records? This action cannot be undone.';

  @override
  String get aiChatInputHint => 'e.g.: Bought a coffee for \$35';

  @override
  String get aiChatThinking => 'Thinking...';

  @override
  String get aiChatHistoryCleared => 'Conversation history cleared';

  @override
  String get aiChatCopy => 'Copy';

  @override
  String get aiChatCopied => 'Copied to clipboard';

  @override
  String get aiChatDeleteMessageConfirm => 'Are you sure you want to delete this message?';

  @override
  String get aiChatMessageDeleted => 'Message deleted';

  @override
  String get aiChatUndone => 'Undone';

  @override
  String get aiChatUndoFailed => 'Undo failed';

  @override
  String get aiChatTransactionNotFound => 'Transaction not found';

  @override
  String get aiChatOpenEditorFailed => 'Failed to open editor';

  @override
  String get aiChatSendFailed => 'Failed to send';

  @override
  String get billCardSuccess => 'Booking Successful';

  @override
  String get billCardUndone => 'Undone';

  @override
  String get billCardAmount => '💰 Amount';

  @override
  String get billCardCategory => '🏷️ Category';

  @override
  String get billCardTime => '📅 Time';

  @override
  String get billCardNote => '📝 Note';

  @override
  String get billCardAccount => '💳 Account';

  @override
  String get billCardUndo => 'Undo';

  @override
  String get billCardEdit => 'Edit';

  @override
  String get donationTitle => 'Donate';

  @override
  String get donationSubtitle => 'Buy me a coffee';

  @override
  String get donationEntrySubtitle => 'Support continued development';

  @override
  String get donationDescription => 'Description';

  @override
  String get donationDescriptionDetail => 'Thank you for using BeeCount! If this app helps you, feel free to buy the developer a coffee as encouragement. Your support is my motivation to keep improving.';

  @override
  String get donationNoFeatures => 'Note: Donations will not unlock any features. All features remain completely free.';

  @override
  String get donationNoProducts => 'No products available';

  @override
  String get donationThankYouTitle => 'Thank You!';

  @override
  String donationThankYouMessage(String productName) {
    return 'Thank you for purchasing $productName! Your support means a lot to me. I will continue to improve BeeCount to make it even better!';
  }

  @override
  String get aiQuickCommandFinancialHealthTitle => 'Financial Health Analysis';

  @override
  String get aiQuickCommandFinancialHealthDesc => 'Analyze income-expense balance and savings rate';

  @override
  String get aiQuickCommandFinancialHealthPrompt => 'Please analyze my financial health based on the following data:\n\n[monthlyStats]\n\n[recentTrends]\n\nPlease provide professional analysis and suggestions from the perspectives of income-expense balance, savings rate, and spending trends. Please respond in English.';

  @override
  String get aiQuickCommandMonthlyExpenseTitle => 'Monthly Expense Summary';

  @override
  String get aiQuickCommandMonthlyExpenseDesc => 'Monthly expense analysis and recommendations';

  @override
  String get aiQuickCommandMonthlyExpensePrompt => 'Please summarize my monthly expenses based on the following data:\n\n[monthlyStats]\n\n[categoryStats]\n\nPlease analyze which categories account for the highest proportion and provide optimization suggestions. Please respond in English.';

  @override
  String get aiQuickCommandCategoryAnalysisTitle => 'Category Analysis';

  @override
  String get aiQuickCommandCategoryAnalysisDesc => 'Analyze spending distribution by category';

  @override
  String get aiQuickCommandCategoryAnalysisPrompt => 'Please analyze my spending by category based on the following data:\n\n[categoryStats]\n\nPlease point out whether there are unreasonable spending ratios and provide optimization suggestions. Please respond in English.';

  @override
  String get aiQuickCommandBudgetPlanningTitle => 'Budget Planning';

  @override
  String get aiQuickCommandBudgetPlanningDesc => 'Smart budget recommendations';

  @override
  String get aiQuickCommandBudgetPlanningPrompt => 'Please help me plan a reasonable budget based on the following data:\n\n[monthlyStats]\n\n[recentTrends]\n\nPlease provide specific budget amounts and execution suggestions for each category. Please respond in English.';

  @override
  String get aiQuickCommandAbnormalExpenseTitle => 'Abnormal Expense Alert';

  @override
  String get aiQuickCommandAbnormalExpenseDesc => 'Identify unusual spending';

  @override
  String get aiQuickCommandAbnormalExpensePrompt => 'Please check if there are any abnormal expenses based on the following data:\n\n[recentTransactions]\n\n[monthlyStats]\n\nPlease identify significantly higher expenses than usual and provide analysis. Please respond in English.';

  @override
  String get aiQuickCommandSavingTipsTitle => 'Saving Tips';

  @override
  String get aiQuickCommandSavingTipsDesc => 'Personalized money-saving suggestions';

  @override
  String get aiQuickCommandSavingTipsPrompt => 'Please provide practical money-saving suggestions based on the following data:\n\n[categoryStats]\n\n[recentTrends]\n\nPlease give 3-5 specific and actionable suggestions. Please respond in English.';

  @override
  String get billCardUnknownLedger => 'Unknown Ledger';

  @override
  String get aiPromptEditTitle => 'Prompt Editor';

  @override
  String get aiPromptEditSubtitle => 'Customize AI bill recognition prompt';

  @override
  String get aiPromptAdvancedSettings => 'Advanced Settings';

  @override
  String get aiAdvancedSettingsDesc => 'Model selection, strategy, local model, prompt';

  @override
  String get aiPromptEditEntry => 'Prompt Editor';

  @override
  String get aiPromptEditEntryDesc => 'Customize AI bill recognition prompt, shareable with others';

  @override
  String get aiPromptVariables => 'Variables';

  @override
  String get aiPromptVariablesHint => 'Tap to view available variables';

  @override
  String get aiPromptContent => 'Prompt Content';

  @override
  String get aiPromptUnsaved => 'Unsaved';

  @override
  String get aiPromptInputHint => 'Enter prompt...';

  @override
  String get aiPromptPreview => 'Preview';

  @override
  String get aiPromptSave => 'Save';

  @override
  String get aiPromptSaved => 'Prompt saved';

  @override
  String get aiPromptResetDefault => 'Reset to Default';

  @override
  String get aiPromptResetConfirmTitle => 'Reset to Default';

  @override
  String get aiPromptResetConfirmMessage => 'Are you sure you want to reset to default prompt? Your custom content will be lost.';

  @override
  String get aiPromptPasted => 'Pasted';

  @override
  String get aiPromptPreviewTitle => 'Prompt Preview';

  @override
  String get aiPromptPreviewNote => 'Preview uses sample data for variables. Real data will be used at runtime.';

  @override
  String get aiPromptVarInputSource => 'Input source description, e.g. \"From the following payment bill text\"';

  @override
  String get aiPromptVarCurrentTime => 'Current date and time, e.g. \"2025-01-15 14:30\"';

  @override
  String get aiPromptVarCurrentDate => 'Current date, e.g. \"2025-01-15\"';

  @override
  String get aiPromptVarOcrText => 'User input or OCR recognized text content';

  @override
  String get aiPromptVarCategories => 'Expense and income category list';

  @override
  String get aiPromptVarAccounts => 'User\'s account list (may be empty)';

  @override
  String get aiModelTitle => 'Text Reasoning Model';

  @override
  String get aiVisionModelTitle => 'Vision Model';

  @override
  String get aiModelFast => 'Faster';

  @override
  String get aiModelAccurate => 'Accurate';

  @override
  String aiModelSwitched(String modelName) {
    return 'Switched to $modelName';
  }

  @override
  String get aiUsingVisionDesc => 'Image recognition is enabled for higher recognition accuracy';

  @override
  String get aiUnUsingVisionDesc => 'Image recognition turned off, OCR text only';

  @override
  String get aiUploadImage => 'Upload images to AI';

  @override
  String get aiUseVisionDesc => 'Use visual models for more accurate recognition';

  @override
  String get aiUnUseVisionDesc => 'Analyze OCR results using only text models';

  @override
  String get aiCustomBaseUrlHelper => 'Standard chat completion API URL, e.g. https://api.example.com/v1';

  @override
  String get aiTextModelTitle => 'Text Model';

  @override
  String get aiAudioModelTitle => 'Audio Model';

  @override
  String get tagManageTitle => 'Tags';

  @override
  String get tagManageSubtitle => 'Manage transaction tags';

  @override
  String get tagManageEmpty => 'No tags yet';

  @override
  String get tagManageEmptyHint => 'Tap + to add a tag';

  @override
  String get tagManageGenerateDefault => 'Generate Default Tags';

  @override
  String get tagManageGenerateDefaultConfirm => 'Generate default tags? Existing tags with the same name will not be overwritten.';

  @override
  String get tagManageGenerateDefaultSuccess => 'Default tags generated';

  @override
  String get tagEditTitle => 'Edit Tag';

  @override
  String get tagAddTitle => 'Add Tag';

  @override
  String get tagNameLabel => 'Tag Name';

  @override
  String get tagNameHint => 'Enter tag name';

  @override
  String get tagNameRequired => 'Tag name is required';

  @override
  String get tagNameDuplicate => 'Tag name already exists';

  @override
  String get tagColorLabel => 'Tag Color';

  @override
  String get tagCreateSuccess => 'Tag created';

  @override
  String get tagUpdateSuccess => 'Tag updated';

  @override
  String get tagDeleteConfirmTitle => 'Delete Tag';

  @override
  String tagDeleteConfirmMessage(String name) {
    return 'Delete tag \"$name\"? This will not affect associated transactions.';
  }

  @override
  String get tagDeleteSuccess => 'Tag deleted';

  @override
  String get tagSelectTitle => 'Select Tags';

  @override
  String get tagSelectHint => 'Multiple selection';

  @override
  String get tagSelectCreateNew => 'Create New Tag';

  @override
  String get tagSelectRecentlyUsed => 'Recently Used';

  @override
  String get tagSelectAllTags => 'All Tags';

  @override
  String tagTransactionCount(int count) {
    return '$count transactions';
  }

  @override
  String get tagDetailTitle => 'Tag Details';

  @override
  String get tagDetailTotalCount => 'Transactions';

  @override
  String get tagDetailTotalExpense => 'Total Expense';

  @override
  String get tagDetailTotalIncome => 'Total Income';

  @override
  String get tagDetailTransactionList => 'Related Transactions';

  @override
  String get tagDetailNoTransactions => 'No related transactions';

  @override
  String get tagDetailNoTransactionsHint => 'Transactions with this tag will appear here';

  @override
  String get tagNotFound => 'Tag not found';

  @override
  String get tagDefaultMeituan => 'Meituan';

  @override
  String get tagDefaultEleme => 'Eleme';

  @override
  String get tagDefaultTaobao => 'Taobao';

  @override
  String get tagDefaultJD => 'JD.com';

  @override
  String get tagDefaultPDD => 'Pinduoduo';

  @override
  String get tagDefaultStarbucks => 'Starbucks';

  @override
  String get tagDefaultLuckin => 'Luckin Coffee';

  @override
  String get tagDefaultMcDonalds => 'McDonald\'s';

  @override
  String get tagDefaultKFC => 'KFC';

  @override
  String get tagDefaultHema => 'Hema';

  @override
  String get tagDefaultSams => 'Sam\'s Club';

  @override
  String get tagDefaultCostco => 'Costco';

  @override
  String get tagDefaultBusinessTrip => 'Business Trip';

  @override
  String get tagDefaultTravel => 'Travel';

  @override
  String get tagDefaultDining => 'Dining Out';

  @override
  String get tagDefaultOnlineShopping => 'Online Shopping';

  @override
  String get tagDefaultDaily => 'Daily';

  @override
  String get tagDefaultReimbursement => 'Reimbursable';

  @override
  String get tagDefaultRefundable => 'Refundable';

  @override
  String get tagDefaultRefunded => 'Refunded';

  @override
  String get tagDefaultVoiceBilling => 'Voice';

  @override
  String get tagDefaultImageBilling => 'Image';

  @override
  String get tagDefaultCameraBilling => 'Camera';

  @override
  String get tagDefaultAiBilling => 'AI';

  @override
  String get tagShare => 'Share Tags';

  @override
  String get tagImport => 'Import Tags';

  @override
  String get tagClearUnused => 'Clear Unused';

  @override
  String tagShareSuccess(String path) {
    return 'Saved to $path';
  }

  @override
  String get tagShareSubject => 'BeeCount Tags Configuration';

  @override
  String get tagShareFailed => 'Share failed';

  @override
  String get tagImportInvalidFile => 'Please select a YAML file';

  @override
  String get tagImportNoTags => 'No tags found in file';

  @override
  String get tagImportModeTitle => 'Select Import Mode';

  @override
  String get tagImportModeMerge => 'Merge';

  @override
  String get tagImportModeMergeDesc => 'Keep existing tags, add new ones';

  @override
  String get tagImportModeOverwrite => 'Overwrite';

  @override
  String get tagImportModeOverwriteDesc => 'Clear unused tags before import';

  @override
  String get tagImportSuccess => 'Import successful';

  @override
  String get tagImportFailed => 'Import failed';

  @override
  String get tagClearUnusedEmpty => 'No unused tags';

  @override
  String get tagClearUnusedTitle => 'Clear Unused Tags';

  @override
  String tagClearUnusedMessage(int count) {
    return 'Delete $count unused tags?';
  }

  @override
  String tagClearUnusedSuccess(int count) {
    return 'Deleted $count tags';
  }

  @override
  String get tagClearUnusedFailed => 'Clear failed';

  @override
  String get homeSwitchLedger => 'Select Ledger';

  @override
  String get homeManageLedgers => 'Manage Ledgers';

  @override
  String get budgetTitle => 'Budget';

  @override
  String get budgetShowOnHome => 'Show budget on home';

  @override
  String get budgetEmptyHint => 'No budget set yet';

  @override
  String get budgetAddTotal => 'Add Total Budget';

  @override
  String get budgetMonthlyBudget => 'Monthly Budget';

  @override
  String get budgetUsed => 'Used';

  @override
  String get budgetRemaining => 'Remaining';

  @override
  String budgetDaysRemaining(int days) {
    return '$days days remaining';
  }

  @override
  String budgetDailyAvailable(String amount) {
    return 'Daily available $amount';
  }

  @override
  String get budgetCategoryBudgets => 'Category Budgets';

  @override
  String get budgetEditTitle => 'Edit Budget';

  @override
  String get budgetAddTitle => 'Add Budget';

  @override
  String get budgetTypeTotalLabel => 'Total Budget';

  @override
  String get budgetTypeCategoryLabel => 'Category Budget';

  @override
  String get budgetAmountLabel => 'Budget Amount';

  @override
  String get budgetAmountHint => 'Enter budget amount';

  @override
  String get budgetCategoryLabel => 'Select Category';

  @override
  String get budgetCategoryHint => 'Select budget category';

  @override
  String get budgetStartDayLabel => 'Start Day';

  @override
  String get budgetPeriodLabel => 'Period';

  @override
  String get budgetSaveSuccess => 'Budget saved';

  @override
  String get budgetDeleteConfirm => 'Delete this budget?';

  @override
  String get budgetDeleteSuccess => 'Budget deleted';

  @override
  String get attachmentAdd => 'Add Image';

  @override
  String get attachmentTakePhoto => 'Take Photo';

  @override
  String get attachmentChooseFromGallery => 'Choose from Gallery';

  @override
  String get attachmentMaxReached => 'Maximum attachments reached';

  @override
  String get attachmentDeleteConfirm => 'Delete this attachment?';

  @override
  String attachmentCount(int count) {
    return '$count images';
  }

  @override
  String get commonDeleted => 'Deleted';

  @override
  String get attachmentExportTitle => 'Export Attachments';

  @override
  String get attachmentExportSubtitle => 'Export all attachments as a compressed file';

  @override
  String get attachmentImportTitle => 'Import Attachments';

  @override
  String get attachmentImportSubtitle => 'Import attachments from a compressed file';

  @override
  String get attachmentExportEmpty => 'No attachments to export';

  @override
  String attachmentExportProgress(int current, int total) {
    return 'Exporting attachments ($current/$total)';
  }

  @override
  String attachmentExportProgressDetail(int attachmentCount, int iconCount, int current, int total) {
    return 'Exporting $attachmentCount attachment(s) + $iconCount icon(s) ($current/$total)';
  }

  @override
  String get attachmentExportSuccess => 'Attachments exported successfully';

  @override
  String attachmentExportSavedTo(String path) {
    return 'Saved to: $path';
  }

  @override
  String get attachmentImportConflictStrategy => 'Conflict Strategy';

  @override
  String get attachmentImportConflictSkip => 'Skip existing attachments';

  @override
  String get attachmentImportConflictOverwrite => 'Overwrite existing attachments';

  @override
  String attachmentImportProgress(int current, int total) {
    return 'Importing attachments ($current/$total)';
  }

  @override
  String attachmentImportResult(int imported, int skipped, int overwritten, int failed) {
    return 'Imported $imported, Skipped $skipped, Overwritten $overwritten, Failed $failed';
  }

  @override
  String get attachmentImportFailed => 'Failed to import attachments';

  @override
  String attachmentArchiveInfo(int count, String date) {
    return '$count attachments, exported on $date';
  }

  @override
  String get attachmentStartImport => 'Start Import';

  @override
  String get attachmentPreview => 'Preview Attachments';

  @override
  String attachmentPreviewSubtitle(int count) {
    return '$count images in total';
  }

  @override
  String get attachmentPreviewEmpty => 'No attachments';

  @override
  String get attachmentExportPreviewTitle => 'Export Preview';

  @override
  String get attachmentImportPreviewTitle => 'Import Preview';

  @override
  String get shortcutsGuide => 'Shortcuts';

  @override
  String get shortcutsGuideDesc => 'Quick access to voice, camera billing, etc.';

  @override
  String get shortcutsIntroTitle => 'Quick Billing';

  @override
  String get shortcutsIntroDesc => 'Use shortcuts to directly open voice billing, camera billing, and other features from your home screen without opening the app first.';

  @override
  String get availableShortcuts => 'Available Shortcuts';

  @override
  String get shortcutVoice => 'Voice Billing';

  @override
  String get shortcutVoiceDesc => 'Quickly record bills by voice';

  @override
  String get shortcutImage => 'Image Billing';

  @override
  String get shortcutImageDesc => 'Recognize bills from gallery images';

  @override
  String get shortcutCamera => 'Camera Billing';

  @override
  String get shortcutCameraDesc => 'Take photos to recognize bills';

  @override
  String get shortcutNewExpense => 'Quick Expense';

  @override
  String get shortcutNewExpenseDesc => 'Open expense entry page directly';

  @override
  String get shortcutNewIncome => 'Quick Income';

  @override
  String get shortcutNewIncomeDesc => 'Open income entry page directly';

  @override
  String get shortcutNewTransfer => 'Quick Transfer';

  @override
  String get shortcutNewTransferDesc => 'Open transfer entry page directly';

  @override
  String get shortcutUrlCopied => 'URL copied to clipboard';

  @override
  String get howToAddShortcut => 'How to Add Shortcuts';

  @override
  String get iosShortcutStep1 => 'Open the Shortcuts app';

  @override
  String get iosShortcutStep2 => 'Tap + in the upper right to create a new shortcut';

  @override
  String get iosShortcutStep3 => 'Add \'Open URL\' action';

  @override
  String get iosShortcutStep4 => 'Paste the copied URL (e.g., beecount://voice)';

  @override
  String get iosShortcutStep5 => 'Save and add to home screen';

  @override
  String get androidShortcutStep1 => 'Download a shortcut creator app (e.g., Shortcut Maker)';

  @override
  String get androidShortcutStep2 => 'Select \'URL Shortcut\'';

  @override
  String get androidShortcutStep3 => 'Paste the copied URL (e.g., beecount://voice)';

  @override
  String get androidShortcutStep4 => 'Set icon and name, then add to home screen';

  @override
  String get shortcutsTip => 'Tips';

  @override
  String get shortcutsTipDesc => 'Shortcuts require AI features. Make sure AI is enabled and API Key is configured.';

  @override
  String get shortcutOpenShortcutsApp => 'Open Shortcuts App';

  @override
  String get shortcutAutoAdd => 'Auto Billing API';

  @override
  String get shortcutAutoAddDesc => 'Automatically create bills via URL parameters. Works great with Shortcuts and automation tools.';

  @override
  String get shortcutAutoAddExample => 'Example URL:';

  @override
  String get shortcutAutoAddParams => 'Supported parameters:';

  @override
  String get shortcutParamAmount => 'Amount (required)';

  @override
  String get shortcutParamType => 'Type: expense / income / transfer';

  @override
  String get shortcutParamCategory => 'Category name (must match existing category)';

  @override
  String get shortcutParamNote => 'Note';

  @override
  String get shortcutParamAccount => 'Account name (must match existing account)';

  @override
  String get shortcutParamTags => 'Tags (comma separated)';

  @override
  String get shortcutParamDate => 'Date (ISO format, e.g., 2024-01-15)';

  @override
  String get quickActionImage => 'Photo Billing';

  @override
  String get quickActionCamera => 'Camera Billing';

  @override
  String get quickActionVoice => 'Voice Billing';

  @override
  String get quickActionAiChat => 'AI Assistant';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get calendarToday => 'Today';

  @override
  String get calendarNoTransactions => 'No transactions';

  @override
  String get commonUncategorized => 'Uncategorized';

  @override
  String get commonSaved => 'Saved';

  @override
  String get aiProviderManageTitle => 'Provider Management';

  @override
  String get aiProviderManageSubtitle => 'Manage AI service providers';

  @override
  String get aiProviderAdd => 'Add Provider';

  @override
  String get aiProviderBuiltIn => 'Built-in';

  @override
  String get aiProviderEmpty => 'No providers configured';

  @override
  String get aiProviderNoApiKey => 'API Key not configured';

  @override
  String get aiProviderTapToEdit => 'Tap to edit';

  @override
  String get aiProviderDeleteTitle => 'Delete Provider';

  @override
  String aiProviderDeleteConfirm(String name) {
    return 'Delete provider \"$name\"? Capabilities using this provider will switch to default.';
  }

  @override
  String get aiProviderDeleted => 'Provider deleted';

  @override
  String get aiProviderEditTitle => 'Edit Provider';

  @override
  String get aiProviderAddTitle => 'Add Provider';

  @override
  String get aiProviderBasicInfo => 'Basic Info';

  @override
  String get aiProviderName => 'Provider Name';

  @override
  String get aiProviderNameHint => 'e.g., SiliconFlow, DeepSeek';

  @override
  String get aiProviderNameRequired => 'Please enter provider name';

  @override
  String get aiProviderBaseUrlRequired => 'Please enter Base URL';

  @override
  String get aiProviderModels => 'Model Configuration';

  @override
  String get aiProviderModelsHint => 'Empty capabilities cannot use this provider';

  @override
  String get aiCapabilityText => 'Text';

  @override
  String get aiCapabilityVision => 'Vision';

  @override
  String get aiCapabilitySpeech => 'Speech';

  @override
  String get aiCapabilitySelectTitle => 'Capability Binding';

  @override
  String get aiCapabilitySelectSubtitle => 'Select provider for each AI capability';

  @override
  String get aiCapabilityTextChat => 'Text Chat';

  @override
  String get aiCapabilityTextChatDesc => 'For AI chat and text bill extraction';

  @override
  String get aiCapabilityImageUnderstand => 'Image Understanding';

  @override
  String get aiCapabilityImageUnderstandDesc => 'For image bill recognition';

  @override
  String get aiCapabilitySpeechToText => 'Speech to Text';

  @override
  String get aiCapabilitySpeechToTextDesc => 'For voice billing';

  @override
  String get aiProviderTestRun => 'Tap to test';

  @override
  String get aiProviderTestRunning => 'Testing...';

  @override
  String get aiProviderTestSuccess => 'Test passed';

  @override
  String get aiProviderTestFailed => 'Test failed';

  @override
  String get aiProviderTestAll => 'Test All';

  @override
  String get aiProviderTestAllRetry => 'Retry Test';

  @override
  String get aiModelInputHelper => 'Leave empty to use default model';

  @override
  String get syncPreviewTitle => 'Sync Preview';

  @override
  String get syncPreviewSelectAll => 'Select All';

  @override
  String get syncPreviewDeselectAll => 'Deselect All';

  @override
  String get syncPreviewAdded => 'Added';

  @override
  String get syncPreviewModified => 'Modified';

  @override
  String get syncPreviewDeleted => 'Deleted';

  @override
  String syncPreviewAddedCount(int count) {
    return '$count added';
  }

  @override
  String syncPreviewModifiedCount(int count) {
    return '$count modified';
  }

  @override
  String syncPreviewDeletedCount(int count) {
    return '$count deleted';
  }

  @override
  String syncPreviewApply(int count) {
    return 'Apply $count items';
  }

  @override
  String get syncPreviewEmpty => 'Cloud data matches local, no sync needed';

  @override
  String get syncPreviewOldFormat => 'Old cloud format, full replace required';

  @override
  String get syncPreviewOldFormatMessage => 'Cloud data does not contain sync IDs. Local data will be cleared and re-imported from cloud.';

  @override
  String syncPreviewApplied(int count) {
    return 'Applied $count changes';
  }

  @override
  String get cloudSyncGuideTitle => 'Cloud Sync Guide';

  @override
  String get cloudSyncGuideGotIt => 'Got it';

  @override
  String get cloudSyncGuideHowItWorks => 'How it works';

  @override
  String get cloudSyncGuideHowItem1 => 'Upload: packages all current ledger data and uploads to cloud, replacing old cloud data';

  @override
  String get cloudSyncGuideHowItem2 => 'Download: fetches cloud data and compares with local records one by one — you choose which changes to apply';

  @override
  String get cloudSyncGuideHowItem3 => 'The cloud always stores only the last uploaded snapshot, no version history';

  @override
  String get cloudSyncGuideCorrect => 'Correct usage';

  @override
  String get cloudSyncGuideCorrectItem1 => 'Edit on one device at a time, upload when done';

  @override
  String get cloudSyncGuideCorrectItem2 => 'Download on the new device before starting to edit';

  @override
  String get cloudSyncGuideCorrectItem3 => 'Review the preview carefully before applying changes';

  @override
  String get cloudSyncGuideCorrectItem4 => 'Follow the pattern: edit → upload → switch device → download → edit';

  @override
  String get cloudSyncGuideWrong => 'What to avoid';

  @override
  String get cloudSyncGuideWrongItem1 => 'Editing the same ledger on two devices simultaneously — the later upload overwrites the earlier one';

  @override
  String get cloudSyncGuideWrongItem2 => 'Downloading immediately after upload — cloud services may have seconds to minutes of sync delay, wait a moment';

  @override
  String get cloudSyncGuideWrongItem3 => 'Going long periods without syncing then downloading many changes at once — easy to miss important differences';

  @override
  String get cloudSyncGuideLimitations => 'Known limitations';

  @override
  String get cloudSyncGuideLimitItem1 => 'Not real-time: requires manually tapping upload and download';

  @override
  String get cloudSyncGuideLimitItem2 => 'No conflict merging: does not auto-merge edits from both sides — last upload wins';

  @override
  String get cloudSyncGuideLimitItem3 => 'Cloud service delay: uploaded files may take seconds to minutes before other devices can read them, depending on your cloud provider';

  @override
  String get cloudSyncGuideLimitItem4 => 'Excludes attachments: transaction image attachments are not synced — export separately via Data Management';

  @override
  String get mineMultiDeviceSyncTitle => 'Multi-device Sync';

  @override
  String get mineMultiDeviceSyncSubtitle => 'Auto-check cloud changes when entering page';

  @override
  String get appLockTitle => 'App Lock';

  @override
  String get appLockDesc => 'PIN & biometric to protect privacy';

  @override
  String get appLockEnable => 'Enable App Lock';

  @override
  String get appLockEnableDesc => 'Require authentication on launch and resume';

  @override
  String get appLockSetPin => 'Set PIN';

  @override
  String get appLockChangePin => 'Change PIN';

  @override
  String get appLockVerifyPin => 'Verify PIN';

  @override
  String get appLockVerifyCurrentPin => 'Enter current PIN';

  @override
  String get appLockSetNewPin => 'Set new PIN';

  @override
  String get appLockConfirmPin => 'Confirm PIN';

  @override
  String get appLockEnterPin => 'Enter PIN';

  @override
  String get appLockPinSetSuccess => 'PIN set successfully';

  @override
  String get appLockDisabled => 'App Lock disabled';

  @override
  String get appLockBiometric => 'Biometric Unlock';

  @override
  String get appLockBiometricDesc => 'Use Face ID or fingerprint to unlock';

  @override
  String get appLockBiometricReason => 'Verify identity to unlock Bee Accounting';

  @override
  String get appLockTimeout => 'Auto-lock Timeout';

  @override
  String get appLockTimeoutImmediate => 'Immediately';

  @override
  String get appLockTimeout1Min => 'After 1 minute';

  @override
  String get appLockTimeout5Min => 'After 5 minutes';

  @override
  String get appLockTimeout15Min => 'After 15 minutes';

  @override
  String get creditCardSettings => 'Credit Card Settings';

  @override
  String get creditLimit => 'Credit Limit';

  @override
  String get creditLimitHint => 'Enter credit limit';

  @override
  String get billingDay => 'Billing Day';

  @override
  String get paymentDueDay => 'Payment Due Day';

  @override
  String get creditUsed => 'Used';

  @override
  String get creditAvailable => 'Available';

  @override
  String get creditCardOwed => 'Owed';

  @override
  String dayOfMonth(int day) {
    return '${day}th of each month';
  }

  @override
  String get creditCardReminderTitle => 'Payment Reminder';

  @override
  String get creditCardReminderDesc => 'Remind before payment due date';

  @override
  String creditCardReminderDaysBefore(int days) {
    return '$days days before';
  }

  @override
  String get creditCardInitialBalanceHint => 'Current debt (negative number)';

  @override
  String get selectDay => 'Select Day';

  @override
  String get accountBankName => 'Bank';

  @override
  String get accountBankNameHint => 'e.g. ICBC';

  @override
  String get accountCardLastFour => 'Last 4 Digits';

  @override
  String get accountCardLastFourHint => 'e.g. 1234';

  @override
  String get accountNote => 'Note';

  @override
  String get accountNoteHint => 'Add a note';

  @override
  String get accountMetaInfo => 'Account Info';

  @override
  String get accountBalanceTrend => 'Balance Trend';

  @override
  String get accountCategoryBreakdown => 'Category Breakdown';

  @override
  String get accountCategoryExpense => 'Expense';

  @override
  String get accountCategoryIncome => 'Income';

  @override
  String get accountNoMoreData => 'No more data';

  @override
  String get totalAssets => 'Total Assets';

  @override
  String get totalLiabilities => 'Total Liabilities';

  @override
  String get assetAccounts => 'Asset Accounts';

  @override
  String get liabilityAccounts => 'Liability Accounts';

  @override
  String get assetComposition => 'Asset Composition';

  @override
  String get accountTypeInvestment => 'Investment';

  @override
  String get accountTypeLoan => 'Loan';

  @override
  String get accountTypeReceivable => 'Receivable';

  @override
  String get accountTypeRealEstate => 'Real Estate';

  @override
  String get accountTypeVehicle => 'Vehicle';

  @override
  String get accountTypeInsurance => 'Insurance';

  @override
  String get accountTypeSocialFund => 'Social Fund';

  @override
  String get valuationCurrentValue => 'Current Valuation';

  @override
  String get valuationCurrentDebt => 'Current Debt';

  @override
  String get valuationUpdateValue => 'Update Valuation';

  @override
  String get valuationUpdateDebt => 'Update Debt';

  @override
  String valuationLastUpdated(String date) {
    return 'Last updated: $date';
  }

  @override
  String get valuationAccountHint => 'Enter current valuation';

  @override
  String get valuationDebtHint => 'Enter current debt amount';

  @override
  String get accountGroupTradable => 'Daily Accounts';

  @override
  String get accountGroupValuation => 'Assets/Liabilities';

  @override
  String get adjustmentTransaction => 'Valuation Adjustment';

  @override
  String creditCardBillingInfo(int billingDay, int paymentDueDay) {
    return 'Bills on ${billingDay}th · Due on ${paymentDueDay}th';
  }

  @override
  String creditCardDaysUntilPayment(int days) {
    return '$days days until payment due';
  }

  @override
  String get creditCardPaymentDueToday => 'Payment due today';

  @override
  String get creditCardQuickRepay => 'Record Repayment';

  @override
  String get budgetManagement => 'Budget';

  @override
  String get budgetManagementDesc => 'Set monthly budget and control spending';

  @override
  String get budgetSetupHint => 'Set a budget to control monthly spending';

  @override
  String get budgetSetupAction => 'Set up';

  @override
  String get cloudCollabDevicesPageTitle => 'Device Sessions';

  @override
  String get cloudCollabDevicesPageSubtitle => 'Manage active devices';

  @override
  String get cloudCollabDevicesViewAllSessions => 'Show all sessions';

  @override
  String get cloudCollabDevicesViewModeHint => 'Default view shows deduped devices active in the last 30 days.';

  @override
  String get cloudCollabNoDevices => 'No active devices';

  @override
  String get cloudCollabUnknownDeviceName => 'Unknown Device';

  @override
  String get cloudCollabDeviceCurrentTag => 'Current Device';

  @override
  String get cloudCollabCurrentDeviceCannotRevoke => 'Current device cannot be revoked.';

  @override
  String cloudCollabDeviceAppVersion(String version) {
    return 'App: $version';
  }

  @override
  String cloudCollabDeviceOsVersion(String version) {
    return 'OS: $version';
  }

  @override
  String cloudCollabDeviceModel(String model) {
    return 'Model: $model';
  }

  @override
  String cloudCollabDeviceLastIp(String ip) {
    return 'IP: $ip';
  }

  @override
  String cloudCollabDeviceSessionCount(String count) {
    return 'Sessions: $count';
  }

  @override
  String cloudCollabDeviceLastSeen(String time) {
    return 'Last seen: $time';
  }

  @override
  String cloudCollabDeviceCreatedAt(String time) {
    return 'Created: $time';
  }

  @override
  String get cloudCollabDeviceRevokeTitle => 'Revoke Device';

  @override
  String cloudCollabDeviceRevokeMessage(String name, String id) {
    return 'Revoke device $name ($id)?';
  }

  @override
  String cloudCollabDeviceRevokeMultipleMessage(String name, String count) {
    return 'Revoke $count sessions for device $name?';
  }

  @override
  String get cloudCollabDeviceRevoked => 'Device revoked';

  @override
  String get cloudCollabUnavailableMessage => 'Cloud sync is unavailable.';

  @override
  String get cloudCollabScopeDeniedHint => 'Server has not enabled ALLOW_APP_RW_SCOPES, so device sessions are unavailable.';

  @override
  String get cloudCollabScopeDeniedAction => 'Set ALLOW_APP_RW_SCOPES=true in server .env, restart the service, then sign in again.';

  @override
  String get syncHealthTitle => 'Sync status';

  @override
  String syncHealthCheckFailed(String msg) {
    return 'Check failed: $msg';
  }

  @override
  String get syncHealthHasDiff => 'Diff detected; auto-synced';

  @override
  String get syncHealthInSync => 'Local matches cloud';

  @override
  String get syncHealthGroupCurrentLedger => 'Current ledger';

  @override
  String get syncHealthGroupAll => 'All ledgers';

  @override
  String get syncHealthRowTx => 'Transactions';

  @override
  String get syncHealthRowAttachment => 'Attachments';

  @override
  String get syncHealthRowCategoryIcon => 'Category icons';

  @override
  String get syncHealthRowBudget => 'Budgets';

  @override
  String get syncHealthRowAccount => 'Accounts';

  @override
  String get syncHealthRowCategory => 'Categories';

  @override
  String get syncHealthRowTag => 'Tags';

  @override
  String get syncHealthRowUnpushed => 'Pending pushes';

  @override
  String syncHealthValue(int local, int remote) {
    return 'Local $local · Cloud $remote';
  }

  @override
  String syncHealthValueRemoteMissing(int local) {
    return 'Local $local · Cloud —';
  }

  @override
  String get twofaChallengeTitle => 'Two-factor authentication';

  @override
  String get twofaMethodTotp => 'Code';

  @override
  String get twofaMethodRecovery => 'Recovery code';

  @override
  String get twofaTotpHint => 'Enter the 6-digit code from your authenticator app (Google Authenticator / 1Password / Authy / etc).';

  @override
  String get twofaRecoveryHint => 'Enter a recovery code saved when you enabled 2FA (e.g. abcd-efgh). Each code works once.';

  @override
  String get twofaTotpInputPlaceholder => '6-digit code';

  @override
  String get twofaRecoveryInputPlaceholder => 'Recovery code';

  @override
  String twofaCountdown(String time) {
    return 'Time remaining $time';
  }

  @override
  String get twofaVerifyButton => 'Verify';

  @override
  String get twofaStatusTitle => 'Two-factor authentication';

  @override
  String get twofaStatusEnabled => 'Enabled ✓';

  @override
  String get twofaStatusDisabled => 'Not enabled';

  @override
  String twofaStatusEnabledAt(String date) {
    return 'Enabled on $date';
  }

  @override
  String get twofaStatusManageHint => 'Manage from the Web app (enable / disable / regenerate recovery codes)';

  @override
  String get twofaStatusOpenWeb => 'Enable on the Web app →';

  @override
  String get sharedRoleOwner => 'Owner';

  @override
  String get sharedRoleEditor => 'Editor';

  @override
  String get sharedRoleViewer => 'Viewer';

  @override
  String get commonCopied => 'Copied';

  @override
  String get commonRemove => 'Remove';

  @override
  String get sharedJoinPageTitle => 'Join shared ledger';

  @override
  String get sharedJoinPageSubtitle => 'Enter an invite code or tap a shared link';

  @override
  String get sharedJoinEnterCode => 'Enter invite code';

  @override
  String get sharedJoinEnterCodeHint => '6 uppercase letters / digits. You can also tap a share link to skip this step.';

  @override
  String get sharedJoinPreviewButton => 'Verify code';

  @override
  String get sharedJoinAcceptButton => 'Join';

  @override
  String sharedJoinInvitedBy(String name) {
    return '$name invited you to join';
  }

  @override
  String sharedJoinRoleLine(String role) {
    return 'Role: $role';
  }

  @override
  String sharedJoinExpiresInMinutes(int n) {
    return 'Expires in $n min';
  }

  @override
  String sharedJoinExpiresInHours(int n) {
    return 'Expires in ${n}h';
  }

  @override
  String sharedJoinExpiresInDays(int n) {
    return 'Expires in ${n}d';
  }

  @override
  String sharedJoinSuccess(String name) {
    return 'Joined \"$name\"';
  }

  @override
  String get sharedJoinCodeFormatError => 'Invite code must be 6 letters/digits.';

  @override
  String get sharedJoinInvalidOrExpired => 'Invite code is invalid or expired. Ask the inviter for a new one.';

  @override
  String get sharedJoinAlreadyMember => 'You are already a member of this ledger.';

  @override
  String get sharedJoinMemberLimit => 'This ledger has reached its member limit. Ask the owner.';

  @override
  String get sharedInvitePageTitle => 'Invite new member';

  @override
  String get sharedInviteFormRole => 'Role';

  @override
  String get sharedInviteFormExpiry => 'Valid for';

  @override
  String sharedInviteExpiryHours(int n) {
    return '$n h';
  }

  @override
  String sharedInviteExpiryDays(int n) {
    return '$n day';
  }

  @override
  String get sharedInviteGenerate => 'Generate invite code';

  @override
  String get sharedInviteGenerateAnother => 'Generate another code';

  @override
  String get sharedInviteCopyCode => 'Copy code';

  @override
  String get sharedInviteCopyLink => 'Copy link';

  @override
  String get sharedInviteShareLink => 'Share link';

  @override
  String sharedInviteExpiresAt(String dt) {
    return 'Expires at $dt';
  }

  @override
  String get sharedInviteWarning => '⚠️ Don\'t post invite codes to public groups / social. Anyone with the code can join. Revoke and regenerate from Members if leaked.';

  @override
  String get sharedInviteInstruction => 'Send the code or short link to the other person. After they install BeeCount, they can tap the link or enter the code from \"Me → Join shared ledger\".';

  @override
  String sharedInviteShareText(String ledger, String code, String url) {
    return 'I\'m inviting you to BeeCount shared ledger \"$ledger\".\n\nCode: $code\nLink: $url\n\nTap the link, or open BeeCount → Me → Join shared ledger and enter this code.';
  }

  @override
  String get sharedMembersPageTitle => 'Members';

  @override
  String get sharedMembersYou => 'you';

  @override
  String get sharedMembersInviteCta => 'Invite new member';

  @override
  String get sharedMembersLeaveCta => 'Leave ledger';

  @override
  String get sharedMembersLeaveTitle => 'Leave ledger';

  @override
  String sharedMembersLeaveConfirm(String name) {
    return 'After leaving \"$name\" you won\'t be able to access its transactions. Continue?';
  }

  @override
  String get sharedMembersLeaveDone => 'Left the ledger';

  @override
  String get sharedMembersRemoveTitle => 'Remove member';

  @override
  String get sharedMembersRemoveCta => 'Remove this member';

  @override
  String sharedMembersRemoveConfirm(String name) {
    return 'Remove $name? They will immediately lose access to this ledger.';
  }

  @override
  String get sharedMembersRemoved => 'Member removed';

  @override
  String get sharedMembersTransferTitle => 'Transfer ownership';

  @override
  String get sharedMembersTransferTo => 'Transfer to this member';

  @override
  String sharedMembersTransferConfirm(String name) {
    return 'Transfer ownership to $name? You will become an editor and can no longer invite, rename, or delete the ledger.';
  }

  @override
  String get sharedMembersTransferConfirmCta => 'Transfer';

  @override
  String get sharedMembersTransferDone => 'Ownership transferred';

  @override
  String sharedTxRecordedBy(String name) {
    return 'recorded by $name';
  }

  @override
  String sharedTxCreatedBy(String name) {
    return 'Created by $name';
  }

  @override
  String sharedTxEditedBy(String name) {
    return 'Last edited by $name';
  }

  @override
  String sharedTxCreatedAndEditedBy(String name) {
    return 'Created and edited by $name';
  }

  @override
  String get sharedRequiresCloudSync => 'Please enable cloud sync first';

  @override
  String get sharedMembersStatsTitle => 'Member balances';

  @override
  String get sharedMembersStatsEmpty => 'No transactions yet';

  @override
  String get sharedMembersStatsLoading => 'Loading…';

  @override
  String get sharedMembersStatsIncome => 'Income';

  @override
  String get sharedMembersStatsExpense => 'Expense';

  @override
  String sharedMembersStatsTxCount(int count) {
    return '$count tx';
  }

  @override
  String get maintenanceOrphanCleanupTitle => 'Data Cleanup';

  @override
  String get maintenanceOrphanCleanupSubtitle => 'Detect and clean local orphan data';

  @override
  String get maintenanceOrphanRescan => 'Rescan';

  @override
  String get maintenanceOrphanEmpty => 'Local data is clean, no orphan data found';

  @override
  String get maintenanceOrphanGroupDb => 'Database orphans';

  @override
  String get maintenanceOrphanGroupFile => 'File orphans';

  @override
  String get maintenanceOrphanGroupSync => 'Sync state orphans';

  @override
  String maintenanceOrphanSummary(int count) {
    return 'Found $count issue(s)';
  }

  @override
  String maintenanceOrphanSummarySize(String size) {
    return 'Reclaimable space ~ $size';
  }

  @override
  String get maintenanceOrphanSelectAll => 'Select all';

  @override
  String get maintenanceOrphanDeselectAll => 'Deselect all';

  @override
  String get maintenanceOrphanDeleteOne => 'Delete this';

  @override
  String maintenanceOrphanSelectedHint(int count) {
    return '$count selected';
  }

  @override
  String get maintenanceOrphanCleanSelected => 'Clean selected';

  @override
  String get maintenanceOrphanConfirmTitle => 'Confirm cleanup';

  @override
  String maintenanceOrphanConfirmDeleteOne(String title) {
    return 'Delete \"$title\"? This cannot be undone.';
  }

  @override
  String maintenanceOrphanConfirmDeleteBatch(int count) {
    return 'Delete the $count selected item(s)? This cannot be undone.';
  }

  @override
  String maintenanceOrphanCleanSuccess(int count) {
    return 'Cleaned $count item(s)';
  }

  @override
  String maintenanceOrphanCleanPartial(int ok, int fail) {
    return 'Cleaned $ok item(s), $fail failed';
  }
}
