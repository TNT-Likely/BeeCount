import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get aiConsentTitle => 'AI 기능을 켜기 전에';

  @override
  String get aiConsentBody => 'AI 기능을 사용하면 관련 데이터가 사용자가 설정한 제3자 AI 제공업체로 전송됩니다:\n\n• 전송 대상: 기본값은 즈푸 GLM(open.bigmodel.cn, 즈푸 운영)이며, 다른 제3자 AI 서비스를 설정한 경우 해당 제공업체로 전송됩니다.\n• 전송 내용: 인식/대화를 위해 직접 사용하는 콘텐츠 — 영수증 이미지, 음성 녹음, 입력한 텍스트, 그리고 인식/분석을 완료하는 데 필요한 카테고리 이름, 계정 이름 및 관련 거래 기록.\n• 목적: 사용자가 직접 시작한 영수증 인식, 기록, 대화에만 사용되며 BeeCount 자체는 이 데이터를 수집하거나 저장하지 않습니다.\n\n해당 데이터는 제3자 제공업체의 자체 개인정보 처리방침에 따라 처리됩니다. 켜면 위와 같은 데이터 공유에 동의하는 것입니다.';

  @override
  String get aiConsentAgree => '동의하고 켜기';

  @override
  String get aboutPrivacyPolicy => '개인정보 처리방침';

  @override
  String get appTitle => '꿀벌 가계부';

  @override
  String get tabHome => '홈';

  @override
  String get tabInsights => '통계';

  @override
  String get tabAssets => '자산';

  @override
  String get tabRecord => '기록';

  @override
  String get tabMine => '내 정보';

  @override
  String get commonCancel => '취소';

  @override
  String get commonConfirm => '확인';

  @override
  String get commonSave => '저장';

  @override
  String get commonDelete => '삭제';

  @override
  String get commonAdd => '추가';

  @override
  String get commonEdit => '편집';

  @override
  String get commonMore => '더보기';

  @override
  String get commonOk => '확인';

  @override
  String get commonKnow => '확인했습니다';

  @override
  String get commonNo => '아니요';

  @override
  String get commonEmpty => '데이터 없음';

  @override
  String get commonError => '오류';

  @override
  String get commonSuccess => '성공';

  @override
  String get commonFailed => '실패';

  @override
  String get commonBack => '뒤로';

  @override
  String get commonNext => '다음';

  @override
  String get fabActionCamera => '카메라';

  @override
  String get fabActionGallery => '갤러리';

  @override
  String get fabActionVoice => '음성';

  @override
  String get fabActionVoiceDisabled => 'AI 활성화 및 API 키 필요';

  @override
  String get voiceRecordingTitle => '음성 기록';

  @override
  String get voiceRecordingPreparing => '준비 중...';

  @override
  String get voiceRecordingInProgress => '녹음 중...';

  @override
  String get voiceRecordingProcessing => '인식 중...';

  @override
  String voiceRecordingDuration(int duration) {
    return '녹음 시간: $duration초';
  }

  @override
  String get voiceRecordingSuccess => '음성 기록 성공';

  @override
  String get voiceRecordingNoLedger => '가계부를 찾을 수 없습니다';

  @override
  String get voiceRecordingNoInfo => '인식된 결제 정보가 없습니다';

  @override
  String get voiceRecordingPermissionDenied => '마이크 권한이 필요합니다';

  @override
  String get voiceRecordingPermissionDeniedTitle => '마이크 권한 필요';

  @override
  String get voiceRecordingPermissionDeniedMessage => '음성 기록에는 마이크 권한이 필요합니다. 시스템 설정에서 BeeCount의 마이크 접근을 허용해 주세요.';

  @override
  String voiceRecordingStartFailed(String error) {
    return '녹음 시작 실패: $error';
  }

  @override
  String voiceRecordingFailed(String error) {
    return '녹음 실패: $error';
  }

  @override
  String voiceRecordingRecognizeFailed(String error) {
    return '인식 실패: $error';
  }

  @override
  String voiceRecordingNoInfoDetected(String text) {
    return '결제 정보를 추출할 수 없습니다: $text';
  }

  @override
  String get voiceRecordingNoSpeech => '음성이 감지되지 않았습니다';

  @override
  String get voiceRecordingHoldToTalk => '눌러서 말하기';

  @override
  String get voiceRecordingReleaseToFinish => '떼면 종료';

  @override
  String get voiceRecordingTooShort => '녹음 시간이 너무 짧습니다';

  @override
  String get voiceRecordingResultLabel => '인식 결과:';

  @override
  String get voiceRecordingAutoHintSpoken => '말을 멈추면 자동으로 인식합니다';

  @override
  String get voiceRecordingAutoHintWaiting => '말씀을 시작해 주세요...';

  @override
  String get smartBillingVoiceTrigger => '음성 트리거 모드';

  @override
  String get voiceTriggerModeAuto => '일시정지 자동 감지';

  @override
  String get voiceTriggerModeAutoDesc => '일시정지 후 자동으로 종료됩니다. 짧은 입력에 적합합니다';

  @override
  String get voiceTriggerModeHold => '눌러서 말하기';

  @override
  String get voiceTriggerModeHoldDesc => '누르고 있는 동안 녹음하고 떼면 종료됩니다. 긴 입력에 적합합니다';

  @override
  String get smartBillingVoiceSilenceTimeout => '일시정지 시 종료';

  @override
  String smartBillingVoiceSilenceTimeoutValue(String seconds) {
    return '$seconds초간 정지되면 자동 종료';
  }

  @override
  String get commonPrevious => '이전';

  @override
  String get commonFinish => '완료';

  @override
  String get commonClose => '닫기';

  @override
  String get commonOther => '기타';

  @override
  String get commonYesterday => '어제';

  @override
  String get commonSearch => '검색';

  @override
  String get commonNoteHint => '메모...';

  @override
  String get commonSettings => '설정';

  @override
  String get commonGoSettings => '설정으로 이동';

  @override
  String get commonLanguage => '언어';

  @override
  String get commonCurrent => '현재';

  @override
  String get commonTutorial => '튜토리얼';

  @override
  String get commonConfigure => '설정';

  @override
  String get commonPressAgainToExit => '한 번 더 누르면 종료됩니다';

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
  String get homeIncome => '수입';

  @override
  String get homeExpense => '지출';

  @override
  String get homeBalance => '잔액';

  @override
  String get homeNoRecords => '아직 기록이 없습니다';

  @override
  String get homeSelectDate => '날짜 선택';

  @override
  String get homeAppTitle => '꿀벌 가계부';

  @override
  String get homeSearch => '검색';

  @override
  String homeYear(int year) {
    return '$year';
  }

  @override
  String homeMonth(String month) {
    return '$month월';
  }

  @override
  String get homeNoRecordsSubtext => '하단의 플러스 버튼을 눌러 기록을 추가하세요';

  @override
  String get homeLastMonthReportSubtitle => '지난달 리포트를 보고 공유하세요';

  @override
  String get homeLastMonthReportView => '보기';

  @override
  String homeAnnualReportReminder(int year) {
    return '$year년 연간 리포트가 준비되었습니다';
  }

  @override
  String get homeAnnualReportView => '보기';

  @override
  String get widgetTodayExpense => '오늘 지출';

  @override
  String get widgetTodayIncome => '오늘 수입';

  @override
  String get widgetMonthExpense => '이번 달 지출';

  @override
  String get widgetMonthIncome => '이번 달 수입';

  @override
  String get widgetMonthSuffix => '';

  @override
  String get searchTitle => '검색';

  @override
  String get searchHint => '메모, 카테고리 또는 금액 검색...';

  @override
  String get searchCategoryHint => '카테고리 이름 검색...';

  @override
  String get searchMinAmount => '최소 금액';

  @override
  String get searchMaxAmount => '최대 금액';

  @override
  String get searchNoInput => '키워드를 입력해 검색을 시작하세요';

  @override
  String get searchNoResults => '일치하는 결과가 없습니다';

  @override
  String get searchBatchMode => '일괄 작업';

  @override
  String searchBatchModeWithCount(Object selected, Object total) {
    return '일괄 작업 ($selected/$total)';
  }

  @override
  String get searchExitBatchMode => '일괄 작업 모드 종료';

  @override
  String get searchSelectAll => '전체 선택';

  @override
  String get searchDeselectAll => '전체 선택 해제';

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
    return '선택한 $count건의 거래를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get searchBatchSetNoteTitle => '메모 일괄 설정';

  @override
  String searchBatchSetNoteMessage(Object count) {
    return '선택한 $count건의 거래에 동일한 메모를 설정합니다';
  }

  @override
  String get searchBatchSetNoteHint => '메모 내용을 입력하세요 (비워두면 메모가 지워집니다)';

  @override
  String searchBatchDeleteSuccess(Object count) {
    return '$count건의 거래를 삭제했습니다';
  }

  @override
  String searchBatchDeleteFailed(Object error) {
    return '삭제 실패: $error';
  }

  @override
  String searchBatchSetNoteSuccess(Object count) {
    return '$count건의 거래에 메모를 설정했습니다';
  }

  @override
  String searchBatchSetNoteFailed(Object error) {
    return '메모 설정 실패: $error';
  }

  @override
  String searchBatchChangeCategorySuccess(Object count) {
    return '$count건의 거래 카테고리를 변경했습니다';
  }

  @override
  String searchBatchChangeCategoryFailed(Object error) {
    return '카테고리 변경 실패: $error';
  }

  @override
  String searchResultsCount(Object count) {
    return '$count개 결과';
  }

  @override
  String get searchSummaryIncome => '수입';

  @override
  String get searchSummaryExpense => '지출';

  @override
  String get searchFilterTitle => '필터';

  @override
  String get searchAmountFilter => '금액 필터';

  @override
  String get searchDateFilter => '날짜 필터';

  @override
  String get searchStartDate => '시작일';

  @override
  String get searchEndDate => '종료일';

  @override
  String get searchNotSet => '설정 안 됨';

  @override
  String get searchClearFilter => '필터 지우기';

  @override
  String get searchBatchCategoryTransferError => '선택한 거래에 이체가 포함되어 있어 카테고리를 변경할 수 없습니다';

  @override
  String get searchBatchCategoryTypeError => '선택한 거래의 유형이 다릅니다. 수입 또는 지출 중 하나만 선택해 주세요';

  @override
  String get searchDateStart => '시작';

  @override
  String get searchDateEnd => '종료';

  @override
  String get analyticsMonth => '월';

  @override
  String get analyticsYear => '년';

  @override
  String get analyticsAll => '전체';

  @override
  String get analyticsCategoryRanking => '카테고리 순위';

  @override
  String get analyticsTotalAmount => '합계';

  @override
  String get analyticsNoDataSubtext => '좌우로 스와이프해 기간을 전환하거나 버튼을 눌러 수입/지출을 전환하세요';

  @override
  String get analyticsSwipeHint => '좌우로 스와이프해 기간 전환';

  @override
  String analyticsSwitchTo(String type) {
    return '$type(으)로 전환';
  }

  @override
  String get analyticsTipHeader => '팁: 상단 캡슐을 눌러 월/년/전체를 전환할 수 있습니다';

  @override
  String get analyticsSwipeToSwitch => '스와이프해 전환';

  @override
  String get analyticsAllYears => '전체 기간';

  @override
  String get analyticsToday => '오늘';

  @override
  String get splashAppName => '꿀벌 가계부';

  @override
  String get splashSlogan => '매 순간의 기록';

  @override
  String get splashSecurityTitle => '오픈소스 데이터 보안';

  @override
  String get splashSecurityFeature1 => '• 로컬 데이터 저장으로 완전한 개인정보 보호';

  @override
  String get splashSecurityFeature2 => '• 오픈소스 코드 투명성으로 신뢰할 수 있는 보안';

  @override
  String get splashSecurityFeature3 => '• 선택적 클라우드 동기화로 기기 간 데이터 일치';

  @override
  String get splashInitializing => '데이터 초기화 중...';

  @override
  String get ledgersTitle => '가계부 관리';

  @override
  String get ledgersNew => '새 가계부';

  @override
  String get ledgersClear => '가계부 비우기';

  @override
  String ledgersClearMessage(Object name) {
    return '가계부 \"$name\"의 모든 거래를 비우시겠습니까? 이 작업은 되돌릴 수 없습니다.\\n가계부 자체는 유지되며 거래 데이터만 삭제됩니다.';
  }

  @override
  String get ledgerDefaultName => '기본 가계부';

  @override
  String get ledgersEdit => '가계부 편집';

  @override
  String get ledgersDelete => '가계부 삭제';

  @override
  String get ledgersDeleteConfirm => '가계부 삭제';

  @override
  String get ledgersDeleteMessage => '이 가계부와 모든 기록을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.\\n클라우드에 백업이 있는 경우 함께 삭제됩니다.';

  @override
  String get ledgersDeleted => '삭제됨';

  @override
  String get ledgersDeleteFailed => '삭제 실패';

  @override
  String get ledgersClearTitle => '가계부 비우기';

  @override
  String get ledgersClearSuccess => '가계부를 비웠습니다';

  @override
  String get ledgersDeleteLocal => '로컬 가계부만 삭제';

  @override
  String get ledgersDeleteLocalTitle => '로컬 가계부 삭제';

  @override
  String ledgersDeleteLocalMessage(Object name) {
    return '로컬 가계부 \"$name\"를 삭제하시겠습니까?\\n클라우드 백업은 유지되며 언제든지 복원할 수 있습니다.';
  }

  @override
  String get ledgersDeleteLocalSuccess => '로컬 가계부가 삭제되었습니다';

  @override
  String get ledgersName => '이름';

  @override
  String get ledgersDefaultLedgerName => '기본 가계부';

  @override
  String get ledgersCurrency => '통화';

  @override
  String get ledgersMonthStartDay => '월 시작일';

  @override
  String get ledgersMonthStartDayHint => '통계와 예산은 이 날짜(1~28)를 매월 기간의 시작으로 사용합니다';

  @override
  String get ledgersMonthStartDayNatural => '1일 (달력 기준)';

  @override
  String ledgersMonthStartDayValue(int day) {
    return '매월 $day일';
  }

  @override
  String get ledgersSelectCurrency => '통화 선택';

  @override
  String get ledgersSearchCurrency => '검색: 중국어 또는 코드';

  @override
  String get ledgersCreate => '만들기';

  @override
  String get ledgersActions => '작업';

  @override
  String ledgersRecords(String count) {
    return '기록: $count건';
  }

  @override
  String ledgersBalance(String balance) {
    return '잔액: $balance';
  }

  @override
  String get ledgerCardDownloadCloud => '클라우드에서 다운로드';

  @override
  String get ledgersLocal => '로컬 가계부';

  @override
  String get ledgersRemote => '클라우드 가계부';

  @override
  String get ledgersEmpty => '가계부가 없습니다';

  @override
  String get ledgersRestoreAll => '전체 복원';

  @override
  String ledgersSwitched(String name) {
    return '가계부 \"$name\"(으)로 전환되었습니다';
  }

  @override
  String get ledgersDownloadTitle => '가계부 다운로드';

  @override
  String ledgersDownloadMessage(String name) {
    return '가계부 \"$name\"를 로컬로 다운로드하시겠습니까?';
  }

  @override
  String get ledgersDownloading => '다운로드 중...';

  @override
  String ledgersDownloadSuccess(String name) {
    return '가계부 \"$name\"를 다운로드했습니다';
  }

  @override
  String get ledgersDownload => '다운로드';

  @override
  String get ledgersDeleteRemote => '클라우드 가계부 삭제';

  @override
  String get ledgersDeleteRemoteConfirm => '클라우드 가계부 삭제';

  @override
  String ledgersDeleteRemoteMessage(String name) {
    return '클라우드 가계부 \"$name\"를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get ledgersDeleting => '삭제 중...';

  @override
  String get ledgersDeleteRemoteSuccess => '클라우드 가계부가 삭제되었습니다';

  @override
  String get ledgersCannotDeleteLastOne => '마지막 남은 가계부는 삭제할 수 없습니다';

  @override
  String get ledgersRestoreAllTitle => '일괄 복원';

  @override
  String ledgersRestoreAllMessage(int count) {
    return '모든 클라우드 가계부를 복원하시겠습니까? 총 $count개입니다.';
  }

  @override
  String get ledgersRestoring => '복원 중...';

  @override
  String get ledgersRestoreComplete => '복원 완료';

  @override
  String ledgersRestoreResult(int success, int failed) {
    return '성공: $success, 실패: $failed';
  }

  @override
  String get categoryTitle => '카테고리 관리';

  @override
  String get categoryNew => '새 카테고리';

  @override
  String get categoryExpense => '지출';

  @override
  String get categoryIncome => '수입';

  @override
  String get categoryEmpty => '카테고리가 없습니다';

  @override
  String get categoryDefault => '기본 카테고리';

  @override
  String get categoryReorderTip => '길게 눌러 카테고리 순서를 드래그하여 변경하세요';

  @override
  String categoryLoadFailed(String error) {
    return '불러오기 실패: $error';
  }

  @override
  String get iconPickerTitle => '아이콘 선택';

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
  String get iconCategoryDining => '식사';

  @override
  String get importTitle => '명세서 가져오기';

  @override
  String get importBillType => '명세서 유형';

  @override
  String get importBillTypeGeneric => '일반 CSV';

  @override
  String get importBillTypeAlipay => '알리페이';

  @override
  String get importBillTypeWechat => '위챗';

  @override
  String get importChooseFile => '파일 선택';

  @override
  String get importNoFileSelected => '선택된 파일이 없습니다';

  @override
  String get importHint => '팁: 가져오기를 시작하려면 파일을 선택하세요 (CSV/TSV/XLSX)';

  @override
  String get importReading => '파일 읽는 중…';

  @override
  String get importPreparing => '준비 중…';

  @override
  String importColumnNumber(Object number) {
    return '$number열';
  }

  @override
  String get importConfirmMapping => '매핑 확인';

  @override
  String get importCategoryMapping => '카테고리 매핑';

  @override
  String get importNoDataParsed => '파싱된 데이터가 없습니다. 이전 페이지로 돌아가 CSV 내용이나 구분자를 확인해 주세요.';

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
    return '전체 $total건 중 처음 $shown건을 표시합니다';
  }

  @override
  String get importCategoryNotSelected => '카테고리가 선택되지 않았습니다';

  @override
  String get importCategoryMappingDescription => '각 카테고리 이름에 해당하는 로컬 카테고리를 선택하세요:';

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
  String get importSelectCategoryFirst => '먼저 카테고리 매핑을 선택해 주세요';

  @override
  String get importNextStep => '다음 단계';

  @override
  String get importPreviousStep => '이전 단계';

  @override
  String get importStartImport => '가져오기 시작';

  @override
  String get importAutoDetect => '자동 감지';

  @override
  String get importInProgress => '가져오는 중';

  @override
  String importProgressDetail(Object done, Object fail, Object ok, Object total) {
    return '$total건 중 $done건 가져옴, 성공 $ok, 실패 $fail';
  }

  @override
  String get importBackgroundImport => '백그라운드로 가져오기';

  @override
  String get importCancelled => '가져오기 취소됨';

  @override
  String importCompleted(Object cancelled, Object fail, Object ok) {
    return '가져오기 완료$cancelled, 성공 $ok, 실패 $fail';
  }

  @override
  String importSkippedNonTransactionTypes(Object count) {
    return '거래가 아닌 $count건(부채 등)을 건너뛰었습니다';
  }

  @override
  String importTransactionFailed(Object error) {
    return '가져오기에 실패하여 모든 변경사항이 롤백되었습니다: $error';
  }

  @override
  String importFileOpenError(String error) {
    return '파일 선택기를 열 수 없습니다: $error';
  }

  @override
  String get mineTitle => '내 정보';

  @override
  String get mineReminder => '알림 설정';

  @override
  String get mineImport => '데이터 가져오기';

  @override
  String get mineExport => '데이터 내보내기';

  @override
  String get mineCloud => '클라우드 서비스';

  @override
  String get mineUpdate => '업데이트 확인';

  @override
  String get mineLanguageSettings => '언어';

  @override
  String get languageTitle => '언어 설정';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystemDefault => '시스템 따르기';

  @override
  String get deleteConfirmTitle => '삭제 확인';

  @override
  String get deleteConfirmMessage => '이 기록을 삭제하시겠습니까?';

  @override
  String get mineSlogan => '꿀벌 가계부, 한 푼도 소중하게';

  @override
  String get mineDisplayNameEditTitle => '닉네임 설정';

  @override
  String get mineDisplayNameHint => '닉네임을 입력하세요';

  @override
  String get mineDisplayNameSaved => '닉네임이 업데이트되었습니다';

  @override
  String get mineGreetingMorning => '좋은 아침이에요';

  @override
  String get mineGreetingNoon => '좋은 점심이에요';

  @override
  String get mineGreetingAfternoon => '좋은 오후예요';

  @override
  String get mineGreetingEvening => '좋은 저녁이에요';

  @override
  String get mineGreetingNight => '편안한 밤 되세요';

  @override
  String mineGreetingNamed(String greeting, String name) {
    return '$greeting, $name님';
  }

  @override
  String get mineProfileEditTitle => '프로필 편집';

  @override
  String get headerSkinTitle => '스킨';

  @override
  String get headerSkinSubtitle => '테마 색상을 따르며 헤더 위에 겹쳐 표시됩니다';

  @override
  String get headerSkinNone => '단색';

  @override
  String get headerSkinAurora => '오로라';

  @override
  String get headerSkinMountains => '산';

  @override
  String get headerSkinBokeh => '보케';

  @override
  String get headerSkinWaves => '물결';

  @override
  String get headerSkinSunset => '노을';

  @override
  String get headerSkinClouds => '구름';

  @override
  String get headerSkinExample => '예시';

  @override
  String get headerSkinHoneycomb => '벌집';

  @override
  String get headerSkinStarry => '별밤';

  @override
  String get headerSkinStripes => '스트라이프';

  @override
  String get headerSkinSkyline => '스카이라인';

  @override
  String get headerSkinSakura => '벚꽃';

  @override
  String get headerSkinMeteor => '유성';

  @override
  String get headerSkinMemphis => '멤피스';

  @override
  String get headerSkinSilk => 'Silk';

  @override
  String get headerSkinBubbles => 'Bubbles';

  @override
  String get headerSkinGalaxy => 'Galaxy';

  @override
  String get headerSkinLowPoly => 'Low-poly';

  @override
  String get headerSkinPrism => 'Prism';

  @override
  String get headerSkinTerrazzo => 'Terrazzo';

  @override
  String get mineAvatarTitle => '아바타 설정';

  @override
  String get mineAvatarFromGallery => '갤러리에서 선택';

  @override
  String get mineAvatarFromCamera => '사진 촬영';

  @override
  String get mineAvatarDelete => '아바타 삭제';

  @override
  String get annualReportTitle => '연간 리포트';

  @override
  String annualReportSubtitle(int year) {
    return '$year년의 재정 여정을 돌아보세요';
  }

  @override
  String get annualReportEntrySubtitle => '나만의 연간 리포트를 만들어 공유하세요';

  @override
  String annualReportNoData(int year) {
    return '$year년 데이터가 없습니다';
  }

  @override
  String get annualReportPage1Title => '연간 개요';

  @override
  String annualReportPage1Subtitle(int year) {
    return '$year년의 가계부 여정';
  }

  @override
  String get annualReportTotalDays => '기록한 일수';

  @override
  String get annualReportTotalRecords => '총 기록 수';

  @override
  String get annualReportTotalIncome => '총 수입';

  @override
  String get annualReportTotalExpense => '총 지출';

  @override
  String get annualReportNetSavings => '순 저축액';

  @override
  String get annualReportPage2Title => '지출 분석';

  @override
  String get annualReportPage2Subtitle => '돈이 어디로 갔는지';

  @override
  String get annualReportPage3Title => '월별 추이';

  @override
  String get annualReportPage3Subtitle => '12개월 수입 및 지출';

  @override
  String get annualReportHighestMonth => '지출이 가장 많은 달';

  @override
  String get annualReportLowestMonth => '지출이 가장 적은 달';

  @override
  String get annualReportPage4Title => '특별한 순간';

  @override
  String get annualReportPage4Subtitle => '기억에 남는 거래';

  @override
  String get annualReportLargestExpense => '최대 지출';

  @override
  String get annualReportLargestIncome => '최대 수입';

  @override
  String get annualReportFirstRecord => '첫 기록';

  @override
  String get annualReportPage5Title => '업적';

  @override
  String get annualReportPage5Subtitle => '나의 가계부 배지';

  @override
  String get annualReportAchievementConsistent => '꾸준함';

  @override
  String annualReportAchievementConsistentDesc(int days) {
    return '$days일 이상 연속으로 기록했습니다';
  }

  @override
  String get annualReportAchievementSaver => '저축왕';

  @override
  String get annualReportAchievementSaverDesc => '올해 순 저축이 플러스입니다';

  @override
  String get annualReportAchievementDetail => '꼼꼼함';

  @override
  String annualReportAchievementDetailDesc(int count) {
    return '$count건 이상 기록했습니다';
  }

  @override
  String get annualReportShareButton => '공유 포스터 만들기';

  @override
  String get annualReportGenerating => '연간 리포트 생성 중...';

  @override
  String get annualReportSaveSuccess => '연간 리포트 포스터를 저장했습니다';

  @override
  String get mineShareApp => '앱 공유';

  @override
  String get mineShareWithFriends => '친구에게 BeeCount 공유하기';

  @override
  String get mineCopyPromoText => '홍보 문구 복사';

  @override
  String get mineCopyPromoSubtitle => '복사해서 친구에게 공유하세요';

  @override
  String get mineShareGenerating => '공유 포스터 생성 중...';

  @override
  String get sharePosterAppName => 'BeeCount';

  @override
  String get sharePosterSlogan => '스마트한 가계부, 아름다운 삶';

  @override
  String get sharePosterFeature1 => '데이터 보안·직접 관리';

  @override
  String get sharePosterFeature2 => '오픈소스·검증 가능';

  @override
  String get sharePosterFeature3 => 'AI 스마트·사진 및 음성 인식';

  @override
  String get sharePosterFeature4 => '사진 기록·자동 인식';

  @override
  String get sharePosterFeature5 => '다중 가계부·다크 모드';

  @override
  String get sharePosterFeature6 => '셀프 호스팅 클라우드·영구 무료';

  @override
  String get sharePosterScanText => '스캔하여 오픈소스 프로젝트 방문하기';

  @override
  String get appPromoTagOpenSource => '오픈소스';

  @override
  String get appPromoTagFree => '무료';

  @override
  String get appPromoFooterText => '한 푼까지 기록하고, 모든 순간을 추적하세요';

  @override
  String userProfileJourneyYears(int years) {
    return '가계부 경력 $years년차';
  }

  @override
  String get userProfileJourneyOneYear => '가계부 1년째';

  @override
  String get userProfileJourneyHalfYear => '6개월째 꾸준히';

  @override
  String get userProfileJourneyThreeMonths => '3개월째 진행 중';

  @override
  String get userProfileJourneyOneMonth => '1개월 달성';

  @override
  String get userProfileJourneyOneWeek => '첫 주 완료';

  @override
  String get userProfileJourneyStart => '여정을 시작했습니다';

  @override
  String get userProfileDailyAverage => '일평균';

  @override
  String get sharePosterSave => '갤러리에 저장';

  @override
  String get sharePosterShare => '공유';

  @override
  String get sharePosterHideIncome => '수입 숨기기';

  @override
  String get sharePosterShowIncome => '수입 표시';

  @override
  String get sharePosterSaveSuccess => '갤러리에 저장되었습니다';

  @override
  String get shareGuidanceCopyText => 'BeeCount로 지출을 기록하세요 - 오픈소스, 무료, 광고 없음! 🐝 다운로드: https://github.com/TNT-Likely/BeeCount';

  @override
  String get shareGuidanceCopied => '텍스트가 복사되었습니다';

  @override
  String get sharePosterSaveFailed => '저장 실패';

  @override
  String get sharePosterPermissionDenied => '갤러리 권한이 거부되었습니다. 설정에서 허용해 주세요';

  @override
  String get sharePosterGenerating => '생성 중...';

  @override
  String get sharePosterGenerateFailed => '포스터 생성에 실패했습니다. 다시 시도해 주세요';

  @override
  String get sharePosterNoLedger => '먼저 가계부를 선택해 주세요';

  @override
  String get sharePosterYearTitle => '나의 연간 가계부 리포트';

  @override
  String get sharePosterYearSubtitle => '데이터로 삶을 기록하고, 이성적으로 미래를 계획하세요';

  @override
  String get sharePosterMonthTitle => '월간 명세서 리포트';

  @override
  String get sharePosterMonthSubtitle => '현명한 예산, 합리적인 지출';

  @override
  String get sharePosterLedgerTitle => '가계부 통계 리포트';

  @override
  String get sharePosterRecordDays => '기록 일수';

  @override
  String get sharePosterRecordCount => '기록 건수';

  @override
  String get sharePosterTotalExpense => '총 지출';

  @override
  String get sharePosterTotalIncome => '총 수입';

  @override
  String get sharePosterYearBalance => '연간 잔액';

  @override
  String get sharePosterYearDeficit => '연간 적자';

  @override
  String get sharePosterMonthBalance => '월간 잔액';

  @override
  String get sharePosterBalance => '총 잔액';

  @override
  String get sharePosterAvgMonthlyExpense => '월평균 지출';

  @override
  String get sharePosterAvgMonthlyIncome => '월평균 수입';

  @override
  String get sharePosterAvgDailyExpense => '일평균 지출';

  @override
  String get sharePosterMaxExpenseMonth => '최대 지출 월';

  @override
  String get sharePosterTopExpense => '지출 TOP 3';

  @override
  String get sharePosterCompareLastMonth => '지난달 대비';

  @override
  String get sharePosterIncreaseRate => '증가';

  @override
  String get sharePosterDecreaseRate => '감소';

  @override
  String get sharePosterSavedMoneyTitle => '축하합니다! 이번 달 저축에 성공했어요';

  @override
  String get sharePosterLedgerName => '가계부 이름';

  @override
  String get sharePosterUnitDay => '일';

  @override
  String get sharePosterUnitCount => '';

  @override
  String get sharePosterUnitYuan => '';

  @override
  String userProfilePosterStartDate(String date) {
    return '$date부터 기록 시작';
  }

  @override
  String get userProfilePosterRecordDays => '기록 일수';

  @override
  String get userProfilePosterDaysUnit => '일';

  @override
  String get userProfilePosterRecordCount => '기록 건수';

  @override
  String get userProfilePosterCountUnit => '';

  @override
  String get userProfilePosterLedgerCount => '가계부 수';

  @override
  String get userProfilePosterLedgerUnit => '';

  @override
  String get mineDaysCount => '일수';

  @override
  String get mineTotalRecords => '기록 수';

  @override
  String get mineCurrentBalance => '잔액';

  @override
  String get mineCloudService => '클라우드 서비스';

  @override
  String get mineCloudServiceLoading => '불러오는 중...';

  @override
  String get mineCloudServiceOffline => '기본 모드 (오프라인)';

  @override
  String get mineCloudServiceCustom => '사용자 지정 Supabase';

  @override
  String get mineCloudServiceWebDAV => '사용자 지정 클라우드 서비스 (WebDAV)';

  @override
  String get mineSyncTitle => '동기화';

  @override
  String get mineSyncNotLoggedIn => '로그인하지 않음';

  @override
  String get mineSyncNotConfigured => '클라우드가 설정되지 않음';

  @override
  String get mineSyncNoRemote => '클라우드 데이터 없음';

  @override
  String mineSyncInSync(Object count) {
    return '동기화됨 (로컬 $count건)';
  }

  @override
  String get mineSyncInSyncSimple => '동기화됨';

  @override
  String mineSyncLocalNewer(Object count) {
    return '로컬이 최신 상태입니다 ($count건, 업로드를 권장합니다)';
  }

  @override
  String get mineSyncLocalNewerSimple => '로컬이 최신 상태';

  @override
  String get mineSyncCloudNewer => '클라우드가 최신 상태입니다 (다운로드하여 동기화하세요)';

  @override
  String get mineSyncCloudNewerSimple => '클라우드가 최신 상태';

  @override
  String get mineSyncDifferent => '로컬과 클라우드가 다릅니다. 다운로드하여 비교하세요';

  @override
  String get mineSyncError => '상태를 가져오지 못했습니다';

  @override
  String get mineSyncDetailTitle => '동기화 상태 상세';

  @override
  String mineSyncLocalRecords(Object count) {
    return '로컬 기록: $count건';
  }

  @override
  String mineSyncCloudRecords(Object count) {
    return '클라우드 기록: $count건';
  }

  @override
  String mineSyncCloudLatest(Object time) {
    return '클라우드 최신 기록 시각: $time';
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
  String get mineUploadNeedCloudService => '클라우드 서비스 모드에서만 사용 가능합니다';

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
  String get mineDownloadTitle => '다운로드 및 동기화';

  @override
  String get mineDownloadNeedCloudService => '클라우드 서비스 모드에서만 사용 가능합니다';

  @override
  String get mineDownloadComplete => '동기화 완료';

  @override
  String mineDownloadResult(Object inserted) {
    return '가져옴: $inserted건';
  }

  @override
  String get mineLoginTitle => '로그인';

  @override
  String get mineLoginSubtitle => '동기화할 때만 필요합니다';

  @override
  String get cloudReloginTitle => '다시 로그인';

  @override
  String get cloudReloginSuccess => '다시 로그인했습니다';

  @override
  String get cloudReloginFailed => '다시 로그인 실패';

  @override
  String get mineLoggedInEmail => '로그인됨';

  @override
  String get mineLogoutSubtitle => '눌러서 로그아웃';

  @override
  String get mineLogoutConfirmTitle => '로그아웃';

  @override
  String get mineLogoutConfirmMessage => '로그아웃하시겠습니까?\n로그아웃하면 클라우드 동기화를 사용할 수 없습니다.';

  @override
  String get mineLogoutButton => '로그아웃';

  @override
  String get mineAutoSyncTitle => '가계부 자동 동기화';

  @override
  String get mineAutoSyncSubtitle => '기록 후 클라우드에 자동 업로드';

  @override
  String get mineAutoSyncNeedLogin => '사용하려면 로그인이 필요합니다';

  @override
  String get mineImportProgressTitle => '백그라운드에서 가져오는 중...';

  @override
  String mineImportProgressSubtitle(Object done, Object fail, Object ok, Object total) {
    return '진행: $done/$total, 성공 $ok, 실패 $fail';
  }

  @override
  String get mineImportCompleteTitle => '가져오기 완료';

  @override
  String get mineCategoryManagement => '카테고리 관리';

  @override
  String get mineCategoryManagementSubtitle => '사용자 지정 카테고리 편집';

  @override
  String get mineCategoryMigration => '카테고리 마이그레이션';

  @override
  String get mineCategoryMigrationSubtitle => '카테고리 데이터를 다른 카테고리로 이전';

  @override
  String get mineRecurringTransactions => '정기 결제';

  @override
  String get mineRecurringTransactionsSubtitle => '정기 결제 관리';

  @override
  String get mineReminderSettings => '알림 설정';

  @override
  String get mineReminderSettingsSubtitle => '매일 기록 알림 설정';

  @override
  String get minePersonalize => '개인화';

  @override
  String get mineDisplayScale => '화면 배율';

  @override
  String get mineDisplayScaleSubtitle => '텍스트와 UI 요소 크기를 조정합니다';

  @override
  String get mineCheckUpdate => '업데이트 확인';

  @override
  String get mineCheckUpdateSubtitle => '최신 버전을 확인합니다';

  @override
  String get mineUpdateDownload => '업데이트 다운로드';

  @override
  String get mineFeedback => '피드백';

  @override
  String get mineFeedbackSubtitle => '문제나 제안 사항을 알려주세요';

  @override
  String get mineHelp => '도움말';

  @override
  String get helpCenterOpenInBrowser => '브라우저에서 열기';

  @override
  String get helpCenterLoadFailed => '불러오기에 실패했습니다. 네트워크 상태를 확인해 주세요.';

  @override
  String get helpCenterRetry => '다시 시도';

  @override
  String get mineHelpSubtitle => '문서와 자주 묻는 질문 보기';

  @override
  String get mineSupportAuthor => '프로젝트에 스타 남기기 ⭐️';

  @override
  String mineSupportAuthorSubtitle(String count) {
    return '오픈소스, $count개의 스타';
  }

  @override
  String get githubStarGuideTitle => '프로젝트에 스타를 남기는 방법';

  @override
  String get githubStarGuideContent => '아래 버튼을 눌러 GitHub를 연 후, 이미지에 표시된 영역을 눌러 스타를 완료하세요';

  @override
  String get githubStarGuideButton => 'GitHub로 이동';

  @override
  String get categoryEditTitle => '카테고리 편집';

  @override
  String get categoryNewTitle => '새 카테고리';

  @override
  String get categoryDetailTooltip => '카테고리 상세';

  @override
  String get categoryMigrationTooltip => '카테고리 마이그레이션';

  @override
  String get categoryMigrationTitle => '카테고리 마이그레이션';

  @override
  String get categoryMigrationDescription => '카테고리 마이그레이션 안내';

  @override
  String get categoryMigrationDescriptionContent => '• 한 카테고리의 모든 거래 기록을 다른 카테고리로 이전합니다\n• 마이그레이션 후 원본 카테고리의 모든 거래 데이터가 대상 카테고리로 옮겨집니다\n• 이 작업은 되돌릴 수 없으니 신중하게 선택해 주세요';

  @override
  String get categoryMigrationTypeLabel => '유형 선택';

  @override
  String get categoryMigrationFromLabel => '원본 카테고리';

  @override
  String get categoryMigrationFromHint => '이전할 카테고리를 선택하세요';

  @override
  String get categoryMigrationToLabel => '대상 카테고리';

  @override
  String get categoryMigrationToHint => '대상 카테고리를 선택하세요';

  @override
  String get categoryMigrationToHintFirst => '먼저 원본 카테고리를 선택해 주세요';

  @override
  String get categoryMigrationStartButton => '마이그레이션 시작';

  @override
  String get categoryMigrationCannotTitle => '마이그레이션 불가';

  @override
  String get categoryMigrationCannotMessage => '선택한 카테고리는 마이그레이션할 수 없습니다. 카테고리 상태를 확인해 주세요.';

  @override
  String get categoryExpenseType => '지출 카테고리';

  @override
  String get categoryIncomeType => '수입 카테고리';

  @override
  String get categoryDefaultTitle => '기본 카테고리';

  @override
  String get categoryNameLabel => '카테고리 이름';

  @override
  String get categoryNameHint => '카테고리 이름을 입력하세요';

  @override
  String get categoryNameRequired => '카테고리 이름을 입력해 주세요';

  @override
  String get categoryNameTooLong => '카테고리 이름은 4자를 초과할 수 없습니다';

  @override
  String get categoryNameDuplicate => '이미 존재하는 카테고리 이름입니다';

  @override
  String get categoryIconLabel => '카테고리 아이콘';

  @override
  String get categoryCustomIconTitle => '사용자 지정 아이콘';

  @override
  String get categoryCustomIconTapToSelect => '눌러서 이미지 선택';

  @override
  String get categoryCustomIconTapToChange => '눌러서 이미지 변경';

  @override
  String get categoryCustomIconError => '이미지 선택 중 오류가 발생했습니다';

  @override
  String get categoryCustomIconRequired => '사용자 지정 아이콘 이미지를 선택해 주세요';

  @override
  String get categoryCustomIconCrop => '아이콘 자르기';

  @override
  String get categoryDangerousOperations => '위험한 작업';

  @override
  String get categoryDeleteTitle => '카테고리 삭제';

  @override
  String get categoryDeleteSubtitle => '삭제 후에는 복구할 수 없습니다';

  @override
  String get categorySaveError => '저장 실패';

  @override
  String categoryUpdated(Object name) {
    return '카테고리 \"$name\"이(가) 수정되었습니다';
  }

  @override
  String categoryCreated(Object name) {
    return '카테고리 \"$name\"이(가) 생성되었습니다';
  }

  @override
  String get categoryCannotDelete => '삭제할 수 없습니다';

  @override
  String categoryCannotDeleteMessage(Object count) {
    return '이 카테고리에는 $count건의 거래 기록이 있습니다. 먼저 처리해 주세요.';
  }

  @override
  String get categoryShare => '카테고리 공유';

  @override
  String get categoryImport => '카테고리 가져오기';

  @override
  String get categoryClearUnused => '사용하지 않는 카테고리 정리';

  @override
  String get categoryClearUnusedTitle => '사용하지 않는 카테고리 정리';

  @override
  String categoryClearUnusedMessage(Object count) {
    return '사용하지 않는 카테고리 $count개를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get categoryClearUnusedListTitle => '삭제될 카테고리:';

  @override
  String get categoryClearUnusedEmpty => '사용하지 않는 카테고리가 없습니다';

  @override
  String categoryClearUnusedSuccess(Object count) {
    return '카테고리 $count개를 삭제했습니다';
  }

  @override
  String get categoryClearUnusedFailed => '정리 실패';

  @override
  String get categoryShareScopeTitle => '범위 선택';

  @override
  String get categoryShareScopeExpense => '지출 카테고리만';

  @override
  String get categoryShareScopeIncome => '수입 카테고리만';

  @override
  String get categoryShareScopeAll => '전체 카테고리';

  @override
  String categoryShareSuccess(Object path) {
    return '$path에 저장되었습니다';
  }

  @override
  String get categoryShareSubject => 'BeeCount 카테고리 설정';

  @override
  String get categoryShareFailed => '공유 실패';

  @override
  String get categoryImportInvalidFile => '카테고리 패키지 파일(.zip)을 선택해 주세요';

  @override
  String get categoryImportModeTitle => '가져오기 방식 선택';

  @override
  String get categoryImportModeMerge => '병합';

  @override
  String get categoryImportModeMergeDesc => '기존 카테고리는 유지하고 새 카테고리만 추가합니다';

  @override
  String get categoryImportModeOverwrite => '덮어쓰기';

  @override
  String get categoryImportModeOverwriteDesc => '사용하지 않는 카테고리를 정리한 후 가져옵니다';

  @override
  String get categoryImportSuccess => '가져오기 성공';

  @override
  String categoryImportSuccessDetail(int imported, int skipped, int icons) {
    return '카테고리 $imported개 가져옴, $skipped개 건너뜀, 아이콘 $icons개 가져옴';
  }

  @override
  String get categoryImportFailed => '가져오기 실패';

  @override
  String get categoryDeleteConfirmTitle => '카테고리 삭제';

  @override
  String categoryDeleteConfirmMessage(Object name) {
    return '카테고리 \"$name\"을(를) 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get categoryDeleteError => '삭제 실패';

  @override
  String categoryDeleted(Object name) {
    return '카테고리 \"$name\"이(가) 삭제되었습니다';
  }

  @override
  String get categorySubCategoryTitle => '하위 카테고리';

  @override
  String get categorySubCategoryDescriptionEnabled => '이 카테고리는 상위 카테고리에 속합니다';

  @override
  String get categorySubCategoryDescriptionDisabled => '이 카테고리는 독립적인 최상위 카테고리입니다';

  @override
  String get categoryParentCategoryTitle => '상위 카테고리';

  @override
  String get categoryParentCategoryHint => '상위 카테고리를 선택하세요';

  @override
  String get categorySelectParentTitle => '상위 카테고리 선택';

  @override
  String categorySubCategoryCreated(Object name) {
    return '하위 카테고리가 추가되었습니다: $name';
  }

  @override
  String get categoryParentRequired => '상위 카테고리를 선택해 주세요';

  @override
  String get categoryParentRequiredTitle => '오류';

  @override
  String get categoryExpenseList => '식사-교통-쇼핑-오락-홈리빙-가족-통신비-공과금-주거-의료-교육-반려동물-운동-디지털-여행-술담배-육아-미용-수리-인간관계-학습-자동차-택시-지하철-배달음식-관리비-주차-기부-선물-세금-음료-의류-간식-축의금-과일-게임-도서-데이트-인테리어-생활용품-복권-주식-사회보험-택배-업무';

  @override
  String get categoryIncomeList => '급여-투자-세뱃돈-보너스-환급-아르바이트-선물받음-이자-환불-투자수익-중고거래-사회복지-세금환급-주택공적금';

  @override
  String get categoryExpenseDining => '식사-아침-점심-저녁-배달의민족-쿠팡이츠-요기요-외식-식비';

  @override
  String get categoryExpenseSnacks => '간식-쿠키-과자-사탕-초콜릿-견과류';

  @override
  String get categoryExpenseFruit => '과일-사과-바나나-오렌지-포도-수박-기타 과일';

  @override
  String get categoryExpenseBeverage => '음료-밀크티-커피-주스-탄산음료-생수';

  @override
  String get categoryExpensePastry => '제과제빵-케이크-빵-디저트-베이커리';

  @override
  String get categoryExpenseCooking => '식재료-채소-육류-해산물-조미료-곡물·식용유';

  @override
  String get categoryExpenseShopping => '쇼핑-의류-신발·모자-가방-액세서리-생활용품';

  @override
  String get categoryExpensePets => '반려동물-반려동물 사료-반려동물 용품-반려동물 병원-반려동물 미용';

  @override
  String get categoryExpenseTransport => '교통-지하철-버스-택시-승차공유-주차비-주유비';

  @override
  String get categoryExpenseCar => '자동차-자동차 정비-자동차 수리-자동차 보험-세차-교통 범칙금';

  @override
  String get categoryExpenseClothing => '의류-상의-하의-원피스-신발-패션 소품';

  @override
  String get categoryExpenseDailyGoods => '생활용품-위생용품-화장지-세제-주방용품';

  @override
  String get categoryExpenseEducation => '교육-학비-학원비-도서-문구-사무용품';

  @override
  String get categoryExpenseInvestLoss => '투자 손실-주식 손실-펀드 손실-기타 투자 손실';

  @override
  String get categoryExpenseEntertainment => '오락-영화-노래방-놀이공원-술집-기타 오락';

  @override
  String get categoryExpenseGame => '게임-게임 충전-게임 아이템-게임 멤버십';

  @override
  String get categoryExpenseHealthProducts => '건강기능식품-비타민-건강식품-영양보충제';

  @override
  String get categoryExpenseSubscription => '구독-영상 멤버십-음악 멤버십-클라우드 저장소-기타 구독';

  @override
  String get categoryExpenseSports => '운동-헬스장-운동용품-운동 강습-야외활동';

  @override
  String get categoryExpenseHousing => '주거-월세-관리비-대출 상환-리모델링';

  @override
  String get categoryExpenseHome => '홈리빙-가구-가전제품-인테리어 소품-침구';

  @override
  String get categoryExpenseBeauty => '미용-스킨케어-화장품-미용실-네일아트';

  @override
  String get categoryIncomeSalary => '급여-기본급-성과급-연말 보너스-초과근무수당';

  @override
  String get categoryIncomeInvestment => '투자-펀드 수익-주식 배당-재테크-기타 재테크';

  @override
  String get categoryIncomeRedPacket => '세뱃돈-명절 용돈-생일 용돈-답례품';

  @override
  String get categoryIncomeBonus => '보너스-연간 보너스-분기 보너스-프로젝트 보너스-기타 보너스';

  @override
  String get categoryIncomeReimbursement => '환급-출장비 환급-식비 환급-기타 환급';

  @override
  String get categoryIncomePartTime => '아르바이트-아르바이트 수입-부수입';

  @override
  String get categoryIncomeGift => '선물받음-축의금-생일 선물-기타 선물';

  @override
  String get categoryIncomeInterest => '이자-은행 이자-기타 이자';

  @override
  String get categoryIncomeRefund => '환불-쇼핑 환불-서비스 환불-기타 환불';

  @override
  String get categoryIncomeInvestIncome => '투자수익-주식 수익-펀드 투자-기타 투자수익';

  @override
  String get categoryIncomeSecondHand => '중고거래-중고 물품-중고 판매';

  @override
  String get categoryIncomeSocialBenefit => '사회복지-실업급여-출산지원금-기타 지원금';

  @override
  String get categoryIncomeTaxRefund => '세금환급-종합소득세 환급-기타 세금환급';

  @override
  String get categoryIncomeProvidentFund => '주택공적금-주택공적금 인출-주택공적금 이자';

  @override
  String get personalizeTitle => '테마 색상';

  @override
  String get personalizeSubtitle => '앱의 강조 색상을 선택하거나 직접 지정하세요';

  @override
  String get personalizeCustomColor => '사용자 지정 색상 선택';

  @override
  String get personalizeCustomTitle => '사용자 지정';

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
    return '명도 ($value%)';
  }

  @override
  String get personalizeSelectColor => '이 색상 선택';

  @override
  String get appearanceThemeMode => '화면 모드';

  @override
  String get appearanceThemeModeSystem => '시스템 따르기';

  @override
  String get appearanceThemeModeLight => '라이트 모드';

  @override
  String get appearanceThemeModeDark => '다크 모드';

  @override
  String get appearanceDarkModePattern => '다크 모드 헤더 패턴';

  @override
  String get appearancePatternNone => '없음';

  @override
  String get appearancePatternIcons => '아이콘 타일';

  @override
  String get appearancePatternParticles => '파티클';

  @override
  String get appearancePatternHoneycomb => '벌집무늬';

  @override
  String get appearanceAmountFormat => '잔액 표시 형식';

  @override
  String get appearanceAmountFormatFull => '전체 금액';

  @override
  String get appearanceAmountFormatFullDesc => '전체 금액을 표시합니다. 예: 123,456.78';

  @override
  String get appearanceAmountFormatCompact => '간략 표시';

  @override
  String get appearanceAmountFormatCompactDesc => '큰 금액을 축약합니다. 예: 12.3K (계좌 잔액에만 적용)';

  @override
  String get appearanceShowTransactionTime => '거래 시간 표시';

  @override
  String get appearanceShowTransactionTimeDesc => '거래 목록에 시간을 표시하고, 편집 시 시간 선택을 허용합니다';

  @override
  String get appearanceNoteDisplay => '메모 표시';

  @override
  String get appearanceNoteDisplayCategory => '카테고리 우선';

  @override
  String get appearanceNoteDisplayCategoryDesc => '카테고리를 표시하고 메모는 괄호 안에 표시합니다';

  @override
  String get appearanceNoteDisplayNote => '메모 우선';

  @override
  String get appearanceNoteDisplayNoteDesc => '메모가 있으면 메모를, 없으면 카테고리를 표시합니다';

  @override
  String get appearanceColorScheme => '수입/지출 색상 구성';

  @override
  String get appearanceColorSchemeOn => '빨강 = 수입 · 초록 = 지출';

  @override
  String get appearanceColorSchemeOff => '빨강 = 지출 · 초록 = 수입';

  @override
  String get appearanceColorSchemeOnDesc => '빨강은 수입을, 초록은 지출을 나타냅니다';

  @override
  String get appearanceColorSchemeOffDesc => '빨강은 지출을, 초록은 수입을 나타냅니다';

  @override
  String fontSettingsCurrentScale(Object scale) {
    return '현재 배율: x$scale';
  }

  @override
  String get fontSettingsPreview => '실시간 미리보기';

  @override
  String get fontSettingsPreviewText => '오늘 점심으로 23.50을 지출해서 기록했습니다;\n이번 달 45일 동안 320건 기록했습니다;\n꾸준함이 곧 성공입니다!';

  @override
  String fontSettingsCurrentLevel(Object level, Object scale) {
    return '현재 단계: $level (배율 x$scale)';
  }

  @override
  String get fontSettingsQuickLevel => '빠른 단계 선택';

  @override
  String get fontSettingsCustomAdjust => '사용자 지정 조정';

  @override
  String get fontSettingsDescription => '안내: 이 설정은 모든 기기에서 1.0배 기준으로 일관된 화면을 보장하며, 기기 간 차이는 자동으로 보정됩니다. 이 기준을 바탕으로 값을 조정해 개인화된 배율을 적용하세요.';

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
  String get fontSettingsBig => '아주 크게';

  @override
  String get fontSettingsVeryBig => '매우 크게';

  @override
  String get fontSettingsExtraBig => '최대로 크게';

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
  String get fontSettingsListSubtitle => '보조 설명 텍스트';

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
  String get fontSettingsYes => '예';

  @override
  String get fontSettingsNo => '아니요';

  @override
  String get fontSettingsScaleExample => '이 상자와 여백은 기기에 따라 자동으로 배율이 조정됩니다';

  @override
  String get fontSettingsPreciseAdjust => '정밀 조정';

  @override
  String get fontSettingsResetTo1x => '1.0배로 초기화';

  @override
  String get fontSettingsAdaptBase => '기준값에 맞추기';

  @override
  String get reminderTitle => '기록 알림';

  @override
  String get reminderSubtitle => '매일 기록 알림 시간을 설정하세요';

  @override
  String get reminderDailyTitle => '매일 기록 알림';

  @override
  String get reminderDailySubtitle => '활성화하면 지정한 시간에 기록하라는 알림을 보냅니다';

  @override
  String get reminderTimeTitle => '알림 시간';

  @override
  String get commonSelectTime => '시간 선택';

  @override
  String get reminderTestNotification => '테스트 알림 보내기';

  @override
  String get reminderTestSent => '테스트 알림을 보냈습니다';

  @override
  String get reminderTestTitle => '테스트 알림';

  @override
  String get reminderTestBody => '테스트 알림입니다. 눌러서 효과를 확인해 보세요';

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
  String get reminderBatteryIgnored => '배터리 최적화: 제외됨 ✅';

  @override
  String get reminderBatteryNotIgnored => '배터리 최적화: 제외되지 않음 ⚠️';

  @override
  String get reminderBatteryAdvice => '알림이 정상적으로 오도록 배터리 최적화를 꺼두는 것을 권장합니다';

  @override
  String get reminderCheckChannel => '알림 채널 설정 확인';

  @override
  String get reminderChannelStatus => '알림 채널 상태';

  @override
  String get reminderChannelEnabled => '채널 활성화: 예 ✅';

  @override
  String get reminderChannelDisabled => '채널 활성화: 아니요 ❌';

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
  String get reminderChannelDndBypass => '방해 금지 모드: 무시하고 알림 가능';

  @override
  String get reminderChannelDndNoBypass => '방해 금지 모드: 무시하고 알림 불가';

  @override
  String get reminderChannelAdvice => '⚠️ 권장 설정:';

  @override
  String get reminderChannelAdviceImportance => '• 중요도: 긴급 또는 높음';

  @override
  String get reminderChannelAdviceSound => '• 소리와 진동을 켜세요';

  @override
  String get reminderChannelAdviceBanner => '• 배너 알림을 허용하세요';

  @override
  String get reminderChannelAdviceXiaomi => '• 샤오미(Xiaomi) 기기는 채널을 개별적으로 설정해야 합니다';

  @override
  String get reminderChannelGood => '✅ 알림 채널이 잘 설정되어 있습니다';

  @override
  String get reminderOpenAppSettings => '앱 설정 열기';

  @override
  String get reminderAppSettingsMessage => '설정에서 알림을 허용하고 배터리 최적화를 꺼주세요';

  @override
  String get reminderDescription => '팁: 기록 알림을 활성화하면 시스템이 매일 지정한 시간에 알림을 보내 수입과 지출 기록을 상기시켜 줍니다.';

  @override
  String get reminderIOSInstructions => '🍎 iOS 알림 설정:\n• 설정 > 알림 > 꿀벌 가계부\n• \"알림 허용\" 활성화\n• 알림 스타일 설정: 배너 또는 알림창\n• 소리와 진동 활성화\n\n⚠️ 중요 안내:\n• iOS 로컬 알림은 앱 프로세스에 의존합니다\n• 작업 관리자에서 앱을 강제 종료하지 마세요\n• 앱이 백그라운드나 포그라운드에 있을 때 알림이 작동합니다\n• 강제 종료하면 알림이 작동하지 않습니다\n\n💡 사용 팁:\n• 홈 버튼을 눌러 앱을 종료하기만 하면 됩니다\n• iOS가 백그라운드 앱을 자동으로 관리합니다\n• 알림을 받으려면 앱을 백그라운드에 유지하세요';

  @override
  String get reminderAndroidInstructions => '알림이 제대로 오지 않는다면 다음을 확인하세요:\n• 앱의 알림 전송이 허용되어 있는지\n• 앱의 배터리 최적화/절전 모드를 꺼두었는지\n• 앱의 백그라운드 실행과 자동 시작이 허용되어 있는지\n• Android 12 이상은 정확한 알람 권한이 필요합니다\n\n📱 샤오미(Xiaomi) 기기 특별 설정:\n• 설정 > 앱 관리 > 꿀벌 가계부 > 알림 관리\n• \"기록 알림\" 채널을 누르세요\n• 중요도를 \"긴급\" 또는 \"높음\"으로 설정하세요\n• \"배너 알림\", \"소리\", \"진동\"을 활성화하세요\n• 보안센터 > 앱 관리 > 권한 > 자동 실행\n\n🔒 백그라운드 고정 방법:\n• 최근 작업 목록에서 꿀벌 가계부를 찾으세요\n• 앱 카드를 아래로 당겨 잠금 아이콘을 표시하세요\n• 잠금 아이콘을 눌러 정리되지 않도록 하세요';

  @override
  String get categoryDetailLoadFailed => '불러오기 실패';

  @override
  String get categoryDetailSummaryTitle => '카테고리 요약';

  @override
  String get categoryDetailTotalCount => '총 건수';

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
  String get categoryMigrationConfirmTitle => '마이그레이션 확인';

  @override
  String categoryMigrationConfirmMessage(Object count, Object fromName, Object toName) {
    return '\"$fromName\"의 거래 $count건을 \"$toName\"(으)로 마이그레이션하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다!';
  }

  @override
  String get categoryMigrationConfirmOk => '마이그레이션 확인';

  @override
  String get categoryMigrationCompleteTitle => '마이그레이션 완료';

  @override
  String categoryMigrationCompleteMessage(Object count, Object fromName, Object toName) {
    return '\"$fromName\"의 거래 $count건을 \"$toName\"(으)로 마이그레이션했습니다.';
  }

  @override
  String get categoryMigrationFailedTitle => '마이그레이션 실패';

  @override
  String categoryMigrationFailedMessage(Object error) {
    return '마이그레이션 오류: $error';
  }

  @override
  String categoryMigrationTransactionLabel(int count) {
    return '$count건';
  }

  @override
  String get mineImportCompleteAllSuccess => '모두 성공';

  @override
  String get mineCheckUpdateDetecting => '업데이트 확인 중...';

  @override
  String get mineCheckUpdateSubtitleDetecting => '최신 버전을 확인하고 있습니다';

  @override
  String get mineUpdateDownloadTitle => '업데이트 다운로드';

  @override
  String get cloudTest => '테스트';

  @override
  String get cloudSwitched => '전환됨';

  @override
  String get cloudSwitchFailed => '전환 실패';

  @override
  String get cloudSupabaseUrlLabel => 'Supabase URL';

  @override
  String get cloudSupabaseUrlHint => 'https://xxx.supabase.co';

  @override
  String get cloudAnonKeyLabel => 'Anon Key';

  @override
  String get cloudSelectServiceType => '클라우드 서비스 유형 선택';

  @override
  String get cloudMultiDeviceWarningTitle => '여러 기기 사용 팁';

  @override
  String get cloudMultiDeviceWarningMessage => '기기를 전환하기 전에 업로드하고, 새 기기에서는 편집 전에 다운로드하세요. 같은 가계부를 두 기기에서 동시에 편집하지 마세요. 자세히 보려면 눌러주세요 →';

  @override
  String get cloudWebdavUrlLabel => 'WebDAV 서버 URL';

  @override
  String get cloudWebdavUrlHint => 'https://dav.jianguoyun.com/dav/';

  @override
  String get cloudWebdavUsernameLabel => '사용자 이름';

  @override
  String get cloudWebdavPasswordLabel => '비밀번호';

  @override
  String get cloudWebdavPathHint => '/BeeCount';

  @override
  String get cloudS3EndpointLabel => '엔드포인트';

  @override
  String get cloudS3EndpointHint => 's3.amazonaws.com 또는 사용자 지정 엔드포인트';

  @override
  String get cloudS3RegionLabel => '리전';

  @override
  String get cloudS3RegionHint => 'us-east-1 (자동 설정하려면 비워두세요)';

  @override
  String get cloudS3AccessKeyLabel => '액세스 키';

  @override
  String get cloudS3AccessKeyHint => 'Access Key ID를 입력하세요';

  @override
  String get cloudS3SecretKeyLabel => '시크릿 키';

  @override
  String get cloudS3SecretKeyHint => 'Secret Access Key를 입력하세요';

  @override
  String get cloudS3BucketLabel => '버킷 이름';

  @override
  String get cloudS3BucketHint => 'beecount-data';

  @override
  String get cloudS3UseSSLLabel => 'HTTPS 사용';

  @override
  String get cloudS3PortLabel => '포트 (선택 사항)';

  @override
  String get cloudS3PortHint => '기본값을 사용하려면 비워두세요';

  @override
  String get cloudSupabaseBucketLabel => '저장소 버킷 이름';

  @override
  String get cloudSupabaseBucketHint => '기본값을 사용하려면 비워두세요: beecount-backups';

  @override
  String get authRememberAccount => '계정 기억하기';

  @override
  String get authRememberAccountHint => '다음 로그인 시 자동으로 입력됩니다 (Supabase만 해당)';

  @override
  String get cloudConfigSaved => '설정이 저장되었습니다';

  @override
  String get cloudTestSuccess => '연결 테스트 성공!';

  @override
  String get cloudTestFailed => '연결 테스트에 실패했습니다. 설정이 올바른지 확인해 주세요.';

  @override
  String get cloudTestError => '테스트 실패';

  @override
  String get authLogin => '로그인';

  @override
  String get authEmail => '이메일';

  @override
  String get authPassword => '비밀번호';

  @override
  String get authInvalidEmail => '올바른 이메일 주소를 입력해 주세요';

  @override
  String get authNoAccountYet => '아직 계정이 없으신가요? ';

  @override
  String get authViewRegisterGuide => '가입 방법 보기';

  @override
  String get authErrorInvalidCredentials => '이메일 또는 비밀번호가 올바르지 않습니다.';

  @override
  String get authErrorEmailNotConfirmed => '이메일이 인증되지 않았습니다. 로그인하기 전에 이메일에서 인증을 완료해 주세요.';

  @override
  String get authErrorRateLimit => '시도 횟수가 너무 많습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get authErrorNetworkIssue => '네트워크 오류입니다. 연결 상태를 확인하고 다시 시도해 주세요.';

  @override
  String get authErrorLoginFailed => '로그인에 실패했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get authErrorEmailInvalid => '이메일 주소가 올바르지 않습니다. 철자를 확인해 주세요.';

  @override
  String get authErrorWeakPassword => '비밀번호가 너무 단순합니다. 영문과 숫자를 포함해 6자 이상 입력해 주세요.';

  @override
  String get importSelectCsvFile => '가져올 파일을 선택하세요 (CSV/TSV/XLSX 지원)';

  @override
  String get exportTitle => '내보내기';

  @override
  String get exportDescription => '지원되는 내보내기 유형:\n• 거래 (수입/지출/이체)\n• 카테고리\n• 계정\n\n아래 버튼을 눌러 저장 위치를 선택하면 현재 가계부를 CSV 파일로 내보냅니다.';

  @override
  String get exportButtonIOS => '내보내기 및 공유';

  @override
  String get exportButtonAndroid => '데이터 내보내기';

  @override
  String exportSavedTo(String path) {
    return '저장 위치: $path';
  }

  @override
  String get exportCsvHeaderType => '유형';

  @override
  String get exportCsvHeaderCategory => '카테고리';

  @override
  String get exportCsvHeaderSubCategory => '하위 카테고리';

  @override
  String get exportCsvHeaderAmount => '금액';

  @override
  String get exportCsvHeaderAccount => '계정';

  @override
  String get exportCsvHeaderFromAccount => '출금 계정';

  @override
  String get exportCsvHeaderToAccount => '입금 계정';

  @override
  String get exportCsvHeaderNote => '메모';

  @override
  String get exportCsvHeaderTime => '시간';

  @override
  String get exportCsvHeaderTags => '태그';

  @override
  String get exportCsvHeaderAttachments => '첨부파일';

  @override
  String get exportShareText => 'BeeCount 내보내기 파일';

  @override
  String get exportSuccessTitle => '내보내기 성공';

  @override
  String exportSuccessMessageIOS(String path) {
    return '저장되었으며 공유 기록에서 확인할 수 있습니다:\n$path';
  }

  @override
  String exportSuccessMessageAndroid(String path) {
    return '저장 위치:\n$path';
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
  String get personalizeThemeHoney => '꿀벌 옐로우';

  @override
  String get personalizeThemeOrange => '플레임 오렌지';

  @override
  String get personalizeThemeGreen => '에메랄드 그린';

  @override
  String get personalizeThemePurple => '퍼플 로터스';

  @override
  String get personalizeThemePink => '체리 핑크';

  @override
  String get personalizeThemeBlue => '스카이 블루';

  @override
  String get personalizeThemeMint => '포레스트 문';

  @override
  String get personalizeThemeSand => '선셋 듄';

  @override
  String get personalizeThemeLavender => '스노우 앤 파인';

  @override
  String get personalizeThemeSky => '미스티 원더랜드';

  @override
  String get personalizeThemeWarmOrange => '웜 오렌지';

  @override
  String get personalizeThemeMintGreen => '민트 그린';

  @override
  String get personalizeThemeRoseGold => '로즈 골드';

  @override
  String get personalizeThemeDeepBlue => '딥 블루';

  @override
  String get personalizeThemeMapleRed => '메이플 레드';

  @override
  String get personalizeThemeEmerald => '에메랄드';

  @override
  String get personalizeThemeLavenderPurple => '라벤더';

  @override
  String get personalizeThemeAmber => '앰버';

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
  String get personalizeThemeSunset => '선셋 오렌지';

  @override
  String get personalizeThemePeacock => '피콕 블루';

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
  String updateNewVersionTitle(String version) {
    return '새 버전 $version 발견';
  }

  @override
  String get updateNoApkFound => 'APK 다운로드 링크를 찾을 수 없습니다';

  @override
  String get updateAlreadyLatest => '이미 최신 버전입니다';

  @override
  String get updateCheckFailed => '업데이트 확인 실패';

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
  String get updateDownloadBackgroundHint => '앱을 백그라운드로 전환해도 다운로드가 계속됩니다';

  @override
  String get updateCancelButton => '취소';

  @override
  String get updateBackgroundDownload => '백그라운드 다운로드';

  @override
  String get updateLaterButton => '나중에';

  @override
  String get updateDownloadButton => '다운로드';

  @override
  String get updateInstallingCachedApk => '캐시된 APK 설치 중';

  @override
  String get updateDownloadComplete => '다운로드 완료';

  @override
  String get updateInstallStarted => '다운로드가 완료되어 설치 프로그램이 시작되었습니다';

  @override
  String get updateInstallFailed => '설치 실패';

  @override
  String get updateDownloadFailed => '다운로드 실패';

  @override
  String get updateInstallNow => '지금 설치';

  @override
  String get updateNotificationPermissionTitle => '알림 권한이 거부되었습니다';

  @override
  String get updateCheckFailedTitle => '업데이트 확인 실패';

  @override
  String get updateDownloadFailedTitle => '다운로드 실패';

  @override
  String get updateGoToGitHub => 'GitHub로 이동';

  @override
  String get updateCannotOpenLink => '링크를 열 수 없습니다';

  @override
  String get updateManualVisit => '브라우저에서 직접 방문해 주세요:\\nhttps://github.com/TNT-Likely/BeeCount/releases';

  @override
  String get updateNoLocalApkTitle => '업데이트 패키지를 찾을 수 없습니다';

  @override
  String get updateInstallPackageTitle => '업데이트 패키지 설치';

  @override
  String get updateMultiplePackagesTitle => '여러 개의 업데이트 패키지를 발견했습니다';

  @override
  String get updateSearchFailedTitle => '검색 실패';

  @override
  String get updateFoundCachedPackageTitle => '다운로드된 업데이트 패키지를 발견했습니다';

  @override
  String get updateIgnoreButton => '무시';

  @override
  String get updateInstallFailedTitle => '설치 실패';

  @override
  String get updateInstallFailedMessage => 'APK 설치 프로그램을 시작할 수 없습니다. 파일 권한을 확인해 주세요.';

  @override
  String get updateErrorTitle => '오류';

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
  String get updateInstallerStarted => '설치 프로그램이 시작되었습니다';

  @override
  String get updateInstallationFailed => '설치 실패';

  @override
  String get updateDownloadCompleted => '다운로드 완료';

  @override
  String get updateDownloadCompletedManual => '다운로드가 완료되었습니다. 수동으로 설치할 수 있습니다';

  @override
  String get updateDownloadCompletedDialog => '다운로드가 완료되었습니다. 수동으로 설치해 주세요 (대화상자 예외)';

  @override
  String get updateDownloadCompletedContext => '다운로드가 완료되었습니다. 수동으로 설치해 주세요';

  @override
  String get updateDownloadFailedGeneric => '다운로드 실패';

  @override
  String get updateCheckingUpdate => '업데이트 확인 중...';

  @override
  String get updateCurrentLatestVersion => '이미 최신 버전입니다';

  @override
  String get updateCheckFailedGeneric => '업데이트 확인 실패';

  @override
  String updateDownloadProgress(String percent) {
    return '다운로드 중: $percent%';
  }

  @override
  String updateCheckingUpdateError(String error) {
    return '업데이트 확인 실패: $error';
  }

  @override
  String get updateNoLocalApkFoundMessage => '다운로드된 업데이트 패키지 파일을 찾을 수 없습니다.\\n\\n먼저 \"업데이트 확인\"을 통해 새 버전을 다운로드해 주세요.';

  @override
  String updateInstallPackageFoundMessage(String fileName, String fileSize, String time) {
    return '업데이트 패키지를 발견했습니다:\\n\\n파일명: $fileName\\n크기: ${fileSize}MB\\n다운로드 시각: $time\\n\\n지금 설치하시겠습니까?';
  }

  @override
  String updateMultiplePackagesFoundMessage(int count, String path) {
    return '업데이트 패키지 파일 $count개를 발견했습니다.\\n\\n최근에 다운로드한 버전을 사용하거나 파일 관리자에서 수동으로 설치하는 것을 권장합니다.\\n\\n파일 위치: $path';
  }

  @override
  String updateSearchLocalApkError(String error) {
    return '로컬 업데이트 패키지를 검색하는 중 오류가 발생했습니다: $error';
  }

  @override
  String updateCachedPackageFoundMessage(String fileName, String fileSize) {
    return '이전에 다운로드한 업데이트 패키지를 발견했습니다:\\n\\n파일명: $fileName\\n크기: ${fileSize}MB\\n\\n지금 설치하시겠습니까?';
  }

  @override
  String updateReadCachedPackageError(String error) {
    return '캐시된 업데이트 패키지를 읽는 데 실패했습니다: $error';
  }

  @override
  String get updateOk => '확인';

  @override
  String get updateCannotOpenLinkTitle => '링크를 열 수 없습니다';

  @override
  String get updateCachedVersionTitle => '다운로드된 버전을 발견했습니다';

  @override
  String get updateCachedVersionMessage => '이전에 다운로드한 설치 패키지를 발견했습니다... \\\"확인\\\"을 눌러 지금 설치하거나, \\\"취소\\\"를 눌러 닫으세요...';

  @override
  String get updateConfirmDownload => '지금 다운로드 및 설치';

  @override
  String get updateDownloadCompleteTitle => '다운로드 완료';

  @override
  String get updateInstallConfirmMessage => '새 버전이 다운로드되었습니다. 지금 설치하시겠습니까?';

  @override
  String get updateMirrorSelectTitle => '다운로드 가속 서버 선택';

  @override
  String get updateMirrorSelectHint => '다운로드가 느리다면 가속 미러 서버를 선택하세요. \"테스트\"를 눌러 지연 시간을 확인할 수 있습니다.';

  @override
  String get updateMirrorTestButton => '테스트';

  @override
  String updateMirrorTesting(int completed, int total) {
    return '테스트 중 $completed/$total...';
  }

  @override
  String get updateMirrorDirectHint => '네트워크 환경이 좋은 사용자에게 적합합니다';

  @override
  String updateDownloadMirror(String mirror) {
    return '소스: $mirror';
  }

  @override
  String get updateMirrorSettingTitle => '다운로드 가속 서버';

  @override
  String get updateNotificationPermissionGuideText => '다운로드 진행 알림이 꺼져 있지만 다운로드 기능에는 영향이 없습니다. 진행 상황을 보려면:';

  @override
  String get updateNotificationGuideStep1 => '시스템 설정 > 앱 관리로 이동';

  @override
  String get updateNotificationGuideStep2 => '\\\"BeeCount\\\" 앱을 찾으세요';

  @override
  String get updateNotificationGuideStep3 => '알림 권한을 활성화하세요';

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
  String get currencyTWD => '신 타이완 달러';

  @override
  String get currencyGBP => '영국 파운드';

  @override
  String get currencyAUD => '호주 달러';

  @override
  String get currencyCAD => '캐나다 달러';

  @override
  String get currencyKRW => '대한민국 원';

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
  String get currencyTRY => '터키 리라';

  @override
  String get currencyZAR => '남아프리카공화국 랜드';

  @override
  String get currencyAED => '아랍에미리트 디르함';

  @override
  String get currencySAR => '사우디아라비아 리얄';

  @override
  String get currencyPLN => '폴란드 즈워티';

  @override
  String get currencyCZK => '체코 코루나';

  @override
  String get currencyHUF => '헝가리 포린트';

  @override
  String get currencyARS => '아르헨티나 페소';

  @override
  String get currencyCLP => '칠레 페소';

  @override
  String get currencyCOP => '콜롬비아 페소';

  @override
  String get currencyPEN => '페루 솔';

  @override
  String get currencyEGP => '이집트 파운드';

  @override
  String get currencyNGN => '나이지리아 나이라';

  @override
  String get currencyKZT => '카자흐스탄 텐게';

  @override
  String get currencyUAH => '우크라이나 흐리우냐';

  @override
  String get currencyILS => '이스라엘 신 셰켈';

  @override
  String get currencyPKR => '파키스탄 루피';

  @override
  String get currencyBDT => '방글라데시 타카';

  @override
  String get currencyLKR => '스리랑카 루피';

  @override
  String get currencyMMK => '미얀마 짯';

  @override
  String get webdavConfiguredTitle => 'WebDAV 클라우드 서비스가 설정되었습니다';

  @override
  String get webdavConfiguredMessage => 'WebDAV 클라우드 서비스는 설정 시 입력한 인증 정보를 사용하므로 추가 로그인이 필요하지 않습니다.';

  @override
  String get recurringTransactionTitle => '정기 결제';

  @override
  String get recurringTransactionAdd => '정기 결제 추가';

  @override
  String get recurringTransactionEdit => '정기 결제 편집';

  @override
  String get recurringTransactionFrequency => '주기';

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
  String get recurringTransactionDayOfMonth => '매월 날짜';

  @override
  String get recurringTransactionStartDate => '시작일';

  @override
  String get recurringTransactionEndDate => '종료일';

  @override
  String get recurringTransactionNoEndDate => '무기한';

  @override
  String get recurringTransactionDeleteConfirm => '이 정기 결제를 삭제하시겠습니까?';

  @override
  String get recurringTransactionEmpty => '정기 결제가 없습니다';

  @override
  String get recurringTransactionEmptyHint => '우측 상단의 + 버튼을 눌러 추가하세요';

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
  String get recurringTransactionUsageTitle => '사용 안내';

  @override
  String get recurringTransactionUsageContent => '정기 결제는 앱을 완전히 새로 시작할 때 자동으로 스캔되어 생성됩니다. 날짜를 설정하면 해당 날짜 이후 처음 실행될 때 시스템이 관련 거래를 생성합니다. 예를 들어 11월 27일로 설정하면 11월 27일 이후 첫 실행 시 자동으로 거래가 기록됩니다.';

  @override
  String get ledgerSelectTitle => '가계부 선택';

  @override
  String get ledgerSelect => '가계부 선택';

  @override
  String get syncNotConfiguredMessage => '클라우드가 설정되지 않음';

  @override
  String get syncNotLoggedInMessage => '로그인하지 않음';

  @override
  String get syncCloudBackupCorruptedMessage => '클라우드 백업 내용이 손상되었습니다. 이전 버전의 인코딩 문제일 수 있습니다. \'현재 가계부를 클라우드에 업로드\'를 눌러 덮어써 복구해 주세요.';

  @override
  String get syncNoCloudBackupMessage => '클라우드 백업이 없음';

  @override
  String get syncAccessDeniedMessage => '403 접근 거부 (저장소 RLS 정책과 경로를 확인하세요)';

  @override
  String get cloudTestConnection => '연결 테스트';

  @override
  String get cloudLocalStorageTitle => '로컬 저장';

  @override
  String get cloudLocalStorageSubtitle => '데이터가 로컬 기기에만 저장됩니다';

  @override
  String get cloudCustomSupabaseTitle => '사용자 지정 Supabase';

  @override
  String get cloudCustomSupabaseSubtitle => '눌러서 셀프 호스팅 Supabase를 설정하세요';

  @override
  String get cloudCustomWebdavTitle => '사용자 지정 WebDAV';

  @override
  String get cloudCustomWebdavSubtitle => '눌러서 Nutstore/Nextcloud 등을 설정하세요';

  @override
  String get cloudCustomS3Title => 'S3 프로토콜 저장소';

  @override
  String get cloudCustomS3Subtitle => 'AWS S3 / Cloudflare R2 / MinIO';

  @override
  String get cloudBeeCountCloudTitle => 'BeeCount 클라우드';

  @override
  String get cloudBeeCountCloudSubtitle => '셀프 호스팅 · 증분 동기화 · 다중 기기';

  @override
  String get cloudConfigureBeeCountCloudTitle => 'BeeCount 클라우드 설정';

  @override
  String get cloudBeeCountCloudUrlLabel => '서버 URL';

  @override
  String get cloudBeeCountCloudUrlHint => 'https://your-server.com';

  @override
  String get cloudBeeCountCloudApiPrefixLabel => 'API 접두사';

  @override
  String get cloudBeeCountCloudApiPrefixHint => '/api/v1';

  @override
  String get cloudBeeCountCloudEmailLabel => '이메일';

  @override
  String get cloudBeeCountCloudEmailHint => 'your@email.com';

  @override
  String get cloudBeeCountCloudPasswordLabel => '비밀번호';

  @override
  String get cloudBeeCountCloudPasswordHint => '비밀번호를 입력하세요';

  @override
  String get cloudBeeCountCloudLoginSuccess => '로그인 성공';

  @override
  String get cloudBeeCountCloudLoginFailed => '로그인 실패';

  @override
  String get cloudBeeCountCloudSyncSubtitle => '증분 동기화 · 다중 기기';

  @override
  String get cloudBeeCountCloudConnected => '연결됨';

  @override
  String get cloudBeeCountCloudNotConnected => '연결되지 않음';

  @override
  String get cloudBeeCountCloudNotConnectedHint => '클라우드 서비스 설정에서 구성하고 로그인하세요';

  @override
  String get cloudBeeCountCloudAutoSync => '증분 동기화';

  @override
  String get cloudBeeCountCloudAutoSyncHint => '변경 사항이 클라우드에 자동으로 동기화됩니다';

  @override
  String get cloudBeeCountCloudMultiDevice => '다중 기기 동기화';

  @override
  String get cloudBeeCountCloudMultiDeviceHint => '여러 기기 간 데이터를 일치시킵니다';

  @override
  String get cloudBeeCountCloudAttachment => '첨부파일 동기화';

  @override
  String get cloudBeeCountCloudAttachmentHint => '영수증 이미지가 클라우드에 자동으로 백업됩니다';

  @override
  String get cloudTabOffline => '오프라인';

  @override
  String get cloudTabBackup => '백업';

  @override
  String get cloudTabCloudSync => '클라우드 동기화';

  @override
  String get cloudIcloudSubtitle => 'Apple ID로 자동 동기화';

  @override
  String get cloudIcloudNotAvailableTitle => 'iCloud를 사용할 수 없습니다';

  @override
  String get cloudIcloudNotAvailableMessage => '설정에서 iCloud에 로그인한 후 다시 시도해 주세요';

  @override
  String get cloudIcloudHelpTitle => 'iCloud 사용 안내';

  @override
  String get cloudIcloudHelpPrerequisites => '사전 조건';

  @override
  String get cloudIcloudHelpPrereq1 => '1. 기기가 Apple ID로 로그인되어 있어야 합니다';

  @override
  String get cloudIcloudHelpPrereq2 => '2. iCloud Drive가 활성화되어 있어야 합니다';

  @override
  String get cloudIcloudHelpPrereq3 => '3. 기기가 인터넷에 연결되어 있어야 합니다';

  @override
  String get cloudIcloudHelpCheckTitle => 'iCloud Drive 확인 방법';

  @override
  String get cloudIcloudHelpCheck1 => '1. 설정 앱을 여세요';

  @override
  String get cloudIcloudHelpCheck2 => '2. 상단의 Apple ID를 누르세요';

  @override
  String get cloudIcloudHelpCheck3 => '3. iCloud를 누르세요';

  @override
  String get cloudIcloudHelpCheck4 => '4. iCloud Drive가 활성화되어 있는지 확인하세요';

  @override
  String get cloudIcloudHelpFaqTitle => '자주 묻는 질문';

  @override
  String get cloudIcloudHelpFaq1 => '사용할 수 없다면 iCloud Drive가 활성화되어 있는지 확인하세요';

  @override
  String get cloudIcloudHelpFaq2 => '처음 사용할 때는 초기화에 몇 초 걸릴 수 있습니다';

  @override
  String get cloudIcloudHelpFaq3 => '데이터는 사용자의 개인 iCloud 공간에 저장됩니다';

  @override
  String get cloudIcloudHelpFaq4 => '동일한 Apple ID를 사용하는 기기끼리 자동으로 동기화됩니다';

  @override
  String get cloudIcloudHelpNote => 'iCloud 동기화는 Apple ID를 사용하므로 별도의 설정이 필요하지 않습니다';

  @override
  String get cloudSupabaseHelpTitle => 'Supabase 설정 가이드';

  @override
  String get cloudSupabaseHelpIntro => 'Supabase란?';

  @override
  String get cloudSupabaseHelpIntro1 => 'Supabase는 오픈소스 BaaS(백엔드 서비스) 플랫폼입니다';

  @override
  String get cloudSupabaseHelpIntro2 => '무료 요금제를 제공하며 개인 용도로 충분합니다';

  @override
  String get cloudSupabaseHelpIntro3 => '데이터를 완전히 직접 관리할 수 있습니다';

  @override
  String get cloudSupabaseHelpSteps => '설정 단계';

  @override
  String get cloudSupabaseHelpStep1 => '1. supabase.com에 방문해 계정을 만드세요';

  @override
  String get cloudSupabaseHelpStep2 => '2. 새 프로젝트를 생성하세요 (무료 요금제 선택)';

  @override
  String get cloudSupabaseHelpStep3 => '3. Project Settings > API로 이동하세요';

  @override
  String get cloudSupabaseHelpStep4 => '4. Project URL과 anon key를 복사하세요';

  @override
  String get cloudSupabaseHelpStep5 => '5. 앱 설정에 붙여넣으세요';

  @override
  String get cloudSupabaseHelpFaq => '자주 묻는 질문';

  @override
  String get cloudSupabaseHelpFaq1 => '무료 요금제는 500MB 저장 공간을 포함합니다';

  @override
  String get cloudSupabaseHelpFaq2 => '데이터는 암호화되어 안전하게 보관됩니다';

  @override
  String get cloudSupabaseHelpFaq3 => '다중 기기 동기화를 지원합니다';

  @override
  String get cloudSupabaseHelpNote => '설정 후 동기화를 사용하려면 가입/로그인이 필요합니다';

  @override
  String get cloudDetailedTutorial => '상세 튜토리얼';

  @override
  String get cloudWebdavHelpTitle => 'WebDAV 설정 가이드';

  @override
  String get cloudWebdavHelpIntro => 'WebDAV란?';

  @override
  String get cloudWebdavHelpIntro1 => 'WebDAV는 네트워크 파일 프로토콜입니다';

  @override
  String get cloudWebdavHelpIntro2 => '많은 클라우드 저장소와 NAS 기기에서 지원됩니다';

  @override
  String get cloudWebdavHelpIntro3 => '데이터가 사용자 자신의 서버에 저장됩니다';

  @override
  String get cloudWebdavHelpProviders => '지원되는 제공업체';

  @override
  String get cloudWebdavHelpProvider1 => '- Nutstore (중국 사용자에게 권장)';

  @override
  String get cloudWebdavHelpProvider2 => '- Nextcloud / ownCloud';

  @override
  String get cloudWebdavHelpProvider3 => '- Synology / QNAP NAS';

  @override
  String get cloudWebdavHelpProvider4 => '- 기타 WebDAV 호환 서비스';

  @override
  String get cloudWebdavHelpSteps => '설정 단계 (Nutstore 예시)';

  @override
  String get cloudWebdavHelpStep1 => '1. Nutstore 웹 버전에 로그인하세요';

  @override
  String get cloudWebdavHelpStep2 => '2. 계정 이름 > 계정 정보를 클릭하세요';

  @override
  String get cloudWebdavHelpStep3 => '3. 보안 옵션 탭을 선택하세요';

  @override
  String get cloudWebdavHelpStep4 => '4. 애플리케이션 비밀번호를 추가하세요 (제3자 앱용)';

  @override
  String get cloudWebdavHelpStep5 => '5. 서버 주소, 계정, 앱 비밀번호를 복사하세요';

  @override
  String get cloudWebdavHelpNote => '계정 비밀번호 대신 앱 전용 비밀번호를 사용하세요';

  @override
  String get cloudS3HelpTitle => 'S3 저장소 설정 가이드';

  @override
  String get cloudS3HelpIntro => 'S3란?';

  @override
  String get cloudS3HelpIntro1 => 'S3는 표준 객체 저장소 프로토콜입니다';

  @override
  String get cloudS3HelpIntro2 => '많은 클라우드 제공업체에서 지원됩니다';

  @override
  String get cloudS3HelpIntro3 => '데이터가 선택한 클라우드 서비스에 저장됩니다';

  @override
  String get cloudS3HelpProviders => '지원되는 제공업체';

  @override
  String get cloudS3HelpProvider1 => '- AWS S3 (Amazon Web Services)';

  @override
  String get cloudS3HelpProvider2 => '- Cloudflare R2 (월 10GB 무료)';

  @override
  String get cloudS3HelpProvider3 => '- Backblaze B2 (10GB 무료)';

  @override
  String get cloudS3HelpProvider4 => '- MinIO (셀프 호스팅)';

  @override
  String get cloudS3HelpProvider5 => '- 알리바바 클라우드 OSS';

  @override
  String get cloudS3HelpProvider6 => '- 텐센트 클라우드 COS';

  @override
  String get cloudS3HelpProvider7 => '- 치니우 코도 (Qiniu Kodo)';

  @override
  String get cloudS3HelpSteps => '설정 단계 (Cloudflare R2 예시)';

  @override
  String get cloudS3HelpStep1 => '1. Cloudflare 대시보드에 로그인하세요';

  @override
  String get cloudS3HelpStep2 => '2. R2 > Create Bucket로 이동하세요';

  @override
  String get cloudS3HelpStep3 => '3. R2 > Manage R2 API Tokens로 이동하세요';

  @override
  String get cloudS3HelpStep4 => '4. API 토큰을 생성하고 인증 정보를 복사하세요';

  @override
  String get cloudS3HelpStep5 => '5. 엔드포인트, 액세스 키, 시크릿 키, 버킷 이름을 붙여넣으세요';

  @override
  String get cloudS3HelpNote => '권장: Cloudflare R2는 10GB의 무료 저장 공간을 제공하며 트래픽 비용이 없습니다';

  @override
  String get cloudStatusNotTested => '테스트하지 않음';

  @override
  String get cloudStatusNormal => '연결 정상';

  @override
  String get cloudStatusFailed => '연결 실패';

  @override
  String get cloudCannotOpenLink => '링크를 열 수 없습니다';

  @override
  String get cloudErrorAuthFailed => '인증 실패: API 키가 올바르지 않습니다';

  @override
  String cloudErrorServerStatus(String code) {
    return '서버가 상태 코드 $code를 반환했습니다';
  }

  @override
  String get cloudErrorWebdavNotSupported => '서버가 WebDAV 프로토콜을 지원하지 않습니다';

  @override
  String get cloudErrorAuthFailedCredentials => '인증 실패: 사용자 이름 또는 비밀번호가 올바르지 않습니다';

  @override
  String get cloudErrorAccessDenied => '접근 거부: 권한을 확인해 주세요';

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
  String get cloudTestSuccessMessage => '연결이 정상이며 설정이 유효합니다';

  @override
  String get cloudTestFailedTitle => '테스트 실패';

  @override
  String get cloudTestFailedMessage => '연결에 실패했습니다';

  @override
  String get cloudTestErrorTitle => '테스트 오류';

  @override
  String get cloudSwitchConfirmTitle => '클라우드 서비스 전환';

  @override
  String get cloudSwitchConfirmMessage => '클라우드 서비스를 전환하면 현재 계정이 로그아웃됩니다. 전환하시겠습니까?';

  @override
  String get cloudSwitchFailedTitle => '전환 실패';

  @override
  String get cloudSwitchFailedConfigMissing => '먼저 이 클라우드 서비스를 설정해 주세요';

  @override
  String get cloudConfigInvalidTitle => '설정이 올바르지 않습니다';

  @override
  String get cloudConfigInvalidMessage => '모든 정보를 입력해 주세요';

  @override
  String get cloudSaveFailed => '저장 실패';

  @override
  String cloudSwitchedTo(String type) {
    return '$type(으)로 전환되었습니다';
  }

  @override
  String get cloudConfigureSupabaseTitle => 'Supabase 설정';

  @override
  String get cloudConfigureWebdavTitle => 'WebDAV 설정';

  @override
  String get cloudConfigureS3Title => 'S3 설정';

  @override
  String get cloudSupabaseAnonKeyHintLong => '전체 anon key를 붙여넣으세요';

  @override
  String get cloudWebdavRemotePathHelp => '데이터를 저장할 원격 디렉터리 경로';

  @override
  String get cloudWebdavRemotePathLabel => '원격 경로';

  @override
  String get cloudWebdavRemotePathHelperText => '데이터를 저장할 원격 디렉터리 경로';

  @override
  String get accountsTitle => '자산 관리';

  @override
  String get accountsEmptyMessage => '아직 계정이 없습니다. 우측 상단을 눌러 추가하세요';

  @override
  String get accountAddTooltip => '계정 추가';

  @override
  String get accountAddButton => '계정 추가';

  @override
  String get accountBalance => '잔액';

  @override
  String get accountEditTitle => '계정 편집';

  @override
  String get accountNewTitle => '새 계정';

  @override
  String get accountNameLabel => '계정 이름';

  @override
  String get accountNameHint => '예: 국민은행, 카카오페이 등';

  @override
  String get accountNameRequired => '계정 이름을 입력해 주세요';

  @override
  String get accountNameDuplicate => '이미 존재하는 계정 이름입니다. 다른 이름을 사용해 주세요';

  @override
  String get accountTypeLabel => '계정 유형';

  @override
  String get accountTypeCash => '현금';

  @override
  String get accountTypeBankCard => '은행 카드';

  @override
  String get accountTypeCreditCard => '신용카드';

  @override
  String get accountTypeAlipay => '알리페이';

  @override
  String get accountTypeWechat => '위챗페이';

  @override
  String get accountTypeOther => '기타';

  @override
  String get accountInitialBalance => '초기 잔액';

  @override
  String get accountInitialBalanceHint => '초기 잔액을 입력하세요 (선택 사항)';

  @override
  String get accountDeleteWarningTitle => '삭제 확인';

  @override
  String accountDeleteWarningMessage(int count) {
    return '이 계정에는 관련 거래 $count건이 있습니다. 삭제하면 거래 기록의 계정 정보가 지워집니다. 삭제하시겠습니까?';
  }

  @override
  String get accountDeleteConfirm => '이 계정을 삭제하시겠습니까?';

  @override
  String get accountSelectTitle => '계정 선택';

  @override
  String get accountNone => '계정 없음';

  @override
  String get accountsEnableFeature => '계정 기능 활성화';

  @override
  String get privacyOpenSourceUrlError => '링크를 열 수 없습니다';

  @override
  String get updateCorruptedFileTitle => '손상된 설치 패키지';

  @override
  String get updateCorruptedFileMessage => '이전에 다운로드한 설치 패키지가 불완전하거나 손상되었습니다. 삭제하고 다시 다운로드하시겠습니까?';

  @override
  String get welcomeTitle => 'BeeCount에 오신 것을 환영합니다';

  @override
  String get welcomeDescription => '사용자의 개인정보를 진심으로 존중하는 가계부 앱';

  @override
  String get welcomeCurrencyDescription => '선호하는 통화를 선택하세요. 설정에서 언제든지 변경할 수 있습니다';

  @override
  String get welcomeCreateDefaultLedger => '기본 가계부 만들기';

  @override
  String get welcomePrivacyTitle => '오픈소스 · 커뮤니티 주도';

  @override
  String get welcomePrivacyFeature1 => '100% 오픈소스 코드로 커뮤니티가 감독합니다';

  @override
  String get welcomePrivacyFeature2 => '개인정보 걱정 없이 데이터가 로컬에 저장됩니다';

  @override
  String get welcomeOpenSourceFeature1 => '활발한 개발자 커뮤니티가 지속적으로 개선합니다';

  @override
  String get welcomeViewGitHub => 'GitHub 저장소 방문';

  @override
  String get welcomeCloudSyncTitle => '선택적 클라우드 동기화';

  @override
  String get welcomeCloudSyncDescription => 'BeeCount는 다양한 동기화 방식을 지원합니다 - 내 데이터는 내가 관리합니다';

  @override
  String get welcomeCloudSyncFeature1 => '클라우드 없이 완전히 오프라인으로 사용 가능';

  @override
  String get welcomeCloudSyncFeature2 => 'BeeCount 클라우드 셀프 호스팅 (실시간 다중 기기 + 웹 UI)';

  @override
  String get welcomeCloudSyncFeature3 => '또는 iCloud / WebDAV / Supabase / S3 중 선택';

  @override
  String get widgetManagement => '홈 화면 위젯';

  @override
  String get widgetManagementDesc => '홈 화면에서 수입과 지출을 빠르게 확인하세요';

  @override
  String get widgetPreview => '위젯 미리보기';

  @override
  String get widgetPreviewDesc => '위젯은 현재 가계부의 실제 데이터를 자동으로 표시하며, 테마 색상은 앱 설정을 따릅니다';

  @override
  String get howToAddWidget => '위젯 추가 방법';

  @override
  String get iosWidgetStep1 => '홈 화면의 빈 곳을 길게 눌러 편집 모드로 진입하세요';

  @override
  String get iosWidgetStep2 => '왼쪽 상단의 \"+\" 버튼을 누르세요';

  @override
  String get iosWidgetStep3 => '\"BeeCount\"를 검색해서 선택하세요';

  @override
  String get iosWidgetStep4 => '중간 크기 위젯을 선택해 홈 화면에 추가하세요';

  @override
  String get androidWidgetStep1 => '홈 화면의 빈 곳을 길게 누르세요';

  @override
  String get androidWidgetStep2 => '\"위젯\"을 선택하세요';

  @override
  String get androidWidgetStep3 => '\"BeeCount\" 위젯을 찾아 길게 누르세요';

  @override
  String get androidWidgetStep4 => '홈 화면의 원하는 위치로 드래그하세요';

  @override
  String get aboutWidget => '위젯 정보';

  @override
  String get widgetDescription => '위젯은 오늘과 이번 달의 수입/지출 데이터를 자동으로 동기화해 표시하며, 30분마다 새로고침됩니다. 앱을 열면 즉시 업데이트됩니다.';

  @override
  String get widgetQuickEntryTitle => '빠른 입력';

  @override
  String get widgetQuickEntryDesc => '위젯의 왼쪽을 누르면 지출을 빠르게 추가하고, 오른쪽을 누르면 수입을 추가합니다. 단축어에서 beecount://new?type=transfer 를 사용해 이체를 빠르게 시작할 수도 있습니다.';

  @override
  String get appName => 'BeeCount';

  @override
  String get monthSuffix => '';

  @override
  String get todayExpense => '오늘 지출';

  @override
  String get todayIncome => '오늘 수입';

  @override
  String get monthExpense => '이번 달 지출';

  @override
  String get monthIncome => '이번 달 수입';

  @override
  String get autoScreenshotBilling => '스크린샷 자동 기록';

  @override
  String get autoScreenshotBillingDesc => '스크린샷에서 결제 정보를 자동으로 인식합니다';

  @override
  String get autoScreenshotBillingTitle => '스크린샷 자동 기록';

  @override
  String get featureDescription => '기능 설명';

  @override
  String get featureDescriptionContent => '결제 페이지를 스크린샷으로 찍으면 시스템이 자동으로 금액과 가맹점 정보를 인식해 지출 기록을 생성합니다.\n\n⚡ 인식 속도: 2~3초 (일부 기기에서는 더 걸릴 수 있음)\n🤖 스마트 카테고리 매칭\n📝 메모 자동 입력\n\n⚠️ 참고:\n• 기기마다 스크린샷 저장 속도가 달라 5~10초 정도 지연될 수 있습니다\n• 시스템 구현 방식에 따라 일부 기기에서는 작동하지 않을 수 있습니다\n• 이미 인식한 스크린샷은 자동으로 건너뜁니다\n• Android의 범위 지정 저장소 제한(Android 10 이상)으로 인해 앱이 시스템 스크린샷을 삭제할 수 없습니다. 수동으로 정리해야 합니다';

  @override
  String get autoBilling => '자동 기록';

  @override
  String get enabled => '사용 중';

  @override
  String get disabled => '사용 안 함';

  @override
  String get photosPermissionRequired => '스크린샷 모니터링을 위해 사진 접근 권한이 필요합니다';

  @override
  String get enableSuccess => '자동 기록이 활성화되었습니다';

  @override
  String get disableSuccess => '자동 기록이 비활성화되었습니다';

  @override
  String get autoBillingBatteryTitle => '백그라운드 실행 유지';

  @override
  String get autoBillingBatteryGuideTitle => '배터리 최적화 설정';

  @override
  String get autoBillingBatteryDesc => '자동 기록을 사용하려면 앱이 백그라운드에서 계속 실행되어야 합니다. 일부 기기는 화면이 꺼지면 백그라운드 앱을 자동으로 정리해 자동 기록이 실패할 수 있습니다. 정상 작동을 위해 배터리 최적화를 꺼두는 것을 권장합니다.';

  @override
  String get autoBillingCheckBattery => '배터리 최적화 확인';

  @override
  String get autoBillingBatteryWarning => '⚠️ 배터리 최적화가 꺼져 있지 않습니다. 시스템이 앱을 자동으로 정리해 자동 기록이 실패할 수 있습니다. 위의 \"설정\" 버튼을 눌러 배터리 최적화를 꺼주세요.';

  @override
  String get enableFailed => '활성화 실패';

  @override
  String get disableFailed => '비활성화 실패';

  @override
  String get iosAutoFeatureDesc => 'iOS \"단축어\" 앱을 사용해 스크린샷에서 결제 정보를 자동으로 인식하고 거래를 생성합니다. 설정을 완료하면 스크린샷을 찍을 때마다 자동으로 실행됩니다.';

  @override
  String get iosAutoShortcutConfigTitle => '설정 단계:';

  @override
  String get iosAutoShortcutStep1 => '\"단축어\" 앱을 열고 오른쪽 상단의 \"+\"를 눌러 새 단축어를 만드세요';

  @override
  String get iosAutoShortcutStep2 => '\"스크린샷 찍기\" 동작을 추가하세요';

  @override
  String get iosAutoShortcutStep3 => '\"BeeCount - 자동 기록\" 동작을 검색해 추가하세요';

  @override
  String get iosAutoShortcutStep4 => '\"BeeCount\"의 스크린샷 매개변수를 이전 단계의 \"스크린샷\"으로 설정하세요';

  @override
  String get iosAutoShortcutStep5 => '(선택 사항) 설정 > 손쉬운 사용 > 터치 > 뒷면 탭으로 이동해 이 단축어를 연결하세요';

  @override
  String get iosAutoShortcutStep6 => '완료! 결제할 때 휴대폰 뒷면을 두 번 두드리면 빠르게 기록할 수 있습니다';

  @override
  String get iosAutoShortcutRecommendedTip => '✅ 권장: 단축어를 \"뒷면 탭\"에 연결하면 결제 시 휴대폰 뒷면을 두 번 두드리는 것만으로 자동으로 스크린샷을 찍고 결제 내역을 인식합니다. 수동 스크린샷이 필요 없습니다.';

  @override
  String get iosAutoBackTapTitle => '💡 뒷면 두 번 탭으로 실행 (권장)';

  @override
  String get iosAutoBackTapDesc => '설정 > 손쉬운 사용 > 터치 > 뒷면 탭\n• \"두 번 탭\" 또는 \"세 번 탭\"을 선택하세요\n• 방금 만든 단축어를 선택하세요\n• 설정 후에는 결제 시 휴대폰 뒷면을 두 번 두드리면 스크린샷 없이 자동으로 기록됩니다';

  @override
  String get iosAutoTutorialTitle => '동영상 튜토리얼';

  @override
  String get iosAutoTutorialDesc => '상세한 설정 방법 동영상을 시청하세요';

  @override
  String get iosAutoImportTitle => '한 번에 단축어 받기';

  @override
  String get iosAutoImportDesc => '아래 버튼을 눌러 미리 만들어진 \"스크린샷 → 자동 기록\" 단축어를 가져오세요 — \"스크린샷 찍기\" 동작을 추가하거나 매개변수를 수동으로 연결할 필요가 없습니다. 가져온 후에는 \"뒷면 탭\"에 연결하는 것을 권장합니다.';

  @override
  String get iosAutoImportButton => '단축어 받기';

  @override
  String get iosAutoImportFailed => '단축어 링크를 열 수 없습니다. 연결 상태를 확인하고 다시 시도해 주세요.';

  @override
  String get iosAutoManualConfigTitle => '수동 설정 (고급)';

  @override
  String get iosAutoManualConfigDesc => '한 번에 가져오기를 사용할 수 없다면 아래 단계를 따라 직접 단축어를 만드세요.';

  @override
  String get aiSettingsTitle => 'AI 어시스턴트';

  @override
  String get aiSettingsSubtitle => 'AI 모델과 인식 전략을 설정합니다';

  @override
  String get aiEnableTitle => 'AI 어시스턴트 활성화';

  @override
  String get aiEnableSubtitle => 'AI 비전으로 영수증 스크린샷을 인식해 금액, 가맹점, 시간을 추출하고 자연어 대화를 지원합니다';

  @override
  String get aiEnableToastOn => 'AI 어시스턴트가 활성화되었습니다';

  @override
  String get aiEnableToastOff => 'AI 어시스턴트가 비활성화되었습니다';

  @override
  String get aiStrategyTitle => '실행 전략';

  @override
  String get aiStrategyLocalFirst => '로컬 우선 (권장)';

  @override
  String get aiStrategyCloudFirst => '클라우드 우선';

  @override
  String get aiStrategyCloudFirstDesc => '클라우드 API를 먼저 사용하고 실패 시 로컬로 전환합니다';

  @override
  String get aiStrategyLocalOnly => '로컬만 사용';

  @override
  String get aiStrategyCloudOnly => '클라우드만 사용';

  @override
  String get aiStrategyCloudOnlyDesc => '클라우드 API만 사용하며 모델을 다운로드하지 않습니다';

  @override
  String get aiStrategyUnavailable => '로컬 모델을 학습 중입니다. 곧 제공될 예정입니다';

  @override
  String aiStrategySwitched(String strategy) {
    return '$strategy(으)로 전환되었습니다';
  }

  @override
  String get aiCloudApiKeyHint => '즈푸 AI API 키를 입력하세요';

  @override
  String get aiCloudApiKeyHintCustom => 'API 키를 입력하세요';

  @override
  String get aiCloudApiKeyHelper => 'GLM-*-Flash 모델은 완전 무료입니다';

  @override
  String get aiCloudApiGetKey => 'API 키 발급받기';

  @override
  String get aiCloudApiTutorial => '튜토리얼';

  @override
  String get aiCloudApiTestKey => '연결 테스트';

  @override
  String get aiChatConfigWarning => 'AI 제공업체가 설정되지 않았습니다. 설정에서 추가하고 연결해 주세요';

  @override
  String get aiChatGoToSettings => '설정으로 이동';

  @override
  String get aiOcrRecognizing => '영수증 인식 중...';

  @override
  String get aiOcrNoAmount => '유효한 금액을 인식하지 못했습니다. 직접 추가해 주세요';

  @override
  String get aiNotConfiguredHint => 'AI 서비스가 설정되지 않았습니다. \"내 정보 → AI 설정\"에서 설정해 주세요.';

  @override
  String get aiOcrCheckLog => '인식에 실패했습니다. 자세한 내용은 로그를 확인해 주세요.';

  @override
  String get aiOcrNoBill => '영수증을 인식하지 못했습니다. 이미지가 영수증인지 확인한 후 다시 시도해 주세요.';

  @override
  String get aiNotConfiguredNotificationTitle => '❌ 스크린샷을 인식할 수 없습니다';

  @override
  String get aiNotConfiguredNotificationBody => 'AI 서비스가 설정되지 않았습니다. 눌러서 설정하세요.';

  @override
  String get autoBillingNotifyDetectedTitle => '✅ 스크린샷이 감지되었습니다';

  @override
  String get autoBillingNotifyWaitingFileBody => '파일 저장을 기다리는 중...';

  @override
  String get autoBillingNotifyRecognizingScreenshotTitle => '스크린샷 인식 중...';

  @override
  String get autoBillingNotifyVisionAnalyzingBody => 'AI 비전으로 결제 정보를 분석하고 있습니다. 잠시만 기다려 주세요';

  @override
  String get autoBillingNotifyRecognizingTextTitle => '⏳ 인식 중';

  @override
  String get autoBillingNotifyTextAnalyzingBody => 'AI가 결제 정보를 분석하고 있습니다...';

  @override
  String get autoBillingNotifyRecognizeFailedTitle => '❌ 인식 실패';

  @override
  String get autoBillingNotifyRecognizeFailedBody => '스크린샷에서 결제 정보를 추출하지 못했습니다. AI 설정이나 이미지를 확인해 주세요.';

  @override
  String get autoBillingNotifyNoBillTitle => '영수증을 찾을 수 없습니다';

  @override
  String get autoBillingNotifyNoBillBody => '이 스크린샷에서 결제 정보를 찾지 못했습니다 — 영수증이 아닐 수 있습니다.';

  @override
  String get autoBillingNotifyFileUnavailableTitle => '인식 실패';

  @override
  String get autoBillingNotifyFileUnavailableBody => '스크린샷 파일을 사용할 수 없습니다';

  @override
  String get autoBillingNotifyNoLedgerTitle => '❌ 자동 기록 실패';

  @override
  String get autoBillingNotifyNoLedgerBody => '사용 가능한 가계부가 없습니다. 먼저 가계부를 만들어 주세요.';

  @override
  String get autoBillingNotifyNoAmountBody => '금액을 인식하지 못했습니다';

  @override
  String get autoBillingNotifyCreateFailedTitle => '❌ 생성 실패';

  @override
  String get autoBillingNotifyCreateFailedBody => '거래 기록을 생성하지 못했습니다';

  @override
  String get autoBillingNotifyProcessFailedTitle => '❌ 처리 실패';

  @override
  String autoBillingNotifyProcessFailedBody(String error) {
    return '오류: $error';
  }

  @override
  String autoBillingNotifySuccessSingleTitle(String amount) {
    return '✅ 자동 기록 성공 ¥$amount';
  }

  @override
  String autoBillingNotifySuccessMultiTitle(int count) {
    return '✅ 자동 기록 성공 ($count건)';
  }

  @override
  String autoBillingNotifySuccessMultiBody(String amount) {
    return '총 ¥$amount';
  }

  @override
  String autoBillingNotifySuccessSingleBodyNote(String note) {
    return '메모: $note';
  }

  @override
  String get autoBillingNotifySuccessSingleBodyDefault => '자동으로 기록이 생성되었습니다';

  @override
  String get aiOcrNoLedger => '가계부를 찾을 수 없습니다';

  @override
  String aiOcrSuccess(String type, String amount) {
    return '✅ $type 내역 생성 완료 ¥$amount';
  }

  @override
  String aiOcrFailed(String error) {
    return '인식 실패: $error';
  }

  @override
  String get aiOcrCreateFailed => '영수증 생성 실패';

  @override
  String get aiTypeIncome => '수입';

  @override
  String get aiTypeExpense => '지출';

  @override
  String get cloudSyncPageTitle => '클라우드 동기화';

  @override
  String get cloudSyncPageSubtitle => '가계부 데이터를 수동으로 업로드하고 다운로드하세요';

  @override
  String get cloudTutorialTitle => '시작하기';

  @override
  String get cloudTutorialIntro => 'BeeCount 클라우드는 실시간 다중 기기 협업을 지원하는 셀프 호스팅 동기화 서버입니다. 사용 방법은 간단합니다:';

  @override
  String get cloudTutorialStep1Title => '1단계: 서버 배포 또는 참여';

  @override
  String get cloudTutorialStep1Desc => 'Docker 명령어 한 줄로 셀프 호스팅할 수 있습니다 (GitHub README의 Docker 가이드 참고). 또는 지인/팀이 운영하는 기존 BeeCount 클라우드 서버에 참여하세요.';

  @override
  String get cloudTutorialStep2Title => '2단계: 계정 받기';

  @override
  String get cloudTutorialStep2Desc => 'BeeCount 클라우드는 (공개 서버 악용을 막기 위해) 자체 가입 기능을 제공하지 않습니다. 직접 호스팅하는 경우: Docker를 처음 실행하면 로그에 무작위 관리자 이메일과 비밀번호가 출력되니 이를 사용하세요. 다른 사람의 서버에 참여하는 경우: 관리자에게 웹 → 사용자에서 계정을 만들어 달라고 요청하세요.';

  @override
  String get cloudTutorialStep3Title => '3단계: 로그인 및 동기화 활성화';

  @override
  String get cloudTutorialStep3Desc => '앱에서 BeeCount 클라우드를 선택하고 서버 URL과 2단계에서 받은 계정을 입력하세요. 첫 로그인 시 로컬 가계부 전체가 업로드되며, 이후의 모든 변경 사항은 실시간으로 전송됩니다.';

  @override
  String get cloudTutorialStep4Title => '4단계: 다른 기기에서 로그인';

  @override
  String get cloudTutorialStep4Desc => '휴대폰 / 태블릿 / 웹 — 같은 계정으로 즉시 상태를 공유합니다. 변경 사항은 몇 초 안에 전파됩니다.';

  @override
  String get cloudTutorialTipTitle => '팁';

  @override
  String get cloudTutorialTipDesc => '웹 UI는 서버 URL에 있습니다. 브라우저에서 열어 가계부와 멤버를 관리하고 로그를 확인하세요.';

  @override
  String get cloudTutorialFeaturesTitle => '기능';

  @override
  String get cloudTutorialFeature1 => '📱 실시간 다중 기기: 휴대폰 A + 휴대폰 B + 웹을 하나의 계정으로, 1초 이내 동기화';

  @override
  String get cloudTutorialFeature2 => '🌐 웹 UI 내장: Docker 이미지 하나에 서버와 웹이 모두 포함되어 바로 브라우저로 사용 가능';

  @override
  String get cloudTutorialFeature3 => '👥 다중 사용자 분리: 하나의 서버에 여러 사용자, 데이터는 완전히 분리';

  @override
  String get cloudTutorialFeature4 => '🤝 공유 가계부: 가족/팀을 초대해 하나의 가계부를 몇 초 단위로 동기화';

  @override
  String get cloudTutorialGotIt => '확인했습니다';

  @override
  String get cloudSyncHint => '다운로드 시 차이점을 자동으로 비교해 선택적으로 미리 볼 수 있습니다. 실시간이 아니므로 여러 기기에서 동시에 같은 가계부를 편집하지 마세요. 동기화 범위는 가계부 데이터(연결된 계정, 카테고리, 태그 포함)이며 첨부파일은 제외됩니다.';

  @override
  String get cloudSyncNow => '지금 동기화';

  @override
  String get cloudSyncNowHint => '로컬 변경 사항을 업로드하고 원격 업데이트를 가져옵니다';

  @override
  String get cloudSyncInProgress => '동기화 중...';

  @override
  String cloudSyncComplete(int pushed, int pulled) {
    return '동기화 완료: 업로드 $pushed건, 다운로드 $pulled건';
  }

  @override
  String get cloudAutoSyncHint => '데이터가 변경되면 클라우드에 자동으로 동기화합니다';

  @override
  String get dataManagement => '데이터 관리';

  @override
  String get dataManagementDesc => '가져오기, 내보내기, 카테고리, 계정';

  @override
  String get dataManagementPageTitle => '데이터 관리';

  @override
  String get dataManagementPageSubtitle => '거래 데이터와 카테고리를 관리하세요';

  @override
  String get dataManagementAttachmentHint => '데이터를 복원할 때는 먼저 첨부파일 패키지를 가져온 후 가계부 데이터(CSV 또는 클라우드 동기화)를 가져와야 첨부파일이 올바르게 연결됩니다.';

  @override
  String get smartBilling => '스마트 기록';

  @override
  String get smartBillingDesc => 'AI 어시스턴트, 스마트 인식, 자동 기록';

  @override
  String get smartBillingPageTitle => '스마트 기록';

  @override
  String get smartBillingPageSubtitle => 'AI 및 자동화 기록 기능';

  @override
  String get smartBillingGuideHint => '홈 화면 하단 중앙의 + 버튼을 길게 눌러 이 기능들을 빠르게 사용할 수 있습니다';

  @override
  String get smartBillingImageBilling => '이미지로 기록';

  @override
  String get smartBillingImageBillingDesc => '갤러리에서 결제 스크린샷을 선택해 인식합니다';

  @override
  String get smartBillingImageBillingGuide => '홈 화면 하단 중앙의 + 버튼을 길게 누르고 \'갤러리\'를 선택하면 이미지로 기록할 수 있습니다. \"내 정보 → AI 설정\"에서 AI 서비스를 설정해야 하며, 비전 모델이 스크린샷에서 금액, 가맹점, 시간 등을 추출합니다.';

  @override
  String get smartBillingVisionAIRequired => '이미지 인식에는 AI 비전 서비스가 필요합니다. 먼저 \"내 정보 → AI 설정\"에서 설정해 주세요.';

  @override
  String get smartBillingCameraBilling => '카메라로 기록';

  @override
  String get smartBillingCameraBillingDesc => '결제 화면을 촬영해 인식합니다';

  @override
  String get smartBillingCameraBillingGuide => '홈 화면 하단 중앙의 + 버튼을 길게 누르고 \'카메라\'를 선택하면 카메라로 기록할 수 있습니다. \"내 정보 → AI 설정\"에서 AI 서비스를 설정해야 하며, 비전 모델이 사진에서 금액, 가맹점, 시간 등을 추출합니다.';

  @override
  String get smartBillingVoiceBilling => '음성으로 기록';

  @override
  String get smartBillingVoiceBillingDesc => '음성 입력으로 빠르게 기록합니다';

  @override
  String get smartBillingVoiceBillingGuide => '홈 화면 하단 중앙의 + 버튼을 길게 누르고 \'음성\'을 선택하면 음성으로 기록할 수 있습니다. 음성 기록에는 음성을 텍스트로 변환하고 영수증 정보를 추출하는 AI가 필요합니다.';

  @override
  String get smartBillingAIRequired => '음성 기록에는 AI 음성 서비스가 필요합니다. 먼저 \"내 정보 → AI 설정\"에서 설정해 주세요.';

  @override
  String get smartBillingAutoTags => '태그 자동 연결';

  @override
  String get smartBillingAutoTagsDesc => '카테고리에 따라 자주 사용하는 태그를 자동으로 연결합니다';

  @override
  String get smartBillingAutoAttachment => '첨부파일 자동 추가';

  @override
  String get smartBillingAutoAttachmentDesc => '사진으로 기록할 때 원본 이미지를 자동으로 첨부파일로 추가합니다';

  @override
  String get autoScreenshotBillingIosTitle => '자동 기록';

  @override
  String get autoScreenshotBillingIosDesc => '단축어를 통해 결제 내역을 자동으로 인식합니다';

  @override
  String get shareBilling => '공유로 기록';

  @override
  String get shareBillingDesc => '알리페이/위챗의 결제 스크린샷을 공유해 기록합니다';

  @override
  String get shareBillingGuide => '알리페이, 위챗, 사진 앱 등에서 결제 스크린샷을 보면 \"공유\"를 누르고 \"BeeCount\"를 선택하세요. 금액, 가맹점, 시간을 자동으로 인식해 거래를 생성합니다 — 스크린샷을 먼저 저장할 필요가 없습니다.';

  @override
  String get shareBillingActionHint => '공유 후 백그라운드에서 자동으로 인식됩니다 — BeeCount를 열 필요가 없습니다';

  @override
  String get automation => '자동화';

  @override
  String get automationDesc => '정기 결제와 알림';

  @override
  String get automationPageTitle => '자동화';

  @override
  String get automationPageSubtitle => '정기 결제 및 알림 설정';

  @override
  String get appearanceSettings => '개인화';

  @override
  String get appearanceSettingsDesc => '테마, 글꼴, 언어, 앱 잠금 등';

  @override
  String get appearanceSettingsPageTitle => '개인화';

  @override
  String get appearanceSettingsPageSubtitle => '화면, 표시, 보안 등 앱 환경 설정';

  @override
  String get about => '정보';

  @override
  String get aboutDesc => '버전 정보, 도움말 및 피드백';

  @override
  String get mineRateApp => '앱 평가하기';

  @override
  String get mineRateAppSubtitle => '앱스토어에서 평가해 주세요';

  @override
  String get aboutPageTitle => '정보';

  @override
  String get aboutPageSubtitle => '앱 정보 및 도움말';

  @override
  String get aboutPageLoadingVersion => '버전 정보를 불러오는 중...';

  @override
  String get aboutWebsite => '공식 웹사이트';

  @override
  String get aboutGitHubRepo => 'GitHub 저장소';

  @override
  String get aboutXiaohongshu => '샤오홍슈';

  @override
  String get aboutDouyin => '도우인';

  @override
  String get aboutTelegram => 'Telegram';

  @override
  String get aboutSupportDevelopment => '개발 후원하기';

  @override
  String get aboutSupportDevelopmentSubtitle => '커피 한 잔 사주기';

  @override
  String get aboutDeveloperStoryTitle => '개발자로부터';

  @override
  String get aboutDeveloperStory => '저는 2015년 인턴 시절부터 가계부를 쓰기 시작해서 10년 넘게 그 습관을 이어오고 있습니다. 광고, 유료 결제, 개인정보 유출 위험, 그리고 앱 서비스 종료에 대한 걱정 때문에 직접 만들어보기로 했습니다 — 처음에는 저와 가족을 위한 작은 도구로 시작했죠.\n\n2025년 9월, BeeCount의 첫 버전을 출시했습니다. 솔직히 누가 써줄지 전혀 알 수 없었습니다. 하지만 점차 피드백이 들어오기 시작했습니다 — 드디어 깔끔한 가계부 앱을 찾았다는 분도 있었고, 좋은 제안을 해주신 분도 있었고, 조용히 별점 5개를 남겨주신 분도 있었습니다. 그 하나하나의 메시지가 계속할 가치가 있다는 걸 일깨워 주었습니다.\n\nBeeCount는 광고도, 구독료도 없는 완전한 오픈소스입니다. 모든 데이터는 사용자의 기기에만 저장되며 어떤 제3자 서버로도 업로드되지 않습니다. 하지만 앱을 출시하고 유지하는 데는 비용이 듭니다 — 개발자 계정, 서버 등의 비용은 현재 커뮤니티 후원으로 충당하고 있으며, 모든 시스템 업데이트와 버그 수정, 신규 기능은 본업 외 시간에 만들고 있습니다.\n\nBeeCount가 도움이 되셨다면, 평점이나 공유, 후원 한 번이 이 작은 프로젝트가 더 멀리 나아가는 데 큰 힘이 됩니다. 믿어주셔서 감사합니다.';

  @override
  String get aboutRelatedProducts => '더 많은 제품';

  @override
  String get aboutBeeAssets => 'BeeAssets';

  @override
  String get aboutBeeAssetsSubtitle => '전체 자산 포트폴리오를 시각화하세요';

  @override
  String get aboutBeeAssetsIntro => 'BeeCount가 일상적인 현금 흐름에 집중한다면, BeeAssets는 그 자매 제품으로 자산 포트폴리오 시각화에 집중합니다: 계좌별 순자산 추이, 부동산/투자/암호화폐 분류, 수익률, 보유 기간, 자산 배분 분석까지 확인할 수 있습니다.';

  @override
  String get aboutBeeDNS => 'BeeDNS';

  @override
  String get aboutBeeDNSSubtitle => '간단하고 효율적인 DNS 관리 도구';

  @override
  String get aboutBeeDNSIntro => 'Cloudflare와 Aliyun에 도메인이 흩어져 있나요? BeeDNS는 이를 한곳에 모아줍니다: 레코드 일괄 편집, A/AAAA 전환, 리졸루션 이전, 서브도메인 일괄 관리까지 — 더 이상 여러 제공업체 콘솔을 오갈 필요가 없습니다.';

  @override
  String get productPromoAndroidTitle => '베타 접근 요청';

  @override
  String get productPromoAndroidMessage => '이 앱은 현재 Google Play에서 비공개 테스트 중이며 초대를 통해서만 이용할 수 있습니다.\n\n신청 방법: Google 계정 이메일(필수)과 간단한 사용 목적(선택)을 적어 이메일을 보내주세요. 1~3일 내로 답변드리고 베타 화이트리스트에 추가해 드립니다.';

  @override
  String get productPromoOpenStore => '앱스토어에서 열기';

  @override
  String get productPromoTestFlight => 'TestFlight 베타';

  @override
  String get productPromoLearnMore => 'Pro';

  @override
  String get productPromoEmailLabel => '신청 이메일 (눌러서 복사)';

  @override
  String get productPromoCopiedToast => '이메일 주소가 클립보드에 복사되었습니다';

  @override
  String get productPromoMailUnavailable => '메일 앱을 찾을 수 없습니다. 주소가 복사되었으니 아무 메일 앱에나 붙여넣어 보내주세요.';

  @override
  String get productPromoEmailButton => '이메일 보내기';

  @override
  String get productPromoWebsiteButton => '웹사이트 방문';

  @override
  String productPromoEmailSubject(String productName) {
    return '베타 접근 요청 - $productName';
  }

  @override
  String productPromoEmailBody(String productName) {
    return '안녕하세요,\n\nGoogle Play의 $productName 비공개 베타에 참여하고 싶습니다. 제 Google 계정 이메일은 다음과 같습니다:\n\n(Gmail / Google 계정 이메일을 입력해 주세요)\n\n감사합니다!';
  }

  @override
  String get logCenterTitle => '로그 센터';

  @override
  String get logCenterSubtitle => '앱 실행 로그를 확인하세요';

  @override
  String get logCenterSearchHint => '로그 내용이나 태그 검색...';

  @override
  String get logCenterFilterLevel => '로그 수준';

  @override
  String get logCenterFilterPlatform => '플랫폼';

  @override
  String get logCenterTotal => '전체';

  @override
  String get logCenterFiltered => '필터링됨';

  @override
  String get logCenterEmpty => '로그가 없습니다';

  @override
  String get logCenterExport => '내보내기';

  @override
  String get logCenterClear => '지우기';

  @override
  String get logCenterExportFailed => '내보내기 실패';

  @override
  String get logCenterClearConfirmTitle => '로그 지우기';

  @override
  String get logCenterClearConfirmMessage => '모든 로그를 지우시겠습니까? 이 작업은 되돌릴 수 없습니다.';

  @override
  String get logCenterCleared => '로그가 지워졌습니다';

  @override
  String get logCenterCopied => '클립보드에 복사되었습니다';

  @override
  String get configImportExportTitle => '설정 가져오기/내보내기';

  @override
  String get configImportExportSubtitle => '앱 설정을 백업하고 복원하세요';

  @override
  String get configImportExportInfoTitle => '기능 설명';

  @override
  String get configImportExportInfoMessage => '이 기능은 클라우드 서비스 설정, AI 설정 등 앱 설정을 내보내고 가져오는 데 사용됩니다. 설정 파일은 확인과 편집이 쉬운 YAML 형식을 사용합니다.\n\n⚠️ 설정 파일에는 API 키, 비밀번호 등 민감한 정보가 포함되어 있으니 안전하게 보관해 주세요.';

  @override
  String get configExportTitle => '설정 내보내기';

  @override
  String get configExportSubtitle => '현재 설정을 YAML 파일로 내보내기';

  @override
  String get configExportShareSubject => 'BeeCount 설정 파일';

  @override
  String get configExportSuccess => '설정을 내보냈습니다';

  @override
  String get configExportFailed => '설정 내보내기 실패';

  @override
  String get configImportTitle => '설정 가져오기';

  @override
  String get configImportSubtitle => 'YAML 파일에서 설정을 복원하세요';

  @override
  String get configImportNoFilePath => '선택된 파일이 없습니다';

  @override
  String get configImportConfirmTitle => '가져오기 확인';

  @override
  String get configImportSuccess => '설정을 가져왔습니다';

  @override
  String get configImportFailed => '설정 가져오기 실패';

  @override
  String get configImportRestartTitle => '재시작이 필요합니다';

  @override
  String get configImportRestartMessage => '설정을 가져왔습니다. 일부 설정은 앱을 재시작해야 적용됩니다.';

  @override
  String get configImportExportIncludesTitle => '포함된 설정';

  @override
  String configExportSavedTo(String path) {
    return '저장 위치: $path';
  }

  @override
  String get configExportViewContent => '내용 보기';

  @override
  String get configExportCopyContent => '내용 복사';

  @override
  String get configExportContentCopied => '클립보드에 복사되었습니다';

  @override
  String get configExportReadFileFailed => '파일을 읽지 못했습니다';

  @override
  String get configIncludeLedgers => '가계부';

  @override
  String get configIncludeSupabase => 'Supabase 클라우드 서비스 설정';

  @override
  String get configIncludeWebdav => 'WebDAV 클라우드 서비스 설정';

  @override
  String get configIncludeS3 => 'S3 클라우드 서비스 설정';

  @override
  String get configIncludeAI => 'AI 스마트 인식 설정';

  @override
  String get configIncludeAISubtitle => '제공업체, 기능 연결, 모델 설정 등';

  @override
  String get configIncludeAppSettings => '앱 설정 (언어, 화면, 알림, 기본 계정 등)';

  @override
  String get configIncludeRecurringTransactions => '정기 결제';

  @override
  String get configIncludeAccounts => '계정';

  @override
  String get configIncludeCategories => '카테고리';

  @override
  String get configIncludeTags => '태그';

  @override
  String get configIncludeBudgets => '예산';

  @override
  String get configIncludeOtherSettings => '기타 설정';

  @override
  String get configIncludeOtherSettingsSubtitle => '클라우드 서비스, AI 설정, 앱 설정 등 포함';

  @override
  String get configExportSelectTitle => '내보낼 내용 선택';

  @override
  String get configExportPreviewTitle => '내보내기 미리보기';

  @override
  String get configExportConfirmTitle => '내보내기 확인';

  @override
  String get configImportSelectTitle => '가져올 내용 선택';

  @override
  String get configImportPreviewTitle => '가져오기 미리보기';

  @override
  String get ledgersConflictTitle => '동기화 충돌';

  @override
  String get ledgersConflictMessage => '로컬과 클라우드 가계부 데이터가 일치하지 않습니다. 처리 방법을 선택해 주세요:';

  @override
  String ledgersConflictLocalInfo(int count) {
    return '로컬: 거래 $count건';
  }

  @override
  String ledgersConflictRemoteInfo(int count) {
    return '클라우드: 거래 $count건';
  }

  @override
  String ledgersConflictRemoteUpdated(String time) {
    return '클라우드 업데이트: $time';
  }

  @override
  String ledgersConflictLocalFingerprint(String fp) {
    return '로컬 지문: $fp';
  }

  @override
  String ledgersConflictRemoteFingerprint(String fp) {
    return '클라우드 지문: $fp';
  }

  @override
  String get ledgersConflictUpload => '클라우드에 업로드';

  @override
  String get ledgersConflictDownload => '로컬로 다운로드';

  @override
  String get ledgersConflictUploading => '업로드 중...';

  @override
  String get ledgersConflictDownloading => '다운로드 중...';

  @override
  String get ledgersConflictUploadSuccess => '업로드 성공';

  @override
  String ledgersConflictDownloadSuccess(int inserted) {
    return '다운로드 성공, 거래 $inserted건이 병합되었습니다';
  }

  @override
  String get storageManagementTitle => '저장 공간 관리';

  @override
  String get storageManagementSubtitle => '캐시를 정리해 공간을 확보하세요';

  @override
  String get storageAIModels => 'AI 모델';

  @override
  String get storageAPKFiles => '설치 패키지';

  @override
  String get storageNoData => '데이터 없음';

  @override
  String get storageFiles => '개 파일';

  @override
  String get storageHint => '항목을 눌러 해당 캐시 파일을 정리하세요';

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
  String get storageClearSuccess => '정리 완료';

  @override
  String get accountNoTransactions => '거래 없음';

  @override
  String get accountTransactionHistory => '거래 내역';

  @override
  String get accountTotalBalance => '순자산';

  @override
  String get accountCurrencyLocked => '이 계정에는 거래가 있어 통화를 변경할 수 없습니다';

  @override
  String get accountDefaultIncomeTitle => '기본 수입 계정';

  @override
  String get accountDefaultExpenseTitle => '기본 지출 계정';

  @override
  String get accountDefaultNone => '설정 안 됨';

  @override
  String get commonNotice => '알림';

  @override
  String get transferTitle => '이체';

  @override
  String get transferIconSettings => '이체 아이콘 설정';

  @override
  String get transferIconSettingsDesc => '이체 기록에 표시할 아이콘을 사용자 지정합니다';

  @override
  String get transferFromAccount => '출금 계정';

  @override
  String get transferToAccount => '입금 계정';

  @override
  String get transferSelectAccount => '계정 선택';

  @override
  String get transferCreateSuccess => '이체가 생성되었습니다';

  @override
  String get transferUpdateSuccess => '이체가 수정되었습니다';

  @override
  String get transferDifferentCurrencyError => '이체는 같은 통화의 계정 간에만 가능합니다';

  @override
  String get transferToPrefix => '받는 곳';

  @override
  String get transferFromPrefix => '보내는 곳';

  @override
  String get welcomeCategoryModeTitle => '카테고리 모드 선택';

  @override
  String get welcomeCategoryModeDescription => '필요에 맞는 카테고리 구조를 선택하세요';

  @override
  String get welcomeCategoryModeFlatTitle => '단일 카테고리';

  @override
  String get welcomeCategoryModeFlatDescription => '간단하고 빠릅니다';

  @override
  String get welcomeCategoryModeFlatFeature1 => '단일 구조로 사용하기 쉽습니다';

  @override
  String get welcomeCategoryModeFlatFeature2 => '간단한 분류에 적합합니다';

  @override
  String get welcomeCategoryModeFlatFeature3 => '빠르게 선택하고 효율적으로 기록합니다';

  @override
  String get welcomeCategoryModeHierarchicalTitle => '계층형 카테고리';

  @override
  String get welcomeCategoryModeHierarchicalDescription => '세밀한 관리가 가능합니다';

  @override
  String get welcomeCategoryModeHierarchicalFeature1 => '상위-하위 카테고리 구조를 지원합니다';

  @override
  String get welcomeCategoryModeHierarchicalFeature2 => '더 세밀한 거래 분류가 가능합니다';

  @override
  String get welcomeCategoryModeHierarchicalFeature3 => '세밀한 관리가 필요한 분들께 적합합니다';

  @override
  String get welcomeCategoryModeNoneTitle => '카테고리 없음';

  @override
  String get welcomeCategoryModeNoneDescription => '완전히 자유롭게 필요에 따라 추가하세요';

  @override
  String get welcomeCategoryModeNoneFeature1 => '미리 설정된 카테고리가 없습니다';

  @override
  String get welcomeCategoryModeNoneFeature2 => '필요에 따라 직접 카테고리를 만드세요';

  @override
  String get welcomeCategoryModeNoneFeature3 => '자유로운 분류가 필요한 분들께 적합합니다';

  @override
  String get welcomeExistingUserTitle => '기존 사용자이신가요?';

  @override
  String get welcomeExistingUserButton => '설정 가져오기';

  @override
  String get welcomeImportingConfig => '설정을 가져오는 중...';

  @override
  String get welcomeImportSuccess => '설정을 가져왔습니다';

  @override
  String welcomeImportFailed(String error) {
    return '가져오기 실패: $error';
  }

  @override
  String get welcomeImportNoFile => '선택된 파일이 없습니다';

  @override
  String get welcomeImportAttachmentTitle => '첨부파일 가져오기';

  @override
  String get welcomeImportAttachmentDesc => '첨부파일도 함께 가져오시겠습니까?';

  @override
  String get welcomeImportAttachmentButton => '첨부파일 선택';

  @override
  String get welcomeImportAttachmentSkip => '건너뛰기';

  @override
  String welcomeImportAttachmentSuccess(int imported) {
    return '첨부파일 $imported개를 가져왔습니다';
  }

  @override
  String welcomeImportAttachmentFailed(String error) {
    return '첨부파일 가져오기 실패: $error';
  }

  @override
  String get welcomeImportingAttachment => '첨부파일을 가져오는 중...';

  @override
  String get iosVersionWarningTitle => 'iOS 16.0 이상이 필요합니다';

  @override
  String get iosVersionWarningDesc => '스크린샷 자동 기록 기능은 iOS 16에서 도입된 App Intents 프레임워크를 사용합니다. 사용 중인 기기는 이전 버전이라 이 기능을 지원하지 않습니다.\n\n이 기능을 사용하려면 iOS 16 이상으로 업그레이드해 주세요.';

  @override
  String get aiChatTitle => 'AI 어시스턴트';

  @override
  String get aiChatClearHistory => '기록 지우기';

  @override
  String get aiChatClearHistoryDialogTitle => '대화 기록 지우기';

  @override
  String get aiChatClearHistoryDialogContent => '모든 대화 기록을 지우시겠습니까? 이 작업은 되돌릴 수 없습니다.';

  @override
  String get aiChatInputHint => '예: 커피 한 잔에 3,500원 썼어';

  @override
  String get aiChatThinking => '생각 중...';

  @override
  String get aiChatHistoryCleared => '대화 기록이 지워졌습니다';

  @override
  String get aiChatCopy => '복사';

  @override
  String get aiChatCopied => '클립보드에 복사되었습니다';

  @override
  String get aiChatDeleteMessageConfirm => '이 메시지를 삭제하시겠습니까?';

  @override
  String get aiChatMessageDeleted => '메시지가 삭제되었습니다';

  @override
  String get aiChatUndone => '실행 취소됨';

  @override
  String get aiChatUndoFailed => '실행 취소 실패';

  @override
  String get aiChatTransactionNotFound => '거래를 찾을 수 없습니다';

  @override
  String get aiChatOpenEditorFailed => '편집기를 열지 못했습니다';

  @override
  String get aiChatSendFailed => '전송 실패';

  @override
  String get billCardSuccess => '기록 성공';

  @override
  String get billCardUndone => '실행 취소됨';

  @override
  String get billCardAmount => '💰 금액';

  @override
  String get billCardCategory => '🏷️ 카테고리';

  @override
  String get billCardTime => '📅 시간';

  @override
  String get billCardNote => '📝 메모';

  @override
  String get billCardAccount => '💳 계정';

  @override
  String get billCardUndo => '실행 취소';

  @override
  String get billCardEdit => '편집';

  @override
  String get donationTitle => '후원하기';

  @override
  String get donationSubtitle => '커피 한 잔 사주기';

  @override
  String get donationEntrySubtitle => '지속적인 개발을 후원해 주세요';

  @override
  String get donationDescription => '설명';

  @override
  String get donationDescriptionDetail => 'BeeCount를 사용해 주셔서 감사합니다! 이 앱이 도움이 되었다면 개발자에게 커피 한 잔을 사주는 것으로 응원해 주세요. 여러분의 후원이 계속 발전할 수 있는 원동력이 됩니다.';

  @override
  String get donationNoFeatures => '안내: 후원해도 별도 기능이 잠금 해제되지 않습니다. 모든 기능은 완전히 무료로 유지됩니다.';

  @override
  String get donationNoProducts => '이용 가능한 상품이 없습니다';

  @override
  String get donationThankYouTitle => '감사합니다!';

  @override
  String donationThankYouMessage(String productName) {
    return '$productName을(를) 구매해 주셔서 감사합니다! 여러분의 후원은 저에게 큰 힘이 됩니다. BeeCount를 더 좋게 만들기 위해 계속 노력하겠습니다!';
  }

  @override
  String get aiQuickCommandFinancialHealthTitle => '재정 건강 분석';

  @override
  String get aiQuickCommandFinancialHealthDesc => '수입-지출 균형과 저축률을 분석합니다';

  @override
  String get aiQuickCommandFinancialHealthPrompt => '다음 데이터를 바탕으로 제 재정 건강 상태를 분석해 주세요:\n\n[monthlyStats]\n\n[recentTrends]\n\n수입-지출 균형, 저축률, 소비 추세 관점에서 전문적인 분석과 제안을 제공해 주세요. 한국어로 답변해 주세요.';

  @override
  String get aiQuickCommandMonthlyExpenseTitle => '월간 지출 요약';

  @override
  String get aiQuickCommandMonthlyExpenseDesc => '월간 지출 분석과 제안';

  @override
  String get aiQuickCommandMonthlyExpensePrompt => '다음 데이터를 바탕으로 제 월간 지출을 요약해 주세요:\n\n[monthlyStats]\n\n[categoryStats]\n\n어느 카테고리의 비중이 가장 높은지 분석하고 개선 제안을 제공해 주세요. 한국어로 답변해 주세요.';

  @override
  String get aiQuickCommandCategoryAnalysisTitle => '카테고리 분석';

  @override
  String get aiQuickCommandCategoryAnalysisDesc => '카테고리별 지출 분포를 분석합니다';

  @override
  String get aiQuickCommandCategoryAnalysisPrompt => '다음 데이터를 바탕으로 카테고리별 지출을 분석해 주세요:\n\n[categoryStats]\n\n불합리한 지출 비율이 있는지 짚어주고 개선 제안을 제공해 주세요. 한국어로 답변해 주세요.';

  @override
  String get aiQuickCommandBudgetPlanningTitle => '예산 계획';

  @override
  String get aiQuickCommandBudgetPlanningDesc => '스마트 예산 제안';

  @override
  String get aiQuickCommandBudgetPlanningPrompt => '다음 데이터를 바탕으로 합리적인 예산을 계획하도록 도와주세요:\n\n[monthlyStats]\n\n[recentTrends]\n\n카테고리별 구체적인 예산 금액과 실행 제안을 제공해 주세요. 한국어로 답변해 주세요.';

  @override
  String get aiQuickCommandAbnormalExpenseTitle => '이상 지출 알림';

  @override
  String get aiQuickCommandAbnormalExpenseDesc => '특이한 지출을 찾아냅니다';

  @override
  String get aiQuickCommandAbnormalExpensePrompt => '다음 데이터를 바탕으로 이상한 지출이 있는지 확인해 주세요:\n\n[recentTransactions]\n\n[monthlyStats]\n\n평소보다 눈에 띄게 높은 지출을 찾아 분석해 주세요. 한국어로 답변해 주세요.';

  @override
  String get aiQuickCommandSavingTipsTitle => '절약 팁';

  @override
  String get aiQuickCommandSavingTipsDesc => '개인 맞춤형 절약 제안';

  @override
  String get aiQuickCommandSavingTipsPrompt => '다음 데이터를 바탕으로 실용적인 절약 제안을 제공해 주세요:\n\n[categoryStats]\n\n[recentTrends]\n\n구체적이고 실천 가능한 제안을 3~5가지 제공해 주세요. 한국어로 답변해 주세요.';

  @override
  String get billCardUnknownLedger => '알 수 없는 가계부';

  @override
  String get aiPromptEditTitle => '프롬프트 편집기';

  @override
  String get aiPromptEditSubtitle => 'AI 영수증 인식 프롬프트를 사용자 지정합니다';

  @override
  String get aiPromptAdvancedSettings => '고급 설정';

  @override
  String get aiAdvancedSettingsDesc => '모델 선택, 전략, 로컬 모델, 프롬프트';

  @override
  String get aiPromptEditEntry => '프롬프트 편집기';

  @override
  String get aiPromptEditEntryDesc => 'AI 영수증 인식 프롬프트를 사용자 지정하고 다른 사람과 공유할 수 있습니다';

  @override
  String get aiPromptVariables => '변수';

  @override
  String get aiPromptVariablesHint => '눌러서 사용 가능한 변수를 확인하세요';

  @override
  String get aiPromptContent => '프롬프트 내용';

  @override
  String get aiPromptUnsaved => '저장되지 않음';

  @override
  String get aiPromptInputHint => '프롬프트를 입력하세요...';

  @override
  String get aiPromptPreview => '미리보기';

  @override
  String get aiPromptSave => '저장';

  @override
  String get aiPromptSaved => '프롬프트가 저장되었습니다';

  @override
  String get aiPromptResetDefault => '기본값으로 재설정';

  @override
  String get aiPromptResetConfirmTitle => '기본값으로 재설정';

  @override
  String get aiPromptResetConfirmMessage => '기본 프롬프트로 재설정하시겠습니까? 사용자 지정 내용이 사라집니다.';

  @override
  String get aiPromptPasted => '붙여넣기 완료';

  @override
  String get aiPromptPreviewTitle => '프롬프트 미리보기';

  @override
  String get aiPromptPreviewNote => '미리보기는 변수에 예시 데이터를 사용합니다. 실행 시에는 실제 데이터가 사용됩니다.';

  @override
  String get aiPromptVarInputSource => '입력 소스 설명, 예: \"다음 결제 영수증 텍스트로부터\"';

  @override
  String get aiPromptVarCurrentTime => '현재 날짜와 시간, 예: \"2025-01-15 14:30\"';

  @override
  String get aiPromptVarCurrentDate => '현재 날짜, 예: \"2025-01-15\"';

  @override
  String get aiPromptVarOcrText => '사용자가 입력한 텍스트 내용';

  @override
  String get aiPromptVarCategories => '지출 및 수입 카테고리 목록';

  @override
  String get aiPromptVarAccounts => '사용자의 계정 목록 (비어 있을 수 있음)';

  @override
  String get aiModelTitle => '텍스트 추론 모델';

  @override
  String get aiVisionModelTitle => '비전 모델';

  @override
  String get aiModelFast => '빠름';

  @override
  String get aiModelAccurate => '정확함';

  @override
  String aiModelSwitched(String modelName) {
    return '$modelName(으)로 전환되었습니다';
  }

  @override
  String get aiCustomBaseUrlHelper => '표준 채팅 완성 API URL, 예: https://api.example.com/v1';

  @override
  String get aiTextModelTitle => '텍스트 모델';

  @override
  String get aiAudioModelTitle => '오디오 모델';

  @override
  String get tagManageTitle => '태그';

  @override
  String get tagManageSubtitle => '거래 태그를 관리하세요';

  @override
  String get tagManageEmpty => '아직 태그가 없습니다';

  @override
  String get tagManageEmptyHint => '+를 눌러 태그를 추가하세요';

  @override
  String get tagManageGenerateDefault => '기본 태그 생성';

  @override
  String get tagManageGenerateDefaultConfirm => '기본 태그를 생성하시겠습니까? 이름이 같은 기존 태그는 덮어쓰지 않습니다.';

  @override
  String get tagManageGenerateDefaultSuccess => '기본 태그가 생성되었습니다';

  @override
  String get tagEditTitle => '태그 편집';

  @override
  String get tagAddTitle => '태그 추가';

  @override
  String get tagNameLabel => '태그 이름';

  @override
  String get tagNameHint => '태그 이름을 입력하세요';

  @override
  String get tagNameRequired => '태그 이름을 입력해 주세요';

  @override
  String get tagNameDuplicate => '이미 존재하는 태그 이름입니다';

  @override
  String get tagColorLabel => '태그 색상';

  @override
  String get tagCreateSuccess => '태그가 생성되었습니다';

  @override
  String get tagUpdateSuccess => '태그가 수정되었습니다';

  @override
  String get tagDeleteConfirmTitle => '태그 삭제';

  @override
  String tagDeleteConfirmMessage(String name) {
    return '태그 \"$name\"을(를) 삭제하시겠습니까? 연결된 거래에는 영향을 주지 않습니다.';
  }

  @override
  String get tagDeleteSuccess => '태그가 삭제되었습니다';

  @override
  String get tagSelectTitle => '태그 선택';

  @override
  String get tagSelectHint => '여러 개 선택 가능';

  @override
  String get tagSelectCreateNew => '새 태그 만들기';

  @override
  String get tagSelectRecentlyUsed => '최근 사용';

  @override
  String get tagSelectAllTags => '전체 태그';

  @override
  String tagTransactionCount(int count) {
    return '거래 $count건';
  }

  @override
  String get tagDetailTitle => '태그 상세';

  @override
  String get tagDetailTotalCount => '거래 수';

  @override
  String get tagDetailTotalExpense => '총 지출';

  @override
  String get tagDetailTotalIncome => '총 수입';

  @override
  String get tagDetailTransactionList => '관련 거래';

  @override
  String get tagDetailNoTransactions => '관련 거래가 없습니다';

  @override
  String get tagDetailNoTransactionsHint => '이 태그가 지정된 거래가 여기에 표시됩니다';

  @override
  String get tagNotFound => '태그를 찾을 수 없습니다';

  @override
  String get tagDefaultMeituan => '배달의민족';

  @override
  String get tagDefaultEleme => '요기요';

  @override
  String get tagDefaultTaobao => '쿠팡';

  @override
  String get tagDefaultJD => '네이버쇼핑';

  @override
  String get tagDefaultPDD => '알리익스프레스';

  @override
  String get tagDefaultStarbucks => '스타벅스';

  @override
  String get tagDefaultLuckin => '메가커피';

  @override
  String get tagDefaultMcDonalds => '맥도날드';

  @override
  String get tagDefaultKFC => 'KFC';

  @override
  String get tagDefaultHema => '마켓컬리';

  @override
  String get tagDefaultSams => '트레이더스';

  @override
  String get tagDefaultCostco => '코스트코';

  @override
  String get tagDefaultBusinessTrip => '출장';

  @override
  String get tagDefaultTravel => '여행';

  @override
  String get tagDefaultDining => '외식';

  @override
  String get tagDefaultOnlineShopping => '온라인 쇼핑';

  @override
  String get tagDefaultDaily => '일상';

  @override
  String get tagDefaultReimbursement => '환급 대상';

  @override
  String get tagDefaultRefundable => '환불 가능';

  @override
  String get tagDefaultRefunded => '환불 완료';

  @override
  String get tagDefaultVoiceBilling => '음성';

  @override
  String get tagDefaultImageBilling => '이미지';

  @override
  String get tagDefaultCameraBilling => '카메라';

  @override
  String get tagDefaultAiBilling => 'AI';

  @override
  String get tagShare => '태그 공유';

  @override
  String get tagImport => '태그 가져오기';

  @override
  String get tagClearUnused => '사용하지 않는 태그 정리';

  @override
  String tagShareSuccess(String path) {
    return '$path에 저장되었습니다';
  }

  @override
  String get tagShareSubject => 'BeeCount 태그 설정';

  @override
  String get tagShareFailed => '공유 실패';

  @override
  String get tagImportInvalidFile => 'YAML 파일을 선택해 주세요';

  @override
  String get tagImportNoTags => '파일에서 태그를 찾을 수 없습니다';

  @override
  String get tagImportModeTitle => '가져오기 방식 선택';

  @override
  String get tagImportModeMerge => '병합';

  @override
  String get tagImportModeMergeDesc => '기존 태그는 유지하고 새 태그만 추가합니다';

  @override
  String get tagImportModeOverwrite => '덮어쓰기';

  @override
  String get tagImportModeOverwriteDesc => '사용하지 않는 태그를 정리한 후 가져옵니다';

  @override
  String get tagImportSuccess => '가져오기 성공';

  @override
  String get tagImportFailed => '가져오기 실패';

  @override
  String get tagClearUnusedEmpty => '사용하지 않는 태그가 없습니다';

  @override
  String get tagClearUnusedTitle => '사용하지 않는 태그 정리';

  @override
  String tagClearUnusedMessage(int count) {
    return '사용하지 않는 태그 $count개를 삭제하시겠습니까?';
  }

  @override
  String tagClearUnusedSuccess(int count) {
    return '태그 $count개를 삭제했습니다';
  }

  @override
  String get tagClearUnusedFailed => '정리 실패';

  @override
  String get homeSwitchLedger => '가계부 선택';

  @override
  String get homeManageLedgers => '가계부 관리';

  @override
  String get budgetTitle => '예산';

  @override
  String get budgetShowOnHome => '홈에 예산 표시';

  @override
  String get budgetEmptyHint => '아직 설정된 예산이 없습니다';

  @override
  String get budgetAddTotal => '총 예산 추가';

  @override
  String get budgetMonthlyBudget => '월간 예산';

  @override
  String get budgetUsed => '사용액';

  @override
  String get budgetRemaining => '남은 금액';

  @override
  String budgetDaysRemaining(int days) {
    return '$days일 남음';
  }

  @override
  String budgetDailyAvailable(String amount) {
    return '일일 사용 가능 $amount';
  }

  @override
  String get budgetCategoryBudgets => '카테고리별 예산';

  @override
  String get budgetEditTitle => '예산 편집';

  @override
  String get budgetAddTitle => '예산 추가';

  @override
  String get budgetTypeTotalLabel => '총 예산';

  @override
  String get budgetTypeCategoryLabel => '카테고리 예산';

  @override
  String get budgetAmountLabel => '예산 금액';

  @override
  String get budgetAmountHint => '예산 금액을 입력하세요';

  @override
  String get budgetCategoryLabel => '카테고리 선택';

  @override
  String get budgetCategoryHint => '예산 카테고리를 선택하세요';

  @override
  String get budgetStartDayLabel => '시작일';

  @override
  String get budgetPeriodLabel => '기간';

  @override
  String get budgetSaveSuccess => '예산이 저장되었습니다';

  @override
  String get budgetDeleteConfirm => '이 예산을 삭제하시겠습니까?';

  @override
  String get budgetDeleteSuccess => '예산이 삭제되었습니다';

  @override
  String get attachmentAdd => '이미지 추가';

  @override
  String get attachmentTakePhoto => '사진 촬영';

  @override
  String get attachmentChooseFromGallery => '갤러리에서 선택';

  @override
  String get attachmentMaxReached => '첨부 가능한 최대 개수에 도달했습니다';

  @override
  String get attachmentDeleteConfirm => '이 첨부파일을 삭제하시겠습니까?';

  @override
  String attachmentCount(int count) {
    return '이미지 $count개';
  }

  @override
  String get commonDeleted => '삭제됨';

  @override
  String get attachmentExportTitle => '첨부파일 내보내기';

  @override
  String get attachmentExportSubtitle => '모든 첨부파일을 압축 파일로 내보냅니다';

  @override
  String get attachmentImportTitle => '첨부파일 가져오기';

  @override
  String get attachmentImportSubtitle => '압축 파일에서 첨부파일을 가져옵니다';

  @override
  String get attachmentExportEmpty => '내보낼 첨부파일이 없습니다';

  @override
  String attachmentExportProgress(int current, int total) {
    return '첨부파일 내보내는 중 ($current/$total)';
  }

  @override
  String attachmentExportProgressDetail(int attachmentCount, int iconCount, int current, int total) {
    return '첨부파일 $attachmentCount개 + 아이콘 $iconCount개 내보내는 중 ($current/$total)';
  }

  @override
  String get attachmentExportSuccess => '첨부파일을 내보냈습니다';

  @override
  String attachmentExportSavedTo(String path) {
    return '저장 위치: $path';
  }

  @override
  String get attachmentImportConflictStrategy => '충돌 처리 방식';

  @override
  String get attachmentImportConflictSkip => '기존 첨부파일 건너뛰기';

  @override
  String get attachmentImportConflictOverwrite => '기존 첨부파일 덮어쓰기';

  @override
  String attachmentImportProgress(int current, int total) {
    return '첨부파일 가져오는 중 ($current/$total)';
  }

  @override
  String attachmentImportResult(int imported, int skipped, int overwritten, int failed) {
    return '가져옴 $imported개, 건너뜀 $skipped개, 덮어씀 $overwritten개, 실패 $failed개';
  }

  @override
  String get attachmentImportFailed => '첨부파일 가져오기 실패';

  @override
  String attachmentArchiveInfo(int count, String date) {
    return '첨부파일 $count개, $date에 내보냄';
  }

  @override
  String get attachmentStartImport => '가져오기 시작';

  @override
  String get attachmentPreview => '첨부파일 미리보기';

  @override
  String attachmentPreviewSubtitle(int count) {
    return '총 $count개 이미지';
  }

  @override
  String get attachmentPreviewEmpty => '첨부파일이 없습니다';

  @override
  String get attachmentExportPreviewTitle => '내보내기 미리보기';

  @override
  String get attachmentImportPreviewTitle => '가져오기 미리보기';

  @override
  String get shortcutsGuide => '단축어';

  @override
  String get shortcutsGuideDesc => '음성, 카메라 기록 등에 빠르게 접근하세요';

  @override
  String get shortcutsIntroTitle => '빠른 기록';

  @override
  String get shortcutsIntroDesc => '단축어를 사용하면 앱을 먼저 열지 않고도 홈 화면에서 음성 기록, 카메라 기록 등 기능을 바로 실행할 수 있습니다.';

  @override
  String get availableShortcuts => '사용 가능한 단축어';

  @override
  String get shortcutVoice => '음성 기록';

  @override
  String get shortcutVoiceDesc => '음성으로 빠르게 기록합니다';

  @override
  String get shortcutImage => '이미지 기록';

  @override
  String get shortcutImageDesc => '갤러리 이미지에서 영수증을 인식합니다';

  @override
  String get shortcutCamera => '카메라 기록';

  @override
  String get shortcutCameraDesc => '사진을 찍어 영수증을 인식합니다';

  @override
  String get shortcutNewExpense => '빠른 지출 기록';

  @override
  String get shortcutNewExpenseDesc => '지출 입력 화면을 바로 엽니다';

  @override
  String get shortcutNewIncome => '빠른 수입 기록';

  @override
  String get shortcutNewIncomeDesc => '수입 입력 화면을 바로 엽니다';

  @override
  String get shortcutNewTransfer => '빠른 이체 기록';

  @override
  String get shortcutNewTransferDesc => '이체 입력 화면을 바로 엽니다';

  @override
  String get shortcutUrlCopied => 'URL이 클립보드에 복사되었습니다';

  @override
  String get howToAddShortcut => '단축어 추가 방법';

  @override
  String get iosShortcutStep1 => '단축어 앱을 여세요';

  @override
  String get iosShortcutStep2 => '오른쪽 상단의 +를 눌러 새 단축어를 만드세요';

  @override
  String get iosShortcutStep3 => '\'URL 열기\' 동작을 추가하세요';

  @override
  String get iosShortcutStep4 => '복사한 URL을 붙여넣으세요 (예: beecount://voice)';

  @override
  String get iosShortcutStep5 => '저장하고 홈 화면에 추가하세요';

  @override
  String get androidShortcutStep1 => '단축어 생성 앱을 다운로드하세요 (예: Shortcut Maker)';

  @override
  String get androidShortcutStep2 => '\'URL 바로가기\'를 선택하세요';

  @override
  String get androidShortcutStep3 => '복사한 URL을 붙여넣으세요 (예: beecount://voice)';

  @override
  String get androidShortcutStep4 => '아이콘과 이름을 설정하고 홈 화면에 추가하세요';

  @override
  String get shortcutsTip => '팁';

  @override
  String get shortcutsTipDesc => '단축어를 사용하려면 AI 기능이 필요합니다. AI가 활성화되어 있고 API 키가 설정되어 있는지 확인하세요.';

  @override
  String get shortcutOpenShortcutsApp => '단축어 앱 열기';

  @override
  String get shortcutAutoAdd => '자동 기록 API';

  @override
  String get shortcutAutoAddDesc => 'URL 매개변수로 영수증을 자동으로 생성합니다. 단축어 및 자동화 도구와 함께 사용하면 편리합니다.';

  @override
  String get shortcutAutoAddExample => 'URL 예시:';

  @override
  String get shortcutAutoAddParams => '지원되는 매개변수:';

  @override
  String get shortcutParamAmount => '금액 (필수)';

  @override
  String get shortcutParamType => '유형: expense / income / transfer';

  @override
  String get shortcutParamCategory => '카테고리 이름 (기존 카테고리와 일치해야 함)';

  @override
  String get shortcutParamNote => '메모';

  @override
  String get shortcutParamAccount => '계정 이름 (기존 계정과 일치해야 함)';

  @override
  String get shortcutParamTags => '태그 (쉼표로 구분)';

  @override
  String get shortcutParamDate => '날짜 (ISO 형식, 예: 2024-01-15)';

  @override
  String get quickActionImage => '사진으로 기록';

  @override
  String get quickActionCamera => '카메라로 기록';

  @override
  String get quickActionVoice => '음성으로 기록';

  @override
  String get quickActionAiChat => 'AI 어시스턴트';

  @override
  String get calendarTitle => '캘린더';

  @override
  String get calendarToday => '오늘';

  @override
  String get calendarNoTransactions => '거래 없음';

  @override
  String get calendarAddTransaction => '이 날짜에 기록 추가';

  @override
  String get calendarAddTransactionTooltip => '선택한 날짜에 기록을 추가합니다';

  @override
  String get commonUncategorized => '미분류';

  @override
  String get commonSaved => '저장됨';

  @override
  String get aiProviderManageTitle => '제공업체 관리';

  @override
  String get aiProviderManageSubtitle => 'AI 서비스 제공업체를 관리하세요';

  @override
  String get aiProviderAdd => '제공업체 추가';

  @override
  String get aiProviderBuiltIn => '기본 제공';

  @override
  String get aiProviderEmpty => '설정된 제공업체가 없습니다';

  @override
  String get aiProviderNoApiKey => 'API 키가 설정되지 않음';

  @override
  String get aiProviderTapToEdit => '눌러서 편집';

  @override
  String get aiProviderDeleteTitle => '제공업체 삭제';

  @override
  String aiProviderDeleteConfirm(String name) {
    return '제공업체 \"$name\"을(를) 삭제하시겠습니까? 이 제공업체를 사용하는 기능은 기본값으로 전환됩니다.';
  }

  @override
  String get aiProviderDeleted => '제공업체가 삭제되었습니다';

  @override
  String get aiProviderEditTitle => '제공업체 편집';

  @override
  String get aiProviderAddTitle => '제공업체 추가';

  @override
  String get aiProviderBasicInfo => '기본 정보';

  @override
  String get aiProviderName => '제공업체 이름';

  @override
  String get aiProviderNameHint => '예: SiliconFlow, DeepSeek';

  @override
  String get aiProviderNameRequired => '제공업체 이름을 입력해 주세요';

  @override
  String get aiProviderBaseUrlRequired => 'Base URL을 입력해 주세요';

  @override
  String get aiProviderModels => '모델 설정';

  @override
  String get aiProviderModelsHint => '비어 있는 기능은 이 제공업체를 사용할 수 없습니다';

  @override
  String get aiCapabilityText => '텍스트';

  @override
  String get aiCapabilityVision => '비전';

  @override
  String get aiCapabilitySpeech => '음성';

  @override
  String get aiCapabilitySelectTitle => '기능 연결';

  @override
  String get aiCapabilitySelectSubtitle => '각 AI 기능에 사용할 제공업체를 선택하세요';

  @override
  String get aiCapabilityTextChat => '텍스트 대화';

  @override
  String get aiCapabilityTextChatDesc => 'AI 대화 및 텍스트 영수증 추출에 사용됩니다';

  @override
  String get aiCapabilityImageUnderstand => '이미지 이해';

  @override
  String get aiCapabilityImageUnderstandDesc => '이미지 영수증 인식에 사용됩니다';

  @override
  String get aiCapabilitySpeechToText => '음성을 텍스트로';

  @override
  String get aiCapabilitySpeechToTextDesc => '음성 기록에 사용됩니다';

  @override
  String get aiProviderTestRun => '눌러서 테스트';

  @override
  String get aiProviderTestRunning => '테스트 중...';

  @override
  String get aiProviderTestSuccess => '테스트 통과';

  @override
  String get aiProviderTestFailed => '테스트 실패';

  @override
  String get aiProviderTestAll => '전체 테스트';

  @override
  String get aiProviderTestAllRetry => '테스트 재시도';

  @override
  String get aiModelInputHelper => '비워두면 기본 모델을 사용합니다';

  @override
  String get syncPreviewTitle => '동기화 미리보기';

  @override
  String get syncPreviewSelectAll => '전체 선택';

  @override
  String get syncPreviewDeselectAll => '전체 선택 해제';

  @override
  String get syncPreviewAdded => '추가됨';

  @override
  String get syncPreviewModified => '수정됨';

  @override
  String get syncPreviewDeleted => '삭제됨';

  @override
  String syncPreviewAddedCount(int count) {
    return '$count건 추가됨';
  }

  @override
  String syncPreviewModifiedCount(int count) {
    return '$count건 수정됨';
  }

  @override
  String syncPreviewDeletedCount(int count) {
    return '$count건 삭제됨';
  }

  @override
  String syncPreviewApply(int count) {
    return '$count건 적용';
  }

  @override
  String get syncPreviewEmpty => '클라우드 데이터가 로컬과 일치합니다. 동기화가 필요하지 않습니다';

  @override
  String get syncPreviewOldFormat => '이전 클라우드 형식, 전체 교체가 필요합니다';

  @override
  String get syncPreviewOldFormatMessage => '클라우드 데이터에 동기화 ID가 없습니다. 로컬 데이터를 지우고 클라우드에서 다시 가져옵니다.';

  @override
  String syncPreviewApplied(int count) {
    return '$count건의 변경 사항을 적용했습니다';
  }

  @override
  String get cloudSyncGuideTitle => '클라우드 동기화 안내';

  @override
  String get cloudSyncGuideGotIt => '확인했습니다';

  @override
  String get cloudSyncGuideHowItWorks => '작동 방식';

  @override
  String get cloudSyncGuideHowItem1 => '업로드: 현재 가계부의 모든 데이터를 묶어 클라우드에 업로드하고 기존 클라우드 데이터를 대체합니다';

  @override
  String get cloudSyncGuideHowItem2 => '다운로드: 클라우드 데이터를 가져와 로컬 기록과 하나씩 비교합니다 — 적용할 변경 사항을 직접 선택할 수 있습니다';

  @override
  String get cloudSyncGuideHowItem3 => '클라우드에는 항상 가장 최근에 업로드된 스냅샷만 저장되며 버전 기록은 없습니다';

  @override
  String get cloudSyncGuideCorrect => '올바른 사용법';

  @override
  String get cloudSyncGuideCorrectItem1 => '한 번에 한 기기에서만 편집하고, 끝나면 업로드하세요';

  @override
  String get cloudSyncGuideCorrectItem2 => '새 기기에서는 편집을 시작하기 전에 다운로드하세요';

  @override
  String get cloudSyncGuideCorrectItem3 => '변경 사항을 적용하기 전에 미리보기를 꼼꼼히 확인하세요';

  @override
  String get cloudSyncGuideCorrectItem4 => '편집 → 업로드 → 기기 전환 → 다운로드 → 편집 순서를 따르세요';

  @override
  String get cloudSyncGuideWrong => '피해야 할 사용법';

  @override
  String get cloudSyncGuideWrongItem1 => '두 기기에서 동시에 같은 가계부를 편집하는 것 — 나중에 업로드한 쪽이 이전 것을 덮어씁니다';

  @override
  String get cloudSyncGuideWrongItem2 => '업로드 직후 바로 다운로드하는 것 — 클라우드 서비스는 수 초에서 수 분의 동기화 지연이 있을 수 있으니 잠시 기다려 주세요';

  @override
  String get cloudSyncGuideWrongItem3 => '오랫동안 동기화하지 않다가 한 번에 많은 변경 사항을 다운로드하는 것 — 중요한 차이를 놓치기 쉽습니다';

  @override
  String get cloudSyncGuideLimitations => '알려진 제한 사항';

  @override
  String get cloudSyncGuideLimitItem1 => '실시간이 아닙니다: 업로드와 다운로드를 수동으로 눌러야 합니다';

  @override
  String get cloudSyncGuideLimitItem2 => '충돌 병합이 없습니다: 양쪽의 편집을 자동으로 병합하지 않으며 마지막 업로드가 우선합니다';

  @override
  String get cloudSyncGuideLimitItem3 => '클라우드 서비스 지연: 업로드된 파일을 다른 기기가 읽을 수 있게 되기까지 사용하는 클라우드 제공업체에 따라 수 초에서 수 분이 걸릴 수 있습니다';

  @override
  String get cloudSyncGuideLimitItem4 => '첨부파일은 제외됩니다: 거래의 이미지 첨부파일은 동기화되지 않으므로 데이터 관리에서 별도로 내보내세요';

  @override
  String get mineMultiDeviceSyncTitle => '다중 기기 동기화';

  @override
  String get mineMultiDeviceSyncSubtitle => '페이지 진입 시 클라우드 변경 사항을 자동으로 확인합니다';

  @override
  String get appLockTitle => '앱 잠금';

  @override
  String get appLockDesc => 'PIN과 생체 인식으로 개인정보를 보호하세요';

  @override
  String get appLockEnable => '앱 잠금 사용';

  @override
  String get appLockEnableDesc => '실행 및 재개 시 인증을 요구합니다';

  @override
  String get appLockSetPin => 'PIN 설정';

  @override
  String get appLockChangePin => 'PIN 변경';

  @override
  String get appLockVerifyPin => 'PIN 확인';

  @override
  String get appLockVerifyCurrentPin => '현재 PIN을 입력하세요';

  @override
  String get appLockSetNewPin => '새 PIN 설정';

  @override
  String get appLockConfirmPin => 'PIN 확인';

  @override
  String get appLockEnterPin => 'PIN 입력';

  @override
  String get appLockPinSetSuccess => 'PIN이 설정되었습니다';

  @override
  String get appLockDisabled => '앱 잠금이 비활성화되었습니다';

  @override
  String get appLockBiometric => '생체 인식 잠금 해제';

  @override
  String get appLockBiometricDesc => 'Face ID 또는 지문으로 잠금을 해제합니다';

  @override
  String get appLockBiometricReason => '꿀벌 가계부 잠금을 해제하려면 본인 인증이 필요합니다';

  @override
  String get appLockTimeout => '자동 잠금 시간';

  @override
  String get appLockTimeoutImmediate => '즉시';

  @override
  String get appLockTimeout1Min => '1분 후';

  @override
  String get appLockTimeout5Min => '5분 후';

  @override
  String get appLockTimeout15Min => '15분 후';

  @override
  String get creditCardSettings => '신용카드 설정';

  @override
  String get accountTabValuation => '평가액';

  @override
  String get creditCardDaysRequired => '결제일과 만기일을 선택해 주세요';

  @override
  String get creditLimit => '신용 한도';

  @override
  String get creditLimitHint => '신용 한도를 입력하세요';

  @override
  String get billingDay => '결제일';

  @override
  String get paymentDueDay => '만기일';

  @override
  String get creditUsed => '사용액';

  @override
  String get creditAvailable => '이용 가능액';

  @override
  String get creditCardOwed => '미납액';

  @override
  String dayOfMonth(int day) {
    return '매월 $day일';
  }

  @override
  String get creditCardReminderTitle => '결제 알림';

  @override
  String get creditCardReminderDesc => '만기일 전에 알려드립니다';

  @override
  String creditCardReminderDaysBefore(int days) {
    return '$days일 전';
  }

  @override
  String get creditCardInitialBalanceHint => '현재 채무액 (음수로 입력)';

  @override
  String get selectDay => '날짜 선택';

  @override
  String get accountBankName => '은행';

  @override
  String get accountBankNameHint => '예: 국민은행';

  @override
  String get accountCardLastFour => '카드 끝 4자리';

  @override
  String get accountCardLastFourHint => '예: 1234';

  @override
  String get accountNote => '메모';

  @override
  String get accountNoteHint => '메모를 추가하세요';

  @override
  String get accountMetaInfo => '계정 정보';

  @override
  String get accountBalanceTrend => '잔액 추이';

  @override
  String get accountCategoryBreakdown => '카테고리별 분석';

  @override
  String get accountCategoryExpense => '지출';

  @override
  String get accountCategoryIncome => '수입';

  @override
  String get accountNoMoreData => '더 이상 데이터가 없습니다';

  @override
  String get totalAssets => '총 자산';

  @override
  String get totalLiabilities => '총 부채';

  @override
  String get assetAccounts => '자산 계정';

  @override
  String get liabilityAccounts => '부채 계정';

  @override
  String get assetComposition => '자산 구성';

  @override
  String get accountTypeInvestment => '투자';

  @override
  String get accountTypeLoan => '대출';

  @override
  String get accountTypeReceivable => '미수금';

  @override
  String get accountTypeRealEstate => '부동산';

  @override
  String get accountTypeVehicle => '차량';

  @override
  String get accountTypeInsurance => '보험';

  @override
  String get accountTypeSocialFund => '사회보험기금';

  @override
  String get valuationCurrentValue => '현재 평가액';

  @override
  String get valuationCurrentDebt => '현재 채무액';

  @override
  String get valuationUpdateValue => '평가액 업데이트';

  @override
  String get valuationUpdateDebt => '채무액 업데이트';

  @override
  String valuationLastUpdated(String date) {
    return '마지막 업데이트: $date';
  }

  @override
  String get valuationAccountHint => '현재 평가액을 입력하세요';

  @override
  String get valuationDebtHint => '현재 채무액을 입력하세요';

  @override
  String get accountGroupTradable => '일상 계정';

  @override
  String get accountGroupValuation => '자산/부채';

  @override
  String get adjustmentTransaction => '평가액 조정';

  @override
  String creditCardBillingInfo(int billingDay, int paymentDueDay) {
    return '매월 $billingDay일 결제 · $paymentDueDay일 만기';
  }

  @override
  String creditCardDaysUntilPayment(int days) {
    return '만기까지 $days일';
  }

  @override
  String get creditCardPaymentDueToday => '오늘이 결제 만기일입니다';

  @override
  String get creditCardQuickRepay => '상환 기록하기';

  @override
  String get budgetManagement => '예산';

  @override
  String get budgetManagementDesc => '월간 예산을 설정하고 지출을 관리하세요';

  @override
  String get budgetSetupHint => '예산을 설정해 월간 지출을 관리하세요';

  @override
  String get budgetSetupAction => '설정하기';

  @override
  String get cloudCollabDevicesPageTitle => '기기 세션';

  @override
  String get cloudCollabDevicesPageSubtitle => '활성 기기를 관리하세요';

  @override
  String get cloudCollabDevicesViewAllSessions => '모든 세션 표시';

  @override
  String get cloudCollabDevicesViewModeHint => '기본 화면은 최근 30일 이내 활성화된 기기를 중복 제거해 표시합니다.';

  @override
  String get cloudCollabNoDevices => '활성 기기가 없습니다';

  @override
  String get cloudCollabUnknownDeviceName => '알 수 없는 기기';

  @override
  String get cloudCollabDeviceCurrentTag => '현재 기기';

  @override
  String get cloudCollabCurrentDeviceCannotRevoke => '현재 기기는 취소할 수 없습니다.';

  @override
  String cloudCollabDeviceAppVersion(String version) {
    return '앱: $version';
  }

  @override
  String cloudCollabDeviceOsVersion(String version) {
    return 'OS: $version';
  }

  @override
  String cloudCollabDeviceModel(String model) {
    return '모델: $model';
  }

  @override
  String cloudCollabDeviceLastIp(String ip) {
    return 'IP: $ip';
  }

  @override
  String cloudCollabDeviceSessionCount(String count) {
    return '세션: $count개';
  }

  @override
  String cloudCollabDeviceLastSeen(String time) {
    return '마지막 접속: $time';
  }

  @override
  String cloudCollabDeviceCreatedAt(String time) {
    return '생성: $time';
  }

  @override
  String get cloudCollabDeviceRevokeTitle => '기기 취소';

  @override
  String cloudCollabDeviceRevokeMessage(String name, String id) {
    return '$name ($id) 기기를 취소하시겠습니까?';
  }

  @override
  String cloudCollabDeviceRevokeMultipleMessage(String name, String count) {
    return '$name 기기의 세션 $count개를 취소하시겠습니까?';
  }

  @override
  String get cloudCollabDeviceRevoked => '기기가 취소되었습니다';

  @override
  String get cloudCollabUnavailableMessage => '클라우드 동기화를 사용할 수 없습니다.';

  @override
  String get cloudCollabScopeDeniedHint => '서버에서 ALLOW_APP_RW_SCOPES가 활성화되어 있지 않아 기기 세션을 사용할 수 없습니다.';

  @override
  String get cloudCollabScopeDeniedAction => '서버 .env에서 ALLOW_APP_RW_SCOPES=true로 설정하고 서비스를 재시작한 후 다시 로그인하세요.';

  @override
  String get syncHealthTitle => '동기화 상태';

  @override
  String get cloudSyncHelpTitle => '동기화 작동 방식 · 가끔 멈추는 이유';

  @override
  String get cloudSyncHelpModesTitle => '세 가지 동기화 모드';

  @override
  String get cloudSyncHelpModesBody => '• 증분 동기화 (자동, 매일): 항목을 추가하거나 편집하면 해당 변경 사항만 자동으로 업로드/다운로드됩니다 — 빠르고 수동 작업이 필요 없습니다. 항상 실행되는 방식입니다.\n• 전체 업로드: 클라우드 동기화를 처음 활성화하거나 이 가계부에 대한 클라우드 데이터가 아직 없을 때, 로컬 데이터 전체가 한 번에 클라우드로 전송됩니다.\n• 전체 다운로드: 새 기기, 재설치 후, 또는 로컬이 비어 있을 때 클라우드에서 모든 데이터를 가져옵니다.';

  @override
  String get cloudSyncHelpWhenFullTitle => '전체 동기화는 언제 발생하나요?';

  @override
  String get cloudSyncHelpWhenFullBody => '전체 동기화는 한쪽이 비어 있을 때만 자동으로 실행됩니다 (클라우드 동기화 최초 활성화 / 새 기기 / 재설치 / 로컬 또는 클라우드 데이터 삭제 후). 양쪽 모두 데이터가 있는 한 동기화는 증분 방식을 유지하며 스스로 다시 시작하지 않습니다. 강제로 전체 재동기화를 하려면 먼저 해당 쪽의 데이터를 지워야 합니다.';

  @override
  String get cloudSyncHelpStuckTitle => '동기화가 가끔 멈추는 이유';

  @override
  String get cloudSyncHelpStuckBody => '• 전체 업로드/다운로드는 이어받기를 지원하지 않습니다: 네트워크가 끊기거나 앱이 백그라운드에서 종료되면 이어서 진행하지 않고 처음부터 다시 시작합니다. 데이터가 클 경우 안정적인 네트워크(Wi-Fi 권장)를 사용하고 완료될 때까지 다른 곳으로 전환하지 마세요.\n• 증분 동기화는 이어받기가 안전하며 일상적인 사용에서는 영향을 받지 않습니다.';

  @override
  String get cloudSyncHelpTroubleshootTitle => '문제 해결';

  @override
  String get cloudSyncHelpTroubleshootBody => '• 먼저 이 페이지를 아래로 당겨 정밀 검사를 실행하고 로컬과 클라우드를 비교하세요.\n• 그래도 해결되지 않으면 로그 센터를 열어 동기화 로그(실패 원인 포함)를 확인하고 신고해 주세요.';

  @override
  String get cloudSyncHelpOpenLogCenter => '로그 센터 열기';

  @override
  String syncHealthCheckFailed(String msg) {
    return '확인 실패: $msg';
  }

  @override
  String get syncHealthHasDiff => '차이가 감지되어 자동으로 동기화되었습니다';

  @override
  String get syncHealthInSync => '로컬과 클라우드가 일치합니다';

  @override
  String get syncHealthGroupCurrentLedger => '현재 가계부';

  @override
  String get syncHealthGroupAll => '전체 가계부';

  @override
  String get syncHealthRowTx => '거래';

  @override
  String get syncHealthRowAttachment => '첨부파일';

  @override
  String get syncHealthRowCategoryIcon => '카테고리 아이콘';

  @override
  String get syncHealthRowBudget => '예산';

  @override
  String get syncHealthRowAccount => '계정';

  @override
  String get syncHealthRowCategory => '카테고리';

  @override
  String get syncHealthRowTag => '태그';

  @override
  String get syncHealthRowUnpushed => '업로드 대기 중';

  @override
  String syncHealthValue(int local, int remote) {
    return '로컬 $local · 클라우드 $remote';
  }

  @override
  String syncHealthValueRemoteMissing(int local) {
    return '로컬 $local · 클라우드 —';
  }

  @override
  String get twofaChallengeTitle => '2단계 인증';

  @override
  String get twofaMethodTotp => '인증 코드';

  @override
  String get twofaMethodRecovery => '복구 코드';

  @override
  String get twofaTotpHint => '인증 앱(Google Authenticator / 1Password / Authy 등)에 표시된 6자리 코드를 입력하세요.';

  @override
  String get twofaRecoveryHint => '2단계 인증을 활성화할 때 저장한 복구 코드를 입력하세요 (예: abcd-efgh). 각 코드는 한 번만 사용할 수 있습니다.';

  @override
  String get twofaTotpInputPlaceholder => '6자리 코드';

  @override
  String get twofaRecoveryInputPlaceholder => '복구 코드';

  @override
  String twofaCountdown(String time) {
    return '남은 시간 $time';
  }

  @override
  String get twofaVerifyButton => '확인';

  @override
  String get twofaStatusTitle => '2단계 인증';

  @override
  String get twofaStatusEnabled => '활성화됨 ✓';

  @override
  String get twofaStatusDisabled => '비활성화됨';

  @override
  String twofaStatusEnabledAt(String date) {
    return '$date에 활성화됨';
  }

  @override
  String get twofaStatusManageHint => '웹 앱에서 관리하세요 (활성화 / 비활성화 / 복구 코드 재생성)';

  @override
  String get twofaStatusOpenWeb => '웹 앱에서 활성화하기 →';

  @override
  String get sharedRoleOwner => '소유자';

  @override
  String get sharedRoleEditor => '편집자';

  @override
  String get sharedRoleViewer => '뷰어';

  @override
  String get commonCopied => '복사됨';

  @override
  String get commonRemove => '제거';

  @override
  String get sharedJoinPageTitle => '공유 가계부 참여';

  @override
  String get sharedJoinPageSubtitle => '초대 코드를 입력하거나 공유 링크를 누르세요';

  @override
  String get sharedJoinEnterCode => '초대 코드 입력';

  @override
  String get sharedJoinEnterCodeHint => '대문자와 숫자 6자리입니다. 공유 링크를 누르면 이 단계를 건너뛸 수 있습니다.';

  @override
  String get sharedJoinPreviewButton => '코드 확인';

  @override
  String get sharedJoinAcceptButton => '참여하기';

  @override
  String sharedJoinInvitedBy(String name) {
    return '$name님이 초대했습니다';
  }

  @override
  String sharedJoinRoleLine(String role) {
    return '역할: $role';
  }

  @override
  String sharedJoinExpiresInMinutes(int n) {
    return '$n분 후 만료';
  }

  @override
  String sharedJoinExpiresInHours(int n) {
    return '$n시간 후 만료';
  }

  @override
  String sharedJoinExpiresInDays(int n) {
    return '$n일 후 만료';
  }

  @override
  String sharedJoinSuccess(String name) {
    return '\"$name\"에 참여했습니다';
  }

  @override
  String get sharedJoinCodeFormatError => '초대 코드는 6자리 문자/숫자여야 합니다.';

  @override
  String get sharedJoinInvalidOrExpired => '초대 코드가 유효하지 않거나 만료되었습니다. 초대한 사람에게 새 코드를 요청하세요.';

  @override
  String get sharedJoinAlreadyMember => '이미 이 가계부의 멤버입니다.';

  @override
  String get sharedJoinMemberLimit => '이 가계부의 멤버 수 한도에 도달했습니다. 소유자에게 문의하세요.';

  @override
  String get sharedInvitePageTitle => '새 멤버 초대';

  @override
  String get sharedInviteFormRole => '역할';

  @override
  String get sharedInviteFormExpiry => '유효 기간';

  @override
  String sharedInviteExpiryHours(int n) {
    return '$n시간';
  }

  @override
  String sharedInviteExpiryDays(int n) {
    return '$n일';
  }

  @override
  String get sharedInviteGenerate => '초대 코드 생성';

  @override
  String get sharedInviteGenerateAnother => '다른 코드 생성';

  @override
  String get sharedInviteCopyCode => '코드 복사';

  @override
  String get sharedInviteCopyLink => '링크 복사';

  @override
  String get sharedInviteShareLink => '링크 공유';

  @override
  String sharedInviteExpiresAt(String dt) {
    return '$dt에 만료';
  }

  @override
  String get sharedInviteWarning => '⚠️ 초대 코드를 공개 그룹이나 SNS에 게시하지 마세요. 코드를 가진 사람은 누구나 참여할 수 있습니다. 유출되었다면 멤버 화면에서 취소하고 다시 생성하세요.';

  @override
  String get sharedInviteInstruction => '코드나 짧은 링크를 상대방에게 전달하세요. BeeCount를 설치한 후 링크를 누르거나 \"내 정보 → 공유 가계부 참여\"에서 코드를 입력하면 됩니다.';

  @override
  String sharedInviteShareText(String ledger, String code, String url) {
    return 'BeeCount 공유 가계부 \"$ledger\"에 초대합니다.\n\n코드: $code\n링크: $url\n\n링크를 누르거나 BeeCount → 내 정보 → 공유 가계부 참여에서 이 코드를 입력하세요.';
  }

  @override
  String get sharedMembersPageTitle => '멤버';

  @override
  String get sharedMembersYou => '나';

  @override
  String get sharedMembersInviteCta => '새 멤버 초대';

  @override
  String get sharedMembersLeaveCta => '가계부 나가기';

  @override
  String get sharedMembersLeaveTitle => '가계부 나가기';

  @override
  String sharedMembersLeaveConfirm(String name) {
    return '\"$name\"에서 나가면 해당 거래에 접근할 수 없습니다. 계속하시겠습니까?';
  }

  @override
  String get sharedMembersLeaveDone => '가계부에서 나갔습니다';

  @override
  String get sharedMembersRemoveTitle => '멤버 제거';

  @override
  String get sharedMembersRemoveCta => '이 멤버 제거';

  @override
  String sharedMembersRemoveConfirm(String name) {
    return '$name님을 제거하시겠습니까? 즉시 이 가계부에 대한 접근 권한을 잃게 됩니다.';
  }

  @override
  String get sharedMembersRemoved => '멤버가 제거되었습니다';

  @override
  String get sharedMembersTransferTitle => '소유권 이전';

  @override
  String get sharedMembersTransferTo => '이 멤버에게 이전';

  @override
  String sharedMembersTransferConfirm(String name) {
    return '$name님에게 소유권을 이전하시겠습니까? 이전 후에는 편집자가 되며 더 이상 초대, 이름 변경, 가계부 삭제를 할 수 없습니다.';
  }

  @override
  String get sharedMembersTransferConfirmCta => '이전';

  @override
  String get sharedMembersTransferDone => '소유권이 이전되었습니다';

  @override
  String sharedTxRecordedBy(String name) {
    return '$name님이 기록함';
  }

  @override
  String sharedTxCreatedBy(String name) {
    return '$name님이 생성함';
  }

  @override
  String sharedTxEditedBy(String name) {
    return '$name님이 마지막으로 편집함';
  }

  @override
  String sharedTxCreatedAndEditedBy(String name) {
    return '$name님이 생성 및 편집함';
  }

  @override
  String get sharedRequiresCloudSync => '먼저 클라우드 동기화를 활성화해 주세요';

  @override
  String get sharedMembersStatsTitle => '멤버별 잔액';

  @override
  String get sharedMembersStatsEmpty => '아직 거래가 없습니다';

  @override
  String get sharedMembersStatsLoading => '불러오는 중…';

  @override
  String get sharedMembersStatsIncome => '수입';

  @override
  String get sharedMembersStatsExpense => '지출';

  @override
  String sharedMembersStatsTxCount(int count) {
    return '거래 $count건';
  }

  @override
  String get maintenanceOrphanCleanupTitle => '데이터 정리';

  @override
  String get maintenanceOrphanCleanupSubtitle => '로컬의 고아 데이터를 감지하고 정리합니다';

  @override
  String get maintenanceOrphanRescan => '다시 검사';

  @override
  String get maintenanceOrphanEmpty => '로컬 데이터가 깨끗합니다. 고아 데이터가 없습니다';

  @override
  String get maintenanceOrphanGroupDb => '데이터베이스 고아 데이터';

  @override
  String get maintenanceOrphanGroupFile => '파일 고아 데이터';

  @override
  String get maintenanceOrphanGroupSync => '동기화 상태 고아 데이터';

  @override
  String maintenanceOrphanSummary(int count) {
    return '$count건의 문제를 발견했습니다';
  }

  @override
  String maintenanceOrphanSummarySize(String size) {
    return '회수 가능한 공간 ~ $size';
  }

  @override
  String get maintenanceOrphanSelectAll => '전체 선택';

  @override
  String get maintenanceOrphanDeselectAll => '전체 선택 해제';

  @override
  String get maintenanceOrphanDeleteOne => '이것만 삭제';

  @override
  String maintenanceOrphanSelectedHint(int count) {
    return '$count개 선택됨';
  }

  @override
  String get maintenanceOrphanCleanSelected => '선택 항목 정리';

  @override
  String get maintenanceOrphanConfirmTitle => '정리 확인';

  @override
  String maintenanceOrphanConfirmDeleteOne(String title) {
    return '\"$title\"을(를) 삭제하시겠습니까? 되돌릴 수 없습니다.';
  }

  @override
  String maintenanceOrphanConfirmDeleteBatch(int count) {
    return '선택한 $count개 항목을 삭제하시겠습니까? 되돌릴 수 없습니다.';
  }

  @override
  String maintenanceOrphanCleanSuccess(int count) {
    return '$count개 항목을 정리했습니다';
  }

  @override
  String maintenanceOrphanCleanPartial(int ok, int fail) {
    return '$ok개 정리 완료, $fail개 실패';
  }

  @override
  String get syncProgressTitle => '동기화 중';

  @override
  String syncProgressCount(int applied, int total) {
    return '$applied / $total';
  }

  @override
  String get exchangeRatePageTitle => '환율';

  @override
  String get exchangeRateEntrySubtitle => '자동으로 가져온 환율을 직접 수정할 수 있습니다';

  @override
  String get baseCurrencyLabel => '기준 통화';

  @override
  String get rateSourceAuto => '자동';

  @override
  String get rateSourceManual => '수동';

  @override
  String rateUpdatedAt(String date) {
    return '$date 업데이트됨';
  }

  @override
  String get rateNotFetched => '가져오지 않음';

  @override
  String get rateTapToSet => '눌러서 직접 설정';

  @override
  String get rateEditTitle => '환율 편집';

  @override
  String rateInverseHint(String base, String rate, String quote) {
    return '역환율: 1 $base ≈ $rate $quote';
  }

  @override
  String get rateResetToAuto => '자동으로 재설정';

  @override
  String get rateRefreshSuccess => '환율이 업데이트되었습니다';

  @override
  String get rateRefreshFailed => '가져오기에 실패했습니다. 직접 환율을 설정할 수 있습니다';

  @override
  String get ratesEmptyHint => '계정에서 서로 다른 통화를 사용하면 여기에 환율이 표시됩니다';

  @override
  String get rateDisclaimer => '출처: 공개 환율 데이터, 매일 업데이트됩니다. 환산은 참고용이며 은행 환율과 다를 수 있습니다.';

  @override
  String convertedNetWorth(String currency) {
    return '순자산 ($currency 기준)';
  }

  @override
  String convertedFootnote(String date) {
    return '$date 환율로 환산됨, 눌러서 관리하세요';
  }

  @override
  String convertedPartialWarning(String currencies) {
    return '$currencies은(는) 환산되지 않았습니다. 눌러서 환율을 설정하세요';
  }

  @override
  String get unconvertedBadge => '환산 안 됨';

  @override
  String get commonDetail => '상세';

  @override
  String get conversionDetailTitle => '환산 상세';

  @override
  String get assetConversionToggle => '기준 통화로 환산';

  @override
  String rateManualApplied(int count) {
    return '수동 환율 $count건을 적용했습니다';
  }

  @override
  String get netWorthTrendTitle => '순자산 추이';

  @override
  String get netWorthTrend3M => '3개월';

  @override
  String get netWorthTrend6M => '6개월';

  @override
  String get netWorthTrend12M => '12개월';

  @override
  String get netWorthTrendAll => '전체';

  @override
  String get netWorthTrendLineNet => '순자산';

  @override
  String get netWorthTrendLineAssets => '총 자산';

  @override
  String get netWorthTrendLineLiabilities => '총 부채';

  @override
  String get netWorthTrendMultiCurrencyNote => '과거 순자산은 통화별 원 금액의 합계이며 환산되지 않았습니다';

  @override
  String get txFlagExcludeFromStats => '수입/지출 통계에서 제외';

  @override
  String get txFlagExcludeFromBudget => '예산에서 제외';

  @override
  String get txFlagMoreOptions => '더 많은 옵션';

  @override
  String get txFlagDialogTitle => '거래 플래그';

  @override
  String get txFlagExcludeFromStatsHint => '통계에서는 제외되지만 잔액에는 계속 반영됩니다';

  @override
  String get txFlagExcludeFromBudgetHint => '예산에는 반영되지 않습니다';

  @override
  String get txFlagExcludedTag => '제외됨';

  @override
  String get txFlagBudgetExcludedTag => '예산 제외';

  @override
  String get txCurrencyLabel => 'Currency';

  @override
  String get txRateLabel => 'Rate';

  @override
  String txConvertedPreview(Object amount, Object currency) {
    return '≈ $amount $currency';
  }

  @override
  String get txRateMissingHint => 'Please enter the rate for this entry before saving';

  @override
  String get txCrossCurrencyTransferBlocked => 'Cross-currency transfers are not supported yet. Record two entries or use same-currency accounts.';

  @override
  String get ledgerBaseCurrencyLabel => 'Primary currency';

  @override
  String statsConvertedFootnote(Object currency) {
    return 'Includes foreign currency, converted to $currency at entry-time rates';
  }

  @override
  String get ledgerCurrencyChangeRecalcHint => 'Changing the base currency will reconvert all history at current rates';

  @override
  String get recalcForeignTxBanner => 'Unconverted foreign-currency transactions detected in this ledger';

  @override
  String get recalcForeignTxAction => 'Reconvert at current rates';

  @override
  String recalcForeignTxDone(Object count) {
    return 'Reconverted $count foreign-currency transactions';
  }

  @override
  String get txCurrencyPickerTitle => 'Select currency';

  @override
  String recalcSyncCountHint(Object count) {
    return '$count transactions will be reconverted and synced';
  }

  @override
  String get exportCsvHeaderCurrency => 'Currency';

  @override
  String get importFieldCurrency => 'Currency';

  @override
  String get currencyMOP => 'Macau Pataca';

  @override
  String get currencyMNT => 'Mongolian Tughrik';

  @override
  String get currencyKPW => 'North Korean Won';

  @override
  String get currencyKHR => 'Cambodian Riel';

  @override
  String get currencyLAK => 'Lao Kip';

  @override
  String get currencyBND => 'Bruneian Dollar';

  @override
  String get currencyNPR => 'Nepalese Rupee';

  @override
  String get currencyBTN => 'Bhutanese Ngultrum';

  @override
  String get currencyMVR => 'Maldivian Rufiyaa';

  @override
  String get currencyAFN => 'Afghan Afghani';

  @override
  String get currencyUZS => 'Uzbekistani Som';

  @override
  String get currencyTJS => 'Tajikistani Somoni';

  @override
  String get currencyTMT => 'Turkmenistani Manat';

  @override
  String get currencyKGS => 'Kyrgyzstani Som';

  @override
  String get currencyQAR => 'Qatari Riyal';

  @override
  String get currencyKWD => 'Kuwaiti Dinar';

  @override
  String get currencyBHD => 'Bahraini Dinar';

  @override
  String get currencyOMR => 'Omani Rial';

  @override
  String get currencyJOD => 'Jordanian Dinar';

  @override
  String get currencyLBP => 'Lebanese Pound';

  @override
  String get currencyIQD => 'Iraqi Dinar';

  @override
  String get currencyIRR => 'Iranian Rial';

  @override
  String get currencyYER => 'Yemeni Rial';

  @override
  String get currencySYP => 'Syrian Pound';

  @override
  String get currencyGEL => 'Georgian Lari';

  @override
  String get currencyAMD => 'Armenian Dram';

  @override
  String get currencyAZN => 'Azerbaijan Manat';

  @override
  String get currencyRON => 'Romanian Leu';

  @override
  String get currencyBGN => 'Bulgarian Lev';

  @override
  String get currencyRSD => 'Serbian Dinar';

  @override
  String get currencyISK => 'Icelandic Krona';

  @override
  String get currencyMDL => 'Moldovan Leu';

  @override
  String get currencyALL => 'Albanian Lek';

  @override
  String get currencyMKD => 'Macedonian Denar';

  @override
  String get currencyBAM => 'Bosnian Convertible Mark';

  @override
  String get currencyGIP => 'Gibraltar Pound';

  @override
  String get currencyGTQ => 'Guatemalan Quetzal';

  @override
  String get currencyHNL => 'Honduran Lempira';

  @override
  String get currencyNIO => 'Nicaraguan Cordoba';

  @override
  String get currencyCRC => 'Costa Rican Colon';

  @override
  String get currencyPAB => 'Panamanian Balboa';

  @override
  String get currencyDOP => 'Dominican Peso';

  @override
  String get currencyCUP => 'Cuban Peso';

  @override
  String get currencyJMD => 'Jamaican Dollar';

  @override
  String get currencyTTD => 'Trinidadian Dollar';

  @override
  String get currencyBSD => 'Bahamian Dollar';

  @override
  String get currencyBBD => 'Barbadian or Bajan Dollar';

  @override
  String get currencyBZD => 'Belizean Dollar';

  @override
  String get currencyHTG => 'Haitian Gourde';

  @override
  String get currencyXCD => 'East Caribbean Dollar';

  @override
  String get currencyKYD => 'Caymanian Dollar';

  @override
  String get currencyAWG => 'Aruban or Dutch Guilder';

  @override
  String get currencyANG => 'Dutch Guilder';

  @override
  String get currencyBMD => 'Bermudian Dollar';

  @override
  String get currencyUYU => 'Uruguayan Peso';

  @override
  String get currencyPYG => 'Paraguayan Guarani';

  @override
  String get currencyBOB => 'Bolivian Bolíviano';

  @override
  String get currencyVES => 'Venezuelan Bolívar';

  @override
  String get currencyGYD => 'Guyanese Dollar';

  @override
  String get currencySRD => 'Surinamese Dollar';

  @override
  String get currencyFJD => 'Fijian Dollar';

  @override
  String get currencyPGK => 'Papua New Guinean Kina';

  @override
  String get currencySBD => 'Solomon Islander Dollar';

  @override
  String get currencyTOP => 'Tongan Pa\'anga';

  @override
  String get currencyVUV => 'Ni-Vanuatu Vatu';

  @override
  String get currencyWST => 'Samoan Tala';

  @override
  String get currencyXPF => 'CFP Franc';

  @override
  String get currencyKES => 'Kenyan Shilling';

  @override
  String get currencyGHS => 'Ghanaian Cedi';

  @override
  String get currencyMAD => 'Moroccan Dirham';

  @override
  String get currencyDZD => 'Algerian Dinar';

  @override
  String get currencyTND => 'Tunisian Dinar';

  @override
  String get currencyLYD => 'Libyan Dinar';

  @override
  String get currencyETB => 'Ethiopian Birr';

  @override
  String get currencyUGX => 'Ugandan Shilling';

  @override
  String get currencyTZS => 'Tanzanian Shilling';

  @override
  String get currencyRWF => 'Rwandan Franc';

  @override
  String get currencyXAF => 'Central African CFA Franc';

  @override
  String get currencyXOF => 'West African CFA Franc';

  @override
  String get currencyMUR => 'Mauritian Rupee';

  @override
  String get currencyBWP => 'Botswana Pula';

  @override
  String get currencyNAD => 'Namibian Dollar';

  @override
  String get currencyZMW => 'Zambian Kwacha';

  @override
  String get currencyMWK => 'Malawian Kwacha';

  @override
  String get currencyMZN => 'Mozambican Metical';

  @override
  String get currencyAOA => 'Angolan Kwanza';

  @override
  String get currencyCDF => 'Congolese Franc';

  @override
  String get currencyGMD => 'Gambian Dalasi';

  @override
  String get currencyGNF => 'Guinean Franc';

  @override
  String get currencyLRD => 'Liberian Dollar';

  @override
  String get currencySLE => 'Sierra Leonean Leone';

  @override
  String get currencySDG => 'Sudanese Pound';

  @override
  String get currencySSP => 'South Sudanese Pound';

  @override
  String get currencySOS => 'Somali Shilling';

  @override
  String get currencyDJF => 'Djiboutian Franc';

  @override
  String get currencyERN => 'Eritrean Nakfa';

  @override
  String get currencyBIF => 'Burundian Franc';

  @override
  String get currencyCVE => 'Cape Verdean Escudo';

  @override
  String get currencySTN => 'Sao Tomean Dobra';

  @override
  String get currencySCR => 'Seychellois Rupee';

  @override
  String get currencyKMF => 'Comorian Franc';

  @override
  String get currencyLSL => 'Basotho Loti';

  @override
  String get currencySZL => 'Swazi Lilangeni';

  @override
  String get currencyMGA => 'Malagasy Ariary';

  @override
  String get currencyMRU => 'Mauritanian Ouguiya';
}
