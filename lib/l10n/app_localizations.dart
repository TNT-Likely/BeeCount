import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'Bee Accounting'**
  String get appTitle;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Charts'**
  String get tabAnalytics;

  /// No description provided for @tabLedgers.
  ///
  /// In en, this message translates to:
  /// **'Ledgers'**
  String get tabLedgers;

  /// No description provided for @tabMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get tabMine;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonEmpty.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get commonEmpty;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get commonSuccess;

  /// No description provided for @commonFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get commonFailed;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get commonPrevious;

  /// No description provided for @commonFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get commonFinish;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Note...'**
  String get commonNoteHint;

  /// No description provided for @commonFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get commonFilter;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get commonSelectAll;

  /// No description provided for @commonSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// No description provided for @commonHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get commonHelp;

  /// No description provided for @commonAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get commonAbout;

  /// No description provided for @commonLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get commonLanguage;

  /// No description provided for @commonWeekdayMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get commonWeekdayMonday;

  /// No description provided for @commonWeekdayTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get commonWeekdayTuesday;

  /// No description provided for @commonWeekdayWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get commonWeekdayWednesday;

  /// No description provided for @commonWeekdayThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get commonWeekdayThursday;

  /// No description provided for @commonWeekdayFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get commonWeekdayFriday;

  /// No description provided for @commonWeekdaySaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get commonWeekdaySaturday;

  /// No description provided for @commonWeekdaySunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get commonWeekdaySunday;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Bee Accounting'**
  String get homeTitle;

  /// No description provided for @homeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get homeIncome;

  /// No description provided for @homeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get homeExpense;

  /// No description provided for @homeBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get homeBalance;

  /// No description provided for @homeTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get homeTotal;

  /// No description provided for @homeAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get homeAverage;

  /// No description provided for @homeDailyAvg.
  ///
  /// In en, this message translates to:
  /// **'Daily Avg'**
  String get homeDailyAvg;

  /// No description provided for @homeMonthlyAvg.
  ///
  /// In en, this message translates to:
  /// **'Monthly Avg'**
  String get homeMonthlyAvg;

  /// No description provided for @homeNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No records yet'**
  String get homeNoRecords;

  /// No description provided for @homeAddRecord.
  ///
  /// In en, this message translates to:
  /// **'Add record by tapping the plus button'**
  String get homeAddRecord;

  /// No description provided for @homeHideAmounts.
  ///
  /// In en, this message translates to:
  /// **'Hide amounts'**
  String get homeHideAmounts;

  /// No description provided for @homeShowAmounts.
  ///
  /// In en, this message translates to:
  /// **'Show amounts'**
  String get homeShowAmounts;

  /// No description provided for @homeSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get homeSelectDate;

  /// No description provided for @homeAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Bee Accounting'**
  String get homeAppTitle;

  /// No description provided for @homeSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get homeSearch;

  /// No description provided for @homeShowAmount.
  ///
  /// In en, this message translates to:
  /// **'Show amounts'**
  String get homeShowAmount;

  /// No description provided for @homeHideAmount.
  ///
  /// In en, this message translates to:
  /// **'Hide amounts'**
  String get homeHideAmount;

  /// No description provided for @homeYear.
  ///
  /// In en, this message translates to:
  /// **'{year}'**
  String homeYear(int year);

  /// No description provided for @homeMonth.
  ///
  /// In en, this message translates to:
  /// **'{month}M'**
  String homeMonth(String month);

  /// No description provided for @homeNoRecordsSubtext.
  ///
  /// In en, this message translates to:
  /// **'Tap the plus button at the bottom to add a record'**
  String get homeNoRecordsSubtext;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search notes, categories or amounts...'**
  String get searchHint;

  /// No description provided for @searchAmountRange.
  ///
  /// In en, this message translates to:
  /// **'Amount range filter'**
  String get searchAmountRange;

  /// No description provided for @searchMinAmount.
  ///
  /// In en, this message translates to:
  /// **'Min amount'**
  String get searchMinAmount;

  /// No description provided for @searchMaxAmount.
  ///
  /// In en, this message translates to:
  /// **'Max amount'**
  String get searchMaxAmount;

  /// No description provided for @searchTo.
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get searchTo;

  /// No description provided for @searchNoInput.
  ///
  /// In en, this message translates to:
  /// **'Enter keywords to start searching'**
  String get searchNoInput;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching results found'**
  String get searchNoResults;

  /// No description provided for @searchResultsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matching results found'**
  String get searchResultsEmpty;

  /// No description provided for @searchResultsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Try other keywords or adjust filter conditions'**
  String get searchResultsEmptyHint;

  /// No description provided for @analyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analyticsTitle;

  /// No description provided for @analyticsMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get analyticsMonth;

  /// No description provided for @analyticsYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get analyticsYear;

  /// No description provided for @analyticsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get analyticsAll;

  /// No description provided for @analyticsSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get analyticsSummary;

  /// No description provided for @analyticsCategoryRanking.
  ///
  /// In en, this message translates to:
  /// **'Category Ranking'**
  String get analyticsCategoryRanking;

  /// No description provided for @analyticsCurrentPeriod.
  ///
  /// In en, this message translates to:
  /// **'Current Period'**
  String get analyticsCurrentPeriod;

  /// No description provided for @analyticsNoDataSubtext.
  ///
  /// In en, this message translates to:
  /// **'Swipe left/right to toggle income/expense, or use the period switcher above'**
  String get analyticsNoDataSubtext;

  /// No description provided for @analyticsSwipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe left/right to change period'**
  String get analyticsSwipeHint;

  /// No description provided for @analyticsTipContent.
  ///
  /// In en, this message translates to:
  /// **'1) Swipe left/right at the top to switch \"Month/Year/All\"\\n2) Swipe left/right in chart area to switch periods\\n3) Tap month or year to quickly select'**
  String get analyticsTipContent;

  /// No description provided for @analyticsSwitchTo.
  ///
  /// In en, this message translates to:
  /// **'Switch to {type}'**
  String analyticsSwitchTo(String type);

  /// No description provided for @analyticsTipHeader.
  ///
  /// In en, this message translates to:
  /// **'Tip: Top capsule can switch Month/Year/All'**
  String get analyticsTipHeader;

  /// No description provided for @analyticsSwipeToSwitch.
  ///
  /// In en, this message translates to:
  /// **'Swipe to switch'**
  String get analyticsSwipeToSwitch;

  /// No description provided for @analyticsAllYears.
  ///
  /// In en, this message translates to:
  /// **'All Years'**
  String get analyticsAllYears;

  /// No description provided for @analyticsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get analyticsToday;

  /// No description provided for @splashAppName.
  ///
  /// In en, this message translates to:
  /// **'Bee Accounting'**
  String get splashAppName;

  /// No description provided for @splashSlogan.
  ///
  /// In en, this message translates to:
  /// **'Record Every Drop'**
  String get splashSlogan;

  /// No description provided for @splashSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Source Data Security'**
  String get splashSecurityTitle;

  /// No description provided for @splashSecurityFeature1.
  ///
  /// In en, this message translates to:
  /// **'• Local data storage, complete privacy control'**
  String get splashSecurityFeature1;

  /// No description provided for @splashSecurityFeature2.
  ///
  /// In en, this message translates to:
  /// **'• Open source code transparency, trustworthy security'**
  String get splashSecurityFeature2;

  /// No description provided for @splashSecurityFeature3.
  ///
  /// In en, this message translates to:
  /// **'• Optional cloud sync, consistent data across devices'**
  String get splashSecurityFeature3;

  /// No description provided for @splashInitializing.
  ///
  /// In en, this message translates to:
  /// **'Initializing data...'**
  String get splashInitializing;

  /// No description provided for @ledgersTitle.
  ///
  /// In en, this message translates to:
  /// **'Ledger Management'**
  String get ledgersTitle;

  /// No description provided for @ledgersNew.
  ///
  /// In en, this message translates to:
  /// **'New Ledger'**
  String get ledgersNew;

  /// No description provided for @ledgersClear.
  ///
  /// In en, this message translates to:
  /// **'Clear Current Ledger'**
  String get ledgersClear;

  /// No description provided for @ledgersClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear current ledger?'**
  String get ledgersClearConfirm;

  /// No description provided for @ledgersClearMessage.
  ///
  /// In en, this message translates to:
  /// **'All transaction records in this ledger will be deleted and cannot be recovered.'**
  String get ledgersClearMessage;

  /// No description provided for @ledgersEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Ledger'**
  String get ledgersEdit;

  /// No description provided for @ledgersDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Ledger'**
  String get ledgersDelete;

  /// No description provided for @ledgersDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete Ledger'**
  String get ledgersDeleteConfirm;

  /// No description provided for @ledgersDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this ledger and all its records? This action cannot be undone.\\nIf there is a backup in the cloud, it will also be deleted.'**
  String get ledgersDeleteMessage;

  /// No description provided for @ledgersDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get ledgersDeleted;

  /// No description provided for @ledgersDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete Failed'**
  String get ledgersDeleteFailed;

  /// No description provided for @ledgersRecordsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} records'**
  String ledgersRecordsDeleted(int count);

  /// No description provided for @ledgersName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get ledgersName;

  /// No description provided for @ledgersDefaultLedgerName.
  ///
  /// In en, this message translates to:
  /// **'Default Ledger'**
  String get ledgersDefaultLedgerName;

  /// No description provided for @ledgersDefaultAccountName.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get ledgersDefaultAccountName;

  /// No description provided for @ledgersCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get ledgersCurrency;

  /// No description provided for @ledgersSelectCurrency.
  ///
  /// In en, this message translates to:
  /// **'Select Currency'**
  String get ledgersSelectCurrency;

  /// No description provided for @ledgersSearchCurrency.
  ///
  /// In en, this message translates to:
  /// **'Search: Chinese or code'**
  String get ledgersSearchCurrency;

  /// No description provided for @ledgersCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get ledgersCreate;

  /// No description provided for @ledgersActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get ledgersActions;

  /// No description provided for @ledgersRecords.
  ///
  /// In en, this message translates to:
  /// **'Records: {count}'**
  String ledgersRecords(String count);

  /// No description provided for @ledgersBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance: {balance}'**
  String ledgersBalance(String balance);

  /// No description provided for @categoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Category Management'**
  String get categoryTitle;

  /// No description provided for @categoryNew.
  ///
  /// In en, this message translates to:
  /// **'New Category'**
  String get categoryNew;

  /// No description provided for @categoryExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense Categories'**
  String get categoryExpense;

  /// No description provided for @categoryIncome.
  ///
  /// In en, this message translates to:
  /// **'Income Categories'**
  String get categoryIncome;

  /// No description provided for @categoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No categories'**
  String get categoryEmpty;

  /// No description provided for @categoryDefault.
  ///
  /// In en, this message translates to:
  /// **'Default Category'**
  String get categoryDefault;

  /// No description provided for @categoryLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed: {error}'**
  String categoryLoadFailed(String error);

  /// No description provided for @iconPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Icon'**
  String get iconPickerTitle;

  /// No description provided for @iconCategoryFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get iconCategoryFood;

  /// No description provided for @iconCategoryTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get iconCategoryTransport;

  /// No description provided for @iconCategoryShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get iconCategoryShopping;

  /// No description provided for @iconCategoryEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get iconCategoryEntertainment;

  /// No description provided for @iconCategoryLife.
  ///
  /// In en, this message translates to:
  /// **'Life'**
  String get iconCategoryLife;

  /// No description provided for @iconCategoryHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get iconCategoryHealth;

  /// No description provided for @iconCategoryEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get iconCategoryEducation;

  /// No description provided for @iconCategoryWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get iconCategoryWork;

  /// No description provided for @iconCategoryFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get iconCategoryFinance;

  /// No description provided for @iconCategoryReward.
  ///
  /// In en, this message translates to:
  /// **'Reward'**
  String get iconCategoryReward;

  /// No description provided for @iconCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get iconCategoryOther;

  /// No description provided for @iconCategoryDining.
  ///
  /// In en, this message translates to:
  /// **'Dining'**
  String get iconCategoryDining;

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Bills'**
  String get importTitle;

  /// No description provided for @importSelectFile.
  ///
  /// In en, this message translates to:
  /// **'Please select a CSV/TSV file to import (default first row as header)'**
  String get importSelectFile;

  /// No description provided for @importChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose File'**
  String get importChooseFile;

  /// No description provided for @importNoFileSelected.
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get importNoFileSelected;

  /// No description provided for @importHint.
  ///
  /// In en, this message translates to:
  /// **'Tip: Please select a CSV/TSV file to start importing'**
  String get importHint;

  /// No description provided for @importReading.
  ///
  /// In en, this message translates to:
  /// **'Reading file…'**
  String get importReading;

  /// No description provided for @importPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get importPreparing;

  /// No description provided for @importColumnNumber.
  ///
  /// In en, this message translates to:
  /// **'Column {number}'**
  String importColumnNumber(Object number);

  /// No description provided for @importConfirmMapping.
  ///
  /// In en, this message translates to:
  /// **'Confirm Mapping'**
  String get importConfirmMapping;

  /// No description provided for @importCategoryMapping.
  ///
  /// In en, this message translates to:
  /// **'Category Mapping'**
  String get importCategoryMapping;

  /// No description provided for @importNoDataParsed.
  ///
  /// In en, this message translates to:
  /// **'No data parsed. Please return to previous page to check CSV content or separator.'**
  String get importNoDataParsed;

  /// No description provided for @importFieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get importFieldDate;

  /// No description provided for @importFieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get importFieldType;

  /// No description provided for @importFieldAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get importFieldAmount;

  /// No description provided for @importFieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get importFieldCategory;

  /// No description provided for @importFieldNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get importFieldNote;

  /// No description provided for @importPreview.
  ///
  /// In en, this message translates to:
  /// **'Data Preview'**
  String get importPreview;

  /// No description provided for @importPreviewLimit.
  ///
  /// In en, this message translates to:
  /// **'Showing first {shown} of {total} records'**
  String importPreviewLimit(Object shown, Object total);

  /// No description provided for @importCategoryNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Category not selected'**
  String get importCategoryNotSelected;

  /// No description provided for @importCategoryMappingDescription.
  ///
  /// In en, this message translates to:
  /// **'Please select corresponding local categories for each category name:'**
  String get importCategoryMappingDescription;

  /// No description provided for @importKeepOriginalName.
  ///
  /// In en, this message translates to:
  /// **'Keep original name'**
  String get importKeepOriginalName;

  /// No description provided for @importProgress.
  ///
  /// In en, this message translates to:
  /// **'Importing, success: {ok}, failed: {fail}'**
  String importProgress(Object fail, Object ok);

  /// No description provided for @importCancelImport.
  ///
  /// In en, this message translates to:
  /// **'Cancel Import'**
  String get importCancelImport;

  /// No description provided for @importCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Complete'**
  String get importCompleteTitle;

  /// No description provided for @importCompletedCount.
  ///
  /// In en, this message translates to:
  /// **'Successfully imported {count} records'**
  String importCompletedCount(Object count);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import Failed'**
  String get importFailed;

  /// No description provided for @importFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailedMessage(Object error);

  /// No description provided for @importSelectCategoryFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select category mapping first'**
  String get importSelectCategoryFirst;

  /// No description provided for @importNextStep.
  ///
  /// In en, this message translates to:
  /// **'Next Step'**
  String get importNextStep;

  /// No description provided for @importPreviousStep.
  ///
  /// In en, this message translates to:
  /// **'Previous Step'**
  String get importPreviousStep;

  /// No description provided for @importStartImport.
  ///
  /// In en, this message translates to:
  /// **'Start Import'**
  String get importStartImport;

  /// No description provided for @importAutoDetect.
  ///
  /// In en, this message translates to:
  /// **'Auto Detect'**
  String get importAutoDetect;

  /// No description provided for @importInProgress.
  ///
  /// In en, this message translates to:
  /// **'Import in Progress'**
  String get importInProgress;

  /// No description provided for @importProgressDetail.
  ///
  /// In en, this message translates to:
  /// **'Imported {done} / {total} records, success {ok}, failed {fail}'**
  String importProgressDetail(Object done, Object fail, Object ok, Object total);

  /// No description provided for @importBackgroundImport.
  ///
  /// In en, this message translates to:
  /// **'Background Import'**
  String get importBackgroundImport;

  /// No description provided for @importCancelled.
  ///
  /// In en, this message translates to:
  /// **'Import Cancelled'**
  String get importCancelled;

  /// No description provided for @importCompleted.
  ///
  /// In en, this message translates to:
  /// **'Import Completed{cancelled}, success {ok}, failed {fail}'**
  String importCompleted(Object cancelled, Object fail, Object ok);

  /// No description provided for @importFileOpenError.
  ///
  /// In en, this message translates to:
  /// **'Unable to open file picker: {error}'**
  String importFileOpenError(String error);

  /// No description provided for @mineTitle.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get mineTitle;

  /// No description provided for @mineSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get mineSettings;

  /// No description provided for @mineTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme Settings'**
  String get mineTheme;

  /// No description provided for @mineFont.
  ///
  /// In en, this message translates to:
  /// **'Font Settings'**
  String get mineFont;

  /// No description provided for @mineReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder Settings'**
  String get mineReminder;

  /// No description provided for @mineData.
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get mineData;

  /// No description provided for @mineImport.
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get mineImport;

  /// No description provided for @mineExport.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get mineExport;

  /// No description provided for @mineCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud Service'**
  String get mineCloud;

  /// No description provided for @mineAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get mineAbout;

  /// No description provided for @mineVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get mineVersion;

  /// No description provided for @mineUpdate.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get mineUpdate;

  /// No description provided for @mineLanguageSettings.
  ///
  /// In en, this message translates to:
  /// **'Language Settings'**
  String get mineLanguageSettings;

  /// No description provided for @mineLanguageSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch application language'**
  String get mineLanguageSettingsSubtitle;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language Settings'**
  String get languageTitle;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get languageSystemDefault;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Confirmation'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this record?'**
  String get deleteConfirmMessage;

  /// No description provided for @logCopied.
  ///
  /// In en, this message translates to:
  /// **'Log copied'**
  String get logCopied;

  /// No description provided for @waitingRestore.
  ///
  /// In en, this message translates to:
  /// **'Waiting for restore task to start...'**
  String get waitingRestore;

  /// No description provided for @restoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud Restore'**
  String get restoreTitle;

  /// No description provided for @copyLog.
  ///
  /// In en, this message translates to:
  /// **'Copy Log'**
  String get copyLog;

  /// No description provided for @restoreProgress.
  ///
  /// In en, this message translates to:
  /// **'Restoring ({current}/{total})'**
  String restoreProgress(Object current, Object total);

  /// No description provided for @restorePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get restorePreparing;

  /// No description provided for @restoreLedgerProgress.
  ///
  /// In en, this message translates to:
  /// **'Ledger: {ledger}  Records: {done}/{total}'**
  String restoreLedgerProgress(String ledger, int done, int total);

  /// No description provided for @mineSlogan.
  ///
  /// In en, this message translates to:
  /// **'Bee Accounting, Every Penny Counts'**
  String get mineSlogan;

  /// No description provided for @mineDaysCount.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get mineDaysCount;

  /// No description provided for @mineTotalRecords.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get mineTotalRecords;

  /// No description provided for @mineCurrentBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get mineCurrentBalance;

  /// No description provided for @mineCloudService.
  ///
  /// In en, this message translates to:
  /// **'Cloud Service'**
  String get mineCloudService;

  /// No description provided for @mineCloudServiceLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get mineCloudServiceLoading;

  /// No description provided for @mineCloudServiceError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String mineCloudServiceError(Object error);

  /// No description provided for @mineCloudServiceDefault.
  ///
  /// In en, this message translates to:
  /// **'Default Cloud (Enabled)'**
  String get mineCloudServiceDefault;

  /// No description provided for @mineCloudServiceOffline.
  ///
  /// In en, this message translates to:
  /// **'Default Mode (Offline)'**
  String get mineCloudServiceOffline;

  /// No description provided for @mineCloudServiceCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom Supabase'**
  String get mineCloudServiceCustom;

  /// No description provided for @mineFirstFullUpload.
  ///
  /// In en, this message translates to:
  /// **'First Full Upload'**
  String get mineFirstFullUpload;

  /// No description provided for @mineFirstFullUploadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload all local ledgers to current Supabase'**
  String get mineFirstFullUploadSubtitle;

  /// No description provided for @mineFirstFullUploadComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get mineFirstFullUploadComplete;

  /// No description provided for @mineFirstFullUploadMessage.
  ///
  /// In en, this message translates to:
  /// **'Current ledger uploaded. Switch to other ledgers to upload them.'**
  String get mineFirstFullUploadMessage;

  /// No description provided for @mineFirstFullUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get mineFirstFullUploadFailed;

  /// No description provided for @mineSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get mineSyncTitle;

  /// No description provided for @mineSyncNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get mineSyncNotLoggedIn;

  /// No description provided for @mineSyncNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Cloud not configured'**
  String get mineSyncNotConfigured;

  /// No description provided for @mineSyncNoRemote.
  ///
  /// In en, this message translates to:
  /// **'No cloud backup'**
  String get mineSyncNoRemote;

  /// No description provided for @mineSyncInSync.
  ///
  /// In en, this message translates to:
  /// **'Synced (local {count} records)'**
  String mineSyncInSync(Object count);

  /// No description provided for @mineSyncLocalNewer.
  ///
  /// In en, this message translates to:
  /// **'Local newer (local {count} records, upload recommended)'**
  String mineSyncLocalNewer(Object count);

  /// No description provided for @mineSyncCloudNewer.
  ///
  /// In en, this message translates to:
  /// **'Cloud newer (download recommended)'**
  String get mineSyncCloudNewer;

  /// No description provided for @mineSyncDifferent.
  ///
  /// In en, this message translates to:
  /// **'Local and cloud differ'**
  String get mineSyncDifferent;

  /// No description provided for @mineSyncError.
  ///
  /// In en, this message translates to:
  /// **'Failed to get status'**
  String get mineSyncError;

  /// No description provided for @mineSyncDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Status Details'**
  String get mineSyncDetailTitle;

  /// No description provided for @mineSyncLocalRecords.
  ///
  /// In en, this message translates to:
  /// **'Local records: {count}'**
  String mineSyncLocalRecords(Object count);

  /// No description provided for @mineSyncCloudRecords.
  ///
  /// In en, this message translates to:
  /// **'Cloud records: {count}'**
  String mineSyncCloudRecords(Object count);

  /// No description provided for @mineSyncCloudLatest.
  ///
  /// In en, this message translates to:
  /// **'Cloud latest record time: {time}'**
  String mineSyncCloudLatest(Object time);

  /// No description provided for @mineSyncLocalFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Local fingerprint: {fingerprint}'**
  String mineSyncLocalFingerprint(Object fingerprint);

  /// No description provided for @mineSyncCloudFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Cloud fingerprint: {fingerprint}'**
  String mineSyncCloudFingerprint(Object fingerprint);

  /// No description provided for @mineSyncMessage.
  ///
  /// In en, this message translates to:
  /// **'Message: {message}'**
  String mineSyncMessage(Object message);

  /// No description provided for @mineUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get mineUploadTitle;

  /// No description provided for @mineUploadNeedLogin.
  ///
  /// In en, this message translates to:
  /// **'Login required'**
  String get mineUploadNeedLogin;

  /// No description provided for @mineUploadInProgress.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get mineUploadInProgress;

  /// No description provided for @mineUploadRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing...'**
  String get mineUploadRefreshing;

  /// No description provided for @mineUploadSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get mineUploadSynced;

  /// No description provided for @mineUploadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get mineUploadSuccess;

  /// No description provided for @mineUploadSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Current ledger synced to cloud'**
  String get mineUploadSuccessMessage;

  /// No description provided for @mineDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get mineDownloadTitle;

  /// No description provided for @mineDownloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get mineDownloadComplete;

  /// No description provided for @mineDownloadResult.
  ///
  /// In en, this message translates to:
  /// **'New imports: {inserted}\nExisting skipped: {skipped}\nDuplicates cleaned: {deleted}'**
  String mineDownloadResult(Object deleted, Object inserted, Object skipped);

  /// No description provided for @mineLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login / Register'**
  String get mineLoginTitle;

  /// No description provided for @mineLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only needed for sync'**
  String get mineLoginSubtitle;

  /// No description provided for @mineLoggedInEmail.
  ///
  /// In en, this message translates to:
  /// **'Logged in'**
  String get mineLoggedInEmail;

  /// No description provided for @mineLogoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to logout'**
  String get mineLogoutSubtitle;

  /// No description provided for @mineLogoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get mineLogoutConfirmTitle;

  /// No description provided for @mineLogoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?\nYou won\'t be able to use cloud sync after logout.'**
  String get mineLogoutConfirmMessage;

  /// No description provided for @mineLogoutButton.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get mineLogoutButton;

  /// No description provided for @mineAutoSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto sync ledger'**
  String get mineAutoSyncTitle;

  /// No description provided for @mineAutoSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto upload to cloud after recording'**
  String get mineAutoSyncSubtitle;

  /// No description provided for @mineAutoSyncNeedLogin.
  ///
  /// In en, this message translates to:
  /// **'Login required to enable'**
  String get mineAutoSyncNeedLogin;

  /// No description provided for @mineImportProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Importing in background...'**
  String get mineImportProgressTitle;

  /// No description provided for @mineImportProgressSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Progress: {done}/{total}, Success {ok}, Failed {fail}'**
  String mineImportProgressSubtitle(Object done, Object fail, Object ok, Object total);

  /// No description provided for @mineImportCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Import complete'**
  String get mineImportCompleteTitle;

  /// No description provided for @mineImportCompleteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Success {ok}, Failed {fail}'**
  String mineImportCompleteSubtitle(Object fail, Object ok);

  /// No description provided for @mineCategoryManagement.
  ///
  /// In en, this message translates to:
  /// **'Category Management'**
  String get mineCategoryManagement;

  /// No description provided for @mineCategoryManagementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Edit custom categories'**
  String get mineCategoryManagementSubtitle;

  /// No description provided for @mineCategoryMigration.
  ///
  /// In en, this message translates to:
  /// **'Category Migration'**
  String get mineCategoryMigration;

  /// No description provided for @mineCategoryMigrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Migrate category data to other categories'**
  String get mineCategoryMigrationSubtitle;

  /// No description provided for @mineReminderSettings.
  ///
  /// In en, this message translates to:
  /// **'Reminder Settings'**
  String get mineReminderSettings;

  /// No description provided for @mineReminderSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set daily recording reminders'**
  String get mineReminderSettingsSubtitle;

  /// No description provided for @minePersonalize.
  ///
  /// In en, this message translates to:
  /// **'Personalization'**
  String get minePersonalize;

  /// No description provided for @mineDisplayScale.
  ///
  /// In en, this message translates to:
  /// **'Display Scale'**
  String get mineDisplayScale;

  /// No description provided for @mineDisplayScaleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust text and UI element sizes'**
  String get mineDisplayScaleSubtitle;

  /// No description provided for @mineAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get mineAboutTitle;

  /// No description provided for @mineAboutMessage.
  ///
  /// In en, this message translates to:
  /// **'App: Bee Accounting\nVersion: {version}\nSource: https://github.com/TNT-Likely/BeeCount\nLicense: See LICENSE in repository'**
  String mineAboutMessage(Object version);

  /// No description provided for @mineAboutOpenGitHub.
  ///
  /// In en, this message translates to:
  /// **'Open GitHub'**
  String get mineAboutOpenGitHub;

  /// No description provided for @mineCheckUpdate.
  ///
  /// In en, this message translates to:
  /// **'Check Update'**
  String get mineCheckUpdate;

  /// No description provided for @mineCheckUpdateInProgress.
  ///
  /// In en, this message translates to:
  /// **'Checking update...'**
  String get mineCheckUpdateInProgress;

  /// No description provided for @mineCheckUpdateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Checking for latest version'**
  String get mineCheckUpdateSubtitle;

  /// No description provided for @mineUpdateDownload.
  ///
  /// In en, this message translates to:
  /// **'Download Update'**
  String get mineUpdateDownload;

  /// No description provided for @mineRefreshStats.
  ///
  /// In en, this message translates to:
  /// **'Refresh Stats (Debug)'**
  String get mineRefreshStats;

  /// No description provided for @mineRefreshStatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Trigger global stats provider recalculation'**
  String get mineRefreshStatsSubtitle;

  /// No description provided for @mineRefreshSync.
  ///
  /// In en, this message translates to:
  /// **'Refresh Sync Status (Debug)'**
  String get mineRefreshSync;

  /// No description provided for @mineRefreshSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Trigger sync status provider refresh'**
  String get mineRefreshSyncSubtitle;

  /// No description provided for @categoryEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Category'**
  String get categoryEditTitle;

  /// No description provided for @categoryNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Category'**
  String get categoryNewTitle;

  /// No description provided for @categoryDetailTooltip.
  ///
  /// In en, this message translates to:
  /// **'Category Details'**
  String get categoryDetailTooltip;

  /// No description provided for @categoryMigrationTooltip.
  ///
  /// In en, this message translates to:
  /// **'Category Migration'**
  String get categoryMigrationTooltip;

  /// No description provided for @categoryMigrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Category Migration'**
  String get categoryMigrationTitle;

  /// No description provided for @categoryMigrationDescription.
  ///
  /// In en, this message translates to:
  /// **'Category Migration Instructions'**
  String get categoryMigrationDescription;

  /// No description provided for @categoryMigrationDescriptionContent.
  ///
  /// In en, this message translates to:
  /// **'• Migrate all transaction records from one category to another\n• After migration, all transaction data from the source category will be transferred to the target category\n• This operation cannot be undone, please choose carefully'**
  String get categoryMigrationDescriptionContent;

  /// No description provided for @categoryMigrationFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From Category'**
  String get categoryMigrationFromLabel;

  /// No description provided for @categoryMigrationFromHint.
  ///
  /// In en, this message translates to:
  /// **'Select category to migrate from'**
  String get categoryMigrationFromHint;

  /// No description provided for @categoryMigrationToLabel.
  ///
  /// In en, this message translates to:
  /// **'To Category'**
  String get categoryMigrationToLabel;

  /// No description provided for @categoryMigrationToHint.
  ///
  /// In en, this message translates to:
  /// **'Select target category'**
  String get categoryMigrationToHint;

  /// No description provided for @categoryMigrationToHintFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select source category first'**
  String get categoryMigrationToHintFirst;

  /// No description provided for @categoryMigrationStartButton.
  ///
  /// In en, this message translates to:
  /// **'Start Migration'**
  String get categoryMigrationStartButton;

  /// No description provided for @categoryMigrationTransactionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} records'**
  String categoryMigrationTransactionCount(int count);

  /// No description provided for @categoryMigrationCannotTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot Migrate'**
  String get categoryMigrationCannotTitle;

  /// No description provided for @categoryMigrationCannotMessage.
  ///
  /// In en, this message translates to:
  /// **'Selected categories cannot be migrated, please check category status.'**
  String get categoryMigrationCannotMessage;

  /// No description provided for @categoryExpenseType.
  ///
  /// In en, this message translates to:
  /// **'Expense Category'**
  String get categoryExpenseType;

  /// No description provided for @categoryIncomeType.
  ///
  /// In en, this message translates to:
  /// **'Income Category'**
  String get categoryIncomeType;

  /// No description provided for @categoryDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Default Category'**
  String get categoryDefaultTitle;

  /// No description provided for @categoryDefaultMessage.
  ///
  /// In en, this message translates to:
  /// **'Default categories cannot be modified, but you can view details and migrate data'**
  String get categoryDefaultMessage;

  /// No description provided for @categoryNameDining.
  ///
  /// In en, this message translates to:
  /// **'Dining'**
  String get categoryNameDining;

  /// No description provided for @categoryNameTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get categoryNameTransport;

  /// No description provided for @categoryNameShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get categoryNameShopping;

  /// No description provided for @categoryNameEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get categoryNameEntertainment;

  /// No description provided for @categoryNameHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get categoryNameHome;

  /// No description provided for @categoryNameFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get categoryNameFamily;

  /// No description provided for @categoryNameCommunication.
  ///
  /// In en, this message translates to:
  /// **'Communication'**
  String get categoryNameCommunication;

  /// No description provided for @categoryNameUtilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get categoryNameUtilities;

  /// No description provided for @categoryNameHousing.
  ///
  /// In en, this message translates to:
  /// **'Housing'**
  String get categoryNameHousing;

  /// No description provided for @categoryNameMedical.
  ///
  /// In en, this message translates to:
  /// **'Medical'**
  String get categoryNameMedical;

  /// No description provided for @categoryNameEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get categoryNameEducation;

  /// No description provided for @categoryNamePets.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get categoryNamePets;

  /// No description provided for @categoryNameSports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get categoryNameSports;

  /// No description provided for @categoryNameDigital.
  ///
  /// In en, this message translates to:
  /// **'Digital'**
  String get categoryNameDigital;

  /// No description provided for @categoryNameTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get categoryNameTravel;

  /// No description provided for @categoryNameAlcoholTobacco.
  ///
  /// In en, this message translates to:
  /// **'Alcohol & Tobacco'**
  String get categoryNameAlcoholTobacco;

  /// No description provided for @categoryNameBabyCare.
  ///
  /// In en, this message translates to:
  /// **'Baby Care'**
  String get categoryNameBabyCare;

  /// No description provided for @categoryNameBeauty.
  ///
  /// In en, this message translates to:
  /// **'Beauty'**
  String get categoryNameBeauty;

  /// No description provided for @categoryNameRepair.
  ///
  /// In en, this message translates to:
  /// **'Repair'**
  String get categoryNameRepair;

  /// No description provided for @categoryNameSocial.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get categoryNameSocial;

  /// No description provided for @categoryNameLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get categoryNameLearning;

  /// No description provided for @categoryNameCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get categoryNameCar;

  /// No description provided for @categoryNameTaxi.
  ///
  /// In en, this message translates to:
  /// **'Taxi'**
  String get categoryNameTaxi;

  /// No description provided for @categoryNameSubway.
  ///
  /// In en, this message translates to:
  /// **'Subway'**
  String get categoryNameSubway;

  /// No description provided for @categoryNameDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get categoryNameDelivery;

  /// No description provided for @categoryNameProperty.
  ///
  /// In en, this message translates to:
  /// **'Property'**
  String get categoryNameProperty;

  /// No description provided for @categoryNameParking.
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get categoryNameParking;

  /// No description provided for @categoryNameDonation.
  ///
  /// In en, this message translates to:
  /// **'Donation'**
  String get categoryNameDonation;

  /// No description provided for @categoryNameGift.
  ///
  /// In en, this message translates to:
  /// **'Gift'**
  String get categoryNameGift;

  /// No description provided for @categoryNameTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get categoryNameTax;

  /// No description provided for @categoryNameBeverage.
  ///
  /// In en, this message translates to:
  /// **'Beverage'**
  String get categoryNameBeverage;

  /// No description provided for @categoryNameClothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get categoryNameClothing;

  /// No description provided for @categoryNameSnacks.
  ///
  /// In en, this message translates to:
  /// **'Snacks'**
  String get categoryNameSnacks;

  /// No description provided for @categoryNameRedPacket.
  ///
  /// In en, this message translates to:
  /// **'Red Packet'**
  String get categoryNameRedPacket;

  /// No description provided for @categoryNameFruit.
  ///
  /// In en, this message translates to:
  /// **'Fruit'**
  String get categoryNameFruit;

  /// No description provided for @categoryNameGame.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get categoryNameGame;

  /// No description provided for @categoryNameBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get categoryNameBook;

  /// No description provided for @categoryNameLover.
  ///
  /// In en, this message translates to:
  /// **'Lover'**
  String get categoryNameLover;

  /// No description provided for @categoryNameDecoration.
  ///
  /// In en, this message translates to:
  /// **'Decoration'**
  String get categoryNameDecoration;

  /// No description provided for @categoryNameDailyGoods.
  ///
  /// In en, this message translates to:
  /// **'Daily Goods'**
  String get categoryNameDailyGoods;

  /// No description provided for @categoryNameLottery.
  ///
  /// In en, this message translates to:
  /// **'Lottery'**
  String get categoryNameLottery;

  /// No description provided for @categoryNameStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get categoryNameStock;

  /// No description provided for @categoryNameSocialSecurity.
  ///
  /// In en, this message translates to:
  /// **'Social Security'**
  String get categoryNameSocialSecurity;

  /// No description provided for @categoryNameExpress.
  ///
  /// In en, this message translates to:
  /// **'Express'**
  String get categoryNameExpress;

  /// No description provided for @categoryNameWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get categoryNameWork;

  /// No description provided for @categoryNameSalary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get categoryNameSalary;

  /// No description provided for @categoryNameInvestment.
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get categoryNameInvestment;

  /// No description provided for @categoryNameBonus.
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get categoryNameBonus;

  /// No description provided for @categoryNameReimbursement.
  ///
  /// In en, this message translates to:
  /// **'Reimbursement'**
  String get categoryNameReimbursement;

  /// No description provided for @categoryNamePartTime.
  ///
  /// In en, this message translates to:
  /// **'Part-time'**
  String get categoryNamePartTime;

  /// No description provided for @categoryNameInterest.
  ///
  /// In en, this message translates to:
  /// **'Interest'**
  String get categoryNameInterest;

  /// No description provided for @categoryNameRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get categoryNameRefund;

  /// No description provided for @categoryNameSecondHand.
  ///
  /// In en, this message translates to:
  /// **'Second-hand Sale'**
  String get categoryNameSecondHand;

  /// No description provided for @categoryNameSocialBenefit.
  ///
  /// In en, this message translates to:
  /// **'Social Benefit'**
  String get categoryNameSocialBenefit;

  /// No description provided for @categoryNameTaxRefund.
  ///
  /// In en, this message translates to:
  /// **'Tax Refund'**
  String get categoryNameTaxRefund;

  /// No description provided for @categoryNameProvidentFund.
  ///
  /// In en, this message translates to:
  /// **'Provident Fund'**
  String get categoryNameProvidentFund;

  /// No description provided for @categoryNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Category Name'**
  String get categoryNameLabel;

  /// No description provided for @categoryNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter category name'**
  String get categoryNameHint;

  /// No description provided for @categoryNameHintDefault.
  ///
  /// In en, this message translates to:
  /// **'Default category name cannot be modified'**
  String get categoryNameHintDefault;

  /// No description provided for @categoryNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter category name'**
  String get categoryNameRequired;

  /// No description provided for @categoryNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Category name cannot exceed 4 characters'**
  String get categoryNameTooLong;

  /// No description provided for @categoryIconLabel.
  ///
  /// In en, this message translates to:
  /// **'Category Icon'**
  String get categoryIconLabel;

  /// No description provided for @categoryIconDefaultMessage.
  ///
  /// In en, this message translates to:
  /// **'Default category icon cannot be modified'**
  String get categoryIconDefaultMessage;

  /// No description provided for @categoryDangerousOperations.
  ///
  /// In en, this message translates to:
  /// **'Dangerous Operations'**
  String get categoryDangerousOperations;

  /// No description provided for @categoryDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Category'**
  String get categoryDeleteTitle;

  /// No description provided for @categoryDeleteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot be recovered after deletion'**
  String get categoryDeleteSubtitle;

  /// No description provided for @categoryDefaultCannotSave.
  ///
  /// In en, this message translates to:
  /// **'Default category cannot be saved'**
  String get categoryDefaultCannotSave;

  /// No description provided for @categorySaveError.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get categorySaveError;

  /// No description provided for @categoryUpdated.
  ///
  /// In en, this message translates to:
  /// **'Category \"{name}\" updated'**
  String categoryUpdated(Object name);

  /// No description provided for @categoryCreated.
  ///
  /// In en, this message translates to:
  /// **'Category \"{name}\" created'**
  String categoryCreated(Object name);

  /// No description provided for @categoryCannotDelete.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete'**
  String get categoryCannotDelete;

  /// No description provided for @categoryCannotDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This category has {count} transaction records. Please handle them first.'**
  String categoryCannotDeleteMessage(Object count);

  /// No description provided for @categoryDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Category'**
  String get categoryDeleteConfirmTitle;

  /// No description provided for @categoryDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete category \"{name}\"? This action cannot be undone.'**
  String categoryDeleteConfirmMessage(Object name);

  /// No description provided for @categoryDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Delete failed'**
  String get categoryDeleteError;

  /// No description provided for @categoryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Category \"{name}\" deleted'**
  String categoryDeleted(Object name);

  /// No description provided for @personalizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Personalize'**
  String get personalizeTitle;

  /// No description provided for @personalizeCustomColor.
  ///
  /// In en, this message translates to:
  /// **'Choose custom color'**
  String get personalizeCustomColor;

  /// No description provided for @personalizeCustomTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get personalizeCustomTitle;

  /// No description provided for @personalizeHue.
  ///
  /// In en, this message translates to:
  /// **'Hue ({value}°)'**
  String personalizeHue(Object value);

  /// No description provided for @personalizeSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation ({value}%)'**
  String personalizeSaturation(Object value);

  /// No description provided for @personalizeBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness ({value}%)'**
  String personalizeBrightness(Object value);

  /// No description provided for @personalizeSelectColor.
  ///
  /// In en, this message translates to:
  /// **'Select this color'**
  String get personalizeSelectColor;

  /// No description provided for @fontSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Display Scale'**
  String get fontSettingsTitle;

  /// No description provided for @fontSettingsCurrentScale.
  ///
  /// In en, this message translates to:
  /// **'Current scale: x{scale}'**
  String fontSettingsCurrentScale(Object scale);

  /// No description provided for @fontSettingsPreview.
  ///
  /// In en, this message translates to:
  /// **'Live Preview'**
  String get fontSettingsPreview;

  /// No description provided for @fontSettingsPreviewText.
  ///
  /// In en, this message translates to:
  /// **'Spent 23.50 on lunch today, record it;\nRecorded for 45 days this month, 320 entries;\nPersistence is victory!'**
  String get fontSettingsPreviewText;

  /// No description provided for @fontSettingsCurrentLevel.
  ///
  /// In en, this message translates to:
  /// **'Current level: {level} (scale x{scale})'**
  String fontSettingsCurrentLevel(Object level, Object scale);

  /// No description provided for @fontSettingsQuickLevel.
  ///
  /// In en, this message translates to:
  /// **'Quick Levels'**
  String get fontSettingsQuickLevel;

  /// No description provided for @fontSettingsCustomAdjust.
  ///
  /// In en, this message translates to:
  /// **'Custom Adjustment'**
  String get fontSettingsCustomAdjust;

  /// No description provided for @fontSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Note: This setting ensures consistent display at 1.0x across all devices, with device differences auto-compensated; adjust values for personalized scaling on this consistent base.'**
  String get fontSettingsDescription;

  /// No description provided for @fontSettingsExtraSmall.
  ///
  /// In en, this message translates to:
  /// **'Extra Small'**
  String get fontSettingsExtraSmall;

  /// No description provided for @fontSettingsVerySmall.
  ///
  /// In en, this message translates to:
  /// **'Very Small'**
  String get fontSettingsVerySmall;

  /// No description provided for @fontSettingsSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get fontSettingsSmall;

  /// No description provided for @fontSettingsStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get fontSettingsStandard;

  /// No description provided for @fontSettingsLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get fontSettingsLarge;

  /// No description provided for @fontSettingsBig.
  ///
  /// In en, this message translates to:
  /// **'Big'**
  String get fontSettingsBig;

  /// No description provided for @fontSettingsVeryBig.
  ///
  /// In en, this message translates to:
  /// **'Very Big'**
  String get fontSettingsVeryBig;

  /// No description provided for @fontSettingsExtraBig.
  ///
  /// In en, this message translates to:
  /// **'Extra Big'**
  String get fontSettingsExtraBig;

  /// No description provided for @fontSettingsMoreStyles.
  ///
  /// In en, this message translates to:
  /// **'More Styles'**
  String get fontSettingsMoreStyles;

  /// No description provided for @fontSettingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Page Title'**
  String get fontSettingsPageTitle;

  /// No description provided for @fontSettingsBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Block Title'**
  String get fontSettingsBlockTitle;

  /// No description provided for @fontSettingsBodyExample.
  ///
  /// In en, this message translates to:
  /// **'Body Text'**
  String get fontSettingsBodyExample;

  /// No description provided for @fontSettingsLabelExample.
  ///
  /// In en, this message translates to:
  /// **'Label Text'**
  String get fontSettingsLabelExample;

  /// No description provided for @fontSettingsStrongNumber.
  ///
  /// In en, this message translates to:
  /// **'Strong Number'**
  String get fontSettingsStrongNumber;

  /// No description provided for @fontSettingsListTitle.
  ///
  /// In en, this message translates to:
  /// **'List Item Title'**
  String get fontSettingsListTitle;

  /// No description provided for @fontSettingsListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Helper Text'**
  String get fontSettingsListSubtitle;

  /// No description provided for @fontSettingsScreenInfo.
  ///
  /// In en, this message translates to:
  /// **'Screen Adaptation Info'**
  String get fontSettingsScreenInfo;

  /// No description provided for @fontSettingsScreenDensity.
  ///
  /// In en, this message translates to:
  /// **'Screen Density'**
  String get fontSettingsScreenDensity;

  /// No description provided for @fontSettingsScreenWidth.
  ///
  /// In en, this message translates to:
  /// **'Screen Width'**
  String get fontSettingsScreenWidth;

  /// No description provided for @fontSettingsDeviceScale.
  ///
  /// In en, this message translates to:
  /// **'Device Scale'**
  String get fontSettingsDeviceScale;

  /// No description provided for @fontSettingsUserScale.
  ///
  /// In en, this message translates to:
  /// **'User Scale'**
  String get fontSettingsUserScale;

  /// No description provided for @fontSettingsFinalScale.
  ///
  /// In en, this message translates to:
  /// **'Final Scale'**
  String get fontSettingsFinalScale;

  /// No description provided for @fontSettingsBaseDevice.
  ///
  /// In en, this message translates to:
  /// **'Base Device'**
  String get fontSettingsBaseDevice;

  /// No description provided for @fontSettingsRecommendedScale.
  ///
  /// In en, this message translates to:
  /// **'Recommended Scale'**
  String get fontSettingsRecommendedScale;

  /// No description provided for @fontSettingsYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get fontSettingsYes;

  /// No description provided for @fontSettingsNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get fontSettingsNo;

  /// No description provided for @fontSettingsScaleExample.
  ///
  /// In en, this message translates to:
  /// **'This box and spacing auto-scale based on device'**
  String get fontSettingsScaleExample;

  /// No description provided for @fontSettingsPreciseAdjust.
  ///
  /// In en, this message translates to:
  /// **'Precise Adjustment'**
  String get fontSettingsPreciseAdjust;

  /// No description provided for @fontSettingsResetTo1x.
  ///
  /// In en, this message translates to:
  /// **'Reset to 1.0x'**
  String get fontSettingsResetTo1x;

  /// No description provided for @fontSettingsAdaptBase.
  ///
  /// In en, this message translates to:
  /// **'Adapt to Base'**
  String get fontSettingsAdaptBase;

  /// No description provided for @reminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording Reminder'**
  String get reminderTitle;

  /// No description provided for @reminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set daily recording reminder time'**
  String get reminderSubtitle;

  /// No description provided for @reminderDailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Recording Reminder'**
  String get reminderDailyTitle;

  /// No description provided for @reminderDailySubtitle.
  ///
  /// In en, this message translates to:
  /// **'When enabled, will remind you to record at specified time'**
  String get reminderDailySubtitle;

  /// No description provided for @reminderTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder Time'**
  String get reminderTimeTitle;

  /// No description provided for @reminderTestNotification.
  ///
  /// In en, this message translates to:
  /// **'Send Test Notification'**
  String get reminderTestNotification;

  /// No description provided for @reminderTestSent.
  ///
  /// In en, this message translates to:
  /// **'Test notification sent'**
  String get reminderTestSent;

  /// No description provided for @reminderQuickTest.
  ///
  /// In en, this message translates to:
  /// **'Quick Test (15s later)'**
  String get reminderQuickTest;

  /// No description provided for @reminderQuickTestMessage.
  ///
  /// In en, this message translates to:
  /// **'Quick test set for 15 seconds later, keep app in background'**
  String get reminderQuickTestMessage;

  /// No description provided for @reminderFlutterTest.
  ///
  /// In en, this message translates to:
  /// **'🔧 Test Flutter Notification Click (Dev)'**
  String get reminderFlutterTest;

  /// No description provided for @reminderFlutterTestMessage.
  ///
  /// In en, this message translates to:
  /// **'Flutter test notification sent, tap to see if app opens'**
  String get reminderFlutterTestMessage;

  /// No description provided for @reminderAlarmTest.
  ///
  /// In en, this message translates to:
  /// **'🔧 Test AlarmManager Notification Click (Dev)'**
  String get reminderAlarmTest;

  /// No description provided for @reminderAlarmTestMessage.
  ///
  /// In en, this message translates to:
  /// **'AlarmManager test notification set (1s later), tap to see if app opens'**
  String get reminderAlarmTestMessage;

  /// No description provided for @reminderDirectTest.
  ///
  /// In en, this message translates to:
  /// **'🔧 Direct Test NotificationReceiver (Dev)'**
  String get reminderDirectTest;

  /// No description provided for @reminderDirectTestMessage.
  ///
  /// In en, this message translates to:
  /// **'Directly called NotificationReceiver to create notification, check if tap works'**
  String get reminderDirectTestMessage;

  /// No description provided for @reminderCheckStatus.
  ///
  /// In en, this message translates to:
  /// **'🔧 Check Notification Status (Dev)'**
  String get reminderCheckStatus;

  /// No description provided for @reminderNotificationStatus.
  ///
  /// In en, this message translates to:
  /// **'Notification Status'**
  String get reminderNotificationStatus;

  /// No description provided for @reminderPendingCount.
  ///
  /// In en, this message translates to:
  /// **'Pending notifications: {count}'**
  String reminderPendingCount(Object count);

  /// No description provided for @reminderNoPending.
  ///
  /// In en, this message translates to:
  /// **'No pending notifications'**
  String get reminderNoPending;

  /// No description provided for @reminderCheckBattery.
  ///
  /// In en, this message translates to:
  /// **'Check Battery Optimization Status'**
  String get reminderCheckBattery;

  /// No description provided for @reminderBatteryStatus.
  ///
  /// In en, this message translates to:
  /// **'Battery Optimization Status'**
  String get reminderBatteryStatus;

  /// No description provided for @reminderManufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer: {value}'**
  String reminderManufacturer(Object value);

  /// No description provided for @reminderModel.
  ///
  /// In en, this message translates to:
  /// **'Model: {value}'**
  String reminderModel(Object value);

  /// No description provided for @reminderAndroidVersion.
  ///
  /// In en, this message translates to:
  /// **'Android Version: {value}'**
  String reminderAndroidVersion(Object value);

  /// No description provided for @reminderBatteryIgnored.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization: Ignored ✅'**
  String get reminderBatteryIgnored;

  /// No description provided for @reminderBatteryNotIgnored.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization: Not ignored ⚠️'**
  String get reminderBatteryNotIgnored;

  /// No description provided for @reminderBatteryAdvice.
  ///
  /// In en, this message translates to:
  /// **'Recommend disabling battery optimization for proper notifications'**
  String get reminderBatteryAdvice;

  /// No description provided for @reminderGoToSettings.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings'**
  String get reminderGoToSettings;

  /// No description provided for @reminderCheckChannel.
  ///
  /// In en, this message translates to:
  /// **'Check Notification Channel Settings'**
  String get reminderCheckChannel;

  /// No description provided for @reminderChannelStatus.
  ///
  /// In en, this message translates to:
  /// **'Notification Channel Status'**
  String get reminderChannelStatus;

  /// No description provided for @reminderChannelEnabled.
  ///
  /// In en, this message translates to:
  /// **'Channel enabled: Yes ✅'**
  String get reminderChannelEnabled;

  /// No description provided for @reminderChannelDisabled.
  ///
  /// In en, this message translates to:
  /// **'Channel enabled: No ❌'**
  String get reminderChannelDisabled;

  /// No description provided for @reminderChannelImportance.
  ///
  /// In en, this message translates to:
  /// **'Importance: {value}'**
  String reminderChannelImportance(Object value);

  /// No description provided for @reminderChannelSoundOn.
  ///
  /// In en, this message translates to:
  /// **'Sound: On 🔊'**
  String get reminderChannelSoundOn;

  /// No description provided for @reminderChannelSoundOff.
  ///
  /// In en, this message translates to:
  /// **'Sound: Off 🔇'**
  String get reminderChannelSoundOff;

  /// No description provided for @reminderChannelVibrationOn.
  ///
  /// In en, this message translates to:
  /// **'Vibration: On 📳'**
  String get reminderChannelVibrationOn;

  /// No description provided for @reminderChannelVibrationOff.
  ///
  /// In en, this message translates to:
  /// **'Vibration: Off'**
  String get reminderChannelVibrationOff;

  /// No description provided for @reminderChannelDndBypass.
  ///
  /// In en, this message translates to:
  /// **'Do Not Disturb: Can bypass'**
  String get reminderChannelDndBypass;

  /// No description provided for @reminderChannelDndNoBypass.
  ///
  /// In en, this message translates to:
  /// **'Do Not Disturb: Cannot bypass'**
  String get reminderChannelDndNoBypass;

  /// No description provided for @reminderChannelAdvice.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Recommended settings:'**
  String get reminderChannelAdvice;

  /// No description provided for @reminderChannelAdviceImportance.
  ///
  /// In en, this message translates to:
  /// **'• Importance: Urgent or High'**
  String get reminderChannelAdviceImportance;

  /// No description provided for @reminderChannelAdviceSound.
  ///
  /// In en, this message translates to:
  /// **'• Enable sound and vibration'**
  String get reminderChannelAdviceSound;

  /// No description provided for @reminderChannelAdviceBanner.
  ///
  /// In en, this message translates to:
  /// **'• Allow banner notifications'**
  String get reminderChannelAdviceBanner;

  /// No description provided for @reminderChannelAdviceXiaomi.
  ///
  /// In en, this message translates to:
  /// **'• Xiaomi phones need individual channel setup'**
  String get reminderChannelAdviceXiaomi;

  /// No description provided for @reminderChannelGood.
  ///
  /// In en, this message translates to:
  /// **'✅ Notification channel well configured'**
  String get reminderChannelGood;

  /// No description provided for @reminderOpenAppSettings.
  ///
  /// In en, this message translates to:
  /// **'Open App Settings'**
  String get reminderOpenAppSettings;

  /// No description provided for @reminderAppSettingsMessage.
  ///
  /// In en, this message translates to:
  /// **'Please allow notifications and disable battery optimization in settings'**
  String get reminderAppSettingsMessage;

  /// No description provided for @reminderIOSTest.
  ///
  /// In en, this message translates to:
  /// **'🍎 iOS Notification Debug Test'**
  String get reminderIOSTest;

  /// No description provided for @reminderIOSTestTitle.
  ///
  /// In en, this message translates to:
  /// **'iOS Notification Test'**
  String get reminderIOSTestTitle;

  /// No description provided for @reminderIOSTestMessage.
  ///
  /// In en, this message translates to:
  /// **'Test notification sent.\n\n🍎 iOS Simulator limitations:\n• Notifications may not show in notification center\n• Banner alerts may not work\n• But Xcode console will show logs\n\n💡 Debug methods:\n• Check Xcode console output\n• Check Flutter log info\n• Use real device for full experience'**
  String get reminderIOSTestMessage;

  /// No description provided for @reminderDescription.
  ///
  /// In en, this message translates to:
  /// **'Tip: When recording reminder is enabled, the system will send notifications at the specified time daily to remind you to record income and expenses.'**
  String get reminderDescription;

  /// No description provided for @reminderIOSInstructions.
  ///
  /// In en, this message translates to:
  /// **'🍎 iOS notification settings:\n• Settings > Notifications > Bee Accounting\n• Enable \"Allow Notifications\"\n• Set notification style: Banner or Alert\n• Enable sound and vibration\n\n⚠️ iOS Simulator limitations:\n• Simulator notification features are limited\n• Recommend using real device\n• Check Xcode console for notification status\n\nIf testing in simulator, observe:\n• Xcode console log output\n• Flutter Debug Console info\n• In-app popups confirming notification sent'**
  String get reminderIOSInstructions;

  /// No description provided for @reminderAndroidInstructions.
  ///
  /// In en, this message translates to:
  /// **'If notifications don\'t work properly, check:\n• App is allowed to send notifications\n• Disable battery optimization/power saving for app\n• Allow app to run in background and auto-start\n• Android 12+ needs exact alarm permission\n\n📱 Xiaomi phone special settings:\n• Settings > App Management > Bee Accounting > Notification Management\n• Tap \"Recording Reminder\" channel\n• Set importance to \"Urgent\" or \"High\"\n• Enable \"Banner notifications\", \"Sound\", \"Vibration\"\n• Security Center > App Management > Permissions > Auto-start\n\n🔒 Lock background methods:\n• Find Bee Accounting in recent tasks\n• Pull down app card to show lock icon\n• Tap lock icon to prevent cleanup'**
  String get reminderAndroidInstructions;

  /// No description provided for @categoryDetailLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed'**
  String get categoryDetailLoadFailed;

  /// No description provided for @categoryDetailSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Category Summary'**
  String get categoryDetailSummaryTitle;

  /// No description provided for @categoryDetailTotalCount.
  ///
  /// In en, this message translates to:
  /// **'Total Count'**
  String get categoryDetailTotalCount;

  /// No description provided for @categoryDetailTotalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get categoryDetailTotalAmount;

  /// No description provided for @categoryDetailAverageAmount.
  ///
  /// In en, this message translates to:
  /// **'Average Amount'**
  String get categoryDetailAverageAmount;

  /// No description provided for @categoryDetailSortTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get categoryDetailSortTitle;

  /// No description provided for @categoryDetailSortTimeDesc.
  ///
  /// In en, this message translates to:
  /// **'Time ↓'**
  String get categoryDetailSortTimeDesc;

  /// No description provided for @categoryDetailSortTimeAsc.
  ///
  /// In en, this message translates to:
  /// **'Time ↑'**
  String get categoryDetailSortTimeAsc;

  /// No description provided for @categoryDetailSortAmountDesc.
  ///
  /// In en, this message translates to:
  /// **'Amount ↓'**
  String get categoryDetailSortAmountDesc;

  /// No description provided for @categoryDetailSortAmountAsc.
  ///
  /// In en, this message translates to:
  /// **'Amount ↑'**
  String get categoryDetailSortAmountAsc;

  /// No description provided for @categoryDetailNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions'**
  String get categoryDetailNoTransactions;

  /// No description provided for @categoryDetailNoTransactionsSubtext.
  ///
  /// In en, this message translates to:
  /// **'No transactions in this category yet'**
  String get categoryDetailNoTransactionsSubtext;

  /// No description provided for @categoryDetailDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed'**
  String get categoryDetailDeleteFailed;

  /// No description provided for @categoryMigrationConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Migration'**
  String get categoryMigrationConfirmTitle;

  /// No description provided for @categoryMigrationConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Migrate {count} transactions from \"{fromName}\" to \"{toName}\"?\n\nThis operation cannot be undone!'**
  String categoryMigrationConfirmMessage(Object count, Object fromName, Object toName);

  /// No description provided for @categoryMigrationConfirmOk.
  ///
  /// In en, this message translates to:
  /// **'Confirm Migration'**
  String get categoryMigrationConfirmOk;

  /// No description provided for @categoryMigrationCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Migration Complete'**
  String get categoryMigrationCompleteTitle;

  /// No description provided for @categoryMigrationCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Successfully migrated {count} transactions from \"{fromName}\" to \"{toName}\".'**
  String categoryMigrationCompleteMessage(Object count, Object fromName, Object toName);

  /// No description provided for @categoryMigrationFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Migration Failed'**
  String get categoryMigrationFailedTitle;

  /// No description provided for @categoryMigrationFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Migration error: {error}'**
  String categoryMigrationFailedMessage(Object error);

  /// No description provided for @categoryMigrationTransactionLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} records'**
  String categoryMigrationTransactionLabel(int count);

  /// No description provided for @categoryPickerExpenseTab.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get categoryPickerExpenseTab;

  /// No description provided for @categoryPickerIncomeTab.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get categoryPickerIncomeTab;

  /// No description provided for @categoryPickerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get categoryPickerCancel;

  /// No description provided for @categoryPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No categories'**
  String get categoryPickerEmpty;

  /// No description provided for @cloudBackupFound.
  ///
  /// In en, this message translates to:
  /// **'Cloud Backup Found'**
  String get cloudBackupFound;

  /// No description provided for @cloudBackupRestoreMessage.
  ///
  /// In en, this message translates to:
  /// **'Cloud and local ledgers are inconsistent. Restore from cloud?\n(Will enter restore progress page)'**
  String get cloudBackupRestoreMessage;

  /// No description provided for @cloudBackupRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore Failed'**
  String get cloudBackupRestoreFailed;

  /// No description provided for @mineCloudBackupRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud Backup Found'**
  String get mineCloudBackupRestoreTitle;

  /// No description provided for @mineAutoSyncRemoteDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto upload to cloud after recording'**
  String get mineAutoSyncRemoteDesc;

  /// No description provided for @mineAutoSyncLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Login required to enable'**
  String get mineAutoSyncLoginRequired;

  /// No description provided for @mineImportCompleteAllSuccess.
  ///
  /// In en, this message translates to:
  /// **'All Success'**
  String get mineImportCompleteAllSuccess;

  /// No description provided for @mineImportCompleteTitleShort.
  ///
  /// In en, this message translates to:
  /// **'Import Complete'**
  String get mineImportCompleteTitleShort;

  /// No description provided for @mineAboutAppName.
  ///
  /// In en, this message translates to:
  /// **'App: Bee Accounting'**
  String get mineAboutAppName;

  /// No description provided for @mineAboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version: {version}'**
  String mineAboutVersion(Object version);

  /// No description provided for @mineAboutRepo.
  ///
  /// In en, this message translates to:
  /// **'Source: https://github.com/TNT-Likely/BeeCount'**
  String get mineAboutRepo;

  /// No description provided for @mineAboutLicense.
  ///
  /// In en, this message translates to:
  /// **'License: See LICENSE in repository'**
  String get mineAboutLicense;

  /// No description provided for @mineCheckUpdateDetecting.
  ///
  /// In en, this message translates to:
  /// **'Checking update...'**
  String get mineCheckUpdateDetecting;

  /// No description provided for @mineCheckUpdateSubtitleDetecting.
  ///
  /// In en, this message translates to:
  /// **'Checking for latest version'**
  String get mineCheckUpdateSubtitleDetecting;

  /// No description provided for @mineUpdateDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Download Update'**
  String get mineUpdateDownloadTitle;

  /// No description provided for @mineDebugRefreshStats.
  ///
  /// In en, this message translates to:
  /// **'Refresh Stats (Debug)'**
  String get mineDebugRefreshStats;

  /// No description provided for @mineDebugRefreshStatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Trigger global stats provider recalculation'**
  String get mineDebugRefreshStatsSubtitle;

  /// No description provided for @mineDebugRefreshSync.
  ///
  /// In en, this message translates to:
  /// **'Refresh Sync Status (Debug)'**
  String get mineDebugRefreshSync;

  /// No description provided for @mineDebugRefreshSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Trigger sync status provider refresh'**
  String get mineDebugRefreshSyncSubtitle;

  /// No description provided for @cloudCurrentService.
  ///
  /// In en, this message translates to:
  /// **'Current Cloud Service'**
  String get cloudCurrentService;

  /// No description provided for @cloudConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get cloudConnected;

  /// No description provided for @cloudOfflineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline Mode'**
  String get cloudOfflineMode;

  /// No description provided for @cloudAvailableServices.
  ///
  /// In en, this message translates to:
  /// **'Available Cloud Services'**
  String get cloudAvailableServices;

  /// No description provided for @cloudReadCustomConfigFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to read custom configuration'**
  String get cloudReadCustomConfigFailed;

  /// No description provided for @cloudFirstUploadNotComplete.
  ///
  /// In en, this message translates to:
  /// **'First full upload not completed'**
  String get cloudFirstUploadNotComplete;

  /// No description provided for @cloudFirstUploadInstruction.
  ///
  /// In en, this message translates to:
  /// **'Login and manually execute \"Upload\" in \"Mine/Sync\" to complete initialization'**
  String get cloudFirstUploadInstruction;

  /// No description provided for @cloudNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get cloudNotConfigured;

  /// No description provided for @cloudNotTested.
  ///
  /// In en, this message translates to:
  /// **'Not tested'**
  String get cloudNotTested;

  /// No description provided for @cloudConnectionNormal.
  ///
  /// In en, this message translates to:
  /// **'Connection normal'**
  String get cloudConnectionNormal;

  /// No description provided for @cloudConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get cloudConnectionFailed;

  /// No description provided for @cloudAddCustomService.
  ///
  /// In en, this message translates to:
  /// **'Add custom cloud service'**
  String get cloudAddCustomService;

  /// No description provided for @cloudDefaultServiceName.
  ///
  /// In en, this message translates to:
  /// **'Default Cloud Service'**
  String get cloudDefaultServiceName;

  /// No description provided for @cloudUseYourSupabase.
  ///
  /// In en, this message translates to:
  /// **'Use your own Supabase'**
  String get cloudUseYourSupabase;

  /// No description provided for @cloudTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get cloudTest;

  /// No description provided for @cloudSwitchService.
  ///
  /// In en, this message translates to:
  /// **'Switch Cloud Service'**
  String get cloudSwitchService;

  /// No description provided for @cloudSwitchToBuiltinConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to switch to the default cloud service? This will log out the current session.'**
  String get cloudSwitchToBuiltinConfirm;

  /// No description provided for @cloudSwitchToCustomConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to switch to the custom cloud service? This will log out the current session.'**
  String get cloudSwitchToCustomConfirm;

  /// No description provided for @cloudSwitched.
  ///
  /// In en, this message translates to:
  /// **'Switched'**
  String get cloudSwitched;

  /// No description provided for @cloudSwitchedToBuiltin.
  ///
  /// In en, this message translates to:
  /// **'Switched to default cloud service and logged out'**
  String get cloudSwitchedToBuiltin;

  /// No description provided for @cloudSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Switch failed'**
  String get cloudSwitchFailed;

  /// No description provided for @cloudActivateFailed.
  ///
  /// In en, this message translates to:
  /// **'Activation failed'**
  String get cloudActivateFailed;

  /// No description provided for @cloudActivateFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Saved configuration is invalid'**
  String get cloudActivateFailedMessage;

  /// No description provided for @cloudActivated.
  ///
  /// In en, this message translates to:
  /// **'Activated'**
  String get cloudActivated;

  /// No description provided for @cloudActivatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Switched to custom cloud service and logged out, please log in again'**
  String get cloudActivatedMessage;

  /// No description provided for @cloudEditCustomService.
  ///
  /// In en, this message translates to:
  /// **'Edit custom cloud service'**
  String get cloudEditCustomService;

  /// No description provided for @cloudAddCustomServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Add custom cloud service'**
  String get cloudAddCustomServiceTitle;

  /// No description provided for @cloudSupabaseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Supabase URL'**
  String get cloudSupabaseUrlLabel;

  /// No description provided for @cloudSupabaseUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://xxx.supabase.co'**
  String get cloudSupabaseUrlHint;

  /// No description provided for @cloudAnonKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Anon Key'**
  String get cloudAnonKeyLabel;

  /// No description provided for @cloudAnonKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Note: Do not fill in service_role Key; Anon Key is publicly available.'**
  String get cloudAnonKeyHint;

  /// No description provided for @cloudInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Invalid input'**
  String get cloudInvalidInput;

  /// No description provided for @cloudValidationEmptyFields.
  ///
  /// In en, this message translates to:
  /// **'URL and Key cannot be empty'**
  String get cloudValidationEmptyFields;

  /// No description provided for @cloudValidationHttpsRequired.
  ///
  /// In en, this message translates to:
  /// **'URL must start with https://'**
  String get cloudValidationHttpsRequired;

  /// No description provided for @cloudValidationKeyTooShort.
  ///
  /// In en, this message translates to:
  /// **'Key length is too short, may be invalid'**
  String get cloudValidationKeyTooShort;

  /// No description provided for @cloudValidationServiceRoleKey.
  ///
  /// In en, this message translates to:
  /// **'service_role Key is not allowed'**
  String get cloudValidationServiceRoleKey;

  /// No description provided for @cloudConfigUpdated.
  ///
  /// In en, this message translates to:
  /// **'Configuration updated'**
  String get cloudConfigUpdated;

  /// No description provided for @cloudConfigSaved.
  ///
  /// In en, this message translates to:
  /// **'Configuration saved'**
  String get cloudConfigSaved;

  /// No description provided for @cloudTestComplete.
  ///
  /// In en, this message translates to:
  /// **'Test complete'**
  String get cloudTestComplete;

  /// No description provided for @cloudTestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection test successful!'**
  String get cloudTestSuccess;

  /// No description provided for @cloudTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection test failed, please check if the configuration is correct.'**
  String get cloudTestFailed;

  /// No description provided for @cloudTestError.
  ///
  /// In en, this message translates to:
  /// **'Test failed'**
  String get cloudTestError;

  /// No description provided for @cloudClearConfig.
  ///
  /// In en, this message translates to:
  /// **'Clear configuration'**
  String get cloudClearConfig;

  /// No description provided for @cloudClearConfigConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear the custom cloud service configuration? (Development environment only)'**
  String get cloudClearConfigConfirm;

  /// No description provided for @cloudConfigCleared.
  ///
  /// In en, this message translates to:
  /// **'Custom cloud service configuration cleared'**
  String get cloudConfigCleared;

  /// No description provided for @cloudClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Clear failed'**
  String get cloudClearFailed;

  /// No description provided for @cloudServiceDescription.
  ///
  /// In en, this message translates to:
  /// **'Built-in cloud service (free but may be unstable, recommend using your own or regular backup)'**
  String get cloudServiceDescription;

  /// No description provided for @cloudServiceDescriptionNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Current build does not have built-in cloud service configuration'**
  String get cloudServiceDescriptionNotConfigured;

  /// No description provided for @cloudServiceDescriptionCustom.
  ///
  /// In en, this message translates to:
  /// **'Server: {url}'**
  String cloudServiceDescriptionCustom(String url);

  /// No description provided for @authLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get authLogin;

  /// No description provided for @authSignup.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get authSignup;

  /// No description provided for @authRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get authRegister;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authPasswordRequirement.
  ///
  /// In en, this message translates to:
  /// **'Password (at least 6 characters, include letters and numbers)'**
  String get authPasswordRequirement;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get authConfirmPassword;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get authInvalidEmail;

  /// No description provided for @authPasswordRequirementShort.
  ///
  /// In en, this message translates to:
  /// **'Password must contain letters and numbers, at least 6 characters'**
  String get authPasswordRequirementShort;

  /// No description provided for @authPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authPasswordMismatch;

  /// No description provided for @authResendVerification.
  ///
  /// In en, this message translates to:
  /// **'Resend verification email'**
  String get authResendVerification;

  /// No description provided for @authSignupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Registration successful'**
  String get authSignupSuccess;

  /// No description provided for @authVerificationEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent, please go to your email to complete verification before logging in.'**
  String get authVerificationEmailSent;

  /// No description provided for @authBackToMinePage.
  ///
  /// In en, this message translates to:
  /// **'Back to My Page'**
  String get authBackToMinePage;

  /// No description provided for @authVerificationEmailResent.
  ///
  /// In en, this message translates to:
  /// **'Verification email resent.'**
  String get authVerificationEmailResent;

  /// No description provided for @authResendAction.
  ///
  /// In en, this message translates to:
  /// **'resend verification'**
  String get authResendAction;

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect.'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authErrorEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Email not verified, please complete verification in your email before logging in.'**
  String get authErrorEmailNotConfirmed;

  /// No description provided for @authErrorRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts, please try again later.'**
  String get authErrorRateLimit;

  /// No description provided for @authErrorNetworkIssue.
  ///
  /// In en, this message translates to:
  /// **'Network error, please check your connection and try again.'**
  String get authErrorNetworkIssue;

  /// No description provided for @authErrorLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed, please try again later.'**
  String get authErrorLoginFailed;

  /// No description provided for @authErrorEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Email address is invalid, please check for spelling errors.'**
  String get authErrorEmailInvalid;

  /// No description provided for @authErrorEmailExists.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered, please login directly or reset password.'**
  String get authErrorEmailExists;

  /// No description provided for @authErrorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password is too simple, please include letters and numbers, at least 6 characters.'**
  String get authErrorWeakPassword;

  /// No description provided for @authErrorSignupFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed, please try again later.'**
  String get authErrorSignupFailed;

  /// No description provided for @authErrorUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'Email not registered, cannot {action}.'**
  String authErrorUserNotFound(String action);

  /// No description provided for @authErrorEmailNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Email not verified, cannot {action}.'**
  String authErrorEmailNotVerified(String action);

  /// No description provided for @authErrorActionFailed.
  ///
  /// In en, this message translates to:
  /// **'{action} failed, please try again later.'**
  String authErrorActionFailed(String action);

  /// No description provided for @importSelectCsvFile.
  ///
  /// In en, this message translates to:
  /// **'Please select CSV/TSV file to import (first row as header by default)'**
  String get importSelectCsvFile;

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportTitle;

  /// No description provided for @exportDescription.
  ///
  /// In en, this message translates to:
  /// **'Click the button below to select save location and export current ledger to CSV file.'**
  String get exportDescription;

  /// No description provided for @exportButtonIOS.
  ///
  /// In en, this message translates to:
  /// **'Export and Share (iOS)'**
  String get exportButtonIOS;

  /// No description provided for @exportButtonAndroid.
  ///
  /// In en, this message translates to:
  /// **'Select Folder and Export'**
  String get exportButtonAndroid;

  /// No description provided for @exportSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to: {path}'**
  String exportSavedTo(String path);

  /// No description provided for @exportSelectFolder.
  ///
  /// In en, this message translates to:
  /// **'Select Export Folder'**
  String get exportSelectFolder;

  /// No description provided for @exportCsvHeaderType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get exportCsvHeaderType;

  /// No description provided for @exportCsvHeaderCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get exportCsvHeaderCategory;

  /// No description provided for @exportCsvHeaderAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get exportCsvHeaderAmount;

  /// No description provided for @exportCsvHeaderNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get exportCsvHeaderNote;

  /// No description provided for @exportCsvHeaderTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get exportCsvHeaderTime;

  /// No description provided for @exportShareText.
  ///
  /// In en, this message translates to:
  /// **'BeeCount Export File'**
  String get exportShareText;

  /// No description provided for @exportSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Successful'**
  String get exportSuccessTitle;

  /// No description provided for @exportSuccessMessageIOS.
  ///
  /// In en, this message translates to:
  /// **'Saved and available in share history:\n{path}'**
  String exportSuccessMessageIOS(String path);

  /// No description provided for @exportSuccessMessageAndroid.
  ///
  /// In en, this message translates to:
  /// **'Saved to:\n{path}'**
  String exportSuccessMessageAndroid(String path);

  /// No description provided for @exportFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Failed'**
  String get exportFailedTitle;

  /// No description provided for @exportTypeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get exportTypeIncome;

  /// No description provided for @exportTypeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get exportTypeExpense;

  /// No description provided for @exportTypeTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get exportTypeTransfer;

  /// No description provided for @personalizeThemeHoney.
  ///
  /// In en, this message translates to:
  /// **'Bee Yellow'**
  String get personalizeThemeHoney;

  /// No description provided for @personalizeThemeOrange.
  ///
  /// In en, this message translates to:
  /// **'Flame Orange'**
  String get personalizeThemeOrange;

  /// No description provided for @personalizeThemeGreen.
  ///
  /// In en, this message translates to:
  /// **'Emerald Green'**
  String get personalizeThemeGreen;

  /// No description provided for @personalizeThemePurple.
  ///
  /// In en, this message translates to:
  /// **'Purple Lotus'**
  String get personalizeThemePurple;

  /// No description provided for @personalizeThemePink.
  ///
  /// In en, this message translates to:
  /// **'Cherry Pink'**
  String get personalizeThemePink;

  /// No description provided for @personalizeThemeBlue.
  ///
  /// In en, this message translates to:
  /// **'Sky Blue'**
  String get personalizeThemeBlue;

  /// No description provided for @personalizeThemeMint.
  ///
  /// In en, this message translates to:
  /// **'Forest Moon'**
  String get personalizeThemeMint;

  /// No description provided for @personalizeThemeSand.
  ///
  /// In en, this message translates to:
  /// **'Sunset Dune'**
  String get personalizeThemeSand;

  /// No description provided for @personalizeThemeLavender.
  ///
  /// In en, this message translates to:
  /// **'Snow & Pine'**
  String get personalizeThemeLavender;

  /// No description provided for @personalizeThemeSky.
  ///
  /// In en, this message translates to:
  /// **'Misty Wonderland'**
  String get personalizeThemeSky;

  /// No description provided for @personalizeThemeWarmOrange.
  ///
  /// In en, this message translates to:
  /// **'Warm Orange'**
  String get personalizeThemeWarmOrange;

  /// No description provided for @personalizeThemeMintGreen.
  ///
  /// In en, this message translates to:
  /// **'Mint Green'**
  String get personalizeThemeMintGreen;

  /// No description provided for @personalizeThemeRoseGold.
  ///
  /// In en, this message translates to:
  /// **'Rose Gold'**
  String get personalizeThemeRoseGold;

  /// No description provided for @personalizeThemeDeepBlue.
  ///
  /// In en, this message translates to:
  /// **'Deep Blue'**
  String get personalizeThemeDeepBlue;

  /// No description provided for @personalizeThemeMapleRed.
  ///
  /// In en, this message translates to:
  /// **'Maple Red'**
  String get personalizeThemeMapleRed;

  /// No description provided for @personalizeThemeEmerald.
  ///
  /// In en, this message translates to:
  /// **'Emerald'**
  String get personalizeThemeEmerald;

  /// No description provided for @personalizeThemeLavenderPurple.
  ///
  /// In en, this message translates to:
  /// **'Lavender'**
  String get personalizeThemeLavenderPurple;

  /// No description provided for @personalizeThemeAmber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get personalizeThemeAmber;

  /// No description provided for @personalizeThemeRouge.
  ///
  /// In en, this message translates to:
  /// **'Rouge Red'**
  String get personalizeThemeRouge;

  /// No description provided for @personalizeThemeIndigo.
  ///
  /// In en, this message translates to:
  /// **'Indigo Blue'**
  String get personalizeThemeIndigo;

  /// No description provided for @personalizeThemeOlive.
  ///
  /// In en, this message translates to:
  /// **'Olive Green'**
  String get personalizeThemeOlive;

  /// No description provided for @personalizeThemeCoral.
  ///
  /// In en, this message translates to:
  /// **'Coral Pink'**
  String get personalizeThemeCoral;

  /// No description provided for @personalizeThemeDarkGreen.
  ///
  /// In en, this message translates to:
  /// **'Dark Green'**
  String get personalizeThemeDarkGreen;

  /// No description provided for @personalizeThemeViolet.
  ///
  /// In en, this message translates to:
  /// **'Violet'**
  String get personalizeThemeViolet;

  /// No description provided for @personalizeThemeSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset Orange'**
  String get personalizeThemeSunset;

  /// No description provided for @personalizeThemePeacock.
  ///
  /// In en, this message translates to:
  /// **'Peacock Blue'**
  String get personalizeThemePeacock;

  /// No description provided for @personalizeThemeLime.
  ///
  /// In en, this message translates to:
  /// **'Lime Green'**
  String get personalizeThemeLime;

  /// No description provided for @analyticsMonthlyAvg.
  ///
  /// In en, this message translates to:
  /// **'Monthly Avg'**
  String get analyticsMonthlyAvg;

  /// No description provided for @analyticsDailyAvg.
  ///
  /// In en, this message translates to:
  /// **'Daily Avg'**
  String get analyticsDailyAvg;

  /// No description provided for @analyticsOverallAvg.
  ///
  /// In en, this message translates to:
  /// **'Overall Avg'**
  String get analyticsOverallAvg;

  /// No description provided for @analyticsTotalIncome.
  ///
  /// In en, this message translates to:
  /// **'Total Income: '**
  String get analyticsTotalIncome;

  /// No description provided for @analyticsTotalExpense.
  ///
  /// In en, this message translates to:
  /// **'Total Expense: '**
  String get analyticsTotalExpense;

  /// No description provided for @analyticsBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance: '**
  String get analyticsBalance;

  /// No description provided for @analyticsAvgIncome.
  ///
  /// In en, this message translates to:
  /// **'{avgLabel} Income: '**
  String analyticsAvgIncome(String avgLabel);

  /// No description provided for @analyticsAvgExpense.
  ///
  /// In en, this message translates to:
  /// **'{avgLabel} Expense: '**
  String analyticsAvgExpense(String avgLabel);

  /// No description provided for @analyticsExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get analyticsExpense;

  /// No description provided for @analyticsIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get analyticsIncome;

  /// No description provided for @analyticsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total {type}: '**
  String analyticsTotal(String type);

  /// No description provided for @analyticsAverage.
  ///
  /// In en, this message translates to:
  /// **'{avgLabel}: '**
  String analyticsAverage(String avgLabel);

  /// No description provided for @updateCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Check Update'**
  String get updateCheckTitle;

  /// No description provided for @updateNewVersionFound.
  ///
  /// In en, this message translates to:
  /// **'New Version Found'**
  String get updateNewVersionFound;

  /// No description provided for @updateNewVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'New Version {version} Found'**
  String updateNewVersionTitle(String version);

  /// No description provided for @updateNoApkFound.
  ///
  /// In en, this message translates to:
  /// **'APK download link not found'**
  String get updateNoApkFound;

  /// No description provided for @updateAlreadyLatest.
  ///
  /// In en, this message translates to:
  /// **'Already latest version'**
  String get updateAlreadyLatest;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Update check failed'**
  String get updateCheckFailed;

  /// No description provided for @updatePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied'**
  String get updatePermissionDenied;

  /// No description provided for @updateUserCancelled.
  ///
  /// In en, this message translates to:
  /// **'User cancelled'**
  String get updateUserCancelled;

  /// No description provided for @updateDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Download Update'**
  String get updateDownloadTitle;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading: {percent}%'**
  String updateDownloading(String percent);

  /// No description provided for @updateDownloadBackgroundHint.
  ///
  /// In en, this message translates to:
  /// **'You can switch the app to background, download will continue'**
  String get updateDownloadBackgroundHint;

  /// No description provided for @updateCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get updateCancelButton;

  /// No description provided for @updateBackgroundDownload.
  ///
  /// In en, this message translates to:
  /// **'Background Download'**
  String get updateBackgroundDownload;

  /// No description provided for @updateLaterButton.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLaterButton;

  /// No description provided for @updateDownloadButton.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get updateDownloadButton;

  /// No description provided for @updateFoundCachedTitle.
  ///
  /// In en, this message translates to:
  /// **'Found Downloaded Version'**
  String get updateFoundCachedTitle;

  /// No description provided for @updateFoundCachedMessage.
  ///
  /// In en, this message translates to:
  /// **'Found a previously downloaded installer, install directly?\\n\\nClick \"OK\" to install immediately, click \"Cancel\" to close this dialog.\\n\\nFile path: {path}'**
  String updateFoundCachedMessage(String path);

  /// No description provided for @updateInstallingCachedApk.
  ///
  /// In en, this message translates to:
  /// **'Installing cached APK'**
  String get updateInstallingCachedApk;

  /// No description provided for @updateDownloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download Complete'**
  String get updateDownloadComplete;

  /// No description provided for @updateInstallStarted.
  ///
  /// In en, this message translates to:
  /// **'Download complete, installer started'**
  String get updateInstallStarted;

  /// No description provided for @updateInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Installation failed'**
  String get updateInstallFailed;

  /// No description provided for @updateDownloadCompleteManual.
  ///
  /// In en, this message translates to:
  /// **'Download complete, can install manually'**
  String get updateDownloadCompleteManual;

  /// No description provided for @updateDownloadCompleteException.
  ///
  /// In en, this message translates to:
  /// **'Download complete, please install manually (dialog exception)'**
  String get updateDownloadCompleteException;

  /// No description provided for @updateDownloadCompleteManualContext.
  ///
  /// In en, this message translates to:
  /// **'Download complete, please install manually'**
  String get updateDownloadCompleteManualContext;

  /// No description provided for @updateDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get updateDownloadFailed;

  /// No description provided for @updateInstallTitle.
  ///
  /// In en, this message translates to:
  /// **'Download Complete'**
  String get updateInstallTitle;

  /// No description provided for @updateInstallMessage.
  ///
  /// In en, this message translates to:
  /// **'APK file download complete, install immediately?\\n\\nNote: The app will temporarily go to background during installation, this is normal.'**
  String get updateInstallMessage;

  /// No description provided for @updateInstallNow.
  ///
  /// In en, this message translates to:
  /// **'Install Now'**
  String get updateInstallNow;

  /// No description provided for @updateInstallLater.
  ///
  /// In en, this message translates to:
  /// **'Install Later'**
  String get updateInstallLater;

  /// No description provided for @updateNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'BeeCount Update Download'**
  String get updateNotificationTitle;

  /// No description provided for @updateNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'Downloading new version...'**
  String get updateNotificationBody;

  /// No description provided for @updateNotificationComplete.
  ///
  /// In en, this message translates to:
  /// **'Download complete, tap to install'**
  String get updateNotificationComplete;

  /// No description provided for @updateNotificationPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Permission Denied'**
  String get updateNotificationPermissionTitle;

  /// No description provided for @updateNotificationPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Cannot get notification permission, download progress will not show in notification bar, but download function works normally.'**
  String get updateNotificationPermissionMessage;

  /// No description provided for @updateNotificationGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'If you need to enable notifications, follow these steps:'**
  String get updateNotificationGuideTitle;

  /// No description provided for @updateNotificationStep1.
  ///
  /// In en, this message translates to:
  /// **'Open system settings'**
  String get updateNotificationStep1;

  /// No description provided for @updateNotificationStep2.
  ///
  /// In en, this message translates to:
  /// **'Find \"App Management\" or \"App Settings\"'**
  String get updateNotificationStep2;

  /// No description provided for @updateNotificationStep3.
  ///
  /// In en, this message translates to:
  /// **'Find \"BeeCount\" app'**
  String get updateNotificationStep3;

  /// No description provided for @updateNotificationStep4.
  ///
  /// In en, this message translates to:
  /// **'Click \"Permission Management\" or \"Notification Management\"'**
  String get updateNotificationStep4;

  /// No description provided for @updateNotificationStep5.
  ///
  /// In en, this message translates to:
  /// **'Enable \"Notification Permission\"'**
  String get updateNotificationStep5;

  /// No description provided for @updateNotificationMiuiHint.
  ///
  /// In en, this message translates to:
  /// **'MIUI users: Xiaomi system has strict notification permission control, may need additional settings in Security Center'**
  String get updateNotificationMiuiHint;

  /// No description provided for @updateNotificationGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get updateNotificationGotIt;

  /// No description provided for @updateCheckFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Check Failed'**
  String get updateCheckFailedTitle;

  /// No description provided for @updateDownloadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Download Failed'**
  String get updateDownloadFailedTitle;

  /// No description provided for @updateGoToGitHub.
  ///
  /// In en, this message translates to:
  /// **'Go to GitHub'**
  String get updateGoToGitHub;

  /// No description provided for @updateCannotOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Cannot open link'**
  String get updateCannotOpenLink;

  /// No description provided for @updateManualVisit.
  ///
  /// In en, this message translates to:
  /// **'Please manually visit in browser:\\nhttps://github.com/TNT-Likely/BeeCount/releases'**
  String get updateManualVisit;

  /// No description provided for @updateNoLocalApkTitle.
  ///
  /// In en, this message translates to:
  /// **'No Update Package Found'**
  String get updateNoLocalApkTitle;

  /// No description provided for @updateNoLocalApkMessage.
  ///
  /// In en, this message translates to:
  /// **'No downloaded update package file found.\\n\\nPlease first download new version through \"Check Update\".'**
  String get updateNoLocalApkMessage;

  /// No description provided for @updateInstallPackageTitle.
  ///
  /// In en, this message translates to:
  /// **'Install Update Package'**
  String get updateInstallPackageTitle;

  /// No description provided for @updateMultiplePackagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Found Multiple Update Packages'**
  String get updateMultiplePackagesTitle;

  /// No description provided for @updateMultiplePackagesMessage.
  ///
  /// In en, this message translates to:
  /// **'Found {count} update package files.\\n\\nRecommend using the latest downloaded version, or manually install in file manager.\\n\\nFile location: {path}'**
  String updateMultiplePackagesMessage(int count, String path);

  /// No description provided for @updateSearchFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Search Failed'**
  String get updateSearchFailedTitle;

  /// No description provided for @updateSearchFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Error occurred while searching for local update packages: {error}'**
  String updateSearchFailedMessage(String error);

  /// No description provided for @updateFoundCachedPackageTitle.
  ///
  /// In en, this message translates to:
  /// **'Found Downloaded Update Package'**
  String get updateFoundCachedPackageTitle;

  /// No description provided for @updateFoundCachedPackageMessage.
  ///
  /// In en, this message translates to:
  /// **'Detected previously downloaded update package:\\n\\nFile name: {fileName}\\nSize: {fileSize}MB\\n\\nInstall immediately?'**
  String updateFoundCachedPackageMessage(String fileName, String fileSize);

  /// No description provided for @updateIgnoreButton.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get updateIgnoreButton;

  /// No description provided for @updateInstallFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Installation Failed'**
  String get updateInstallFailedTitle;

  /// No description provided for @updateInstallFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Cannot start APK installer, please check file permissions.'**
  String get updateInstallFailedMessage;

  /// No description provided for @updateErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get updateErrorTitle;

  /// No description provided for @updateReadCacheFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to read cached update package: {error}'**
  String updateReadCacheFailedMessage(String error);

  /// No description provided for @updateCheckingPermissions.
  ///
  /// In en, this message translates to:
  /// **'Checking permissions...'**
  String get updateCheckingPermissions;

  /// No description provided for @updateCheckingCache.
  ///
  /// In en, this message translates to:
  /// **'Checking local cache...'**
  String get updateCheckingCache;

  /// No description provided for @updatePreparingDownload.
  ///
  /// In en, this message translates to:
  /// **'Preparing download...'**
  String get updatePreparingDownload;

  /// No description provided for @updateUserCancelledDownload.
  ///
  /// In en, this message translates to:
  /// **'User cancelled download'**
  String get updateUserCancelledDownload;

  /// No description provided for @updateStartingInstaller.
  ///
  /// In en, this message translates to:
  /// **'Starting installer...'**
  String get updateStartingInstaller;

  /// No description provided for @updateInstallerStarted.
  ///
  /// In en, this message translates to:
  /// **'Installer started'**
  String get updateInstallerStarted;

  /// No description provided for @updateInstallationFailed.
  ///
  /// In en, this message translates to:
  /// **'Installation failed'**
  String get updateInstallationFailed;

  /// No description provided for @updateDownloadCompleted.
  ///
  /// In en, this message translates to:
  /// **'Download completed'**
  String get updateDownloadCompleted;

  /// No description provided for @updateDownloadCompletedManual.
  ///
  /// In en, this message translates to:
  /// **'Download completed, can install manually'**
  String get updateDownloadCompletedManual;

  /// No description provided for @updateDownloadCompletedDialog.
  ///
  /// In en, this message translates to:
  /// **'Download completed, please install manually (dialog exception)'**
  String get updateDownloadCompletedDialog;

  /// No description provided for @updateDownloadCompletedContext.
  ///
  /// In en, this message translates to:
  /// **'Download completed, please install manually'**
  String get updateDownloadCompletedContext;

  /// No description provided for @updateDownloadFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get updateDownloadFailedGeneric;

  /// No description provided for @updateCheckingUpdate.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates...'**
  String get updateCheckingUpdate;

  /// No description provided for @updateCurrentLatestVersion.
  ///
  /// In en, this message translates to:
  /// **'Already latest version'**
  String get updateCurrentLatestVersion;

  /// No description provided for @updateCheckFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Update check failed'**
  String get updateCheckFailedGeneric;

  /// No description provided for @updateDownloadProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloading: {percent}%'**
  String updateDownloadProgress(String percent);

  /// No description provided for @updateNoApkFoundError.
  ///
  /// In en, this message translates to:
  /// **'APK download link not found'**
  String get updateNoApkFoundError;

  /// No description provided for @updateCheckingUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Update check failed: {error}'**
  String updateCheckingUpdateError(String error);

  /// No description provided for @updateNotificationChannelName.
  ///
  /// In en, this message translates to:
  /// **'Update Download'**
  String get updateNotificationChannelName;

  /// No description provided for @updateNotificationDownloadingIndeterminate.
  ///
  /// In en, this message translates to:
  /// **'Downloading new version...'**
  String get updateNotificationDownloadingIndeterminate;

  /// No description provided for @updateNotificationDownloadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Download progress: {progress}%'**
  String updateNotificationDownloadingProgress(String progress);

  /// No description provided for @updateNotificationDownloadCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Download Complete'**
  String get updateNotificationDownloadCompleteTitle;

  /// No description provided for @updateNotificationDownloadCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'New version downloaded, tap to install'**
  String get updateNotificationDownloadCompleteMessage;

  /// No description provided for @updateUserCancelledDownloadDialog.
  ///
  /// In en, this message translates to:
  /// **'User cancelled download'**
  String get updateUserCancelledDownloadDialog;

  /// No description provided for @updateCannotOpenLinkError.
  ///
  /// In en, this message translates to:
  /// **'Cannot open link'**
  String get updateCannotOpenLinkError;

  /// No description provided for @updateNoLocalApkFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'No downloaded update package file found.\\n\\nPlease first download new version through \"Check Update\".'**
  String get updateNoLocalApkFoundMessage;

  /// No description provided for @updateInstallPackageFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'Found update package:\\n\\nFile name: {fileName}\\nSize: {fileSize}MB\\nDownload time: {time}\\n\\nInstall immediately?'**
  String updateInstallPackageFoundMessage(String fileName, String fileSize, String time);

  /// No description provided for @updateMultiplePackagesFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'Found {count} update package files.\\n\\nRecommend using the latest downloaded version, or manually install in file manager.\\n\\nFile location: {path}'**
  String updateMultiplePackagesFoundMessage(int count, String path);

  /// No description provided for @updateSearchLocalApkError.
  ///
  /// In en, this message translates to:
  /// **'Error occurred while searching for local update packages: {error}'**
  String updateSearchLocalApkError(String error);

  /// No description provided for @updateCachedPackageFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'Detected previously downloaded update package:\\n\\nFile name: {fileName}\\nSize: {fileSize}MB\\n\\nInstall immediately?'**
  String updateCachedPackageFoundMessage(String fileName, String fileSize);

  /// No description provided for @updateReadCachedPackageError.
  ///
  /// In en, this message translates to:
  /// **'Failed to read cached update package: {error}'**
  String updateReadCachedPackageError(String error);

  /// No description provided for @reminderQuickTestSent.
  ///
  /// In en, this message translates to:
  /// **'Quick test set for 15 seconds later, please keep app in background'**
  String get reminderQuickTestSent;

  /// No description provided for @reminderFlutterTestSent.
  ///
  /// In en, this message translates to:
  /// **'Flutter test notification sent, click to see if it opens the app'**
  String get reminderFlutterTestSent;

  /// No description provided for @reminderAlarmTestSent.
  ///
  /// In en, this message translates to:
  /// **'AlarmManager test notification set (1 second later), click to see if it opens the app'**
  String get reminderAlarmTestSent;

  /// No description provided for @updateOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get updateOk;

  /// No description provided for @updateCannotOpenLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot Open Link'**
  String get updateCannotOpenLinkTitle;

  /// No description provided for @updateCachedVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'Found Downloaded Version'**
  String get updateCachedVersionTitle;

  /// No description provided for @updateCachedVersionMessage.
  ///
  /// In en, this message translates to:
  /// **'Found previously downloaded installation package... Click \\\"OK\\\" to install immediately, click \\\"Cancel\\\" to close...'**
  String get updateCachedVersionMessage;

  /// No description provided for @updateConfirmDownload.
  ///
  /// In en, this message translates to:
  /// **'Download and Install Now'**
  String get updateConfirmDownload;

  /// No description provided for @updateDownloadCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Download Complete'**
  String get updateDownloadCompleteTitle;

  /// No description provided for @updateInstallConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'New version has been downloaded. Install now?'**
  String get updateInstallConfirmMessage;

  /// No description provided for @updateNotificationPermissionGuideText.
  ///
  /// In en, this message translates to:
  /// **'Download progress notifications are disabled, but this doesn\'t affect download functionality. To view progress:'**
  String get updateNotificationPermissionGuideText;

  /// No description provided for @updateNotificationGuideStep1.
  ///
  /// In en, this message translates to:
  /// **'Go to System Settings > App Management'**
  String get updateNotificationGuideStep1;

  /// No description provided for @updateNotificationGuideStep2.
  ///
  /// In en, this message translates to:
  /// **'Find \\\"BeeCount\\\" app'**
  String get updateNotificationGuideStep2;

  /// No description provided for @updateNotificationGuideStep3.
  ///
  /// In en, this message translates to:
  /// **'Enable notification permissions'**
  String get updateNotificationGuideStep3;

  /// No description provided for @updateNotificationGuideInfo.
  ///
  /// In en, this message translates to:
  /// **'Downloads will continue normally in the background even without notifications'**
  String get updateNotificationGuideInfo;

  /// No description provided for @currencyCNY.
  ///
  /// In en, this message translates to:
  /// **'Chinese Yuan'**
  String get currencyCNY;

  /// No description provided for @currencyUSD.
  ///
  /// In en, this message translates to:
  /// **'US Dollar'**
  String get currencyUSD;

  /// No description provided for @currencyEUR.
  ///
  /// In en, this message translates to:
  /// **'Euro'**
  String get currencyEUR;

  /// No description provided for @currencyJPY.
  ///
  /// In en, this message translates to:
  /// **'Japanese Yen'**
  String get currencyJPY;

  /// No description provided for @currencyHKD.
  ///
  /// In en, this message translates to:
  /// **'Hong Kong Dollar'**
  String get currencyHKD;

  /// No description provided for @currencyTWD.
  ///
  /// In en, this message translates to:
  /// **'New Taiwan Dollar'**
  String get currencyTWD;

  /// No description provided for @currencyGBP.
  ///
  /// In en, this message translates to:
  /// **'British Pound'**
  String get currencyGBP;

  /// No description provided for @currencyAUD.
  ///
  /// In en, this message translates to:
  /// **'Australian Dollar'**
  String get currencyAUD;

  /// No description provided for @currencyCAD.
  ///
  /// In en, this message translates to:
  /// **'Canadian Dollar'**
  String get currencyCAD;

  /// No description provided for @currencyKRW.
  ///
  /// In en, this message translates to:
  /// **'South Korean Won'**
  String get currencyKRW;

  /// No description provided for @currencySGD.
  ///
  /// In en, this message translates to:
  /// **'Singapore Dollar'**
  String get currencySGD;

  /// No description provided for @currencyTHB.
  ///
  /// In en, this message translates to:
  /// **'Thai Baht'**
  String get currencyTHB;

  /// No description provided for @currencyIDR.
  ///
  /// In en, this message translates to:
  /// **'Indonesian Rupiah'**
  String get currencyIDR;

  /// No description provided for @currencyINR.
  ///
  /// In en, this message translates to:
  /// **'Indian Rupee'**
  String get currencyINR;

  /// No description provided for @currencyRUB.
  ///
  /// In en, this message translates to:
  /// **'Russian Ruble'**
  String get currencyRUB;

  /// No description provided for @cloudDefaultServiceDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Default Cloud Service'**
  String get cloudDefaultServiceDisplayName;

  /// No description provided for @cloudNotConfiguredDisplay.
  ///
  /// In en, this message translates to:
  /// **'Not Configured'**
  String get cloudNotConfiguredDisplay;

  /// No description provided for @syncNotConfiguredMessage.
  ///
  /// In en, this message translates to:
  /// **'Cloud not configured'**
  String get syncNotConfiguredMessage;

  /// No description provided for @syncNotLoggedInMessage.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get syncNotLoggedInMessage;

  /// No description provided for @syncCloudBackupCorruptedMessage.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup content is corrupted, possibly due to encoding issues from earlier versions. Please click \'Upload Current Ledger to Cloud\' to overwrite and fix.'**
  String get syncCloudBackupCorruptedMessage;

  /// No description provided for @syncNoCloudBackupMessage.
  ///
  /// In en, this message translates to:
  /// **'No cloud backup'**
  String get syncNoCloudBackupMessage;

  /// No description provided for @syncAccessDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'403 Access denied (check storage RLS policy and path)'**
  String get syncAccessDeniedMessage;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
