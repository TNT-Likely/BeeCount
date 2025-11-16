// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '꿀벌 가계부';

  @override
  String get tabHome => '홈';

  @override
  String get tabAnalytics => '차트';

  @override
  String get tabLedgers => '가계부';

  @override
  String get tabMine => '마이페이지';

  @override
  String get commonCancel => '취소';

  @override
  String get commonConfirm => '확인';

  @override
  String get commonSave => '저장';

  @override
  String get commonDelete => '삭제';

  @override
  String get commonEdit => '편집';

  @override
  String get commonAdd => '추가';

  @override
  String get commonOk => '확인';

  @override
  String get commonYes => '네';

  @override
  String get commonNo => '아니오';

  @override
  String get commonLoading => '로딩 중...';

  @override
  String get commonEmpty => '데이터 없음';

  @override
  String get commonError => '오류';

  @override
  String get commonSuccess => '성공';

  @override
  String get commonFailed => '실패';

  @override
  String get commonRetry => '다시 시도';

  @override
  String get commonBack => '뒤로';

  @override
  String get commonNext => '다음';

  @override
  String get commonPrevious => '이전';

  @override
  String get commonFinish => '완료';

  @override
  String get commonClose => '닫기';

  @override
  String get commonCopy => '복사';

  @override
  String get commonSearch => '검색';

  @override
  String get commonNoteHint => '메모...';

  @override
  String get commonFilter => '필터';

  @override
  String get commonClear => '지우기';

  @override
  String get commonSelectAll => '모두 선택';

  @override
  String get commonSettings => '설정';

  @override
  String get commonHelp => '도움말';

  @override
  String get commonAbout => '정보';

  @override
  String get commonLanguage => '언어';

  @override
  String get commonCurrent => '현재';

  @override
  String get commonTutorial => '튜토리얼';

  @override
  String get commonConfigure => '구성';

  @override
  String get commonWeekdayMonday => '월요일';

  @override
  String get commonWeekdayTuesday => '화요일';

  @override
  String get commonWeekdayWednesday => '수요일';

  @override
  String get commonWeekdayThursday => '목요일';

  @override
  String get commonWeekdayFriday => '금요일';

  @override
  String get commonWeekdaySaturday => '토요일';

  @override
  String get commonWeekdaySunday => '일요일';

  @override
  String get homeTitle => '꿀벌 가계부';

  @override
  String get homeIncome => '수입';

  @override
  String get homeExpense => '지출';

  @override
  String get homeBalance => '잔액';

  @override
  String get homeTotal => '총계';

  @override
  String get homeAverage => '평균';

  @override
  String get homeDailyAvg => '일평균';

  @override
  String get homeMonthlyAvg => '월평균';

  @override
  String get homeNoRecords => '아직 기록이 없습니다';

  @override
  String get homeAddRecord => '플러스 버튼을 눌러 기록을 추가하세요';

  @override
  String get homeHideAmounts => '금액 숨기기';

  @override
  String get homeShowAmounts => '금액 표시';

  @override
  String get homeSelectDate => '날짜 선택';

  @override
  String get homeAppTitle => '꿀벌 가계부';

  @override
  String get homeSearch => '검색';

  @override
  String get homeShowAmount => '금액 표시';

  @override
  String get homeHideAmount => '금액 숨기기';

  @override
  String homeYear(int year) {
    return '$year년';
  }

  @override
  String homeMonth(String month) {
    return '$month월';
  }

  @override
  String get homeNoRecordsSubtext => '아래 플러스 버튼을 눌러 기록을 추가하세요';

  @override
  String get widgetTodayExpense => '오늘 지출';

  @override
  String get widgetTodayIncome => '오늘 수입';

  @override
  String get widgetMonthExpense => '이번 달 지출';

  @override
  String get widgetMonthIncome => '이번 달 수입';

  @override
  String get widgetMonthSuffix => '월';

  @override
  String get searchTitle => '검색';

  @override
  String get searchHint => '메모, 카테고리, 금액을 검색...';

  @override
  String get searchAmountRange => '금액 범위 필터';

  @override
  String get searchMinAmount => '최소 금액';

  @override
  String get searchMaxAmount => '최대 금액';

  @override
  String get searchTo => '~';

  @override
  String get searchNoInput => '키워드를 입력하여 검색을 시작하세요';

  @override
  String get searchNoResults => '일치하는 결과를 찾을 수 없습니다';

  @override
  String get searchResultsEmpty => '일치하는 결과를 찾을 수 없습니다';

  @override
  String get searchResultsEmptyHint => '다른 키워드를 시도하거나 필터 조건을 조정하세요';

  @override
  String get searchBatchMode => '일괄 작업';

  @override
  String searchBatchModeWithCount(Object selected, Object total) {
    return '일괄 작업 ($selected/$total)';
  }

  @override
  String get searchExitBatchMode => '일괄 작업 종료';

  @override
  String get searchSelectAll => '전체 선택';

  @override
  String get searchDeselectAll => '선택 해제';

  @override
  String searchSelectedCount(Object count) {
    return '$count개 선택됨';
  }

  @override
  String get searchBatchSetNote => '메모 설정';

  @override
  String get searchBatchChangeCategory => '카테고리 변경';

  @override
  String get searchBatchDeleteConfirmTitle => '삭제 확인';

  @override
  String searchBatchDeleteConfirmMessage(Object count) {
    return '선택한 $count개의 거래를 삭제하시겠습니까?\n이 작업은 취소할 수 없습니다.';
  }

  @override
  String get searchBatchSetNoteTitle => '일괄 메모 설정';

  @override
  String searchBatchSetNoteMessage(Object count) {
    return '선택한 $count개의 거래에 동일한 메모를 설정합니다';
  }

  @override
  String get searchBatchSetNoteHint => '메모 내용 입력 (비워두면 메모가 삭제됩니다)';

  @override
  String get searchBatchChangeCategoryTitle => '일괄 카테고리 변경';

  @override
  String searchBatchChangeCategoryMessage(Object count) {
    return '선택한 $count개의 거래에 새 카테고리를 설정합니다';
  }

  @override
  String get searchBatchChangeCategoryLabel => '카테고리 선택';

  @override
  String searchBatchDeleteSuccess(Object count) {
    return '$count개의 거래를 성공적으로 삭제했습니다';
  }

  @override
  String searchBatchDeleteFailed(Object error) {
    return '삭제 실패: $error';
  }

  @override
  String searchBatchSetNoteSuccess(Object count) {
    return '$count개의 거래에 메모를 성공적으로 설정했습니다';
  }

  @override
  String searchBatchSetNoteFailed(Object error) {
    return '메모 설정 실패: $error';
  }

  @override
  String searchBatchChangeCategorySuccess(Object count) {
    return '$count개의 거래의 카테고리를 성공적으로 변경했습니다';
  }

  @override
  String searchBatchChangeCategoryFailed(Object error) {
    return '카테고리 변경 실패: $error';
  }

  @override
  String searchResultsCount(Object count) {
    return '$count개의 결과';
  }

  @override
  String get analyticsTitle => '분석';

  @override
  String get analyticsMonth => '월';

  @override
  String get analyticsYear => '년';

  @override
  String get analyticsAll => '전체';

  @override
  String get analyticsSummary => '요약';

  @override
  String get analyticsCategoryRanking => '카테고리 순위';

  @override
  String get analyticsCurrentPeriod => '현재 기간';

  @override
  String get analyticsNoDataSubtext =>
      '좌우로 스와이프하여 기간을 전환하거나, 버튼을 탭하여 수입/지출을 전환하세요';

  @override
  String get analyticsSwipeHint => '좌우로 스와이프하여 기간을 변경하세요';

  @override
  String get analyticsTipContent =>
      '1) 하단을 좌우로 스와이프하여 지출/수입/잔액 전환\\n2) 차트 영역을 좌우로 스와이프하여 기간 전환';

  @override
  String analyticsSwitchTo(String type) {
    return '$type로 전환';
  }

  @override
  String get analyticsTipHeader => '팁: 상단 캡슐로 월/년/전체 전환 가능';

  @override
  String get analyticsSwipeToSwitch => '스와이프하여 전환';

  @override
  String get analyticsAllYears => '모든 년도';

  @override
  String get analyticsToday => '오늘';

  @override
  String get splashAppName => '꿀벌 가계부';

  @override
  String get splashSlogan => '한 방울 한 방울을 기록';

  @override
  String get splashSecurityTitle => '오픈소스 데이터 보안';

  @override
  String get splashSecurityFeature1 => '• 로컬 데이터 저장, 완전한 프라이버시 제어';

  @override
  String get splashSecurityFeature2 => '• 오픈소스 코드 투명성, 신뢰할 수 있는 보안';

  @override
  String get splashSecurityFeature3 => '• 선택적 클라우드 동기화, 기기 간 데이터 일관성';

  @override
  String get splashInitializing => '데이터 초기화 중...';

  @override
  String get ledgersTitle => '가계부 관리';

  @override
  String get ledgersNew => '새 가계부';

  @override
  String get ledgersClear => '현재 가계부 비우기';

  @override
  String get ledgersClearConfirm => '현재 가계부를 비우시겠습니까?';

  @override
  String ledgersClearMessage(Object name) {
    return '이 가계부의 모든 거래 기록이 삭제되며 복구할 수 없습니다.';
  }

  @override
  String get ledgersEdit => '가계부 편집';

  @override
  String get ledgersDelete => '가계부 삭제';

  @override
  String get ledgersDeleteConfirm => '가계부 삭제';

  @override
  String get ledgersDeleteMessage =>
      '이 가계부와 모든 기록을 삭제하시겠습니까? 이 작업은 취소할 수 없습니다.\\n클라우드에 백업이 있는 경우에도 삭제됩니다.';

  @override
  String get ledgersDeleted => '삭제됨';

  @override
  String get ledgersDeleteFailed => '삭제 실패';

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
  String ledgersRecordsDeleted(int count) {
    return '$count개의 기록이 삭제되었습니다';
  }

  @override
  String get ledgersName => '이름';

  @override
  String get ledgersDefaultLedgerName => '기본 가계부';

  @override
  String get ledgersDefaultAccountName => '현금';

  @override
  String get accountTitle => '계정';

  @override
  String get ledgersCurrency => '통화';

  @override
  String get ledgersSelectCurrency => '통화 선택';

  @override
  String get ledgersSearchCurrency => '검색: 중국어 또는 코드';

  @override
  String get ledgersCreate => '생성';

  @override
  String get ledgersActions => '작업';

  @override
  String ledgersRecords(String count) {
    return '기록: $count개';
  }

  @override
  String ledgersBalance(String balance) {
    return '잔액: $balance';
  }

  @override
  String get ledgerCardTransactions => 'transactions';

  @override
  String get ledgerCardRemoteOnly => 'Cloud only';

  @override
  String get ledgerCardDownloadCloud => 'Download from Cloud';

  @override
  String get ledgerCardJustNow => 'Just now';

  @override
  String ledgerCardMinutesAgo(int minutes) {
    return '$minutes minutes ago';
  }

  @override
  String ledgerCardHoursAgo(int hours) {
    return '$hours hours ago';
  }

  @override
  String ledgerCardDaysAgo(int days) {
    return '$days days ago';
  }

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
  String get categoryTitle => '카테고리 관리';

  @override
  String get categoryNew => '새 카테고리';

  @override
  String get categoryExpense => '지출 카테고리';

  @override
  String get categoryIncome => '수입 카테고리';

  @override
  String get categoryEmpty => '카테고리 없음';

  @override
  String get categoryDefault => '기본 카테고리';

  @override
  String get categoryCustomTag => '사용자 정의';

  @override
  String get categoryReorderTip => '길게 눌러 드래그하여 순서를 변경할 수 있습니다';

  @override
  String categoryLoadFailed(String error) {
    return '로딩 실패: $error';
  }

  @override
  String get iconPickerTitle => '아이콘 선택';

  @override
  String get iconCategoryFood => '음식';

  @override
  String get iconCategoryTransport => '교통';

  @override
  String get iconCategoryShopping => '쇼핑';

  @override
  String get iconCategoryEntertainment => '오락';

  @override
  String get iconCategoryLife => '생활';

  @override
  String get iconCategoryHealth => '건강';

  @override
  String get iconCategoryEducation => '교육';

  @override
  String get iconCategoryWork => '업무';

  @override
  String get iconCategoryFinance => '금융';

  @override
  String get iconCategoryReward => '보상';

  @override
  String get iconCategoryOther => '기타';

  @override
  String get iconCategoryDining => '외식';

  @override
  String get importTitle => '계산서 가져오기';

  @override
  String get importSelectFile => '가져올 파일을 선택하세요 (CSV/TSV/XLSX 지원)';

  @override
  String get importBillType => '계산서 유형';

  @override
  String get importBillTypeGeneric => '일반 CSV';

  @override
  String get importBillTypeAlipay => '알리페이';

  @override
  String get importBillTypeWechat => '위챗';

  @override
  String get importChooseFile => '파일 선택';

  @override
  String get importNoFileSelected => '파일이 선택되지 않았습니다';

  @override
  String get importHint => '팁: 파일을 선택하여 가져오기를 시작하세요 (CSV/TSV/XLSX)';

  @override
  String get importReading => '파일 읽는 중…';

  @override
  String get importPreparing => '준비 중…';

  @override
  String importColumnNumber(Object number) {
    return '열 $number';
  }

  @override
  String get importConfirmMapping => '매핑 확인';

  @override
  String get importCategoryMapping => '카테고리 매핑';

  @override
  String get importNoDataParsed =>
      '데이터가 파싱되지 않았습니다. 이전 페이지로 돌아가서 CSV 내용이나 구분자를 확인하세요.';

  @override
  String get importFieldDate => '날짜';

  @override
  String get importFieldType => '유형';

  @override
  String get importFieldAmount => '금액';

  @override
  String get importFieldCategory => '카테고리';

  @override
  String get importFieldAccount => '계정';

  @override
  String get importFieldNote => '메모';

  @override
  String get importPreview => '데이터 미리보기';

  @override
  String importPreviewLimit(Object shown, Object total) {
    return '$total개 중 처음 $shown개 표시';
  }

  @override
  String get importCategoryNotSelected => '카테고리가 선택되지 않았습니다';

  @override
  String get importCategoryMappingDescription =>
      '각 카테고리 이름에 해당하는 로컬 카테고리를 선택하세요:';

  @override
  String get importKeepOriginalName => '원래 이름 유지';

  @override
  String importProgress(Object fail, Object ok) {
    return '가져오는 중, 성공: $ok, 실패: $fail';
  }

  @override
  String get importCancelImport => '가져오기 취소';

  @override
  String get importCompleteTitle => '가져오기 완료';

  @override
  String importCompletedCount(Object count) {
    return '$count개의 기록을 성공적으로 가져왔습니다';
  }

  @override
  String get importFailed => '가져오기 실패';

  @override
  String importFailedMessage(Object error) {
    return '가져오기 실패: $error';
  }

  @override
  String get importSelectCategoryFirst => '먼저 카테고리 매핑을 선택하세요';

  @override
  String get importNextStep => '다음 단계';

  @override
  String get importPreviousStep => '이전 단계';

  @override
  String get importStartImport => '가져오기 시작';

  @override
  String get importAutoDetect => '자동 감지';

  @override
  String get importInProgress => '가져오기 진행 중';

  @override
  String importProgressDetail(
      Object done, Object fail, Object ok, Object total) {
    return '$total개 중 $done개 가져옴, 성공 $ok개, 실패 $fail개';
  }

  @override
  String get importBackgroundImport => '백그라운드 가져오기';

  @override
  String get importCancelled => '가져오기 취소됨';

  @override
  String importCompleted(Object cancelled, Object fail, Object ok) {
    return '가져오기 완료$cancelled, 성공 $ok개, 실패 $fail개';
  }

  @override
  String importSkippedNonTransactionTypes(Object count) {
    return '$count개의 비거래 기록 건너뜀 (이체, 부채 등)';
  }

  @override
  String importTransactionFailed(Object error) {
    return '가져오기 실패, 모든 변경 사항이 롤백되었습니다: $error';
  }

  @override
  String importFileOpenError(String error) {
    return '파일 선택기를 열 수 없습니다: $error';
  }

  @override
  String get mineTitle => '마이페이지';

  @override
  String get mineSettings => '설정';

  @override
  String get mineTheme => '테마 설정';

  @override
  String get mineFont => '글꼴 설정';

  @override
  String get mineReminder => '알림 설정';

  @override
  String get mineData => '데이터 관리';

  @override
  String get mineImport => '데이터 가져오기';

  @override
  String get mineExport => '데이터 내보내기';

  @override
  String get mineCloud => '클라우드 서비스';

  @override
  String get mineAbout => '정보';

  @override
  String get mineVersion => '버전';

  @override
  String get mineUpdate => '업데이트 확인';

  @override
  String get mineLanguageSettings => '언어 설정';

  @override
  String get mineLanguageSettingsSubtitle => '애플리케이션 언어 전환';

  @override
  String get languageTitle => '언어 설정';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystemDefault => '시스템 따라가기';

  @override
  String get deleteConfirmTitle => '삭제 확인';

  @override
  String get deleteConfirmMessage => '이 기록을 삭제하시겠습니까?';

  @override
  String get logCopied => '로그가 복사되었습니다';

  @override
  String get waitingRestore => '복원 작업 시작 대기 중...';

  @override
  String get restoreTitle => '클라우드 복원';

  @override
  String get copyLog => '로그 복사';

  @override
  String restoreProgress(Object current, Object total) {
    return '복원 중 ($current/$total)';
  }

  @override
  String get restorePreparing => '준비 중...';

  @override
  String restoreLedgerProgress(String ledger, int done, int total) {
    return '가계부: $ledger 기록: $done/$total';
  }

  @override
  String get mineSlogan => '꿀벌 가계부, 한 푼도 놓치지 않기';

  @override
  String get mineAvatarTitle => 'Avatar Settings';

  @override
  String get mineAvatarFromGallery => 'Choose from Gallery';

  @override
  String get mineAvatarFromCamera => 'Take Photo';

  @override
  String get mineAvatarDelete => 'Delete Avatar';

  @override
  String get mineShareApp => 'Share App';

  @override
  String get mineShareAppSubtitle =>
      'Generate share poster and save to gallery';

  @override
  String get mineShareGenerating => 'Generating share poster...';

  @override
  String get mineShareSuccess => 'Saved Successfully';

  @override
  String get mineShareSuccessMessage =>
      'Share poster has been saved to gallery';

  @override
  String get mineShareFailed => 'Save failed, please check gallery permissions';

  @override
  String get sharePosterAppName => 'BeeCount';

  @override
  String get sharePosterSlogan => 'Smart Accounting, Beautiful Life';

  @override
  String get sharePosterFeature1 => '✨ Completely Open Source & Free';

  @override
  String get sharePosterFeature2 => '🤖 AI Smart Bill Recognition';

  @override
  String get sharePosterFeature3 => '⚡ Automated Accounting';

  @override
  String get sharePosterFeature4 => '🔒 Privacy & Security';

  @override
  String get sharePosterFeature5 => '☁️ Cloud Sync & Backup';

  @override
  String get sharePosterFeature6 => '📊 Multiple Ledgers';

  @override
  String get sharePosterScanText => 'Scan to visit open source project';

  @override
  String get sharePosterPreviewTitle => 'Share Poster Preview';

  @override
  String get sharePosterSave => 'Save to Gallery';

  @override
  String get sharePosterShare => 'Share';

  @override
  String get sharePosterSaveSuccess => 'Saved to gallery';

  @override
  String get sharePosterSaveFailed => 'Failed to save';

  @override
  String get sharePosterPermissionDenied =>
      'Gallery permission denied, please enable in settings';

  @override
  String get mineDaysCount => '일';

  @override
  String get mineTotalRecords => '기록';

  @override
  String get mineCurrentBalance => '잔액';

  @override
  String get mineCloudService => '클라우드 서비스';

  @override
  String get mineCloudServiceLoading => '로딩 중...';

  @override
  String mineCloudServiceError(Object error) {
    return '오류: $error';
  }

  @override
  String get mineCloudServiceDefault => '기본 클라우드 (활성화됨)';

  @override
  String get mineCloudServiceOffline => '기본 모드 (오프라인)';

  @override
  String get mineCloudServiceCustom => '사용자 정의 Supabase';

  @override
  String get mineCloudServiceWebDAV => '사용자 정의 클라우드 서비스 (WebDAV)';

  @override
  String get mineSyncTitle => '동기화';

  @override
  String get mineSyncNotLoggedIn => '로그인되지 않음';

  @override
  String get mineSyncNotConfigured => '클라우드가 설정되지 않음';

  @override
  String get mineSyncNoRemote => '클라우드 백업 없음';

  @override
  String mineSyncInSync(Object count) {
    return '동기화됨 (로컬 $count개 기록)';
  }

  @override
  String get mineSyncInSyncSimple => '동기화됨';

  @override
  String mineSyncLocalNewer(Object count) {
    return '로컬이 최신 (로컬 $count개 기록, 업로드 권장)';
  }

  @override
  String get mineSyncLocalNewerSimple => '로컬이 최신';

  @override
  String get mineSyncCloudNewer => '클라우드가 최신 (다운로드 권장)';

  @override
  String get mineSyncCloudNewerSimple => '클라우드가 최신';

  @override
  String get mineSyncDifferent => '로컬과 클라우드가 다릅니다';

  @override
  String get mineSyncError => '상태 가져오기 실패';

  @override
  String get mineSyncDetailTitle => '동기화 상태 세부정보';

  @override
  String mineSyncLocalRecords(Object count) {
    return '로컬 기록: $count개';
  }

  @override
  String mineSyncCloudRecords(Object count) {
    return '클라우드 기록: $count개';
  }

  @override
  String mineSyncCloudLatest(Object time) {
    return '클라우드 최신 기록 시간: $time';
  }

  @override
  String mineSyncLocalFingerprint(Object fingerprint) {
    return '로컬 지문: $fingerprint';
  }

  @override
  String mineSyncCloudFingerprint(Object fingerprint) {
    return '클라우드 지문: $fingerprint';
  }

  @override
  String mineSyncMessage(Object message) {
    return '메시지: $message';
  }

  @override
  String get mineUploadTitle => '업로드';

  @override
  String get mineUploadNeedLogin => '로그인이 필요합니다';

  @override
  String get mineUploadNeedCloudService => '클라우드 서비스 모드에서만 사용 가능';

  @override
  String get mineUploadInProgress => '업로드 중...';

  @override
  String get mineUploadRefreshing => '새로고침 중...';

  @override
  String get mineUploadSynced => '동기화됨';

  @override
  String get mineUploadSuccess => '업로드 완료';

  @override
  String get mineUploadSuccessMessage => '현재 가계부가 클라우드에 동기화되었습니다';

  @override
  String get mineDownloadTitle => '다운로드';

  @override
  String get mineDownloadNeedCloudService => '클라우드 서비스 모드에서만 사용 가능';

  @override
  String get mineDownloadComplete => '완료';

  @override
  String mineDownloadResult(Object deleted, Object inserted, Object skipped) {
    return '새로운 가져오기: $inserted\\n기존 건너뛰기: $skipped\\n중복 정리: $deleted';
  }

  @override
  String get mineLoginTitle => '로그인 / 등록';

  @override
  String get mineLoginSubtitle => '동기화에만 필요';

  @override
  String get mineLoggedInEmail => '로그인됨';

  @override
  String get mineLogoutSubtitle => '탭하여 로그아웃';

  @override
  String get mineLogoutConfirmTitle => '로그아웃';

  @override
  String get mineLogoutConfirmMessage =>
      '로그아웃하시겠습니까?\\n로그아웃 후에는 클라우드 동기화를 사용할 수 없습니다.';

  @override
  String get mineLogoutButton => '로그아웃';

  @override
  String get mineAutoSyncTitle => '가계부 자동 동기화';

  @override
  String get mineAutoSyncSubtitle => '기록 후 자동으로 클라우드에 업로드';

  @override
  String get mineAutoSyncNeedLogin => '활성화하려면 로그인이 필요합니다';

  @override
  String get mineAutoSyncNeedCloudService => '클라우드 서비스 모드에서만 사용 가능';

  @override
  String get mineImportProgressTitle => '백그라운드에서 가져오는 중...';

  @override
  String mineImportProgressSubtitle(
      Object done, Object fail, Object ok, Object total) {
    return '진행 상황: $done/$total, 성공 $ok개, 실패 $fail개';
  }

  @override
  String get mineImportCompleteTitle => '가져오기 완료';

  @override
  String mineImportCompleteSubtitle(Object fail, Object ok) {
    return '성공 $ok개, 실패 $fail개';
  }

  @override
  String get mineCategoryManagement => '카테고리 관리';

  @override
  String get mineCategoryManagementSubtitle => '사용자 정의 카테고리 편집';

  @override
  String get mineCategoryMigration => '카테고리 이전';

  @override
  String get mineCategoryMigrationSubtitle => '카테고리 데이터를 다른 카테고리로 이전';

  @override
  String get mineRecurringTransactions => '반복 거래';

  @override
  String get mineRecurringTransactionsSubtitle => '반복 거래 관리';

  @override
  String get mineReminderSettings => '알림 설정';

  @override
  String get mineReminderSettingsSubtitle => '일일 기록 알림 설정';

  @override
  String get minePersonalize => '개인화';

  @override
  String get mineDisplayScale => '표시 배율';

  @override
  String get mineDisplayScaleSubtitle => '텍스트 및 UI 요소 크기 조정';

  @override
  String get mineAboutTitle => '정보';

  @override
  String mineAboutMessage(Object version) {
    return '앱: 꿀벌 가계부\\n버전: $version\\n소스: https://github.com/TNT-Likely/BeeCount\\n라이선스: 저장소의 LICENSE 참조';
  }

  @override
  String get mineAboutOpenGitHub => 'GitHub 열기';

  @override
  String get mineCheckUpdate => '업데이트 확인';

  @override
  String get mineCheckUpdateInProgress => '업데이트 확인 중...';

  @override
  String get mineCheckUpdateSubtitle => '최신 버전 확인 중';

  @override
  String get mineUpdateDownload => '업데이트 다운로드';

  @override
  String get mineFeedback => '피드백';

  @override
  String get mineFeedbackSubtitle => '문제 또는 제안 보고';

  @override
  String get mineHelp => '도움말';

  @override
  String get mineHelpSubtitle => '문서 및 FAQ 보기';

  @override
  String get mineSupportAuthor => '작성자 지원';

  @override
  String get mineSupportAuthorSubtitle => 'GitHub에서 프로젝트에 스타 주기';

  @override
  String get mineRefreshStats => '통계 새로고침 (디버그)';

  @override
  String get mineRefreshStatsSubtitle => '글로벌 통계 프로바이더 재계산 트리거';

  @override
  String get mineRefreshSync => '동기화 상태 새로고침 (디버그)';

  @override
  String get mineRefreshSyncSubtitle => '동기화 상태 프로바이더 새로고침 트리거';

  @override
  String get categoryEditTitle => '카테고리 편집';

  @override
  String get categoryNewTitle => '새 카테고리';

  @override
  String get categoryDetailTooltip => '카테고리 세부정보';

  @override
  String get categoryMigrationTooltip => '카테고리 이전';

  @override
  String get categoryMigrationTitle => '카테고리 이전';

  @override
  String get categoryMigrationDescription => '카테고리 이전 안내';

  @override
  String get categoryMigrationDescriptionContent =>
      '• 한 카테고리의 모든 거래 기록을 다른 카테고리로 이전\\n• 이전 후, 원래 카테고리의 모든 거래 데이터가 대상 카테고리로 전송됩니다\\n• 이 작업은 취소할 수 없으므로 신중하게 선택하세요';

  @override
  String get categoryMigrationFromLabel => '원본 카테고리';

  @override
  String get categoryMigrationFromHint => '이전할 카테고리 선택';

  @override
  String get categoryMigrationToLabel => '대상 카테고리';

  @override
  String get categoryMigrationToHint => '대상 카테고리 선택';

  @override
  String get categoryMigrationToHintFirst => '먼저 원본 카테고리를 선택하세요';

  @override
  String get categoryMigrationStartButton => '이전 시작';

  @override
  String categoryMigrationTransactionCount(int count) {
    return '$count개 기록';
  }

  @override
  String get categoryMigrationCannotTitle => '이전할 수 없음';

  @override
  String get categoryMigrationCannotMessage =>
      '선택된 카테고리는 이전할 수 없습니다. 카테고리 상태를 확인하세요.';

  @override
  String get categoryExpenseType => '지출 카테고리';

  @override
  String get categoryIncomeType => '수입 카테고리';

  @override
  String get categoryDefaultTitle => '기본 카테고리';

  @override
  String get categoryDefaultMessage =>
      '기본 카테고리는 수정할 수 없지만 세부정보를 보고 데이터를 이전할 수 있습니다';

  @override
  String get categoryNameDining => '외식';

  @override
  String get categoryNameTransport => '교통';

  @override
  String get categoryNameShopping => '쇼핑';

  @override
  String get categoryNameEntertainment => '오락';

  @override
  String get categoryNameHome => '가정';

  @override
  String get categoryNameFamily => '가족';

  @override
  String get categoryNameCommunication => '통신';

  @override
  String get categoryNameUtilities => '공과금';

  @override
  String get categoryNameHousing => '주거';

  @override
  String get categoryNameMedical => '의료';

  @override
  String get categoryNameEducation => '교육';

  @override
  String get categoryNamePets => '반려동물';

  @override
  String get categoryNameSports => '스포츠';

  @override
  String get categoryNameDigital => '디지털';

  @override
  String get categoryNameTravel => '여행';

  @override
  String get categoryNameAlcoholTobacco => '주류 & 담배';

  @override
  String get categoryNameBabyCare => '육아';

  @override
  String get categoryNameBeauty => '미용';

  @override
  String get categoryNameRepair => '수리';

  @override
  String get categoryNameSocial => '사교';

  @override
  String get categoryNameLearning => '학습';

  @override
  String get categoryNameCar => '자동차';

  @override
  String get categoryNameTaxi => '택시';

  @override
  String get categoryNameSubway => '지하철';

  @override
  String get categoryNameDelivery => '배송';

  @override
  String get categoryNameProperty => '부동산';

  @override
  String get categoryNameParking => '주차';

  @override
  String get categoryNameDonation => '기부';

  @override
  String get categoryNameGift => '선물';

  @override
  String get categoryNameTax => '세금';

  @override
  String get categoryNameBeverage => '음료';

  @override
  String get categoryNameClothing => '의류';

  @override
  String get categoryNameSnacks => '간식';

  @override
  String get categoryNameRedPacket => '세뱃돈';

  @override
  String get categoryNameFruit => '과일';

  @override
  String get categoryNameGame => '게임';

  @override
  String get categoryNameBook => '도서';

  @override
  String get categoryNameLover => '연인';

  @override
  String get categoryNameDecoration => '장식';

  @override
  String get categoryNameDailyGoods => '생필품';

  @override
  String get categoryNameLottery => '복권';

  @override
  String get categoryNameStock => '주식';

  @override
  String get categoryNameSocialSecurity => '사회보장';

  @override
  String get categoryNameExpress => '택배';

  @override
  String get categoryNameWork => '업무';

  @override
  String get categoryNameSalary => '급여';

  @override
  String get categoryNameInvestment => '투자';

  @override
  String get categoryNameBonus => '보너스';

  @override
  String get categoryNameReimbursement => '환급';

  @override
  String get categoryNamePartTime => '아르바이트';

  @override
  String get categoryNameInterest => '이자';

  @override
  String get categoryNameRefund => '환불';

  @override
  String get categoryNameSecondHand => '중고 판매';

  @override
  String get categoryNameSocialBenefit => '사회보장급여';

  @override
  String get categoryNameTaxRefund => '세금 환급';

  @override
  String get categoryNameProvidentFund => '적립금';

  @override
  String get categoryNameLabel => '카테고리 이름';

  @override
  String get categoryNameHint => '카테고리 이름 입력';

  @override
  String get categoryNameHintDefault => '기본 카테고리 이름은 수정할 수 없습니다';

  @override
  String get categoryNameRequired => '카테고리 이름을 입력하세요';

  @override
  String get categoryNameTooLong => '카테고리 이름은 4자를 초과할 수 없습니다';

  @override
  String get categoryIconLabel => '카테고리 아이콘';

  @override
  String get categoryIconDefaultMessage => '기본 카테고리 아이콘은 수정할 수 없습니다';

  @override
  String get categoryDangerousOperations => '위험한 작업';

  @override
  String get categoryDeleteTitle => '카테고리 삭제';

  @override
  String get categoryDeleteSubtitle => '삭제 후 복구할 수 없습니다';

  @override
  String get categoryDefaultCannotSave => '기본 카테고리는 저장할 수 없습니다';

  @override
  String get categorySaveError => '저장 실패';

  @override
  String categoryUpdated(Object name) {
    return '카테고리 \"$name\"이(가) 업데이트되었습니다';
  }

  @override
  String categoryCreated(Object name) {
    return '카테고리 \"$name\"이(가) 생성되었습니다';
  }

  @override
  String get categoryCannotDelete => '삭제할 수 없음';

  @override
  String categoryCannotDeleteMessage(Object count) {
    return '이 카테고리에는 $count개의 거래 기록이 있습니다. 먼저 처리하세요.';
  }

  @override
  String get categoryDeleteConfirmTitle => '카테고리 삭제';

  @override
  String categoryDeleteConfirmMessage(Object name) {
    return '카테고리 \"$name\"을(를) 삭제하시겠습니까? 이 작업은 취소할 수 없습니다.';
  }

  @override
  String get categoryDeleteError => '삭제 실패';

  @override
  String categoryDeleted(Object name) {
    return '카테고리 \"$name\"이(가) 삭제되었습니다';
  }

  @override
  String get personalizeTitle => '개인화';

  @override
  String get personalizeCustomColor => '사용자 정의 색상 선택';

  @override
  String get personalizeCustomTitle => '사용자 정의';

  @override
  String personalizeHue(Object value) {
    return '색조 ($value°)';
  }

  @override
  String personalizeSaturation(Object value) {
    return '채도 ($value%)';
  }

  @override
  String personalizeBrightness(Object value) {
    return '밝기 ($value%)';
  }

  @override
  String get personalizeSelectColor => '이 색상 선택';

  @override
  String get fontSettingsTitle => '표시 배율';

  @override
  String fontSettingsCurrentScale(Object scale) {
    return '현재 배율: x$scale';
  }

  @override
  String get fontSettingsPreview => '실시간 미리보기';

  @override
  String get fontSettingsPreviewText =>
      '오늘 점심에 23.50을 사용, 기록했습니다;\\n이번 달은 45일 동안 기록, 320개 항목;\\n지속이 승리!';

  @override
  String fontSettingsCurrentLevel(Object level, Object scale) {
    return '현재 레벨: $level (배율 x$scale)';
  }

  @override
  String get fontSettingsQuickLevel => '빠른 레벨';

  @override
  String get fontSettingsCustomAdjust => '사용자 정의 조정';

  @override
  String get fontSettingsDescription =>
      '참고: 이 설정은 모든 기기에서 1.0x로 일관된 표시를 보장하며, 기기 차이는 자동 보정됩니다; 이 일관된 기준에서 개인화된 배율 값을 조정하세요.';

  @override
  String get fontSettingsExtraSmall => '매우 작게';

  @override
  String get fontSettingsVerySmall => '아주 작게';

  @override
  String get fontSettingsSmall => '작게';

  @override
  String get fontSettingsStandard => '표준';

  @override
  String get fontSettingsLarge => '크게';

  @override
  String get fontSettingsBig => '큰';

  @override
  String get fontSettingsVeryBig => '아주 크게';

  @override
  String get fontSettingsExtraBig => '매우 크게';

  @override
  String get fontSettingsMoreStyles => '더 많은 스타일';

  @override
  String get fontSettingsPageTitle => '페이지 제목';

  @override
  String get fontSettingsBlockTitle => '블록 제목';

  @override
  String get fontSettingsBodyExample => '본문 텍스트';

  @override
  String get fontSettingsLabelExample => '라벨 텍스트';

  @override
  String get fontSettingsStrongNumber => '강조 숫자';

  @override
  String get fontSettingsListTitle => '목록 항목 제목';

  @override
  String get fontSettingsListSubtitle => '도움말 텍스트';

  @override
  String get fontSettingsScreenInfo => '화면 적응 정보';

  @override
  String get fontSettingsScreenDensity => '화면 밀도';

  @override
  String get fontSettingsScreenWidth => '화면 너비';

  @override
  String get fontSettingsDeviceScale => '기기 배율';

  @override
  String get fontSettingsUserScale => '사용자 배율';

  @override
  String get fontSettingsFinalScale => '최종 배율';

  @override
  String get fontSettingsBaseDevice => '기준 기기';

  @override
  String get fontSettingsRecommendedScale => '권장 배율';

  @override
  String get fontSettingsYes => '네';

  @override
  String get fontSettingsNo => '아니오';

  @override
  String get fontSettingsScaleExample => '이 박스와 간격은 기기에 따라 자동 배율';

  @override
  String get fontSettingsPreciseAdjust => '정밀 조정';

  @override
  String get fontSettingsResetTo1x => '1.0x로 재설정';

  @override
  String get fontSettingsAdaptBase => '기준에 적응';

  @override
  String get reminderTitle => '기록 알림';

  @override
  String get reminderSubtitle => '일일 기록 알림 시간 설정';

  @override
  String get reminderDailyTitle => '일일 기록 알림';

  @override
  String get reminderDailySubtitle => '활성화하면 지정된 시간에 기록을 알리는 알림이 전송됩니다';

  @override
  String get reminderTimeTitle => '알림 시간';

  @override
  String get reminderTestNotification => '테스트 알림 전송';

  @override
  String get reminderTestSent => '테스트 알림을 전송했습니다';

  @override
  String get reminderTestTitle => '테스트 알림';

  @override
  String get reminderTestBody => '테스트 알림입니다. 탭하여 효과를 확인하세요';

  @override
  String get reminderTestDelayBody => '15초 지연된 테스트 알림입니다';

  @override
  String get reminderQuickTest => '빠른 테스트 (15초 후)';

  @override
  String get reminderQuickTestMessage =>
      '15초 후 빠른 테스트를 설정했습니다. 앱을 백그라운드에 유지하세요';

  @override
  String get reminderFlutterTest => '🔧 Flutter 알림 클릭 테스트 (개발)';

  @override
  String get reminderFlutterTestMessage =>
      'Flutter 테스트 알림을 전송했습니다. 탭하여 앱이 열리는지 확인하세요';

  @override
  String get reminderAlarmTest => '🔧 AlarmManager 알림 클릭 테스트 (개발)';

  @override
  String get reminderAlarmTestMessage =>
      'AlarmManager 테스트 알림을 설정했습니다 (1초 후). 탭하여 앱이 열리는지 확인하세요';

  @override
  String get reminderDirectTest => '🔧 NotificationReceiver 직접 테스트 (개발)';

  @override
  String get reminderDirectTestMessage =>
      'NotificationReceiver를 직접 호출하여 알림을 생성했습니다. 탭이 작동하는지 확인하세요';

  @override
  String get reminderCheckStatus => '🔧 알림 상태 확인 (개발)';

  @override
  String get reminderNotificationStatus => '알림 상태';

  @override
  String reminderPendingCount(Object count) {
    return '대기 중인 알림: $count개';
  }

  @override
  String get reminderNoPending => '대기 중인 알림이 없습니다';

  @override
  String get reminderCheckBattery => '배터리 최적화 상태 확인';

  @override
  String get reminderBatteryStatus => '배터리 최적화 상태';

  @override
  String reminderManufacturer(Object value) {
    return '제조사: $value';
  }

  @override
  String reminderModel(Object value) {
    return '모델: $value';
  }

  @override
  String reminderAndroidVersion(Object value) {
    return 'Android 버전: $value';
  }

  @override
  String get reminderBatteryIgnored => '배터리 최적화: 무시됨 ✅';

  @override
  String get reminderBatteryNotIgnored => '배터리 최적화: 무시되지 않음 ⚠️';

  @override
  String get reminderBatteryAdvice => '적절한 알림을 위해 배터리 최적화를 비활성화하는 것을 권장합니다';

  @override
  String get reminderGoToSettings => '설정으로 이동';

  @override
  String get reminderCheckChannel => '알림 채널 설정 확인';

  @override
  String get reminderChannelStatus => '알림 채널 상태';

  @override
  String get reminderChannelEnabled => '채널 활성화: 네 ✅';

  @override
  String get reminderChannelDisabled => '채널 활성화: 아니오 ❌';

  @override
  String reminderChannelImportance(Object value) {
    return '중요도: $value';
  }

  @override
  String get reminderChannelSoundOn => '소리: 켜짐 🔊';

  @override
  String get reminderChannelSoundOff => '소리: 꺼짐 🔇';

  @override
  String get reminderChannelVibrationOn => '진동: 켜짐 📳';

  @override
  String get reminderChannelVibrationOff => '진동: 꺼짐';

  @override
  String get reminderChannelDndBypass => '방해 금지: 무시 가능';

  @override
  String get reminderChannelDndNoBypass => '방해 금지: 무시 불가';

  @override
  String get reminderChannelAdvice => '⚠️ 권장 설정:';

  @override
  String get reminderChannelAdviceImportance => '• 중요도: 긴급 또는 높음';

  @override
  String get reminderChannelAdviceSound => '• 소리와 진동 활성화';

  @override
  String get reminderChannelAdviceBanner => '• 배너 알림 허용';

  @override
  String get reminderChannelAdviceXiaomi => '• Xiaomi 폰은 개별 채널 설정이 필요';

  @override
  String get reminderChannelGood => '✅ 알림 채널이 적절히 설정되었습니다';

  @override
  String get reminderOpenAppSettings => '앱 설정 열기';

  @override
  String get reminderAppSettingsMessage => '설정에서 알림을 허용하고 배터리 최적화를 비활성화하세요';

  @override
  String get reminderIOSTest => '🍎 iOS 알림 디버그 테스트';

  @override
  String get reminderIOSTestTitle => 'iOS 알림 테스트';

  @override
  String get reminderIOSTestMessage =>
      '테스트 알림을 전송했습니다.\\n\\n🍎 iOS 시뮬레이터 제한사항:\\n• 알림 센터에 알림이 표시되지 않을 수 있습니다\\n• 배너 알림이 작동하지 않을 수 있습니다\\n• 하지만 Xcode 콘솔에 로그가 표시됩니다\\n\\n💡 디버그 방법:\\n• Xcode 콘솔 출력 확인\\n• Flutter 로그 정보 확인\\n• 완전한 경험을 위해 실제 기기 사용';

  @override
  String get reminderDescription =>
      '팁: 기록 알림이 활성화되면 시스템이 매일 지정된 시간에 알림을 전송하여 수입과 지출 기록을 알려줍니다.';

  @override
  String get reminderIOSInstructions =>
      '🍎 iOS 알림 설정:\\n• 설정 > 알림 > 꿀벌 가계부\\n• \"알림 허용\" 활성화\\n• 알림 스타일 설정: 배너 또는 알림\\n• 소리와 진동 활성화\\n\\n⚠️ iOS 시뮬레이터 제한사항:\\n• 시뮬레이터 알림 기능이 제한됩니다\\n• 실제 기기 사용을 권장합니다\\n• 알림 상태는 Xcode 콘솔에서 확인\\n\\n시뮬레이터에서 테스트할 때 관찰하세요:\\n• Xcode 콘솔 로그 출력\\n• Flutter 디버그 콘솔 정보\\n• 앱 내 알림 전송 확인 팝업';

  @override
  String get reminderAndroidInstructions =>
      '알림이 제대로 작동하지 않는 경우 확인하세요:\\n• 앱이 알림 전송을 허용하는지\\n• 앱의 배터리 최적화/절전 모드 비활성화\\n• 앱의 백그라운드 실행 및 자동 시작 허용\\n• Android 12+에서는 정확한 알람 권한이 필요\\n\\n📱 Xiaomi 폰 특별 설정:\\n• 설정 > 앱 관리 > 꿀벌 가계부 > 알림 관리\\n• \"기록 알림\" 채널 탭\\n• 중요도를 \"긴급\" 또는 \"높음\"으로 설정\\n• \"배너 알림\", \"소리\", \"진동\" 활성화\\n• 보안 센터 > 앱 관리 > 권한 > 자동 시작\\n\\n🔒 백그라운드 잠금 방법:\\n• 최근 작업에서 꿀벌 가계부 찾기\\n• 앱 카드를 아래로 스와이프하여 잠금 아이콘 표시\\n• 잠금 아이콘을 탭하여 정리 방지';

  @override
  String get categoryDetailLoadFailed => '로딩 실패';

  @override
  String get categoryDetailSummaryTitle => '카테고리 요약';

  @override
  String get categoryDetailTotalCount => '총 개수';

  @override
  String get categoryDetailTotalAmount => '총 금액';

  @override
  String get categoryDetailAverageAmount => '평균 금액';

  @override
  String get categoryDetailSortTitle => '정렬';

  @override
  String get categoryDetailSortTimeDesc => '시간 ↓';

  @override
  String get categoryDetailSortTimeAsc => '시간 ↑';

  @override
  String get categoryDetailSortAmountDesc => '금액 ↓';

  @override
  String get categoryDetailSortAmountAsc => '금액 ↑';

  @override
  String get categoryDetailNoTransactions => '거래 없음';

  @override
  String get categoryDetailNoTransactionsSubtext => '이 카테고리에는 아직 거래가 없습니다';

  @override
  String get categoryDetailDeleteFailed => '삭제 실패';

  @override
  String get categoryMigrationConfirmTitle => '이전 확인';

  @override
  String categoryMigrationConfirmMessage(
      Object count, Object fromName, Object toName) {
    return '\"$fromName\"에서 \"$toName\"으로 $count개의 거래를 이전하시겠습니까?\\n\\n이 작업은 취소할 수 없습니다!';
  }

  @override
  String get categoryMigrationConfirmOk => '이전 확인';

  @override
  String get categoryMigrationCompleteTitle => '이전 완료';

  @override
  String categoryMigrationCompleteMessage(
      Object count, Object fromName, Object toName) {
    return '\"$fromName\"에서 \"$toName\"으로 $count개의 거래를 성공적으로 이전했습니다.';
  }

  @override
  String get categoryMigrationFailedTitle => '이전 실패';

  @override
  String categoryMigrationFailedMessage(Object error) {
    return '이전 오류: $error';
  }

  @override
  String categoryMigrationTransactionLabel(int count) {
    return '$count개 기록';
  }

  @override
  String get categoryPickerExpenseTab => '지출';

  @override
  String get categoryPickerIncomeTab => '수입';

  @override
  String get categoryPickerCancel => '취소';

  @override
  String get categoryPickerEmpty => '카테고리 없음';

  @override
  String get cloudBackupFound => '클라우드 백업을 찾았습니다';

  @override
  String get cloudBackupRestoreMessage =>
      '클라우드와 로컬 가계부가 일치하지 않습니다. 클라우드에서 복원하시겠습니까?\\n(복원 진행 페이지로 이동합니다)';

  @override
  String get cloudBackupRestoreFailed => '복원 실패';

  @override
  String get mineCloudBackupRestoreTitle => '클라우드 백업을 찾았습니다';

  @override
  String get mineAutoSyncRemoteDesc => '기록 후 자동으로 클라우드에 업로드';

  @override
  String get mineAutoSyncLoginRequired => '활성화하려면 로그인이 필요합니다';

  @override
  String get mineImportCompleteAllSuccess => '모두 성공';

  @override
  String get mineImportCompleteTitleShort => '가져오기 완료';

  @override
  String get mineAboutAppName => '앱: 꿀벌 가계부';

  @override
  String mineAboutVersion(Object version) {
    return '버전: $version';
  }

  @override
  String get mineAboutRepo => '소스: https://github.com/TNT-Likely/BeeCount';

  @override
  String get mineAboutLicense => '라이선스: 저장소의 LICENSE 참조';

  @override
  String get mineCheckUpdateDetecting => '업데이트 확인 중...';

  @override
  String get mineCheckUpdateSubtitleDetecting => '최신 버전 확인 중';

  @override
  String get mineUpdateDownloadTitle => '업데이트 다운로드';

  @override
  String get mineDebugRefreshStats => '통계 새로고침 (디버그)';

  @override
  String get mineDebugRefreshStatsSubtitle => '글로벌 통계 프로바이더 재계산 트리거';

  @override
  String get mineDebugRefreshSync => '동기화 상태 새로고침 (디버그)';

  @override
  String get mineDebugRefreshSyncSubtitle => '동기화 상태 프로바이더 새로고침 트리거';

  @override
  String get cloudCurrentService => '현재 클라우드 서비스';

  @override
  String get cloudConnected => '연결됨';

  @override
  String get cloudOfflineMode => '오프라인 모드';

  @override
  String get cloudAvailableServices => '사용 가능한 클라우드 서비스';

  @override
  String get cloudReadCustomConfigFailed => '사용자 정의 설정 읽기 실패';

  @override
  String get cloudNotConfigured => '설정되지 않음';

  @override
  String get cloudNotTested => '테스트되지 않음';

  @override
  String get cloudConnectionNormal => '연결 정상';

  @override
  String get cloudConnectionFailed => '연결 실패';

  @override
  String get cloudAddCustomService => '사용자 정의 클라우드 서비스 추가';

  @override
  String get cloudCustomServiceName => '사용자 정의 클라우드 서비스';

  @override
  String get cloudDefaultServiceName => '기본 클라우드 서비스';

  @override
  String get cloudUseYourSupabase => '자신의 Supabase 사용';

  @override
  String get cloudTest => '테스트';

  @override
  String get cloudSwitchService => '클라우드 서비스 전환';

  @override
  String get cloudSwitchToBuiltinConfirm =>
      '기본 클라우드 서비스로 전환하시겠습니까? 현재 세션에서 로그아웃됩니다.';

  @override
  String get cloudSwitchToCustomConfirm =>
      '사용자 정의 클라우드 서비스로 전환하시겠습니까? 현재 세션에서 로그아웃됩니다.';

  @override
  String get cloudSwitched => '전환됨';

  @override
  String get cloudSwitchedToBuiltin => '기본 클라우드 서비스로 전환하고 로그아웃했습니다';

  @override
  String get cloudSwitchFailed => '전환 실패';

  @override
  String get cloudActivateFailed => '활성화 실패';

  @override
  String get cloudActivateFailedMessage => '저장된 설정이 유효하지 않습니다';

  @override
  String get cloudActivated => '활성화됨';

  @override
  String get cloudActivatedMessage =>
      '사용자 정의 클라우드 서비스로 전환하고 로그아웃했습니다. 다시 로그인하세요';

  @override
  String get cloudEditCustomService => '사용자 정의 클라우드 서비스 편집';

  @override
  String get cloudAddCustomServiceTitle => '사용자 정의 클라우드 서비스 추가';

  @override
  String get cloudSupabaseUrlLabel => 'Supabase URL';

  @override
  String get cloudSupabaseUrlHint => 'https://xxx.supabase.co';

  @override
  String get cloudAnonKeyLabel => 'Anon Key';

  @override
  String get cloudAnonKeyHint =>
      '참고: service_role Key를 입력하지 마세요; Anon Key는 공개됩니다.';

  @override
  String get cloudInvalidInput => '잘못된 입력';

  @override
  String get cloudValidationEmptyFields => 'URL과 Key는 비워둘 수 없습니다';

  @override
  String get cloudValidationHttpsRequired => 'URL은 https://로 시작해야 합니다';

  @override
  String get cloudValidationKeyTooShort => 'Key 길이가 너무 짧습니다. 유효하지 않을 수 있습니다';

  @override
  String get cloudValidationServiceRoleKey => 'service_role Key는 허용되지 않습니다';

  @override
  String get cloudValidationHttpRequired =>
      'URL은 http:// 또는 https://로 시작해야 합니다';

  @override
  String get cloudSelectServiceType => '클라우드 서비스 유형 선택';

  @override
  String get cloudWebdavUrlLabel => 'WebDAV 서버 URL';

  @override
  String get cloudWebdavUrlHint => 'https://dav.jianguoyun.com/dav/';

  @override
  String get cloudWebdavUsernameLabel => '사용자 이름';

  @override
  String get cloudWebdavPasswordLabel => '비밀번호';

  @override
  String get cloudWebdavPathLabel => '원격 경로';

  @override
  String get cloudWebdavPathHint => '/BeeCount';

  @override
  String get cloudWebdavHint => 'Nutstore, Nextcloud, Synology 등 지원';

  @override
  String get cloudConfigUpdated => '설정이 업데이트되었습니다';

  @override
  String get cloudConfigSaved => '설정이 저장되었습니다';

  @override
  String get cloudTestComplete => '테스트 완료';

  @override
  String get cloudTestSuccess => '연결 테스트 성공!';

  @override
  String get cloudTestFailed => '연결 테스트에 실패했습니다. 설정이 올바른지 확인하세요.';

  @override
  String get cloudTestError => '테스트 실패';

  @override
  String get cloudClearConfig => '설정 지우기';

  @override
  String get cloudClearConfigConfirm => '사용자 정의 클라우드 서비스 설정을 지우시겠습니까? (개발 환경만)';

  @override
  String get cloudConfigCleared => '사용자 정의 클라우드 서비스 설정이 지워졌습니다';

  @override
  String get cloudClearFailed => '지우기 실패';

  @override
  String get cloudServiceDescription =>
      '내장 클라우드 서비스 (무료이지만 불안정할 수 있습니다. 자신만의 서비스나 정기 백업을 권장)';

  @override
  String get cloudServiceDescriptionNotConfigured =>
      '현재 빌드에는 내장 클라우드 서비스 설정이 없습니다';

  @override
  String cloudServiceDescriptionCustom(String url) {
    return '서버: $url';
  }

  @override
  String get authLogin => '로그인';

  @override
  String get authSignup => '가입';

  @override
  String get authRegister => '등록';

  @override
  String get authEmail => '이메일';

  @override
  String get authPassword => '비밀번호';

  @override
  String get authPasswordRequirement => '비밀번호 (6자 이상, 문자와 숫자 포함)';

  @override
  String get authConfirmPassword => '비밀번호 확인';

  @override
  String get authInvalidEmail => '유효한 이메일 주소를 입력하세요';

  @override
  String get authPasswordRequirementShort => '비밀번호는 문자와 숫자를 포함하여 6자 이상이어야 합니다';

  @override
  String get authPasswordMismatch => '비밀번호가 일치하지 않습니다';

  @override
  String get authResendVerification => '인증 이메일 재전송';

  @override
  String get authSignupSuccess => '등록 성공';

  @override
  String get authVerificationEmailSent =>
      '인증 이메일을 전송했습니다. 이메일에서 인증을 완료한 후 로그인하세요.';

  @override
  String get authBackToMinePage => '마이페이지로 돌아가기';

  @override
  String get authVerificationEmailResent => '인증 이메일을 재전송했습니다.';

  @override
  String get authResendAction => '인증 재전송';

  @override
  String get authErrorInvalidCredentials => '이메일 또는 비밀번호가 올바르지 않습니다.';

  @override
  String get authErrorEmailNotConfirmed =>
      '이메일이 인증되지 않았습니다. 로그인 전에 이메일에서 인증을 완료하세요.';

  @override
  String get authErrorRateLimit => '시도 횟수가 너무 많습니다. 나중에 다시 시도하세요.';

  @override
  String get authErrorNetworkIssue => '네트워크 오류입니다. 연결을 확인하고 다시 시도하세요.';

  @override
  String get authErrorLoginFailed => '로그인에 실패했습니다. 나중에 다시 시도하세요.';

  @override
  String get authErrorEmailInvalid => '이메일 주소가 유효하지 않습니다. 철자 오류가 없는지 확인하세요.';

  @override
  String get authErrorEmailExists =>
      '이 이메일은 이미 등록되어 있습니다. 직접 로그인하거나 비밀번호를 재설정하세요.';

  @override
  String get authErrorWeakPassword =>
      '비밀번호가 너무 단순합니다. 문자와 숫자를 포함하여 6자 이상으로 설정하세요.';

  @override
  String get authErrorSignupFailed => '등록에 실패했습니다. 나중에 다시 시도하세요.';

  @override
  String authErrorUserNotFound(String action) {
    return '이메일이 등록되지 않았습니다. $action할 수 없습니다.';
  }

  @override
  String authErrorEmailNotVerified(String action) {
    return '이메일이 인증되지 않았습니다. $action할 수 없습니다.';
  }

  @override
  String authErrorActionFailed(String action) {
    return '$action에 실패했습니다. 나중에 다시 시도하세요.';
  }

  @override
  String get importSelectCsvFile => '가져올 파일을 선택하세요 (CSV/TSV/XLSX 지원)';

  @override
  String get exportTitle => '내보내기';

  @override
  String get exportDescription =>
      '아래 버튼을 클릭하여 저장 위치를 선택하고 현재 가계부를 CSV 파일로 내보내세요.';

  @override
  String get exportButtonIOS => '내보내기 및 공유';

  @override
  String get exportButtonAndroid => '데이터 내보내기';

  @override
  String exportSavedTo(String path) {
    return '저장 위치: $path';
  }

  @override
  String get exportSelectFolder => '내보내기 폴더 선택';

  @override
  String get exportCsvHeaderType => '유형';

  @override
  String get exportCsvHeaderCategory => '카테고리';

  @override
  String get exportCsvHeaderAmount => '금액';

  @override
  String get exportCsvHeaderAccount => '계정';

  @override
  String get exportCsvHeaderNote => '메모';

  @override
  String get exportCsvHeaderTime => '시간';

  @override
  String get exportShareText => 'BeeCount 내보내기 파일';

  @override
  String get exportSuccessTitle => '내보내기 성공';

  @override
  String exportSuccessMessageIOS(String path) {
    return '저장되었으며 공유 기록에서 사용 가능:\\n$path';
  }

  @override
  String exportSuccessMessageAndroid(String path) {
    return '저장 위치:\\n$path';
  }

  @override
  String get exportFailedTitle => '내보내기 실패';

  @override
  String get exportTypeIncome => '수입';

  @override
  String get exportTypeExpense => '지출';

  @override
  String get exportTypeTransfer => '이체';

  @override
  String get personalizeThemeHoney => '꿀벌 노랑';

  @override
  String get personalizeThemeOrange => '화염 오렌지';

  @override
  String get personalizeThemeGreen => '에메랄드 그린';

  @override
  String get personalizeThemePurple => '보라 연꽃';

  @override
  String get personalizeThemePink => '체리 핑크';

  @override
  String get personalizeThemeBlue => '하늘 파랑';

  @override
  String get personalizeThemeMint => '숲 달';

  @override
  String get personalizeThemeSand => '석양 모래언덕';

  @override
  String get personalizeThemeLavender => '눈과 소나무';

  @override
  String get personalizeThemeSky => '안개 원더랜드';

  @override
  String get personalizeThemeWarmOrange => '따뜻한 오렌지';

  @override
  String get personalizeThemeMintGreen => '민트 그린';

  @override
  String get personalizeThemeRoseGold => '로즈 골드';

  @override
  String get personalizeThemeDeepBlue => '딥 블루';

  @override
  String get personalizeThemeMapleRed => '단풍 빨강';

  @override
  String get personalizeThemeEmerald => '에메랄드';

  @override
  String get personalizeThemeLavenderPurple => '라벤더';

  @override
  String get personalizeThemeAmber => '호박';

  @override
  String get personalizeThemeRouge => '루즈 레드';

  @override
  String get personalizeThemeIndigo => '인디고 블루';

  @override
  String get personalizeThemeOlive => '올리브 그린';

  @override
  String get personalizeThemeCoral => '코랄 핑크';

  @override
  String get personalizeThemeDarkGreen => '다크 그린';

  @override
  String get personalizeThemeViolet => '바이올렛';

  @override
  String get personalizeThemeSunset => '석양 오렌지';

  @override
  String get personalizeThemePeacock => '공작 파랑';

  @override
  String get personalizeThemeLime => '라임 그린';

  @override
  String get analyticsMonthlyAvg => '월평균';

  @override
  String get analyticsDailyAvg => '일평균';

  @override
  String get analyticsOverallAvg => '전체 평균';

  @override
  String get analyticsTotalIncome => '총 수입: ';

  @override
  String get analyticsTotalExpense => '총 지출: ';

  @override
  String get analyticsBalance => '잔액: ';

  @override
  String analyticsAvgIncome(String avgLabel) {
    return '$avgLabel 수입: ';
  }

  @override
  String analyticsAvgExpense(String avgLabel) {
    return '$avgLabel 지출: ';
  }

  @override
  String get analyticsExpense => '지출';

  @override
  String get analyticsIncome => '수입';

  @override
  String analyticsTotal(String type) {
    return '총 $type: ';
  }

  @override
  String analyticsAverage(String avgLabel) {
    return '$avgLabel: ';
  }

  @override
  String get updateCheckTitle => '업데이트 확인';

  @override
  String get updateNewVersionFound => '새 버전을 찾았습니다';

  @override
  String updateNewVersionTitle(String version) {
    return '새 버전 $version을(를) 찾았습니다';
  }

  @override
  String get updateNoApkFound => 'APK 다운로드 링크를 찾을 수 없습니다';

  @override
  String get updateAlreadyLatest => '이미 최신 버전입니다';

  @override
  String get updateCheckFailed => '업데이트 확인에 실패했습니다';

  @override
  String get updatePermissionDenied => '권한이 거부되었습니다';

  @override
  String get updateUserCancelled => '사용자가 취소했습니다';

  @override
  String get updateDownloadTitle => '업데이트 다운로드';

  @override
  String updateDownloading(String percent) {
    return '다운로드 중: $percent%';
  }

  @override
  String get updateDownloadBackgroundHint =>
      '앱을 백그라운드로 전환할 수 있습니다. 다운로드는 계속됩니다';

  @override
  String get updateCancelButton => '취소';

  @override
  String get updateBackgroundDownload => '백그라운드 다운로드';

  @override
  String get updateLaterButton => '나중에';

  @override
  String get updateDownloadButton => '다운로드';

  @override
  String get updateFoundCachedTitle => '다운로드된 버전을 찾았습니다';

  @override
  String updateFoundCachedMessage(String path) {
    return '이전에 다운로드한 설치 프로그램을 찾았습니다. 바로 설치하시겠습니까?\\n\\n\"확인\"을 클릭하면 즉시 설치하고, \"취소\"를 클릭하면 이 대화상자를 닫습니다.\\n\\n파일 경로: $path';
  }

  @override
  String get updateInstallingCachedApk => '캐시된 APK 설치 중';

  @override
  String get updateDownloadComplete => '다운로드 완료';

  @override
  String get updateInstallStarted => '다운로드 완료, 설치 프로그램 시작됨';

  @override
  String get updateInstallFailed => '설치에 실패했습니다';

  @override
  String get updateDownloadCompleteManual => '다운로드 완료, 수동으로 설치할 수 있습니다';

  @override
  String get updateDownloadCompleteException => '다운로드 완료, 수동으로 설치하세요 (대화상자 예외)';

  @override
  String get updateDownloadCompleteManualContext => '다운로드 완료, 수동으로 설치하세요';

  @override
  String get updateDownloadFailed => '다운로드에 실패했습니다';

  @override
  String get updateInstallTitle => '다운로드 완료';

  @override
  String get updateInstallMessage =>
      'APK 파일 다운로드가 완료되었습니다. 즉시 설치하시겠습니까?\\n\\n참고: 설치 중에 앱이 일시적으로 백그라운드로 이동하는 것은 정상입니다.';

  @override
  String get updateInstallNow => '지금 설치';

  @override
  String get updateInstallLater => '나중에 설치';

  @override
  String get updateNotificationTitle => 'BeeCount 업데이트 다운로드';

  @override
  String get updateNotificationBody => '새 버전 다운로드 중...';

  @override
  String get updateNotificationComplete => '다운로드 완료, 탭하여 설치';

  @override
  String get updateNotificationPermissionTitle => '알림 권한이 거부되었습니다';

  @override
  String get updateNotificationPermissionMessage =>
      '알림 권한을 얻을 수 없습니다. 다운로드 진행률이 알림 표시줄에 표시되지 않지만 다운로드 기능은 정상적으로 작동합니다.';

  @override
  String get updateNotificationGuideTitle => '알림을 활성화해야 하는 경우 다음 단계를 따르세요:';

  @override
  String get updateNotificationStep1 => '시스템 설정 열기';

  @override
  String get updateNotificationStep2 => '\"앱 관리\" 또는 \"앱 설정\" 찾기';

  @override
  String get updateNotificationStep3 => '\"BeeCount\" 앱 찾기';

  @override
  String get updateNotificationStep4 => '\"권한 관리\" 또는 \"알림 관리\" 클릭';

  @override
  String get updateNotificationStep5 => '\"알림 권한\" 활성화';

  @override
  String get updateNotificationMiuiHint =>
      'MIUI 사용자: Xiaomi 시스템은 엄격한 알림 권한 제어가 있어 보안 센터에서 추가 설정이 필요할 수 있습니다';

  @override
  String get updateNotificationGotIt => '알겠습니다';

  @override
  String get updateCheckFailedTitle => '업데이트 확인 실패';

  @override
  String get updateDownloadFailedTitle => '다운로드 실패';

  @override
  String get updateGoToGitHub => 'GitHub로 이동';

  @override
  String get updateCannotOpenLink => '링크를 열 수 없습니다';

  @override
  String get updateManualVisit =>
      '브라우저에서 수동으로 방문하세요:\\nhttps://github.com/TNT-Likely/BeeCount/releases';

  @override
  String get updateNoLocalApkTitle => '업데이트 패키지를 찾을 수 없습니다';

  @override
  String get updateNoLocalApkMessage =>
      '다운로드된 업데이트 패키지 파일을 찾을 수 없습니다.\\n\\n먼저 \"업데이트 확인\"을 통해 새 버전을 다운로드하세요.';

  @override
  String get updateInstallPackageTitle => '업데이트 패키지 설치';

  @override
  String get updateMultiplePackagesTitle => '여러 업데이트 패키지를 찾았습니다';

  @override
  String updateMultiplePackagesMessage(int count, String path) {
    return '$count개의 업데이트 패키지 파일을 찾았습니다.\\n\\n최신 다운로드 버전 사용을 권장하거나 파일 관리자에서 수동으로 설치하세요.\\n\\n파일 위치: $path';
  }

  @override
  String get updateSearchFailedTitle => '검색 실패';

  @override
  String updateSearchFailedMessage(String error) {
    return '로컬 업데이트 패키지 검색 중 오류가 발생했습니다: $error';
  }

  @override
  String get updateFoundCachedPackageTitle => '다운로드된 업데이트 패키지를 찾았습니다';

  @override
  String updateFoundCachedPackageMessage(String fileName, String fileSize) {
    return '이전에 다운로드한 업데이트 패키지가 감지되었습니다:\\n\\n파일 이름: $fileName\\n크기: ${fileSize}MB\\n\\n즉시 설치하시겠습니까?';
  }

  @override
  String get updateIgnoreButton => '무시';

  @override
  String get updateInstallFailedTitle => '설치 실패';

  @override
  String get updateInstallFailedMessage =>
      'APK 설치 프로그램을 시작할 수 없습니다. 파일 권한을 확인하세요.';

  @override
  String get updateErrorTitle => '오류';

  @override
  String updateReadCacheFailedMessage(String error) {
    return '캐시된 업데이트 패키지 읽기에 실패했습니다: $error';
  }

  @override
  String get updateCheckingPermissions => '권한 확인 중...';

  @override
  String get updateCheckingCache => '로컬 캐시 확인 중...';

  @override
  String get updatePreparingDownload => '다운로드 준비 중...';

  @override
  String get updateUserCancelledDownload => '사용자가 다운로드를 취소했습니다';

  @override
  String get updateStartingInstaller => '설치 프로그램 시작 중...';

  @override
  String get updateInstallerStarted => '설치 프로그램을 시작했습니다';

  @override
  String get updateInstallationFailed => '설치에 실패했습니다';

  @override
  String get updateDownloadCompleted => '다운로드 완료';

  @override
  String get updateDownloadCompletedManual => '다운로드 완료, 수동으로 설치할 수 있습니다';

  @override
  String get updateDownloadCompletedDialog => '다운로드 완료, 수동으로 설치하세요 (대화상자 예외)';

  @override
  String get updateDownloadCompletedContext => '다운로드 완료, 수동으로 설치하세요';

  @override
  String get updateDownloadFailedGeneric => '다운로드에 실패했습니다';

  @override
  String get updateCheckingUpdate => '업데이트 확인 중...';

  @override
  String get updateCurrentLatestVersion => '이미 최신 버전입니다';

  @override
  String get updateCheckFailedGeneric => '업데이트 확인에 실패했습니다';

  @override
  String updateDownloadProgress(String percent) {
    return '다운로드 중: $percent%';
  }

  @override
  String get updateNoApkFoundError => 'APK 다운로드 링크를 찾을 수 없습니다';

  @override
  String updateCheckingUpdateError(String error) {
    return '업데이트 확인에 실패했습니다: $error';
  }

  @override
  String get updateNotificationChannelName => '업데이트 다운로드';

  @override
  String get updateNotificationDownloadingIndeterminate => '새 버전 다운로드 중...';

  @override
  String updateNotificationDownloadingProgress(String progress) {
    return '다운로드 진행률: $progress%';
  }

  @override
  String get updateNotificationDownloadCompleteTitle => '다운로드 완료';

  @override
  String get updateNotificationDownloadCompleteMessage =>
      '새 버전이 다운로드되었습니다. 탭하여 설치';

  @override
  String get updateUserCancelledDownloadDialog => '사용자가 다운로드를 취소했습니다';

  @override
  String get updateCannotOpenLinkError => '링크를 열 수 없습니다';

  @override
  String get updateNoLocalApkFoundMessage =>
      '다운로드된 업데이트 패키지 파일을 찾을 수 없습니다.\\n\\n먼저 \"업데이트 확인\"을 통해 새 버전을 다운로드하세요.';

  @override
  String updateInstallPackageFoundMessage(
      String fileName, String fileSize, String time) {
    return '업데이트 패키지를 찾았습니다:\\n\\n파일 이름: $fileName\\n크기: ${fileSize}MB\\n다운로드 시간: $time\\n\\n즉시 설치하시겠습니까?';
  }

  @override
  String updateMultiplePackagesFoundMessage(int count, String path) {
    return '$count개의 업데이트 패키지 파일을 찾았습니다.\\n\\n최신 다운로드 버전 사용을 권장하거나 파일 관리자에서 수동으로 설치하세요.\\n\\n파일 위치: $path';
  }

  @override
  String updateSearchLocalApkError(String error) {
    return '로컬 업데이트 패키지 검색 중 오류가 발생했습니다: $error';
  }

  @override
  String updateCachedPackageFoundMessage(String fileName, String fileSize) {
    return '이전에 다운로드한 업데이트 패키지가 감지되었습니다:\\n\\n파일 이름: $fileName\\n크기: ${fileSize}MB\\n\\n즉시 설치하시겠습니까?';
  }

  @override
  String updateReadCachedPackageError(String error) {
    return '캐시된 업데이트 패키지 읽기에 실패했습니다: $error';
  }

  @override
  String get reminderQuickTestSent => '15초 후 빠른 테스트를 설정했습니다. 앱을 백그라운드에 유지하세요';

  @override
  String get reminderFlutterTestSent =>
      'Flutter 테스트 알림을 전송했습니다. 탭하여 앱이 열리는지 확인하세요';

  @override
  String get reminderAlarmTestSent =>
      'AlarmManager 테스트 알림을 설정했습니다 (1초 후). 탭하여 앱이 열리는지 확인하세요';

  @override
  String get updateOk => '확인';

  @override
  String get updateCannotOpenLinkTitle => '링크를 열 수 없습니다';

  @override
  String get updateCachedVersionTitle => '다운로드된 버전을 찾았습니다';

  @override
  String get updateCachedVersionMessage =>
      '이전에 다운로드한 설치 패키지를 찾았습니다...\"확인\"을 클릭하면 즉시 설치하고, \"취소\"를 클릭하면 닫습니다...';

  @override
  String get updateConfirmDownload => '지금 다운로드하고 설치';

  @override
  String get updateDownloadCompleteTitle => '다운로드 완료';

  @override
  String get updateInstallConfirmMessage => '새 버전이 다운로드되었습니다. 지금 설치하시겠습니까?';

  @override
  String get updateNotificationPermissionGuideText =>
      '다운로드 진행률 알림이 비활성화되어 있지만 다운로드 기능에는 영향을 주지 않습니다. 진행률을 보려면:';

  @override
  String get updateNotificationGuideStep1 => '시스템 설정 > 앱 관리로 이동';

  @override
  String get updateNotificationGuideStep2 => '\"BeeCount\" 앱 찾기';

  @override
  String get updateNotificationGuideStep3 => '알림 권한 활성화';

  @override
  String get updateNotificationGuideInfo => '알림이 없어도 다운로드는 백그라운드에서 정상적으로 계속됩니다';

  @override
  String get currencyCNY => '중국 위안';

  @override
  String get currencyUSD => '미국 달러';

  @override
  String get currencyEUR => '유로';

  @override
  String get currencyJPY => '일본 엔';

  @override
  String get currencyHKD => '홍콩 달러';

  @override
  String get currencyTWD => '신 대만 달러';

  @override
  String get currencyGBP => '영국 파운드';

  @override
  String get currencyAUD => '호주 달러';

  @override
  String get currencyCAD => '캐나다 달러';

  @override
  String get currencyKRW => '한국 원';

  @override
  String get currencySGD => '싱가포르 달러';

  @override
  String get currencyMYR => '말레이시아 링깃';

  @override
  String get currencyTHB => '태국 바트';

  @override
  String get currencyIDR => '인도네시아 루피아';

  @override
  String get currencyPHP => '필리핀 페소';

  @override
  String get currencyVND => '베트남 동';

  @override
  String get currencyINR => '인도 루피';

  @override
  String get currencyRUB => '러시아 루블';

  @override
  String get currencyBYN => '벨라루스 루블';

  @override
  String get currencyNZD => '뉴질랜드 달러';

  @override
  String get currencyCHF => '스위스 프랑';

  @override
  String get currencySEK => '스웨덴 크로나';

  @override
  String get currencyNOK => '노르웨이 크로네';

  @override
  String get currencyDKK => '덴마크 크로네';

  @override
  String get currencyBRL => '브라질 헤알';

  @override
  String get currencyMXN => '멕시코 페소';

  @override
  String get webdavConfiguredTitle => 'WebDAV 클라우드 서비스 설정 완료';

  @override
  String get webdavConfiguredMessage =>
      'WebDAV 클라우드 서비스는 설정 시 제공된 자격 증명을 사용하므로 추가 로그인이 필요하지 않습니다.';

  @override
  String get recurringTransactionTitle => '반복 거래';

  @override
  String get recurringTransactionAdd => '반복 거래 추가';

  @override
  String get recurringTransactionEdit => '반복 거래 편집';

  @override
  String get recurringTransactionFrequency => '빈도';

  @override
  String get recurringTransactionDaily => '매일';

  @override
  String get recurringTransactionWeekly => '매주';

  @override
  String get recurringTransactionMonthly => '매월';

  @override
  String get recurringTransactionYearly => '매년';

  @override
  String get recurringTransactionInterval => '간격';

  @override
  String get recurringTransactionDayOfMonth => '월의 일';

  @override
  String get recurringTransactionStartDate => '시작일';

  @override
  String get recurringTransactionEndDate => '종료일';

  @override
  String get recurringTransactionNoEndDate => '종료일 없음';

  @override
  String get recurringTransactionEnabled => '활성화됨';

  @override
  String get recurringTransactionDisabled => '비활성화됨';

  @override
  String get recurringTransactionNextGeneration => '다음 생성';

  @override
  String get recurringTransactionDeleteConfirm => '이 반복 거래를 삭제하시겠습니까?';

  @override
  String get recurringTransactionEmpty => '반복 거래가 없습니다';

  @override
  String get recurringTransactionEmptyHint => '오른쪽 상단의 + 버튼을 눌러 추가하세요';

  @override
  String recurringTransactionEveryNDays(int n) {
    return '$n일마다';
  }

  @override
  String recurringTransactionEveryNWeeks(int n) {
    return '$n주마다';
  }

  @override
  String recurringTransactionEveryNMonths(int n) {
    return '$n개월마다';
  }

  @override
  String recurringTransactionEveryNYears(int n) {
    return '$n년마다';
  }

  @override
  String get cloudDefaultServiceDisplayName => '기본 클라우드 서비스';

  @override
  String get cloudNotConfiguredDisplay => '설정되지 않음';

  @override
  String get syncNotConfiguredMessage => '클라우드가 설정되지 않았습니다';

  @override
  String get syncNotLoggedInMessage => '로그인되지 않았습니다';

  @override
  String get syncCloudBackupCorruptedMessage =>
      '클라우드 백업 내용이 손상되었습니다. 이전 버전의 인코딩 문제로 인한 것일 수 있습니다. \'현재 가계부를 클라우드에 업로드\'를 클릭하여 덮어쓰고 수정하세요.';

  @override
  String get syncNoCloudBackupMessage => '클라우드 백업 없음';

  @override
  String get syncAccessDeniedMessage => '403 액세스 거부 (스토리지 RLS 정책 및 경로 확인)';

  @override
  String get cloudTestConnection => '연결 테스트';

  @override
  String get cloudLocalStorageTitle => '로컬 저장소';

  @override
  String get cloudLocalStorageSubtitle => '데이터는 로컬 기기에만 저장됩니다';

  @override
  String get cloudCustomSupabaseTitle => '사용자 정의 Supabase';

  @override
  String get cloudCustomSupabaseSubtitle => '자체 호스팅 Supabase 구성하려면 클릭';

  @override
  String get cloudCustomWebdavTitle => '사용자 정의 WebDAV';

  @override
  String get cloudCustomWebdavSubtitle => 'Nutstore/Nextcloud 등을 구성하려면 클릭';

  @override
  String get cloudStatusNotTested => '테스트되지 않음';

  @override
  String get cloudStatusNormal => '연결 정상';

  @override
  String get cloudStatusFailed => '연결 실패';

  @override
  String get cloudCannotOpenLink => '링크를 열 수 없습니다';

  @override
  String get cloudErrorAuthFailed => '인증 실패: 잘못된 API 키';

  @override
  String cloudErrorServerStatus(String code) {
    return '서버가 상태 코드 $code를 반환했습니다';
  }

  @override
  String get cloudErrorWebdavNotSupported => '서버가 WebDAV 프로토콜을 지원하지 않습니다';

  @override
  String get cloudErrorAuthFailedCredentials =>
      '인증 실패: 사용자 이름 또는 비밀번호가 올바르지 않습니다';

  @override
  String get cloudErrorAccessDenied => '액세스 거부됨: 권한을 확인하세요';

  @override
  String cloudErrorPathNotFound(String path) {
    return '서버 경로를 찾을 수 없습니다: $path';
  }

  @override
  String cloudErrorNetwork(String message) {
    return '네트워크 오류: $message';
  }

  @override
  String get cloudTestSuccessTitle => '테스트 성공';

  @override
  String get cloudTestSuccessMessage => '연결 정상, 구성 유효';

  @override
  String get cloudTestFailedTitle => '테스트 실패';

  @override
  String get cloudTestFailedMessage => '연결 실패';

  @override
  String get cloudTestErrorTitle => '테스트 오류';

  @override
  String get cloudSwitchConfirmTitle => '클라우드 서비스 전환';

  @override
  String get cloudSwitchConfirmMessage =>
      '클라우드 서비스를 전환하면 현재 계정이 로그아웃됩니다. 전환하시겠습니까?';

  @override
  String get cloudSwitchFailedTitle => '전환 실패';

  @override
  String get cloudSwitchFailedConfigMissing => '먼저 이 클라우드 서비스를 구성하세요';

  @override
  String get cloudConfigInvalidTitle => '잘못된 구성';

  @override
  String get cloudConfigInvalidMessage => '완전한 정보를 입력하세요';

  @override
  String get cloudSaveFailed => '저장 실패';

  @override
  String cloudSwitchedTo(String type) {
    return '$type(으)로 전환했습니다';
  }

  @override
  String get cloudConfigureSupabaseTitle => 'Supabase 구성';

  @override
  String get cloudConfigureWebdavTitle => 'WebDAV 구성';

  @override
  String get cloudSupabaseAnonKeyHintLong => '완전한 anon key를 붙여넣으세요';

  @override
  String get cloudWebdavRemotePathHelp => '데이터저장的원격디렉토리경로';

  @override
  String get cloudWebdavRemotePathLabel => '원격 경로';

  @override
  String get cloudWebdavRemotePathHelperText => '데이터 저장을 위한 원격 디렉토리 경로';

  @override
  String get accountsTitle => '계정관리';

  @override
  String get accountsManageDesc => '결제 계정 및 잔액 관리';

  @override
  String get accountsEmptyMessage => '还없음계정，탭右上角추가';

  @override
  String get accountAddTooltip => '추가계정';

  @override
  String get accountAddButton => '추가계정';

  @override
  String get accountBalance => '잔액';

  @override
  String get accountEditTitle => '편집계정';

  @override
  String get accountNewTitle => '新建계정';

  @override
  String get accountNameLabel => '계정名称';

  @override
  String get accountNameHint => '例如：工商银行、Alipay等';

  @override
  String get accountNameRequired => '입력계정名称';

  @override
  String get accountTypeLabel => '계정类型';

  @override
  String get accountTypeCash => '현금';

  @override
  String get accountTypeBankCard => '은행 카드';

  @override
  String get accountTypeCreditCard => '신용 카드';

  @override
  String get accountTypeAlipay => 'Alipay';

  @override
  String get accountTypeWechat => 'WeChat';

  @override
  String get accountTypeOther => '기타';

  @override
  String get accountInitialBalance => '초기자금';

  @override
  String get accountInitialBalanceHint => '입력초기자금（선택 사항）';

  @override
  String get accountDeleteWarningTitle => '확인삭제';

  @override
  String accountDeleteWarningMessage(int count) {
    return '该계정有 $count 笔관련거래，삭제후거래기록中的계정정보将被지우기。확인삭제吗？';
  }

  @override
  String get accountDeleteConfirm => '확인삭제该계정吗？';

  @override
  String get accountSelectTitle => '선택계정';

  @override
  String get accountNone => '不선택계정';

  @override
  String get accountsEnableFeature => '활성화계정기능';

  @override
  String get accountsFeatureDescription => '활성화후可以관리多个支付계정，추적매个계정的잔액변화';

  @override
  String get privacyOpenSourceUrlError => '할 수 없음열기링크';

  @override
  String get updateCorruptedFileTitle => '설치 패키지가 손상되었습니다';

  @override
  String get updateCorruptedFileMessage =>
      '이전에 다운로드한 설치 패키지가 불완전하거나 손상된 것으로 감지되었습니다. 삭제하고 다시 다운로드하시겠습니까？';

  @override
  String get welcomeTitle => '환영합니다사용 BeeCount';

  @override
  String get welcomeDescription => '一个진정으로존중您개인정보的记账앱';

  @override
  String get welcomePrivacyTitle => '您的데이터，您제어';

  @override
  String get welcomePrivacyFeature1 => '데이터저장在您的기기로컬';

  @override
  String get welcomePrivacyFeature2 => '不업로드에어떤제3자서버';

  @override
  String get welcomePrivacyFeature3 => '无광고，无데이터收集';

  @override
  String get welcomePrivacyFeature4 => '无需등록계정';

  @override
  String get welcomeOpenSourceTitle => '오픈소스 & 투명';

  @override
  String get welcomeOpenSourceFeature1 => '100%오픈소스코드';

  @override
  String get welcomeOpenSourceFeature2 => '커뮤니티감독，无백도어';

  @override
  String get welcomeOpenSourceFeature3 => '개인사용자무료사용';

  @override
  String get welcomeViewGitHub => '在GitHub보기源코드';

  @override
  String get welcomeCloudSyncTitle => '선택 사항的클라우드동기화';

  @override
  String get welcomeCloudSyncDescription => '不想사용상업클라우드服务？BeeCount지원다양한동기화방법';

  @override
  String get welcomeCloudSyncFeature1 => '완전히오프라인사용';

  @override
  String get welcomeCloudSyncFeature2 => '셀프 호스팅WebDAV동기화';

  @override
  String get welcomeCloudSyncFeature3 => '셀프 호스팅Supabase服务';

  @override
  String get lab => '실험실';

  @override
  String get labDesc => '체험실험적기능';

  @override
  String get widgetManagement => '데스크톱위젯';

  @override
  String get widgetManagementDesc => '在홈 화면빠르게보기수입지출상황';

  @override
  String get widgetPreview => '위젯미리보기';

  @override
  String get widgetPreviewDesc => '위젯자동표시현재账本的실제데이터，테마色따라앱설정';

  @override
  String get howToAddWidget => '방법추가위젯';

  @override
  String get iosWidgetStep1 => '길게 누르기홈 화면빈영역，진입편집모드';

  @override
  String get iosWidgetStep2 => '탭왼쪽 상단的\"+\"버튼';

  @override
  String get iosWidgetStep3 => '검색및선택\"蜜蜂记账\"';

  @override
  String get iosWidgetStep4 => '선택중형위젯，추가에홈 화면';

  @override
  String get androidWidgetStep1 => '길게 누르기홈 화면빈영역';

  @override
  String get androidWidgetStep2 => '선택\"위젯\"또는\"Widgets\"';

  @override
  String get androidWidgetStep3 => '找에및길게 누르기\"蜜蜂记账\"위젯';

  @override
  String get androidWidgetStep4 => '드래그에홈 화면적절한위치';

  @override
  String get aboutWidget => '정보위젯';

  @override
  String get widgetDescription =>
      '위젯자동동기화표시오늘和이번 달的수입지출데이터，매30분자동새로고침한 번。열기앱후즉시업데이트데이터。';

  @override
  String get appName => '蜜蜂记账';

  @override
  String get monthSuffix => '월';

  @override
  String get todayExpense => '오늘지출';

  @override
  String get todayIncome => '오늘수입';

  @override
  String get monthExpense => '이번 달지출';

  @override
  String get monthIncome => '이번 달수입';

  @override
  String get autoScreenshotBilling => '스크린샷 자동 기록';

  @override
  String get autoScreenshotBillingDesc => '스크린샷 후 결제 정보 자동 인식';

  @override
  String get autoScreenshotBillingTitle => '스크린샷 자동 기록';

  @override
  String get featureDescription => '기능 설명';

  @override
  String get featureDescriptionContent =>
      '결제 페이지의 스크린샷을 찍으면 시스템이 금액과 가맹점 정보를 자동으로 인식하고 지출 기록을 생성합니다.\n\n⚡ 인식 속도 약 1-2초\n🤖 자동으로 카테고리 매칭\n📝 자동으로 메모 입력\n\n참고:\n• 접근성 서비스가 활성화되지 않은 경우 인식 속도가 약간 느려집니다(3-5초)\n• 접근성 서비스를 활성화하면 즉시 인식할 수 있습니다';

  @override
  String get autoBilling => '자동 기록';

  @override
  String get enabled => '활성화됨';

  @override
  String get disabled => '비활성화됨';

  @override
  String get accessibilityService => '접근성 서비스';

  @override
  String get accessibilityServiceEnabled => '활성화 - 즉시 인식';

  @override
  String get accessibilityServiceDisabled => '비활성화 - 인식이 느림';

  @override
  String get improveRecognitionSpeed => '인식 속도 향상';

  @override
  String get accessibilityGuideContent =>
      '접근성 서비스를 활성화하면 스크린샷 순간 인식이 가능하며 파일 쓰기를 기다릴 필요가 없습니다.';

  @override
  String get setupSteps => '설정 단계:';

  @override
  String get accessibilityStep1 => '아래 \"접근성 설정 열기\" 버튼을 탭하세요';

  @override
  String get accessibilityStep2 => '목록에서 \"벌꿀 가계부-스크린샷 인식\"을 찾으세요';

  @override
  String get accessibilityStep3 => '서비스 스위치를 활성화하세요';

  @override
  String get accessibilityStep4 => '앱으로 돌아가서 사용하세요';

  @override
  String get openAccessibilitySettings => '접근성 설정 열기';

  @override
  String get accessibilityServiceNote =>
      '💡 참고: 접근성 서비스는 스크린샷 동작 감지에만 사용되며 다른 데이터를 읽거나 수정하지 않습니다.';

  @override
  String get supportedPayments => '지원되는 결제 방법';

  @override
  String get supportedAlipay => '✅ Alipay';

  @override
  String get supportedWechat => '✅ WeChat Pay';

  @override
  String get supportedUnionpay => '✅ UnionPay';

  @override
  String get supportedOthers => '⚠️ 다른 결제 방법의 인식 정확도가 낮을 수 있습니다';

  @override
  String get photosPermissionRequired => '스크린샷을 모니터링하려면 사진 권한이 필요합니다';

  @override
  String get enableSuccess => '자동 기록이 활성화되었습니다';

  @override
  String get disableSuccess => '자동 기록이 비활성화되었습니다';

  @override
  String get autoBillingBatteryTitle => '백그라운드 실행 유지';

  @override
  String get autoBillingBatteryGuideTitle => '배터리 최적화 설정';

  @override
  String get autoBillingBatteryDesc =>
      '자동 기록을 위해서는 앱이 백그라운드에서 계속 실행되어야 합니다. 일부 장치에서는 화면 잠금 후 백그라운드 앱이 자동으로 정리되어 자동 기록 기능이 비활성화될 수 있습니다. 배터리 최적화를 끄는 것이 좋습니다.';

  @override
  String get autoBillingCheckBattery => '배터리 최적화 상태 확인';

  @override
  String get autoBillingBatteryWarning =>
      '⚠️ 배터리 최적화가 꺼져 있지 않습니다. 앱이 시스템에 의해 자동으로 정리되어 자동 기록이 비활성화될 수 있습니다. 위의 \"설정으로 이동\" 버튼을 탭하여 배터리 최적화를 끄는 것이 좋습니다.';

  @override
  String get enableFailed => '활성화 실패';

  @override
  String get disableFailed => '비활성화 실패';

  @override
  String get openSettingsFailed => '설정을 여는 데 실패했습니다';

  @override
  String get reselectImage => '다시 선택';

  @override
  String get viewOriginalText => '원본 텍스트 보기';

  @override
  String get createBill => '청구서 생성';

  @override
  String get ocrBilling => 'OCR 스캔 기록';

  @override
  String get ocrBillingDesc => '결제 스크린샷을 스캔하여 금액 자동 인식';

  @override
  String get quickActions => '빠른 기능';

  @override
  String get iosAutoFeatureDesc =>
      'iOS \"바로 가기\" 앱을 사용하여 스크린샷 후 결제 정보를 자동으로 인식하고 기록합니다. 설정 후 스크린샷을 찍을 때마다 자동으로 인식이 트리거됩니다.';

  @override
  String get iosAutoShortcutQuickAdd => '바로 가기 빠르게 추가';

  @override
  String get iosAutoShortcutQuickAddDesc =>
      '아래 버튼을 탭하면 설정된 바로 가기를 직접 가져오거나 바로 가기 앱을 수동으로 열어 설정할 수 있습니다.';

  @override
  String get iosAutoShortcutImport => '원클릭으로 바로 가기 가져오기';

  @override
  String get iosAutoShortcutOpenApp => '또는 수동으로 바로 가기 앱을 열어 설정';

  @override
  String get iosAutoShortcutConfigTitle => '설정 단계 (권장 방법 - URL 매개변수 전달):';

  @override
  String get iosAutoShortcutStep1 => '\"바로 가기\" 앱 열기';

  @override
  String get iosAutoShortcutStep2 => '오른쪽 상단의 \"+\"를 탭하여 새 바로 가기 만들기';

  @override
  String get iosAutoShortcutStep3 => '\"스크린샷\" 작업 추가 (최신 스크린샷 가져오기)';

  @override
  String get iosAutoShortcutStep4 => '\"스크린샷에서 텍스트 추출\" 작업 추가';

  @override
  String get iosAutoShortcutStep5 =>
      '\"텍스트 바꾸기\" 작업 추가: \"추출된 텍스트\"의 \"\\n\"을 \",\" (쉼표)로 바꿉니다';

  @override
  String get iosAutoShortcutStep6 =>
      '\"URL 인코딩\" 작업 추가: \"바꾼 텍스트\"를 URL 인코딩합니다';

  @override
  String get iosAutoShortcutStep7 =>
      '\"URL 열기\" 작업 추가, URL 입력:\nbeecount://auto-billing?text=[URL 인코딩된 텍스트]';

  @override
  String get iosAutoShortcutStep8 => '바로 가기 설정 (오른쪽 상단의 점 세 개) 탭';

  @override
  String get iosAutoShortcutStep9 => '\"...할 때 실행\"에서 \"스크린샷 찍을 때\" 트리거 추가';

  @override
  String get iosAutoShortcutStep10 => '저장 및 테스트: 스크린샷 후 자동으로 인식됩니다';

  @override
  String get iosAutoShortcutRecommendedTip =>
      '✅ 권장: URL 매개변수 전달, 권한 불필요, 최고의 경험. 중요한 단계:\n• 텍스트를 바꿀 때 줄바꿈 문자\\n을 쉼표,로 바꿉니다 (URL 잘림 방지)\n• URL 인코딩 작업을 사용합니다 (문자 깨짐 방지)\n• 일반적으로 스크린샷 텍스트는 2048자 제한을 초과하지 않습니다';

  @override
  String get iosAutoBackTapTitle => '💡 뒤로 두 번 탭하여 빠르게 트리거 (권장)';

  @override
  String get iosAutoBackTapDesc =>
      '설정 > 손쉬운 사용 > 터치 > 뒤로 탭하기\n• \"이중 탭\" 또는 \"삼중 탭\" 선택\n• 생성한 바로 가기 선택\n• 완료 후 결제 시 전화기 뒤쪽을 두 번 탭하면 스크린샷 없이 자동으로 기록됩니다';

  @override
  String iosAutoImportFailed(Object error) {
    return '가져오기 실패: $error';
  }

  @override
  String iosAutoOpenAppFailed(Object error) {
    return '열기 실패: $error';
  }

  @override
  String get iosAutoCannotOpenLink => '링크를 열 수 없습니다. 네트워크 연결을 확인하세요';

  @override
  String get iosAutoCannotOpenShortcuts => '바로 가기 앱을 열 수 없습니다';

  @override
  String get aiSettingsTitle => 'AI 인식';

  @override
  String get aiSettingsSubtitle => 'AI 모델 및 인식 전략 설정';

  @override
  String get aiEnableTitle => 'AI 인식 활성화';

  @override
  String get aiEnableSubtitle =>
      'AI를 사용하여 OCR 인식 정확도를 향상시키고 금액, 가맹점, 시간 등의 정보를 추출합니다';

  @override
  String get aiEnableToastOn => 'AI 향상이 활성화되었습니다';

  @override
  String get aiEnableToastOff => 'AI 향상이 비활성화되었습니다';

  @override
  String get aiStrategyTitle => '실행 전략';

  @override
  String get aiStrategyLocalFirst => '로컬 우선 (권장)';

  @override
  String get aiStrategyLocalFirstDesc => '로컬 모델을 우선 사용하고 실패 시 자동으로 클라우드로 전환';

  @override
  String get aiStrategyCloudFirst => '클라우드 우선';

  @override
  String get aiStrategyCloudFirstDesc => '클라우드 API를 우선 사용하고 실패 시 로컬로 다운그레이드';

  @override
  String get aiStrategyLocalOnly => '로컬만';

  @override
  String get aiStrategyLocalOnlyDesc => '로컬 모델만 사용, 완전 오프라인';

  @override
  String get aiStrategyCloudOnly => '클라우드만';

  @override
  String get aiStrategyCloudOnlyDesc => '클라우드 API만 사용, 모델을 다운로드하지 않음';

  @override
  String get aiStrategyUnavailable => '로컬 모델이 학습 중입니다. 기대해 주세요';

  @override
  String aiStrategySwitched(String strategy) {
    return '전환되었습니다: $strategy';
  }

  @override
  String get aiCloudApiTitle => 'Zhipu GLM API';

  @override
  String get aiCloudApiKeyLabel => 'API Key';

  @override
  String get aiCloudApiKeyHint => 'Zhipu AI API 키를 입력하세요';

  @override
  String get aiCloudApiKeyHelper => 'GLM-4-Flash 모델은 완전 무료입니다';

  @override
  String get aiCloudApiKeySaved => 'API Key가 저장되었습니다';

  @override
  String get aiCloudApiGetKey => 'API Key 가져오기';

  @override
  String get aiLocalModelTitle => '로컬 모델';

  @override
  String get aiLocalModelTraining => '학습 중';

  @override
  String get aiLocalModelManagement => '모델 관리';

  @override
  String get aiLocalModelUnavailable => '로컬 모델이 학습 중이므로 아직 사용할 수 없습니다';

  @override
  String get aiFabSettingTitle => '빠른 추가 버튼으로 사진 우선';

  @override
  String get aiFabSettingDescCamera => '탭으로 사진 촬영, 길게 눌러 수동 기록';

  @override
  String get aiFabSettingDescManual => '탭으로 수동 기록, 길게 눌러 사진 촬영';

  @override
  String get aiOcrRecognizing => '청구서 인식 중...';

  @override
  String get aiOcrNoAmount => '유효한 금액이 인식되지 않았습니다. 수동으로 기록하세요';

  @override
  String get aiOcrNoLedger => '가계부를 찾을 수 없습니다';

  @override
  String aiOcrSuccess(String type, String amount) {
    return '✅ $type 청구서가 생성되었습니다 ¥$amount';
  }

  @override
  String aiOcrFailed(String error) {
    return '인식 실패: $error';
  }

  @override
  String get aiOcrCreateFailed => '청구서 생성에 실패했습니다';

  @override
  String get aiTypeIncome => '수입';

  @override
  String get aiTypeExpense => '지출';

  @override
  String get ocrRecognitionResult => '인식 결과';

  @override
  String get ocrAmount => '금액';

  @override
  String get ocrNoAmountDetected => '금액이 감지되지 않음';

  @override
  String get ocrManualAmountInput => '또는 수동으로 금액 입력';

  @override
  String get ocrMerchant => '판매자';

  @override
  String get ocrSuggestedCategory => '추천 카테고리';

  @override
  String get ocrTime => '시간';

  @override
  String get cloudSyncAndBackup => '클라우드 동기화 및 백업';

  @override
  String get cloudSyncAndBackupDesc => '클라우드 서비스 구성, 데이터 동기화 관리';

  @override
  String get cloudSyncPageTitle => '클라우드 동기화 및 백업';

  @override
  String get cloudSyncPageSubtitle => '클라우드 서비스 및 데이터 동기화 관리';

  @override
  String get dataManagement => '데이터 관리';

  @override
  String get dataManagementDesc => '가져오기, 내보내기, 카테고리 및 계정';

  @override
  String get dataManagementPageTitle => '데이터 관리';

  @override
  String get dataManagementPageSubtitle => '거래 데이터 및 카테고리 관리';

  @override
  String get smartBilling => '스마트 기록';

  @override
  String get smartBillingDesc => 'AI 인식, OCR 스캔, 자동 기록';

  @override
  String get smartBillingPageTitle => '스마트 기록';

  @override
  String get smartBillingPageSubtitle => 'AI 및 자동화 기록 기능';

  @override
  String get automation => '자동화';

  @override
  String get automationDesc => '반복 거래 및 알림';

  @override
  String get automationPageTitle => '자동화 기능';

  @override
  String get automationPageSubtitle => '반복 거래 및 알림 설정';

  @override
  String get appearanceSettings => '외관 설정';

  @override
  String get appearanceSettingsDesc => '테마, 글꼴, 언어 설정';

  @override
  String get appearanceSettingsPageTitle => '외관 설정';

  @override
  String get appearanceSettingsPageSubtitle => '외관 및 디스플레이 사용자 지정';

  @override
  String get about => '정보';

  @override
  String get aboutDesc => '버전 정보, 도움말 및 피드백';

  @override
  String get mineRateApp => '앱 평가하기';

  @override
  String get mineRateAppSubtitle => 'App Store에서 평가하기';

  @override
  String get aboutPageTitle => '정보';

  @override
  String get aboutPageSubtitle => '앱 정보 및 도움말';

  @override
  String get aboutPageLoadingVersion => '버전 번호 로드 중...';

  @override
  String get aboutGitHubRepo => 'GitHub 저장소';

  @override
  String get aboutContactEmail => '문의 이메일';

  @override
  String get aboutWeChatGroup => 'WeChat 그룹';

  @override
  String get aboutWeChatGroupDesc => 'QR 코드를 보려면 탭하세요';

  @override
  String get aboutXiaohongshu => '샤오홍슈';

  @override
  String get aboutDouyin => 'Douyin';

  @override
  String get aboutTelegramGroup => 'Telegram 그룹';

  @override
  String get aboutCopied => '클립보드에 복사됨';

  @override
  String get aboutSupportDevelopment => 'Support Development';

  @override
  String get aboutSupportDevelopmentSubtitle => 'Buy me a coffee';

  @override
  String get cloudService => '클라우드 서비스';

  @override
  String get cloudServiceDesc => '클라우드 스토리지 공급자 구성';

  @override
  String get syncManagement => '동기화 관리';

  @override
  String get syncManagementDesc => '데이터 동기화 및 백업';

  @override
  String get moreSettings => '추가 설정';

  @override
  String get moreSettingsDesc => '고급 클라우드 동기화 옵션';

  @override
  String get configImportExportTitle => 'Config Import/Export';

  @override
  String get configImportExportSubtitle =>
      'Backup and restore app configurations';

  @override
  String get configImportExportInfoTitle => 'Feature Description';

  @override
  String get configImportExportInfoMessage =>
      'This feature is used to export and import app configurations, including cloud service settings, AI settings, etc. The config file uses YAML format for easy viewing and editing.\n\n⚠️ Config files contain sensitive information (such as API keys, passwords, etc.), please keep them safe.';

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
  String get configImportConfirmMessage =>
      'Importing config will overwrite current settings, continue?';

  @override
  String get configImportSuccess => 'Config imported successfully';

  @override
  String get configImportFailed => 'Config import failed';

  @override
  String get configImportRestartTitle => 'Restart Required';

  @override
  String get configImportRestartMessage =>
      'Config has been imported. Some settings will take effect after restarting the app.';

  @override
  String get configImportExportIncludesTitle => 'Included Configurations';

  @override
  String configExportSavedTo(String path) {
    return 'Saved to: $path';
  }

  @override
  String get configExportOpenFile => 'Open Folder';

  @override
  String get configExportOpenFileFailed => 'Unable to open folder';

  @override
  String get configExportViewContent => 'View Content';

  @override
  String get configExportCopyContent => 'Copy Content';

  @override
  String get configExportContentCopied => 'Copied to clipboard';

  @override
  String get configExportReadFileFailed => 'Failed to read file';

  @override
  String get configIncludeSupabase => 'Supabase cloud service config';

  @override
  String get configIncludeWebdav => 'WebDAV cloud service config';

  @override
  String get configIncludeAI => 'AI smart recognition config';

  @override
  String get ledgersConflictTitle => 'Sync Conflict';

  @override
  String get ledgersConflictMessage =>
      'Local and cloud ledger data are inconsistent, please choose an action:';

  @override
  String ledgersConflictLocalInfo(int count) {
    return 'Local: $count transactions';
  }

  @override
  String ledgersConflictRemoteInfo(int count) {
    return 'Cloud: $count transactions';
  }

  @override
  String ledgersConflictLocalUpdated(String time) {
    return 'Local updated: $time';
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
  String get storageManagementTitle => '저장 공간 관리';

  @override
  String get storageManagementSubtitle => '캐시를 정리하여 공간 확보';

  @override
  String get storageAIModels => 'AI 모델';

  @override
  String get storageAPKFiles => '설치 패키지';

  @override
  String get storageNoData => '데이터 없음';

  @override
  String get storageFiles => '개 파일';

  @override
  String get storageHint => '항목을 탭하면 해당 캐시 파일을 정리할 수 있습니다';

  @override
  String get storageClearConfirmTitle => '정리 확인';

  @override
  String storageClearAIModelsMessage(String size) {
    return '모든 AI 모델을 정리하시겠습니까? 크기: $size';
  }

  @override
  String storageClearAPKMessage(String size) {
    return '모든 설치 패키지를 정리하시겠습니까? 크기: $size';
  }

  @override
  String get storageClearSuccess => '정리 성공';

  @override
  String get accountNoTransactions => 'No transactions';

  @override
  String get accountTransactionHistory => 'Transaction History';

  @override
  String get accountTotalBalance => 'Total Balance';

  @override
  String get accountTotalExpense => 'Total Expense';

  @override
  String get accountTotalIncome => 'Total Income';

  @override
  String get accountDetailTitle => 'Account Details';

  @override
  String get commonUncategorized => 'Uncategorized';
}
