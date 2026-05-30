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
    Locale('zh'),
    Locale('zh', 'TW')
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

  /// No description provided for @tabInsights.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get tabInsights;

  /// No description provided for @tabAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get tabAssets;

  /// No description provided for @tabRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get tabRecord;

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

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get commonMore;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonKnow.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get commonKnow;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

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

  /// No description provided for @fabActionCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get fabActionCamera;

  /// No description provided for @fabActionGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get fabActionGallery;

  /// No description provided for @fabActionVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get fabActionVoice;

  /// No description provided for @fabActionVoiceDisabled.
  ///
  /// In en, this message translates to:
  /// **'AI enabled & API Key required'**
  String get fabActionVoiceDisabled;

  /// No description provided for @voiceRecordingTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice Billing'**
  String get voiceRecordingTitle;

  /// No description provided for @voiceRecordingPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get voiceRecordingPreparing;

  /// No description provided for @voiceRecordingInProgress.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get voiceRecordingInProgress;

  /// No description provided for @voiceRecordingProcessing.
  ///
  /// In en, this message translates to:
  /// **'Recognizing...'**
  String get voiceRecordingProcessing;

  /// No description provided for @voiceRecordingDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration: {duration}s'**
  String voiceRecordingDuration(int duration);

  /// No description provided for @voiceRecordingSuccess.
  ///
  /// In en, this message translates to:
  /// **'Voice billing successful'**
  String get voiceRecordingSuccess;

  /// No description provided for @voiceRecordingNoLedger.
  ///
  /// In en, this message translates to:
  /// **'No ledger found'**
  String get voiceRecordingNoLedger;

  /// No description provided for @voiceRecordingNoInfo.
  ///
  /// In en, this message translates to:
  /// **'No billing information recognized'**
  String get voiceRecordingNoInfo;

  /// No description provided for @voiceRecordingPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission required'**
  String get voiceRecordingPermissionDenied;

  /// No description provided for @voiceRecordingPermissionDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone Permission Required'**
  String get voiceRecordingPermissionDeniedTitle;

  /// No description provided for @voiceRecordingPermissionDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice billing requires microphone permission. Please allow BeeCount to access the microphone in System Settings.'**
  String get voiceRecordingPermissionDeniedMessage;

  /// No description provided for @voiceRecordingStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start recording: {error}'**
  String voiceRecordingStartFailed(String error);

  /// No description provided for @voiceRecordingFailed.
  ///
  /// In en, this message translates to:
  /// **'Recording failed: {error}'**
  String voiceRecordingFailed(String error);

  /// No description provided for @voiceRecordingRecognizeFailed.
  ///
  /// In en, this message translates to:
  /// **'Recognition failed: {error}'**
  String voiceRecordingRecognizeFailed(String error);

  /// No description provided for @voiceRecordingNoInfoDetected.
  ///
  /// In en, this message translates to:
  /// **'Unable to extract bill info: {text}'**
  String voiceRecordingNoInfoDetected(String text);

  /// No description provided for @voiceRecordingNoSpeech.
  ///
  /// In en, this message translates to:
  /// **'No speech detected'**
  String get voiceRecordingNoSpeech;

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

  /// No description provided for @commonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get commonOther;

  /// No description provided for @commonYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get commonYesterday;

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

  /// No description provided for @commonSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// No description provided for @commonGoSettings.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings'**
  String get commonGoSettings;

  /// No description provided for @commonLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get commonLanguage;

  /// No description provided for @commonCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get commonCurrent;

  /// No description provided for @commonTutorial.
  ///
  /// In en, this message translates to:
  /// **'Tutorial'**
  String get commonTutorial;

  /// No description provided for @commonConfigure.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get commonConfigure;

  /// No description provided for @commonPressAgainToExit.
  ///
  /// In en, this message translates to:
  /// **'Press again to exit'**
  String get commonPressAgainToExit;

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

  /// No description provided for @homeNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No records yet'**
  String get homeNoRecords;

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

  /// No description provided for @homeLastMonthReportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View and share last month\'s report'**
  String get homeLastMonthReportSubtitle;

  /// No description provided for @homeLastMonthReportView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get homeLastMonthReportView;

  /// No description provided for @homeAnnualReportReminder.
  ///
  /// In en, this message translates to:
  /// **'Your {year} Annual Report is ready'**
  String homeAnnualReportReminder(int year);

  /// No description provided for @homeAnnualReportView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get homeAnnualReportView;

  /// No description provided for @widgetTodayExpense.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Expense'**
  String get widgetTodayExpense;

  /// No description provided for @widgetTodayIncome.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Income'**
  String get widgetTodayIncome;

  /// No description provided for @widgetMonthExpense.
  ///
  /// In en, this message translates to:
  /// **'Month\'s Expense'**
  String get widgetMonthExpense;

  /// No description provided for @widgetMonthIncome.
  ///
  /// In en, this message translates to:
  /// **'Month\'s Income'**
  String get widgetMonthIncome;

  /// No description provided for @widgetMonthSuffix.
  ///
  /// In en, this message translates to:
  /// **''**
  String get widgetMonthSuffix;

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

  /// No description provided for @searchCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'Search category name...'**
  String get searchCategoryHint;

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

  /// No description provided for @searchBatchMode.
  ///
  /// In en, this message translates to:
  /// **'Batch Operations'**
  String get searchBatchMode;

  /// No description provided for @searchBatchModeWithCount.
  ///
  /// In en, this message translates to:
  /// **'Batch Operations ({selected}/{total})'**
  String searchBatchModeWithCount(Object selected, Object total);

  /// No description provided for @searchExitBatchMode.
  ///
  /// In en, this message translates to:
  /// **'Exit Batch Mode'**
  String get searchExitBatchMode;

  /// No description provided for @searchSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get searchSelectAll;

  /// No description provided for @searchDeselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get searchDeselectAll;

  /// No description provided for @searchSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String searchSelectedCount(Object count);

  /// No description provided for @searchBatchSetNote.
  ///
  /// In en, this message translates to:
  /// **'Set Note'**
  String get searchBatchSetNote;

  /// No description provided for @searchBatchChangeCategory.
  ///
  /// In en, this message translates to:
  /// **'Change Category'**
  String get searchBatchChangeCategory;

  /// No description provided for @searchBatchDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get searchBatchDeleteConfirmTitle;

  /// No description provided for @searchBatchDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete the selected {count} transactions?\nThis action cannot be undone.'**
  String searchBatchDeleteConfirmMessage(Object count);

  /// No description provided for @searchBatchSetNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Batch Set Note'**
  String get searchBatchSetNoteTitle;

  /// No description provided for @searchBatchSetNoteMessage.
  ///
  /// In en, this message translates to:
  /// **'Set the same note for the selected {count} transactions'**
  String searchBatchSetNoteMessage(Object count);

  /// No description provided for @searchBatchSetNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Enter note content (leave empty to clear notes)'**
  String get searchBatchSetNoteHint;

  /// No description provided for @searchBatchDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully deleted {count} transactions'**
  String searchBatchDeleteSuccess(Object count);

  /// No description provided for @searchBatchDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String searchBatchDeleteFailed(Object error);

  /// No description provided for @searchBatchSetNoteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully set note for {count} transactions'**
  String searchBatchSetNoteSuccess(Object count);

  /// No description provided for @searchBatchSetNoteFailed.
  ///
  /// In en, this message translates to:
  /// **'Set note failed: {error}'**
  String searchBatchSetNoteFailed(Object error);

  /// No description provided for @searchBatchChangeCategorySuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully changed category for {count} transactions'**
  String searchBatchChangeCategorySuccess(Object count);

  /// No description provided for @searchBatchChangeCategoryFailed.
  ///
  /// In en, this message translates to:
  /// **'Change category failed: {error}'**
  String searchBatchChangeCategoryFailed(Object error);

  /// No description provided for @searchResultsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} results'**
  String searchResultsCount(Object count);

  /// No description provided for @searchFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get searchFilterTitle;

  /// No description provided for @searchAmountFilter.
  ///
  /// In en, this message translates to:
  /// **'Amount Filter'**
  String get searchAmountFilter;

  /// No description provided for @searchDateFilter.
  ///
  /// In en, this message translates to:
  /// **'Date Filter'**
  String get searchDateFilter;

  /// No description provided for @searchStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get searchStartDate;

  /// No description provided for @searchEndDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get searchEndDate;

  /// No description provided for @searchNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not Set'**
  String get searchNotSet;

  /// No description provided for @searchClearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear Filter'**
  String get searchClearFilter;

  /// No description provided for @searchBatchCategoryTransferError.
  ///
  /// In en, this message translates to:
  /// **'Selected transactions contain transfers, cannot change category'**
  String get searchBatchCategoryTransferError;

  /// No description provided for @searchBatchCategoryTypeError.
  ///
  /// In en, this message translates to:
  /// **'Selected transactions have different types, please select all income or all expense'**
  String get searchBatchCategoryTypeError;

  /// No description provided for @searchDateStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get searchDateStart;

  /// No description provided for @searchDateEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get searchDateEnd;

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

  /// No description provided for @analyticsCategoryRanking.
  ///
  /// In en, this message translates to:
  /// **'Category Ranking'**
  String get analyticsCategoryRanking;

  /// No description provided for @analyticsTotalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get analyticsTotalAmount;

  /// No description provided for @analyticsNoDataSubtext.
  ///
  /// In en, this message translates to:
  /// **'Swipe left/right to switch periods, or tap button to toggle income/expense'**
  String get analyticsNoDataSubtext;

  /// No description provided for @analyticsSwipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe left/right to change period'**
  String get analyticsSwipeHint;

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
  /// **'Clear Ledger'**
  String get ledgersClear;

  /// No description provided for @ledgersClearMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to clear all transactions in ledger \"{name}\"? This action cannot be undone.\\nThe ledger will be kept, only transaction data will be deleted.'**
  String ledgersClearMessage(Object name);

  /// No description provided for @ledgerDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Default Ledger'**
  String get ledgerDefaultName;

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

  /// No description provided for @ledgersClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Ledger'**
  String get ledgersClearTitle;

  /// No description provided for @ledgersClearSuccess.
  ///
  /// In en, this message translates to:
  /// **'Ledger cleared'**
  String get ledgersClearSuccess;

  /// No description provided for @ledgersDeleteLocal.
  ///
  /// In en, this message translates to:
  /// **'Delete Local Ledger Only'**
  String get ledgersDeleteLocal;

  /// No description provided for @ledgersDeleteLocalTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Local Ledger'**
  String get ledgersDeleteLocalTitle;

  /// No description provided for @ledgersDeleteLocalMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure to delete local ledger \"{name}\"?\\nCloud backup will be kept and you can restore it anytime.'**
  String ledgersDeleteLocalMessage(Object name);

  /// No description provided for @ledgersDeleteLocalSuccess.
  ///
  /// In en, this message translates to:
  /// **'Local ledger deleted'**
  String get ledgersDeleteLocalSuccess;

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

  /// No description provided for @ledgerCardDownloadCloud.
  ///
  /// In en, this message translates to:
  /// **'Download from Cloud'**
  String get ledgerCardDownloadCloud;

  /// No description provided for @ledgersLocal.
  ///
  /// In en, this message translates to:
  /// **'Local Ledgers'**
  String get ledgersLocal;

  /// No description provided for @ledgersRemote.
  ///
  /// In en, this message translates to:
  /// **'Cloud Ledgers'**
  String get ledgersRemote;

  /// No description provided for @ledgersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No ledgers'**
  String get ledgersEmpty;

  /// No description provided for @ledgersRestoreAll.
  ///
  /// In en, this message translates to:
  /// **'Restore All'**
  String get ledgersRestoreAll;

  /// No description provided for @ledgersSwitched.
  ///
  /// In en, this message translates to:
  /// **'Switched to ledger \"{name}\"'**
  String ledgersSwitched(String name);

  /// No description provided for @ledgersDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Download Ledger'**
  String get ledgersDownloadTitle;

  /// No description provided for @ledgersDownloadMessage.
  ///
  /// In en, this message translates to:
  /// **'Confirm download ledger \"{name}\" to local?'**
  String ledgersDownloadMessage(String name);

  /// No description provided for @ledgersDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get ledgersDownloading;

  /// No description provided for @ledgersDownloadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Ledger \"{name}\" downloaded successfully'**
  String ledgersDownloadSuccess(String name);

  /// No description provided for @ledgersDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get ledgersDownload;

  /// No description provided for @ledgersDeleteRemote.
  ///
  /// In en, this message translates to:
  /// **'Delete Cloud Ledger'**
  String get ledgersDeleteRemote;

  /// No description provided for @ledgersDeleteRemoteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete Cloud Ledger'**
  String get ledgersDeleteRemoteConfirm;

  /// No description provided for @ledgersDeleteRemoteMessage.
  ///
  /// In en, this message translates to:
  /// **'Confirm delete cloud ledger \"{name}\"? This action cannot be undone.'**
  String ledgersDeleteRemoteMessage(String name);

  /// No description provided for @ledgersDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting...'**
  String get ledgersDeleting;

  /// No description provided for @ledgersDeleteRemoteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Cloud ledger deleted'**
  String get ledgersDeleteRemoteSuccess;

  /// No description provided for @ledgersCannotDeleteLastOne.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete the last ledger'**
  String get ledgersCannotDeleteLastOne;

  /// No description provided for @ledgersRestoreAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Batch Restore'**
  String get ledgersRestoreAllTitle;

  /// No description provided for @ledgersRestoreAllMessage.
  ///
  /// In en, this message translates to:
  /// **'Confirm restore all cloud ledgers? Total {count}.'**
  String ledgersRestoreAllMessage(int count);

  /// No description provided for @ledgersRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring...'**
  String get ledgersRestoring;

  /// No description provided for @ledgersRestoreComplete.
  ///
  /// In en, this message translates to:
  /// **'Restore Complete'**
  String get ledgersRestoreComplete;

  /// No description provided for @ledgersRestoreResult.
  ///
  /// In en, this message translates to:
  /// **'Success: {success}, Failed: {failed}'**
  String ledgersRestoreResult(int success, int failed);

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
  /// **'Expense'**
  String get categoryExpense;

  /// No description provided for @categoryIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
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

  /// No description provided for @categoryReorderTip.
  ///
  /// In en, this message translates to:
  /// **'Long press to drag and reorder categories'**
  String get categoryReorderTip;

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

  /// No description provided for @importBillType.
  ///
  /// In en, this message translates to:
  /// **'Bill Type'**
  String get importBillType;

  /// No description provided for @importBillTypeGeneric.
  ///
  /// In en, this message translates to:
  /// **'Generic CSV'**
  String get importBillTypeGeneric;

  /// No description provided for @importBillTypeAlipay.
  ///
  /// In en, this message translates to:
  /// **'Alipay'**
  String get importBillTypeAlipay;

  /// No description provided for @importBillTypeWechat.
  ///
  /// In en, this message translates to:
  /// **'WeChat'**
  String get importBillTypeWechat;

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
  /// **'Tip: Please select a file to start importing (CSV/TSV/XLSX)'**
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

  /// No description provided for @importFieldAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get importFieldAccount;

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

  /// No description provided for @importSkippedNonTransactionTypes.
  ///
  /// In en, this message translates to:
  /// **'Skipped {count} non-transaction records (debts, etc.)'**
  String importSkippedNonTransactionTypes(Object count);

  /// No description provided for @importTransactionFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed, all changes have been rolled back: {error}'**
  String importTransactionFailed(Object error);

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

  /// No description provided for @mineReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder Settings'**
  String get mineReminder;

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

  /// No description provided for @mineSlogan.
  ///
  /// In en, this message translates to:
  /// **'Bee Accounting, Every Penny Counts'**
  String get mineSlogan;

  /// No description provided for @mineAvatarTitle.
  ///
  /// In en, this message translates to:
  /// **'Avatar Settings'**
  String get mineAvatarTitle;

  /// No description provided for @mineAvatarFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get mineAvatarFromGallery;

  /// No description provided for @mineAvatarFromCamera.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get mineAvatarFromCamera;

  /// No description provided for @mineAvatarDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Avatar'**
  String get mineAvatarDelete;

  /// No description provided for @annualReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Annual Report'**
  String get annualReportTitle;

  /// No description provided for @annualReportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review your {year} financial journey'**
  String annualReportSubtitle(int year);

  /// No description provided for @annualReportEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your personalized annual report to share'**
  String get annualReportEntrySubtitle;

  /// No description provided for @annualReportNoData.
  ///
  /// In en, this message translates to:
  /// **'No data for {year}'**
  String annualReportNoData(int year);

  /// No description provided for @annualReportPage1Title.
  ///
  /// In en, this message translates to:
  /// **'Annual Overview'**
  String get annualReportPage1Title;

  /// No description provided for @annualReportPage1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your {year} bookkeeping journey'**
  String annualReportPage1Subtitle(int year);

  /// No description provided for @annualReportTotalDays.
  ///
  /// In en, this message translates to:
  /// **'Days Tracked'**
  String get annualReportTotalDays;

  /// No description provided for @annualReportTotalRecords.
  ///
  /// In en, this message translates to:
  /// **'Total Records'**
  String get annualReportTotalRecords;

  /// No description provided for @annualReportTotalIncome.
  ///
  /// In en, this message translates to:
  /// **'Total Income'**
  String get annualReportTotalIncome;

  /// No description provided for @annualReportTotalExpense.
  ///
  /// In en, this message translates to:
  /// **'Total Expense'**
  String get annualReportTotalExpense;

  /// No description provided for @annualReportNetSavings.
  ///
  /// In en, this message translates to:
  /// **'Net Savings'**
  String get annualReportNetSavings;

  /// No description provided for @annualReportPage2Title.
  ///
  /// In en, this message translates to:
  /// **'Expense Analysis'**
  String get annualReportPage2Title;

  /// No description provided for @annualReportPage2Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Where your money went'**
  String get annualReportPage2Subtitle;

  /// No description provided for @annualReportPage3Title.
  ///
  /// In en, this message translates to:
  /// **'Monthly Trends'**
  String get annualReportPage3Title;

  /// No description provided for @annualReportPage3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'12 months of income & expense'**
  String get annualReportPage3Subtitle;

  /// No description provided for @annualReportHighestMonth.
  ///
  /// In en, this message translates to:
  /// **'Highest Spending Month'**
  String get annualReportHighestMonth;

  /// No description provided for @annualReportLowestMonth.
  ///
  /// In en, this message translates to:
  /// **'Lowest Spending Month'**
  String get annualReportLowestMonth;

  /// No description provided for @annualReportPage4Title.
  ///
  /// In en, this message translates to:
  /// **'Special Moments'**
  String get annualReportPage4Title;

  /// No description provided for @annualReportPage4Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Memorable transactions'**
  String get annualReportPage4Subtitle;

  /// No description provided for @annualReportLargestExpense.
  ///
  /// In en, this message translates to:
  /// **'Largest Expense'**
  String get annualReportLargestExpense;

  /// No description provided for @annualReportLargestIncome.
  ///
  /// In en, this message translates to:
  /// **'Largest Income'**
  String get annualReportLargestIncome;

  /// No description provided for @annualReportFirstRecord.
  ///
  /// In en, this message translates to:
  /// **'First Record'**
  String get annualReportFirstRecord;

  /// No description provided for @annualReportPage5Title.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get annualReportPage5Title;

  /// No description provided for @annualReportPage5Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your bookkeeping badges'**
  String get annualReportPage5Subtitle;

  /// No description provided for @annualReportAchievementConsistent.
  ///
  /// In en, this message translates to:
  /// **'Consistent'**
  String get annualReportAchievementConsistent;

  /// No description provided for @annualReportAchievementConsistentDesc.
  ///
  /// In en, this message translates to:
  /// **'Tracked for over {days} days straight'**
  String annualReportAchievementConsistentDesc(int days);

  /// No description provided for @annualReportAchievementSaver.
  ///
  /// In en, this message translates to:
  /// **'Saver'**
  String get annualReportAchievementSaver;

  /// No description provided for @annualReportAchievementSaverDesc.
  ///
  /// In en, this message translates to:
  /// **'Positive net savings this year'**
  String get annualReportAchievementSaverDesc;

  /// No description provided for @annualReportAchievementDetail.
  ///
  /// In en, this message translates to:
  /// **'Detail-Oriented'**
  String get annualReportAchievementDetail;

  /// No description provided for @annualReportAchievementDetailDesc.
  ///
  /// In en, this message translates to:
  /// **'Over {count} records tracked'**
  String annualReportAchievementDetailDesc(int count);

  /// No description provided for @annualReportShareButton.
  ///
  /// In en, this message translates to:
  /// **'Generate Share Poster'**
  String get annualReportShareButton;

  /// No description provided for @annualReportGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating annual report...'**
  String get annualReportGenerating;

  /// No description provided for @annualReportSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Annual report poster saved'**
  String get annualReportSaveSuccess;

  /// No description provided for @mineShareApp.
  ///
  /// In en, this message translates to:
  /// **'Share App'**
  String get mineShareApp;

  /// No description provided for @mineShareWithFriends.
  ///
  /// In en, this message translates to:
  /// **'Share BeeCount with friends'**
  String get mineShareWithFriends;

  /// No description provided for @mineCopyPromoText.
  ///
  /// In en, this message translates to:
  /// **'Copy Promo Text'**
  String get mineCopyPromoText;

  /// No description provided for @mineCopyPromoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Copy and share with friends'**
  String get mineCopyPromoSubtitle;

  /// No description provided for @mineShareGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating share poster...'**
  String get mineShareGenerating;

  /// No description provided for @sharePosterAppName.
  ///
  /// In en, this message translates to:
  /// **'BeeCount'**
  String get sharePosterAppName;

  /// No description provided for @sharePosterSlogan.
  ///
  /// In en, this message translates to:
  /// **'Smart Accounting, Beautiful Life'**
  String get sharePosterSlogan;

  /// No description provided for @sharePosterFeature1.
  ///
  /// In en, this message translates to:
  /// **'Data Security·You Control'**
  String get sharePosterFeature1;

  /// No description provided for @sharePosterFeature2.
  ///
  /// In en, this message translates to:
  /// **'Open Source·Auditable'**
  String get sharePosterFeature2;

  /// No description provided for @sharePosterFeature3.
  ///
  /// In en, this message translates to:
  /// **'AI Smart·Photo & Voice'**
  String get sharePosterFeature3;

  /// No description provided for @sharePosterFeature4.
  ///
  /// In en, this message translates to:
  /// **'Photo Accounting·Auto Recognition'**
  String get sharePosterFeature4;

  /// No description provided for @sharePosterFeature5.
  ///
  /// In en, this message translates to:
  /// **'Multi Ledger·Dark Mode'**
  String get sharePosterFeature5;

  /// No description provided for @sharePosterFeature6.
  ///
  /// In en, this message translates to:
  /// **'Self-Hosted Cloud·Free Forever'**
  String get sharePosterFeature6;

  /// No description provided for @sharePosterScanText.
  ///
  /// In en, this message translates to:
  /// **'Scan to visit open source project'**
  String get sharePosterScanText;

  /// No description provided for @appPromoTagOpenSource.
  ///
  /// In en, this message translates to:
  /// **'Open Source'**
  String get appPromoTagOpenSource;

  /// No description provided for @appPromoTagFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get appPromoTagFree;

  /// No description provided for @appPromoFooterText.
  ///
  /// In en, this message translates to:
  /// **'Track every penny, trace every moment'**
  String get appPromoFooterText;

  /// No description provided for @userProfileJourneyYears.
  ///
  /// In en, this message translates to:
  /// **'Bookkeeping Pro {years} Years'**
  String userProfileJourneyYears(int years);

  /// No description provided for @userProfileJourneyOneYear.
  ///
  /// In en, this message translates to:
  /// **'One Year of Bookkeeping'**
  String get userProfileJourneyOneYear;

  /// No description provided for @userProfileJourneyHalfYear.
  ///
  /// In en, this message translates to:
  /// **'Six Months Strong'**
  String get userProfileJourneyHalfYear;

  /// No description provided for @userProfileJourneyThreeMonths.
  ///
  /// In en, this message translates to:
  /// **'Three Months In'**
  String get userProfileJourneyThreeMonths;

  /// No description provided for @userProfileJourneyOneMonth.
  ///
  /// In en, this message translates to:
  /// **'One Month Milestone'**
  String get userProfileJourneyOneMonth;

  /// No description provided for @userProfileJourneyOneWeek.
  ///
  /// In en, this message translates to:
  /// **'First Week Done'**
  String get userProfileJourneyOneWeek;

  /// No description provided for @userProfileJourneyStart.
  ///
  /// In en, this message translates to:
  /// **'Starting the Journey'**
  String get userProfileJourneyStart;

  /// No description provided for @userProfileDailyAverage.
  ///
  /// In en, this message translates to:
  /// **'Daily Average'**
  String get userProfileDailyAverage;

  /// No description provided for @sharePosterSave.
  ///
  /// In en, this message translates to:
  /// **'Save to Gallery'**
  String get sharePosterSave;

  /// No description provided for @sharePosterShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get sharePosterShare;

  /// No description provided for @sharePosterHideIncome.
  ///
  /// In en, this message translates to:
  /// **'Hide Income'**
  String get sharePosterHideIncome;

  /// No description provided for @sharePosterShowIncome.
  ///
  /// In en, this message translates to:
  /// **'Show Income'**
  String get sharePosterShowIncome;

  /// No description provided for @sharePosterSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved to gallery'**
  String get sharePosterSaveSuccess;

  /// No description provided for @shareGuidanceCopyText.
  ///
  /// In en, this message translates to:
  /// **'Track my expenses with BeeCount - open source, free & ad-free! 🐝 Download: https://github.com/TNT-Likely/BeeCount'**
  String get shareGuidanceCopyText;

  /// No description provided for @shareGuidanceCopied.
  ///
  /// In en, this message translates to:
  /// **'Text copied'**
  String get shareGuidanceCopied;

  /// No description provided for @sharePosterSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save'**
  String get sharePosterSaveFailed;

  /// No description provided for @sharePosterPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Gallery permission denied, please enable in settings'**
  String get sharePosterPermissionDenied;

  /// No description provided for @sharePosterGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get sharePosterGenerating;

  /// No description provided for @sharePosterGenerateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate poster, please try again'**
  String get sharePosterGenerateFailed;

  /// No description provided for @sharePosterNoLedger.
  ///
  /// In en, this message translates to:
  /// **'Please select a ledger first'**
  String get sharePosterNoLedger;

  /// No description provided for @sharePosterYearTitle.
  ///
  /// In en, this message translates to:
  /// **'My Annual Bookkeeping Report'**
  String get sharePosterYearTitle;

  /// No description provided for @sharePosterYearSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Record life with data, plan future with reason'**
  String get sharePosterYearSubtitle;

  /// No description provided for @sharePosterMonthTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly Bill Report'**
  String get sharePosterMonthTitle;

  /// No description provided for @sharePosterMonthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Budget Wisely, Spend Rationally'**
  String get sharePosterMonthSubtitle;

  /// No description provided for @sharePosterLedgerTitle.
  ///
  /// In en, this message translates to:
  /// **'Ledger Statistics Report'**
  String get sharePosterLedgerTitle;

  /// No description provided for @sharePosterRecordDays.
  ///
  /// In en, this message translates to:
  /// **'Record Days'**
  String get sharePosterRecordDays;

  /// No description provided for @sharePosterRecordCount.
  ///
  /// In en, this message translates to:
  /// **'Record Count'**
  String get sharePosterRecordCount;

  /// No description provided for @sharePosterTotalExpense.
  ///
  /// In en, this message translates to:
  /// **'Total Expense'**
  String get sharePosterTotalExpense;

  /// No description provided for @sharePosterTotalIncome.
  ///
  /// In en, this message translates to:
  /// **'Total Income'**
  String get sharePosterTotalIncome;

  /// No description provided for @sharePosterYearBalance.
  ///
  /// In en, this message translates to:
  /// **'Annual Balance'**
  String get sharePosterYearBalance;

  /// No description provided for @sharePosterYearDeficit.
  ///
  /// In en, this message translates to:
  /// **'Annual Deficit'**
  String get sharePosterYearDeficit;

  /// No description provided for @sharePosterMonthBalance.
  ///
  /// In en, this message translates to:
  /// **'Monthly Balance'**
  String get sharePosterMonthBalance;

  /// No description provided for @sharePosterBalance.
  ///
  /// In en, this message translates to:
  /// **'Total Balance'**
  String get sharePosterBalance;

  /// No description provided for @sharePosterAvgMonthlyExpense.
  ///
  /// In en, this message translates to:
  /// **'Avg. Monthly Expense'**
  String get sharePosterAvgMonthlyExpense;

  /// No description provided for @sharePosterAvgMonthlyIncome.
  ///
  /// In en, this message translates to:
  /// **'Avg. Monthly Income'**
  String get sharePosterAvgMonthlyIncome;

  /// No description provided for @sharePosterAvgDailyExpense.
  ///
  /// In en, this message translates to:
  /// **'Avg. Daily Expense'**
  String get sharePosterAvgDailyExpense;

  /// No description provided for @sharePosterMaxExpenseMonth.
  ///
  /// In en, this message translates to:
  /// **'Highest Expense Month'**
  String get sharePosterMaxExpenseMonth;

  /// No description provided for @sharePosterTopExpense.
  ///
  /// In en, this message translates to:
  /// **'TOP 3 Expenses'**
  String get sharePosterTopExpense;

  /// No description provided for @sharePosterCompareLastMonth.
  ///
  /// In en, this message translates to:
  /// **'vs Last Month'**
  String get sharePosterCompareLastMonth;

  /// No description provided for @sharePosterIncreaseRate.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get sharePosterIncreaseRate;

  /// No description provided for @sharePosterDecreaseRate.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get sharePosterDecreaseRate;

  /// No description provided for @sharePosterSavedMoneyTitle.
  ///
  /// In en, this message translates to:
  /// **'Congrats! You saved this month'**
  String get sharePosterSavedMoneyTitle;

  /// No description provided for @sharePosterLedgerName.
  ///
  /// In en, this message translates to:
  /// **'Ledger Name'**
  String get sharePosterLedgerName;

  /// No description provided for @sharePosterUnitDay.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get sharePosterUnitDay;

  /// No description provided for @sharePosterUnitCount.
  ///
  /// In en, this message translates to:
  /// **''**
  String get sharePosterUnitCount;

  /// No description provided for @sharePosterUnitYuan.
  ///
  /// In en, this message translates to:
  /// **''**
  String get sharePosterUnitYuan;

  /// No description provided for @userProfilePosterStartDate.
  ///
  /// In en, this message translates to:
  /// **'Bookkeeping since {date}'**
  String userProfilePosterStartDate(String date);

  /// No description provided for @userProfilePosterRecordDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get userProfilePosterRecordDays;

  /// No description provided for @userProfilePosterDaysUnit.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get userProfilePosterDaysUnit;

  /// No description provided for @userProfilePosterRecordCount.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get userProfilePosterRecordCount;

  /// No description provided for @userProfilePosterCountUnit.
  ///
  /// In en, this message translates to:
  /// **''**
  String get userProfilePosterCountUnit;

  /// No description provided for @userProfilePosterLedgerCount.
  ///
  /// In en, this message translates to:
  /// **'Ledgers'**
  String get userProfilePosterLedgerCount;

  /// No description provided for @userProfilePosterLedgerUnit.
  ///
  /// In en, this message translates to:
  /// **''**
  String get userProfilePosterLedgerUnit;

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

  /// No description provided for @mineCloudServiceWebDAV.
  ///
  /// In en, this message translates to:
  /// **'Custom Cloud Service (WebDAV)'**
  String get mineCloudServiceWebDAV;

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
  /// **'No cloud data'**
  String get mineSyncNoRemote;

  /// No description provided for @mineSyncInSync.
  ///
  /// In en, this message translates to:
  /// **'Synced (local {count} records)'**
  String mineSyncInSync(Object count);

  /// No description provided for @mineSyncInSyncSimple.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get mineSyncInSyncSimple;

  /// No description provided for @mineSyncLocalNewer.
  ///
  /// In en, this message translates to:
  /// **'Local updated ({count} records, upload recommended)'**
  String mineSyncLocalNewer(Object count);

  /// No description provided for @mineSyncLocalNewerSimple.
  ///
  /// In en, this message translates to:
  /// **'Local updated'**
  String get mineSyncLocalNewerSimple;

  /// No description provided for @mineSyncCloudNewer.
  ///
  /// In en, this message translates to:
  /// **'Cloud updated (download to sync)'**
  String get mineSyncCloudNewer;

  /// No description provided for @mineSyncCloudNewerSimple.
  ///
  /// In en, this message translates to:
  /// **'Cloud updated'**
  String get mineSyncCloudNewerSimple;

  /// No description provided for @mineSyncDifferent.
  ///
  /// In en, this message translates to:
  /// **'Local and cloud differ, download to compare'**
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

  /// No description provided for @mineUploadNeedCloudService.
  ///
  /// In en, this message translates to:
  /// **'Available in cloud service mode only'**
  String get mineUploadNeedCloudService;

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
  /// **'Download & Sync'**
  String get mineDownloadTitle;

  /// No description provided for @mineDownloadNeedCloudService.
  ///
  /// In en, this message translates to:
  /// **'Available in cloud service mode only'**
  String get mineDownloadNeedCloudService;

  /// No description provided for @mineDownloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync Complete'**
  String get mineDownloadComplete;

  /// No description provided for @mineDownloadResult.
  ///
  /// In en, this message translates to:
  /// **'Imported: {inserted} records'**
  String mineDownloadResult(Object inserted);

  /// No description provided for @mineLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get mineLoginTitle;

  /// No description provided for @mineLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only needed for sync'**
  String get mineLoginSubtitle;

  /// No description provided for @cloudReloginTitle.
  ///
  /// In en, this message translates to:
  /// **'Re-login'**
  String get cloudReloginTitle;

  /// No description provided for @cloudReloginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Re-logged in'**
  String get cloudReloginSuccess;

  /// No description provided for @cloudReloginFailed.
  ///
  /// In en, this message translates to:
  /// **'Re-login failed'**
  String get cloudReloginFailed;

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

  /// No description provided for @mineRecurringTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recurring Bills'**
  String get mineRecurringTransactions;

  /// No description provided for @mineRecurringTransactionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage recurring bills'**
  String get mineRecurringTransactionsSubtitle;

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

  /// No description provided for @mineCheckUpdate.
  ///
  /// In en, this message translates to:
  /// **'Check Update'**
  String get mineCheckUpdate;

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

  /// No description provided for @mineFeedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get mineFeedback;

  /// No description provided for @mineFeedbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Report issues or suggestions'**
  String get mineFeedbackSubtitle;

  /// No description provided for @mineHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get mineHelp;

  /// No description provided for @mineHelpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View documentation and FAQ'**
  String get mineHelpSubtitle;

  /// No description provided for @mineSupportAuthor.
  ///
  /// In en, this message translates to:
  /// **'Star the Project ⭐️'**
  String get mineSupportAuthor;

  /// No description provided for @mineSupportAuthorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open source, {count} stars'**
  String mineSupportAuthorSubtitle(String count);

  /// No description provided for @githubStarGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'How to Star the Project'**
  String get githubStarGuideTitle;

  /// No description provided for @githubStarGuideContent.
  ///
  /// In en, this message translates to:
  /// **'After tapping the button below to open GitHub, tap the area marked in the image to complete the Star'**
  String get githubStarGuideContent;

  /// No description provided for @githubStarGuideButton.
  ///
  /// In en, this message translates to:
  /// **'Go to GitHub'**
  String get githubStarGuideButton;

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

  /// No description provided for @categoryMigrationTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Select Type'**
  String get categoryMigrationTypeLabel;

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

  /// No description provided for @categoryNameDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Category name already exists'**
  String get categoryNameDuplicate;

  /// No description provided for @categoryIconLabel.
  ///
  /// In en, this message translates to:
  /// **'Category Icon'**
  String get categoryIconLabel;

  /// No description provided for @categoryCustomIconTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Icon'**
  String get categoryCustomIconTitle;

  /// No description provided for @categoryCustomIconTapToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap to select image'**
  String get categoryCustomIconTapToSelect;

  /// No description provided for @categoryCustomIconTapToChange.
  ///
  /// In en, this message translates to:
  /// **'Tap to change image'**
  String get categoryCustomIconTapToChange;

  /// No description provided for @categoryCustomIconError.
  ///
  /// In en, this message translates to:
  /// **'Error selecting image'**
  String get categoryCustomIconError;

  /// No description provided for @categoryCustomIconRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a custom icon image'**
  String get categoryCustomIconRequired;

  /// No description provided for @categoryCustomIconCrop.
  ///
  /// In en, this message translates to:
  /// **'Crop Icon'**
  String get categoryCustomIconCrop;

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

  /// No description provided for @categoryShare.
  ///
  /// In en, this message translates to:
  /// **'Share Categories'**
  String get categoryShare;

  /// No description provided for @categoryImport.
  ///
  /// In en, this message translates to:
  /// **'Import Categories'**
  String get categoryImport;

  /// No description provided for @categoryClearUnused.
  ///
  /// In en, this message translates to:
  /// **'Clear Unused Categories'**
  String get categoryClearUnused;

  /// No description provided for @categoryClearUnusedTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Unused Categories'**
  String get categoryClearUnusedTitle;

  /// No description provided for @categoryClearUnusedMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} unused categories? This action cannot be undone.'**
  String categoryClearUnusedMessage(Object count);

  /// No description provided for @categoryClearUnusedListTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories to be deleted:'**
  String get categoryClearUnusedListTitle;

  /// No description provided for @categoryClearUnusedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No unused categories'**
  String get categoryClearUnusedEmpty;

  /// No description provided for @categoryClearUnusedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} categories'**
  String categoryClearUnusedSuccess(Object count);

  /// No description provided for @categoryClearUnusedFailed.
  ///
  /// In en, this message translates to:
  /// **'Clear failed'**
  String get categoryClearUnusedFailed;

  /// No description provided for @categoryShareScopeTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Scope'**
  String get categoryShareScopeTitle;

  /// No description provided for @categoryShareScopeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense categories only'**
  String get categoryShareScopeExpense;

  /// No description provided for @categoryShareScopeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income categories only'**
  String get categoryShareScopeIncome;

  /// No description provided for @categoryShareScopeAll.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get categoryShareScopeAll;

  /// No description provided for @categoryShareSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String categoryShareSuccess(Object path);

  /// No description provided for @categoryShareSubject.
  ///
  /// In en, this message translates to:
  /// **'BeeCount Category Configuration'**
  String get categoryShareSubject;

  /// No description provided for @categoryShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Share failed'**
  String get categoryShareFailed;

  /// No description provided for @categoryImportInvalidFile.
  ///
  /// In en, this message translates to:
  /// **'Please select a category package file (.zip)'**
  String get categoryImportInvalidFile;

  /// No description provided for @categoryImportModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Import Mode'**
  String get categoryImportModeTitle;

  /// No description provided for @categoryImportModeMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get categoryImportModeMerge;

  /// No description provided for @categoryImportModeMergeDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep existing, add new ones'**
  String get categoryImportModeMergeDesc;

  /// No description provided for @categoryImportModeOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get categoryImportModeOverwrite;

  /// No description provided for @categoryImportModeOverwriteDesc.
  ///
  /// In en, this message translates to:
  /// **'Clear unused categories then import'**
  String get categoryImportModeOverwriteDesc;

  /// No description provided for @categoryImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Import successful'**
  String get categoryImportSuccess;

  /// No description provided for @categoryImportSuccessDetail.
  ///
  /// In en, this message translates to:
  /// **'Imported {imported} categories, skipped {skipped}, imported {icons} icons'**
  String categoryImportSuccessDetail(int imported, int skipped, int icons);

  /// No description provided for @categoryImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get categoryImportFailed;

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

  /// No description provided for @categorySubCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Subcategory'**
  String get categorySubCategoryTitle;

  /// No description provided for @categorySubCategoryDescriptionEnabled.
  ///
  /// In en, this message translates to:
  /// **'This category belongs to a parent category'**
  String get categorySubCategoryDescriptionEnabled;

  /// No description provided for @categorySubCategoryDescriptionDisabled.
  ///
  /// In en, this message translates to:
  /// **'This is an independent top-level category'**
  String get categorySubCategoryDescriptionDisabled;

  /// No description provided for @categoryParentCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent Category'**
  String get categoryParentCategoryTitle;

  /// No description provided for @categoryParentCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'Please select parent category'**
  String get categoryParentCategoryHint;

  /// No description provided for @categorySelectParentTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Parent Category'**
  String get categorySelectParentTitle;

  /// No description provided for @categorySubCategoryCreated.
  ///
  /// In en, this message translates to:
  /// **'Subcategory added: {name}'**
  String categorySubCategoryCreated(Object name);

  /// No description provided for @categoryParentRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select parent category'**
  String get categoryParentRequired;

  /// No description provided for @categoryParentRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get categoryParentRequiredTitle;

  /// No description provided for @categoryExpenseList.
  ///
  /// In en, this message translates to:
  /// **'Dining-Transport-Shopping-Entertainment-Home-Family-Communication-Utilities-Housing-Medical-Education-Pets-Sports-Digital-Travel-Alcohol & Tobacco-Baby Care-Beauty-Repair-Social-Learning-Car-Taxi-Subway-Delivery-Property-Parking-Donation-Give Gift-Tax-Beverage-Clothing-Snacks-Send Red Packet-Fruit-Game-Book-Lover-Decoration-Daily Goods-Lottery-Stock-Social Security-Express-Work'**
  String get categoryExpenseList;

  /// No description provided for @categoryIncomeList.
  ///
  /// In en, this message translates to:
  /// **'Salary-Investment-Receive Red Packet-Bonus-Reimbursement-Part-time-Receive Gift-Interest-Refund-Investment Income-Second-hand-Social Benefit-Tax Refund-Provident Fund'**
  String get categoryIncomeList;

  /// No description provided for @categoryExpenseDining.
  ///
  /// In en, this message translates to:
  /// **'Dining-Breakfast-Lunch-Dinner-Meituan Delivery-Ele.me Delivery-JD Delivery-Restaurant-Food'**
  String get categoryExpenseDining;

  /// No description provided for @categoryExpenseSnacks.
  ///
  /// In en, this message translates to:
  /// **'Cookies-Chips-Candy-Chocolate-Nuts'**
  String get categoryExpenseSnacks;

  /// No description provided for @categoryExpenseFruit.
  ///
  /// In en, this message translates to:
  /// **'Fruit-Apple-Banana-Orange-Grape-Watermelon-Other Fruits'**
  String get categoryExpenseFruit;

  /// No description provided for @categoryExpenseBeverage.
  ///
  /// In en, this message translates to:
  /// **'Beverage-Milk Tea-Coffee-Juice-Soda-Mineral Water'**
  String get categoryExpenseBeverage;

  /// No description provided for @categoryExpensePastry.
  ///
  /// In en, this message translates to:
  /// **'Pastry-Cake-Bread-Dessert-Pastry'**
  String get categoryExpensePastry;

  /// No description provided for @categoryExpenseCooking.
  ///
  /// In en, this message translates to:
  /// **'Cooking Ingredients-Vegetables-Meat-Seafood-Seasoning-Grain & Oil'**
  String get categoryExpenseCooking;

  /// No description provided for @categoryExpenseShopping.
  ///
  /// In en, this message translates to:
  /// **'Clothing-Shoes & Hats-Bags-Accessories-Daily Necessities'**
  String get categoryExpenseShopping;

  /// No description provided for @categoryExpensePets.
  ///
  /// In en, this message translates to:
  /// **'Pets-Pet Food-Pet Supplies-Pet Medical-Pet Grooming'**
  String get categoryExpensePets;

  /// No description provided for @categoryExpenseTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport-Subway-Bus-Taxi-Ride-hailing-Parking Fee-Fuel'**
  String get categoryExpenseTransport;

  /// No description provided for @categoryExpenseCar.
  ///
  /// In en, this message translates to:
  /// **'Car-Car Maintenance-Car Repair-Car Insurance-Car Wash-Traffic Fine'**
  String get categoryExpenseCar;

  /// No description provided for @categoryExpenseClothing.
  ///
  /// In en, this message translates to:
  /// **'Top-Pants-Dress-Shoes-Accessories'**
  String get categoryExpenseClothing;

  /// No description provided for @categoryExpenseDailyGoods.
  ///
  /// In en, this message translates to:
  /// **'Daily Goods-Personal Care-Paper Products-Cleaning Supplies-Kitchen Supplies'**
  String get categoryExpenseDailyGoods;

  /// No description provided for @categoryExpenseEducation.
  ///
  /// In en, this message translates to:
  /// **'Tuition-Training Fee-Books-Stationery-Office Supplies'**
  String get categoryExpenseEducation;

  /// No description provided for @categoryExpenseInvestLoss.
  ///
  /// In en, this message translates to:
  /// **'Investment Loss-Stock Loss-Fund Loss-Other Investment Loss'**
  String get categoryExpenseInvestLoss;

  /// No description provided for @categoryExpenseEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment-Movie-KTV-Amusement Park-Bar-Other Entertainment'**
  String get categoryExpenseEntertainment;

  /// No description provided for @categoryExpenseGame.
  ///
  /// In en, this message translates to:
  /// **'Game-Game Top-up-Game Equipment-Game Membership'**
  String get categoryExpenseGame;

  /// No description provided for @categoryExpenseHealthProducts.
  ///
  /// In en, this message translates to:
  /// **'Health Products-Vitamins-Health Food-Nutritional Supplements'**
  String get categoryExpenseHealthProducts;

  /// No description provided for @categoryExpenseSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription-Video Membership-Music Membership-Cloud Storage-Other Subscription'**
  String get categoryExpenseSubscription;

  /// No description provided for @categoryExpenseSports.
  ///
  /// In en, this message translates to:
  /// **'Sports-Gym-Sports Equipment-Sports Course-Outdoor Activity'**
  String get categoryExpenseSports;

  /// No description provided for @categoryExpenseHousing.
  ///
  /// In en, this message translates to:
  /// **'Housing-Rent-Property Fee-Mortgage-Renovation'**
  String get categoryExpenseHousing;

  /// No description provided for @categoryExpenseHome.
  ///
  /// In en, this message translates to:
  /// **'Home-Furniture-Appliances-Decorations-Bedding'**
  String get categoryExpenseHome;

  /// No description provided for @categoryExpenseBeauty.
  ///
  /// In en, this message translates to:
  /// **'Beauty-Skincare-Cosmetics-Beauty Salon-Nail Care'**
  String get categoryExpenseBeauty;

  /// No description provided for @categoryIncomeSalary.
  ///
  /// In en, this message translates to:
  /// **'Base Salary-Performance Bonus-Year-end Bonus-Overtime Pay'**
  String get categoryIncomeSalary;

  /// No description provided for @categoryIncomeInvestment.
  ///
  /// In en, this message translates to:
  /// **'Fund Earnings-Stock Dividend-Wealth Management-Other Wealth Management'**
  String get categoryIncomeInvestment;

  /// No description provided for @categoryIncomeRedPacket.
  ///
  /// In en, this message translates to:
  /// **'Red Packet-Holiday Red Packet-Birthday Red Packet-Return Gift'**
  String get categoryIncomeRedPacket;

  /// No description provided for @categoryIncomeBonus.
  ///
  /// In en, this message translates to:
  /// **'Bonus-Year-end Bonus-Quarterly Bonus-Project Bonus-Other Bonus'**
  String get categoryIncomeBonus;

  /// No description provided for @categoryIncomeReimbursement.
  ///
  /// In en, this message translates to:
  /// **'Reimbursement-Travel Reimbursement-Meal Reimbursement-Other Reimbursement'**
  String get categoryIncomeReimbursement;

  /// No description provided for @categoryIncomePartTime.
  ///
  /// In en, this message translates to:
  /// **'Part-time-Part-time Income-Side Income'**
  String get categoryIncomePartTime;

  /// No description provided for @categoryIncomeGift.
  ///
  /// In en, this message translates to:
  /// **'Gift-Wedding Gift-Birthday Gift-Other Gift'**
  String get categoryIncomeGift;

  /// No description provided for @categoryIncomeInterest.
  ///
  /// In en, this message translates to:
  /// **'Interest-Bank Interest-Other Interest'**
  String get categoryIncomeInterest;

  /// No description provided for @categoryIncomeRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund-Shopping Refund-Service Refund-Other Refund'**
  String get categoryIncomeRefund;

  /// No description provided for @categoryIncomeInvestIncome.
  ///
  /// In en, this message translates to:
  /// **'Investment Income-Stock Earnings-Fund Earnings-Other Investment Income'**
  String get categoryIncomeInvestIncome;

  /// No description provided for @categoryIncomeSecondHand.
  ///
  /// In en, this message translates to:
  /// **'Second-hand-Idle Items-Second-hand Goods'**
  String get categoryIncomeSecondHand;

  /// No description provided for @categoryIncomeSocialBenefit.
  ///
  /// In en, this message translates to:
  /// **'Social Benefit-Unemployment Insurance-Maternity Subsidy-Other Subsidy'**
  String get categoryIncomeSocialBenefit;

  /// No description provided for @categoryIncomeTaxRefund.
  ///
  /// In en, this message translates to:
  /// **'Tax Refund-Individual Tax Refund-Other Refund'**
  String get categoryIncomeTaxRefund;

  /// No description provided for @categoryIncomeProvidentFund.
  ///
  /// In en, this message translates to:
  /// **'Provident Fund-Provident Fund Withdrawal-Provident Fund Interest'**
  String get categoryIncomeProvidentFund;

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

  /// No description provided for @appearanceThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceThemeMode;

  /// No description provided for @appearanceThemeModeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get appearanceThemeModeSystem;

  /// No description provided for @appearanceThemeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get appearanceThemeModeLight;

  /// No description provided for @appearanceThemeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get appearanceThemeModeDark;

  /// No description provided for @appearanceDarkModePattern.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode Header Pattern'**
  String get appearanceDarkModePattern;

  /// No description provided for @appearancePatternNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get appearancePatternNone;

  /// No description provided for @appearancePatternIcons.
  ///
  /// In en, this message translates to:
  /// **'Icon Tiling'**
  String get appearancePatternIcons;

  /// No description provided for @appearancePatternParticles.
  ///
  /// In en, this message translates to:
  /// **'Particles'**
  String get appearancePatternParticles;

  /// No description provided for @appearancePatternHoneycomb.
  ///
  /// In en, this message translates to:
  /// **'Honeycomb'**
  String get appearancePatternHoneycomb;

  /// No description provided for @appearanceAmountFormat.
  ///
  /// In en, this message translates to:
  /// **'Balance Display Format'**
  String get appearanceAmountFormat;

  /// No description provided for @appearanceAmountFormatFull.
  ///
  /// In en, this message translates to:
  /// **'Full Amount'**
  String get appearanceAmountFormatFull;

  /// No description provided for @appearanceAmountFormatFullDesc.
  ///
  /// In en, this message translates to:
  /// **'Show full amount, e.g. 123,456.78'**
  String get appearanceAmountFormatFullDesc;

  /// No description provided for @appearanceAmountFormatCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get appearanceAmountFormatCompact;

  /// No description provided for @appearanceAmountFormatCompactDesc.
  ///
  /// In en, this message translates to:
  /// **'Abbreviate large amounts, e.g. 12.3K (only affects account balance)'**
  String get appearanceAmountFormatCompactDesc;

  /// No description provided for @appearanceShowTransactionTime.
  ///
  /// In en, this message translates to:
  /// **'Show Transaction Time'**
  String get appearanceShowTransactionTime;

  /// No description provided for @appearanceShowTransactionTimeDesc.
  ///
  /// In en, this message translates to:
  /// **'Display time in transaction list, allow time selection when editing'**
  String get appearanceShowTransactionTimeDesc;

  /// No description provided for @appearanceColorScheme.
  ///
  /// In en, this message translates to:
  /// **'Income/Expense Color Scheme'**
  String get appearanceColorScheme;

  /// No description provided for @appearanceColorSchemeOn.
  ///
  /// In en, this message translates to:
  /// **'Red for income · Green for expense'**
  String get appearanceColorSchemeOn;

  /// No description provided for @appearanceColorSchemeOff.
  ///
  /// In en, this message translates to:
  /// **'Red for expense · Green for income'**
  String get appearanceColorSchemeOff;

  /// No description provided for @appearanceColorSchemeOnDesc.
  ///
  /// In en, this message translates to:
  /// **'Red represents income, green represents expense'**
  String get appearanceColorSchemeOnDesc;

  /// No description provided for @appearanceColorSchemeOffDesc.
  ///
  /// In en, this message translates to:
  /// **'Red represents expense, green represents income'**
  String get appearanceColorSchemeOffDesc;

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

  /// No description provided for @commonSelectTime.
  ///
  /// In en, this message translates to:
  /// **'Select Time'**
  String get commonSelectTime;

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

  /// No description provided for @reminderTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Test Notification'**
  String get reminderTestTitle;

  /// No description provided for @reminderTestBody.
  ///
  /// In en, this message translates to:
  /// **'This is a test notification, tap to see the effect'**
  String get reminderTestBody;

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

  /// No description provided for @reminderDescription.
  ///
  /// In en, this message translates to:
  /// **'Tip: When recording reminder is enabled, the system will send notifications at the specified time daily to remind you to record income and expenses.'**
  String get reminderDescription;

  /// No description provided for @reminderIOSInstructions.
  ///
  /// In en, this message translates to:
  /// **'🍎 iOS notification settings:\n• Settings > Notifications > Bee Accounting\n• Enable \"Allow Notifications\"\n• Set notification style: Banner or Alert\n• Enable sound and vibration\n\n⚠️ Important Note:\n• iOS local notifications depend on app process\n• Do not force quit app from task manager\n• Notifications work when app is in background or foreground\n• Force quitting will disable notifications\n\n💡 Usage Tips:\n• Simply press Home button to exit app\n• iOS will manage background apps automatically\n• Keep app in background to receive reminders'**
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

  /// No description provided for @mineImportCompleteAllSuccess.
  ///
  /// In en, this message translates to:
  /// **'All Success'**
  String get mineImportCompleteAllSuccess;

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

  /// No description provided for @cloudTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get cloudTest;

  /// No description provided for @cloudSwitched.
  ///
  /// In en, this message translates to:
  /// **'Switched'**
  String get cloudSwitched;

  /// No description provided for @cloudSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Switch failed'**
  String get cloudSwitchFailed;

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

  /// No description provided for @cloudSelectServiceType.
  ///
  /// In en, this message translates to:
  /// **'Select Cloud Service Type'**
  String get cloudSelectServiceType;

  /// No description provided for @cloudMultiDeviceWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-Device Tips'**
  String get cloudMultiDeviceWarningTitle;

  /// No description provided for @cloudMultiDeviceWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'Upload before switching devices, download on the new device before editing. Don\'t edit the same ledger on two devices at once. Tap for details →'**
  String get cloudMultiDeviceWarningMessage;

  /// No description provided for @cloudWebdavUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Server URL'**
  String get cloudWebdavUrlLabel;

  /// No description provided for @cloudWebdavUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://dav.jianguoyun.com/dav/'**
  String get cloudWebdavUrlHint;

  /// No description provided for @cloudWebdavUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get cloudWebdavUsernameLabel;

  /// No description provided for @cloudWebdavPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get cloudWebdavPasswordLabel;

  /// No description provided for @cloudWebdavPathHint.
  ///
  /// In en, this message translates to:
  /// **'/BeeCount'**
  String get cloudWebdavPathHint;

  /// No description provided for @cloudS3EndpointLabel.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get cloudS3EndpointLabel;

  /// No description provided for @cloudS3EndpointHint.
  ///
  /// In en, this message translates to:
  /// **'s3.amazonaws.com or custom endpoint'**
  String get cloudS3EndpointHint;

  /// No description provided for @cloudS3RegionLabel.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get cloudS3RegionLabel;

  /// No description provided for @cloudS3RegionHint.
  ///
  /// In en, this message translates to:
  /// **'us-east-1 (leave blank for auto)'**
  String get cloudS3RegionHint;

  /// No description provided for @cloudS3AccessKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Access Key'**
  String get cloudS3AccessKeyLabel;

  /// No description provided for @cloudS3AccessKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Your Access Key ID'**
  String get cloudS3AccessKeyHint;

  /// No description provided for @cloudS3SecretKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Secret Key'**
  String get cloudS3SecretKeyLabel;

  /// No description provided for @cloudS3SecretKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Your Secret Access Key'**
  String get cloudS3SecretKeyHint;

  /// No description provided for @cloudS3BucketLabel.
  ///
  /// In en, this message translates to:
  /// **'Bucket Name'**
  String get cloudS3BucketLabel;

  /// No description provided for @cloudS3BucketHint.
  ///
  /// In en, this message translates to:
  /// **'beecount-data'**
  String get cloudS3BucketHint;

  /// No description provided for @cloudS3UseSSLLabel.
  ///
  /// In en, this message translates to:
  /// **'Use HTTPS'**
  String get cloudS3UseSSLLabel;

  /// No description provided for @cloudS3PortLabel.
  ///
  /// In en, this message translates to:
  /// **'Port (optional)'**
  String get cloudS3PortLabel;

  /// No description provided for @cloudS3PortHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank for default'**
  String get cloudS3PortHint;

  /// No description provided for @cloudSupabaseBucketLabel.
  ///
  /// In en, this message translates to:
  /// **'Storage Bucket Name'**
  String get cloudSupabaseBucketLabel;

  /// No description provided for @cloudSupabaseBucketHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank for default: beecount-backups'**
  String get cloudSupabaseBucketHint;

  /// No description provided for @authRememberAccount.
  ///
  /// In en, this message translates to:
  /// **'Remember account'**
  String get authRememberAccount;

  /// No description provided for @authRememberAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Auto-fill on next login (Supabase only)'**
  String get authRememberAccountHint;

  /// No description provided for @cloudConfigSaved.
  ///
  /// In en, this message translates to:
  /// **'Configuration saved'**
  String get cloudConfigSaved;

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

  /// No description provided for @authLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get authLogin;

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

  /// No description provided for @authErrorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password is too simple, please include letters and numbers, at least 6 characters.'**
  String get authErrorWeakPassword;

  /// No description provided for @importSelectCsvFile.
  ///
  /// In en, this message translates to:
  /// **'Please select a file to import (CSV/TSV/XLSX supported)'**
  String get importSelectCsvFile;

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportTitle;

  /// No description provided for @exportDescription.
  ///
  /// In en, this message translates to:
  /// **'Supported export types:\n• Transactions (Income/Expense/Transfer)\n• Categories\n• Accounts\n\nClick the button below to select save location and export current ledger to CSV file.'**
  String get exportDescription;

  /// No description provided for @exportButtonIOS.
  ///
  /// In en, this message translates to:
  /// **'Export and Share'**
  String get exportButtonIOS;

  /// No description provided for @exportButtonAndroid.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get exportButtonAndroid;

  /// No description provided for @exportSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to: {path}'**
  String exportSavedTo(String path);

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

  /// No description provided for @exportCsvHeaderSubCategory.
  ///
  /// In en, this message translates to:
  /// **'Subcategory'**
  String get exportCsvHeaderSubCategory;

  /// No description provided for @exportCsvHeaderAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get exportCsvHeaderAmount;

  /// No description provided for @exportCsvHeaderAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get exportCsvHeaderAccount;

  /// No description provided for @exportCsvHeaderFromAccount.
  ///
  /// In en, this message translates to:
  /// **'From Account'**
  String get exportCsvHeaderFromAccount;

  /// No description provided for @exportCsvHeaderToAccount.
  ///
  /// In en, this message translates to:
  /// **'To Account'**
  String get exportCsvHeaderToAccount;

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

  /// No description provided for @exportCsvHeaderTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get exportCsvHeaderTags;

  /// No description provided for @exportCsvHeaderAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get exportCsvHeaderAttachments;

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

  /// No description provided for @updateDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get updateDownloadFailed;

  /// No description provided for @updateInstallNow.
  ///
  /// In en, this message translates to:
  /// **'Install Now'**
  String get updateInstallNow;

  /// No description provided for @updateNotificationPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Permission Denied'**
  String get updateNotificationPermissionTitle;

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

  /// No description provided for @updateSearchFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Search Failed'**
  String get updateSearchFailedTitle;

  /// No description provided for @updateFoundCachedPackageTitle.
  ///
  /// In en, this message translates to:
  /// **'Found Downloaded Update Package'**
  String get updateFoundCachedPackageTitle;

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

  /// No description provided for @updateCheckingUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Update check failed: {error}'**
  String updateCheckingUpdateError(String error);

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

  /// No description provided for @updateMirrorSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Download Accelerator'**
  String get updateMirrorSelectTitle;

  /// No description provided for @updateMirrorSelectHint.
  ///
  /// In en, this message translates to:
  /// **'If download is slow, select an accelerated mirror. Click \"Test\" to check latency.'**
  String get updateMirrorSelectHint;

  /// No description provided for @updateMirrorTestButton.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get updateMirrorTestButton;

  /// No description provided for @updateMirrorTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing {completed}/{total}...'**
  String updateMirrorTesting(int completed, int total);

  /// No description provided for @updateMirrorDirectHint.
  ///
  /// In en, this message translates to:
  /// **'For users with good network'**
  String get updateMirrorDirectHint;

  /// No description provided for @updateDownloadMirror.
  ///
  /// In en, this message translates to:
  /// **'Source: {mirror}'**
  String updateDownloadMirror(String mirror);

  /// No description provided for @updateMirrorSettingTitle.
  ///
  /// In en, this message translates to:
  /// **'Download Accelerator'**
  String get updateMirrorSettingTitle;

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

  /// No description provided for @currencyMYR.
  ///
  /// In en, this message translates to:
  /// **'Malaysian Ringgit'**
  String get currencyMYR;

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

  /// No description provided for @currencyPHP.
  ///
  /// In en, this message translates to:
  /// **'Philippine Peso'**
  String get currencyPHP;

  /// No description provided for @currencyVND.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese Dong'**
  String get currencyVND;

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

  /// No description provided for @currencyBYN.
  ///
  /// In en, this message translates to:
  /// **'Belarusian Ruble'**
  String get currencyBYN;

  /// No description provided for @currencyNZD.
  ///
  /// In en, this message translates to:
  /// **'New Zealand Dollar'**
  String get currencyNZD;

  /// No description provided for @currencyCHF.
  ///
  /// In en, this message translates to:
  /// **'Swiss Franc'**
  String get currencyCHF;

  /// No description provided for @currencySEK.
  ///
  /// In en, this message translates to:
  /// **'Swedish Krona'**
  String get currencySEK;

  /// No description provided for @currencyNOK.
  ///
  /// In en, this message translates to:
  /// **'Norwegian Krone'**
  String get currencyNOK;

  /// No description provided for @currencyDKK.
  ///
  /// In en, this message translates to:
  /// **'Danish Krone'**
  String get currencyDKK;

  /// No description provided for @currencyBRL.
  ///
  /// In en, this message translates to:
  /// **'Brazilian Real'**
  String get currencyBRL;

  /// No description provided for @currencyMXN.
  ///
  /// In en, this message translates to:
  /// **'Mexican Peso'**
  String get currencyMXN;

  /// No description provided for @currencyTRY.
  ///
  /// In en, this message translates to:
  /// **'Turkish Lira'**
  String get currencyTRY;

  /// No description provided for @currencyZAR.
  ///
  /// In en, this message translates to:
  /// **'South African Rand'**
  String get currencyZAR;

  /// No description provided for @currencyAED.
  ///
  /// In en, this message translates to:
  /// **'UAE Dirham'**
  String get currencyAED;

  /// No description provided for @currencySAR.
  ///
  /// In en, this message translates to:
  /// **'Saudi Riyal'**
  String get currencySAR;

  /// No description provided for @currencyPLN.
  ///
  /// In en, this message translates to:
  /// **'Polish Zloty'**
  String get currencyPLN;

  /// No description provided for @currencyCZK.
  ///
  /// In en, this message translates to:
  /// **'Czech Koruna'**
  String get currencyCZK;

  /// No description provided for @currencyHUF.
  ///
  /// In en, this message translates to:
  /// **'Hungarian Forint'**
  String get currencyHUF;

  /// No description provided for @currencyARS.
  ///
  /// In en, this message translates to:
  /// **'Argentine Peso'**
  String get currencyARS;

  /// No description provided for @currencyCLP.
  ///
  /// In en, this message translates to:
  /// **'Chilean Peso'**
  String get currencyCLP;

  /// No description provided for @currencyCOP.
  ///
  /// In en, this message translates to:
  /// **'Colombian Peso'**
  String get currencyCOP;

  /// No description provided for @currencyPEN.
  ///
  /// In en, this message translates to:
  /// **'Peruvian Sol'**
  String get currencyPEN;

  /// No description provided for @currencyEGP.
  ///
  /// In en, this message translates to:
  /// **'Egyptian Pound'**
  String get currencyEGP;

  /// No description provided for @currencyNGN.
  ///
  /// In en, this message translates to:
  /// **'Nigerian Naira'**
  String get currencyNGN;

  /// No description provided for @currencyKZT.
  ///
  /// In en, this message translates to:
  /// **'Kazakhstani Tenge'**
  String get currencyKZT;

  /// No description provided for @currencyUAH.
  ///
  /// In en, this message translates to:
  /// **'Ukrainian Hryvnia'**
  String get currencyUAH;

  /// No description provided for @currencyILS.
  ///
  /// In en, this message translates to:
  /// **'Israeli New Shekel'**
  String get currencyILS;

  /// No description provided for @currencyPKR.
  ///
  /// In en, this message translates to:
  /// **'Pakistani Rupee'**
  String get currencyPKR;

  /// No description provided for @currencyBDT.
  ///
  /// In en, this message translates to:
  /// **'Bangladeshi Taka'**
  String get currencyBDT;

  /// No description provided for @currencyLKR.
  ///
  /// In en, this message translates to:
  /// **'Sri Lankan Rupee'**
  String get currencyLKR;

  /// No description provided for @currencyMMK.
  ///
  /// In en, this message translates to:
  /// **'Myanmar Kyat'**
  String get currencyMMK;

  /// No description provided for @webdavConfiguredTitle.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Cloud Service Configured'**
  String get webdavConfiguredTitle;

  /// No description provided for @webdavConfiguredMessage.
  ///
  /// In en, this message translates to:
  /// **'WebDAV cloud service uses the credentials provided during configuration, no additional login required.'**
  String get webdavConfiguredMessage;

  /// No description provided for @recurringTransactionTitle.
  ///
  /// In en, this message translates to:
  /// **'Recurring Bills'**
  String get recurringTransactionTitle;

  /// No description provided for @recurringTransactionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Recurring Bill'**
  String get recurringTransactionAdd;

  /// No description provided for @recurringTransactionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Recurring Bill'**
  String get recurringTransactionEdit;

  /// No description provided for @recurringTransactionFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get recurringTransactionFrequency;

  /// No description provided for @recurringTransactionDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get recurringTransactionDaily;

  /// No description provided for @recurringTransactionWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get recurringTransactionWeekly;

  /// No description provided for @recurringTransactionMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get recurringTransactionMonthly;

  /// No description provided for @recurringTransactionYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get recurringTransactionYearly;

  /// No description provided for @recurringTransactionInterval.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get recurringTransactionInterval;

  /// No description provided for @recurringTransactionDayOfMonth.
  ///
  /// In en, this message translates to:
  /// **'Day of Month'**
  String get recurringTransactionDayOfMonth;

  /// No description provided for @recurringTransactionStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get recurringTransactionStartDate;

  /// No description provided for @recurringTransactionEndDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get recurringTransactionEndDate;

  /// No description provided for @recurringTransactionNoEndDate.
  ///
  /// In en, this message translates to:
  /// **'Perpetual'**
  String get recurringTransactionNoEndDate;

  /// No description provided for @recurringTransactionDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this recurring bill?'**
  String get recurringTransactionDeleteConfirm;

  /// No description provided for @recurringTransactionEmpty.
  ///
  /// In en, this message translates to:
  /// **'No Recurring Bills'**
  String get recurringTransactionEmpty;

  /// No description provided for @recurringTransactionEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button in the top right corner to add'**
  String get recurringTransactionEmptyHint;

  /// No description provided for @recurringTransactionEveryNDays.
  ///
  /// In en, this message translates to:
  /// **'Every {n} day(s)'**
  String recurringTransactionEveryNDays(int n);

  /// No description provided for @recurringTransactionEveryNWeeks.
  ///
  /// In en, this message translates to:
  /// **'Every {n} week(s)'**
  String recurringTransactionEveryNWeeks(int n);

  /// No description provided for @recurringTransactionEveryNMonths.
  ///
  /// In en, this message translates to:
  /// **'Every {n} month(s)'**
  String recurringTransactionEveryNMonths(int n);

  /// No description provided for @recurringTransactionEveryNYears.
  ///
  /// In en, this message translates to:
  /// **'Every {n} year(s)'**
  String recurringTransactionEveryNYears(int n);

  /// No description provided for @recurringTransactionUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage Guide'**
  String get recurringTransactionUsageTitle;

  /// No description provided for @recurringTransactionUsageContent.
  ///
  /// In en, this message translates to:
  /// **'Recurring transactions are automatically scanned and generated when the app cold starts. After setting a date, the system will create corresponding bills on the first startup after that date. For example: if set to Nov 27, bills will be auto-recorded on the first launch after Nov 27.'**
  String get recurringTransactionUsageContent;

  /// No description provided for @ledgerSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Ledger'**
  String get ledgerSelectTitle;

  /// No description provided for @ledgerSelect.
  ///
  /// In en, this message translates to:
  /// **'Select Ledger'**
  String get ledgerSelect;

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

  /// No description provided for @cloudTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get cloudTestConnection;

  /// No description provided for @cloudLocalStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Local Storage'**
  String get cloudLocalStorageTitle;

  /// No description provided for @cloudLocalStorageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Data is only saved on local device'**
  String get cloudLocalStorageSubtitle;

  /// No description provided for @cloudCustomSupabaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Supabase'**
  String get cloudCustomSupabaseTitle;

  /// No description provided for @cloudCustomSupabaseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Click to configure self-hosted Supabase'**
  String get cloudCustomSupabaseSubtitle;

  /// No description provided for @cloudCustomWebdavTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom WebDAV'**
  String get cloudCustomWebdavTitle;

  /// No description provided for @cloudCustomWebdavSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Click to configure Nutstore/Nextcloud etc.'**
  String get cloudCustomWebdavSubtitle;

  /// No description provided for @cloudCustomS3Title.
  ///
  /// In en, this message translates to:
  /// **'S3 Protocol Storage'**
  String get cloudCustomS3Title;

  /// No description provided for @cloudCustomS3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'AWS S3 / Cloudflare R2 / MinIO'**
  String get cloudCustomS3Subtitle;

  /// No description provided for @cloudBeeCountCloudTitle.
  ///
  /// In en, this message translates to:
  /// **'BeeCount Cloud'**
  String get cloudBeeCountCloudTitle;

  /// No description provided for @cloudBeeCountCloudSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Self-hosted · Incremental sync · Multi-device'**
  String get cloudBeeCountCloudSubtitle;

  /// No description provided for @cloudConfigureBeeCountCloudTitle.
  ///
  /// In en, this message translates to:
  /// **'Configure BeeCount Cloud'**
  String get cloudConfigureBeeCountCloudTitle;

  /// No description provided for @cloudBeeCountCloudUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get cloudBeeCountCloudUrlLabel;

  /// No description provided for @cloudBeeCountCloudUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://your-server.com'**
  String get cloudBeeCountCloudUrlHint;

  /// No description provided for @cloudBeeCountCloudApiPrefixLabel.
  ///
  /// In en, this message translates to:
  /// **'API Prefix'**
  String get cloudBeeCountCloudApiPrefixLabel;

  /// No description provided for @cloudBeeCountCloudApiPrefixHint.
  ///
  /// In en, this message translates to:
  /// **'/api/v1'**
  String get cloudBeeCountCloudApiPrefixHint;

  /// No description provided for @cloudBeeCountCloudEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get cloudBeeCountCloudEmailLabel;

  /// No description provided for @cloudBeeCountCloudEmailHint.
  ///
  /// In en, this message translates to:
  /// **'your@email.com'**
  String get cloudBeeCountCloudEmailHint;

  /// No description provided for @cloudBeeCountCloudPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get cloudBeeCountCloudPasswordLabel;

  /// No description provided for @cloudBeeCountCloudPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get cloudBeeCountCloudPasswordHint;

  /// No description provided for @cloudBeeCountCloudLoginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Login successful'**
  String get cloudBeeCountCloudLoginSuccess;

  /// No description provided for @cloudBeeCountCloudLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get cloudBeeCountCloudLoginFailed;

  /// No description provided for @cloudBeeCountCloudSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Incremental sync · Multi-device'**
  String get cloudBeeCountCloudSyncSubtitle;

  /// No description provided for @cloudBeeCountCloudConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get cloudBeeCountCloudConnected;

  /// No description provided for @cloudBeeCountCloudNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get cloudBeeCountCloudNotConnected;

  /// No description provided for @cloudBeeCountCloudNotConnectedHint.
  ///
  /// In en, this message translates to:
  /// **'Configure and login in cloud service settings'**
  String get cloudBeeCountCloudNotConnectedHint;

  /// No description provided for @cloudBeeCountCloudAutoSync.
  ///
  /// In en, this message translates to:
  /// **'Incremental Sync'**
  String get cloudBeeCountCloudAutoSync;

  /// No description provided for @cloudBeeCountCloudAutoSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Changes sync to cloud automatically'**
  String get cloudBeeCountCloudAutoSyncHint;

  /// No description provided for @cloudBeeCountCloudMultiDevice.
  ///
  /// In en, this message translates to:
  /// **'Multi-device Sync'**
  String get cloudBeeCountCloudMultiDevice;

  /// No description provided for @cloudBeeCountCloudMultiDeviceHint.
  ///
  /// In en, this message translates to:
  /// **'Keep data consistent across devices'**
  String get cloudBeeCountCloudMultiDeviceHint;

  /// No description provided for @cloudBeeCountCloudAttachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment Sync'**
  String get cloudBeeCountCloudAttachment;

  /// No description provided for @cloudBeeCountCloudAttachmentHint.
  ///
  /// In en, this message translates to:
  /// **'Receipt images backed up to cloud automatically'**
  String get cloudBeeCountCloudAttachmentHint;

  /// No description provided for @cloudTabOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get cloudTabOffline;

  /// No description provided for @cloudTabBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get cloudTabBackup;

  /// No description provided for @cloudTabCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get cloudTabCloudSync;

  /// No description provided for @cloudIcloudSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto sync with Apple ID'**
  String get cloudIcloudSubtitle;

  /// No description provided for @cloudIcloudNotAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'iCloud Not Available'**
  String get cloudIcloudNotAvailableTitle;

  /// No description provided for @cloudIcloudNotAvailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to iCloud in Settings and try again'**
  String get cloudIcloudNotAvailableMessage;

  /// No description provided for @cloudIcloudHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'iCloud Instructions'**
  String get cloudIcloudHelpTitle;

  /// No description provided for @cloudIcloudHelpPrerequisites.
  ///
  /// In en, this message translates to:
  /// **'Prerequisites'**
  String get cloudIcloudHelpPrerequisites;

  /// No description provided for @cloudIcloudHelpPrereq1.
  ///
  /// In en, this message translates to:
  /// **'1. Device is signed in with Apple ID'**
  String get cloudIcloudHelpPrereq1;

  /// No description provided for @cloudIcloudHelpPrereq2.
  ///
  /// In en, this message translates to:
  /// **'2. iCloud Drive is enabled'**
  String get cloudIcloudHelpPrereq2;

  /// No description provided for @cloudIcloudHelpPrereq3.
  ///
  /// In en, this message translates to:
  /// **'3. Device is connected to internet'**
  String get cloudIcloudHelpPrereq3;

  /// No description provided for @cloudIcloudHelpCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'How to Check iCloud Drive'**
  String get cloudIcloudHelpCheckTitle;

  /// No description provided for @cloudIcloudHelpCheck1.
  ///
  /// In en, this message translates to:
  /// **'1. Open Settings'**
  String get cloudIcloudHelpCheck1;

  /// No description provided for @cloudIcloudHelpCheck2.
  ///
  /// In en, this message translates to:
  /// **'2. Tap your Apple ID at the top'**
  String get cloudIcloudHelpCheck2;

  /// No description provided for @cloudIcloudHelpCheck3.
  ///
  /// In en, this message translates to:
  /// **'3. Tap iCloud'**
  String get cloudIcloudHelpCheck3;

  /// No description provided for @cloudIcloudHelpCheck4.
  ///
  /// In en, this message translates to:
  /// **'4. Make sure iCloud Drive is enabled'**
  String get cloudIcloudHelpCheck4;

  /// No description provided for @cloudIcloudHelpFaqTitle.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get cloudIcloudHelpFaqTitle;

  /// No description provided for @cloudIcloudHelpFaq1.
  ///
  /// In en, this message translates to:
  /// **'If not available, check if iCloud Drive is enabled'**
  String get cloudIcloudHelpFaq1;

  /// No description provided for @cloudIcloudHelpFaq2.
  ///
  /// In en, this message translates to:
  /// **'First time use may take a few seconds to initialize'**
  String get cloudIcloudHelpFaq2;

  /// No description provided for @cloudIcloudHelpFaq3.
  ///
  /// In en, this message translates to:
  /// **'Data is stored in your private iCloud space'**
  String get cloudIcloudHelpFaq3;

  /// No description provided for @cloudIcloudHelpFaq4.
  ///
  /// In en, this message translates to:
  /// **'Devices with same Apple ID sync automatically'**
  String get cloudIcloudHelpFaq4;

  /// No description provided for @cloudIcloudHelpNote.
  ///
  /// In en, this message translates to:
  /// **'iCloud sync uses your Apple ID, no extra configuration needed'**
  String get cloudIcloudHelpNote;

  /// No description provided for @cloudSupabaseHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Supabase Setup Guide'**
  String get cloudSupabaseHelpTitle;

  /// No description provided for @cloudSupabaseHelpIntro.
  ///
  /// In en, this message translates to:
  /// **'What is Supabase'**
  String get cloudSupabaseHelpIntro;

  /// No description provided for @cloudSupabaseHelpIntro1.
  ///
  /// In en, this message translates to:
  /// **'Supabase is an open-source backend-as-a-service platform'**
  String get cloudSupabaseHelpIntro1;

  /// No description provided for @cloudSupabaseHelpIntro2.
  ///
  /// In en, this message translates to:
  /// **'Offers a free tier, sufficient for personal use'**
  String get cloudSupabaseHelpIntro2;

  /// No description provided for @cloudSupabaseHelpIntro3.
  ///
  /// In en, this message translates to:
  /// **'You have full control over your data'**
  String get cloudSupabaseHelpIntro3;

  /// No description provided for @cloudSupabaseHelpSteps.
  ///
  /// In en, this message translates to:
  /// **'Setup Steps'**
  String get cloudSupabaseHelpSteps;

  /// No description provided for @cloudSupabaseHelpStep1.
  ///
  /// In en, this message translates to:
  /// **'1. Visit supabase.com to create an account'**
  String get cloudSupabaseHelpStep1;

  /// No description provided for @cloudSupabaseHelpStep2.
  ///
  /// In en, this message translates to:
  /// **'2. Create a new project (select free tier)'**
  String get cloudSupabaseHelpStep2;

  /// No description provided for @cloudSupabaseHelpStep3.
  ///
  /// In en, this message translates to:
  /// **'3. Go to Project Settings > API'**
  String get cloudSupabaseHelpStep3;

  /// No description provided for @cloudSupabaseHelpStep4.
  ///
  /// In en, this message translates to:
  /// **'4. Copy Project URL and anon key'**
  String get cloudSupabaseHelpStep4;

  /// No description provided for @cloudSupabaseHelpStep5.
  ///
  /// In en, this message translates to:
  /// **'5. Paste them into the app configuration'**
  String get cloudSupabaseHelpStep5;

  /// No description provided for @cloudSupabaseHelpFaq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get cloudSupabaseHelpFaq;

  /// No description provided for @cloudSupabaseHelpFaq1.
  ///
  /// In en, this message translates to:
  /// **'Free tier includes 500MB storage'**
  String get cloudSupabaseHelpFaq1;

  /// No description provided for @cloudSupabaseHelpFaq2.
  ///
  /// In en, this message translates to:
  /// **'Data is encrypted and secure'**
  String get cloudSupabaseHelpFaq2;

  /// No description provided for @cloudSupabaseHelpFaq3.
  ///
  /// In en, this message translates to:
  /// **'Supports multi-device sync'**
  String get cloudSupabaseHelpFaq3;

  /// No description provided for @cloudSupabaseHelpNote.
  ///
  /// In en, this message translates to:
  /// **'After configuration, you need to register/login to use sync'**
  String get cloudSupabaseHelpNote;

  /// No description provided for @cloudDetailedTutorial.
  ///
  /// In en, this message translates to:
  /// **'Detailed Tutorial'**
  String get cloudDetailedTutorial;

  /// No description provided for @cloudWebdavHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Setup Guide'**
  String get cloudWebdavHelpTitle;

  /// No description provided for @cloudWebdavHelpIntro.
  ///
  /// In en, this message translates to:
  /// **'What is WebDAV'**
  String get cloudWebdavHelpIntro;

  /// No description provided for @cloudWebdavHelpIntro1.
  ///
  /// In en, this message translates to:
  /// **'WebDAV is a network file protocol'**
  String get cloudWebdavHelpIntro1;

  /// No description provided for @cloudWebdavHelpIntro2.
  ///
  /// In en, this message translates to:
  /// **'Supported by many cloud storage and NAS devices'**
  String get cloudWebdavHelpIntro2;

  /// No description provided for @cloudWebdavHelpIntro3.
  ///
  /// In en, this message translates to:
  /// **'Data is stored on your own server'**
  String get cloudWebdavHelpIntro3;

  /// No description provided for @cloudWebdavHelpProviders.
  ///
  /// In en, this message translates to:
  /// **'Supported Providers'**
  String get cloudWebdavHelpProviders;

  /// No description provided for @cloudWebdavHelpProvider1.
  ///
  /// In en, this message translates to:
  /// **'- Nutstore (recommended for China users)'**
  String get cloudWebdavHelpProvider1;

  /// No description provided for @cloudWebdavHelpProvider2.
  ///
  /// In en, this message translates to:
  /// **'- Nextcloud / ownCloud'**
  String get cloudWebdavHelpProvider2;

  /// No description provided for @cloudWebdavHelpProvider3.
  ///
  /// In en, this message translates to:
  /// **'- Synology / QNAP NAS'**
  String get cloudWebdavHelpProvider3;

  /// No description provided for @cloudWebdavHelpProvider4.
  ///
  /// In en, this message translates to:
  /// **'- Other WebDAV-compatible services'**
  String get cloudWebdavHelpProvider4;

  /// No description provided for @cloudWebdavHelpSteps.
  ///
  /// In en, this message translates to:
  /// **'Setup Steps (Nutstore example)'**
  String get cloudWebdavHelpSteps;

  /// No description provided for @cloudWebdavHelpStep1.
  ///
  /// In en, this message translates to:
  /// **'1. Login to Nutstore web version'**
  String get cloudWebdavHelpStep1;

  /// No description provided for @cloudWebdavHelpStep2.
  ///
  /// In en, this message translates to:
  /// **'2. Click account name > Account Info'**
  String get cloudWebdavHelpStep2;

  /// No description provided for @cloudWebdavHelpStep3.
  ///
  /// In en, this message translates to:
  /// **'3. Select Security Options tab'**
  String get cloudWebdavHelpStep3;

  /// No description provided for @cloudWebdavHelpStep4.
  ///
  /// In en, this message translates to:
  /// **'4. Add application password (for third-party apps)'**
  String get cloudWebdavHelpStep4;

  /// No description provided for @cloudWebdavHelpStep5.
  ///
  /// In en, this message translates to:
  /// **'5. Copy server address, account, and app password'**
  String get cloudWebdavHelpStep5;

  /// No description provided for @cloudWebdavHelpNote.
  ///
  /// In en, this message translates to:
  /// **'Use an app-specific password instead of your account password'**
  String get cloudWebdavHelpNote;

  /// No description provided for @cloudS3HelpTitle.
  ///
  /// In en, this message translates to:
  /// **'S3 Storage Setup Guide'**
  String get cloudS3HelpTitle;

  /// No description provided for @cloudS3HelpIntro.
  ///
  /// In en, this message translates to:
  /// **'What is S3'**
  String get cloudS3HelpIntro;

  /// No description provided for @cloudS3HelpIntro1.
  ///
  /// In en, this message translates to:
  /// **'S3 is a standard object storage protocol'**
  String get cloudS3HelpIntro1;

  /// No description provided for @cloudS3HelpIntro2.
  ///
  /// In en, this message translates to:
  /// **'Supported by many cloud providers'**
  String get cloudS3HelpIntro2;

  /// No description provided for @cloudS3HelpIntro3.
  ///
  /// In en, this message translates to:
  /// **'Data is stored on your chosen cloud service'**
  String get cloudS3HelpIntro3;

  /// No description provided for @cloudS3HelpProviders.
  ///
  /// In en, this message translates to:
  /// **'Supported Providers'**
  String get cloudS3HelpProviders;

  /// No description provided for @cloudS3HelpProvider1.
  ///
  /// In en, this message translates to:
  /// **'- AWS S3 (Amazon Web Services)'**
  String get cloudS3HelpProvider1;

  /// No description provided for @cloudS3HelpProvider2.
  ///
  /// In en, this message translates to:
  /// **'- Cloudflare R2 (free 10GB/month)'**
  String get cloudS3HelpProvider2;

  /// No description provided for @cloudS3HelpProvider3.
  ///
  /// In en, this message translates to:
  /// **'- Backblaze B2 (free 10GB)'**
  String get cloudS3HelpProvider3;

  /// No description provided for @cloudS3HelpProvider4.
  ///
  /// In en, this message translates to:
  /// **'- MinIO (self-hosted)'**
  String get cloudS3HelpProvider4;

  /// No description provided for @cloudS3HelpProvider5.
  ///
  /// In en, this message translates to:
  /// **'- Alibaba Cloud OSS'**
  String get cloudS3HelpProvider5;

  /// No description provided for @cloudS3HelpProvider6.
  ///
  /// In en, this message translates to:
  /// **'- Tencent Cloud COS'**
  String get cloudS3HelpProvider6;

  /// No description provided for @cloudS3HelpProvider7.
  ///
  /// In en, this message translates to:
  /// **'- Qiniu Kodo'**
  String get cloudS3HelpProvider7;

  /// No description provided for @cloudS3HelpSteps.
  ///
  /// In en, this message translates to:
  /// **'Setup Steps (Cloudflare R2 example)'**
  String get cloudS3HelpSteps;

  /// No description provided for @cloudS3HelpStep1.
  ///
  /// In en, this message translates to:
  /// **'1. Login to Cloudflare Dashboard'**
  String get cloudS3HelpStep1;

  /// No description provided for @cloudS3HelpStep2.
  ///
  /// In en, this message translates to:
  /// **'2. Go to R2 > Create Bucket'**
  String get cloudS3HelpStep2;

  /// No description provided for @cloudS3HelpStep3.
  ///
  /// In en, this message translates to:
  /// **'3. Go to R2 > Manage R2 API Tokens'**
  String get cloudS3HelpStep3;

  /// No description provided for @cloudS3HelpStep4.
  ///
  /// In en, this message translates to:
  /// **'4. Create API Token and copy credentials'**
  String get cloudS3HelpStep4;

  /// No description provided for @cloudS3HelpStep5.
  ///
  /// In en, this message translates to:
  /// **'5. Paste endpoint, access key, secret key, and bucket name'**
  String get cloudS3HelpStep5;

  /// No description provided for @cloudS3HelpNote.
  ///
  /// In en, this message translates to:
  /// **'Recommended: Cloudflare R2 offers 10GB free storage without egress fees'**
  String get cloudS3HelpNote;

  /// No description provided for @cloudStatusNotTested.
  ///
  /// In en, this message translates to:
  /// **'Not tested'**
  String get cloudStatusNotTested;

  /// No description provided for @cloudStatusNormal.
  ///
  /// In en, this message translates to:
  /// **'Connection normal'**
  String get cloudStatusNormal;

  /// No description provided for @cloudStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get cloudStatusFailed;

  /// No description provided for @cloudCannotOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Cannot open link'**
  String get cloudCannotOpenLink;

  /// No description provided for @cloudErrorAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed: Invalid API Key'**
  String get cloudErrorAuthFailed;

  /// No description provided for @cloudErrorServerStatus.
  ///
  /// In en, this message translates to:
  /// **'Server returned status code {code}'**
  String cloudErrorServerStatus(String code);

  /// No description provided for @cloudErrorWebdavNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Server does not support WebDAV protocol'**
  String get cloudErrorWebdavNotSupported;

  /// No description provided for @cloudErrorAuthFailedCredentials.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed: Incorrect username or password'**
  String get cloudErrorAuthFailedCredentials;

  /// No description provided for @cloudErrorAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access denied: Please check permissions'**
  String get cloudErrorAccessDenied;

  /// No description provided for @cloudErrorPathNotFound.
  ///
  /// In en, this message translates to:
  /// **'Server path not found: {path}'**
  String cloudErrorPathNotFound(String path);

  /// No description provided for @cloudErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error: {message}'**
  String cloudErrorNetwork(String message);

  /// No description provided for @cloudTestSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Test Successful'**
  String get cloudTestSuccessTitle;

  /// No description provided for @cloudTestSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Connection normal, configuration valid'**
  String get cloudTestSuccessMessage;

  /// No description provided for @cloudTestFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Test Failed'**
  String get cloudTestFailedTitle;

  /// No description provided for @cloudTestFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get cloudTestFailedMessage;

  /// No description provided for @cloudTestErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Test Error'**
  String get cloudTestErrorTitle;

  /// No description provided for @cloudSwitchConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch Cloud Service'**
  String get cloudSwitchConfirmTitle;

  /// No description provided for @cloudSwitchConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Switching cloud service will log out current account. Confirm switch?'**
  String get cloudSwitchConfirmMessage;

  /// No description provided for @cloudSwitchFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch Failed'**
  String get cloudSwitchFailedTitle;

  /// No description provided for @cloudSwitchFailedConfigMissing.
  ///
  /// In en, this message translates to:
  /// **'Please configure this cloud service first'**
  String get cloudSwitchFailedConfigMissing;

  /// No description provided for @cloudConfigInvalidTitle.
  ///
  /// In en, this message translates to:
  /// **'Invalid Configuration'**
  String get cloudConfigInvalidTitle;

  /// No description provided for @cloudConfigInvalidMessage.
  ///
  /// In en, this message translates to:
  /// **'Please fill in complete information'**
  String get cloudConfigInvalidMessage;

  /// No description provided for @cloudSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save Failed'**
  String get cloudSaveFailed;

  /// No description provided for @cloudSwitchedTo.
  ///
  /// In en, this message translates to:
  /// **'Switched to {type}'**
  String cloudSwitchedTo(String type);

  /// No description provided for @cloudConfigureSupabaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Configure Supabase'**
  String get cloudConfigureSupabaseTitle;

  /// No description provided for @cloudConfigureWebdavTitle.
  ///
  /// In en, this message translates to:
  /// **'Configure WebDAV'**
  String get cloudConfigureWebdavTitle;

  /// No description provided for @cloudConfigureS3Title.
  ///
  /// In en, this message translates to:
  /// **'Configure S3'**
  String get cloudConfigureS3Title;

  /// No description provided for @cloudSupabaseAnonKeyHintLong.
  ///
  /// In en, this message translates to:
  /// **'Paste complete anon key'**
  String get cloudSupabaseAnonKeyHintLong;

  /// No description provided for @cloudWebdavRemotePathHelp.
  ///
  /// In en, this message translates to:
  /// **'Remote directory path for data storage'**
  String get cloudWebdavRemotePathHelp;

  /// No description provided for @cloudWebdavRemotePathLabel.
  ///
  /// In en, this message translates to:
  /// **'Remote Path'**
  String get cloudWebdavRemotePathLabel;

  /// No description provided for @cloudWebdavRemotePathHelperText.
  ///
  /// In en, this message translates to:
  /// **'Remote directory path for data storage'**
  String get cloudWebdavRemotePathHelperText;

  /// No description provided for @accountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Asset Management'**
  String get accountsTitle;

  /// No description provided for @accountsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet, tap the top right to add'**
  String get accountsEmptyMessage;

  /// No description provided for @accountAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get accountAddTooltip;

  /// No description provided for @accountAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get accountAddButton;

  /// No description provided for @accountBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get accountBalance;

  /// No description provided for @accountEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Account'**
  String get accountEditTitle;

  /// No description provided for @accountNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Account'**
  String get accountNewTitle;

  /// No description provided for @accountNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Account Name'**
  String get accountNameLabel;

  /// No description provided for @accountNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g.: ICBC, Alipay, etc.'**
  String get accountNameHint;

  /// No description provided for @accountNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter account name'**
  String get accountNameRequired;

  /// No description provided for @accountNameDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Account name already exists, please use a different name'**
  String get accountNameDuplicate;

  /// No description provided for @accountTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Account Type'**
  String get accountTypeLabel;

  /// No description provided for @accountTypeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get accountTypeCash;

  /// No description provided for @accountTypeBankCard.
  ///
  /// In en, this message translates to:
  /// **'Bank Card'**
  String get accountTypeBankCard;

  /// No description provided for @accountTypeCreditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit Card'**
  String get accountTypeCreditCard;

  /// No description provided for @accountTypeAlipay.
  ///
  /// In en, this message translates to:
  /// **'Alipay'**
  String get accountTypeAlipay;

  /// No description provided for @accountTypeWechat.
  ///
  /// In en, this message translates to:
  /// **'WeChat'**
  String get accountTypeWechat;

  /// No description provided for @accountTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get accountTypeOther;

  /// No description provided for @accountInitialBalance.
  ///
  /// In en, this message translates to:
  /// **'Initial Balance'**
  String get accountInitialBalance;

  /// No description provided for @accountInitialBalanceHint.
  ///
  /// In en, this message translates to:
  /// **'Enter initial balance (optional)'**
  String get accountInitialBalanceHint;

  /// No description provided for @accountDeleteWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get accountDeleteWarningTitle;

  /// No description provided for @accountDeleteWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'This account has {count} related transactions. After deletion, account information in transaction records will be cleared. Confirm deletion?'**
  String accountDeleteWarningMessage(int count);

  /// No description provided for @accountDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm to delete this account?'**
  String get accountDeleteConfirm;

  /// No description provided for @accountSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Account'**
  String get accountSelectTitle;

  /// No description provided for @accountNone.
  ///
  /// In en, this message translates to:
  /// **'No Account'**
  String get accountNone;

  /// No description provided for @accountsEnableFeature.
  ///
  /// In en, this message translates to:
  /// **'Enable Account Feature'**
  String get accountsEnableFeature;

  /// No description provided for @privacyOpenSourceUrlError.
  ///
  /// In en, this message translates to:
  /// **'Cannot open link'**
  String get privacyOpenSourceUrlError;

  /// No description provided for @updateCorruptedFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Corrupted Installation Package'**
  String get updateCorruptedFileTitle;

  /// No description provided for @updateCorruptedFileMessage.
  ///
  /// In en, this message translates to:
  /// **'The previously downloaded installation package is incomplete or corrupted. Delete and re-download?'**
  String get updateCorruptedFileMessage;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to BeeCount'**
  String get welcomeTitle;

  /// No description provided for @welcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'An accounting app that truly respects your privacy'**
  String get welcomeDescription;

  /// No description provided for @welcomeCurrencyDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred currency, you can change it anytime in settings'**
  String get welcomeCurrencyDescription;

  /// No description provided for @welcomeCreateDefaultLedger.
  ///
  /// In en, this message translates to:
  /// **'Create a default ledger'**
  String get welcomeCreateDefaultLedger;

  /// No description provided for @welcomePrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Source · Community Driven'**
  String get welcomePrivacyTitle;

  /// No description provided for @welcomePrivacyFeature1.
  ///
  /// In en, this message translates to:
  /// **'100% open source code, supervised by community'**
  String get welcomePrivacyFeature1;

  /// No description provided for @welcomePrivacyFeature2.
  ///
  /// In en, this message translates to:
  /// **'No privacy concerns, data stored locally'**
  String get welcomePrivacyFeature2;

  /// No description provided for @welcomeOpenSourceFeature1.
  ///
  /// In en, this message translates to:
  /// **'Active developer community, continuous improvement'**
  String get welcomeOpenSourceFeature1;

  /// No description provided for @welcomeViewGitHub.
  ///
  /// In en, this message translates to:
  /// **'Visit GitHub Repository'**
  String get welcomeViewGitHub;

  /// No description provided for @welcomeCloudSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Optional Cloud Sync'**
  String get welcomeCloudSyncTitle;

  /// No description provided for @welcomeCloudSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'BeeCount supports multiple sync methods - your data, your control'**
  String get welcomeCloudSyncDescription;

  /// No description provided for @welcomeCloudSyncFeature1.
  ///
  /// In en, this message translates to:
  /// **'Completely offline usage, no cloud needed'**
  String get welcomeCloudSyncFeature1;

  /// No description provided for @welcomeCloudSyncFeature2.
  ///
  /// In en, this message translates to:
  /// **'BeeCount Cloud self-hosted (real-time multi-device + Web UI)'**
  String get welcomeCloudSyncFeature2;

  /// No description provided for @welcomeCloudSyncFeature3.
  ///
  /// In en, this message translates to:
  /// **'Or pick iCloud / WebDAV / Supabase / S3'**
  String get welcomeCloudSyncFeature3;

  /// No description provided for @widgetManagement.
  ///
  /// In en, this message translates to:
  /// **'Home Screen Widget'**
  String get widgetManagement;

  /// No description provided for @widgetManagementDesc.
  ///
  /// In en, this message translates to:
  /// **'Quick view of income and expenses on home screen'**
  String get widgetManagementDesc;

  /// No description provided for @widgetPreview.
  ///
  /// In en, this message translates to:
  /// **'Widget Preview'**
  String get widgetPreview;

  /// No description provided for @widgetPreviewDesc.
  ///
  /// In en, this message translates to:
  /// **'Widget automatically displays actual data from current ledger, theme color follows app settings'**
  String get widgetPreviewDesc;

  /// No description provided for @howToAddWidget.
  ///
  /// In en, this message translates to:
  /// **'How to Add Widget'**
  String get howToAddWidget;

  /// No description provided for @iosWidgetStep1.
  ///
  /// In en, this message translates to:
  /// **'Long press on home screen blank area to enter edit mode'**
  String get iosWidgetStep1;

  /// No description provided for @iosWidgetStep2.
  ///
  /// In en, this message translates to:
  /// **'Tap the \"+\" button in upper left corner'**
  String get iosWidgetStep2;

  /// No description provided for @iosWidgetStep3.
  ///
  /// In en, this message translates to:
  /// **'Search and select \"BeeCount\"'**
  String get iosWidgetStep3;

  /// No description provided for @iosWidgetStep4.
  ///
  /// In en, this message translates to:
  /// **'Select medium widget and add to home screen'**
  String get iosWidgetStep4;

  /// No description provided for @androidWidgetStep1.
  ///
  /// In en, this message translates to:
  /// **'Long press on home screen blank area'**
  String get androidWidgetStep1;

  /// No description provided for @androidWidgetStep2.
  ///
  /// In en, this message translates to:
  /// **'Select \"Widgets\"'**
  String get androidWidgetStep2;

  /// No description provided for @androidWidgetStep3.
  ///
  /// In en, this message translates to:
  /// **'Find and long press \"BeeCount\" widget'**
  String get androidWidgetStep3;

  /// No description provided for @androidWidgetStep4.
  ///
  /// In en, this message translates to:
  /// **'Drag to suitable position on home screen'**
  String get androidWidgetStep4;

  /// No description provided for @aboutWidget.
  ///
  /// In en, this message translates to:
  /// **'About Widget'**
  String get aboutWidget;

  /// No description provided for @widgetDescription.
  ///
  /// In en, this message translates to:
  /// **'Widget automatically syncs to display today\'s and this month\'s income and expense data, refreshing every 30 minutes. Data updates immediately when app is opened.'**
  String get widgetDescription;

  /// No description provided for @widgetQuickEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Entry'**
  String get widgetQuickEntryTitle;

  /// No description provided for @widgetQuickEntryDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap the left side of the widget to quickly add an expense, or tap the right side to add an income. You can also use beecount://new?type=transfer via Shortcuts to quickly start a transfer.'**
  String get widgetQuickEntryDesc;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'BeeCount'**
  String get appName;

  /// No description provided for @monthSuffix.
  ///
  /// In en, this message translates to:
  /// **''**
  String get monthSuffix;

  /// No description provided for @todayExpense.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Expense'**
  String get todayExpense;

  /// No description provided for @todayIncome.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Income'**
  String get todayIncome;

  /// No description provided for @monthExpense.
  ///
  /// In en, this message translates to:
  /// **'Month\'s Expense'**
  String get monthExpense;

  /// No description provided for @monthIncome.
  ///
  /// In en, this message translates to:
  /// **'Month\'s Income'**
  String get monthIncome;

  /// No description provided for @autoScreenshotBilling.
  ///
  /// In en, this message translates to:
  /// **'Auto Screenshot Billing'**
  String get autoScreenshotBilling;

  /// No description provided for @autoScreenshotBillingDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto-recognize payment info from screenshots'**
  String get autoScreenshotBillingDesc;

  /// No description provided for @autoScreenshotBillingTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto Screenshot Billing'**
  String get autoScreenshotBillingTitle;

  /// No description provided for @featureDescription.
  ///
  /// In en, this message translates to:
  /// **'Feature Description'**
  String get featureDescription;

  /// No description provided for @featureDescriptionContent.
  ///
  /// In en, this message translates to:
  /// **'After taking a screenshot of payment page, the system will automatically recognize amount and merchant info, and create expense record.\n\n⚡ Recognition speed: 2-3 seconds (may be longer on some devices)\n🤖 Smart category matching\n📝 Auto-fill notes\n\n⚠️ Note:\n• Different devices have different screenshot save speeds, delay may be 5-10 seconds\n• May not work on some devices, depending on system implementation\n• Recognized screenshots will be skipped automatically\n• Due to Android Scoped Storage restrictions (Android 10+), apps cannot delete system screenshots. Manual cleanup required'**
  String get featureDescriptionContent;

  /// No description provided for @autoBilling.
  ///
  /// In en, this message translates to:
  /// **'Auto Billing'**
  String get autoBilling;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @photosPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Photos permission required for screenshot monitoring'**
  String get photosPermissionRequired;

  /// No description provided for @enableSuccess.
  ///
  /// In en, this message translates to:
  /// **'Auto billing enabled'**
  String get enableSuccess;

  /// No description provided for @disableSuccess.
  ///
  /// In en, this message translates to:
  /// **'Auto billing disabled'**
  String get disableSuccess;

  /// No description provided for @autoBillingBatteryTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep Running in Background'**
  String get autoBillingBatteryTitle;

  /// No description provided for @autoBillingBatteryGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Battery Optimization Settings'**
  String get autoBillingBatteryGuideTitle;

  /// No description provided for @autoBillingBatteryDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto billing requires the app to keep running in the background. Some phones automatically clean background apps when locked, which may cause auto billing to fail. It is recommended to disable battery optimization to ensure proper functionality.'**
  String get autoBillingBatteryDesc;

  /// No description provided for @autoBillingCheckBattery.
  ///
  /// In en, this message translates to:
  /// **'Check Battery Optimization'**
  String get autoBillingCheckBattery;

  /// No description provided for @autoBillingBatteryWarning.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Battery optimization is not disabled. The app may be automatically cleaned by the system, causing auto billing to fail. Please tap the \"Settings\" button above to disable battery optimization.'**
  String get autoBillingBatteryWarning;

  /// No description provided for @enableFailed.
  ///
  /// In en, this message translates to:
  /// **'Enable failed'**
  String get enableFailed;

  /// No description provided for @disableFailed.
  ///
  /// In en, this message translates to:
  /// **'Disable failed'**
  String get disableFailed;

  /// No description provided for @iosAutoFeatureDesc.
  ///
  /// In en, this message translates to:
  /// **'Use iOS \"Shortcuts\" app to automatically identify payment information from screenshots and create transactions. Once set up, it will automatically trigger on every screenshot.'**
  String get iosAutoFeatureDesc;

  /// No description provided for @iosAutoShortcutConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Configuration Steps:'**
  String get iosAutoShortcutConfigTitle;

  /// No description provided for @iosAutoShortcutStep1.
  ///
  /// In en, this message translates to:
  /// **'Open \"Shortcuts\" app, tap \"+\" in top right to create new shortcut'**
  String get iosAutoShortcutStep1;

  /// No description provided for @iosAutoShortcutStep2.
  ///
  /// In en, this message translates to:
  /// **'Add \"Take Screenshot\" action'**
  String get iosAutoShortcutStep2;

  /// No description provided for @iosAutoShortcutStep3.
  ///
  /// In en, this message translates to:
  /// **'Search and add \"BeeCount - Auto Billing\" action'**
  String get iosAutoShortcutStep3;

  /// No description provided for @iosAutoShortcutStep4.
  ///
  /// In en, this message translates to:
  /// **'Set the screenshot parameter of \"BeeCount\" to the previous \"Screenshot\"'**
  String get iosAutoShortcutStep4;

  /// No description provided for @iosAutoShortcutStep5.
  ///
  /// In en, this message translates to:
  /// **'(Optional) Go to Settings > Accessibility > Touch > Back Tap, bind this shortcut'**
  String get iosAutoShortcutStep5;

  /// No description provided for @iosAutoShortcutStep6.
  ///
  /// In en, this message translates to:
  /// **'Done! Double tap phone back during payment for quick billing'**
  String get iosAutoShortcutStep6;

  /// No description provided for @iosAutoShortcutRecommendedTip.
  ///
  /// In en, this message translates to:
  /// **'✅ Recommended: After binding the shortcut to \"Back Tap\", double tap phone back during payment to auto-screenshot and recognize billing, no manual screenshot needed.'**
  String get iosAutoShortcutRecommendedTip;

  /// No description provided for @iosAutoBackTapTitle.
  ///
  /// In en, this message translates to:
  /// **'💡 Double Tap Back to Trigger (Recommended)'**
  String get iosAutoBackTapTitle;

  /// No description provided for @iosAutoBackTapDesc.
  ///
  /// In en, this message translates to:
  /// **'Settings > Accessibility > Touch > Back Tap\n• Select \"Double Tap\" or \"Triple Tap\"\n• Choose the shortcut you just created\n• After setup, double tap phone back during payment to auto-record, no screenshot needed'**
  String get iosAutoBackTapDesc;

  /// No description provided for @iosAutoTutorialTitle.
  ///
  /// In en, this message translates to:
  /// **'Video Tutorial'**
  String get iosAutoTutorialTitle;

  /// No description provided for @iosAutoTutorialDesc.
  ///
  /// In en, this message translates to:
  /// **'Watch detailed setup video tutorial'**
  String get iosAutoTutorialDesc;

  /// No description provided for @iosAutoImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Get Shortcut in One Tap'**
  String get iosAutoImportTitle;

  /// No description provided for @iosAutoImportDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap the button below to import the ready-made \"Screenshot → Auto Billing\" shortcut — no need to add the \"Take Screenshot\" action or connect parameters manually. After importing, binding it to \"Back Tap\" is recommended.'**
  String get iosAutoImportDesc;

  /// No description provided for @iosAutoImportButton.
  ///
  /// In en, this message translates to:
  /// **'Get Shortcut'**
  String get iosAutoImportButton;

  /// No description provided for @iosAutoImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the shortcut link. Check your connection and try again.'**
  String get iosAutoImportFailed;

  /// No description provided for @iosAutoManualConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual Setup (Advanced)'**
  String get iosAutoManualConfigTitle;

  /// No description provided for @iosAutoManualConfigDesc.
  ///
  /// In en, this message translates to:
  /// **'If one-tap import isn\'t available, follow these steps to create the shortcut manually.'**
  String get iosAutoManualConfigDesc;

  /// No description provided for @aiSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiSettingsTitle;

  /// No description provided for @aiSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure AI models and recognition strategy'**
  String get aiSettingsSubtitle;

  /// No description provided for @aiEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable AI Assistant'**
  String get aiEnableTitle;

  /// No description provided for @aiEnableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use AI vision to recognize bill screenshots, extract amount, merchant, time, and support natural language conversation'**
  String get aiEnableSubtitle;

  /// No description provided for @aiEnableToastOn.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant enabled'**
  String get aiEnableToastOn;

  /// No description provided for @aiEnableToastOff.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant disabled'**
  String get aiEnableToastOff;

  /// No description provided for @aiStrategyTitle.
  ///
  /// In en, this message translates to:
  /// **'Execution Strategy'**
  String get aiStrategyTitle;

  /// No description provided for @aiStrategyLocalFirst.
  ///
  /// In en, this message translates to:
  /// **'Local First (Recommended)'**
  String get aiStrategyLocalFirst;

  /// No description provided for @aiStrategyCloudFirst.
  ///
  /// In en, this message translates to:
  /// **'Cloud First'**
  String get aiStrategyCloudFirst;

  /// No description provided for @aiStrategyCloudFirstDesc.
  ///
  /// In en, this message translates to:
  /// **'Use cloud API first, downgrade to local if failed'**
  String get aiStrategyCloudFirstDesc;

  /// No description provided for @aiStrategyLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Local Only'**
  String get aiStrategyLocalOnly;

  /// No description provided for @aiStrategyCloudOnly.
  ///
  /// In en, this message translates to:
  /// **'Cloud Only'**
  String get aiStrategyCloudOnly;

  /// No description provided for @aiStrategyCloudOnlyDesc.
  ///
  /// In en, this message translates to:
  /// **'Use cloud API only, no model download'**
  String get aiStrategyCloudOnlyDesc;

  /// No description provided for @aiStrategyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Local model in training, coming soon'**
  String get aiStrategyUnavailable;

  /// No description provided for @aiStrategySwitched.
  ///
  /// In en, this message translates to:
  /// **'Switched to: {strategy}'**
  String aiStrategySwitched(String strategy);

  /// No description provided for @aiCloudApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your Zhipu AI API Key'**
  String get aiCloudApiKeyHint;

  /// No description provided for @aiCloudApiKeyHintCustom.
  ///
  /// In en, this message translates to:
  /// **'Enter API Key'**
  String get aiCloudApiKeyHintCustom;

  /// No description provided for @aiCloudApiKeyHelper.
  ///
  /// In en, this message translates to:
  /// **'GLM-*-Flash model is completely free'**
  String get aiCloudApiKeyHelper;

  /// No description provided for @aiCloudApiGetKey.
  ///
  /// In en, this message translates to:
  /// **'Get API Key'**
  String get aiCloudApiGetKey;

  /// No description provided for @aiCloudApiTutorial.
  ///
  /// In en, this message translates to:
  /// **'Tutorial'**
  String get aiCloudApiTutorial;

  /// No description provided for @aiCloudApiTestKey.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get aiCloudApiTestKey;

  /// No description provided for @aiChatConfigWarning.
  ///
  /// In en, this message translates to:
  /// **'AI provider not configured. Please add and bind one in Settings'**
  String get aiChatConfigWarning;

  /// No description provided for @aiChatGoToSettings.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings'**
  String get aiChatGoToSettings;

  /// No description provided for @aiOcrRecognizing.
  ///
  /// In en, this message translates to:
  /// **'Recognizing bill...'**
  String get aiOcrRecognizing;

  /// No description provided for @aiOcrNoAmount.
  ///
  /// In en, this message translates to:
  /// **'No valid amount recognized, please add manually'**
  String get aiOcrNoAmount;

  /// No description provided for @aiNotConfiguredHint.
  ///
  /// In en, this message translates to:
  /// **'AI service not configured. Go to \"Me → AI Settings\" to set up.'**
  String get aiNotConfiguredHint;

  /// No description provided for @aiOcrCheckLog.
  ///
  /// In en, this message translates to:
  /// **'Recognition failed. Check logs for details.'**
  String get aiOcrCheckLog;

  /// No description provided for @aiNotConfiguredNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'❌ Cannot recognize screenshot'**
  String get aiNotConfiguredNotificationTitle;

  /// No description provided for @aiNotConfiguredNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'AI service not configured. Tap to set up.'**
  String get aiNotConfiguredNotificationBody;

  /// No description provided for @autoBillingNotifyDetectedTitle.
  ///
  /// In en, this message translates to:
  /// **'✅ Screenshot detected'**
  String get autoBillingNotifyDetectedTitle;

  /// No description provided for @autoBillingNotifyWaitingFileBody.
  ///
  /// In en, this message translates to:
  /// **'Waiting for file to be written...'**
  String get autoBillingNotifyWaitingFileBody;

  /// No description provided for @autoBillingNotifyRecognizingScreenshotTitle.
  ///
  /// In en, this message translates to:
  /// **'Recognizing screenshot...'**
  String get autoBillingNotifyRecognizingScreenshotTitle;

  /// No description provided for @autoBillingNotifyVisionAnalyzingBody.
  ///
  /// In en, this message translates to:
  /// **'Calling AI vision to analyze payment info, please wait'**
  String get autoBillingNotifyVisionAnalyzingBody;

  /// No description provided for @autoBillingNotifyRecognizingTextTitle.
  ///
  /// In en, this message translates to:
  /// **'⏳ Recognizing'**
  String get autoBillingNotifyRecognizingTextTitle;

  /// No description provided for @autoBillingNotifyTextAnalyzingBody.
  ///
  /// In en, this message translates to:
  /// **'Calling AI to parse payment info...'**
  String get autoBillingNotifyTextAnalyzingBody;

  /// No description provided for @autoBillingNotifyRecognizeFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'❌ Recognition failed'**
  String get autoBillingNotifyRecognizeFailedTitle;

  /// No description provided for @autoBillingNotifyRecognizeFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Could not extract billing info from screenshot. Check AI config or the image.'**
  String get autoBillingNotifyRecognizeFailedBody;

  /// No description provided for @autoBillingNotifyFileUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Recognition failed'**
  String get autoBillingNotifyFileUnavailableTitle;

  /// No description provided for @autoBillingNotifyFileUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Screenshot file is not available'**
  String get autoBillingNotifyFileUnavailableBody;

  /// No description provided for @autoBillingNotifyNoLedgerTitle.
  ///
  /// In en, this message translates to:
  /// **'❌ Auto billing failed'**
  String get autoBillingNotifyNoLedgerTitle;

  /// No description provided for @autoBillingNotifyNoLedgerBody.
  ///
  /// In en, this message translates to:
  /// **'No ledger available. Please create one first.'**
  String get autoBillingNotifyNoLedgerBody;

  /// No description provided for @autoBillingNotifyNoAmountBody.
  ///
  /// In en, this message translates to:
  /// **'Could not recognize the amount'**
  String get autoBillingNotifyNoAmountBody;

  /// No description provided for @autoBillingNotifyCreateFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'❌ Failed to create'**
  String get autoBillingNotifyCreateFailedTitle;

  /// No description provided for @autoBillingNotifyCreateFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Could not create transaction record'**
  String get autoBillingNotifyCreateFailedBody;

  /// No description provided for @autoBillingNotifyProcessFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'❌ Processing failed'**
  String get autoBillingNotifyProcessFailedTitle;

  /// No description provided for @autoBillingNotifyProcessFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String autoBillingNotifyProcessFailedBody(String error);

  /// No description provided for @autoBillingNotifySuccessSingleTitle.
  ///
  /// In en, this message translates to:
  /// **'✅ Auto billing succeeded ¥{amount}'**
  String autoBillingNotifySuccessSingleTitle(String amount);

  /// No description provided for @autoBillingNotifySuccessMultiTitle.
  ///
  /// In en, this message translates to:
  /// **'✅ Auto billing succeeded ({count} entries)'**
  String autoBillingNotifySuccessMultiTitle(int count);

  /// No description provided for @autoBillingNotifySuccessMultiBody.
  ///
  /// In en, this message translates to:
  /// **'Total ¥{amount}'**
  String autoBillingNotifySuccessMultiBody(String amount);

  /// No description provided for @autoBillingNotifySuccessSingleBodyNote.
  ///
  /// In en, this message translates to:
  /// **'Note: {note}'**
  String autoBillingNotifySuccessSingleBodyNote(String note);

  /// No description provided for @autoBillingNotifySuccessSingleBodyDefault.
  ///
  /// In en, this message translates to:
  /// **'Record created automatically'**
  String get autoBillingNotifySuccessSingleBodyDefault;

  /// No description provided for @aiOcrNoLedger.
  ///
  /// In en, this message translates to:
  /// **'Ledger not found'**
  String get aiOcrNoLedger;

  /// No description provided for @aiOcrSuccess.
  ///
  /// In en, this message translates to:
  /// **'✅ {type} bill created ¥{amount}'**
  String aiOcrSuccess(String type, String amount);

  /// No description provided for @aiOcrFailed.
  ///
  /// In en, this message translates to:
  /// **'Recognition failed: {error}'**
  String aiOcrFailed(String error);

  /// No description provided for @aiOcrCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create bill'**
  String get aiOcrCreateFailed;

  /// No description provided for @aiTypeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get aiTypeIncome;

  /// No description provided for @aiTypeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get aiTypeExpense;

  /// No description provided for @cloudSyncPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get cloudSyncPageTitle;

  /// No description provided for @cloudSyncPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manual upload and download ledger data'**
  String get cloudSyncPageSubtitle;

  /// No description provided for @cloudTutorialTitle.
  ///
  /// In en, this message translates to:
  /// **'Getting Started'**
  String get cloudTutorialTitle;

  /// No description provided for @cloudTutorialIntro.
  ///
  /// In en, this message translates to:
  /// **'BeeCount Cloud is a self-hosted sync server that supports real-time multi-device collaboration. The flow is simple:'**
  String get cloudTutorialIntro;

  /// No description provided for @cloudTutorialStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Step 1: Deploy or join a server'**
  String get cloudTutorialStep1Title;

  /// No description provided for @cloudTutorialStep1Desc.
  ///
  /// In en, this message translates to:
  /// **'Self-host with one Docker command (see the Docker guide in GitHub README). Or join an existing BeeCount Cloud server run by a friend / team.'**
  String get cloudTutorialStep1Desc;

  /// No description provided for @cloudTutorialStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Step 2: Get an account'**
  String get cloudTutorialStep2Title;

  /// No description provided for @cloudTutorialStep2Desc.
  ///
  /// In en, this message translates to:
  /// **'BeeCount Cloud does NOT offer self-registration (to prevent abuse on public servers). If you self-host: the first Docker boot prints a random admin email + password to the logs — use that. Joining someone else\'s server: ask the admin to create an account for you in Web → Users.'**
  String get cloudTutorialStep2Desc;

  /// No description provided for @cloudTutorialStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Step 3: Login + enable sync'**
  String get cloudTutorialStep3Title;

  /// No description provided for @cloudTutorialStep3Desc.
  ///
  /// In en, this message translates to:
  /// **'In the app, pick BeeCount Cloud, enter the server URL and the account you got in step 2. First login uploads your entire local ledger; every subsequent edit is pushed in real time.'**
  String get cloudTutorialStep3Desc;

  /// No description provided for @cloudTutorialStep4Title.
  ///
  /// In en, this message translates to:
  /// **'Step 4: Login from other devices'**
  String get cloudTutorialStep4Title;

  /// No description provided for @cloudTutorialStep4Desc.
  ///
  /// In en, this message translates to:
  /// **'Phone / tablet / Web — same account, instant shared state. Edits propagate within seconds.'**
  String get cloudTutorialStep4Desc;

  /// No description provided for @cloudTutorialTipTitle.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get cloudTutorialTipTitle;

  /// No description provided for @cloudTutorialTipDesc.
  ///
  /// In en, this message translates to:
  /// **'The Web UI lives at the server URL. Open it in a browser to manage ledgers, members, and view logs.'**
  String get cloudTutorialTipDesc;

  /// No description provided for @cloudTutorialFeaturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get cloudTutorialFeaturesTitle;

  /// No description provided for @cloudTutorialFeature1.
  ///
  /// In en, this message translates to:
  /// **'📱 Real-time multi-device: phone A + phone B + Web on one account, sub-second sync'**
  String get cloudTutorialFeature1;

  /// No description provided for @cloudTutorialFeature2.
  ///
  /// In en, this message translates to:
  /// **'🌐 Web UI included: one Docker image ships server + Web, browser ready'**
  String get cloudTutorialFeature2;

  /// No description provided for @cloudTutorialFeature3.
  ///
  /// In en, this message translates to:
  /// **'👥 Multi-user isolation: multiple users on one server, data fully separated'**
  String get cloudTutorialFeature3;

  /// No description provided for @cloudTutorialFeature4.
  ///
  /// In en, this message translates to:
  /// **'🤝 Shared ledgers: invite family / team into one book with seconds-level sync'**
  String get cloudTutorialFeature4;

  /// No description provided for @cloudTutorialGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get cloudTutorialGotIt;

  /// No description provided for @cloudSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Downloads automatically compare differences for selective preview. Not real-time — avoid editing the same ledger on multiple devices simultaneously. Sync scope covers ledger data (including associated accounts, categories, and tags), excluding attachments.'**
  String get cloudSyncHint;

  /// No description provided for @cloudSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get cloudSyncNow;

  /// No description provided for @cloudSyncNowHint.
  ///
  /// In en, this message translates to:
  /// **'Push local changes and pull remote updates'**
  String get cloudSyncNowHint;

  /// No description provided for @cloudSyncInProgress.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get cloudSyncInProgress;

  /// No description provided for @cloudSyncComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync complete: pushed {pushed}, pulled {pulled}'**
  String cloudSyncComplete(int pushed, int pulled);

  /// No description provided for @cloudAutoSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Auto-sync to cloud after data changes'**
  String get cloudAutoSyncHint;

  /// No description provided for @dataManagement.
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get dataManagement;

  /// No description provided for @dataManagementDesc.
  ///
  /// In en, this message translates to:
  /// **'Import, export, categories and accounts'**
  String get dataManagementDesc;

  /// No description provided for @dataManagementPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get dataManagementPageTitle;

  /// No description provided for @dataManagementPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage transaction data and categories'**
  String get dataManagementPageSubtitle;

  /// No description provided for @dataManagementAttachmentHint.
  ///
  /// In en, this message translates to:
  /// **'When restoring data, please import the attachment package first, then import ledger data (CSV or cloud sync) to ensure attachments are correctly associated.'**
  String get dataManagementAttachmentHint;

  /// No description provided for @smartBilling.
  ///
  /// In en, this message translates to:
  /// **'Smart Billing'**
  String get smartBilling;

  /// No description provided for @smartBillingDesc.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant, smart recognition, auto billing'**
  String get smartBillingDesc;

  /// No description provided for @smartBillingPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Billing'**
  String get smartBillingPageTitle;

  /// No description provided for @smartBillingPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'AI and automation billing features'**
  String get smartBillingPageSubtitle;

  /// No description provided for @smartBillingGuideHint.
  ///
  /// In en, this message translates to:
  /// **'Long press the + button at the bottom center of the home page to quickly access these features'**
  String get smartBillingGuideHint;

  /// No description provided for @smartBillingImageBilling.
  ///
  /// In en, this message translates to:
  /// **'Image Billing'**
  String get smartBillingImageBilling;

  /// No description provided for @smartBillingImageBillingDesc.
  ///
  /// In en, this message translates to:
  /// **'Select payment screenshots from gallery for recognition'**
  String get smartBillingImageBillingDesc;

  /// No description provided for @smartBillingImageBillingGuide.
  ///
  /// In en, this message translates to:
  /// **'Long press the + button at the bottom center of the home page and select \'Gallery\' to use image billing. Requires AI service configured under \"Me → AI Settings\"; the vision model will extract amount, merchant, time, etc. from the screenshot.'**
  String get smartBillingImageBillingGuide;

  /// No description provided for @smartBillingVisionAIRequired.
  ///
  /// In en, this message translates to:
  /// **'Image recognition requires an AI vision service. Set it up in \"Me → AI Settings\" first.'**
  String get smartBillingVisionAIRequired;

  /// No description provided for @smartBillingCameraBilling.
  ///
  /// In en, this message translates to:
  /// **'Camera Billing'**
  String get smartBillingCameraBilling;

  /// No description provided for @smartBillingCameraBillingDesc.
  ///
  /// In en, this message translates to:
  /// **'Capture payment screenshots for recognition'**
  String get smartBillingCameraBillingDesc;

  /// No description provided for @smartBillingCameraBillingGuide.
  ///
  /// In en, this message translates to:
  /// **'Long press the + button at the bottom center of the home page and select \'Camera\' to use camera billing. Requires AI service configured under \"Me → AI Settings\"; the vision model will extract amount, merchant, time, etc. from the photo.'**
  String get smartBillingCameraBillingGuide;

  /// No description provided for @smartBillingVoiceBilling.
  ///
  /// In en, this message translates to:
  /// **'Voice Billing'**
  String get smartBillingVoiceBilling;

  /// No description provided for @smartBillingVoiceBillingDesc.
  ///
  /// In en, this message translates to:
  /// **'Quick billing through voice input'**
  String get smartBillingVoiceBillingDesc;

  /// No description provided for @smartBillingVoiceBillingGuide.
  ///
  /// In en, this message translates to:
  /// **'Long press the + button at the bottom center of the home page and select \'Voice\' to use voice billing. Voice billing requires AI to convert speech to text and extract bill information.'**
  String get smartBillingVoiceBillingGuide;

  /// No description provided for @smartBillingAIRequired.
  ///
  /// In en, this message translates to:
  /// **'Voice billing requires an AI speech service. Set it up in \"Me → AI Settings\" first.'**
  String get smartBillingAIRequired;

  /// No description provided for @smartBillingAutoTags.
  ///
  /// In en, this message translates to:
  /// **'Auto-associate Tags'**
  String get smartBillingAutoTags;

  /// No description provided for @smartBillingAutoTagsDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically associate frequently used tags based on category'**
  String get smartBillingAutoTagsDesc;

  /// No description provided for @smartBillingAutoAttachment.
  ///
  /// In en, this message translates to:
  /// **'Auto-add Attachment'**
  String get smartBillingAutoAttachment;

  /// No description provided for @smartBillingAutoAttachmentDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically add original image as attachment for photo billing'**
  String get smartBillingAutoAttachmentDesc;

  /// No description provided for @autoScreenshotBillingIosTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto Billing'**
  String get autoScreenshotBillingIosTitle;

  /// No description provided for @autoScreenshotBillingIosDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto-recognize payments via Shortcuts'**
  String get autoScreenshotBillingIosDesc;

  /// No description provided for @shareBilling.
  ///
  /// In en, this message translates to:
  /// **'Share to Bill'**
  String get shareBilling;

  /// No description provided for @shareBillingDesc.
  ///
  /// In en, this message translates to:
  /// **'Share a payment screenshot from Alipay/WeChat to bill it'**
  String get shareBillingDesc;

  /// No description provided for @shareBillingGuide.
  ///
  /// In en, this message translates to:
  /// **'When you see a payment screenshot in Alipay, WeChat, Photos, etc., tap \"Share\" and choose \"BeeCount\" to auto-recognize the amount, merchant, and time and create a transaction — no need to save the screenshot first.'**
  String get shareBillingGuide;

  /// No description provided for @shareBillingActionHint.
  ///
  /// In en, this message translates to:
  /// **'Recognized automatically in the background after sharing — no need to open BeeCount'**
  String get shareBillingActionHint;

  /// No description provided for @automation.
  ///
  /// In en, this message translates to:
  /// **'Automation'**
  String get automation;

  /// No description provided for @automationDesc.
  ///
  /// In en, this message translates to:
  /// **'Recurring transactions and reminders'**
  String get automationDesc;

  /// No description provided for @automationPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Automation'**
  String get automationPageTitle;

  /// No description provided for @automationPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recurring transactions and reminder settings'**
  String get automationPageSubtitle;

  /// No description provided for @appearanceSettings.
  ///
  /// In en, this message translates to:
  /// **'Personalization'**
  String get appearanceSettings;

  /// No description provided for @appearanceSettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Theme, font, language, app lock, etc.'**
  String get appearanceSettingsDesc;

  /// No description provided for @appearanceSettingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Personalization'**
  String get appearanceSettingsPageTitle;

  /// No description provided for @appearanceSettingsPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance, display, security and other app preferences'**
  String get appearanceSettingsPageSubtitle;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutDesc.
  ///
  /// In en, this message translates to:
  /// **'Version info, help and feedback'**
  String get aboutDesc;

  /// No description provided for @mineRateApp.
  ///
  /// In en, this message translates to:
  /// **'Rate the App'**
  String get mineRateApp;

  /// No description provided for @mineRateAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rate us on the App Store'**
  String get mineRateAppSubtitle;

  /// No description provided for @aboutPageTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutPageTitle;

  /// No description provided for @aboutPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App information and help'**
  String get aboutPageSubtitle;

  /// No description provided for @aboutPageLoadingVersion.
  ///
  /// In en, this message translates to:
  /// **'Loading version...'**
  String get aboutPageLoadingVersion;

  /// No description provided for @aboutWebsite.
  ///
  /// In en, this message translates to:
  /// **'Official Website'**
  String get aboutWebsite;

  /// No description provided for @aboutGitHubRepo.
  ///
  /// In en, this message translates to:
  /// **'GitHub Repository'**
  String get aboutGitHubRepo;

  /// No description provided for @aboutXiaohongshu.
  ///
  /// In en, this message translates to:
  /// **'Xiaohongshu'**
  String get aboutXiaohongshu;

  /// No description provided for @aboutDouyin.
  ///
  /// In en, this message translates to:
  /// **'Douyin'**
  String get aboutDouyin;

  /// No description provided for @aboutSupportDevelopment.
  ///
  /// In en, this message translates to:
  /// **'Support Development'**
  String get aboutSupportDevelopment;

  /// No description provided for @aboutSupportDevelopmentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Buy me a coffee'**
  String get aboutSupportDevelopmentSubtitle;

  /// No description provided for @aboutDeveloperStoryTitle.
  ///
  /// In en, this message translates to:
  /// **'From the Developer'**
  String get aboutDeveloperStoryTitle;

  /// No description provided for @aboutDeveloperStory.
  ///
  /// In en, this message translates to:
  /// **'I started tracking my expenses in 2015 as an intern, and I\'ve kept the habit for over a decade. Concerned about ads, paywalls, privacy risks, and apps shutting down, I decided to build my own — first as a small tool for myself and my family.\n\nIn September 2025, BeeCount launched its first version. Honestly, I had no idea if anyone would use it. But gradually, feedback started coming in — someone said they finally found a clean budgeting app, others offered great suggestions, and some quietly left five-star reviews. Every single message reminded me this was worth continuing.\n\nBeeCount is ad-free, subscription-free, and fully open source. All your data stays on your device and is never uploaded to any third-party server. But publishing and maintaining an app isn\'t free — developer accounts, servers, and other costs are currently covered by community donations, and every system update, bug fix, and new feature is built outside of my day job.\n\nIf BeeCount has been helpful to you, a rating, a share, or a donation would help this little project go further. Thank you for your trust.'**
  String get aboutDeveloperStory;

  /// No description provided for @aboutRelatedProducts.
  ///
  /// In en, this message translates to:
  /// **'More Products'**
  String get aboutRelatedProducts;

  /// No description provided for @aboutBeeAssets.
  ///
  /// In en, this message translates to:
  /// **'BeeAssets'**
  String get aboutBeeAssets;

  /// No description provided for @aboutBeeAssetsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Visualize your full asset portfolio'**
  String get aboutBeeAssetsSubtitle;

  /// No description provided for @aboutBeeAssetsIntro.
  ///
  /// In en, this message translates to:
  /// **'BeeCount focuses on daily cash flow; BeeAssets is its sibling product, focused on asset portfolio visualization: net worth trends across accounts, property / investment / crypto classification, returns, holding period, and allocation breakdown.'**
  String get aboutBeeAssetsIntro;

  /// No description provided for @aboutBeeDNS.
  ///
  /// In en, this message translates to:
  /// **'BeeDNS'**
  String get aboutBeeDNS;

  /// No description provided for @aboutBeeDNSSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Simple and efficient DNS management tool'**
  String get aboutBeeDNSSubtitle;

  /// No description provided for @aboutBeeDNSIntro.
  ///
  /// In en, this message translates to:
  /// **'Got domains across Cloudflare and Aliyun? BeeDNS unifies them in one place: batch edit records, A/AAAA toggles, resolution migration, subdomain bulk management — no more switching between provider consoles.'**
  String get aboutBeeDNSIntro;

  /// No description provided for @productPromoAndroidTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Beta Access'**
  String get productPromoAndroidTitle;

  /// No description provided for @productPromoAndroidMessage.
  ///
  /// In en, this message translates to:
  /// **'This app is still in closed testing on Google Play — invitation only.\n\nHow to apply: email us with your Google account address (required) and a brief use case (optional). We\'ll reply within 1-3 days and add you to the beta whitelist.'**
  String get productPromoAndroidMessage;

  /// No description provided for @productPromoOpenStore.
  ///
  /// In en, this message translates to:
  /// **'Open in App Store'**
  String get productPromoOpenStore;

  /// No description provided for @productPromoTestFlight.
  ///
  /// In en, this message translates to:
  /// **'TestFlight beta'**
  String get productPromoTestFlight;

  /// No description provided for @productPromoLearnMore.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get productPromoLearnMore;

  /// No description provided for @productPromoEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Application Email (tap to copy)'**
  String get productPromoEmailLabel;

  /// No description provided for @productPromoCopiedToast.
  ///
  /// In en, this message translates to:
  /// **'Email copied to clipboard'**
  String get productPromoCopiedToast;

  /// No description provided for @productPromoMailUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No email app detected. The address has been copied — paste it into any mail app to send.'**
  String get productPromoMailUnavailable;

  /// No description provided for @productPromoEmailButton.
  ///
  /// In en, this message translates to:
  /// **'Send Email'**
  String get productPromoEmailButton;

  /// No description provided for @productPromoWebsiteButton.
  ///
  /// In en, this message translates to:
  /// **'Visit Website'**
  String get productPromoWebsiteButton;

  /// No description provided for @productPromoEmailSubject.
  ///
  /// In en, this message translates to:
  /// **'Beta access request - {productName}'**
  String productPromoEmailSubject(String productName);

  /// No description provided for @productPromoEmailBody.
  ///
  /// In en, this message translates to:
  /// **'Hi,\n\nI\'d like to join the closed beta for {productName} on Google Play. My Google account email is:\n\n(please fill in your Gmail / Google account email)\n\nThanks!'**
  String productPromoEmailBody(String productName);

  /// No description provided for @logCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Log Center'**
  String get logCenterTitle;

  /// No description provided for @logCenterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View app runtime logs'**
  String get logCenterSubtitle;

  /// No description provided for @logCenterSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search log content or tags...'**
  String get logCenterSearchHint;

  /// No description provided for @logCenterFilterLevel.
  ///
  /// In en, this message translates to:
  /// **'Log Level'**
  String get logCenterFilterLevel;

  /// No description provided for @logCenterFilterPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get logCenterFilterPlatform;

  /// No description provided for @logCenterTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get logCenterTotal;

  /// No description provided for @logCenterFiltered.
  ///
  /// In en, this message translates to:
  /// **'Filtered'**
  String get logCenterFiltered;

  /// No description provided for @logCenterEmpty.
  ///
  /// In en, this message translates to:
  /// **'No logs'**
  String get logCenterEmpty;

  /// No description provided for @logCenterExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get logCenterExport;

  /// No description provided for @logCenterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get logCenterClear;

  /// No description provided for @logCenterExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get logCenterExportFailed;

  /// No description provided for @logCenterClearConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Logs'**
  String get logCenterClearConfirmTitle;

  /// No description provided for @logCenterClearConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all logs? This action cannot be undone.'**
  String get logCenterClearConfirmMessage;

  /// No description provided for @logCenterCleared.
  ///
  /// In en, this message translates to:
  /// **'Logs cleared'**
  String get logCenterCleared;

  /// No description provided for @logCenterCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get logCenterCopied;

  /// No description provided for @configImportExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Config Import/Export'**
  String get configImportExportTitle;

  /// No description provided for @configImportExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Backup and restore app configurations'**
  String get configImportExportSubtitle;

  /// No description provided for @configImportExportInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Feature Description'**
  String get configImportExportInfoTitle;

  /// No description provided for @configImportExportInfoMessage.
  ///
  /// In en, this message translates to:
  /// **'This feature is used to export and import app configurations, including cloud service settings, AI settings, etc. The config file uses YAML format for easy viewing and editing.\n\n⚠️ Config files contain sensitive information (such as API keys, passwords, etc.), please keep them safe.'**
  String get configImportExportInfoMessage;

  /// No description provided for @configExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Config'**
  String get configExportTitle;

  /// No description provided for @configExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export current config to YAML file'**
  String get configExportSubtitle;

  /// No description provided for @configExportShareSubject.
  ///
  /// In en, this message translates to:
  /// **'BeeCount Config File'**
  String get configExportShareSubject;

  /// No description provided for @configExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Config exported successfully'**
  String get configExportSuccess;

  /// No description provided for @configExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Config export failed'**
  String get configExportFailed;

  /// No description provided for @configImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Config'**
  String get configImportTitle;

  /// No description provided for @configImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore config from YAML file'**
  String get configImportSubtitle;

  /// No description provided for @configImportNoFilePath.
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get configImportNoFilePath;

  /// No description provided for @configImportConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Import'**
  String get configImportConfirmTitle;

  /// No description provided for @configImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Config imported successfully'**
  String get configImportSuccess;

  /// No description provided for @configImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Config import failed'**
  String get configImportFailed;

  /// No description provided for @configImportRestartTitle.
  ///
  /// In en, this message translates to:
  /// **'Restart Required'**
  String get configImportRestartTitle;

  /// No description provided for @configImportRestartMessage.
  ///
  /// In en, this message translates to:
  /// **'Config has been imported. Some settings will take effect after restarting the app.'**
  String get configImportRestartMessage;

  /// No description provided for @configImportExportIncludesTitle.
  ///
  /// In en, this message translates to:
  /// **'Included Configurations'**
  String get configImportExportIncludesTitle;

  /// No description provided for @configExportSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to: {path}'**
  String configExportSavedTo(String path);

  /// No description provided for @configExportViewContent.
  ///
  /// In en, this message translates to:
  /// **'View Content'**
  String get configExportViewContent;

  /// No description provided for @configExportCopyContent.
  ///
  /// In en, this message translates to:
  /// **'Copy Content'**
  String get configExportCopyContent;

  /// No description provided for @configExportContentCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get configExportContentCopied;

  /// No description provided for @configExportReadFileFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to read file'**
  String get configExportReadFileFailed;

  /// No description provided for @configIncludeLedgers.
  ///
  /// In en, this message translates to:
  /// **'Ledgers'**
  String get configIncludeLedgers;

  /// No description provided for @configIncludeSupabase.
  ///
  /// In en, this message translates to:
  /// **'Supabase cloud service config'**
  String get configIncludeSupabase;

  /// No description provided for @configIncludeWebdav.
  ///
  /// In en, this message translates to:
  /// **'WebDAV cloud service config'**
  String get configIncludeWebdav;

  /// No description provided for @configIncludeS3.
  ///
  /// In en, this message translates to:
  /// **'S3 cloud service config'**
  String get configIncludeS3;

  /// No description provided for @configIncludeAI.
  ///
  /// In en, this message translates to:
  /// **'AI smart recognition config'**
  String get configIncludeAI;

  /// No description provided for @configIncludeAISubtitle.
  ///
  /// In en, this message translates to:
  /// **'Providers, capability binding, model settings, etc.'**
  String get configIncludeAISubtitle;

  /// No description provided for @configIncludeAppSettings.
  ///
  /// In en, this message translates to:
  /// **'App settings (language, appearance, reminder, default account, etc.)'**
  String get configIncludeAppSettings;

  /// No description provided for @configIncludeRecurringTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recurring transactions'**
  String get configIncludeRecurringTransactions;

  /// No description provided for @configIncludeAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get configIncludeAccounts;

  /// No description provided for @configIncludeCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get configIncludeCategories;

  /// No description provided for @configIncludeTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get configIncludeTags;

  /// No description provided for @configIncludeBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get configIncludeBudgets;

  /// No description provided for @configIncludeOtherSettings.
  ///
  /// In en, this message translates to:
  /// **'Other Settings'**
  String get configIncludeOtherSettings;

  /// No description provided for @configIncludeOtherSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Including cloud service, AI config, app settings, etc.'**
  String get configIncludeOtherSettingsSubtitle;

  /// No description provided for @configExportSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Export Content'**
  String get configExportSelectTitle;

  /// No description provided for @configExportPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Preview'**
  String get configExportPreviewTitle;

  /// No description provided for @configExportConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Export'**
  String get configExportConfirmTitle;

  /// No description provided for @configImportSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Import Content'**
  String get configImportSelectTitle;

  /// No description provided for @configImportPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Preview'**
  String get configImportPreviewTitle;

  /// No description provided for @ledgersConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Conflict'**
  String get ledgersConflictTitle;

  /// No description provided for @ledgersConflictMessage.
  ///
  /// In en, this message translates to:
  /// **'Local and cloud ledger data are inconsistent, please choose an action:'**
  String get ledgersConflictMessage;

  /// No description provided for @ledgersConflictLocalInfo.
  ///
  /// In en, this message translates to:
  /// **'Local: {count} transactions'**
  String ledgersConflictLocalInfo(int count);

  /// No description provided for @ledgersConflictRemoteInfo.
  ///
  /// In en, this message translates to:
  /// **'Cloud: {count} transactions'**
  String ledgersConflictRemoteInfo(int count);

  /// No description provided for @ledgersConflictRemoteUpdated.
  ///
  /// In en, this message translates to:
  /// **'Cloud updated: {time}'**
  String ledgersConflictRemoteUpdated(String time);

  /// No description provided for @ledgersConflictLocalFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Local fingerprint: {fp}'**
  String ledgersConflictLocalFingerprint(String fp);

  /// No description provided for @ledgersConflictRemoteFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Cloud fingerprint: {fp}'**
  String ledgersConflictRemoteFingerprint(String fp);

  /// No description provided for @ledgersConflictUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload to Cloud'**
  String get ledgersConflictUpload;

  /// No description provided for @ledgersConflictDownload.
  ///
  /// In en, this message translates to:
  /// **'Download to Local'**
  String get ledgersConflictDownload;

  /// No description provided for @ledgersConflictUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get ledgersConflictUploading;

  /// No description provided for @ledgersConflictDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get ledgersConflictDownloading;

  /// No description provided for @ledgersConflictUploadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Upload successful'**
  String get ledgersConflictUploadSuccess;

  /// No description provided for @ledgersConflictDownloadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Download successful, merged {inserted} transactions'**
  String ledgersConflictDownloadSuccess(int inserted);

  /// No description provided for @storageManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage Management'**
  String get storageManagementTitle;

  /// No description provided for @storageManagementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear cache to free up space'**
  String get storageManagementSubtitle;

  /// No description provided for @storageAIModels.
  ///
  /// In en, this message translates to:
  /// **'AI Models'**
  String get storageAIModels;

  /// No description provided for @storageAPKFiles.
  ///
  /// In en, this message translates to:
  /// **'Installation Packages'**
  String get storageAPKFiles;

  /// No description provided for @storageNoData.
  ///
  /// In en, this message translates to:
  /// **'No Data'**
  String get storageNoData;

  /// No description provided for @storageFiles.
  ///
  /// In en, this message translates to:
  /// **'files'**
  String get storageFiles;

  /// No description provided for @storageHint.
  ///
  /// In en, this message translates to:
  /// **'Tap items to clear corresponding cache files'**
  String get storageHint;

  /// No description provided for @storageClearConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Clear'**
  String get storageClearConfirmTitle;

  /// No description provided for @storageClearAIModelsMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all AI models? Size: {size}'**
  String storageClearAIModelsMessage(String size);

  /// No description provided for @storageClearAPKMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all installation packages? Size: {size}'**
  String storageClearAPKMessage(String size);

  /// No description provided for @storageClearSuccess.
  ///
  /// In en, this message translates to:
  /// **'Cleared successfully'**
  String get storageClearSuccess;

  /// No description provided for @accountNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions'**
  String get accountNoTransactions;

  /// No description provided for @accountTransactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get accountTransactionHistory;

  /// No description provided for @accountTotalBalance.
  ///
  /// In en, this message translates to:
  /// **'Net Assets'**
  String get accountTotalBalance;

  /// No description provided for @accountCurrencyLocked.
  ///
  /// In en, this message translates to:
  /// **'This account has transactions and cannot change currency'**
  String get accountCurrencyLocked;

  /// No description provided for @accountDefaultIncomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Default Income Account'**
  String get accountDefaultIncomeTitle;

  /// No description provided for @accountDefaultExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Default Expense Account'**
  String get accountDefaultExpenseTitle;

  /// No description provided for @accountDefaultNone.
  ///
  /// In en, this message translates to:
  /// **'Not Set'**
  String get accountDefaultNone;

  /// No description provided for @commonNotice.
  ///
  /// In en, this message translates to:
  /// **'Notice'**
  String get commonNotice;

  /// No description provided for @transferTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transferTitle;

  /// No description provided for @transferIconSettings.
  ///
  /// In en, this message translates to:
  /// **'Transfer Icon Settings'**
  String get transferIconSettings;

  /// No description provided for @transferIconSettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Customize the display icon for transfer records'**
  String get transferIconSettingsDesc;

  /// No description provided for @transferFromAccount.
  ///
  /// In en, this message translates to:
  /// **'From Account'**
  String get transferFromAccount;

  /// No description provided for @transferToAccount.
  ///
  /// In en, this message translates to:
  /// **'To Account'**
  String get transferToAccount;

  /// No description provided for @transferSelectAccount.
  ///
  /// In en, this message translates to:
  /// **'Select Account'**
  String get transferSelectAccount;

  /// No description provided for @transferCreateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Transfer created successfully'**
  String get transferCreateSuccess;

  /// No description provided for @transferUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Transfer updated successfully'**
  String get transferUpdateSuccess;

  /// No description provided for @transferDifferentCurrencyError.
  ///
  /// In en, this message translates to:
  /// **'Transfer only supports accounts with the same currency'**
  String get transferDifferentCurrencyError;

  /// No description provided for @transferToPrefix.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get transferToPrefix;

  /// No description provided for @transferFromPrefix.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get transferFromPrefix;

  /// No description provided for @welcomeCategoryModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Category Mode'**
  String get welcomeCategoryModeTitle;

  /// No description provided for @welcomeCategoryModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Select the category structure that suits your needs'**
  String get welcomeCategoryModeDescription;

  /// No description provided for @welcomeCategoryModeFlatTitle.
  ///
  /// In en, this message translates to:
  /// **'Flat Categories'**
  String get welcomeCategoryModeFlatTitle;

  /// No description provided for @welcomeCategoryModeFlatDescription.
  ///
  /// In en, this message translates to:
  /// **'Simple and fast'**
  String get welcomeCategoryModeFlatDescription;

  /// No description provided for @welcomeCategoryModeFlatFeature1.
  ///
  /// In en, this message translates to:
  /// **'Flat structure, easy to use'**
  String get welcomeCategoryModeFlatFeature1;

  /// No description provided for @welcomeCategoryModeFlatFeature2.
  ///
  /// In en, this message translates to:
  /// **'Perfect for simple categorization'**
  String get welcomeCategoryModeFlatFeature2;

  /// No description provided for @welcomeCategoryModeFlatFeature3.
  ///
  /// In en, this message translates to:
  /// **'Quick selection, efficient tracking'**
  String get welcomeCategoryModeFlatFeature3;

  /// No description provided for @welcomeCategoryModeHierarchicalTitle.
  ///
  /// In en, this message translates to:
  /// **'Hierarchical Categories'**
  String get welcomeCategoryModeHierarchicalTitle;

  /// No description provided for @welcomeCategoryModeHierarchicalDescription.
  ///
  /// In en, this message translates to:
  /// **'Detailed management'**
  String get welcomeCategoryModeHierarchicalDescription;

  /// No description provided for @welcomeCategoryModeHierarchicalFeature1.
  ///
  /// In en, this message translates to:
  /// **'Support parent-child category levels'**
  String get welcomeCategoryModeHierarchicalFeature1;

  /// No description provided for @welcomeCategoryModeHierarchicalFeature2.
  ///
  /// In en, this message translates to:
  /// **'More detailed transaction classification'**
  String get welcomeCategoryModeHierarchicalFeature2;

  /// No description provided for @welcomeCategoryModeHierarchicalFeature3.
  ///
  /// In en, this message translates to:
  /// **'Perfect for detailed management'**
  String get welcomeCategoryModeHierarchicalFeature3;

  /// No description provided for @welcomeCategoryModeNoneTitle.
  ///
  /// In en, this message translates to:
  /// **'No Categories'**
  String get welcomeCategoryModeNoneTitle;

  /// No description provided for @welcomeCategoryModeNoneDescription.
  ///
  /// In en, this message translates to:
  /// **'Fully customizable, add as needed'**
  String get welcomeCategoryModeNoneDescription;

  /// No description provided for @welcomeCategoryModeNoneFeature1.
  ///
  /// In en, this message translates to:
  /// **'No preset categories'**
  String get welcomeCategoryModeNoneFeature1;

  /// No description provided for @welcomeCategoryModeNoneFeature2.
  ///
  /// In en, this message translates to:
  /// **'Create categories based on your needs'**
  String get welcomeCategoryModeNoneFeature2;

  /// No description provided for @welcomeCategoryModeNoneFeature3.
  ///
  /// In en, this message translates to:
  /// **'Perfect for custom classification needs'**
  String get welcomeCategoryModeNoneFeature3;

  /// No description provided for @welcomeExistingUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Existing User?'**
  String get welcomeExistingUserTitle;

  /// No description provided for @welcomeExistingUserButton.
  ///
  /// In en, this message translates to:
  /// **'Import Config'**
  String get welcomeExistingUserButton;

  /// No description provided for @welcomeImportingConfig.
  ///
  /// In en, this message translates to:
  /// **'Importing configuration...'**
  String get welcomeImportingConfig;

  /// No description provided for @welcomeImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Configuration imported successfully'**
  String get welcomeImportSuccess;

  /// No description provided for @welcomeImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String welcomeImportFailed(String error);

  /// No description provided for @welcomeImportNoFile.
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get welcomeImportNoFile;

  /// No description provided for @welcomeImportAttachmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Attachments'**
  String get welcomeImportAttachmentTitle;

  /// No description provided for @welcomeImportAttachmentDesc.
  ///
  /// In en, this message translates to:
  /// **'Would you like to import attachment files as well?'**
  String get welcomeImportAttachmentDesc;

  /// No description provided for @welcomeImportAttachmentButton.
  ///
  /// In en, this message translates to:
  /// **'Select Attachment File'**
  String get welcomeImportAttachmentButton;

  /// No description provided for @welcomeImportAttachmentSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get welcomeImportAttachmentSkip;

  /// No description provided for @welcomeImportAttachmentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Attachments imported: {imported}'**
  String welcomeImportAttachmentSuccess(int imported);

  /// No description provided for @welcomeImportAttachmentFailed.
  ///
  /// In en, this message translates to:
  /// **'Attachment import failed: {error}'**
  String welcomeImportAttachmentFailed(String error);

  /// No description provided for @welcomeImportingAttachment.
  ///
  /// In en, this message translates to:
  /// **'Importing attachments...'**
  String get welcomeImportingAttachment;

  /// No description provided for @iosVersionWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Requires iOS 16.0 or later'**
  String get iosVersionWarningTitle;

  /// No description provided for @iosVersionWarningDesc.
  ///
  /// In en, this message translates to:
  /// **'Screenshot auto-billing feature uses the App Intents framework introduced in iOS 16. Your device is running an older version and does not support this feature.\n\nPlease upgrade to iOS 16 or later to use this feature.'**
  String get iosVersionWarningDesc;

  /// No description provided for @aiChatTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiChatTitle;

  /// No description provided for @aiChatClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get aiChatClearHistory;

  /// No description provided for @aiChatClearHistoryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Conversation History'**
  String get aiChatClearHistoryDialogTitle;

  /// No description provided for @aiChatClearHistoryDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all conversation records? This action cannot be undone.'**
  String get aiChatClearHistoryDialogContent;

  /// No description provided for @aiChatInputHint.
  ///
  /// In en, this message translates to:
  /// **'e.g.: Bought a coffee for \$35'**
  String get aiChatInputHint;

  /// No description provided for @aiChatThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get aiChatThinking;

  /// No description provided for @aiChatHistoryCleared.
  ///
  /// In en, this message translates to:
  /// **'Conversation history cleared'**
  String get aiChatHistoryCleared;

  /// No description provided for @aiChatCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get aiChatCopy;

  /// No description provided for @aiChatCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get aiChatCopied;

  /// No description provided for @aiChatDeleteMessageConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this message?'**
  String get aiChatDeleteMessageConfirm;

  /// No description provided for @aiChatMessageDeleted.
  ///
  /// In en, this message translates to:
  /// **'Message deleted'**
  String get aiChatMessageDeleted;

  /// No description provided for @aiChatUndone.
  ///
  /// In en, this message translates to:
  /// **'Undone'**
  String get aiChatUndone;

  /// No description provided for @aiChatUndoFailed.
  ///
  /// In en, this message translates to:
  /// **'Undo failed'**
  String get aiChatUndoFailed;

  /// No description provided for @aiChatTransactionNotFound.
  ///
  /// In en, this message translates to:
  /// **'Transaction not found'**
  String get aiChatTransactionNotFound;

  /// No description provided for @aiChatOpenEditorFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open editor'**
  String get aiChatOpenEditorFailed;

  /// No description provided for @aiChatSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send'**
  String get aiChatSendFailed;

  /// No description provided for @billCardSuccess.
  ///
  /// In en, this message translates to:
  /// **'Booking Successful'**
  String get billCardSuccess;

  /// No description provided for @billCardUndone.
  ///
  /// In en, this message translates to:
  /// **'Undone'**
  String get billCardUndone;

  /// No description provided for @billCardAmount.
  ///
  /// In en, this message translates to:
  /// **'💰 Amount'**
  String get billCardAmount;

  /// No description provided for @billCardCategory.
  ///
  /// In en, this message translates to:
  /// **'🏷️ Category'**
  String get billCardCategory;

  /// No description provided for @billCardTime.
  ///
  /// In en, this message translates to:
  /// **'📅 Time'**
  String get billCardTime;

  /// No description provided for @billCardNote.
  ///
  /// In en, this message translates to:
  /// **'📝 Note'**
  String get billCardNote;

  /// No description provided for @billCardAccount.
  ///
  /// In en, this message translates to:
  /// **'💳 Account'**
  String get billCardAccount;

  /// No description provided for @billCardUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get billCardUndo;

  /// No description provided for @billCardEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get billCardEdit;

  /// No description provided for @donationTitle.
  ///
  /// In en, this message translates to:
  /// **'Donate'**
  String get donationTitle;

  /// No description provided for @donationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Buy me a coffee'**
  String get donationSubtitle;

  /// No description provided for @donationEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Support continued development'**
  String get donationEntrySubtitle;

  /// No description provided for @donationDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get donationDescription;

  /// No description provided for @donationDescriptionDetail.
  ///
  /// In en, this message translates to:
  /// **'Thank you for using BeeCount! If this app helps you, feel free to buy the developer a coffee as encouragement. Your support is my motivation to keep improving.'**
  String get donationDescriptionDetail;

  /// No description provided for @donationNoFeatures.
  ///
  /// In en, this message translates to:
  /// **'Note: Donations will not unlock any features. All features remain completely free.'**
  String get donationNoFeatures;

  /// No description provided for @donationNoProducts.
  ///
  /// In en, this message translates to:
  /// **'No products available'**
  String get donationNoProducts;

  /// No description provided for @donationThankYouTitle.
  ///
  /// In en, this message translates to:
  /// **'Thank You!'**
  String get donationThankYouTitle;

  /// No description provided for @donationThankYouMessage.
  ///
  /// In en, this message translates to:
  /// **'Thank you for purchasing {productName}! Your support means a lot to me. I will continue to improve BeeCount to make it even better!'**
  String donationThankYouMessage(String productName);

  /// No description provided for @aiQuickCommandFinancialHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial Health Analysis'**
  String get aiQuickCommandFinancialHealthTitle;

  /// No description provided for @aiQuickCommandFinancialHealthDesc.
  ///
  /// In en, this message translates to:
  /// **'Analyze income-expense balance and savings rate'**
  String get aiQuickCommandFinancialHealthDesc;

  /// No description provided for @aiQuickCommandFinancialHealthPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please analyze my financial health based on the following data:\n\n[monthlyStats]\n\n[recentTrends]\n\nPlease provide professional analysis and suggestions from the perspectives of income-expense balance, savings rate, and spending trends. Please respond in English.'**
  String get aiQuickCommandFinancialHealthPrompt;

  /// No description provided for @aiQuickCommandMonthlyExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly Expense Summary'**
  String get aiQuickCommandMonthlyExpenseTitle;

  /// No description provided for @aiQuickCommandMonthlyExpenseDesc.
  ///
  /// In en, this message translates to:
  /// **'Monthly expense analysis and recommendations'**
  String get aiQuickCommandMonthlyExpenseDesc;

  /// No description provided for @aiQuickCommandMonthlyExpensePrompt.
  ///
  /// In en, this message translates to:
  /// **'Please summarize my monthly expenses based on the following data:\n\n[monthlyStats]\n\n[categoryStats]\n\nPlease analyze which categories account for the highest proportion and provide optimization suggestions. Please respond in English.'**
  String get aiQuickCommandMonthlyExpensePrompt;

  /// No description provided for @aiQuickCommandCategoryAnalysisTitle.
  ///
  /// In en, this message translates to:
  /// **'Category Analysis'**
  String get aiQuickCommandCategoryAnalysisTitle;

  /// No description provided for @aiQuickCommandCategoryAnalysisDesc.
  ///
  /// In en, this message translates to:
  /// **'Analyze spending distribution by category'**
  String get aiQuickCommandCategoryAnalysisDesc;

  /// No description provided for @aiQuickCommandCategoryAnalysisPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please analyze my spending by category based on the following data:\n\n[categoryStats]\n\nPlease point out whether there are unreasonable spending ratios and provide optimization suggestions. Please respond in English.'**
  String get aiQuickCommandCategoryAnalysisPrompt;

  /// No description provided for @aiQuickCommandBudgetPlanningTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget Planning'**
  String get aiQuickCommandBudgetPlanningTitle;

  /// No description provided for @aiQuickCommandBudgetPlanningDesc.
  ///
  /// In en, this message translates to:
  /// **'Smart budget recommendations'**
  String get aiQuickCommandBudgetPlanningDesc;

  /// No description provided for @aiQuickCommandBudgetPlanningPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please help me plan a reasonable budget based on the following data:\n\n[monthlyStats]\n\n[recentTrends]\n\nPlease provide specific budget amounts and execution suggestions for each category. Please respond in English.'**
  String get aiQuickCommandBudgetPlanningPrompt;

  /// No description provided for @aiQuickCommandAbnormalExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Abnormal Expense Alert'**
  String get aiQuickCommandAbnormalExpenseTitle;

  /// No description provided for @aiQuickCommandAbnormalExpenseDesc.
  ///
  /// In en, this message translates to:
  /// **'Identify unusual spending'**
  String get aiQuickCommandAbnormalExpenseDesc;

  /// No description provided for @aiQuickCommandAbnormalExpensePrompt.
  ///
  /// In en, this message translates to:
  /// **'Please check if there are any abnormal expenses based on the following data:\n\n[recentTransactions]\n\n[monthlyStats]\n\nPlease identify significantly higher expenses than usual and provide analysis. Please respond in English.'**
  String get aiQuickCommandAbnormalExpensePrompt;

  /// No description provided for @aiQuickCommandSavingTipsTitle.
  ///
  /// In en, this message translates to:
  /// **'Saving Tips'**
  String get aiQuickCommandSavingTipsTitle;

  /// No description provided for @aiQuickCommandSavingTipsDesc.
  ///
  /// In en, this message translates to:
  /// **'Personalized money-saving suggestions'**
  String get aiQuickCommandSavingTipsDesc;

  /// No description provided for @aiQuickCommandSavingTipsPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please provide practical money-saving suggestions based on the following data:\n\n[categoryStats]\n\n[recentTrends]\n\nPlease give 3-5 specific and actionable suggestions. Please respond in English.'**
  String get aiQuickCommandSavingTipsPrompt;

  /// No description provided for @billCardUnknownLedger.
  ///
  /// In en, this message translates to:
  /// **'Unknown Ledger'**
  String get billCardUnknownLedger;

  /// No description provided for @aiPromptEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Prompt Editor'**
  String get aiPromptEditTitle;

  /// No description provided for @aiPromptEditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customize AI bill recognition prompt'**
  String get aiPromptEditSubtitle;

  /// No description provided for @aiPromptAdvancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get aiPromptAdvancedSettings;

  /// No description provided for @aiAdvancedSettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Model selection, strategy, local model, prompt'**
  String get aiAdvancedSettingsDesc;

  /// No description provided for @aiPromptEditEntry.
  ///
  /// In en, this message translates to:
  /// **'Prompt Editor'**
  String get aiPromptEditEntry;

  /// No description provided for @aiPromptEditEntryDesc.
  ///
  /// In en, this message translates to:
  /// **'Customize AI bill recognition prompt, shareable with others'**
  String get aiPromptEditEntryDesc;

  /// No description provided for @aiPromptVariables.
  ///
  /// In en, this message translates to:
  /// **'Variables'**
  String get aiPromptVariables;

  /// No description provided for @aiPromptVariablesHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to view available variables'**
  String get aiPromptVariablesHint;

  /// No description provided for @aiPromptContent.
  ///
  /// In en, this message translates to:
  /// **'Prompt Content'**
  String get aiPromptContent;

  /// No description provided for @aiPromptUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Unsaved'**
  String get aiPromptUnsaved;

  /// No description provided for @aiPromptInputHint.
  ///
  /// In en, this message translates to:
  /// **'Enter prompt...'**
  String get aiPromptInputHint;

  /// No description provided for @aiPromptPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get aiPromptPreview;

  /// No description provided for @aiPromptSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get aiPromptSave;

  /// No description provided for @aiPromptSaved.
  ///
  /// In en, this message translates to:
  /// **'Prompt saved'**
  String get aiPromptSaved;

  /// No description provided for @aiPromptResetDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get aiPromptResetDefault;

  /// No description provided for @aiPromptResetConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get aiPromptResetConfirmTitle;

  /// No description provided for @aiPromptResetConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset to default prompt? Your custom content will be lost.'**
  String get aiPromptResetConfirmMessage;

  /// No description provided for @aiPromptPasted.
  ///
  /// In en, this message translates to:
  /// **'Pasted'**
  String get aiPromptPasted;

  /// No description provided for @aiPromptPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Prompt Preview'**
  String get aiPromptPreviewTitle;

  /// No description provided for @aiPromptPreviewNote.
  ///
  /// In en, this message translates to:
  /// **'Preview uses sample data for variables. Real data will be used at runtime.'**
  String get aiPromptPreviewNote;

  /// No description provided for @aiPromptVarInputSource.
  ///
  /// In en, this message translates to:
  /// **'Input source description, e.g. \"From the following payment bill text\"'**
  String get aiPromptVarInputSource;

  /// No description provided for @aiPromptVarCurrentTime.
  ///
  /// In en, this message translates to:
  /// **'Current date and time, e.g. \"2025-01-15 14:30\"'**
  String get aiPromptVarCurrentTime;

  /// No description provided for @aiPromptVarCurrentDate.
  ///
  /// In en, this message translates to:
  /// **'Current date, e.g. \"2025-01-15\"'**
  String get aiPromptVarCurrentDate;

  /// No description provided for @aiPromptVarOcrText.
  ///
  /// In en, this message translates to:
  /// **'User input text content'**
  String get aiPromptVarOcrText;

  /// No description provided for @aiPromptVarCategories.
  ///
  /// In en, this message translates to:
  /// **'Expense and income category list'**
  String get aiPromptVarCategories;

  /// No description provided for @aiPromptVarAccounts.
  ///
  /// In en, this message translates to:
  /// **'User\'s account list (may be empty)'**
  String get aiPromptVarAccounts;

  /// No description provided for @aiModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Text Reasoning Model'**
  String get aiModelTitle;

  /// No description provided for @aiVisionModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Vision Model'**
  String get aiVisionModelTitle;

  /// No description provided for @aiModelFast.
  ///
  /// In en, this message translates to:
  /// **'Faster'**
  String get aiModelFast;

  /// No description provided for @aiModelAccurate.
  ///
  /// In en, this message translates to:
  /// **'Accurate'**
  String get aiModelAccurate;

  /// No description provided for @aiModelSwitched.
  ///
  /// In en, this message translates to:
  /// **'Switched to {modelName}'**
  String aiModelSwitched(String modelName);

  /// No description provided for @aiCustomBaseUrlHelper.
  ///
  /// In en, this message translates to:
  /// **'Standard chat completion API URL, e.g. https://api.example.com/v1'**
  String get aiCustomBaseUrlHelper;

  /// No description provided for @aiTextModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Text Model'**
  String get aiTextModelTitle;

  /// No description provided for @aiAudioModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio Model'**
  String get aiAudioModelTitle;

  /// No description provided for @tagManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagManageTitle;

  /// No description provided for @tagManageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage transaction tags'**
  String get tagManageSubtitle;

  /// No description provided for @tagManageEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tags yet'**
  String get tagManageEmpty;

  /// No description provided for @tagManageEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add a tag'**
  String get tagManageEmptyHint;

  /// No description provided for @tagManageGenerateDefault.
  ///
  /// In en, this message translates to:
  /// **'Generate Default Tags'**
  String get tagManageGenerateDefault;

  /// No description provided for @tagManageGenerateDefaultConfirm.
  ///
  /// In en, this message translates to:
  /// **'Generate default tags? Existing tags with the same name will not be overwritten.'**
  String get tagManageGenerateDefaultConfirm;

  /// No description provided for @tagManageGenerateDefaultSuccess.
  ///
  /// In en, this message translates to:
  /// **'Default tags generated'**
  String get tagManageGenerateDefaultSuccess;

  /// No description provided for @tagEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Tag'**
  String get tagEditTitle;

  /// No description provided for @tagAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Tag'**
  String get tagAddTitle;

  /// No description provided for @tagNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Tag Name'**
  String get tagNameLabel;

  /// No description provided for @tagNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter tag name'**
  String get tagNameHint;

  /// No description provided for @tagNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Tag name is required'**
  String get tagNameRequired;

  /// No description provided for @tagNameDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Tag name already exists'**
  String get tagNameDuplicate;

  /// No description provided for @tagColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Tag Color'**
  String get tagColorLabel;

  /// No description provided for @tagCreateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Tag created'**
  String get tagCreateSuccess;

  /// No description provided for @tagUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Tag updated'**
  String get tagUpdateSuccess;

  /// No description provided for @tagDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Tag'**
  String get tagDeleteConfirmTitle;

  /// No description provided for @tagDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete tag \"{name}\"? This will not affect associated transactions.'**
  String tagDeleteConfirmMessage(String name);

  /// No description provided for @tagDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Tag deleted'**
  String get tagDeleteSuccess;

  /// No description provided for @tagSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Tags'**
  String get tagSelectTitle;

  /// No description provided for @tagSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Multiple selection'**
  String get tagSelectHint;

  /// No description provided for @tagSelectCreateNew.
  ///
  /// In en, this message translates to:
  /// **'Create New Tag'**
  String get tagSelectCreateNew;

  /// No description provided for @tagSelectRecentlyUsed.
  ///
  /// In en, this message translates to:
  /// **'Recently Used'**
  String get tagSelectRecentlyUsed;

  /// No description provided for @tagSelectAllTags.
  ///
  /// In en, this message translates to:
  /// **'All Tags'**
  String get tagSelectAllTags;

  /// No description provided for @tagTransactionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} transactions'**
  String tagTransactionCount(int count);

  /// No description provided for @tagDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Tag Details'**
  String get tagDetailTitle;

  /// No description provided for @tagDetailTotalCount.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get tagDetailTotalCount;

  /// No description provided for @tagDetailTotalExpense.
  ///
  /// In en, this message translates to:
  /// **'Total Expense'**
  String get tagDetailTotalExpense;

  /// No description provided for @tagDetailTotalIncome.
  ///
  /// In en, this message translates to:
  /// **'Total Income'**
  String get tagDetailTotalIncome;

  /// No description provided for @tagDetailTransactionList.
  ///
  /// In en, this message translates to:
  /// **'Related Transactions'**
  String get tagDetailTransactionList;

  /// No description provided for @tagDetailNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No related transactions'**
  String get tagDetailNoTransactions;

  /// No description provided for @tagDetailNoTransactionsHint.
  ///
  /// In en, this message translates to:
  /// **'Transactions with this tag will appear here'**
  String get tagDetailNoTransactionsHint;

  /// No description provided for @tagNotFound.
  ///
  /// In en, this message translates to:
  /// **'Tag not found'**
  String get tagNotFound;

  /// No description provided for @tagDefaultMeituan.
  ///
  /// In en, this message translates to:
  /// **'Meituan'**
  String get tagDefaultMeituan;

  /// No description provided for @tagDefaultEleme.
  ///
  /// In en, this message translates to:
  /// **'Eleme'**
  String get tagDefaultEleme;

  /// No description provided for @tagDefaultTaobao.
  ///
  /// In en, this message translates to:
  /// **'Taobao'**
  String get tagDefaultTaobao;

  /// No description provided for @tagDefaultJD.
  ///
  /// In en, this message translates to:
  /// **'JD.com'**
  String get tagDefaultJD;

  /// No description provided for @tagDefaultPDD.
  ///
  /// In en, this message translates to:
  /// **'Pinduoduo'**
  String get tagDefaultPDD;

  /// No description provided for @tagDefaultStarbucks.
  ///
  /// In en, this message translates to:
  /// **'Starbucks'**
  String get tagDefaultStarbucks;

  /// No description provided for @tagDefaultLuckin.
  ///
  /// In en, this message translates to:
  /// **'Luckin Coffee'**
  String get tagDefaultLuckin;

  /// No description provided for @tagDefaultMcDonalds.
  ///
  /// In en, this message translates to:
  /// **'McDonald\'s'**
  String get tagDefaultMcDonalds;

  /// No description provided for @tagDefaultKFC.
  ///
  /// In en, this message translates to:
  /// **'KFC'**
  String get tagDefaultKFC;

  /// No description provided for @tagDefaultHema.
  ///
  /// In en, this message translates to:
  /// **'Hema'**
  String get tagDefaultHema;

  /// No description provided for @tagDefaultSams.
  ///
  /// In en, this message translates to:
  /// **'Sam\'s Club'**
  String get tagDefaultSams;

  /// No description provided for @tagDefaultCostco.
  ///
  /// In en, this message translates to:
  /// **'Costco'**
  String get tagDefaultCostco;

  /// No description provided for @tagDefaultBusinessTrip.
  ///
  /// In en, this message translates to:
  /// **'Business Trip'**
  String get tagDefaultBusinessTrip;

  /// No description provided for @tagDefaultTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get tagDefaultTravel;

  /// No description provided for @tagDefaultDining.
  ///
  /// In en, this message translates to:
  /// **'Dining Out'**
  String get tagDefaultDining;

  /// No description provided for @tagDefaultOnlineShopping.
  ///
  /// In en, this message translates to:
  /// **'Online Shopping'**
  String get tagDefaultOnlineShopping;

  /// No description provided for @tagDefaultDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get tagDefaultDaily;

  /// No description provided for @tagDefaultReimbursement.
  ///
  /// In en, this message translates to:
  /// **'Reimbursable'**
  String get tagDefaultReimbursement;

  /// No description provided for @tagDefaultRefundable.
  ///
  /// In en, this message translates to:
  /// **'Refundable'**
  String get tagDefaultRefundable;

  /// No description provided for @tagDefaultRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get tagDefaultRefunded;

  /// No description provided for @tagDefaultVoiceBilling.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get tagDefaultVoiceBilling;

  /// No description provided for @tagDefaultImageBilling.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get tagDefaultImageBilling;

  /// No description provided for @tagDefaultCameraBilling.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get tagDefaultCameraBilling;

  /// No description provided for @tagDefaultAiBilling.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get tagDefaultAiBilling;

  /// No description provided for @tagShare.
  ///
  /// In en, this message translates to:
  /// **'Share Tags'**
  String get tagShare;

  /// No description provided for @tagImport.
  ///
  /// In en, this message translates to:
  /// **'Import Tags'**
  String get tagImport;

  /// No description provided for @tagClearUnused.
  ///
  /// In en, this message translates to:
  /// **'Clear Unused'**
  String get tagClearUnused;

  /// No description provided for @tagShareSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String tagShareSuccess(String path);

  /// No description provided for @tagShareSubject.
  ///
  /// In en, this message translates to:
  /// **'BeeCount Tags Configuration'**
  String get tagShareSubject;

  /// No description provided for @tagShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Share failed'**
  String get tagShareFailed;

  /// No description provided for @tagImportInvalidFile.
  ///
  /// In en, this message translates to:
  /// **'Please select a YAML file'**
  String get tagImportInvalidFile;

  /// No description provided for @tagImportNoTags.
  ///
  /// In en, this message translates to:
  /// **'No tags found in file'**
  String get tagImportNoTags;

  /// No description provided for @tagImportModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Import Mode'**
  String get tagImportModeTitle;

  /// No description provided for @tagImportModeMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get tagImportModeMerge;

  /// No description provided for @tagImportModeMergeDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep existing tags, add new ones'**
  String get tagImportModeMergeDesc;

  /// No description provided for @tagImportModeOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get tagImportModeOverwrite;

  /// No description provided for @tagImportModeOverwriteDesc.
  ///
  /// In en, this message translates to:
  /// **'Clear unused tags before import'**
  String get tagImportModeOverwriteDesc;

  /// No description provided for @tagImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Import successful'**
  String get tagImportSuccess;

  /// No description provided for @tagImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get tagImportFailed;

  /// No description provided for @tagClearUnusedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No unused tags'**
  String get tagClearUnusedEmpty;

  /// No description provided for @tagClearUnusedTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Unused Tags'**
  String get tagClearUnusedTitle;

  /// No description provided for @tagClearUnusedMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} unused tags?'**
  String tagClearUnusedMessage(int count);

  /// No description provided for @tagClearUnusedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} tags'**
  String tagClearUnusedSuccess(int count);

  /// No description provided for @tagClearUnusedFailed.
  ///
  /// In en, this message translates to:
  /// **'Clear failed'**
  String get tagClearUnusedFailed;

  /// No description provided for @homeSwitchLedger.
  ///
  /// In en, this message translates to:
  /// **'Select Ledger'**
  String get homeSwitchLedger;

  /// No description provided for @homeManageLedgers.
  ///
  /// In en, this message translates to:
  /// **'Manage Ledgers'**
  String get homeManageLedgers;

  /// No description provided for @budgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budgetTitle;

  /// No description provided for @budgetShowOnHome.
  ///
  /// In en, this message translates to:
  /// **'Show budget on home'**
  String get budgetShowOnHome;

  /// No description provided for @budgetEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'No budget set yet'**
  String get budgetEmptyHint;

  /// No description provided for @budgetAddTotal.
  ///
  /// In en, this message translates to:
  /// **'Add Total Budget'**
  String get budgetAddTotal;

  /// No description provided for @budgetMonthlyBudget.
  ///
  /// In en, this message translates to:
  /// **'Monthly Budget'**
  String get budgetMonthlyBudget;

  /// No description provided for @budgetUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get budgetUsed;

  /// No description provided for @budgetRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get budgetRemaining;

  /// No description provided for @budgetDaysRemaining.
  ///
  /// In en, this message translates to:
  /// **'{days} days remaining'**
  String budgetDaysRemaining(int days);

  /// No description provided for @budgetDailyAvailable.
  ///
  /// In en, this message translates to:
  /// **'Daily available {amount}'**
  String budgetDailyAvailable(String amount);

  /// No description provided for @budgetCategoryBudgets.
  ///
  /// In en, this message translates to:
  /// **'Category Budgets'**
  String get budgetCategoryBudgets;

  /// No description provided for @budgetEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Budget'**
  String get budgetEditTitle;

  /// No description provided for @budgetAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Budget'**
  String get budgetAddTitle;

  /// No description provided for @budgetTypeTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Budget'**
  String get budgetTypeTotalLabel;

  /// No description provided for @budgetTypeCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category Budget'**
  String get budgetTypeCategoryLabel;

  /// No description provided for @budgetAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Budget Amount'**
  String get budgetAmountLabel;

  /// No description provided for @budgetAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Enter budget amount'**
  String get budgetAmountHint;

  /// No description provided for @budgetCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Select Category'**
  String get budgetCategoryLabel;

  /// No description provided for @budgetCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'Select budget category'**
  String get budgetCategoryHint;

  /// No description provided for @budgetStartDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Start Day'**
  String get budgetStartDayLabel;

  /// No description provided for @budgetPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get budgetPeriodLabel;

  /// No description provided for @budgetSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Budget saved'**
  String get budgetSaveSuccess;

  /// No description provided for @budgetDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this budget?'**
  String get budgetDeleteConfirm;

  /// No description provided for @budgetDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Budget deleted'**
  String get budgetDeleteSuccess;

  /// No description provided for @attachmentAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Image'**
  String get attachmentAdd;

  /// No description provided for @attachmentTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get attachmentTakePhoto;

  /// No description provided for @attachmentChooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get attachmentChooseFromGallery;

  /// No description provided for @attachmentMaxReached.
  ///
  /// In en, this message translates to:
  /// **'Maximum attachments reached'**
  String get attachmentMaxReached;

  /// No description provided for @attachmentDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this attachment?'**
  String get attachmentDeleteConfirm;

  /// No description provided for @attachmentCount.
  ///
  /// In en, this message translates to:
  /// **'{count} images'**
  String attachmentCount(int count);

  /// No description provided for @commonDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get commonDeleted;

  /// No description provided for @attachmentExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Attachments'**
  String get attachmentExportTitle;

  /// No description provided for @attachmentExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export all attachments as a compressed file'**
  String get attachmentExportSubtitle;

  /// No description provided for @attachmentImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Attachments'**
  String get attachmentImportTitle;

  /// No description provided for @attachmentImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import attachments from a compressed file'**
  String get attachmentImportSubtitle;

  /// No description provided for @attachmentExportEmpty.
  ///
  /// In en, this message translates to:
  /// **'No attachments to export'**
  String get attachmentExportEmpty;

  /// No description provided for @attachmentExportProgress.
  ///
  /// In en, this message translates to:
  /// **'Exporting attachments ({current}/{total})'**
  String attachmentExportProgress(int current, int total);

  /// No description provided for @attachmentExportProgressDetail.
  ///
  /// In en, this message translates to:
  /// **'Exporting {attachmentCount} attachment(s) + {iconCount} icon(s) ({current}/{total})'**
  String attachmentExportProgressDetail(int attachmentCount, int iconCount, int current, int total);

  /// No description provided for @attachmentExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Attachments exported successfully'**
  String get attachmentExportSuccess;

  /// No description provided for @attachmentExportSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to: {path}'**
  String attachmentExportSavedTo(String path);

  /// No description provided for @attachmentImportConflictStrategy.
  ///
  /// In en, this message translates to:
  /// **'Conflict Strategy'**
  String get attachmentImportConflictStrategy;

  /// No description provided for @attachmentImportConflictSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip existing attachments'**
  String get attachmentImportConflictSkip;

  /// No description provided for @attachmentImportConflictOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite existing attachments'**
  String get attachmentImportConflictOverwrite;

  /// No description provided for @attachmentImportProgress.
  ///
  /// In en, this message translates to:
  /// **'Importing attachments ({current}/{total})'**
  String attachmentImportProgress(int current, int total);

  /// No description provided for @attachmentImportResult.
  ///
  /// In en, this message translates to:
  /// **'Imported {imported}, Skipped {skipped}, Overwritten {overwritten}, Failed {failed}'**
  String attachmentImportResult(int imported, int skipped, int overwritten, int failed);

  /// No description provided for @attachmentImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to import attachments'**
  String get attachmentImportFailed;

  /// No description provided for @attachmentArchiveInfo.
  ///
  /// In en, this message translates to:
  /// **'{count} attachments, exported on {date}'**
  String attachmentArchiveInfo(int count, String date);

  /// No description provided for @attachmentStartImport.
  ///
  /// In en, this message translates to:
  /// **'Start Import'**
  String get attachmentStartImport;

  /// No description provided for @attachmentPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview Attachments'**
  String get attachmentPreview;

  /// No description provided for @attachmentPreviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} images in total'**
  String attachmentPreviewSubtitle(int count);

  /// No description provided for @attachmentPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'No attachments'**
  String get attachmentPreviewEmpty;

  /// No description provided for @attachmentExportPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Preview'**
  String get attachmentExportPreviewTitle;

  /// No description provided for @attachmentImportPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Preview'**
  String get attachmentImportPreviewTitle;

  /// No description provided for @shortcutsGuide.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get shortcutsGuide;

  /// No description provided for @shortcutsGuideDesc.
  ///
  /// In en, this message translates to:
  /// **'Quick access to voice, camera billing, etc.'**
  String get shortcutsGuideDesc;

  /// No description provided for @shortcutsIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Billing'**
  String get shortcutsIntroTitle;

  /// No description provided for @shortcutsIntroDesc.
  ///
  /// In en, this message translates to:
  /// **'Use shortcuts to directly open voice billing, camera billing, and other features from your home screen without opening the app first.'**
  String get shortcutsIntroDesc;

  /// No description provided for @availableShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Available Shortcuts'**
  String get availableShortcuts;

  /// No description provided for @shortcutVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice Billing'**
  String get shortcutVoice;

  /// No description provided for @shortcutVoiceDesc.
  ///
  /// In en, this message translates to:
  /// **'Quickly record bills by voice'**
  String get shortcutVoiceDesc;

  /// No description provided for @shortcutImage.
  ///
  /// In en, this message translates to:
  /// **'Image Billing'**
  String get shortcutImage;

  /// No description provided for @shortcutImageDesc.
  ///
  /// In en, this message translates to:
  /// **'Recognize bills from gallery images'**
  String get shortcutImageDesc;

  /// No description provided for @shortcutCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera Billing'**
  String get shortcutCamera;

  /// No description provided for @shortcutCameraDesc.
  ///
  /// In en, this message translates to:
  /// **'Take photos to recognize bills'**
  String get shortcutCameraDesc;

  /// No description provided for @shortcutNewExpense.
  ///
  /// In en, this message translates to:
  /// **'Quick Expense'**
  String get shortcutNewExpense;

  /// No description provided for @shortcutNewExpenseDesc.
  ///
  /// In en, this message translates to:
  /// **'Open expense entry page directly'**
  String get shortcutNewExpenseDesc;

  /// No description provided for @shortcutNewIncome.
  ///
  /// In en, this message translates to:
  /// **'Quick Income'**
  String get shortcutNewIncome;

  /// No description provided for @shortcutNewIncomeDesc.
  ///
  /// In en, this message translates to:
  /// **'Open income entry page directly'**
  String get shortcutNewIncomeDesc;

  /// No description provided for @shortcutNewTransfer.
  ///
  /// In en, this message translates to:
  /// **'Quick Transfer'**
  String get shortcutNewTransfer;

  /// No description provided for @shortcutNewTransferDesc.
  ///
  /// In en, this message translates to:
  /// **'Open transfer entry page directly'**
  String get shortcutNewTransferDesc;

  /// No description provided for @shortcutUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'URL copied to clipboard'**
  String get shortcutUrlCopied;

  /// No description provided for @howToAddShortcut.
  ///
  /// In en, this message translates to:
  /// **'How to Add Shortcuts'**
  String get howToAddShortcut;

  /// No description provided for @iosShortcutStep1.
  ///
  /// In en, this message translates to:
  /// **'Open the Shortcuts app'**
  String get iosShortcutStep1;

  /// No description provided for @iosShortcutStep2.
  ///
  /// In en, this message translates to:
  /// **'Tap + in the upper right to create a new shortcut'**
  String get iosShortcutStep2;

  /// No description provided for @iosShortcutStep3.
  ///
  /// In en, this message translates to:
  /// **'Add \'Open URL\' action'**
  String get iosShortcutStep3;

  /// No description provided for @iosShortcutStep4.
  ///
  /// In en, this message translates to:
  /// **'Paste the copied URL (e.g., beecount://voice)'**
  String get iosShortcutStep4;

  /// No description provided for @iosShortcutStep5.
  ///
  /// In en, this message translates to:
  /// **'Save and add to home screen'**
  String get iosShortcutStep5;

  /// No description provided for @androidShortcutStep1.
  ///
  /// In en, this message translates to:
  /// **'Download a shortcut creator app (e.g., Shortcut Maker)'**
  String get androidShortcutStep1;

  /// No description provided for @androidShortcutStep2.
  ///
  /// In en, this message translates to:
  /// **'Select \'URL Shortcut\''**
  String get androidShortcutStep2;

  /// No description provided for @androidShortcutStep3.
  ///
  /// In en, this message translates to:
  /// **'Paste the copied URL (e.g., beecount://voice)'**
  String get androidShortcutStep3;

  /// No description provided for @androidShortcutStep4.
  ///
  /// In en, this message translates to:
  /// **'Set icon and name, then add to home screen'**
  String get androidShortcutStep4;

  /// No description provided for @shortcutsTip.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get shortcutsTip;

  /// No description provided for @shortcutsTipDesc.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts require AI features. Make sure AI is enabled and API Key is configured.'**
  String get shortcutsTipDesc;

  /// No description provided for @shortcutOpenShortcutsApp.
  ///
  /// In en, this message translates to:
  /// **'Open Shortcuts App'**
  String get shortcutOpenShortcutsApp;

  /// No description provided for @shortcutAutoAdd.
  ///
  /// In en, this message translates to:
  /// **'Auto Billing API'**
  String get shortcutAutoAdd;

  /// No description provided for @shortcutAutoAddDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically create bills via URL parameters. Works great with Shortcuts and automation tools.'**
  String get shortcutAutoAddDesc;

  /// No description provided for @shortcutAutoAddExample.
  ///
  /// In en, this message translates to:
  /// **'Example URL:'**
  String get shortcutAutoAddExample;

  /// No description provided for @shortcutAutoAddParams.
  ///
  /// In en, this message translates to:
  /// **'Supported parameters:'**
  String get shortcutAutoAddParams;

  /// No description provided for @shortcutParamAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount (required)'**
  String get shortcutParamAmount;

  /// No description provided for @shortcutParamType.
  ///
  /// In en, this message translates to:
  /// **'Type: expense / income / transfer'**
  String get shortcutParamType;

  /// No description provided for @shortcutParamCategory.
  ///
  /// In en, this message translates to:
  /// **'Category name (must match existing category)'**
  String get shortcutParamCategory;

  /// No description provided for @shortcutParamNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get shortcutParamNote;

  /// No description provided for @shortcutParamAccount.
  ///
  /// In en, this message translates to:
  /// **'Account name (must match existing account)'**
  String get shortcutParamAccount;

  /// No description provided for @shortcutParamTags.
  ///
  /// In en, this message translates to:
  /// **'Tags (comma separated)'**
  String get shortcutParamTags;

  /// No description provided for @shortcutParamDate.
  ///
  /// In en, this message translates to:
  /// **'Date (ISO format, e.g., 2024-01-15)'**
  String get shortcutParamDate;

  /// No description provided for @quickActionImage.
  ///
  /// In en, this message translates to:
  /// **'Photo Billing'**
  String get quickActionImage;

  /// No description provided for @quickActionCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera Billing'**
  String get quickActionCamera;

  /// No description provided for @quickActionVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice Billing'**
  String get quickActionVoice;

  /// No description provided for @quickActionAiChat.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get quickActionAiChat;

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTitle;

  /// No description provided for @calendarToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarToday;

  /// No description provided for @calendarNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions'**
  String get calendarNoTransactions;

  /// No description provided for @calendarAddTransaction.
  ///
  /// In en, this message translates to:
  /// **'Add entry on this day'**
  String get calendarAddTransaction;

  /// No description provided for @calendarAddTransactionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add a record on the selected day'**
  String get calendarAddTransactionTooltip;

  /// No description provided for @commonUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get commonUncategorized;

  /// No description provided for @commonSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get commonSaved;

  /// No description provided for @aiProviderManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Provider Management'**
  String get aiProviderManageTitle;

  /// No description provided for @aiProviderManageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage AI service providers'**
  String get aiProviderManageSubtitle;

  /// No description provided for @aiProviderAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Provider'**
  String get aiProviderAdd;

  /// No description provided for @aiProviderBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get aiProviderBuiltIn;

  /// No description provided for @aiProviderEmpty.
  ///
  /// In en, this message translates to:
  /// **'No providers configured'**
  String get aiProviderEmpty;

  /// No description provided for @aiProviderNoApiKey.
  ///
  /// In en, this message translates to:
  /// **'API Key not configured'**
  String get aiProviderNoApiKey;

  /// No description provided for @aiProviderTapToEdit.
  ///
  /// In en, this message translates to:
  /// **'Tap to edit'**
  String get aiProviderTapToEdit;

  /// No description provided for @aiProviderDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Provider'**
  String get aiProviderDeleteTitle;

  /// No description provided for @aiProviderDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete provider \"{name}\"? Capabilities using this provider will switch to default.'**
  String aiProviderDeleteConfirm(String name);

  /// No description provided for @aiProviderDeleted.
  ///
  /// In en, this message translates to:
  /// **'Provider deleted'**
  String get aiProviderDeleted;

  /// No description provided for @aiProviderEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Provider'**
  String get aiProviderEditTitle;

  /// No description provided for @aiProviderAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Provider'**
  String get aiProviderAddTitle;

  /// No description provided for @aiProviderBasicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Info'**
  String get aiProviderBasicInfo;

  /// No description provided for @aiProviderName.
  ///
  /// In en, this message translates to:
  /// **'Provider Name'**
  String get aiProviderName;

  /// No description provided for @aiProviderNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., SiliconFlow, DeepSeek'**
  String get aiProviderNameHint;

  /// No description provided for @aiProviderNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter provider name'**
  String get aiProviderNameRequired;

  /// No description provided for @aiProviderBaseUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter Base URL'**
  String get aiProviderBaseUrlRequired;

  /// No description provided for @aiProviderModels.
  ///
  /// In en, this message translates to:
  /// **'Model Configuration'**
  String get aiProviderModels;

  /// No description provided for @aiProviderModelsHint.
  ///
  /// In en, this message translates to:
  /// **'Empty capabilities cannot use this provider'**
  String get aiProviderModelsHint;

  /// No description provided for @aiCapabilityText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get aiCapabilityText;

  /// No description provided for @aiCapabilityVision.
  ///
  /// In en, this message translates to:
  /// **'Vision'**
  String get aiCapabilityVision;

  /// No description provided for @aiCapabilitySpeech.
  ///
  /// In en, this message translates to:
  /// **'Speech'**
  String get aiCapabilitySpeech;

  /// No description provided for @aiCapabilitySelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Capability Binding'**
  String get aiCapabilitySelectTitle;

  /// No description provided for @aiCapabilitySelectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select provider for each AI capability'**
  String get aiCapabilitySelectSubtitle;

  /// No description provided for @aiCapabilityTextChat.
  ///
  /// In en, this message translates to:
  /// **'Text Chat'**
  String get aiCapabilityTextChat;

  /// No description provided for @aiCapabilityTextChatDesc.
  ///
  /// In en, this message translates to:
  /// **'For AI chat and text bill extraction'**
  String get aiCapabilityTextChatDesc;

  /// No description provided for @aiCapabilityImageUnderstand.
  ///
  /// In en, this message translates to:
  /// **'Image Understanding'**
  String get aiCapabilityImageUnderstand;

  /// No description provided for @aiCapabilityImageUnderstandDesc.
  ///
  /// In en, this message translates to:
  /// **'For image bill recognition'**
  String get aiCapabilityImageUnderstandDesc;

  /// No description provided for @aiCapabilitySpeechToText.
  ///
  /// In en, this message translates to:
  /// **'Speech to Text'**
  String get aiCapabilitySpeechToText;

  /// No description provided for @aiCapabilitySpeechToTextDesc.
  ///
  /// In en, this message translates to:
  /// **'For voice billing'**
  String get aiCapabilitySpeechToTextDesc;

  /// No description provided for @aiProviderTestRun.
  ///
  /// In en, this message translates to:
  /// **'Tap to test'**
  String get aiProviderTestRun;

  /// No description provided for @aiProviderTestRunning.
  ///
  /// In en, this message translates to:
  /// **'Testing...'**
  String get aiProviderTestRunning;

  /// No description provided for @aiProviderTestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Test passed'**
  String get aiProviderTestSuccess;

  /// No description provided for @aiProviderTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Test failed'**
  String get aiProviderTestFailed;

  /// No description provided for @aiProviderTestAll.
  ///
  /// In en, this message translates to:
  /// **'Test All'**
  String get aiProviderTestAll;

  /// No description provided for @aiProviderTestAllRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry Test'**
  String get aiProviderTestAllRetry;

  /// No description provided for @aiModelInputHelper.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use default model'**
  String get aiModelInputHelper;

  /// No description provided for @syncPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Preview'**
  String get syncPreviewTitle;

  /// No description provided for @syncPreviewSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get syncPreviewSelectAll;

  /// No description provided for @syncPreviewDeselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get syncPreviewDeselectAll;

  /// No description provided for @syncPreviewAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get syncPreviewAdded;

  /// No description provided for @syncPreviewModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get syncPreviewModified;

  /// No description provided for @syncPreviewDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get syncPreviewDeleted;

  /// No description provided for @syncPreviewAddedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} added'**
  String syncPreviewAddedCount(int count);

  /// No description provided for @syncPreviewModifiedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} modified'**
  String syncPreviewModifiedCount(int count);

  /// No description provided for @syncPreviewDeletedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} deleted'**
  String syncPreviewDeletedCount(int count);

  /// No description provided for @syncPreviewApply.
  ///
  /// In en, this message translates to:
  /// **'Apply {count} items'**
  String syncPreviewApply(int count);

  /// No description provided for @syncPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Cloud data matches local, no sync needed'**
  String get syncPreviewEmpty;

  /// No description provided for @syncPreviewOldFormat.
  ///
  /// In en, this message translates to:
  /// **'Old cloud format, full replace required'**
  String get syncPreviewOldFormat;

  /// No description provided for @syncPreviewOldFormatMessage.
  ///
  /// In en, this message translates to:
  /// **'Cloud data does not contain sync IDs. Local data will be cleared and re-imported from cloud.'**
  String get syncPreviewOldFormatMessage;

  /// No description provided for @syncPreviewApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied {count} changes'**
  String syncPreviewApplied(int count);

  /// No description provided for @cloudSyncGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync Guide'**
  String get cloudSyncGuideTitle;

  /// No description provided for @cloudSyncGuideGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get cloudSyncGuideGotIt;

  /// No description provided for @cloudSyncGuideHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get cloudSyncGuideHowItWorks;

  /// No description provided for @cloudSyncGuideHowItem1.
  ///
  /// In en, this message translates to:
  /// **'Upload: packages all current ledger data and uploads to cloud, replacing old cloud data'**
  String get cloudSyncGuideHowItem1;

  /// No description provided for @cloudSyncGuideHowItem2.
  ///
  /// In en, this message translates to:
  /// **'Download: fetches cloud data and compares with local records one by one — you choose which changes to apply'**
  String get cloudSyncGuideHowItem2;

  /// No description provided for @cloudSyncGuideHowItem3.
  ///
  /// In en, this message translates to:
  /// **'The cloud always stores only the last uploaded snapshot, no version history'**
  String get cloudSyncGuideHowItem3;

  /// No description provided for @cloudSyncGuideCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct usage'**
  String get cloudSyncGuideCorrect;

  /// No description provided for @cloudSyncGuideCorrectItem1.
  ///
  /// In en, this message translates to:
  /// **'Edit on one device at a time, upload when done'**
  String get cloudSyncGuideCorrectItem1;

  /// No description provided for @cloudSyncGuideCorrectItem2.
  ///
  /// In en, this message translates to:
  /// **'Download on the new device before starting to edit'**
  String get cloudSyncGuideCorrectItem2;

  /// No description provided for @cloudSyncGuideCorrectItem3.
  ///
  /// In en, this message translates to:
  /// **'Review the preview carefully before applying changes'**
  String get cloudSyncGuideCorrectItem3;

  /// No description provided for @cloudSyncGuideCorrectItem4.
  ///
  /// In en, this message translates to:
  /// **'Follow the pattern: edit → upload → switch device → download → edit'**
  String get cloudSyncGuideCorrectItem4;

  /// No description provided for @cloudSyncGuideWrong.
  ///
  /// In en, this message translates to:
  /// **'What to avoid'**
  String get cloudSyncGuideWrong;

  /// No description provided for @cloudSyncGuideWrongItem1.
  ///
  /// In en, this message translates to:
  /// **'Editing the same ledger on two devices simultaneously — the later upload overwrites the earlier one'**
  String get cloudSyncGuideWrongItem1;

  /// No description provided for @cloudSyncGuideWrongItem2.
  ///
  /// In en, this message translates to:
  /// **'Downloading immediately after upload — cloud services may have seconds to minutes of sync delay, wait a moment'**
  String get cloudSyncGuideWrongItem2;

  /// No description provided for @cloudSyncGuideWrongItem3.
  ///
  /// In en, this message translates to:
  /// **'Going long periods without syncing then downloading many changes at once — easy to miss important differences'**
  String get cloudSyncGuideWrongItem3;

  /// No description provided for @cloudSyncGuideLimitations.
  ///
  /// In en, this message translates to:
  /// **'Known limitations'**
  String get cloudSyncGuideLimitations;

  /// No description provided for @cloudSyncGuideLimitItem1.
  ///
  /// In en, this message translates to:
  /// **'Not real-time: requires manually tapping upload and download'**
  String get cloudSyncGuideLimitItem1;

  /// No description provided for @cloudSyncGuideLimitItem2.
  ///
  /// In en, this message translates to:
  /// **'No conflict merging: does not auto-merge edits from both sides — last upload wins'**
  String get cloudSyncGuideLimitItem2;

  /// No description provided for @cloudSyncGuideLimitItem3.
  ///
  /// In en, this message translates to:
  /// **'Cloud service delay: uploaded files may take seconds to minutes before other devices can read them, depending on your cloud provider'**
  String get cloudSyncGuideLimitItem3;

  /// No description provided for @cloudSyncGuideLimitItem4.
  ///
  /// In en, this message translates to:
  /// **'Excludes attachments: transaction image attachments are not synced — export separately via Data Management'**
  String get cloudSyncGuideLimitItem4;

  /// No description provided for @mineMultiDeviceSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-device Sync'**
  String get mineMultiDeviceSyncTitle;

  /// No description provided for @mineMultiDeviceSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-check cloud changes when entering page'**
  String get mineMultiDeviceSyncSubtitle;

  /// No description provided for @appLockTitle.
  ///
  /// In en, this message translates to:
  /// **'App Lock'**
  String get appLockTitle;

  /// No description provided for @appLockDesc.
  ///
  /// In en, this message translates to:
  /// **'PIN & biometric to protect privacy'**
  String get appLockDesc;

  /// No description provided for @appLockEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable App Lock'**
  String get appLockEnable;

  /// No description provided for @appLockEnableDesc.
  ///
  /// In en, this message translates to:
  /// **'Require authentication on launch and resume'**
  String get appLockEnableDesc;

  /// No description provided for @appLockSetPin.
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get appLockSetPin;

  /// No description provided for @appLockChangePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get appLockChangePin;

  /// No description provided for @appLockVerifyPin.
  ///
  /// In en, this message translates to:
  /// **'Verify PIN'**
  String get appLockVerifyPin;

  /// No description provided for @appLockVerifyCurrentPin.
  ///
  /// In en, this message translates to:
  /// **'Enter current PIN'**
  String get appLockVerifyCurrentPin;

  /// No description provided for @appLockSetNewPin.
  ///
  /// In en, this message translates to:
  /// **'Set new PIN'**
  String get appLockSetNewPin;

  /// No description provided for @appLockConfirmPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get appLockConfirmPin;

  /// No description provided for @appLockEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get appLockEnterPin;

  /// No description provided for @appLockPinSetSuccess.
  ///
  /// In en, this message translates to:
  /// **'PIN set successfully'**
  String get appLockPinSetSuccess;

  /// No description provided for @appLockDisabled.
  ///
  /// In en, this message translates to:
  /// **'App Lock disabled'**
  String get appLockDisabled;

  /// No description provided for @appLockBiometric.
  ///
  /// In en, this message translates to:
  /// **'Biometric Unlock'**
  String get appLockBiometric;

  /// No description provided for @appLockBiometricDesc.
  ///
  /// In en, this message translates to:
  /// **'Use Face ID or fingerprint to unlock'**
  String get appLockBiometricDesc;

  /// No description provided for @appLockBiometricReason.
  ///
  /// In en, this message translates to:
  /// **'Verify identity to unlock Bee Accounting'**
  String get appLockBiometricReason;

  /// No description provided for @appLockTimeout.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock Timeout'**
  String get appLockTimeout;

  /// No description provided for @appLockTimeoutImmediate.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get appLockTimeoutImmediate;

  /// No description provided for @appLockTimeout1Min.
  ///
  /// In en, this message translates to:
  /// **'After 1 minute'**
  String get appLockTimeout1Min;

  /// No description provided for @appLockTimeout5Min.
  ///
  /// In en, this message translates to:
  /// **'After 5 minutes'**
  String get appLockTimeout5Min;

  /// No description provided for @appLockTimeout15Min.
  ///
  /// In en, this message translates to:
  /// **'After 15 minutes'**
  String get appLockTimeout15Min;

  /// No description provided for @creditCardSettings.
  ///
  /// In en, this message translates to:
  /// **'Credit Card Settings'**
  String get creditCardSettings;

  /// No description provided for @creditLimit.
  ///
  /// In en, this message translates to:
  /// **'Credit Limit'**
  String get creditLimit;

  /// No description provided for @creditLimitHint.
  ///
  /// In en, this message translates to:
  /// **'Enter credit limit'**
  String get creditLimitHint;

  /// No description provided for @billingDay.
  ///
  /// In en, this message translates to:
  /// **'Billing Day'**
  String get billingDay;

  /// No description provided for @paymentDueDay.
  ///
  /// In en, this message translates to:
  /// **'Payment Due Day'**
  String get paymentDueDay;

  /// No description provided for @creditUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get creditUsed;

  /// No description provided for @creditAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get creditAvailable;

  /// No description provided for @creditCardOwed.
  ///
  /// In en, this message translates to:
  /// **'Owed'**
  String get creditCardOwed;

  /// No description provided for @dayOfMonth.
  ///
  /// In en, this message translates to:
  /// **'{day}th of each month'**
  String dayOfMonth(int day);

  /// No description provided for @creditCardReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Reminder'**
  String get creditCardReminderTitle;

  /// No description provided for @creditCardReminderDesc.
  ///
  /// In en, this message translates to:
  /// **'Remind before payment due date'**
  String get creditCardReminderDesc;

  /// No description provided for @creditCardReminderDaysBefore.
  ///
  /// In en, this message translates to:
  /// **'{days} days before'**
  String creditCardReminderDaysBefore(int days);

  /// No description provided for @creditCardInitialBalanceHint.
  ///
  /// In en, this message translates to:
  /// **'Current debt (negative number)'**
  String get creditCardInitialBalanceHint;

  /// No description provided for @selectDay.
  ///
  /// In en, this message translates to:
  /// **'Select Day'**
  String get selectDay;

  /// No description provided for @accountBankName.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get accountBankName;

  /// No description provided for @accountBankNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. ICBC'**
  String get accountBankNameHint;

  /// No description provided for @accountCardLastFour.
  ///
  /// In en, this message translates to:
  /// **'Last 4 Digits'**
  String get accountCardLastFour;

  /// No description provided for @accountCardLastFourHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 1234'**
  String get accountCardLastFourHint;

  /// No description provided for @accountNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get accountNote;

  /// No description provided for @accountNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note'**
  String get accountNoteHint;

  /// No description provided for @accountMetaInfo.
  ///
  /// In en, this message translates to:
  /// **'Account Info'**
  String get accountMetaInfo;

  /// No description provided for @accountBalanceTrend.
  ///
  /// In en, this message translates to:
  /// **'Balance Trend'**
  String get accountBalanceTrend;

  /// No description provided for @accountCategoryBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Category Breakdown'**
  String get accountCategoryBreakdown;

  /// No description provided for @accountCategoryExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get accountCategoryExpense;

  /// No description provided for @accountCategoryIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get accountCategoryIncome;

  /// No description provided for @accountNoMoreData.
  ///
  /// In en, this message translates to:
  /// **'No more data'**
  String get accountNoMoreData;

  /// No description provided for @totalAssets.
  ///
  /// In en, this message translates to:
  /// **'Total Assets'**
  String get totalAssets;

  /// No description provided for @totalLiabilities.
  ///
  /// In en, this message translates to:
  /// **'Total Liabilities'**
  String get totalLiabilities;

  /// No description provided for @assetAccounts.
  ///
  /// In en, this message translates to:
  /// **'Asset Accounts'**
  String get assetAccounts;

  /// No description provided for @liabilityAccounts.
  ///
  /// In en, this message translates to:
  /// **'Liability Accounts'**
  String get liabilityAccounts;

  /// No description provided for @assetComposition.
  ///
  /// In en, this message translates to:
  /// **'Asset Composition'**
  String get assetComposition;

  /// No description provided for @accountTypeInvestment.
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get accountTypeInvestment;

  /// No description provided for @accountTypeLoan.
  ///
  /// In en, this message translates to:
  /// **'Loan'**
  String get accountTypeLoan;

  /// No description provided for @accountTypeReceivable.
  ///
  /// In en, this message translates to:
  /// **'Receivable'**
  String get accountTypeReceivable;

  /// No description provided for @accountTypeRealEstate.
  ///
  /// In en, this message translates to:
  /// **'Real Estate'**
  String get accountTypeRealEstate;

  /// No description provided for @accountTypeVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get accountTypeVehicle;

  /// No description provided for @accountTypeInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get accountTypeInsurance;

  /// No description provided for @accountTypeSocialFund.
  ///
  /// In en, this message translates to:
  /// **'Social Fund'**
  String get accountTypeSocialFund;

  /// No description provided for @valuationCurrentValue.
  ///
  /// In en, this message translates to:
  /// **'Current Valuation'**
  String get valuationCurrentValue;

  /// No description provided for @valuationCurrentDebt.
  ///
  /// In en, this message translates to:
  /// **'Current Debt'**
  String get valuationCurrentDebt;

  /// No description provided for @valuationUpdateValue.
  ///
  /// In en, this message translates to:
  /// **'Update Valuation'**
  String get valuationUpdateValue;

  /// No description provided for @valuationUpdateDebt.
  ///
  /// In en, this message translates to:
  /// **'Update Debt'**
  String get valuationUpdateDebt;

  /// No description provided for @valuationLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated: {date}'**
  String valuationLastUpdated(String date);

  /// No description provided for @valuationAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Enter current valuation'**
  String get valuationAccountHint;

  /// No description provided for @valuationDebtHint.
  ///
  /// In en, this message translates to:
  /// **'Enter current debt amount'**
  String get valuationDebtHint;

  /// No description provided for @accountGroupTradable.
  ///
  /// In en, this message translates to:
  /// **'Daily Accounts'**
  String get accountGroupTradable;

  /// No description provided for @accountGroupValuation.
  ///
  /// In en, this message translates to:
  /// **'Assets/Liabilities'**
  String get accountGroupValuation;

  /// No description provided for @adjustmentTransaction.
  ///
  /// In en, this message translates to:
  /// **'Valuation Adjustment'**
  String get adjustmentTransaction;

  /// No description provided for @creditCardBillingInfo.
  ///
  /// In en, this message translates to:
  /// **'Bills on {billingDay}th · Due on {paymentDueDay}th'**
  String creditCardBillingInfo(int billingDay, int paymentDueDay);

  /// No description provided for @creditCardDaysUntilPayment.
  ///
  /// In en, this message translates to:
  /// **'{days} days until payment due'**
  String creditCardDaysUntilPayment(int days);

  /// No description provided for @creditCardPaymentDueToday.
  ///
  /// In en, this message translates to:
  /// **'Payment due today'**
  String get creditCardPaymentDueToday;

  /// No description provided for @creditCardQuickRepay.
  ///
  /// In en, this message translates to:
  /// **'Record Repayment'**
  String get creditCardQuickRepay;

  /// No description provided for @budgetManagement.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budgetManagement;

  /// No description provided for @budgetManagementDesc.
  ///
  /// In en, this message translates to:
  /// **'Set monthly budget and control spending'**
  String get budgetManagementDesc;

  /// No description provided for @budgetSetupHint.
  ///
  /// In en, this message translates to:
  /// **'Set a budget to control monthly spending'**
  String get budgetSetupHint;

  /// No description provided for @budgetSetupAction.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get budgetSetupAction;

  /// No description provided for @cloudCollabDevicesPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Sessions'**
  String get cloudCollabDevicesPageTitle;

  /// No description provided for @cloudCollabDevicesPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage active devices'**
  String get cloudCollabDevicesPageSubtitle;

  /// No description provided for @cloudCollabDevicesViewAllSessions.
  ///
  /// In en, this message translates to:
  /// **'Show all sessions'**
  String get cloudCollabDevicesViewAllSessions;

  /// No description provided for @cloudCollabDevicesViewModeHint.
  ///
  /// In en, this message translates to:
  /// **'Default view shows deduped devices active in the last 30 days.'**
  String get cloudCollabDevicesViewModeHint;

  /// No description provided for @cloudCollabNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No active devices'**
  String get cloudCollabNoDevices;

  /// No description provided for @cloudCollabUnknownDeviceName.
  ///
  /// In en, this message translates to:
  /// **'Unknown Device'**
  String get cloudCollabUnknownDeviceName;

  /// No description provided for @cloudCollabDeviceCurrentTag.
  ///
  /// In en, this message translates to:
  /// **'Current Device'**
  String get cloudCollabDeviceCurrentTag;

  /// No description provided for @cloudCollabCurrentDeviceCannotRevoke.
  ///
  /// In en, this message translates to:
  /// **'Current device cannot be revoked.'**
  String get cloudCollabCurrentDeviceCannotRevoke;

  /// No description provided for @cloudCollabDeviceAppVersion.
  ///
  /// In en, this message translates to:
  /// **'App: {version}'**
  String cloudCollabDeviceAppVersion(String version);

  /// No description provided for @cloudCollabDeviceOsVersion.
  ///
  /// In en, this message translates to:
  /// **'OS: {version}'**
  String cloudCollabDeviceOsVersion(String version);

  /// No description provided for @cloudCollabDeviceModel.
  ///
  /// In en, this message translates to:
  /// **'Model: {model}'**
  String cloudCollabDeviceModel(String model);

  /// No description provided for @cloudCollabDeviceLastIp.
  ///
  /// In en, this message translates to:
  /// **'IP: {ip}'**
  String cloudCollabDeviceLastIp(String ip);

  /// No description provided for @cloudCollabDeviceSessionCount.
  ///
  /// In en, this message translates to:
  /// **'Sessions: {count}'**
  String cloudCollabDeviceSessionCount(String count);

  /// No description provided for @cloudCollabDeviceLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen: {time}'**
  String cloudCollabDeviceLastSeen(String time);

  /// No description provided for @cloudCollabDeviceCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Created: {time}'**
  String cloudCollabDeviceCreatedAt(String time);

  /// No description provided for @cloudCollabDeviceRevokeTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke Device'**
  String get cloudCollabDeviceRevokeTitle;

  /// No description provided for @cloudCollabDeviceRevokeMessage.
  ///
  /// In en, this message translates to:
  /// **'Revoke device {name} ({id})?'**
  String cloudCollabDeviceRevokeMessage(String name, String id);

  /// No description provided for @cloudCollabDeviceRevokeMultipleMessage.
  ///
  /// In en, this message translates to:
  /// **'Revoke {count} sessions for device {name}?'**
  String cloudCollabDeviceRevokeMultipleMessage(String name, String count);

  /// No description provided for @cloudCollabDeviceRevoked.
  ///
  /// In en, this message translates to:
  /// **'Device revoked'**
  String get cloudCollabDeviceRevoked;

  /// No description provided for @cloudCollabUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync is unavailable.'**
  String get cloudCollabUnavailableMessage;

  /// No description provided for @cloudCollabScopeDeniedHint.
  ///
  /// In en, this message translates to:
  /// **'Server has not enabled ALLOW_APP_RW_SCOPES, so device sessions are unavailable.'**
  String get cloudCollabScopeDeniedHint;

  /// No description provided for @cloudCollabScopeDeniedAction.
  ///
  /// In en, this message translates to:
  /// **'Set ALLOW_APP_RW_SCOPES=true in server .env, restart the service, then sign in again.'**
  String get cloudCollabScopeDeniedAction;

  /// No description provided for @syncHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync status'**
  String get syncHealthTitle;

  /// No description provided for @syncHealthCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Check failed: {msg}'**
  String syncHealthCheckFailed(String msg);

  /// No description provided for @syncHealthHasDiff.
  ///
  /// In en, this message translates to:
  /// **'Diff detected; auto-synced'**
  String get syncHealthHasDiff;

  /// No description provided for @syncHealthInSync.
  ///
  /// In en, this message translates to:
  /// **'Local matches cloud'**
  String get syncHealthInSync;

  /// No description provided for @syncHealthGroupCurrentLedger.
  ///
  /// In en, this message translates to:
  /// **'Current ledger'**
  String get syncHealthGroupCurrentLedger;

  /// No description provided for @syncHealthGroupAll.
  ///
  /// In en, this message translates to:
  /// **'All ledgers'**
  String get syncHealthGroupAll;

  /// No description provided for @syncHealthRowTx.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get syncHealthRowTx;

  /// No description provided for @syncHealthRowAttachment.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get syncHealthRowAttachment;

  /// No description provided for @syncHealthRowCategoryIcon.
  ///
  /// In en, this message translates to:
  /// **'Category icons'**
  String get syncHealthRowCategoryIcon;

  /// No description provided for @syncHealthRowBudget.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get syncHealthRowBudget;

  /// No description provided for @syncHealthRowAccount.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get syncHealthRowAccount;

  /// No description provided for @syncHealthRowCategory.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get syncHealthRowCategory;

  /// No description provided for @syncHealthRowTag.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get syncHealthRowTag;

  /// No description provided for @syncHealthRowUnpushed.
  ///
  /// In en, this message translates to:
  /// **'Pending pushes'**
  String get syncHealthRowUnpushed;

  /// No description provided for @syncHealthValue.
  ///
  /// In en, this message translates to:
  /// **'Local {local} · Cloud {remote}'**
  String syncHealthValue(int local, int remote);

  /// No description provided for @syncHealthValueRemoteMissing.
  ///
  /// In en, this message translates to:
  /// **'Local {local} · Cloud —'**
  String syncHealthValueRemoteMissing(int local);

  /// No description provided for @twofaChallengeTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication'**
  String get twofaChallengeTitle;

  /// No description provided for @twofaMethodTotp.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get twofaMethodTotp;

  /// No description provided for @twofaMethodRecovery.
  ///
  /// In en, this message translates to:
  /// **'Recovery code'**
  String get twofaMethodRecovery;

  /// No description provided for @twofaTotpHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from your authenticator app (Google Authenticator / 1Password / Authy / etc).'**
  String get twofaTotpHint;

  /// No description provided for @twofaRecoveryHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a recovery code saved when you enabled 2FA (e.g. abcd-efgh). Each code works once.'**
  String get twofaRecoveryHint;

  /// No description provided for @twofaTotpInputPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get twofaTotpInputPlaceholder;

  /// No description provided for @twofaRecoveryInputPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Recovery code'**
  String get twofaRecoveryInputPlaceholder;

  /// No description provided for @twofaCountdown.
  ///
  /// In en, this message translates to:
  /// **'Time remaining {time}'**
  String twofaCountdown(String time);

  /// No description provided for @twofaVerifyButton.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get twofaVerifyButton;

  /// No description provided for @twofaStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication'**
  String get twofaStatusTitle;

  /// No description provided for @twofaStatusEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled ✓'**
  String get twofaStatusEnabled;

  /// No description provided for @twofaStatusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Not enabled'**
  String get twofaStatusDisabled;

  /// No description provided for @twofaStatusEnabledAt.
  ///
  /// In en, this message translates to:
  /// **'Enabled on {date}'**
  String twofaStatusEnabledAt(String date);

  /// No description provided for @twofaStatusManageHint.
  ///
  /// In en, this message translates to:
  /// **'Manage from the Web app (enable / disable / regenerate recovery codes)'**
  String get twofaStatusManageHint;

  /// No description provided for @twofaStatusOpenWeb.
  ///
  /// In en, this message translates to:
  /// **'Enable on the Web app →'**
  String get twofaStatusOpenWeb;

  /// No description provided for @sharedRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get sharedRoleOwner;

  /// No description provided for @sharedRoleEditor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get sharedRoleEditor;

  /// No description provided for @sharedRoleViewer.
  ///
  /// In en, this message translates to:
  /// **'Viewer'**
  String get sharedRoleViewer;

  /// No description provided for @commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get commonCopied;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @sharedJoinPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Join shared ledger'**
  String get sharedJoinPageTitle;

  /// No description provided for @sharedJoinPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter an invite code or tap a shared link'**
  String get sharedJoinPageSubtitle;

  /// No description provided for @sharedJoinEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter invite code'**
  String get sharedJoinEnterCode;

  /// No description provided for @sharedJoinEnterCodeHint.
  ///
  /// In en, this message translates to:
  /// **'6 uppercase letters / digits. You can also tap a share link to skip this step.'**
  String get sharedJoinEnterCodeHint;

  /// No description provided for @sharedJoinPreviewButton.
  ///
  /// In en, this message translates to:
  /// **'Verify code'**
  String get sharedJoinPreviewButton;

  /// No description provided for @sharedJoinAcceptButton.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get sharedJoinAcceptButton;

  /// No description provided for @sharedJoinInvitedBy.
  ///
  /// In en, this message translates to:
  /// **'{name} invited you to join'**
  String sharedJoinInvitedBy(String name);

  /// No description provided for @sharedJoinRoleLine.
  ///
  /// In en, this message translates to:
  /// **'Role: {role}'**
  String sharedJoinRoleLine(String role);

  /// No description provided for @sharedJoinExpiresInMinutes.
  ///
  /// In en, this message translates to:
  /// **'Expires in {n} min'**
  String sharedJoinExpiresInMinutes(int n);

  /// No description provided for @sharedJoinExpiresInHours.
  ///
  /// In en, this message translates to:
  /// **'Expires in {n}h'**
  String sharedJoinExpiresInHours(int n);

  /// No description provided for @sharedJoinExpiresInDays.
  ///
  /// In en, this message translates to:
  /// **'Expires in {n}d'**
  String sharedJoinExpiresInDays(int n);

  /// No description provided for @sharedJoinSuccess.
  ///
  /// In en, this message translates to:
  /// **'Joined \"{name}\"'**
  String sharedJoinSuccess(String name);

  /// No description provided for @sharedJoinCodeFormatError.
  ///
  /// In en, this message translates to:
  /// **'Invite code must be 6 letters/digits.'**
  String get sharedJoinCodeFormatError;

  /// No description provided for @sharedJoinInvalidOrExpired.
  ///
  /// In en, this message translates to:
  /// **'Invite code is invalid or expired. Ask the inviter for a new one.'**
  String get sharedJoinInvalidOrExpired;

  /// No description provided for @sharedJoinAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'You are already a member of this ledger.'**
  String get sharedJoinAlreadyMember;

  /// No description provided for @sharedJoinMemberLimit.
  ///
  /// In en, this message translates to:
  /// **'This ledger has reached its member limit. Ask the owner.'**
  String get sharedJoinMemberLimit;

  /// No description provided for @sharedInvitePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite new member'**
  String get sharedInvitePageTitle;

  /// No description provided for @sharedInviteFormRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get sharedInviteFormRole;

  /// No description provided for @sharedInviteFormExpiry.
  ///
  /// In en, this message translates to:
  /// **'Valid for'**
  String get sharedInviteFormExpiry;

  /// No description provided for @sharedInviteExpiryHours.
  ///
  /// In en, this message translates to:
  /// **'{n} h'**
  String sharedInviteExpiryHours(int n);

  /// No description provided for @sharedInviteExpiryDays.
  ///
  /// In en, this message translates to:
  /// **'{n} day'**
  String sharedInviteExpiryDays(int n);

  /// No description provided for @sharedInviteGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate invite code'**
  String get sharedInviteGenerate;

  /// No description provided for @sharedInviteGenerateAnother.
  ///
  /// In en, this message translates to:
  /// **'Generate another code'**
  String get sharedInviteGenerateAnother;

  /// No description provided for @sharedInviteCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get sharedInviteCopyCode;

  /// No description provided for @sharedInviteCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get sharedInviteCopyLink;

  /// No description provided for @sharedInviteShareLink.
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get sharedInviteShareLink;

  /// No description provided for @sharedInviteExpiresAt.
  ///
  /// In en, this message translates to:
  /// **'Expires at {dt}'**
  String sharedInviteExpiresAt(String dt);

  /// No description provided for @sharedInviteWarning.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Don\'t post invite codes to public groups / social. Anyone with the code can join. Revoke and regenerate from Members if leaked.'**
  String get sharedInviteWarning;

  /// No description provided for @sharedInviteInstruction.
  ///
  /// In en, this message translates to:
  /// **'Send the code or short link to the other person. After they install BeeCount, they can tap the link or enter the code from \"Me → Join shared ledger\".'**
  String get sharedInviteInstruction;

  /// No description provided for @sharedInviteShareText.
  ///
  /// In en, this message translates to:
  /// **'I\'m inviting you to BeeCount shared ledger \"{ledger}\".\n\nCode: {code}\nLink: {url}\n\nTap the link, or open BeeCount → Me → Join shared ledger and enter this code.'**
  String sharedInviteShareText(String ledger, String code, String url);

  /// No description provided for @sharedMembersPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get sharedMembersPageTitle;

  /// No description provided for @sharedMembersYou.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get sharedMembersYou;

  /// No description provided for @sharedMembersInviteCta.
  ///
  /// In en, this message translates to:
  /// **'Invite new member'**
  String get sharedMembersInviteCta;

  /// No description provided for @sharedMembersLeaveCta.
  ///
  /// In en, this message translates to:
  /// **'Leave ledger'**
  String get sharedMembersLeaveCta;

  /// No description provided for @sharedMembersLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave ledger'**
  String get sharedMembersLeaveTitle;

  /// No description provided for @sharedMembersLeaveConfirm.
  ///
  /// In en, this message translates to:
  /// **'After leaving \"{name}\" you won\'t be able to access its transactions. Continue?'**
  String sharedMembersLeaveConfirm(String name);

  /// No description provided for @sharedMembersLeaveDone.
  ///
  /// In en, this message translates to:
  /// **'Left the ledger'**
  String get sharedMembersLeaveDone;

  /// No description provided for @sharedMembersRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove member'**
  String get sharedMembersRemoveTitle;

  /// No description provided for @sharedMembersRemoveCta.
  ///
  /// In en, this message translates to:
  /// **'Remove this member'**
  String get sharedMembersRemoveCta;

  /// No description provided for @sharedMembersRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}? They will immediately lose access to this ledger.'**
  String sharedMembersRemoveConfirm(String name);

  /// No description provided for @sharedMembersRemoved.
  ///
  /// In en, this message translates to:
  /// **'Member removed'**
  String get sharedMembersRemoved;

  /// No description provided for @sharedMembersTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership'**
  String get sharedMembersTransferTitle;

  /// No description provided for @sharedMembersTransferTo.
  ///
  /// In en, this message translates to:
  /// **'Transfer to this member'**
  String get sharedMembersTransferTo;

  /// No description provided for @sharedMembersTransferConfirm.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership to {name}? You will become an editor and can no longer invite, rename, or delete the ledger.'**
  String sharedMembersTransferConfirm(String name);

  /// No description provided for @sharedMembersTransferConfirmCta.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get sharedMembersTransferConfirmCta;

  /// No description provided for @sharedMembersTransferDone.
  ///
  /// In en, this message translates to:
  /// **'Ownership transferred'**
  String get sharedMembersTransferDone;

  /// No description provided for @sharedTxRecordedBy.
  ///
  /// In en, this message translates to:
  /// **'recorded by {name}'**
  String sharedTxRecordedBy(String name);

  /// No description provided for @sharedTxCreatedBy.
  ///
  /// In en, this message translates to:
  /// **'Created by {name}'**
  String sharedTxCreatedBy(String name);

  /// No description provided for @sharedTxEditedBy.
  ///
  /// In en, this message translates to:
  /// **'Last edited by {name}'**
  String sharedTxEditedBy(String name);

  /// No description provided for @sharedTxCreatedAndEditedBy.
  ///
  /// In en, this message translates to:
  /// **'Created and edited by {name}'**
  String sharedTxCreatedAndEditedBy(String name);

  /// No description provided for @sharedRequiresCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Please enable cloud sync first'**
  String get sharedRequiresCloudSync;

  /// No description provided for @sharedMembersStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Member balances'**
  String get sharedMembersStatsTitle;

  /// No description provided for @sharedMembersStatsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get sharedMembersStatsEmpty;

  /// No description provided for @sharedMembersStatsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get sharedMembersStatsLoading;

  /// No description provided for @sharedMembersStatsIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get sharedMembersStatsIncome;

  /// No description provided for @sharedMembersStatsExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get sharedMembersStatsExpense;

  /// No description provided for @sharedMembersStatsTxCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tx'**
  String sharedMembersStatsTxCount(int count);

  /// No description provided for @maintenanceOrphanCleanupTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Cleanup'**
  String get maintenanceOrphanCleanupTitle;

  /// No description provided for @maintenanceOrphanCleanupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Detect and clean local orphan data'**
  String get maintenanceOrphanCleanupSubtitle;

  /// No description provided for @maintenanceOrphanRescan.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get maintenanceOrphanRescan;

  /// No description provided for @maintenanceOrphanEmpty.
  ///
  /// In en, this message translates to:
  /// **'Local data is clean, no orphan data found'**
  String get maintenanceOrphanEmpty;

  /// No description provided for @maintenanceOrphanGroupDb.
  ///
  /// In en, this message translates to:
  /// **'Database orphans'**
  String get maintenanceOrphanGroupDb;

  /// No description provided for @maintenanceOrphanGroupFile.
  ///
  /// In en, this message translates to:
  /// **'File orphans'**
  String get maintenanceOrphanGroupFile;

  /// No description provided for @maintenanceOrphanGroupSync.
  ///
  /// In en, this message translates to:
  /// **'Sync state orphans'**
  String get maintenanceOrphanGroupSync;

  /// No description provided for @maintenanceOrphanSummary.
  ///
  /// In en, this message translates to:
  /// **'Found {count} issue(s)'**
  String maintenanceOrphanSummary(int count);

  /// No description provided for @maintenanceOrphanSummarySize.
  ///
  /// In en, this message translates to:
  /// **'Reclaimable space ~ {size}'**
  String maintenanceOrphanSummarySize(String size);

  /// No description provided for @maintenanceOrphanSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get maintenanceOrphanSelectAll;

  /// No description provided for @maintenanceOrphanDeselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get maintenanceOrphanDeselectAll;

  /// No description provided for @maintenanceOrphanDeleteOne.
  ///
  /// In en, this message translates to:
  /// **'Delete this'**
  String get maintenanceOrphanDeleteOne;

  /// No description provided for @maintenanceOrphanSelectedHint.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String maintenanceOrphanSelectedHint(int count);

  /// No description provided for @maintenanceOrphanCleanSelected.
  ///
  /// In en, this message translates to:
  /// **'Clean selected'**
  String get maintenanceOrphanCleanSelected;

  /// No description provided for @maintenanceOrphanConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm cleanup'**
  String get maintenanceOrphanConfirmTitle;

  /// No description provided for @maintenanceOrphanConfirmDeleteOne.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"? This cannot be undone.'**
  String maintenanceOrphanConfirmDeleteOne(String title);

  /// No description provided for @maintenanceOrphanConfirmDeleteBatch.
  ///
  /// In en, this message translates to:
  /// **'Delete the {count} selected item(s)? This cannot be undone.'**
  String maintenanceOrphanConfirmDeleteBatch(int count);

  /// No description provided for @maintenanceOrphanCleanSuccess.
  ///
  /// In en, this message translates to:
  /// **'Cleaned {count} item(s)'**
  String maintenanceOrphanCleanSuccess(int count);

  /// No description provided for @maintenanceOrphanCleanPartial.
  ///
  /// In en, this message translates to:
  /// **'Cleaned {ok} item(s), {fail} failed'**
  String maintenanceOrphanCleanPartial(int ok, int fail);

  /// No description provided for @syncProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get syncProgressTitle;

  /// No description provided for @syncProgressCount.
  ///
  /// In en, this message translates to:
  /// **'{applied} / {total}'**
  String syncProgressCount(int applied, int total);
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

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh': {
  switch (locale.countryCode) {
    case 'TW': return AppLocalizationsZhTw();
   }
  break;
   }
  }

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
