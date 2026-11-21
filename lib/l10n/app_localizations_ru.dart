import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get agentActivityPreparing => 'Готовим ответ…';

  @override
  String get agentActivityAwaitingModel => 'Ожидаем ответа модели…';

  @override
  String get agentActivityThinking => 'Модель обдумывает запрос…';

  @override
  String get agentActivityGenerating => 'Формулируем ответ…';

  @override
  String agentExecutionCompletedSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Выполнено $count операции',
      many: 'Выполнено $count операций',
      few: 'Выполнены $count операции',
      one: 'Выполнена $count операция',
    );
    return '$_temp0';
  }

  @override
  String get agentExecutionFailedSummary => 'Не все операции завершены';

  @override
  String get agentActivityUnknownTool => 'Локальная операция';

  @override
  String get agentActivityOverview => 'Обзор доходов и расходов';

  @override
  String get agentActivityTrend => 'Динамика расходов';

  @override
  String get agentActivityCategories => 'Категории расходов';

  @override
  String get agentActivityLeafCategories => 'Подробно по категориям';

  @override
  String agentActivityCategoryScope(String categories) {
    return 'Категории: $categories';
  }

  @override
  String agentActivityReturnedRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Получено $count транзакции',
      many: 'Получено $count транзакций',
      few: 'Получены $count транзакции',
      one: 'Получена $count транзакция',
    );
    return '$_temp0';
  }

  @override
  String agentActivityReturnedGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Получено $count группы',
      many: 'Получено $count групп',
      few: 'Получены $count группы',
      one: 'Получена $count группа',
    );
    return '$_temp0';
  }

  @override
  String get agentActivityTruncated => 'Получена только часть результатов';

  @override
  String get agentFollowUpRotate => 'Сменить варианты';

  @override
  String get agentScrollToLatest => 'К последнему сообщению';

  @override
  String get agentSuggestionHealthTitle => 'Финансовое здоровье';

  @override
  String get agentSuggestionHealthPrompt => 'Проанализируй доходы, расходы, разницу между ними и долю сбережений за этот месяц. Покажи расходы по месяцам за последние полгода. По результатам запросов оцени финансовое состояние и предложи рекомендации. Если данных недостаточно, объясни ограничения.';

  @override
  String get agentSuggestionSummaryTitle => 'Расходы за месяц';

  @override
  String get agentSuggestionSummaryPrompt => 'Подведи итоги расходов за этот месяц, разбери основные категории верхнего уровня и их доли. Предложи способы сэкономить. Опирайся на фактические результаты запросов и укажи, если каких-то данных не хватает.';

  @override
  String get agentSuggestionAnalysisTitle => 'Анализ категорий';

  @override
  String get agentSuggestionAnalysisPrompt => 'Проанализируй расходы за этот месяц по категориям верхнего уровня и их доли. Предложи, что можно улучшить. Не считай расходы необоснованными только из-за их доли. Если данных не хватает, объясни ограничения.';

  @override
  String get agentSuggestionBudgetTitle => 'Планирование бюджета';

  @override
  String get agentSuggestionBudgetPrompt => 'С учётом доходов, расходов и разницы между ними за этот месяц, долей расходов по категориям верхнего уровня и динамики расходов за последние полгода предложи бюджеты по категориям на следующий месяц. Дай только рекомендации: не создавай и не меняй бюджеты. Если данных не хватает, объясни ограничения.';

  @override
  String get agentSuggestionAnomalyTitle => 'Проверка расходов';

  @override
  String get agentSuggestionAnomalyPrompt => 'Изучи подробности транзакций и сводку доходов и расходов за последние 30 дней. Отметь крупные или повторные транзакции, которые стоит проверить, и объясни почему. Это предварительная проверка только тех транзакций, которые вернул запрос, а не поиск аномалий по всем транзакциям. Не называй обычные покупки аномальными.';

  @override
  String get agentSuggestionSavingTitle => 'Советы по экономии';

  @override
  String get agentSuggestionSavingPrompt => 'Проанализируй доли расходов за этот месяц по категориям верхнего уровня и динамику расходов за последние полгода. Дай от трёх до пяти практических советов по экономии на основе результатов запросов. Не делай предположений о личных обстоятельствах. Если данных не хватает, объясни ограничения.';

  @override
  String get agentFollowUpTitle => 'Узнать больше';

  @override
  String agentFollowUpRange(String start, String end) {
    return 'С $start до $end (не включая конец периода)';
  }

  @override
  String get agentFollowUpAllCategories => 'все категории расходов';

  @override
  String get agentFollowUpCategoryTitle => 'Посмотреть доли расходов';

  @override
  String agentFollowUpCategoryPrompt(String range) {
    return 'Покажи доли расходов по категориям верхнего уровня за период: $range.';
  }

  @override
  String get agentFollowUpTrendTitle => 'Посмотреть динамику';

  @override
  String agentFollowUpTrendPrompt(String category, String range) {
    return 'Покажи расходы по месяцам. Категории: $category. Период: $range. Не сравнивай расходы с предыдущим месяцем или с тем же месяцем прошлого года.';
  }

  @override
  String get agentFollowUpCompareTitle => 'Сравнить соседние месяцы';

  @override
  String agentFollowUpComparePrompt(String category, String range) {
    return 'Покажи расходы по месяцам и изменение относительно предыдущего месяца. Категории: $category. Период: $range.';
  }

  @override
  String agentFollowUpLeafTitle(String category) {
    return 'Разобрать «$category»';
  }

  @override
  String agentFollowUpLeafPrompt(String category, String range) {
    return 'Покажи доли расходов по подкатегориям категории «$category» за период: $range.';
  }

  @override
  String get agentFollowUpOverviewTitle => 'Посмотреть доходы и расходы';

  @override
  String agentFollowUpOverviewPrompt(String range) {
    return 'Покажи общую сумму доходов, общую сумму расходов и разницу между ними за период: $range.';
  }

  @override
  String get aiConsentTitle => 'Перед включением функций ИИ';

  @override
  String get aiConsentBody => 'Для работы функций ИИ данные отправляются стороннему поставщику ИИ, выбранному в настройках:\n\n• Кому: по умолчанию — Zhipu GLM (open.bigmodel.cn, оператор — Zhipu). Если вы настроили другой сервис ИИ, данные отправляются выбранному вами поставщику.\n• Какие данные: изображения чеков, аудиозаписи и текст, которые вы используете для распознавания или чата, а также названия категорий и счетов и соответствующие транзакции, необходимые для распознавания или анализа.\n• Зачем: только для распознавания транзакций, ведения учёта и чатов, которые вы начинаете. BeeCount не собирает и не хранит эти данные.\n\nСторонний поставщик обрабатывает данные согласно своей политике конфиденциальности. Включая функции ИИ, вы соглашаетесь на передачу данных на этих условиях.';

  @override
  String get aiConsentAgree => 'Согласиться и включить';

  @override
  String get aboutPrivacyPolicy => 'Политика конфиденциальности';

  @override
  String get aboutChangelog => 'Список изменений';

  @override
  String get appTitle => 'BeeCount';

  @override
  String get tabHome => 'Главная';

  @override
  String get tabInsights => 'Анализ';

  @override
  String get tabAssets => 'Активы';

  @override
  String get tabRecord => 'Добавить';

  @override
  String get tabMine => 'Профиль';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonConfirm => 'Подтвердить';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonAdd => 'Добавить';

  @override
  String get commonEdit => 'Изменить';

  @override
  String get commonMore => 'Ещё';

  @override
  String get commonOk => 'ОК';

  @override
  String get commonKnow => 'Понятно';

  @override
  String get commonNo => 'Нет';

  @override
  String get commonEmpty => 'Нет данных';

  @override
  String get commonError => 'Ошибка';

  @override
  String get commonSuccess => 'Успешно';

  @override
  String get commonFailed => 'Не удалось';

  @override
  String get commonBack => 'Назад';

  @override
  String get commonNext => 'Далее';

  @override
  String get fabActionCamera => 'Камера';

  @override
  String get fabActionGallery => 'Галерея';

  @override
  String get fabActionVoice => 'Голос';

  @override
  String get fabActionVoiceDisabled => 'Нужно включить ИИ и указать ключ API';

  @override
  String get voiceRecordingTitle => 'Голосовой ввод';

  @override
  String get voiceRecordingPreparing => 'Подготовка...';

  @override
  String get voiceRecordingInProgress => 'Идёт запись...';

  @override
  String get voiceRecordingProcessing => 'Распознавание...';

  @override
  String voiceRecordingDuration(int duration) {
    return 'Длительность: $duration с';
  }

  @override
  String get voiceRecordingSuccess => 'Транзакция добавлена голосом';

  @override
  String get voiceMicPermissionRestricted => 'Политика управления устройством ограничивает доступ к микрофону';

  @override
  String get voiceRecordingNoLedger => 'Ведомость не найдена';

  @override
  String get voiceRecordingNoInfo => 'Не удалось распознать данные транзакции';

  @override
  String get voiceRecordingPermissionDenied => 'Для записи нужен доступ к микрофону';

  @override
  String get voiceRecordingPermissionDeniedTitle => 'Нужен доступ к микрофону';

  @override
  String get voiceRecordingPermissionDeniedMessage => 'Для голосового ввода нужен микрофон. Разрешите BeeCount доступ к микрофону в настройках системы.';

  @override
  String voiceRecordingStartFailed(String error) {
    return 'Не удалось начать запись: $error';
  }

  @override
  String voiceRecordingFailed(String error) {
    return 'Ошибка записи: $error';
  }

  @override
  String voiceRecordingRecognizeFailed(String error) {
    return 'Ошибка распознавания: $error';
  }

  @override
  String voiceRecordingNoInfoDetected(String text) {
    return 'Не удалось распознать данные транзакции: $text';
  }

  @override
  String get voiceRecordingNoSpeech => 'Речь не обнаружена';

  @override
  String get voiceRecordingHoldToTalk => 'Удерживайте и говорите';

  @override
  String get voiceRecordingReleaseToFinish => 'Отпустите, чтобы завершить запись';

  @override
  String get voiceRecordingTooShort => 'Запись слишком короткая';

  @override
  String get voiceRecordingResultLabel => 'Результат распознавания:';

  @override
  String get voiceRecordingAutoHintSpoken => 'Закончив говорить, сделайте паузу для распознавания';

  @override
  String get voiceRecordingAutoHintWaiting => 'Начните говорить...';

  @override
  String get smartBillingVoiceTrigger => 'Режим голосового ввода';

  @override
  String get voiceTriggerModeAuto => 'Завершение по паузе';

  @override
  String get voiceTriggerModeAutoDesc => 'Запись завершается после паузы — удобно для коротких фраз';

  @override
  String get voiceTriggerModeHold => 'Удерживать для записи';

  @override
  String get voiceTriggerModeHoldDesc => 'Удерживайте кнопку для записи и отпустите, чтобы завершить — удобно для длинных фраз';

  @override
  String get smartBillingVoiceSilenceTimeout => 'Длительность паузы';

  @override
  String smartBillingVoiceSilenceTimeoutValue(String seconds) {
    return 'Автозавершение после паузы в $seconds с';
  }

  @override
  String get commonPrevious => 'Назад';

  @override
  String get commonFinish => 'Завершить';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get commonOther => 'Другое';

  @override
  String get commonYesterday => 'Вчера';

  @override
  String get commonSearch => 'Поиск';

  @override
  String get commonNoteHint => 'Заметка...';

  @override
  String get commonSettings => 'Настройки';

  @override
  String get commonGoSettings => 'Открыть настройки';

  @override
  String get commonLanguage => 'Язык';

  @override
  String get commonCurrent => 'Сейчас';

  @override
  String get commonTutorial => 'Руководство';

  @override
  String get commonConfigure => 'Настроить';

  @override
  String get commonPressAgainToExit => 'Нажмите ещё раз, чтобы выйти';

  @override
  String get commonWeekdayMonday => 'Понедельник';

  @override
  String get commonWeekdayTuesday => 'Вторник';

  @override
  String get commonWeekdayWednesday => 'Среда';

  @override
  String get commonWeekdayThursday => 'Четверг';

  @override
  String get commonWeekdayFriday => 'Пятница';

  @override
  String get commonWeekdaySaturday => 'Суббота';

  @override
  String get commonWeekdaySunday => 'Воскресенье';

  @override
  String get homeIncome => 'Доход';

  @override
  String get homeExpense => 'Расход';

  @override
  String get homeBalance => 'Баланс';

  @override
  String get homeNoRecords => 'Транзакций пока нет';

  @override
  String get homeSelectDate => 'Выбрать дату';

  @override
  String get homeAppTitle => 'BeeCount';

  @override
  String get homeSearch => 'Поиск';

  @override
  String homeYear(int year) {
    return '$year';
  }

  @override
  String homeMonth(String month) {
    return '$month мес.';
  }

  @override
  String get homeNoRecordsSubtext => 'Нажмите на плюс внизу, чтобы добавить транзакцию';

  @override
  String get homeLastMonthReportSubtitle => 'Посмотрите отчёт о расходах за прошлый месяц и поделитесь им';

  @override
  String get homeLastMonthReportView => 'Посмотреть';

  @override
  String homeAnnualReportReminder(int year) {
    return 'Годовой отчёт за $year готов';
  }

  @override
  String get homeAnnualReportView => 'Посмотреть';

  @override
  String get widgetTodayExpense => 'Расходы сегодня';

  @override
  String get widgetConsumptionRhythmTitle => 'Темп расходов';

  @override
  String get widgetConsumptionRhythmRange => 'Последние 30 дней';

  @override
  String get widgetConsumptionRhythmStable => 'Расходы равномерны';

  @override
  String get widgetConsumptionRhythmIncrease => 'Быстрее, чем на прошлой неделе';

  @override
  String get widgetConsumptionRhythmDecrease => 'Равномернее, чем на прошлой неделе';

  @override
  String get widgetConsumptionRhythmEmpty => 'За последние 30 дней расходов не было';

  @override
  String get widgetBeeTrailTitle => 'Серия дней учёта';

  @override
  String get widgetBeeTrailStreakSuffix => 'дн.';

  @override
  String get widgetBeeTrailCompletion => 'Регулярность учёта за 28 дней';

  @override
  String get widgetBeeTrailEmpty => 'Добавьте транзакцию, чтобы зажечь первую ячейку';

  @override
  String get widgetTodayIncome => 'Доходы сегодня';

  @override
  String get widgetMonthExpense => 'Расходы за месяц';

  @override
  String get widgetMonthIncome => 'Доходы за месяц';

  @override
  String get widgetMonthSuffix => '';

  @override
  String get widgetToday => 'Сегодня';

  @override
  String get widgetQuickAddLabel => 'Добавить';

  @override
  String get widgetBudgetTotal => 'Всего';

  @override
  String get widgetBudgetRemaining => 'Остаток';

  @override
  String get widgetNoBudget => 'Бюджет не задан';

  @override
  String get widgetNoTransactions => 'Нет транзакций';

  @override
  String get widgetRecentTransactions => 'Недавние транзакции';

  @override
  String get widgetNoAccounts => 'Нет счетов';

  @override
  String get searchTitle => 'Поиск';

  @override
  String get searchHint => 'Поиск по заметкам, категориям или суммам...';

  @override
  String get searchCategoryHint => 'Поиск по названию категории...';

  @override
  String get searchCategoryFilter => 'Фильтр по категории';

  @override
  String get searchMinAmount => 'Мин. сумма';

  @override
  String get searchMaxAmount => 'Макс. сумма';

  @override
  String get searchNoInput => 'Введите запрос, чтобы начать поиск';

  @override
  String get searchNoResults => 'Ничего не найдено';

  @override
  String get searchBatchMode => 'Групповые действия';

  @override
  String searchBatchModeWithCount(Object selected, Object total) {
    return 'Групповые действия ($selected/$total)';
  }

  @override
  String get searchExitBatchMode => 'Выйти из режима выбора';

  @override
  String get searchSelectAll => 'Выбрать все';

  @override
  String get searchDeselectAll => 'Снять выделение';

  @override
  String searchSelectedCount(Object count) {
    return 'Выбрано: $count';
  }

  @override
  String get searchBatchSetNote => 'Задать заметку';

  @override
  String get searchBatchChangeCategory => 'Изменить категорию';

  @override
  String get searchBatchDeleteConfirmTitle => 'Подтверждение удаления';

  @override
  String searchBatchDeleteConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count выбранной транзакции',
      many: '$count выбранных транзакций',
      few: '$count выбранные транзакции',
      one: '$count выбранную транзакцию',
    );
    return 'Удалить $_temp0?\nЭто действие нельзя отменить.';
  }

  @override
  String get searchBatchSetNoteTitle => 'Общая заметка';

  @override
  String searchBatchSetNoteMessage(Object count) {
    return 'Для выбранных транзакций будет установлена общая заметка. Выбрано: $count';
  }

  @override
  String get searchBatchSetNoteHint => 'Введите заметку (оставьте поле пустым, чтобы удалить заметки)';

  @override
  String searchBatchDeleteSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалено $count транзакции',
      many: 'Удалено $count транзакций',
      few: 'Удалены $count транзакции',
      one: 'Удалена $count транзакция',
    );
    return '$_temp0';
  }

  @override
  String searchBatchDeleteFailed(Object error) {
    return 'Не удалось удалить: $error';
  }

  @override
  String searchBatchSetNoteSuccess(Object count) {
    return 'Заметка сохранена. Обновлено транзакций: $count';
  }

  @override
  String searchBatchSetNoteFailed(Object error) {
    return 'Не удалось сохранить заметку: $error';
  }

  @override
  String searchBatchChangeCategorySuccess(Object count) {
    return 'Категория изменена. Обновлено транзакций: $count';
  }

  @override
  String searchBatchChangeCategoryFailed(Object error) {
    return 'Не удалось изменить категорию: $error';
  }

  @override
  String searchResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count результата',
      many: '$count результатов',
      few: '$count результата',
      one: '$count результат',
    );
    return '$_temp0';
  }

  @override
  String get searchSummaryIncome => 'Всего доходов';

  @override
  String get searchSummaryExpense => 'Всего расходов';

  @override
  String get searchFilterTitle => 'Фильтр';

  @override
  String get searchAmountFilter => 'По сумме';

  @override
  String get searchDateFilter => 'По дате';

  @override
  String get searchStartDate => 'Начальная дата';

  @override
  String get searchEndDate => 'Конечная дата';

  @override
  String get searchNotSet => 'Не задано';

  @override
  String get searchClearFilter => 'Сбросить фильтр';

  @override
  String get searchBatchCategoryTransferError => 'Нельзя изменить категорию: среди выбранных транзакций есть переводы';

  @override
  String get searchBatchCategoryTypeError => 'Выберите транзакции одного типа: только доходы или только расходы';

  @override
  String get searchDateStart => 'Начало';

  @override
  String get searchDateEnd => 'Конец';

  @override
  String get analyticsMonth => 'Месяц';

  @override
  String get analyticsYear => 'Год';

  @override
  String get analyticsAll => 'Всё';

  @override
  String get analyticsCategoryRanking => 'Рейтинг категорий';

  @override
  String get analyticsTotalAmount => 'Всего';

  @override
  String get analyticsNoDataSubtext => 'Листайте влево или вправо, чтобы сменить период, или нажмите кнопку, чтобы переключиться между доходами и расходами';

  @override
  String get analyticsSwipeHint => 'Листайте влево или вправо, чтобы сменить период';

  @override
  String analyticsSwitchTo(String type) {
    return 'Переключиться: $type';
  }

  @override
  String get analyticsTipHeader => 'Подсказка: вверху можно выбрать период «Месяц», «Год» или «Всё»';

  @override
  String get analyticsSwipeToSwitch => 'Листайте для переключения';

  @override
  String get analyticsAllYears => 'Все годы';

  @override
  String get analyticsToday => 'Сегодня';

  @override
  String get splashAppName => 'BeeCount';

  @override
  String get splashSlogan => 'Каждая транзакция на счету';

  @override
  String get splashSecurityTitle => 'Открытый код и защита данных';

  @override
  String get splashSecurityFeature1 => '• Данные хранятся на устройстве, и только вы ими управляете';

  @override
  String get splashSecurityFeature2 => '• Открытый код можно проверить';

  @override
  String get splashSecurityFeature3 => '• При желании данные можно синхронизировать между устройствами';

  @override
  String get splashPreparingRecords => 'Готовим ваши транзакции';

  @override
  String get splashSecuritySummary => 'Локальные данные · Открытый код';

  @override
  String get splashSecurityCaption => 'Синхронизация с облаком — по желанию. Вы сами решаете, где хранить данные.';

  @override
  String get splashSecurityLocalTitle => 'Локальное хранение';

  @override
  String get splashSecurityOpenTitle => 'Открытый код';

  @override
  String get splashSecuritySyncTitle => 'Синхронизация по желанию';

  @override
  String get splashSecurityFootnote => 'Для начала аккаунт не нужен. Синхронизацию с облаком можно включить по желанию.';

  @override
  String get splashInitializing => 'Подготовка данных...';

  @override
  String get ledgersTitle => 'Управление ведомостями';

  @override
  String get ledgersNew => 'Новая ведомость';

  @override
  String get ledgersClear => 'Очистить ведомость';

  @override
  String ledgersClearMessage(Object name) {
    return 'Удалить все транзакции из ведомости «$name»? Это действие нельзя отменить.\\nСама ведомость сохранится, удалятся только транзакции.';
  }

  @override
  String get ledgerDefaultName => 'Основная ведомость';

  @override
  String get ledgersEdit => 'Изменить ведомость';

  @override
  String get ledgersDelete => 'Удалить ведомость';

  @override
  String get ledgersDeleteConfirm => 'Удалить ведомость';

  @override
  String get ledgersDeleteMessage => 'Удалить эту ведомость и все её транзакции? Это действие нельзя отменить.\\nЕсли в облаке есть резервная копия, она тоже будет удалена.';

  @override
  String get ledgersDeleted => 'Удалено';

  @override
  String get ledgersDeleteFailed => 'Не удалось удалить';

  @override
  String get ledgersClearTitle => 'Очистка ведомости';

  @override
  String get ledgersClearSuccess => 'Ведомость очищена';

  @override
  String get ledgersDeleteLocal => 'Удалить только с устройства';

  @override
  String get ledgersDeleteLocalTitle => 'Удаление локальной ведомости';

  @override
  String ledgersDeleteLocalMessage(Object name) {
    return 'Удалить локальную ведомость «$name»?\\nРезервная копия останется в облаке, и вы сможете в любое время восстановить ведомость.';
  }

  @override
  String get ledgersDeleteLocalSuccess => 'Локальная ведомость удалена';

  @override
  String get ledgersName => 'Название';

  @override
  String get ledgersDefaultLedgerName => 'Основная ведомость';

  @override
  String get ledgersCurrency => 'Валюта';

  @override
  String get ledgersMonthStartDay => 'Начало месяца';

  @override
  String get ledgersMonthStartDayHint => 'Для статистики и бюджетов месяц начинается в выбранный день (с 1-го по 28-е)';

  @override
  String get ledgersMonthStartDayNatural => '1-е (календарный месяц)';

  @override
  String ledgersMonthStartDayValue(int day) {
    return '$day-е число каждого месяца';
  }

  @override
  String get ledgersSelectCurrency => 'Выбрать валюту';

  @override
  String get ledgersSearchCurrency => 'Поиск: название на китайском или код';

  @override
  String get ledgersCreate => 'Создать';

  @override
  String get ledgersActions => 'Действия';

  @override
  String ledgersRecords(String count) {
    return 'Транзакций: $count';
  }

  @override
  String ledgersBalance(String balance) {
    return 'Баланс: $balance';
  }

  @override
  String get ledgerCardDownloadCloud => 'Скачать из облака';

  @override
  String get ledgersLocal => 'На устройстве';

  @override
  String get ledgersRemote => 'В облаке';

  @override
  String get ledgersEmpty => 'Нет ведомостей';

  @override
  String get ledgersRestoreAll => 'Восстановить все';

  @override
  String ledgersSwitched(String name) {
    return 'Выбрана ведомость «$name»';
  }

  @override
  String get ledgersDownloadTitle => 'Загрузка ведомости';

  @override
  String ledgersDownloadMessage(String name) {
    return 'Скачать ведомость «$name» на устройство?';
  }

  @override
  String get ledgersDownloading => 'Загрузка...';

  @override
  String ledgersDownloadSuccess(String name) {
    return 'Ведомость «$name» скачана';
  }

  @override
  String get ledgersDownload => 'Скачать';

  @override
  String get ledgersDeleteRemote => 'Удалить из облака';

  @override
  String get ledgersDeleteRemoteConfirm => 'Удалить из облака';

  @override
  String ledgersDeleteRemoteMessage(String name) {
    return 'Удалить ведомость «$name» из облака? Это действие нельзя отменить.';
  }

  @override
  String get ledgersDeleting => 'Удаление...';

  @override
  String get ledgersDeleteRemoteSuccess => 'Ведомость удалена из облака';

  @override
  String get ledgersCannotDeleteLastOne => 'Нельзя удалить последнюю ведомость';

  @override
  String get ledgersRestoreAllTitle => 'Восстановление ведомостей';

  @override
  String ledgersRestoreAllMessage(int count) {
    return 'Восстановить все ведомости из облака? Всего: $count.';
  }

  @override
  String get ledgersRestoring => 'Восстановление...';

  @override
  String get ledgersRestoreComplete => 'Восстановление завершено';

  @override
  String ledgersRestoreResult(int success, int failed) {
    return 'Восстановлено: $success, не удалось: $failed';
  }

  @override
  String get categoryTitle => 'Управление категориями';

  @override
  String get categoryIconGroupBasic => 'Основные';

  @override
  String get categoryIconGroupFoodDining => 'Еда и напитки';

  @override
  String get categoryIconGroupTransportation => 'Транспорт';

  @override
  String get categoryIconGroupShopping => 'Покупки';

  @override
  String get categoryIconGroupHomeLiving => 'Дом и быт';

  @override
  String get categoryIconGroupCommunicationDevices => 'Связь и устройства';

  @override
  String get categoryIconGroupEntertainmentLeisure => 'Развлечения и досуг';

  @override
  String get categoryIconGroupHealthMedical => 'Здоровье и медицина';

  @override
  String get categoryIconGroupEducationLearning => 'Образование';

  @override
  String get categoryIconGroupPetsAnimals => 'Животные';

  @override
  String get categoryIconGroupClothingBeauty => 'Одежда и уход';

  @override
  String get categoryIconGroupOtherMiscellaneous => 'Другое';

  @override
  String get categoryIconGroupWorkCareer => 'Работа и карьера';

  @override
  String get categoryIconGroupFinance => 'Финансы';

  @override
  String get categoryIconGroupRewardsGifts => 'Награды и подарки';

  @override
  String get categoryIconGroupInvestmentReturns => 'Доход от инвестиций';

  @override
  String get categoryIconGroupOtherIncome => 'Прочие доходы';

  @override
  String get categoryGenerateDefault => 'Создать стандартные категории';

  @override
  String get categoryGenerateDefaultFlat => 'Без подкатегорий';

  @override
  String get categoryGenerateDefaultHierarchical => 'С подкатегориями';

  @override
  String get categoryGenerateDefaultHint => 'Существующие категории сохранятся. Стандартные категории с такими же названиями будут пропущены.';

  @override
  String categoryGenerateDefaultSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Создано $count стандартной категории',
      many: 'Создано $count стандартных категорий',
      few: 'Созданы $count стандартные категории',
      one: 'Создана $count стандартная категория',
    );
    return '$_temp0';
  }

  @override
  String get categoryGenerateDefaultNoChanges => 'Стандартные категории уже есть';

  @override
  String get categoryGenerateDefaultFailed => 'Не удалось создать стандартные категории. Попробуйте ещё раз.';

  @override
  String get categoryNew => 'Новая категория';

  @override
  String get categoryExpense => 'Расход';

  @override
  String get categoryIncome => 'Доход';

  @override
  String get categoryEmpty => 'Нет категорий';

  @override
  String get categoryDefault => 'Категория по умолчанию';

  @override
  String get categoryReorderTip => 'Перетащите категорию за значок справа, чтобы изменить порядок';

  @override
  String categoryLoadFailed(String error) {
    return 'Не удалось загрузить: $error';
  }

  @override
  String get iconPickerTitle => 'Выбор значка';

  @override
  String get iconCategoryTransport => 'Транспорт';

  @override
  String get iconCategoryShopping => 'Покупки';

  @override
  String get iconCategoryEntertainment => 'Развлечения';

  @override
  String get iconCategoryLife => 'Повседневное';

  @override
  String get iconCategoryHealth => 'Здоровье';

  @override
  String get iconCategoryEducation => 'Образование';

  @override
  String get iconCategoryWork => 'Работа';

  @override
  String get iconCategoryFinance => 'Финансы';

  @override
  String get iconCategoryReward => 'Награды';

  @override
  String get iconCategoryOther => 'Другое';

  @override
  String get iconCategoryDining => 'Еда и напитки';

  @override
  String get importTitle => 'Импорт транзакций';

  @override
  String get importBillType => 'Источник транзакций';

  @override
  String get importBillTypeGeneric => 'Обычный CSV';

  @override
  String get importBillTypeAlipay => 'Alipay';

  @override
  String get importBillTypeWechat => 'WeChat';

  @override
  String get importChooseFile => 'Выбрать файл';

  @override
  String get importNoFileSelected => 'Файл не выбран';

  @override
  String get importHint => 'Выберите файл для импорта (CSV/TSV/XLSX)';

  @override
  String get importReading => 'Чтение файла…';

  @override
  String get importPreparing => 'Подготовка…';

  @override
  String importColumnNumber(Object number) {
    return 'Столбец $number';
  }

  @override
  String get importConfirmMapping => 'Подтвердить соответствие';

  @override
  String get importCategoryMapping => 'Сопоставление категорий';

  @override
  String get importNoDataParsed => 'Не удалось прочитать данные. Вернитесь на предыдущий экран и проверьте содержимое CSV или разделитель.';

  @override
  String get importFieldDate => 'Дата';

  @override
  String get importFieldType => 'Тип';

  @override
  String get importFieldAmount => 'Сумма';

  @override
  String get importFieldCategory => 'Категория';

  @override
  String get importFieldAccount => 'Счёт';

  @override
  String get importFieldNote => 'Заметка';

  @override
  String get importPreview => 'Предпросмотр';

  @override
  String importPreviewLimit(Object shown, Object total) {
    return 'Предпросмотр строк с начала файла: $shown из $total';
  }

  @override
  String get importCategoryNotSelected => 'Категория не выбрана';

  @override
  String get importCategoryMappingDescription => 'Сопоставьте каждую категорию из файла с категорией в приложении:';

  @override
  String get importKeepOriginalName => 'Сохранить исходное название';

  @override
  String importProgress(Object fail, Object ok) {
    return 'Импорт: успешно — $ok, с ошибками — $fail';
  }

  @override
  String get importCancelImport => 'Отменить импорт';

  @override
  String get importCompleteTitle => 'Импорт завершён';

  @override
  String get importSelectCategoryFirst => 'Сначала выберите столбец «Категория»';

  @override
  String get importNextStep => 'Далее';

  @override
  String get importPreviousStep => 'Назад';

  @override
  String get importStartImport => 'Начать импорт';

  @override
  String get importAutoDetect => 'Определять автоматически';

  @override
  String get importInProgress => 'Идёт импорт';

  @override
  String importProgressDetail(Object done, Object fail, Object ok, Object total) {
    return 'Обработано: $done из $total, успешно — $ok, с ошибками — $fail';
  }

  @override
  String get importBackgroundImport => 'Импорт в фоне';

  @override
  String get importCancelled => ' (отменён)';

  @override
  String importCompleted(Object cancelled, Object fail, Object ok) {
    return 'Импорт завершён$cancelled, успешно — $ok, с ошибками — $fail';
  }

  @override
  String importSkippedNonTransactionTypes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Пропущено $count строки без транзакций',
      many: 'Пропущено $count строк без транзакций',
      few: 'Пропущено $count строки без транзакций',
      one: 'Пропущена $count строка без транзакций',
    );
    return '$_temp0 (долги и т. п.)';
  }

  @override
  String importTransactionFailed(Object error) {
    return 'Не удалось выполнить импорт. Все изменения отменены: $error';
  }

  @override
  String importFileOpenError(String error) {
    return 'Не удалось открыть окно выбора файла: $error';
  }

  @override
  String get mineTitle => 'Профиль';

  @override
  String get mineReminder => 'Настройки напоминаний';

  @override
  String get mineImport => 'Импортировать данные';

  @override
  String get mineExport => 'Экспортировать данные';

  @override
  String get mineCloud => 'Облачный сервис';

  @override
  String get mineUpdate => 'Проверить обновления';

  @override
  String get mineLanguageSettings => 'Язык';

  @override
  String get languageTitle => 'Настройки языка';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystemDefault => 'Как в системе';

  @override
  String get deleteConfirmTitle => 'Подтверждение удаления';

  @override
  String get deleteConfirmMessage => 'Удалить эту транзакцию?';

  @override
  String get mineSlogan => 'BeeCount — каждая копейка на счету';

  @override
  String get mineDisplayNameEditTitle => 'Имя в профиле';

  @override
  String get mineDisplayNameHint => 'Введите имя для профиля';

  @override
  String get mineDisplayNameSaved => 'Имя обновлено';

  @override
  String get mineGreetingMorning => 'Доброе утро';

  @override
  String get mineGreetingNoon => 'Добрый день';

  @override
  String get mineGreetingAfternoon => 'Добрый день';

  @override
  String get mineGreetingEvening => 'Добрый вечер';

  @override
  String get mineGreetingNight => 'Доброй ночи';

  @override
  String mineGreetingNamed(String greeting, String name) {
    return '$greeting, $name';
  }

  @override
  String get mineProfileEditTitle => 'Редактирование профиля';

  @override
  String get headerSkinTitle => 'Скин';

  @override
  String get headerSkinSubtitle => 'Накладывается на шапку и использует цвет темы';

  @override
  String get headerSkinGroupBasic => 'Базовые';

  @override
  String get headerSkinGroupAnniversary => 'Годовщина';

  @override
  String get headerSkinGroupGradient => 'Градиенты';

  @override
  String get headerSkinGroupScene => 'Пейзажи';

  @override
  String get headerSkinGroupPattern => 'Узоры';

  @override
  String get headerSkinGroupGeometric => 'Геометрия';

  @override
  String get headerSkinNone => 'Сплошной цвет';

  @override
  String get headerSkinAnniversary => 'Созвездие первого года';

  @override
  String get headerSkinAnnivCake => 'Торт на годовщину';

  @override
  String get headerSkinTabAll => 'Все';

  @override
  String get headerSkinTabAnimated => 'Анимированные';

  @override
  String get headerSkinTabStatic => 'Статичные';

  @override
  String get headerSkinAnimatedBadge => 'Аним.';

  @override
  String get headerSkinFixedPalette => 'Своя палитра';

  @override
  String personalizeLockedBySkin(String skin) {
    return 'У скина «$skin» своя палитра, поэтому цвет темы изменить нельзя. Чтобы вернуть свой цвет, выберите другой скин.';
  }

  @override
  String get personalizeFixedSkinAction => 'Сменить скин';

  @override
  String get headerSkinAurora => 'Полярное сияние';

  @override
  String get headerSkinMountains => 'Горы';

  @override
  String get headerSkinBokeh => 'Боке';

  @override
  String get headerSkinWaves => 'Волны';

  @override
  String get headerSkinSunset => 'Закат';

  @override
  String get headerSkinClouds => 'Облака';

  @override
  String get headerSkinExample => 'Пример';

  @override
  String get headerSkinHoneycomb => 'Соты';

  @override
  String get headerSkinStarry => 'Звёздное небо';

  @override
  String get headerSkinStripes => 'Косые полосы';

  @override
  String get headerSkinSkyline => 'Панорама города';

  @override
  String get headerSkinSakura => 'Сакура';

  @override
  String get headerSkinMeteor => 'Метеор';

  @override
  String get headerSkinMemphis => 'Мемфис';

  @override
  String get headerSkinSilk => 'Ленты';

  @override
  String get headerSkinBubbles => 'Пузырьки';

  @override
  String get headerSkinGalaxy => 'Галактика';

  @override
  String get headerSkinLowPoly => 'Полигоны';

  @override
  String get headerSkinPrism => 'Призма';

  @override
  String get headerSkinTerrazzo => 'Терраццо';

  @override
  String get mineAvatarTitle => 'Настройки аватара';

  @override
  String get mineAvatarFromGallery => 'Выбрать из галереи';

  @override
  String get mineAvatarFromCamera => 'Сделать фото';

  @override
  String get mineAvatarDelete => 'Удалить аватар';

  @override
  String get annualReportTitle => 'Годовой отчёт';

  @override
  String annualReportSubtitle(int year) {
    return 'Ваши финансы за $year год';
  }

  @override
  String get annualReportEntrySubtitle => 'Создайте годовой отчёт, которым можно поделиться';

  @override
  String annualReportNoData(int year) {
    return 'Нет данных за $year год';
  }

  @override
  String get annualReportPage1Title => 'Обзор года';

  @override
  String annualReportPage1Subtitle(int year) {
    return 'Как вы вели учёт в $year году';
  }

  @override
  String get annualReportTotalDays => 'Дней учёта';

  @override
  String get annualReportTotalRecords => 'Всего транзакций';

  @override
  String get annualReportTotalIncome => 'Всего доходов';

  @override
  String get annualReportTotalExpense => 'Всего расходов';

  @override
  String get annualReportNetSavings => 'Итог за год';

  @override
  String get annualReportPage2Title => 'Анализ расходов';

  @override
  String get annualReportPage2Subtitle => 'На что ушли деньги';

  @override
  String get annualReportPage3Title => 'Динамика по месяцам';

  @override
  String get annualReportPage3Subtitle => 'Доходы и расходы за 12 месяцев';

  @override
  String get annualReportHighestMonth => 'Месяц с наибольшими расходами';

  @override
  String get annualReportLowestMonth => 'Месяц с наименьшими расходами';

  @override
  String get annualReportPage4Title => 'Особые моменты';

  @override
  String get annualReportPage4Subtitle => 'Запоминающиеся транзакции';

  @override
  String get annualReportLargestExpense => 'Самый крупный расход';

  @override
  String get annualReportLargestIncome => 'Самый крупный доход';

  @override
  String get annualReportFirstRecord => 'Первая транзакция';

  @override
  String get annualReportPage5Title => 'Достижения';

  @override
  String get annualReportPage5Subtitle => 'Ваши награды за ведение учёта';

  @override
  String get annualReportAchievementConsistent => 'Постоянство';

  @override
  String annualReportAchievementConsistentDesc(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Учёт вёлся более $days дня подряд',
      many: 'Учёт вёлся более $days дней подряд',
      few: 'Учёт вёлся более $days дней подряд',
      one: 'Учёт вёлся более $days дня подряд',
    );
    return '$_temp0';
  }

  @override
  String get annualReportAchievementSaver => 'Бережливость';

  @override
  String get annualReportAchievementSaverDesc => 'Доходы за год превысили расходы';

  @override
  String get annualReportAchievementDetail => 'Внимание к деталям';

  @override
  String annualReportAchievementDetailDesc(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Добавлено более $count транзакции',
      many: 'Добавлено более $count транзакций',
      few: 'Добавлено более $count транзакций',
      one: 'Добавлено более $count транзакции',
    );
    return '$_temp0';
  }

  @override
  String get annualReportShareButton => 'Создать постер';

  @override
  String get annualReportGenerating => 'Создание годового отчёта...';

  @override
  String get annualReportSaveSuccess => 'Постер годового отчёта сохранён';

  @override
  String get mineShareApp => 'Поделиться приложением';

  @override
  String get mineShareWithFriends => 'Поделиться BeeCount с друзьями';

  @override
  String get mineCopyPromoText => 'Скопировать текст';

  @override
  String get mineCopyPromoSubtitle => 'Скопировать текст и отправить друзьям';

  @override
  String get mineShareGenerating => 'Создание постера...';

  @override
  String get sharePosterAppName => 'BeeCount';

  @override
  String get sharePosterSlogan => 'Умный учёт на каждый день';

  @override
  String get sharePosterFeature1 => 'Защита данных · Вы решаете';

  @override
  String get sharePosterFeature2 => 'Открытый код · Можно проверить';

  @override
  String get sharePosterFeature3 => 'Ввод с ИИ · Фото и голос';

  @override
  String get sharePosterFeature4 => 'Учёт по фото · Автораспознавание';

  @override
  String get sharePosterFeature5 => 'Несколько ведомостей · Тёмная тема';

  @override
  String get sharePosterFeature6 => 'Синхронизация в своём облаке · Бесплатно навсегда';

  @override
  String get sharePosterScanText => 'Отсканируйте код, чтобы открыть страницу проекта';

  @override
  String get appPromoTagOpenSource => 'Открытый код';

  @override
  String get appPromoTagFree => 'Бесплатно';

  @override
  String get appPromoFooterText => 'Каждая транзакция на виду';

  @override
  String userProfileJourneyYears(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years года учёта',
      many: '$years лет учёта',
      few: '$years года учёта',
      one: '$years год учёта',
    );
    return '$_temp0';
  }

  @override
  String get userProfileJourneyOneYear => 'Год учёта';

  @override
  String get userProfileJourneyHalfYear => 'Полгода учёта';

  @override
  String get userProfileJourneyThreeMonths => 'Три месяца учёта';

  @override
  String get userProfileJourneyOneMonth => 'Месяц учёта';

  @override
  String get userProfileJourneyOneWeek => 'Первая неделя учёта';

  @override
  String get userProfileJourneyStart => 'Начало учёта';

  @override
  String get userProfileDailyAverage => 'В среднем за день';

  @override
  String get sharePosterSave => 'Сохранить в галерею';

  @override
  String get sharePosterShare => 'Поделиться';

  @override
  String get sharePosterHideIncome => 'Скрыть доходы';

  @override
  String get sharePosterShowIncome => 'Показать доходы';

  @override
  String get sharePosterSaveSuccess => 'Сохранено в галерею';

  @override
  String get shareGuidanceCopyText => 'Ведите учёт расходов в BeeCount — открытый код, бесплатно и без рекламы! 🐝 Скачать: https://github.com/TNT-Likely/BeeCount';

  @override
  String get shareGuidanceCopied => 'Текст скопирован';

  @override
  String get sharePosterSaveFailed => 'Не удалось сохранить';

  @override
  String get sharePosterPermissionDenied => 'Нет доступа к галерее. Разрешите его в настройках';

  @override
  String get sharePosterGenerating => 'Создаём постер...';

  @override
  String get sharePosterGenerateFailed => 'Не удалось создать постер. Попробуйте ещё раз';

  @override
  String get sharePosterNoLedger => 'Сначала выберите ведомость';

  @override
  String get sharePosterYearTitle => 'Мой годовой отчёт по учёту';

  @override
  String get sharePosterYearSubtitle => 'Цифры помогают понять прошлое и спланировать будущее';

  @override
  String get sharePosterMonthTitle => 'Отчёт по транзакциям за месяц';

  @override
  String get sharePosterMonthSubtitle => 'Планируйте бюджет, тратьте с умом';

  @override
  String get sharePosterLedgerTitle => 'Отчёт по ведомости';

  @override
  String get sharePosterRecordDays => 'Дни учёта';

  @override
  String get sharePosterRecordCount => 'Число транзакций';

  @override
  String get sharePosterTotalExpense => 'Расходы всего';

  @override
  String get sharePosterTotalIncome => 'Доходы всего';

  @override
  String get sharePosterYearBalance => 'Остаток за год';

  @override
  String get sharePosterYearDeficit => 'Дефицит за год';

  @override
  String get sharePosterMonthBalance => 'Остаток за месяц';

  @override
  String get sharePosterBalance => 'Общий остаток';

  @override
  String get sharePosterAvgMonthlyExpense => 'Средний расход за месяц';

  @override
  String get sharePosterAvgMonthlyIncome => 'Средний доход за месяц';

  @override
  String get sharePosterAvgDailyExpense => 'Средний расход за день';

  @override
  String get sharePosterMaxExpenseMonth => 'Месяц пиковых расходов';

  @override
  String get sharePosterTopExpense => 'Топ-3 расходов';

  @override
  String get sharePosterCompareLastMonth => 'К прошлому месяцу';

  @override
  String get sharePosterIncreaseRate => 'Рост';

  @override
  String get sharePosterDecreaseRate => 'Снижение';

  @override
  String get sharePosterSavedMoneyTitle => 'Поздравляем! Вы потратили меньше, чем в прошлом месяце';

  @override
  String get sharePosterLedgerName => 'Название ведомости';

  @override
  String get sharePosterUnitDay => 'дн.';

  @override
  String get sharePosterUnitCount => '';

  @override
  String get sharePosterUnitYuan => '';

  @override
  String userProfilePosterStartDate(String date) {
    return 'Ведёт учёт с $date';
  }

  @override
  String get userProfilePosterRecordDays => 'Дни учёта';

  @override
  String get userProfilePosterDaysUnit => 'дн.';

  @override
  String get userProfilePosterRecordCount => 'Транзакции';

  @override
  String get userProfilePosterCountUnit => '';

  @override
  String get userProfilePosterLedgerCount => 'Ведомости';

  @override
  String get userProfilePosterLedgerUnit => '';

  @override
  String get mineDaysCount => 'Дни учёта';

  @override
  String get mineTotalRecords => 'Транзакции';

  @override
  String get mineCurrentBalance => 'Баланс ведомости';

  @override
  String get mineCloudService => 'Облачный сервис';

  @override
  String get mineCloudServiceLoading => 'Загрузка...';

  @override
  String get mineCloudServiceOffline => 'Офлайн (по умолчанию)';

  @override
  String get mineCloudServiceCustom => 'Свой Supabase';

  @override
  String get mineCloudServiceWebDAV => 'Свой облачный сервис (WebDAV)';

  @override
  String get mineSyncTitle => 'Синхронизация';

  @override
  String get mineSyncNotLoggedIn => 'Вход не выполнен';

  @override
  String get mineSyncNotConfigured => 'Облачный сервис не настроен';

  @override
  String get mineSyncNoRemote => 'В облаке пока нет данных';

  @override
  String mineSyncInSync(Object count) {
    return 'Синхронизировано (транзакций на устройстве: $count)';
  }

  @override
  String get mineSyncInSyncSimple => 'Синхронизировано';

  @override
  String mineSyncLocalNewer(Object count) {
    return 'На устройстве есть изменения (транзакций: $count; рекомендуется загрузить в облако)';
  }

  @override
  String get mineSyncLocalNewerSimple => 'На устройстве есть изменения';

  @override
  String get mineSyncCloudNewer => 'В облаке есть изменения (скачайте для синхронизации)';

  @override
  String get mineSyncCloudNewerSimple => 'В облаке есть изменения';

  @override
  String get mineSyncDifferent => 'Данные на устройстве и в облаке различаются. Скачайте их для сравнения';

  @override
  String get mineSyncError => 'Не удалось получить статус';

  @override
  String get mineSyncDetailTitle => 'Статус синхронизации';

  @override
  String mineSyncLocalRecords(Object count) {
    return 'Транзакций на устройстве: $count';
  }

  @override
  String mineSyncCloudRecords(Object count) {
    return 'Транзакций в облаке: $count';
  }

  @override
  String mineSyncCloudLatest(Object time) {
    return 'Время последней транзакции в облаке: $time';
  }

  @override
  String mineSyncLocalFingerprint(Object fingerprint) {
    return 'Отпечаток на устройстве: $fingerprint';
  }

  @override
  String mineSyncCloudFingerprint(Object fingerprint) {
    return 'Отпечаток в облаке: $fingerprint';
  }

  @override
  String mineSyncMessage(Object message) {
    return 'Сообщение: $message';
  }

  @override
  String get mineUploadTitle => 'Загрузить в облако';

  @override
  String get mineUploadNeedLogin => 'Нужно войти в аккаунт';

  @override
  String get mineUploadNeedCloudService => 'Доступно только при использовании облачного сервиса';

  @override
  String get mineUploadInProgress => 'Загрузка в облако...';

  @override
  String get mineUploadRefreshing => 'Обновление...';

  @override
  String get mineUploadSynced => 'Синхронизировано';

  @override
  String get mineUploadSuccess => 'Загружено в облако';

  @override
  String get mineUploadSuccessMessage => 'Текущая ведомость синхронизирована с облаком';

  @override
  String get mineDownloadTitle => 'Скачать и синхронизировать';

  @override
  String get mineDownloadNeedCloudService => 'Доступно только при использовании облачного сервиса';

  @override
  String get mineDownloadComplete => 'Синхронизация завершена';

  @override
  String mineDownloadResult(Object inserted) {
    return 'Импортировано транзакций: $inserted';
  }

  @override
  String get mineLoginTitle => 'Войти';

  @override
  String get mineLoginSubtitle => 'Вход нужен только для синхронизации';

  @override
  String get cloudReloginTitle => 'Войти снова';

  @override
  String get cloudReloginSuccess => 'Повторный вход выполнен';

  @override
  String get cloudReloginFailed => 'Не удалось войти снова';

  @override
  String get mineLoggedInEmail => 'Вход выполнен';

  @override
  String get mineLogoutSubtitle => 'Нажмите, чтобы выйти';

  @override
  String get mineLogoutConfirmTitle => 'Выход из аккаунта';

  @override
  String get mineLogoutConfirmMessage => 'Выйти из аккаунта?\nПосле выхода облачная синхронизация будет недоступна.';

  @override
  String get mineLogoutButton => 'Выйти';

  @override
  String get mineAutoSyncTitle => 'Автосинхронизация ведомости';

  @override
  String get mineAutoSyncSubtitle => 'Загружать данные в облако после добавления транзакции';

  @override
  String get mineAutoSyncNeedLogin => 'Чтобы включить синхронизацию, войдите в аккаунт';

  @override
  String get mineImportProgressTitle => 'Импорт в фоновом режиме...';

  @override
  String mineImportProgressSubtitle(Object done, Object fail, Object ok, Object total) {
    return 'Прогресс: $done/$total, успешно: $ok, ошибок: $fail';
  }

  @override
  String get mineImportCompleteTitle => 'Импорт завершён';

  @override
  String get mineCategoryManagement => 'Управление категориями';

  @override
  String get mineCategoryManagementSubtitle => 'Изменить свои категории';

  @override
  String get mineCategoryMigration => 'Перенос категорий';

  @override
  String get mineCategoryMigrationSubtitle => 'Перенести данные из одних категорий в другие';

  @override
  String get mineRecurringTransactions => 'Повторяющиеся транзакции';

  @override
  String get mineRecurringTransactionsSubtitle => 'Управлять повторяющимися транзакциями';

  @override
  String get mineReminderSettings => 'Напоминания об учёте';

  @override
  String get mineReminderSettingsSubtitle => 'Настроить ежедневные напоминания об учёте';

  @override
  String get minePersonalize => 'Внешний вид';

  @override
  String get mineDisplayScale => 'Масштаб интерфейса';

  @override
  String get mineDisplayScaleSubtitle => 'Изменить размер текста и элементов интерфейса';

  @override
  String get mineCheckUpdate => 'Проверить обновления';

  @override
  String get mineCheckUpdateSubtitle => 'Проверяем, доступна ли новая версия';

  @override
  String get mineUpdateDownload => 'Скачать обновление';

  @override
  String get mineFeedback => 'Обратная связь';

  @override
  String get mineFeedbackSubtitle => 'Сообщить о проблеме или предложить улучшение';

  @override
  String get mineHelp => 'Справка';

  @override
  String get helpCenterOpenInBrowser => 'Открыть в браузере';

  @override
  String get helpCenterLoadFailed => 'Не удалось загрузить. Проверьте подключение к сети.';

  @override
  String get helpCenterRetry => 'Повторить';

  @override
  String get mineHelpSubtitle => 'Открыть документацию и ответы на частые вопросы';

  @override
  String get mineSupportAuthor => 'Поставить звезду ⭐️';

  @override
  String mineSupportAuthorSubtitle(String count) {
    return 'Открытый код, звёзд на GitHub: $count';
  }

  @override
  String get githubStarGuideTitle => 'Как поставить звезду проекту';

  @override
  String get githubStarGuideContent => 'Откройте GitHub кнопкой ниже, затем нажмите на кнопку, отмеченную на изображении';

  @override
  String get githubStarGuideButton => 'Открыть GitHub';

  @override
  String get categoryEditTitle => 'Редактирование категории';

  @override
  String get categoryNewTitle => 'Новая категория';

  @override
  String get categoryDetailTooltip => 'О категории';

  @override
  String get categoryMigrationTooltip => 'Перенести транзакции';

  @override
  String get categoryMigrationTitle => 'Перенос транзакций';

  @override
  String get categoryMigrationDescription => 'Как перенести транзакции';

  @override
  String get categoryMigrationDescriptionContent => '• Перенесите все транзакции из одной категории в другую\n• После переноса все данные этих транзакций будут доступны в новой категории\n• Отменить перенос нельзя, поэтому внимательно проверьте выбор';

  @override
  String get categoryMigrationTypeLabel => 'Выбрать тип';

  @override
  String get categoryMigrationFromLabel => 'Из категории';

  @override
  String get categoryMigrationFromHint => 'Выберите исходную категорию';

  @override
  String get categoryMigrationToLabel => 'В категорию';

  @override
  String get categoryMigrationToHint => 'Выберите категорию назначения';

  @override
  String get categoryMigrationToHintFirst => 'Сначала выберите исходную категорию';

  @override
  String get categoryMigrationStartButton => 'Начать перенос';

  @override
  String get categoryMigrationCannotTitle => 'Перенос невозможен';

  @override
  String get categoryMigrationCannotMessage => 'Не удалось перенести транзакции. Проверьте состояние выбранных категорий.';

  @override
  String get categoryExpenseType => 'Категория расходов';

  @override
  String get categoryIncomeType => 'Категория доходов';

  @override
  String get categoryDefaultTitle => 'Категория по умолчанию';

  @override
  String get categoryNameLabel => 'Название категории';

  @override
  String get categoryNameHint => 'Введите название категории';

  @override
  String get categoryNameRequired => 'Введите название категории';

  @override
  String get categoryNameTooLong => 'Название категории должно быть не длиннее 10 символов';

  @override
  String get categoryNameDuplicate => 'Категория с таким названием уже есть';

  @override
  String get categoryIconLabel => 'Значок категории';

  @override
  String get categoryCustomIconTitle => 'Свой значок';

  @override
  String get categoryCustomIconTapToSelect => 'Нажмите, чтобы выбрать изображение';

  @override
  String get categoryCustomIconTapToChange => 'Нажмите, чтобы заменить изображение';

  @override
  String get categoryCustomIconError => 'Не удалось выбрать изображение';

  @override
  String get categoryCustomIconRequired => 'Выберите изображение для значка';

  @override
  String get categoryCustomIconCrop => 'Обрезать значок';

  @override
  String get categoryDangerousOperations => 'Опасные действия';

  @override
  String get categoryDeleteTitle => 'Удалить категорию';

  @override
  String get categoryDeleteSubtitle => 'После удаления восстановить категорию не получится';

  @override
  String get categorySaveError => 'Не удалось сохранить';

  @override
  String categoryUpdated(Object name) {
    return 'Категория «$name» обновлена';
  }

  @override
  String categoryCreated(Object name) {
    return 'Категория «$name» создана';
  }

  @override
  String get categoryCannotDelete => 'Удаление невозможно';

  @override
  String categoryCannotDeleteMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count транзакции',
      many: '$count транзакций',
      few: '$count транзакции',
      one: '$count транзакция',
    );
    return 'В этой категории $_temp0. Сначала обработайте их.';
  }

  @override
  String get categoryShare => 'Поделиться категориями';

  @override
  String get categoryImport => 'Импортировать категории';

  @override
  String get categoryClearUnused => 'Удалить неиспользуемые категории';

  @override
  String get categoryClearUnusedTitle => 'Удаление неиспользуемых категорий';

  @override
  String categoryClearUnusedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count неиспользуемой категории',
      many: '$count неиспользуемых категорий',
      few: '$count неиспользуемые категории',
      one: '$count неиспользуемую категорию',
    );
    return 'Удалить $_temp0? Это действие нельзя отменить.';
  }

  @override
  String get categoryClearUnusedListTitle => 'Категории к удалению:';

  @override
  String get categoryClearUnusedEmpty => 'Нет неиспользуемых категорий';

  @override
  String categoryClearUnusedSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалено $count категории',
      many: 'Удалено $count категорий',
      few: 'Удалены $count категории',
      one: 'Удалена $count категория',
    );
    return '$_temp0';
  }

  @override
  String get categoryClearUnusedFailed => 'Не удалось удалить категории';

  @override
  String get categoryShareScopeTitle => 'Выбрать категории';

  @override
  String get categoryShareScopeExpense => 'Только категории расходов';

  @override
  String get categoryShareScopeIncome => 'Только категории доходов';

  @override
  String get categoryShareScopeAll => 'Все категории';

  @override
  String categoryShareSuccess(Object path) {
    return 'Сохранено: $path';
  }

  @override
  String get categoryShareSubject => 'Настройки категорий BeeCount';

  @override
  String get categoryShareFailed => 'Не удалось поделиться';

  @override
  String get categoryImportInvalidFile => 'Выберите архив категорий (.zip)';

  @override
  String get categoryImportModeTitle => 'Режим импорта';

  @override
  String get categoryImportModeMerge => 'Объединить';

  @override
  String get categoryImportModeMergeDesc => 'Сохранить существующие категории и добавить новые';

  @override
  String get categoryImportModeOverwrite => 'Заменить';

  @override
  String get categoryImportModeOverwriteDesc => 'Удалить неиспользуемые категории, затем выполнить импорт';

  @override
  String get categoryImportSuccess => 'Импорт завершён';

  @override
  String categoryImportSuccessDetail(int imported, int skipped, int icons) {
    return 'Импортировано категорий: $imported, пропущено: $skipped, импортировано значков: $icons';
  }

  @override
  String get categoryImportFailed => 'Не удалось импортировать';

  @override
  String get categoryDeleteConfirmTitle => 'Удаление категории';

  @override
  String categoryDeleteConfirmMessage(Object name) {
    return 'Удалить категорию «$name»? Это действие нельзя отменить.';
  }

  @override
  String get categoryDeleteError => 'Не удалось удалить';

  @override
  String categoryDeleted(Object name) {
    return 'Категория «$name» удалена';
  }

  @override
  String get categoryManageChildren => 'Управлять';

  @override
  String get categorySubCategoryTitle => 'Подкатегория';

  @override
  String get categorySubCategoryDescriptionEnabled => 'У этой категории есть родительская категория';

  @override
  String get categorySubCategoryDescriptionDisabled => 'Это самостоятельная категория верхнего уровня';

  @override
  String get categoryParentCategoryTitle => 'Родительская категория';

  @override
  String get categoryParentCategoryHint => 'Выберите родительскую категорию';

  @override
  String get categorySelectParentTitle => 'Выбор родительской категории';

  @override
  String categorySubCategoryCreated(Object name) {
    return 'Добавлена подкатегория: $name';
  }

  @override
  String get categoryParentRequired => 'Выберите родительскую категорию';

  @override
  String get categoryParentRequiredTitle => 'Ошибка';

  @override
  String get categoryExpenseList => 'Питание-Транспорт-Покупки-Развлечения-Дом-Семья-Связь-Коммуналка-Жильё-Медицина-Образование-Питомцы-Спорт-Электроника-Путешествия-Алкоголь-Малыш-Красота-Ремонт-Общение-Учёба-Автомобиль-Такси-Метро-Доставка-Квартплата-Парковка-Донаты-Подарки-Налоги-Напитки-Одежда-Перекусы-Конверты-Фрукты-Игры-Книги-Партнёр-Отделка-Хозтовары-Лотереи-Акции-Соцстрах-Курьер-Работа';

  @override
  String get categoryIncomeList => 'Зарплата-Сбережения-Конверты-Премии-Возмещение-Подработка-Подарки-Проценты-Возврат-Инвестиции-Перепродажа-Соцвыплаты-Возврат налогов-Жилфонд';

  @override
  String get categoryExpenseDining => 'Питание-Завтрак-Обед-Ужин-Meituan-Ele.me-JD-Рестораны-Еда';

  @override
  String get categoryExpenseSnacks => 'Перекусы-Печенье-Чипсы-Конфеты-Шоколад-Орехи';

  @override
  String get categoryExpenseFruit => 'Фрукты-Яблоки-Бананы-Апельсины-Виноград-Арбузы-Прочие';

  @override
  String get categoryExpenseBeverage => 'Напитки-Молочный чай-Кофе-Сок-Газировка-Минералка';

  @override
  String get categoryExpensePastry => 'Выпечка-Торты-Хлеб-Десерты-Печенье';

  @override
  String get categoryExpenseCooking => 'Продукты-Овощи-Мясо-Рыба, морепр.-Приправы-Крупы, масло';

  @override
  String get categoryExpenseShopping => 'Покупки-Одежда-Обувь, шапки-Сумки-Аксессуары-Хозтовары';

  @override
  String get categoryExpensePets => 'Питомцы-Корм-Зоотовары-Ветеринария-Груминг';

  @override
  String get categoryExpenseTransport => 'Транспорт-Метро-Автобус-Такси-Такси онлайн-Парковка-Топливо';

  @override
  String get categoryExpenseCar => 'Автомобиль-ТО-Ремонт-Страховка-Автомойка-Штрафы';

  @override
  String get categoryExpenseClothing => 'Одежда-Верх-Брюки-Юбки-Обувь-Аксессуары';

  @override
  String get categoryExpenseDailyGoods => 'Хозтовары-Гигиена-Бумага-Для уборки-Для кухни';

  @override
  String get categoryExpenseEducation => 'Образование-Учёба-Курсы-Книги-Канцтовары-Для офиса';

  @override
  String get categoryExpenseInvestLoss => 'Убытки-Акции-Фонды-Прочие';

  @override
  String get categoryExpenseEntertainment => 'Развлечения-Кино-Караоке-Аттракционы-Бары-Прочие';

  @override
  String get categoryExpenseGame => 'Игры-Пополнение-Снаряжение-Подписки';

  @override
  String get categoryExpenseHealthProducts => 'Здоровье-Витамины-Здоровая еда-БАДы';

  @override
  String get categoryExpenseSubscription => 'Подписки-Видео-Музыка-Облако-Прочие';

  @override
  String get categoryExpenseSports => 'Спорт-Спортзал-Экипировка-Занятия-На природе';

  @override
  String get categoryExpenseHousing => 'Жильё-Аренда-Квартплата-Ипотека-Отделка';

  @override
  String get categoryExpenseHome => 'Дом-Мебель-Техника-Декор-Постельное';

  @override
  String get categoryExpenseBeauty => 'Красота-Уход за кожей-Косметика-Салон-Маникюр';

  @override
  String get categoryIncomeSalary => 'Зарплата-Оклад-За результат-За год-Сверхурочные';

  @override
  String get categoryIncomeInvestment => 'Сбережения-Фонды-Дивиденды-Финпродукты-Прочие';

  @override
  String get categoryIncomeRedPacket => 'Конверты-На праздник-На ДР-Ответный дар';

  @override
  String get categoryIncomeBonus => 'Премии-За год-За квартал-За проект-Прочие';

  @override
  String get categoryIncomeReimbursement => 'Возмещение-Командировки-Питание-Прочее';

  @override
  String get categoryIncomePartTime => 'Подработка-Вторая работа-Доп. доход';

  @override
  String get categoryIncomeGift => 'Подарки-На свадьбу-На ДР-Прочие';

  @override
  String get categoryIncomeInterest => 'Проценты-От банка-Прочие';

  @override
  String get categoryIncomeRefund => 'Возврат-За покупки-За услуги-Прочее';

  @override
  String get categoryIncomeInvestIncome => 'Инвестиции-Акции-Фонды-Прочее';

  @override
  String get categoryIncomeSecondHand => 'Продажа б/у-Свои вещи-Товары б/у';

  @override
  String get categoryIncomeSocialBenefit => 'Соцвыплаты-Безработица-Декретные-Прочие';

  @override
  String get categoryIncomeTaxRefund => 'Возврат налогов-Возврат НДФЛ-Прочие возвраты';

  @override
  String get categoryIncomeProvidentFund => 'Жилфонд-Снятие-Проценты';

  @override
  String get personalizeTitle => 'Цвет темы';

  @override
  String get personalizeSubtitle => 'Выберите готовый цвет или настройте свой';

  @override
  String get personalizeCustomColor => 'Выбрать свой цвет';

  @override
  String get personalizeCustomTitle => 'Свой цвет';

  @override
  String personalizeHue(Object value) {
    return 'Тон ($value°)';
  }

  @override
  String personalizeSaturation(Object value) {
    return 'Насыщенность ($value%)';
  }

  @override
  String personalizeBrightness(Object value) {
    return 'Яркость ($value%)';
  }

  @override
  String get personalizeSelectColor => 'Выбрать этот цвет';

  @override
  String get appearanceThemeMode => 'Оформление';

  @override
  String get appearanceThemeModeSystem => 'Как в системе';

  @override
  String get appearanceThemeModeLight => 'Светлая тема';

  @override
  String get appearanceThemeModeDark => 'Тёмная тема';

  @override
  String get appearanceDarkModePattern => 'Узор шапки в тёмной теме';

  @override
  String get appearancePatternNone => 'Без узора';

  @override
  String get appearancePatternIcons => 'Узор из значков';

  @override
  String get appearancePatternParticles => 'Частицы';

  @override
  String get appearancePatternHoneycomb => 'Соты';

  @override
  String get appearanceAmountFormat => 'Формат баланса';

  @override
  String get appearanceAmountFormatFull => 'Полная сумма';

  @override
  String get appearanceAmountFormatFullDesc => 'Показать сумму полностью, например 123 456,78';

  @override
  String get appearanceAmountFormatCompact => 'Сокращённый';

  @override
  String get appearanceAmountFormatCompactDesc => 'Сокращать крупные суммы, например 12,3 тыс. (только для баланса счёта)';

  @override
  String get appearanceSkinAnimation => 'Анимация скина';

  @override
  String get appearanceSkinAnimationDesc => 'Если отключить анимацию, скин станет статичным, а приложение будет расходовать меньше заряда';

  @override
  String get appearanceShowTransactionTime => 'Показывать время транзакций';

  @override
  String get appearanceShowTransactionTimeDesc => 'В списке видно время транзакции, при редактировании его можно изменить';

  @override
  String get appearanceNoteDisplay => 'Отображение заметок';

  @override
  String get appearanceNoteDisplayCategory => 'Сначала категория';

  @override
  String get appearanceNoteDisplayCategoryDesc => 'Категория, затем заметка в скобках';

  @override
  String get appearanceNoteDisplayNote => 'Сначала заметка';

  @override
  String get appearanceNoteDisplayNoteDesc => 'Заметка, если она есть, иначе категория';

  @override
  String get appearanceNoteHistory => 'История заметок';

  @override
  String get appearanceNoteHistoryScope => 'Показывать';

  @override
  String get appearanceNoteHistoryScopeAllCategories => 'Все категории';

  @override
  String get appearanceNoteHistoryScopeCurrentCategory => 'Текущая категория';

  @override
  String get appearanceNoteHistorySort => 'Сортировать по';

  @override
  String get appearanceNoteHistorySortFrequency => 'Частоте использования';

  @override
  String get appearanceNoteHistorySortRecent => 'Дате использования';

  @override
  String get appearanceNoteHistoryLimit => 'Лимит заметок';

  @override
  String get appearanceNoteHistoryLimitHint => 'Введите число от 1 до 100';

  @override
  String get appearanceNoteHistoryLimitInvalid => 'Введите целое число от 1 до 100';

  @override
  String get appearanceColorScheme => 'Цвета доходов и расходов';

  @override
  String get appearanceColorSchemeOn => 'Красный — доходы · зелёный — расходы';

  @override
  String get appearanceColorSchemeOff => 'Красный — расходы · зелёный — доходы';

  @override
  String get appearanceColorSchemeOnDesc => 'Доходы показаны красным, расходы — зелёным';

  @override
  String get appearanceColorSchemeOffDesc => 'Расходы показаны красным, доходы — зелёным';

  @override
  String fontSettingsCurrentScale(Object scale) {
    return 'Текущий масштаб: ×$scale';
  }

  @override
  String get fontSettingsPreview => 'Предпросмотр';

  @override
  String get fontSettingsPreviewText => 'Сегодня на обед ушло 23,50 — добавим транзакцию;\nВ этом месяце — 45 дней учёта и 320 транзакций;\nГлавное — не бросать!';

  @override
  String fontSettingsCurrentLevel(Object level, Object scale) {
    return 'Текущий размер: $level (масштаб ×$scale)';
  }

  @override
  String get fontSettingsQuickLevel => 'Готовые размеры';

  @override
  String get fontSettingsCustomAdjust => 'Свой масштаб';

  @override
  String get fontSettingsDescription => 'При масштабе 1,0× приложение выглядит одинаково на разных устройствах: их различия учитываются автоматически. Меняйте масштаб, чтобы подобрать удобный размер.';

  @override
  String get fontSettingsExtraSmall => 'Минимальный';

  @override
  String get fontSettingsVerySmall => 'Очень мелкий';

  @override
  String get fontSettingsSmall => 'Мелкий';

  @override
  String get fontSettingsStandard => 'Стандартный';

  @override
  String get fontSettingsLarge => 'Увеличенный';

  @override
  String get fontSettingsBig => 'Крупный';

  @override
  String get fontSettingsVeryBig => 'Очень крупный';

  @override
  String get fontSettingsExtraBig => 'Максимальный';

  @override
  String get fontSettingsMoreStyles => 'Другие стили';

  @override
  String get fontSettingsPageTitle => 'Заголовок страницы';

  @override
  String get fontSettingsBlockTitle => 'Заголовок блока';

  @override
  String get fontSettingsBodyExample => 'Основной текст';

  @override
  String get fontSettingsLabelExample => 'Подпись';

  @override
  String get fontSettingsStrongNumber => 'Выделенное число';

  @override
  String get fontSettingsListTitle => 'Заголовок пункта списка';

  @override
  String get fontSettingsListSubtitle => 'Пояснение';

  @override
  String get fontSettingsScreenInfo => 'Адаптация к экрану';

  @override
  String get fontSettingsScreenDensity => 'Плотность экрана';

  @override
  String get fontSettingsScreenWidth => 'Ширина экрана';

  @override
  String get fontSettingsDeviceScale => 'Масштаб устройства';

  @override
  String get fontSettingsUserScale => 'Масштаб пользователя';

  @override
  String get fontSettingsFinalScale => 'Итоговый масштаб';

  @override
  String get fontSettingsBaseDevice => 'Эталонное устройство';

  @override
  String get fontSettingsRecommendedScale => 'Рекомендуемый масштаб';

  @override
  String get fontSettingsYes => 'Да';

  @override
  String get fontSettingsNo => 'Нет';

  @override
  String get fontSettingsScaleExample => 'Размер рамки и отступы автоматически подстраиваются под устройство';

  @override
  String get fontSettingsPreciseAdjust => 'Точная настройка';

  @override
  String get fontSettingsResetTo1x => 'Сбросить до 1,0×';

  @override
  String get fontSettingsAdaptBase => 'Подстроить под эталон';

  @override
  String get reminderTitle => 'Напоминание об учёте';

  @override
  String get reminderSubtitle => 'Настройте время ежедневного напоминания об учёте';

  @override
  String get reminderDailyTitle => 'Ежедневное напоминание об учёте';

  @override
  String get reminderDailySubtitle => 'Если включить, приложение будет напоминать об учёте в указанное время';

  @override
  String get reminderDailyBody => 'Не забудьте внести сегодняшние доходы и расходы 💰';

  @override
  String get reminderTimeTitle => 'Время напоминания';

  @override
  String get commonSelectTime => 'Выбрать время';

  @override
  String get reminderTestNotification => 'Отправить тестовое уведомление';

  @override
  String get reminderTestSent => 'Тестовое уведомление отправлено';

  @override
  String get reminderTestTitle => 'Тестовое уведомление';

  @override
  String get reminderTestBody => 'Это тестовое уведомление. Нажмите, чтобы проверить, что произойдёт';

  @override
  String get reminderCheckBattery => 'Проверить оптимизацию батареи';

  @override
  String get reminderBatteryStatus => 'Состояние оптимизации батареи';

  @override
  String reminderManufacturer(Object value) {
    return 'Производитель: $value';
  }

  @override
  String reminderModel(Object value) {
    return 'Модель: $value';
  }

  @override
  String reminderAndroidVersion(Object value) {
    return 'Версия Android: $value';
  }

  @override
  String get reminderBatteryIgnored => 'Оптимизация батареи для приложения: отключена ✅';

  @override
  String get reminderBatteryNotIgnored => 'Оптимизация батареи для приложения: включена ⚠️';

  @override
  String get reminderBatteryAdvice => 'Чтобы уведомления приходили вовремя, отключите оптимизацию батареи для приложения';

  @override
  String get reminderCheckChannel => 'Проверить настройки канала уведомлений';

  @override
  String get reminderChannelStatus => 'Состояние канала уведомлений';

  @override
  String get reminderChannelEnabled => 'Канал включён: да ✅';

  @override
  String get reminderChannelDisabled => 'Канал включён: нет ❌';

  @override
  String reminderChannelImportance(Object value) {
    return 'Важность: $value';
  }

  @override
  String get reminderChannelSoundOn => 'Звук: вкл. 🔊';

  @override
  String get reminderChannelSoundOff => 'Звук: выкл. 🔇';

  @override
  String get reminderChannelVibrationOn => 'Вибрация: вкл. 📳';

  @override
  String get reminderChannelVibrationOff => 'Вибрация: выкл.';

  @override
  String get reminderChannelDndBypass => 'Уведомления в режиме «Не беспокоить»: разрешены';

  @override
  String get reminderChannelDndNoBypass => 'Уведомления в режиме «Не беспокоить»: запрещены';

  @override
  String get reminderChannelAdvice => '⚠️ Рекомендуемые настройки:';

  @override
  String get reminderChannelAdviceImportance => '• Важность: срочная или высокая';

  @override
  String get reminderChannelAdviceSound => '• Включите звук и вибрацию';

  @override
  String get reminderChannelAdviceBanner => '• Разрешите баннеры уведомлений';

  @override
  String get reminderChannelAdviceXiaomi => '• На телефонах Xiaomi настройте каждый канал отдельно';

  @override
  String get reminderChannelGood => '✅ Канал уведомлений настроен правильно';

  @override
  String get reminderOpenAppSettings => 'Открыть настройки приложения';

  @override
  String get reminderAppSettingsMessage => 'Разрешите уведомления и отключите оптимизацию батареи в настройках';

  @override
  String get reminderDescription => 'Если включить напоминание об учёте, система будет каждый день в заданное время напоминать вам о необходимости внести доходы и расходы.';

  @override
  String get reminderIOSInstructions => '🍎 Настройки уведомлений iOS:\n• Настройки > Уведомления > BeeCount\n• Включите «Допуск уведомлений»\n• Выберите стиль уведомлений: баннеры или предупреждения\n• Включите звук и вибрацию\n\n⚠️ Важно:\n• Локальные уведомления iOS зависят от работы приложения\n• Не смахивайте карточку приложения в списке открытых приложений\n• Уведомления работают и в открытом приложении, и в фоновом режиме\n• При принудительном закрытии приложения уведомления перестанут приходить\n\n💡 Советы:\n• Чтобы свернуть приложение, перейдите на экран «Домой»\n• iOS автоматически управляет фоновыми приложениями\n• Оставьте приложение в фоновом режиме, чтобы получать напоминания';

  @override
  String get reminderAndroidInstructions => 'Если уведомления не приходят, проверьте настройки:\n• Разрешите приложению отправлять уведомления\n• Отключите оптимизацию батареи и энергосбережение для приложения\n• Разрешите работу в фоновом режиме и автозапуск\n• На Android 12 и новее разрешите приложению устанавливать точные будильники\n\n📱 Дополнительные настройки для телефонов Xiaomi:\n• Настройки > Управление приложениями > BeeCount > Управление уведомлениями\n• Выберите канал «Напоминание об учёте»\n• Установите важность «Срочная» или «Высокая»\n• Включите «Баннеры уведомлений», «Звук» и «Вибрацию»\n• Безопасность > Управление приложениями > Разрешения > Автозапуск\n\n🔒 Как закрепить приложение в фоновом режиме:\n• Найдите BeeCount в списке недавних приложений\n• Потяните карточку приложения вниз, чтобы появился значок замка\n• Нажмите на замок, чтобы приложение не закрывалось при очистке';

  @override
  String get categoryDetailLoadFailed => 'Не удалось загрузить';

  @override
  String get categoryDetailSummaryTitle => 'Сводка по категории';

  @override
  String get categoryDetailTotalCount => 'Всего транзакций';

  @override
  String get categoryDetailTotalAmount => 'Общая сумма';

  @override
  String get categoryDetailAverageAmount => 'Средняя сумма';

  @override
  String get categoryDetailSortTitle => 'Сортировка';

  @override
  String get categoryDetailSortTimeDesc => 'Время ↓';

  @override
  String get categoryDetailSortTimeAsc => 'Время ↑';

  @override
  String get categoryDetailSortAmountDesc => 'Сумма ↓';

  @override
  String get categoryDetailSortAmountAsc => 'Сумма ↑';

  @override
  String get categoryDetailNoTransactions => 'Нет транзакций';

  @override
  String get categoryDetailNoTransactionsSubtext => 'В этой категории пока нет транзакций';

  @override
  String get categoryDetailDeleteFailed => 'Не удалось удалить';

  @override
  String get categoryMigrationConfirmTitle => 'Подтверждение переноса';

  @override
  String categoryMigrationConfirmMessage(Object count, Object fromName, Object toName) {
    return 'Перенести транзакции из категории «$fromName» в категорию «$toName»? Количество: $count.\n\nОтменить перенос нельзя!';
  }

  @override
  String get categoryMigrationConfirmOk => 'Перенести';

  @override
  String get categoryMigrationCompleteTitle => 'Перенос завершён';

  @override
  String categoryMigrationCompleteMessage(Object count, Object fromName, Object toName) {
    return 'Транзакции перенесены из категории «$fromName» в категорию «$toName». Количество: $count.';
  }

  @override
  String get categoryMigrationFailedTitle => 'Перенос не удался';

  @override
  String categoryMigrationFailedMessage(Object error) {
    return 'Ошибка переноса: $error';
  }

  @override
  String categoryMigrationTransactionLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count транзакции',
      many: '$count транзакций',
      few: '$count транзакции',
      one: '$count транзакция',
    );
    return '$_temp0';
  }

  @override
  String get mineImportCompleteAllSuccess => 'Всё импортировано';

  @override
  String get mineCheckUpdateDetecting => 'Проверка обновлений...';

  @override
  String get mineCheckUpdateSubtitleDetecting => 'Проверяем, доступна ли новая версия';

  @override
  String get mineUpdateDownloadTitle => 'Загрузка обновления';

  @override
  String get cloudTest => 'Проверить';

  @override
  String get cloudSwitched => 'Сервис переключён';

  @override
  String get cloudSwitchFailed => 'Не удалось переключить сервис';

  @override
  String get cloudSupabaseUrlLabel => 'URL Supabase';

  @override
  String get cloudSupabaseUrlHint => 'https://xxx.supabase.co';

  @override
  String get cloudAnonKeyLabel => 'Ключ anon';

  @override
  String get cloudSelectServiceType => 'Выбрать тип облачного сервиса';

  @override
  String get cloudMultiDeviceWarningTitle => 'Работа на нескольких устройствах';

  @override
  String get cloudMultiDeviceWarningMessage => 'Перед сменой устройства отправьте данные в облако. На новом устройстве скачайте их, прежде чем вести учёт. Не редактируйте одну ведомость на двух устройствах одновременно. Подробнее →';

  @override
  String get cloudWebdavUrlLabel => 'URL сервера WebDAV';

  @override
  String get cloudWebdavUrlHint => 'https://dav.jianguoyun.com/dav/';

  @override
  String get cloudWebdavUsernameLabel => 'Имя пользователя';

  @override
  String get cloudWebdavPasswordLabel => 'Пароль';

  @override
  String get cloudWebdavPathHint => '/BeeCount';

  @override
  String get cloudS3EndpointLabel => 'Адрес сервиса';

  @override
  String get cloudS3EndpointHint => 's3.amazonaws.com или свой адрес';

  @override
  String get cloudS3RegionLabel => 'Регион';

  @override
  String get cloudS3RegionHint => 'us-east-1 (оставьте пустым для автовыбора)';

  @override
  String get cloudS3AccessKeyLabel => 'Ключ доступа';

  @override
  String get cloudS3AccessKeyHint => 'Идентификатор ключа доступа';

  @override
  String get cloudS3SecretKeyLabel => 'Секретный ключ';

  @override
  String get cloudS3SecretKeyHint => 'Ваш секретный ключ доступа';

  @override
  String get cloudS3BucketLabel => 'Имя бакета';

  @override
  String get cloudS3BucketHint => 'beecount-data';

  @override
  String get cloudS3UseSSLLabel => 'Использовать HTTPS';

  @override
  String get cloudS3PortLabel => 'Порт (необязательно)';

  @override
  String get cloudS3PortHint => 'Оставьте поле пустым, чтобы использовать порт по умолчанию';

  @override
  String get cloudSupabaseBucketLabel => 'Имя бакета';

  @override
  String get cloudSupabaseBucketHint => 'Оставьте поле пустым, чтобы использовать beecount-backups';

  @override
  String get authRememberAccount => 'Запомнить данные входа';

  @override
  String get authRememberAccountHint => 'Подставить данные при следующем входе (только Supabase)';

  @override
  String get cloudConfigSaved => 'Настройки сохранены';

  @override
  String get cloudTestSuccess => 'Подключение проверено!';

  @override
  String get cloudTestFailed => 'Не удалось подключиться. Проверьте настройки.';

  @override
  String get cloudTestError => 'Проверка не пройдена';

  @override
  String get authLogin => 'Войти';

  @override
  String get authEmail => 'Эл. почта';

  @override
  String get authPassword => 'Пароль';

  @override
  String get authInvalidEmail => 'Введите действительный адрес эл. почты';

  @override
  String get authNoAccountYet => 'Ещё нет аккаунта? ';

  @override
  String get authViewRegisterGuide => 'Узнать, как зарегистрироваться';

  @override
  String get authErrorInvalidCredentials => 'Неверный адрес эл. почты или пароль.';

  @override
  String get authErrorEmailNotConfirmed => 'Адрес эл. почты не подтверждён. Перед входом подтвердите его по ссылке в письме.';

  @override
  String get authErrorRateLimit => 'Слишком много попыток. Попробуйте позже.';

  @override
  String get authErrorNetworkIssue => 'Ошибка сети. Проверьте подключение и попробуйте ещё раз.';

  @override
  String get authErrorLoginFailed => 'Не удалось войти. Попробуйте позже.';

  @override
  String get authErrorEmailInvalid => 'Некорректный адрес эл. почты. Проверьте, нет ли опечаток.';

  @override
  String get authErrorWeakPassword => 'Пароль слишком простой. Используйте буквы и цифры, не менее 6 символов.';

  @override
  String get importSelectCsvFile => 'Выберите файл для импорта (поддерживаются CSV/TSV/XLSX)';

  @override
  String get exportTitle => 'Экспорт';

  @override
  String get exportDescription => 'Можно экспортировать:\n• Транзакции (доходы, расходы и переводы)\n• Категории\n• Счета\n\nНажмите кнопку ниже, чтобы выбрать место сохранения и экспортировать текущую ведомость в CSV.';

  @override
  String get exportButtonIOS => 'Экспортировать и поделиться';

  @override
  String get exportButtonAndroid => 'Экспортировать данные';

  @override
  String exportSavedTo(String path) {
    return 'Сохранено в: $path';
  }

  @override
  String get exportCsvHeaderType => 'Тип';

  @override
  String get exportCsvHeaderCategory => 'Категория';

  @override
  String get exportCsvHeaderSubCategory => 'Подкатегория';

  @override
  String get exportCsvHeaderAmount => 'Сумма';

  @override
  String get exportCsvHeaderAccount => 'Счёт';

  @override
  String get exportCsvHeaderFromAccount => 'Счёт списания';

  @override
  String get exportCsvHeaderToAccount => 'Счёт зачисления';

  @override
  String get exportCsvHeaderNote => 'Заметка';

  @override
  String get exportCsvHeaderTime => 'Время';

  @override
  String get exportCsvHeaderTags => 'Теги';

  @override
  String get exportCsvHeaderAttachments => 'Вложения';

  @override
  String get exportShareText => 'Файл экспорта BeeCount';

  @override
  String get exportSuccessTitle => 'Экспорт завершён';

  @override
  String exportSuccessMessageIOS(String path) {
    return 'Файл сохранён и доступен в истории отправки:\n$path';
  }

  @override
  String exportSuccessMessageAndroid(String path) {
    return 'Сохранено в:\n$path';
  }

  @override
  String get exportFailedTitle => 'Не удалось экспортировать';

  @override
  String get exportTypeIncome => 'Доход';

  @override
  String get exportTypeExpense => 'Расход';

  @override
  String get exportTypeTransfer => 'Перевод';

  @override
  String get personalizeThemeHoney => 'Медовый';

  @override
  String get personalizeThemeOrange => 'Огненно-оранжевый';

  @override
  String get personalizeThemeGreen => 'Малахитовый';

  @override
  String get personalizeThemePurple => 'Лиловый лотос';

  @override
  String get personalizeThemePink => 'Вишнёво-розовый';

  @override
  String get personalizeThemeBlue => 'Небесно-голубой';

  @override
  String get personalizeThemeMint => 'Луна над лесом';

  @override
  String get personalizeThemeSand => 'Дюны на закате';

  @override
  String get personalizeThemeLavender => 'Снег и сосны';

  @override
  String get personalizeThemeSky => 'Сказка в тумане';

  @override
  String get personalizeThemeWarmOrange => 'Тёплый оранжевый';

  @override
  String get personalizeThemeMintGreen => 'Мятный';

  @override
  String get personalizeThemeRoseGold => 'Розовое золото';

  @override
  String get personalizeThemeDeepBlue => 'Глубокий синий';

  @override
  String get personalizeThemeMapleRed => 'Красный клён';

  @override
  String get personalizeThemeEmerald => 'Изумрудный';

  @override
  String get personalizeThemeLavenderPurple => 'Лавандовый';

  @override
  String get personalizeThemeAmber => 'Янтарный';

  @override
  String get personalizeThemeRouge => 'Карминовый';

  @override
  String get personalizeThemeIndigo => 'Индиго';

  @override
  String get personalizeThemeOlive => 'Оливковый';

  @override
  String get personalizeThemeCoral => 'Коралловый';

  @override
  String get personalizeThemeDarkGreen => 'Тёмно-зелёный';

  @override
  String get personalizeThemeViolet => 'Фиалковый';

  @override
  String get personalizeThemeSunset => 'Оранжевый закат';

  @override
  String get personalizeThemePeacock => 'Павлиний синий';

  @override
  String get personalizeThemeLime => 'Лаймовый';

  @override
  String get analyticsMonthlyAvg => 'В среднем за месяц';

  @override
  String get analyticsDailyAvg => 'В среднем за день';

  @override
  String get analyticsOverallAvg => 'В среднем';

  @override
  String get analyticsTotalIncome => 'Всего доходов: ';

  @override
  String get analyticsTotalExpense => 'Всего расходов: ';

  @override
  String get analyticsBalance => 'Баланс: ';

  @override
  String analyticsAvgIncome(String avgLabel) {
    return 'Доходы ($avgLabel): ';
  }

  @override
  String analyticsAvgExpense(String avgLabel) {
    return 'Расходы ($avgLabel): ';
  }

  @override
  String get analyticsExpense => 'Расход';

  @override
  String get analyticsIncome => 'Доход';

  @override
  String analyticsTotal(String type) {
    return '$type, всего: ';
  }

  @override
  String analyticsAverage(String avgLabel) {
    return '$avgLabel: ';
  }

  @override
  String get updateCheckTitle => 'Проверить обновления';

  @override
  String updateNewVersionTitle(String version) {
    return 'Доступна версия $version';
  }

  @override
  String get updateNoApkFound => 'Ссылка для скачивания APK не найдена';

  @override
  String get updateAlreadyLatest => 'Уже установлена последняя версия';

  @override
  String get updateCheckFailed => 'Не удалось проверить обновления';

  @override
  String get updatePermissionDenied => 'В доступе отказано';

  @override
  String get updateUserCancelled => 'Отменено пользователем';

  @override
  String get updateDownloadTitle => 'Скачать обновление';

  @override
  String updateDownloading(String percent) {
    return 'Скачивание: $percent%';
  }

  @override
  String get updateDownloadBackgroundHint => 'Можно свернуть приложение: скачивание продолжится';

  @override
  String get updateCancelButton => 'Отмена';

  @override
  String get updateBackgroundDownload => 'Скачать в фоне';

  @override
  String get updateLaterButton => 'Позже';

  @override
  String get updateDownloadButton => 'Скачать';

  @override
  String get updateInstallingCachedApk => 'Установка APK из кэша';

  @override
  String get updateDownloadComplete => 'Скачивание завершено';

  @override
  String get updateInstallStarted => 'Скачивание завершено, установщик запущен';

  @override
  String get updateInstallFailed => 'Не удалось установить';

  @override
  String get updateDownloadFailed => 'Не удалось скачать';

  @override
  String get updateInstallNow => 'Установить сейчас';

  @override
  String get updateNotificationPermissionTitle => 'Уведомления не разрешены';

  @override
  String get updateCheckFailedTitle => 'Не удалось проверить обновления';

  @override
  String get updateDownloadFailedTitle => 'Не удалось скачать';

  @override
  String get updateGoToGitHub => 'Открыть GitHub';

  @override
  String get updateCannotOpenLink => 'Не удалось открыть ссылку';

  @override
  String get updateManualVisit => 'Откройте ссылку в браузере:\\nhttps://github.com/TNT-Likely/BeeCount/releases';

  @override
  String get updateNoLocalApkTitle => 'Пакет обновления не найден';

  @override
  String get updateInstallPackageTitle => 'Установить пакет обновления';

  @override
  String get updateMultiplePackagesTitle => 'Найдено несколько пакетов обновления';

  @override
  String get updateSearchFailedTitle => 'Ошибка поиска';

  @override
  String get updateFoundCachedPackageTitle => 'Найден скачанный пакет обновления';

  @override
  String get updateIgnoreButton => 'Игнорировать';

  @override
  String get updateInstallFailedTitle => 'Не удалось установить';

  @override
  String get updateInstallFailedMessage => 'Не удалось запустить установщик APK. Проверьте разрешения на доступ к файлу.';

  @override
  String get updateErrorTitle => 'Ошибка';

  @override
  String get updateCheckingPermissions => 'Проверка разрешений...';

  @override
  String get updateCheckingCache => 'Проверка кэша...';

  @override
  String get updatePreparingDownload => 'Подготовка к скачиванию...';

  @override
  String get updateUserCancelledDownload => 'Скачивание отменено';

  @override
  String get updateStartingInstaller => 'Запуск установщика...';

  @override
  String get updateInstallerStarted => 'Установщик запущен';

  @override
  String get updateInstallationFailed => 'Не удалось установить';

  @override
  String get updateDownloadCompleted => 'Скачивание завершено';

  @override
  String get updateDownloadCompletedManual => 'Скачивание завершено. Обновление можно установить вручную';

  @override
  String get updateDownloadCompletedDialog => 'Скачивание завершено, но окно установки не открылось. Установите обновление вручную';

  @override
  String get updateDownloadCompletedContext => 'Скачивание завершено. Установите обновление вручную';

  @override
  String get updateDownloadFailedGeneric => 'Не удалось скачать';

  @override
  String get updateCheckingUpdate => 'Проверка обновлений...';

  @override
  String get updateCurrentLatestVersion => 'Уже установлена последняя версия';

  @override
  String get updateCheckFailedGeneric => 'Не удалось проверить обновления';

  @override
  String updateDownloadProgress(String percent) {
    return 'Скачивание: $percent%';
  }

  @override
  String updateCheckingUpdateError(String error) {
    return 'Не удалось проверить обновления: $error';
  }

  @override
  String get updateNoLocalApkFoundMessage => 'Скачанный пакет обновления не найден.\\n\\nСначала скачайте новую версию через пункт «Проверить обновления».';

  @override
  String updateInstallPackageFoundMessage(String fileName, String fileSize, String time) {
    return 'Найден пакет обновления:\\n\\nИмя файла: $fileName\\nРазмер: $fileSize МБ\\nВремя скачивания: $time\\n\\nУстановить сейчас?';
  }

  @override
  String updateMultiplePackagesFoundMessage(int count, String path) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Найдено $count файла обновления',
      many: 'Найдено $count файлов обновления',
      few: 'Найдено $count файла обновления',
      one: 'Найден $count файл обновления',
    );
    return '$_temp0.\\n\\nИспользуйте последнюю скачанную версию или установите обновление вручную через файловый менеджер.\\n\\nРасположение файлов: $path';
  }

  @override
  String updateSearchLocalApkError(String error) {
    return 'Не удалось найти пакеты обновления на устройстве: $error';
  }

  @override
  String updateCachedPackageFoundMessage(String fileName, String fileSize) {
    return 'Найден ранее скачанный пакет обновления:\\n\\nИмя файла: $fileName\\nРазмер: $fileSize МБ\\n\\nУстановить сейчас?';
  }

  @override
  String updateReadCachedPackageError(String error) {
    return 'Не удалось прочитать сохранённый пакет обновления: $error';
  }

  @override
  String get updateOk => 'ОК';

  @override
  String get updateCannotOpenLinkTitle => 'Не удалось открыть ссылку';

  @override
  String get updateCachedVersionTitle => 'Найдено скачанное обновление';

  @override
  String get updateCachedVersionMessage => 'Найден ранее скачанный установочный пакет... Нажмите \\\"ОК\\\", чтобы установить его сейчас, или \\\"Отмена\\\", чтобы закрыть окно...';

  @override
  String get updateConfirmDownload => 'Скачать и установить сейчас';

  @override
  String get updateDownloadCompleteTitle => 'Загрузка завершена';

  @override
  String get updateInstallConfirmMessage => 'Новая версия скачана. Установить сейчас?';

  @override
  String get updateMirrorSelectTitle => 'Источник загрузки';

  @override
  String get updateMirrorSelectHint => 'Если загрузка идёт медленно, выберите более быстрое зеркало. Нажмите «Проверить», чтобы измерить задержку.';

  @override
  String get updateMirrorTestButton => 'Проверить';

  @override
  String updateMirrorTesting(int completed, int total) {
    return 'Проверка: $completed/$total...';
  }

  @override
  String get updateMirrorDirectHint => 'Для стабильного соединения';

  @override
  String updateDownloadMirror(String mirror) {
    return 'Источник: $mirror';
  }

  @override
  String get updateMirrorSettingTitle => 'Ускорение загрузки';

  @override
  String get updateNotificationPermissionGuideText => 'Уведомления о ходе загрузки отключены. Это не мешает скачиванию. Чтобы видеть ход загрузки:';

  @override
  String get updateNotificationGuideStep1 => 'Откройте настройки системы > Управление приложениями';

  @override
  String get updateNotificationGuideStep2 => 'Найдите приложение \\\"BeeCount\\\"';

  @override
  String get updateNotificationGuideStep3 => 'Разрешите уведомления';

  @override
  String get updateNotificationGuideInfo => 'Даже без уведомлений загрузка продолжится в фоновом режиме';

  @override
  String get currencyCNY => 'Китайский юань';

  @override
  String get currencyUSD => 'Доллар США';

  @override
  String get currencyEUR => 'Евро';

  @override
  String get currencyJPY => 'Японская иена';

  @override
  String get currencyHKD => 'Гонконгский доллар';

  @override
  String get currencyTWD => 'Новый тайваньский доллар';

  @override
  String get currencyGBP => 'Фунт стерлингов';

  @override
  String get currencyAUD => 'Австралийский доллар';

  @override
  String get currencyCAD => 'Канадский доллар';

  @override
  String get currencyKRW => 'Южнокорейская вона';

  @override
  String get currencySGD => 'Сингапурский доллар';

  @override
  String get currencyMYR => 'Малайзийский ринггит';

  @override
  String get currencyTHB => 'Таиландский бат';

  @override
  String get currencyIDR => 'Индонезийская рупия';

  @override
  String get currencyPHP => 'Филиппинское песо';

  @override
  String get currencyVND => 'Вьетнамский донг';

  @override
  String get currencyINR => 'Индийская рупия';

  @override
  String get currencyRUB => 'Российский рубль';

  @override
  String get currencyBYN => 'Белорусский рубль';

  @override
  String get currencyNZD => 'Новозеландский доллар';

  @override
  String get currencyCHF => 'Швейцарский франк';

  @override
  String get currencySEK => 'Шведская крона';

  @override
  String get currencyNOK => 'Норвежская крона';

  @override
  String get currencyDKK => 'Датская крона';

  @override
  String get currencyBRL => 'Бразильский реал';

  @override
  String get currencyMXN => 'Мексиканское песо';

  @override
  String get currencyTRY => 'Турецкая лира';

  @override
  String get currencyZAR => 'Южноафриканский рэнд';

  @override
  String get currencyAED => 'Дирхам ОАЭ';

  @override
  String get currencySAR => 'Саудовский риял';

  @override
  String get currencyPLN => 'Польский злотый';

  @override
  String get currencyCZK => 'Чешская крона';

  @override
  String get currencyHUF => 'Венгерский форинт';

  @override
  String get currencyARS => 'Аргентинское песо';

  @override
  String get currencyCLP => 'Чилийское песо';

  @override
  String get currencyCOP => 'Колумбийское песо';

  @override
  String get currencyPEN => 'Перуанский соль';

  @override
  String get currencyEGP => 'Египетский фунт';

  @override
  String get currencyNGN => 'Нигерийская найра';

  @override
  String get currencyKZT => 'Казахстанский тенге';

  @override
  String get currencyUAH => 'Украинская гривна';

  @override
  String get currencyILS => 'Новый израильский шекель';

  @override
  String get currencyPKR => 'Пакистанская рупия';

  @override
  String get currencyBDT => 'Бангладешская така';

  @override
  String get currencyLKR => 'Шри-ланкийская рупия';

  @override
  String get currencyMMK => 'Мьянманский кьят';

  @override
  String get webdavConfiguredTitle => 'Облачный сервис WebDAV настроен';

  @override
  String get webdavConfiguredMessage => 'WebDAV использует данные для входа, указанные при настройке. Входить отдельно не нужно.';

  @override
  String get recurringTransactionTitle => 'Повторяющиеся транзакции';

  @override
  String get recurringTransactionAdd => 'Добавить повторяющуюся транзакцию';

  @override
  String get recurringTransactionEdit => 'Изменить повторяющуюся транзакцию';

  @override
  String get recurringTransactionFrequency => 'Частота';

  @override
  String get recurringTransactionDaily => 'Ежедневно';

  @override
  String get recurringTransactionWeekly => 'Еженедельно';

  @override
  String get recurringTransactionMonthly => 'Ежемесячно';

  @override
  String get recurringTransactionYearly => 'Ежегодно';

  @override
  String get recurringTransactionInterval => 'Интервал';

  @override
  String get recurringTransactionDayOfMonth => 'День месяца';

  @override
  String get recurringTransactionStartDate => 'Дата начала';

  @override
  String get recurringTransactionEndDate => 'Дата окончания';

  @override
  String get recurringTransactionNoEndDate => 'Бессрочно';

  @override
  String get recurringTransactionDeleteConfirm => 'Удалить эту повторяющуюся транзакцию?';

  @override
  String get recurringTransactionEmpty => 'Нет повторяющихся транзакций';

  @override
  String get recurringTransactionEmptyHint => 'Чтобы добавить транзакцию, нажмите «+» в правом верхнем углу';

  @override
  String recurringTransactionEveryNDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Раз в $n дня',
      many: 'Раз в $n дней',
      few: 'Раз в $n дня',
      one: 'Раз в $n день',
    );
    return '$_temp0';
  }

  @override
  String recurringTransactionEveryNWeeks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Раз в $n недели',
      many: 'Раз в $n недель',
      few: 'Раз в $n недели',
      one: 'Раз в $n неделю',
    );
    return '$_temp0';
  }

  @override
  String recurringTransactionEveryNMonths(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Раз в $n месяца',
      many: 'Раз в $n месяцев',
      few: 'Раз в $n месяца',
      one: 'Раз в $n месяц',
    );
    return '$_temp0';
  }

  @override
  String recurringTransactionEveryNYears(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Раз в $n года',
      many: 'Раз в $n лет',
      few: 'Раз в $n года',
      one: 'Раз в $n год',
    );
    return '$_temp0';
  }

  @override
  String get recurringTransactionUsageTitle => 'Как это работает';

  @override
  String get recurringTransactionUsageContent => 'При запуске приложения, возвращении в него или сохранении правила приложение автоматически добавляет транзакции, срок которых уже наступил. Нажмите на карточку, чтобы изменить правило и увидеть три ближайшие даты добавления транзакций.';

  @override
  String get ledgerSelectTitle => 'Выбор ведомости';

  @override
  String get ledgerSelect => 'Выбрать ведомость';

  @override
  String get syncNotConfiguredMessage => 'Облако не настроено';

  @override
  String get syncNotLoggedInMessage => 'Вход не выполнен';

  @override
  String get syncCloudBackupCorruptedMessage => 'Не удалось прочитать резервную копию в облаке. Возможно, она повреждена из-за проблем с кодировкой в предыдущих версиях. Чтобы заменить копию, нажмите «Загрузить текущую ведомость в облако».';

  @override
  String get syncNoCloudBackupMessage => 'Нет резервной копии в облаке';

  @override
  String get syncAccessDeniedMessage => '403: доступ запрещён (проверьте политику RLS хранилища и путь)';

  @override
  String get cloudTestConnection => 'Проверить подключение';

  @override
  String get cloudLocalStorageTitle => 'Локальное хранилище';

  @override
  String get cloudLocalStorageSubtitle => 'Данные хранятся только на этом устройстве';

  @override
  String get cloudCustomSupabaseTitle => 'Свой Supabase';

  @override
  String get cloudCustomSupabaseSubtitle => 'Настройте подключение к своему серверу Supabase';

  @override
  String get cloudCustomWebdavTitle => 'Свой WebDAV';

  @override
  String get cloudCustomWebdavSubtitle => 'Настройте подключение к Nutstore, Nextcloud или другому сервису';

  @override
  String get cloudCustomS3Title => 'Хранилище S3';

  @override
  String get cloudCustomS3Subtitle => 'AWS S3 / Cloudflare R2 / MinIO';

  @override
  String get cloudBeeCountCloudTitle => 'BeeCount Cloud';

  @override
  String get cloudBeeCountCloudSubtitle => 'Свой сервер · синхронизация изменений · несколько устройств';

  @override
  String get cloudConfigureBeeCountCloudTitle => 'Настроить BeeCount Cloud';

  @override
  String get cloudBeeCountCloudUrlLabel => 'URL сервера';

  @override
  String get cloudBeeCountCloudUrlHint => 'https://your-server.com';

  @override
  String get cloudBeeCountCloudApiPrefixLabel => 'Префикс API';

  @override
  String get cloudBeeCountCloudApiPrefixHint => '/api/v1';

  @override
  String get cloudBeeCountCloudEmailLabel => 'Эл. почта';

  @override
  String get cloudBeeCountCloudEmailHint => 'your@email.com';

  @override
  String get cloudBeeCountCloudPasswordLabel => 'Пароль';

  @override
  String get cloudBeeCountCloudPasswordHint => 'Введите пароль';

  @override
  String get cloudBeeCountCloudLoginSuccess => 'Вход выполнен';

  @override
  String get cloudBeeCountCloudLoginFailed => 'Не удалось войти';

  @override
  String get cloudBeeCountCloudSyncSubtitle => 'Синхронизация изменений · несколько устройств';

  @override
  String get cloudBeeCountCloudConnected => 'Подключено';

  @override
  String get cloudBeeCountCloudNotConnected => 'Не подключено';

  @override
  String get cloudBeeCountCloudNotConnectedHint => 'Настройте облачный сервис и войдите в аккаунт';

  @override
  String get cloudBeeCountCloudAutoSync => 'Синхронизация изменений';

  @override
  String get cloudBeeCountCloudAutoSyncHint => 'Изменения автоматически отправляются в облако';

  @override
  String get cloudBeeCountCloudMultiDevice => 'Синхронизация устройств';

  @override
  String get cloudBeeCountCloudMultiDeviceHint => 'Данные на всех устройствах остаются актуальными';

  @override
  String get cloudBeeCountCloudAttachment => 'Синхронизация вложений';

  @override
  String get cloudBeeCountCloudAttachmentHint => 'Фото чеков и другие вложения автоматически копируются в облако';

  @override
  String get cloudTabOffline => 'Офлайн';

  @override
  String get cloudTabBackup => 'Резервное копирование';

  @override
  String get cloudTabCloudSync => 'Облачная синхронизация';

  @override
  String get cloudIcloudSubtitle => 'Автосинхронизация через Apple ID';

  @override
  String get cloudIcloudNotAvailableTitle => 'iCloud недоступен';

  @override
  String get cloudIcloudNotAvailableMessage => 'Войдите в iCloud в настройках устройства и попробуйте снова';

  @override
  String get cloudIcloudHelpTitle => 'Инструкция по iCloud';

  @override
  String get cloudIcloudHelpPrerequisites => 'Что потребуется';

  @override
  String get cloudIcloudHelpPrereq1 => '1. На устройстве выполнен вход в Apple ID';

  @override
  String get cloudIcloudHelpPrereq2 => '2. iCloud Drive включён';

  @override
  String get cloudIcloudHelpPrereq3 => '3. Устройство подключено к интернету';

  @override
  String get cloudIcloudHelpCheckTitle => 'Как проверить iCloud Drive';

  @override
  String get cloudIcloudHelpCheck1 => '1. Откройте «Настройки»';

  @override
  String get cloudIcloudHelpCheck2 => '2. Нажмите на свой Apple ID вверху';

  @override
  String get cloudIcloudHelpCheck3 => '3. Нажмите «iCloud»';

  @override
  String get cloudIcloudHelpCheck4 => '4. Убедитесь, что iCloud Drive включён';

  @override
  String get cloudIcloudHelpFaqTitle => 'Частые вопросы';

  @override
  String get cloudIcloudHelpFaq1 => 'Если iCloud недоступен, проверьте, включён ли iCloud Drive';

  @override
  String get cloudIcloudHelpFaq2 => 'При первом запуске может потребоваться несколько секунд на подготовку';

  @override
  String get cloudIcloudHelpFaq3 => 'Данные хранятся в вашем личном хранилище iCloud';

  @override
  String get cloudIcloudHelpFaq4 => 'Устройства с одним Apple ID синхронизируются автоматически';

  @override
  String get cloudIcloudHelpNote => 'Синхронизация iCloud использует ваш Apple ID и не требует дополнительных настроек';

  @override
  String get cloudSupabaseHelpTitle => 'Настройка Supabase';

  @override
  String get cloudSupabaseHelpIntro => 'Что такое Supabase';

  @override
  String get cloudSupabaseHelpIntro1 => 'Supabase — платформа с открытым кодом, которая предоставляет серверную часть как сервис';

  @override
  String get cloudSupabaseHelpIntro2 => 'Для личного использования достаточно бесплатного тарифа';

  @override
  String get cloudSupabaseHelpIntro3 => 'Вы полностью контролируете свои данные';

  @override
  String get cloudSupabaseHelpSteps => 'Порядок настройки';

  @override
  String get cloudSupabaseHelpStep1 => '1. Создайте аккаунт на supabase.com';

  @override
  String get cloudSupabaseHelpStep2 => '2. Создайте новый проект на бесплатном тарифе';

  @override
  String get cloudSupabaseHelpStep3 => '3. Откройте «Project Settings» > «API»';

  @override
  String get cloudSupabaseHelpStep4 => '4. Скопируйте «Project URL» и ключ anon';

  @override
  String get cloudSupabaseHelpStep5 => '5. Вставьте их в настройки приложения';

  @override
  String get cloudSupabaseHelpFaq => 'Частые вопросы';

  @override
  String get cloudSupabaseHelpFaq1 => 'Бесплатный тариф включает 500 МБ хранилища';

  @override
  String get cloudSupabaseHelpFaq2 => 'Данные хранятся в зашифрованном виде';

  @override
  String get cloudSupabaseHelpFaq3 => 'Поддерживается синхронизация между устройствами';

  @override
  String get cloudSupabaseHelpNote => 'После настройки создайте аккаунт или войдите, чтобы пользоваться синхронизацией';

  @override
  String get cloudDetailedTutorial => 'Подробная инструкция';

  @override
  String get cloudWebdavHelpTitle => 'Настройка WebDAV';

  @override
  String get cloudWebdavHelpIntro => 'Что такое WebDAV';

  @override
  String get cloudWebdavHelpIntro1 => 'WebDAV — протокол для работы с файлами по сети';

  @override
  String get cloudWebdavHelpIntro2 => 'Его поддерживают многие облачные и сетевые хранилища (NAS)';

  @override
  String get cloudWebdavHelpIntro3 => 'Данные хранятся на вашем сервере';

  @override
  String get cloudWebdavHelpProviders => 'Поддерживаемые сервисы';

  @override
  String get cloudWebdavHelpProvider1 => '- Nutstore (рекомендуется пользователям из Китая)';

  @override
  String get cloudWebdavHelpProvider2 => '- Nextcloud / ownCloud';

  @override
  String get cloudWebdavHelpProvider3 => '- Synology / QNAP NAS';

  @override
  String get cloudWebdavHelpProvider4 => '- Другие сервисы с поддержкой WebDAV';

  @override
  String get cloudWebdavHelpSteps => 'Порядок настройки на примере Nutstore';

  @override
  String get cloudWebdavHelpStep1 => '1. Войдите в веб-версию Nutstore';

  @override
  String get cloudWebdavHelpStep2 => '2. Нажмите на имя аккаунта и выберите «Account Info»';

  @override
  String get cloudWebdavHelpStep3 => '3. Откройте вкладку «Security Options»';

  @override
  String get cloudWebdavHelpStep4 => '4. Добавьте пароль приложения (для сторонних приложений)';

  @override
  String get cloudWebdavHelpStep5 => '5. Скопируйте адрес сервера, имя пользователя и пароль приложения';

  @override
  String get cloudWebdavHelpNote => 'Используйте пароль приложения вместо пароля от аккаунта';

  @override
  String get cloudS3HelpTitle => 'Настройка хранилища S3';

  @override
  String get cloudS3HelpIntro => 'Что такое S3';

  @override
  String get cloudS3HelpIntro1 => 'S3 — стандартный протокол объектного хранилища';

  @override
  String get cloudS3HelpIntro2 => 'Его поддерживают многие облачные сервисы';

  @override
  String get cloudS3HelpIntro3 => 'Данные хранятся в выбранном вами облачном сервисе';

  @override
  String get cloudS3HelpProviders => 'Поддерживаемые сервисы';

  @override
  String get cloudS3HelpProvider1 => '- AWS S3 (Amazon Web Services)';

  @override
  String get cloudS3HelpProvider2 => '- Cloudflare R2 (10 ГБ в месяц бесплатно)';

  @override
  String get cloudS3HelpProvider3 => '- Backblaze B2 (10 ГБ бесплатно)';

  @override
  String get cloudS3HelpProvider4 => '- MinIO (на своём сервере)';

  @override
  String get cloudS3HelpProvider5 => '- Alibaba Cloud OSS';

  @override
  String get cloudS3HelpProvider6 => '- Tencent Cloud COS';

  @override
  String get cloudS3HelpProvider7 => '- Qiniu Kodo';

  @override
  String get cloudS3HelpSteps => 'Порядок настройки на примере Cloudflare R2';

  @override
  String get cloudS3HelpStep1 => '1. Войдите в панель управления Cloudflare';

  @override
  String get cloudS3HelpStep2 => '2. Откройте «R2» > «Create Bucket»';

  @override
  String get cloudS3HelpStep3 => '3. Откройте «R2» > «Manage R2 API Tokens»';

  @override
  String get cloudS3HelpStep4 => '4. Создайте токен API и скопируйте данные доступа';

  @override
  String get cloudS3HelpStep5 => '5. Вставьте адрес сервиса, ключ доступа, секретный ключ и имя бакета';

  @override
  String get cloudS3HelpNote => 'Рекомендуем Cloudflare R2: 10 ГБ бесплатного хранилища без платы за исходящий трафик';

  @override
  String get cloudStatusNotTested => 'Не проверено';

  @override
  String get cloudStatusNormal => 'Подключение работает';

  @override
  String get cloudStatusFailed => 'Не удалось подключиться';

  @override
  String get cloudCannotOpenLink => 'Не удалось открыть ссылку';

  @override
  String get cloudErrorAuthFailed => 'Не удалось пройти аутентификацию: неверный ключ API';

  @override
  String cloudErrorServerStatus(String code) {
    return 'Сервер вернул код $code';
  }

  @override
  String get cloudErrorWebdavNotSupported => 'Сервер не поддерживает WebDAV';

  @override
  String get cloudErrorAuthFailedCredentials => 'Не удалось войти: неверное имя пользователя или пароль';

  @override
  String get cloudErrorAccessDenied => 'Доступ запрещён. Проверьте права доступа';

  @override
  String cloudErrorPathNotFound(String path) {
    return 'Путь на сервере не найден: $path';
  }

  @override
  String cloudErrorNetwork(String message) {
    return 'Ошибка сети: $message';
  }

  @override
  String get cloudTestSuccessTitle => 'Проверка пройдена';

  @override
  String get cloudTestSuccessMessage => 'Подключение работает, настройки верны';

  @override
  String get cloudTestFailedTitle => 'Проверка не пройдена';

  @override
  String get cloudTestFailedMessage => 'Не удалось подключиться';

  @override
  String get cloudTestErrorTitle => 'Ошибка проверки';

  @override
  String get cloudSwitchConfirmTitle => 'Сменить облачный сервис';

  @override
  String get cloudSwitchConfirmMessage => 'При смене облачного сервиса будет выполнен выход из текущего аккаунта. Сменить сервис?';

  @override
  String get cloudSwitchFailedTitle => 'Не удалось сменить сервис';

  @override
  String get cloudSwitchFailedConfigMissing => 'Сначала настройте этот облачный сервис';

  @override
  String get cloudConfigInvalidTitle => 'Неверные настройки';

  @override
  String get cloudConfigInvalidMessage => 'Заполните все необходимые поля';

  @override
  String get cloudSaveFailed => 'Не удалось сохранить';

  @override
  String cloudSwitchedTo(String type) {
    return 'Текущий сервис: $type';
  }

  @override
  String get cloudConfigureSupabaseTitle => 'Настроить Supabase';

  @override
  String get cloudConfigureWebdavTitle => 'Настроить WebDAV';

  @override
  String get cloudConfigureS3Title => 'Настроить S3';

  @override
  String get cloudSupabaseAnonKeyHintLong => 'Вставьте ключ anon целиком';

  @override
  String get cloudWebdavRemotePathHelp => 'Путь к папке на сервере, где будут храниться данные';

  @override
  String get cloudWebdavRemotePathLabel => 'Путь на сервере';

  @override
  String get cloudWebdavRemotePathHelperText => 'Путь к папке на сервере, где будут храниться данные';

  @override
  String get accountsTitle => 'Управление активами';

  @override
  String get accountsEmptyMessage => 'Счетов пока нет. Чтобы добавить счёт, нажмите кнопку в правом верхнем углу';

  @override
  String get accountAddTooltip => 'Добавить счёт';

  @override
  String get accountAddButton => 'Добавить счёт';

  @override
  String get accountBalance => 'Баланс';

  @override
  String get accountUpdateBalance => 'Изменить баланс';

  @override
  String get accountBalanceAdjustmentTitle => 'Подтверждение изменения баланса';

  @override
  String get accountBalanceAdjustmentChooseAction => 'Выберите, как сохранить изменение баланса';

  @override
  String get accountBalanceAdjustmentOnly => 'Изменить только баланс';

  @override
  String get accountBalanceAdjustmentOnlyMessage => 'Транзакция не будет создана. Динамика баланса за прошлые периоды пересчитается на основе нового баланса.';

  @override
  String get accountBalanceAdjustmentCreate => 'Создать транзакцию';

  @override
  String get accountBalanceAdjustmentCreateMessage => 'Будет создана обычная транзакция дохода или расхода в категории «Корректировка баланса». Она будет учтена в статистике доходов, расходов и бюджета.';

  @override
  String get accountBalanceAdjustmentConfirmOnly => 'Изменить только баланс';

  @override
  String get accountBalanceAdjustmentConfirmCreate => 'Подтвердить и создать транзакцию';

  @override
  String get accountBalanceCurrent => 'Текущий баланс';

  @override
  String get accountBalanceAfterAdjustment => 'Новый баланс';

  @override
  String get accountBalanceDifference => 'Разница';

  @override
  String get accountBalanceUnchanged => 'Баланс не изменился';

  @override
  String get accountEditTitle => 'Редактирование счёта';

  @override
  String get accountNewTitle => 'Новый счёт';

  @override
  String get accountNameLabel => 'Название счёта';

  @override
  String get accountNameHint => 'Например: ICBC, Alipay и др.';

  @override
  String get accountNameRequired => 'Введите название счёта';

  @override
  String get accountNameDuplicate => 'Счёт с таким названием уже есть. Введите другое название';

  @override
  String get accountTypeLabel => 'Тип счёта';

  @override
  String get accountTypeCash => 'Наличные';

  @override
  String get accountTypeBankCard => 'Банковская карта';

  @override
  String get accountTypeCreditCard => 'Кредитная карта';

  @override
  String get accountTypeAlipay => 'Alipay';

  @override
  String get accountTypeWechat => 'WeChat';

  @override
  String get accountTypeOther => 'Другое';

  @override
  String get accountInitialBalance => 'Начальный баланс';

  @override
  String get accountInitialBalanceHint => 'Введите начальный баланс (необязательно)';

  @override
  String get accountDeleteWarningTitle => 'Подтверждение удаления';

  @override
  String accountDeleteWarningMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'связано $count транзакции',
      many: 'связано $count транзакций',
      few: 'связаны $count транзакции',
      one: 'связана $count транзакция',
    );
    return 'С этим счётом $_temp0. После удаления сведения о счёте в этих транзакциях будут очищены. Удалить счёт?';
  }

  @override
  String get accountDeleteConfirm => 'Удалить этот счёт?';

  @override
  String get accountSelectTitle => 'Выбор счёта';

  @override
  String get accountNone => 'Без счёта';

  @override
  String get accountsEnableFeature => 'Включить учёт счетов';

  @override
  String get accountHide => 'Скрыть счёт';

  @override
  String get accountUnhide => 'Восстановить счёт';

  @override
  String get accountRestore => 'Восстановить';

  @override
  String get accountHiddenTag => 'Скрыт';

  @override
  String get accountHiddenSection => 'Скрытые счета';

  @override
  String accountHiddenSectionSummary(int count, String total) {
    return 'Скрыто: $count · Итого: $total';
  }

  @override
  String get accountHideConfirmTitle => 'Скрыть этот счёт?';

  @override
  String get accountHideConfirmBody => 'Этот счёт нельзя будет выбрать для новых транзакций. История и баланс сохранятся, а счёт можно восстановить в любой момент.';

  @override
  String accountHideRecurringWarn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count повторяющейся транзакции используют этот счёт',
      many: '$count повторяющихся транзакций используют этот счёт',
      few: '$count повторяющиеся транзакции используют этот счёт',
      one: '$count повторяющаяся транзакция использует этот счёт',
    );
    return '$_temp0. Пока счёт скрыт, такие транзакции не создаются.';
  }

  @override
  String get accountHideClearedDefault => 'Этот счёт больше не используется по умолчанию';

  @override
  String get accountHiddenToast => 'Счёт скрыт';

  @override
  String get accountRestoredToast => 'Счёт восстановлен';

  @override
  String get privacyOpenSourceUrlError => 'Не удалось открыть ссылку';

  @override
  String get updateCorruptedFileTitle => 'Установочный пакет повреждён';

  @override
  String get updateCorruptedFileMessage => 'Ранее скачанный установочный пакет неполный или повреждён. Удалить его и скачать заново?';

  @override
  String get welcomeTitle => 'Добро пожаловать в BeeCount';

  @override
  String get welcomeDescription => 'Приложение для учёта, которое бережно относится к вашим данным';

  @override
  String get welcomeCurrencyDescription => 'Выберите валюту, которой пользуетесь чаще всего. Её можно сменить в настройках в любое время';

  @override
  String get welcomeCreateDefaultLedger => 'Создать основную ведомость';

  @override
  String get welcomePrivacyTitle => 'Открытый код · Развитие с сообществом';

  @override
  String get welcomePrivacyFeature1 => 'Код открыт на 100% и доступен для проверки сообществом';

  @override
  String get welcomePrivacyFeature2 => 'Все данные хранятся на вашем устройстве';

  @override
  String get welcomeOpenSourceFeature1 => 'Активное сообщество разработчиков постоянно улучшает приложение';

  @override
  String get welcomeViewGitHub => 'Открыть репозиторий на GitHub';

  @override
  String get welcomeCloudSyncTitle => 'Синхронизация по желанию';

  @override
  String get welcomeCloudSyncDescription => 'Выберите удобный способ синхронизации — данные в BeeCount остаются под вашим контролем';

  @override
  String get welcomeCloudSyncFeature1 => 'Можно пользоваться приложением офлайн, без облачного сервиса';

  @override
  String get welcomeCloudSyncFeature2 => 'BeeCount Cloud на своём сервере (синхронизация устройств в реальном времени и веб-интерфейс)';

  @override
  String get welcomeCloudSyncFeature3 => 'Или выберите iCloud / WebDAV / Supabase / S3';

  @override
  String get widgetManagement => 'Виджет на главном экране';

  @override
  String get widgetManagementDesc => 'Доходы и расходы прямо на главном экране';

  @override
  String get widgetPreview => 'Предпросмотр виджета';

  @override
  String get widgetPreviewDesc => 'Виджет показывает данные текущей ведомости и использует цвет темы приложения';

  @override
  String get widgetGalleryTitle => 'Варианты виджетов';

  @override
  String get widgetGalleryDesc => 'На примерах — тестовые данные. Сам виджет показывает данные текущей ведомости и использует цвет вашей темы.';

  @override
  String get widgetGalleryGlanceTitle => 'Обзор';

  @override
  String get widgetGalleryGlanceDesc => 'Доходы и расходы за сегодня и за месяц';

  @override
  String get widgetGalleryNetWorthDesc => 'Сумма активов и обязательств, динамика чистых активов';

  @override
  String get widgetGalleryQuickAddTitle => 'Быстрый ввод';

  @override
  String get widgetGalleryQuickAddDesc => 'Добавляйте транзакции в частые категории одним касанием';

  @override
  String get widgetGalleryBudgetDesc => 'Следите за тем, сколько бюджета уже потрачено';

  @override
  String get widgetGalleryRecentDesc => 'Просматривайте последние транзакции';

  @override
  String get widgetGalleryDashboardTitle => 'Сводка';

  @override
  String get widgetDashboardTitle => 'Обзор месяца';

  @override
  String get widgetGalleryDashboardDesc => 'Доходы, расходы, динамика и недавние транзакции на одном экране';

  @override
  String get widgetGalleryConsumptionRhythmDesc => 'Темп расходов за последние 30 дней';

  @override
  String get widgetGalleryBeeTrailDesc => 'Отмечайте дни в сотах и постепенно привыкайте вести учёт ежедневно';

  @override
  String get widgetSizeSmall => 'Малый';

  @override
  String get widgetSizeMedium => 'Средний';

  @override
  String get widgetSizeLarge => 'Большой';

  @override
  String get howToAddWidget => 'Как добавить виджет';

  @override
  String get iosWidgetStep1 => 'Нажмите и удерживайте свободное место на экране «Домой», чтобы перейти в режим правки';

  @override
  String get iosWidgetStep2 => 'Нажмите «+» в левом верхнем углу';

  @override
  String get iosWidgetStep3 => 'Найдите и выберите «BeeCount»';

  @override
  String get iosWidgetStep4 => 'Выберите виджет среднего размера и добавьте его на экран «Домой»';

  @override
  String get androidWidgetStep1 => 'Нажмите и удерживайте свободное место на главном экране';

  @override
  String get androidWidgetStep2 => 'Выберите «Виджеты»';

  @override
  String get androidWidgetStep3 => 'Найдите виджет «BeeCount», нажмите и удерживайте его';

  @override
  String get androidWidgetStep4 => 'Перетащите виджет в нужное место на главном экране';

  @override
  String get aboutWidget => 'О виджете';

  @override
  String get widgetDescription => 'Виджет показывает доходы и расходы за сегодня и за месяц. Данные обновляются каждые 30 минут и сразу при открытии приложения.';

  @override
  String get widgetQuickEntryTitle => 'Быстрый ввод';

  @override
  String get widgetQuickEntryDesc => 'Коснитесь левой части виджета, чтобы добавить расход, или правой, чтобы добавить доход. Быстрая команда с URL beecount://new?type=transfer позволяет сразу начать перевод.';

  @override
  String get appName => 'BeeCount';

  @override
  String get monthSuffix => '';

  @override
  String get todayExpense => 'Расходы за сегодня';

  @override
  String get todayIncome => 'Доходы за сегодня';

  @override
  String get monthExpense => 'Расходы за месяц';

  @override
  String get monthIncome => 'Доходы за месяц';

  @override
  String get autoScreenshotBilling => 'Автоучёт по скриншотам';

  @override
  String get autoScreenshotBillingDesc => 'Автоматически распознаёт данные о платежах на скриншотах';

  @override
  String get autoScreenshotBillingTitle => 'Автоучёт по скриншотам';

  @override
  String get featureDescription => 'Описание функции';

  @override
  String get featureDescriptionContent => 'Сделайте скриншот экрана оплаты. Приложение распознает сумму и данные продавца и добавит расходную транзакцию.\n\n⚡ Распознавание: 2–3 секунды (на некоторых устройствах дольше)\n🤖 Автоподбор категории\n📝 Автозаполнение заметки\n\n⚠️ Важно:\n• Устройства сохраняют скриншоты с разной скоростью, поэтому задержка может составлять 5–10 секунд\n• Функция может не работать на некоторых устройствах из-за особенностей системы\n• Уже распознанные скриншоты пропускаются\n• Из-за ограничений Scoped Storage в Android 10 и новее приложение не может удалять системные скриншоты. Удаляйте их вручную';

  @override
  String get autoBilling => 'Автоучёт';

  @override
  String get enabled => 'Включено';

  @override
  String get disabled => 'Отключено';

  @override
  String get photosPermissionRequired => 'Для отслеживания скриншотов нужен доступ к фото';

  @override
  String get enableSuccess => 'Автоучёт включён';

  @override
  String get disableSuccess => 'Автоучёт отключён';

  @override
  String get autoBillingBatteryTitle => 'Работа в фоновом режиме';

  @override
  String get autoBillingBatteryGuideTitle => 'Настройки оптимизации батареи';

  @override
  String get autoBillingBatteryDesc => 'Для автоучёта приложение должно работать в фоновом режиме. Некоторые телефоны закрывают фоновые приложения при блокировке экрана, из-за чего автоучёт может не сработать. Чтобы этого избежать, отключите оптимизацию батареи для BeeCount.';

  @override
  String get autoBillingCheckBattery => 'Проверить оптимизацию батареи';

  @override
  String get autoBillingBatteryWarning => '⚠️ Оптимизация батареи включена. Система может закрыть BeeCount, и автоучёт не сработает. Нажмите «Настройки» выше и отключите оптимизацию для BeeCount.';

  @override
  String get enableFailed => 'Не удалось включить автоучёт';

  @override
  String get disableFailed => 'Не удалось отключить';

  @override
  String get iosAutoFeatureDesc => 'Приложение «Команды» в iOS позволяет распознавать данные платежей на скриншотах и автоматически добавлять транзакции. После настройки распознавание будет запускаться при каждом новом скриншоте.';

  @override
  String get iosAutoShortcutConfigTitle => 'Порядок настройки:';

  @override
  String get iosAutoShortcutStep1 => 'Откройте приложение «Команды» и нажмите «+» в правом верхнем углу, чтобы создать быструю команду';

  @override
  String get iosAutoShortcutStep2 => 'Добавьте действие «Сделать снимок экрана»';

  @override
  String get iosAutoShortcutStep3 => 'Найдите и добавьте действие «BeeCount — Автоучёт по скриншоту»';

  @override
  String get iosAutoShortcutStep4 => 'В действии «BeeCount» укажите в качестве скриншота результат предыдущего шага «Сделать снимок экрана»';

  @override
  String get iosAutoShortcutStep5 => '(Необязательно) Откройте «Настройки» > «Универсальный доступ» > «Касание» > «Коснуться сзади» и назначьте эту команду';

  @override
  String get iosAutoShortcutStep6 => 'Готово! При оплате дважды коснитесь задней панели iPhone, чтобы быстро добавить транзакцию';

  @override
  String get iosAutoShortcutRecommendedTip => '✅ Рекомендуем назначить команду для функции «Коснуться сзади»: тогда при оплате достаточно дважды коснуться задней панели iPhone. Скриншот будет сделан и распознан автоматически.';

  @override
  String get iosAutoBackTapTitle => '💡 Запуск двойным касанием сзади (рекомендуется)';

  @override
  String get iosAutoBackTapDesc => '«Настройки» > «Универсальный доступ» > «Касание» > «Коснуться сзади»\n• Выберите «Двойное касание» или «Тройное касание»\n• Выберите только что созданную быструю команду\n• После настройки при оплате дважды коснитесь задней панели iPhone: транзакция добавится автоматически, без ручного скриншота';

  @override
  String get iosAutoTutorialTitle => 'Видеоинструкция';

  @override
  String get iosAutoTutorialDesc => 'Посмотреть подробную видеоинструкцию по настройке';

  @override
  String get iosAutoImportTitle => 'Быстрая команда в одно касание';

  @override
  String get iosAutoImportDesc => 'Нажмите кнопку ниже, чтобы импортировать готовую команду «Скриншот → Автоучёт». Не нужно вручную добавлять действие «Сделать снимок экрана» и связывать параметры. После импорта рекомендуем назначить команду для функции «Коснуться сзади».';

  @override
  String get iosAutoImportButton => 'Получить команду';

  @override
  String get iosAutoImportFailed => 'Не удалось открыть ссылку на быструю команду. Проверьте подключение и повторите попытку.';

  @override
  String get iosAutoManualConfigTitle => 'Ручная настройка (для опытных)';

  @override
  String get iosAutoManualConfigDesc => 'Если быстрый импорт недоступен, создайте команду вручную по этой инструкции.';

  @override
  String get aiSettingsTitle => 'ИИ-ассистент';

  @override
  String get aiSettingsSubtitle => 'Настройка моделей ИИ и способа распознавания';

  @override
  String get aiEnableTitle => 'Включить ИИ-ассистент';

  @override
  String get aiEnableSubtitle => 'ИИ распознаёт транзакции на скриншотах, определяет сумму, продавца и время и поддерживает диалог обычным языком';

  @override
  String get aiEnableToastOn => 'ИИ-ассистент включён';

  @override
  String get aiEnableToastOff => 'ИИ-ассистент выключен';

  @override
  String get aiStrategyTitle => 'Режим выполнения';

  @override
  String get aiStrategyLocalFirst => 'Сначала на устройстве (рекомендуется)';

  @override
  String get aiStrategyCloudFirst => 'Сначала в облаке';

  @override
  String get aiStrategyCloudFirstDesc => 'Сначала использовать облачный API, а при сбое — локальную модель';

  @override
  String get aiStrategyLocalOnly => 'Только на устройстве';

  @override
  String get aiStrategyCloudOnly => 'Только в облаке';

  @override
  String get aiStrategyCloudOnlyDesc => 'Использовать только облачный API, не скачивая модель';

  @override
  String get aiStrategyUnavailable => 'Локальная модель ещё обучается и скоро станет доступна';

  @override
  String aiStrategySwitched(String strategy) {
    return 'Новый режим: $strategy';
  }

  @override
  String get aiCloudApiKeyHint => 'Введите ключ API для Zhipu AI';

  @override
  String get aiCloudApiKeyHintCustom => 'Введите ключ API';

  @override
  String get aiCloudApiKeyHelper => 'Модель GLM-*-Flash полностью бесплатна';

  @override
  String get aiCloudApiGetKey => 'Получить ключ API';

  @override
  String get aiCloudApiTutorial => 'Инструкция';

  @override
  String get aiCloudApiTestKey => 'Проверить подключение';

  @override
  String get aiChatConfigWarning => 'Поставщик ИИ не настроен. Добавьте его в настройках и выберите для нужных функций';

  @override
  String get aiChatGoToSettings => 'Открыть настройки';

  @override
  String get aiOcrRecognizing => 'Распознаём транзакцию...';

  @override
  String get aiOcrNoAmount => 'Не удалось распознать сумму. Добавьте транзакцию вручную';

  @override
  String get aiNotConfiguredHint => 'Сервис ИИ не настроен. Чтобы настроить его, откройте «Профиль → ИИ-ассистент».';

  @override
  String get aiOcrCheckLog => 'Не удалось распознать транзакцию. Подробности — в журнале.';

  @override
  String get aiOcrNoBill => 'Не удалось распознать транзакцию. Убедитесь, что на изображении есть данные о платеже, и попробуйте ещё раз.';

  @override
  String get aiNotConfiguredNotificationTitle => '❌ Не удалось распознать скриншот';

  @override
  String get aiNotConfiguredNotificationBody => 'Сервис ИИ не настроен. Нажмите, чтобы настроить.';

  @override
  String get autoBillingNotifyDetectedTitle => '✅ Скриншот обнаружен';

  @override
  String get autoBillingNotifyWaitingFileBody => 'Ожидание сохранения скриншота...';

  @override
  String get autoBillingNotifyRecognizingScreenshotTitle => 'Распознавание скриншота...';

  @override
  String get autoBillingNotifyVisionAnalyzingBody => 'Подождите, ИИ распознаёт данные о платеже на скриншоте';

  @override
  String get autoBillingNotifyRecognizingTextTitle => '⏳ Распознавание';

  @override
  String get autoBillingNotifyTextAnalyzingBody => 'ИИ анализирует данные о платеже...';

  @override
  String get autoBillingNotifyRecognizeFailedTitle => '❌ Ошибка распознавания';

  @override
  String get autoBillingNotifyRecognizeFailedBody => 'Не удалось извлечь данные о платеже из скриншота. Проверьте настройки ИИ или изображение.';

  @override
  String get autoBillingNotifyNoBillTitle => 'Транзакция не распознана';

  @override
  String get autoBillingNotifyNoBillBody => 'На скриншоте не найдено данных о транзакции — возможно, на нём нет платежа.';

  @override
  String get autoBillingNotifyFileUnavailableTitle => 'Ошибка распознавания';

  @override
  String get autoBillingNotifyFileUnavailableBody => 'Файл скриншота недоступен';

  @override
  String get autoBillingNotifyNoLedgerTitle => '❌ Ошибка автоучёта';

  @override
  String get autoBillingNotifyNoLedgerBody => 'Нет ни одной ведомости. Сначала создайте ведомость.';

  @override
  String get autoBillingNotifyNoAmountBody => 'Не удалось распознать сумму';

  @override
  String get autoBillingNotifyCreateFailedTitle => '❌ Транзакция не создана';

  @override
  String get autoBillingNotifyCreateFailedBody => 'Не удалось создать транзакцию';

  @override
  String get autoBillingNotifyProcessFailedTitle => '❌ Ошибка обработки';

  @override
  String autoBillingNotifyProcessFailedBody(String error) {
    return 'Ошибка: $error';
  }

  @override
  String autoBillingNotifySuccessSingleTitle(String amount) {
    return '✅ Транзакция добавлена: ¥$amount';
  }

  @override
  String autoBillingNotifySuccessMultiTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Добавлено $count транзакции',
      many: 'Добавлено $count транзакций',
      few: 'Добавлены $count транзакции',
      one: 'Добавлена $count транзакция',
    );
    return '✅ $_temp0';
  }

  @override
  String autoBillingNotifySuccessMultiBody(String amount) {
    return 'Итого: ¥$amount';
  }

  @override
  String autoBillingNotifySuccessSingleBodyNote(String note) {
    return 'Заметка: $note';
  }

  @override
  String get autoBillingNotifySuccessSingleBodyDefault => 'Транзакция добавлена автоматически';

  @override
  String get aiOcrNoLedger => 'Ведомость не найдена';

  @override
  String aiBillingRateMissingHint(String currency) {
    return '⚠️ Курс для $currency недоступен — транзакция временно учтена по курсу 1:1. Чтобы исправить сумму, нажмите «Пересчитать» в разделе «Статистика».';
  }

  @override
  String get aiPromptVarCurrencies => 'Основная валюта ведомости + используемые счета в иностранных валютах';

  @override
  String get aiPromptVarBillGuard => 'Фильтр изображений без данных о платеже (добавляется только при распознавании скриншотов и автоматическом учёте)';

  @override
  String aiPromptMissingVarsHint(String vars) {
    return 'В вашем шаблоне отсутствуют переменные, без которых соответствующие функции не работают: $vars';
  }

  @override
  String aiPromptInsertVarSection(String name) {
    return 'Вставить раздел «$name»';
  }

  @override
  String aiPromptVarSectionInserted(String name) {
    return 'Раздел «$name» добавлен в конец — проверьте и сохраните';
  }

  @override
  String aiOcrSuccess(String type, String amount) {
    return '✅ Транзакция добавлена: $type, ¥$amount';
  }

  @override
  String aiOcrFailed(String error) {
    return 'Ошибка распознавания: $error';
  }

  @override
  String get aiOcrCreateFailed => 'Не удалось добавить транзакцию';

  @override
  String get aiTypeIncome => 'Доход';

  @override
  String get aiTypeExpense => 'Расход';

  @override
  String get cloudSyncPageTitle => 'Облачная синхронизация';

  @override
  String get cloudSyncPageSubtitle => 'Загрузка данных ведомости в облако и скачивание вручную';

  @override
  String get cloudTutorialTitle => 'Начало работы';

  @override
  String get cloudTutorialIntro => 'BeeCount Cloud — сервер синхронизации для совместной работы на нескольких устройствах в реальном времени. Его можно развернуть у себя. Вот как начать:';

  @override
  String get cloudTutorialStep1Title => 'Шаг 1. Развернуть или выбрать сервер';

  @override
  String get cloudTutorialStep1Desc => 'Разверните сервер одной командой Docker (см. инструкцию по Docker в README на GitHub). Или подключитесь к серверу BeeCount Cloud, который уже настроили ваши друзья или команда.';

  @override
  String get cloudTutorialStep2Title => 'Шаг 2. Получить аккаунт';

  @override
  String get cloudTutorialStep2Desc => 'В BeeCount Cloud нет самостоятельной регистрации, чтобы предотвратить злоупотребления на общедоступных серверах. Если вы развернули свой сервер, при первом запуске Docker в журнале появятся сгенерированные адрес эл. почты и пароль администратора. Войдите с ними. Если вы подключаетесь к чужому серверу, попросите администратора создать для вас аккаунт в разделе «Пользователи» веб-интерфейса.';

  @override
  String get cloudTutorialStep3Title => 'Шаг 3. Войти и включить синхронизацию';

  @override
  String get cloudTutorialStep3Desc => 'В приложении выберите BeeCount Cloud, введите URL сервера и данные аккаунта из шага 2, затем войдите. При первом входе в облако загрузятся все данные ваших локальных ведомостей. Дальнейшие изменения будут отправляться в реальном времени.';

  @override
  String get cloudTutorialStep4Title => 'Шаг 4. Войти с других устройств';

  @override
  String get cloudTutorialStep4Desc => 'Войдите в тот же аккаунт на телефоне, планшете или в браузере. Данные сразу станут доступны, а изменения появятся на других устройствах за несколько секунд.';

  @override
  String get cloudTutorialTipTitle => 'Совет';

  @override
  String get cloudTutorialTipDesc => 'Откройте URL сервера в браузере, чтобы перейти в веб-интерфейс. После входа вы сможете управлять ведомостями и участниками, а также просматривать журналы.';

  @override
  String get cloudTutorialFeaturesTitle => 'Возможности';

  @override
  String get cloudTutorialFeature1 => '📱 Мгновенная синхронизация: два телефона и веб-версия в одном аккаунте, данные обновляются меньше чем за секунду';

  @override
  String get cloudTutorialFeature2 => '🌐 Веб-интерфейс в комплекте: один образ Docker содержит сервер и веб-интерфейс, доступный в браузере';

  @override
  String get cloudTutorialFeature3 => '👥 Несколько пользователей: на одном сервере могут зарегистрироваться несколько человек, их данные полностью изолированы друг от друга';

  @override
  String get cloudTutorialFeature4 => '🤝 Совместные ведомости: пригласите близких или коллег вести одну ведомость, изменения синхронизируются за считаные секунды';

  @override
  String get cloudTutorialGotIt => 'Понятно';

  @override
  String get cloudSyncHint => 'При скачивании приложение автоматически сравнивает данные и показывает изменения по отдельности. Синхронизация не мгновенная — не редактируйте одну ведомость на нескольких устройствах одновременно. Синхронизируются данные ведомости, включая связанные счета, категории и теги, но не вложения.';

  @override
  String get cloudSyncNow => 'Синхронизировать';

  @override
  String get cloudSyncNowHint => 'Отправить изменения с устройства и получить обновления из облака';

  @override
  String get cloudSyncInProgress => 'Синхронизация...';

  @override
  String cloudSyncComplete(int pushed, int pulled) {
    return 'Синхронизация завершена: отправлено — $pushed, получено — $pulled';
  }

  @override
  String get cloudAutoSyncHint => 'Синхронизировать с облаком после каждого изменения';

  @override
  String get dataManagement => 'Управление данными';

  @override
  String get dataManagementDesc => 'Импорт, экспорт, категории и счета';

  @override
  String get dataManagementPageTitle => 'Управление данными';

  @override
  String get dataManagementPageSubtitle => 'Управляйте транзакциями и категориями';

  @override
  String get dataManagementAttachmentHint => 'При восстановлении сначала импортируйте пакет вложений, а затем загрузите данные ведомости из CSV или синхронизируйте их с облаком. Так вложения будут правильно привязаны.';

  @override
  String get smartBilling => 'Умный учёт';

  @override
  String get smartBillingDesc => 'ИИ-ассистент, распознавание и автоматический учёт';

  @override
  String get smartBillingPageTitle => 'Умный учёт';

  @override
  String get smartBillingPageSubtitle => 'ИИ и автоматизация учёта';

  @override
  String get smartBillingGuideHint => 'Удерживайте кнопку «+» внизу по центру главной страницы, чтобы быстро открыть эти функции';

  @override
  String get smartBillingImageBilling => 'Ввод по изображению';

  @override
  String get smartBillingImageBillingDesc => 'Выберите скриншот платежа из галереи для распознавания';

  @override
  String get smartBillingImageBillingGuide => 'На главной странице удерживайте кнопку «+» внизу по центру и выберите «Галерея». Сначала настройте сервис в разделе «Профиль → Настройки ИИ». Модель распознает сумму, продавца, время и другие данные на скриншоте.';

  @override
  String get smartBillingVisionAIRequired => 'Для распознавания изображений нужен ИИ-сервис с поддержкой этой функции. Настройте его в разделе «Профиль → Настройки ИИ».';

  @override
  String get smartBillingCameraBilling => 'Ввод по фото';

  @override
  String get smartBillingCameraBillingDesc => 'Сфотографируйте данные платежа для распознавания';

  @override
  String get smartBillingCameraBillingGuide => 'На главной странице удерживайте кнопку «+» внизу по центру и выберите «Камера». Сначала настройте сервис в разделе «Профиль → Настройки ИИ». Модель распознает сумму, продавца, время и другие данные на фото.';

  @override
  String get smartBillingVoiceBilling => 'Голосовой ввод';

  @override
  String get smartBillingVoiceBillingDesc => 'Быстрое добавление транзакций голосом';

  @override
  String get smartBillingVoiceBillingGuide => 'На главной странице удерживайте кнопку «+» внизу по центру и выберите «Голос». ИИ преобразует речь в текст и извлечёт из него данные транзакции.';

  @override
  String get smartBillingAIRequired => 'Для голосового ввода нужен ИИ-сервис распознавания речи. Настройте его в разделе «Профиль → Настройки ИИ».';

  @override
  String get smartBillingAutoTags => 'Автоподбор тегов';

  @override
  String get smartBillingAutoTagsDesc => 'Автоматически подбирать часто используемые теги по категории';

  @override
  String get smartBillingAutoAttachment => 'Автовложения';

  @override
  String get smartBillingAutoAttachmentDesc => 'Автоматически прикреплять исходное изображение при вводе по изображению или фото';

  @override
  String get autoScreenshotBillingIosTitle => 'Автоучёт';

  @override
  String get autoScreenshotBillingIosDesc => 'Автоматическое распознавание платежей через быстрые команды';

  @override
  String get shareBilling => 'Учёт по скриншоту';

  @override
  String get shareBillingDesc => 'Поделитесь скриншотом оплаты из Alipay или WeChat, чтобы добавить транзакцию';

  @override
  String get shareBillingGuide => 'Откройте скриншот оплаты в Alipay, WeChat, галерее или другом приложении, нажмите «Поделиться» и выберите BeeCount. Приложение распознает сумму, продавца и время и добавит транзакцию. Сохранять скриншот заранее не нужно.';

  @override
  String get shareBillingActionHint => 'После отправки скриншот распознаётся в фоновом режиме — открывать BeeCount не нужно';

  @override
  String get automation => 'Автоматизация';

  @override
  String get automationDesc => 'Повторяющиеся транзакции и напоминания';

  @override
  String get automationPageTitle => 'Автоматизация';

  @override
  String get automationPageSubtitle => 'Настройте повторяющиеся транзакции и напоминания';

  @override
  String get appearanceSettings => 'Персонализация';

  @override
  String get appearanceSettingsDesc => 'Тема, шрифт, язык, блокировка приложения и т. д.';

  @override
  String get appearanceSettingsPageTitle => 'Персонализация';

  @override
  String get appearanceSettingsPageSubtitle => 'Оформление, отображение, безопасность и другие настройки приложения';

  @override
  String get about => 'О приложении';

  @override
  String get aboutDesc => 'Версия, помощь и обратная связь';

  @override
  String get mineRateApp => 'Оценить приложение';

  @override
  String get mineRateAppSubtitle => 'Оставить оценку в App Store';

  @override
  String get aboutPageTitle => 'О приложении';

  @override
  String get aboutPageSubtitle => 'Информация о приложении и помощь';

  @override
  String get aboutPageLoadingVersion => 'Загрузка версии...';

  @override
  String get aboutWebsite => 'Официальный сайт';

  @override
  String get aboutGitHubRepo => 'Репозиторий GitHub';

  @override
  String get aboutXiaohongshu => 'Xiaohongshu';

  @override
  String get aboutDouyin => 'Douyin';

  @override
  String get aboutTelegram => 'Группа в Telegram';

  @override
  String get aboutSupportDevelopment => 'Поддержать разработку';

  @override
  String get aboutSupportDevelopmentSubtitle => 'Угостить разработчика кофе';

  @override
  String get aboutDeveloperStoryTitle => 'От разработчика';

  @override
  String get aboutDeveloperStory => 'Я начал записывать расходы в 2015 году, когда был стажёром, и веду учёт уже больше десяти лет. Меня беспокоили реклама, платный доступ, риск утечки данных и закрытия приложений. Поэтому я решил сделать своё — сначала это был небольшой инструмент для меня и моей семьи.\n\nВ сентябре 2025 года вышла первая версия BeeCount. Честно говоря, я не знал, будет ли им кто-нибудь пользоваться. Но постепенно стали приходить отзывы: кто-то наконец нашёл простое приложение для учёта финансов, кто-то предложил отличную идею, а кто-то просто поставил пять звёзд. Каждый отзыв напоминал мне, что проект стоит развивать дальше.\n\nВ BeeCount нет рекламы и подписок, а исходный код полностью открыт. Все ваши данные остаются на устройстве и не загружаются ни на один сторонний сервер. Но выпуск и поддержка приложения требуют расходов: аккаунты разработчика, серверы и другие затраты сейчас покрываются пожертвованиями сообщества. Адаптацией к новым версиям ОС, исправлением ошибок и разработкой новых функций я занимаюсь в свободное от основной работы время.\n\nЕсли BeeCount вам помогает, поставьте оценку, расскажите о приложении или поддержите его пожертвованием. Это поможет небольшому проекту развиваться. Спасибо за ваше доверие.';

  @override
  String get aboutRelatedProducts => 'Другие продукты';

  @override
  String get aboutBeeAssets => 'BeeAssets';

  @override
  String get aboutBeeAssetsSubtitle => 'Весь портфель активов наглядно';

  @override
  String get aboutBeeAssetsIntro => 'BeeCount помогает вести повседневный учёт, а BeeAssets наглядно показывает состав портфеля: динамику чистых активов по всем счетам, разбивку по недвижимости, инвестициям и криптоактивам, доходность, сроки владения и долю каждого вида активов.';

  @override
  String get aboutBeeDNS => 'BeeDNS';

  @override
  String get aboutBeeDNSSubtitle => 'Простое управление DNS';

  @override
  String get aboutBeeDNSIntro => 'Ваши домены распределены между Cloudflare и Aliyun? В BeeDNS можно массово редактировать записи, переключать A/AAAA, переносить настройки DNS и управлять поддоменами — без переключения между панелями провайдеров.';

  @override
  String get productPromoAndroidTitle => 'Запросить доступ к бете';

  @override
  String get productPromoAndroidMessage => 'Приложение пока проходит закрытое тестирование в Google Play — доступ только по приглашению.\n\nКак подать заявку: напишите нам, указав адрес почты аккаунта Google (обязательно) и кратко описав, как вы планируете пользоваться приложением (необязательно). Мы ответим в течение 1–3 дней и добавим вас в список участников бета-тестирования.';

  @override
  String get productPromoOpenStore => 'Открыть в App Store';

  @override
  String get productPromoTestFlight => 'Бета в TestFlight';

  @override
  String get productPromoLearnMore => 'Pro';

  @override
  String get productPromoEmailLabel => 'Почта для заявок (нажмите, чтобы скопировать)';

  @override
  String get productPromoCopiedToast => 'Адрес скопирован в буфер обмена';

  @override
  String get productPromoMailUnavailable => 'Почтовое приложение не найдено. Адрес скопирован — вставьте его в любом почтовом приложении и отправьте письмо.';

  @override
  String get productPromoEmailButton => 'Отправить письмо';

  @override
  String get productPromoWebsiteButton => 'Открыть сайт';

  @override
  String productPromoEmailSubject(String productName) {
    return 'Заявка на бета-тестирование — $productName';
  }

  @override
  String productPromoEmailBody(String productName) {
    return 'Здравствуйте!\n\nХочу принять участие в закрытом бета-тестировании $productName в Google Play. Почта моего аккаунта Google:\n\n(укажите адрес Gmail или почту аккаунта Google)\n\nСпасибо!';
  }

  @override
  String get logCenterTitle => 'Журналы';

  @override
  String get logCenterSubtitle => 'Просмотр журналов работы приложения';

  @override
  String get logCenterSearchHint => 'Поиск по тексту или тегам...';

  @override
  String get logCenterFilterLevel => 'Уровень журнала';

  @override
  String get logCenterFilterPlatform => 'Платформа';

  @override
  String get logCenterTotal => 'Всего';

  @override
  String get logCenterFiltered => 'После фильтрации';

  @override
  String get logCenterEmpty => 'Журнал пуст';

  @override
  String get logCenterExport => 'Экспортировать';

  @override
  String get logCenterClear => 'Очистить';

  @override
  String get logCenterExportFailed => 'Не удалось экспортировать';

  @override
  String get logCenterClearConfirmTitle => 'Очистка журналов';

  @override
  String get logCenterClearConfirmMessage => 'Очистить все журналы? Это действие нельзя отменить.';

  @override
  String get logCenterCleared => 'Журналы очищены';

  @override
  String get logCenterCopied => 'Скопировано в буфер обмена';

  @override
  String get configImportExportTitle => 'Импорт и экспорт настроек';

  @override
  String get configImportExportSubtitle => 'Резервное копирование и восстановление настроек';

  @override
  String get configImportExportInfoTitle => 'Описание';

  @override
  String get configImportExportInfoMessage => 'Здесь можно экспортировать и импортировать настройки приложения, в том числе параметры облачных сервисов и ИИ. Файл настроек в формате YAML удобно просматривать и редактировать.\n\n⚠️ В файлах настроек есть конфиденциальные данные, например ключи API и пароли. Храните их в безопасном месте.';

  @override
  String get configExportTitle => 'Экспортировать настройки';

  @override
  String get configExportSubtitle => 'Экспорт текущих настроек в файл YAML';

  @override
  String get configExportShareSubject => 'Файл настроек BeeCount';

  @override
  String get configExportSuccess => 'Настройки экспортированы';

  @override
  String get configExportFailed => 'Не удалось экспортировать настройки';

  @override
  String get configImportTitle => 'Импортировать настройки';

  @override
  String get configImportSubtitle => 'Восстановление настроек из файла YAML';

  @override
  String get configImportNoFilePath => 'Файл не выбран';

  @override
  String get configImportConfirmTitle => 'Подтверждение импорта';

  @override
  String get configImportSuccess => 'Настройки импортированы';

  @override
  String get configImportFailed => 'Не удалось импортировать настройки';

  @override
  String get configImportRestartTitle => 'Требуется перезапуск';

  @override
  String get configImportRestartMessage => 'Настройки импортированы. Часть настроек вступит в силу после перезапуска приложения.';

  @override
  String get configImportExportIncludesTitle => 'Что входит в файл';

  @override
  String configExportSavedTo(String path) {
    return 'Сохранено в: $path';
  }

  @override
  String get configExportViewContent => 'Посмотреть содержимое';

  @override
  String get configExportCopyContent => 'Скопировать содержимое';

  @override
  String get configExportContentCopied => 'Скопировано в буфер обмена';

  @override
  String get configExportReadFileFailed => 'Не удалось прочитать файл';

  @override
  String get configIncludeLedgers => 'Ведомости';

  @override
  String get configIncludeSupabase => 'Настройки облачного сервиса Supabase';

  @override
  String get configIncludeWebdav => 'Настройки облачного сервиса WebDAV';

  @override
  String get configIncludeS3 => 'Настройки облачного сервиса S3';

  @override
  String get configIncludeAI => 'Настройки распознавания с ИИ';

  @override
  String get configIncludeAISubtitle => 'Поставщики, назначение моделей для задач, параметры моделей и т. д.';

  @override
  String get configIncludeAppSettings => 'Настройки приложения (язык, оформление, напоминания, основной счёт и др.)';

  @override
  String get configIncludeRecurringTransactions => 'Повторяющиеся транзакции';

  @override
  String get configIncludeAccounts => 'Счета';

  @override
  String get configIncludeCategories => 'Категории';

  @override
  String get configIncludeTags => 'Теги';

  @override
  String get configIncludeBudgets => 'Бюджеты';

  @override
  String get configIncludeOtherSettings => 'Другие настройки';

  @override
  String get configIncludeOtherSettingsSubtitle => 'Настройки облачного сервиса, ИИ, приложения и др.';

  @override
  String get configExportSelectTitle => 'Что экспортировать';

  @override
  String get configExportPreviewTitle => 'Предпросмотр экспорта';

  @override
  String get configExportConfirmTitle => 'Подтверждение экспорта';

  @override
  String get configImportSelectTitle => 'Что импортировать';

  @override
  String get configImportPreviewTitle => 'Предпросмотр импорта';

  @override
  String get ledgersConflictTitle => 'Конфликт синхронизации';

  @override
  String get ledgersConflictMessage => 'Данные ведомости на устройстве и в облаке различаются. Выберите действие:';

  @override
  String ledgersConflictLocalInfo(int count) {
    return 'Транзакций на устройстве: $count';
  }

  @override
  String ledgersConflictRemoteInfo(int count) {
    return 'Транзакций в облаке: $count';
  }

  @override
  String ledgersConflictRemoteUpdated(String time) {
    return 'Обновлено в облаке: $time';
  }

  @override
  String ledgersConflictLocalFingerprint(String fp) {
    return 'Отпечаток на устройстве: $fp';
  }

  @override
  String ledgersConflictRemoteFingerprint(String fp) {
    return 'Отпечаток в облаке: $fp';
  }

  @override
  String get ledgersConflictUpload => 'Загрузить в облако';

  @override
  String get ledgersConflictDownload => 'Скачать на устройство';

  @override
  String get ledgersConflictUploading => 'Загрузка в облако...';

  @override
  String get ledgersConflictDownloading => 'Загрузка на устройство...';

  @override
  String get ledgersConflictUploadSuccess => 'Данные загружены в облако';

  @override
  String ledgersConflictDownloadSuccess(int inserted) {
    return 'Загрузка завершена. Объединено транзакций: $inserted';
  }

  @override
  String get storageManagementTitle => 'Управление хранилищем';

  @override
  String get storageManagementSubtitle => 'Очистите кеш, чтобы освободить место';

  @override
  String get storageAIModels => 'Модели ИИ';

  @override
  String get storageAPKFiles => 'Установочные пакеты';

  @override
  String get storageNoData => 'Нет данных';

  @override
  String get storageFiles => 'файлов';

  @override
  String get storageHint => 'Нажмите на пункт, чтобы удалить соответствующие файлы кеша';

  @override
  String get storageClearConfirmTitle => 'Подтверждение очистки';

  @override
  String storageClearAIModelsMessage(String size) {
    return 'Удалить все модели ИИ? Размер: $size';
  }

  @override
  String storageClearAPKMessage(String size) {
    return 'Удалить все установочные пакеты? Размер: $size';
  }

  @override
  String get storageClearSuccess => 'Очистка завершена';

  @override
  String get accountNoTransactions => 'Нет транзакций';

  @override
  String get accountTransactionHistory => 'История транзакций';

  @override
  String get accountTotalBalance => 'Чистые активы';

  @override
  String get accountCurrencyLocked => 'Нельзя изменить валюту счёта, по которому уже есть транзакции';

  @override
  String get accountDefaultIncomeTitle => 'Счёт для доходов по умолчанию';

  @override
  String get accountDefaultExpenseTitle => 'Счёт для расходов по умолчанию';

  @override
  String get accountDefaultNone => 'Не задан';

  @override
  String get commonNotice => 'Внимание';

  @override
  String get transferTitle => 'Перевод';

  @override
  String get transferIconSettings => 'Значок перевода';

  @override
  String get transferIconSettingsDesc => 'Настройте значок транзакций перевода';

  @override
  String get transferFromAccount => 'Со счёта';

  @override
  String get transferToAccount => 'На счёт';

  @override
  String get transferSelectAccount => 'Выбрать счёт';

  @override
  String get transferCreateSuccess => 'Перевод создан';

  @override
  String get transferUpdateSuccess => 'Перевод обновлён';

  @override
  String get transferDifferentCurrencyError => 'Перевод возможен только между счетами в одной валюте';

  @override
  String get transferToPrefix => 'Куда:';

  @override
  String get transferFromPrefix => 'Откуда:';

  @override
  String get welcomeCategoryModeTitle => 'Структура категорий';

  @override
  String get welcomeCategoryModeDescription => 'Выберите, как вам удобнее организовать категории';

  @override
  String get welcomeCategoryModeFlatTitle => 'Без подкатегорий';

  @override
  String get welcomeCategoryModeFlatDescription => 'Просто и быстро';

  @override
  String get welcomeCategoryModeFlatFeature1 => 'Один уровень категорий — легко разобраться';

  @override
  String get welcomeCategoryModeFlatFeature2 => 'Подходит, если не нужно много категорий';

  @override
  String get welcomeCategoryModeFlatFeature3 => 'Быстрый выбор категорий при добавлении транзакций';

  @override
  String get welcomeCategoryModeHierarchicalTitle => 'С подкатегориями';

  @override
  String get welcomeCategoryModeHierarchicalDescription => 'Более подробный учёт';

  @override
  String get welcomeCategoryModeHierarchicalFeature1 => 'Поддержка родительских категорий и подкатегорий';

  @override
  String get welcomeCategoryModeHierarchicalFeature2 => 'Более точная группировка транзакций';

  @override
  String get welcomeCategoryModeHierarchicalFeature3 => 'Подходит для детального учёта';

  @override
  String get welcomeCategoryModeNoneTitle => 'Без категорий';

  @override
  String get welcomeCategoryModeNoneDescription => 'Добавляйте только те категории, которые нужны вам';

  @override
  String get welcomeCategoryModeNoneFeature1 => 'Нет готового набора категорий';

  @override
  String get welcomeCategoryModeNoneFeature2 => 'Создавайте категории под свои задачи';

  @override
  String get welcomeCategoryModeNoneFeature3 => 'Подходит, если у вас своя система категорий';

  @override
  String get welcomeExistingUserTitle => 'Уже пользовались BeeCount?';

  @override
  String get welcomeExistingUserButton => 'Импортировать настройки';

  @override
  String get welcomeImportingConfig => 'Импорт настроек...';

  @override
  String get welcomeImportSuccess => 'Настройки импортированы';

  @override
  String welcomeImportFailed(String error) {
    return 'Не удалось импортировать настройки: $error';
  }

  @override
  String get welcomeImportNoFile => 'Файл не выбран';

  @override
  String get welcomeImportAttachmentTitle => 'Импорт вложений';

  @override
  String get welcomeImportAttachmentDesc => 'Импортировать также файлы вложений?';

  @override
  String get welcomeImportAttachmentButton => 'Выбрать файл вложений';

  @override
  String get welcomeImportAttachmentSkip => 'Пропустить';

  @override
  String welcomeImportAttachmentSuccess(int imported) {
    return 'Импортировано вложений: $imported';
  }

  @override
  String welcomeImportAttachmentFailed(String error) {
    return 'Не удалось импортировать вложения: $error';
  }

  @override
  String get welcomeImportingAttachment => 'Импорт вложений...';

  @override
  String get iosVersionWarningTitle => 'Требуется iOS 16.0 или новее';

  @override
  String get iosVersionWarningDesc => 'Автоучёт по скриншотам использует фреймворк App Intents, который появился в iOS 16. На вашем устройстве установлена более ранняя версия iOS, и эта функция недоступна.\n\nЧтобы пользоваться функцией, обновите iOS до версии 16 или новее.';

  @override
  String get aiChatTitle => 'ИИ-ассистент';

  @override
  String get aiChatClearHistory => 'Очистить историю';

  @override
  String get aiChatClearHistoryDialogTitle => 'Очистка истории чата';

  @override
  String get aiChatClearHistoryDialogContent => 'Удалить все сообщения чата? Отменить это действие нельзя.';

  @override
  String get aiChatInputHint => 'Например: кофе стоил \$35';

  @override
  String get aiQuickCommandsTitle => 'Готовые запросы';

  @override
  String get agentSuggestionOverviewTitle => 'Доходы и расходы за месяц';

  @override
  String get agentSuggestionOverviewPrompt => 'Подведи итоги за этот месяц: доходы, расходы и разница между ними.';

  @override
  String get agentSuggestionCategoryTitle => 'Доли по категориям';

  @override
  String get agentSuggestionCategoryPrompt => 'Как распределились расходы за этот месяц по категориям верхнего уровня?';

  @override
  String get aiQuickCommandsOpen => 'Показать запросы';

  @override
  String get aiChatEmptyMessages => 'Сообщений пока нет';

  @override
  String get aiChatEmptyCurrentLedger => 'Текущая ведомость';

  @override
  String get aiChatEmptyStartTitle => 'Добавьте транзакцию или задайте вопрос';

  @override
  String get aiChatEmptyStartDescription => 'Я отвечаю на основе данных этой ведомости и при необходимости запрашиваю разрешение.';

  @override
  String get aiChatEmptyMonthExpense => 'Расходы за этот месяц';

  @override
  String get aiChatEmptyRecordedTransactions => 'Учтённые транзакции';

  @override
  String aiChatEmptyTransactionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count транзакции',
      many: '$count транзакций',
      few: '$count транзакции',
      one: '$count транзакция',
    );
    return '$_temp0';
  }

  @override
  String get aiChatEmptyQuestionExample => 'Спросите: на что у меня ушло больше всего денег в этом месяце?';

  @override
  String get aiChatEmptyFirstTransactionTitle => 'Первая транзакция за сегодня';

  @override
  String get aiChatEmptyFirstTransactionDescription => 'Укажите сумму и назначение, а я помогу добавить транзакцию.';

  @override
  String get aiChatEmptyFirstTransactionExample => 'Например: обед стоил 28';

  @override
  String aiChatMessagesLoadFailed(String error) {
    return 'Не удалось загрузить сообщения: $error';
  }

  @override
  String get aiChatThinking => 'Думаю...';

  @override
  String get aiChatHistoryCleared => 'История чата очищена';

  @override
  String get aiChatCopy => 'Копировать';

  @override
  String get aiChatCopied => 'Скопировано в буфер обмена';

  @override
  String get aiChatDeleteMessageConfirm => 'Удалить это сообщение?';

  @override
  String get aiChatMessageDeleted => 'Сообщение удалено';

  @override
  String get aiChatUndone => 'Действие отменено';

  @override
  String get aiChatUndoFailed => 'Не удалось отменить действие';

  @override
  String get aiChatTransactionNotFound => 'Транзакция не найдена';

  @override
  String get aiChatOpenEditorFailed => 'Не удалось открыть редактор';

  @override
  String get aiChatSendFailed => 'Не удалось отправить';

  @override
  String get agentRunFailed => 'Сервис ИИ временно недоступен. Попробуйте ещё раз позже.';

  @override
  String get agentNativeToolsUnsupported => 'Эта модель может отвечать в чате, но не поддерживает встроенный вызов инструментов для чтения и изменения данных ведомости. Чтобы проверить или сменить модель, откройте «Настройки > Настройки ИИ > Управление провайдерами».';

  @override
  String get agentTurnTimedOut => 'Не удалось дождаться ответа ИИ. Попробуйте ещё раз чуть позже.';

  @override
  String get agentRecordIncomplete => 'Не хватает данных о транзакции. Укажите сумму и назначение, затем попробуйте ещё раз.';

  @override
  String agentRecordCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Создано $count транзакции',
      many: 'Создано $count транзакций',
      few: 'Созданы $count транзакции',
      one: 'Создана $count транзакция',
    );
    return '$_temp0.';
  }

  @override
  String get agentStepsExceeded => 'Для этого запроса понадобилось слишком много шагов. Упростите запрос и попробуйте ещё раз.';

  @override
  String agentExecutingTool(Object tool) {
    return 'Выполняется: $tool';
  }

  @override
  String agentToolCompleted(Object tool) {
    return 'Готово: $tool';
  }

  @override
  String agentToolFailed(Object tool) {
    return 'Не удалось выполнить: $tool';
  }

  @override
  String get agentToolQueryTransactions => 'найти транзакции';

  @override
  String get agentToolSpendingSummary => 'подвести итоги расходов';

  @override
  String get agentToolTransactionSummary => 'сгруппировать транзакции';

  @override
  String get agentToolBudgetStatus => 'проверить бюджет';

  @override
  String get agentToolRecurringTransactions => 'посмотреть повторяющиеся транзакции';

  @override
  String get agentToolRecordTransaction => 'добавить транзакцию';

  @override
  String get agentToolSaveMemory => 'запомнить';

  @override
  String get agentToolForgetMemory => 'забыть';

  @override
  String get agentPermissionsTitle => 'Разрешения ИИ-ассистента';

  @override
  String get agentPermissionsIntro => 'Выберите, что может делать ИИ-ассистент. Одни инструменты только читают данные, другие запрашивают разрешение перед изменением данных.';

  @override
  String get agentPermissionsReadOnlySection => 'Только чтение';

  @override
  String get agentPermissionsReadOnlySectionDescription => 'Просмотр данных ведомости без изменений.';

  @override
  String get agentPermissionsWriteSection => 'Изменение данных';

  @override
  String get agentPermissionsWriteSectionDescription => 'Эти инструменты могут менять данные ведомости или локальной памяти. Рекомендуем каждый раз запрашивать разрешение.';

  @override
  String get agentPermissionsDefaultsActive => 'Для всех инструментов действуют разрешения по умолчанию';

  @override
  String agentPermissionsModifiedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Изменено $count настройки',
      many: 'Изменено $count настроек',
      few: 'Изменены $count настройки',
      one: 'Изменена $count настройка',
    );
    return '$_temp0';
  }

  @override
  String get agentPermissionsRestoreDefaults => 'Сбросить настройки';

  @override
  String get agentPermissionsRestoreTitle => 'Восстановить разрешения по умолчанию?';

  @override
  String get agentPermissionsRestoreDescription => 'Это отменит все настройки «Всегда разрешать» и восстановит разрешения по умолчанию для каждого инструмента.';

  @override
  String get agentPermissionsRestoreConfirm => 'Восстановить';

  @override
  String get agentPermissionAsk => 'Спрашивать каждый раз';

  @override
  String get agentPermissionAlwaysAllow => 'Всегда разрешать';

  @override
  String get agentPermissionWaiting => 'Ожидание вашего разрешения';

  @override
  String get agentPermissionWriteFailed => 'Не удалось сохранить настройки разрешений. Попробуйте ещё раз.';

  @override
  String get agentAuthorizationPersistenceFailed => 'Не удалось сохранить разрешение, но для этой операции ваш выбор будет учтён.';

  @override
  String get agentToolQueryTransactionsDescription => 'Найти транзакции в текущей ведомости за выбранный период.';

  @override
  String get agentToolSpendingSummaryDescription => 'Подвести итоги расходов в текущей ведомости за выбранный период.';

  @override
  String get agentToolTransactionSummaryDescription => 'Подвести итоги по транзакциям в текущей ведомости, сгруппировав их по типу, категории, тегу, счёту или периоду.';

  @override
  String get agentToolBudgetStatusDescription => 'Проверить состояние бюджета текущей ведомости.';

  @override
  String get agentToolRecurringTransactionsDescription => 'Посмотреть активные повторяющиеся транзакции в текущей ведомости.';

  @override
  String get agentToolRecordTransactionDescription => 'Добавить транзакцию на основе текста вашего сообщения.';

  @override
  String get agentToolSaveMemoryDescription => 'Сохранить информацию, которую вы попросили ассистента запомнить.';

  @override
  String get agentToolForgetMemoryDescription => 'Удалить запись из локальной памяти ассистента.';

  @override
  String get agentToolUnknownDescription => 'Запустить локальный инструмент ИИ-ассистента.';

  @override
  String get agentAuthorizationTitle => 'Разрешить действие ассистента?';

  @override
  String agentAuthorizationCurrentLedger(int ledgerId) {
    return 'Ведомость: текущая (ID $ledgerId)';
  }

  @override
  String get agentAuthorizationAllLedgers => 'Ведомости: все доступные';

  @override
  String get agentAuthorizationParameters => 'Данные для этой операции';

  @override
  String get agentAuthorizationNoParameters => 'Нет параметров для отображения.';

  @override
  String get agentAuthorizationSourceText => 'Исходный текст транзакции';

  @override
  String get agentAuthorizationTimeRange => 'Период запроса';

  @override
  String get agentAuthorizationSummaryTypes => 'Типы транзакций';

  @override
  String get agentAuthorizationSummaryGroupBy => 'Группировка';

  @override
  String get agentAuthorizationCategoryIds => 'ID категорий';

  @override
  String get agentAuthorizationTagIds => 'ID тегов';

  @override
  String get agentAuthorizationAccountIds => 'ID счетов';

  @override
  String get agentAuthorizationMemoryContent => 'Содержимое записи';

  @override
  String get agentAuthorizationMemoryId => 'ID записи';

  @override
  String get agentAuthorizationDeny => 'Отклонить';

  @override
  String get agentAuthorizationAllowOnce => 'Разрешить один раз';

  @override
  String get agentAuthorizationAlwaysAllow => 'Всегда разрешать';

  @override
  String get billCardSuccess => 'Транзакция добавлена';

  @override
  String get billCardUndone => 'Отменено';

  @override
  String get billCardAmount => '💰 Сумма';

  @override
  String get billCardCategory => '🏷️ Категория';

  @override
  String get billCardTime => '📅 Время';

  @override
  String get billCardNote => '📝 Заметка';

  @override
  String get billCardAccount => '💳 Счёт';

  @override
  String get billCardTransferAccounts => '🔁 Счета перевода';

  @override
  String get billCardType => '↕️ Тип';

  @override
  String get billCardExpense => 'Расход';

  @override
  String get billCardIncome => 'Доход';

  @override
  String get billCardTransfer => 'Перевод';

  @override
  String get billCardCurrency => '💱 Валюта';

  @override
  String get billCardTags => '🏷️ Теги';

  @override
  String get billCardUndo => 'Отменить';

  @override
  String get billCardEdit => 'Изменить';

  @override
  String get donationTitle => 'Поддержать';

  @override
  String get donationSubtitle => 'Угостить разработчика кофе';

  @override
  String get donationEntrySubtitle => 'Поддержите развитие приложения';

  @override
  String get donationDescription => 'Описание';

  @override
  String get donationDescriptionDetail => 'Спасибо, что пользуетесь BeeCount! Если приложение вам помогает, можете угостить разработчика кофе. Ваша поддержка вдохновляет меня улучшать приложение.';

  @override
  String get donationNoFeatures => 'Пожертвования не открывают дополнительных функций. Все функции остаются бесплатными.';

  @override
  String get donationNoProducts => 'Нет доступных товаров';

  @override
  String get donationThankYouTitle => 'Спасибо за поддержку!';

  @override
  String donationThankYouMessage(String productName) {
    return 'Спасибо за покупку «$productName»! Ваша поддержка много для меня значит. Я продолжу улучшать BeeCount, чтобы пользоваться им стало ещё удобнее!';
  }

  @override
  String get aiQuickCommandFinancialHealthTitle => 'Оценка финансового положения';

  @override
  String get aiQuickCommandFinancialHealthDesc => 'Анализ баланса доходов и расходов и доли сбережений';

  @override
  String get aiQuickCommandFinancialHealthPrompt => 'Оцените моё финансовое положение по этим данным:\n\n[monthlyStats]\n\n[recentTrends]\n\nПроанализируйте баланс доходов и расходов, долю сбережений и динамику расходов. Дайте рекомендации. Ответьте на русском языке.';

  @override
  String get aiQuickCommandMonthlyExpenseTitle => 'Расходы за месяц';

  @override
  String get aiQuickCommandMonthlyExpenseDesc => 'Анализ расходов за месяц и рекомендации';

  @override
  String get aiQuickCommandMonthlyExpensePrompt => 'Подведите итоги моих расходов за этот месяц по этим данным:\n\n[monthlyStats]\n\n[categoryStats]\n\nУкажите, на какие категории приходится самая большая доля расходов, и предложите способы сократить расходы. Ответьте на русском языке.';

  @override
  String get aiQuickCommandCategoryAnalysisTitle => 'Расходы по категориям';

  @override
  String get aiQuickCommandCategoryAnalysisDesc => 'Доли расходов по категориям и их динамика';

  @override
  String get aiQuickCommandCategoryAnalysisPrompt => 'Проанализируйте распределение моих расходов по категориям на основе этих данных:\n\n[categoryStats]\n\nУкажите, по каким категориям доля расходов может быть слишком высокой, и предложите, как её снизить. Ответьте на русском языке.';

  @override
  String get aiQuickCommandBudgetPlanningTitle => 'Планирование бюджета';

  @override
  String get aiQuickCommandBudgetPlanningDesc => 'Рекомендации по бюджету на основе прошлых данных';

  @override
  String get aiQuickCommandBudgetPlanningPrompt => 'Помогите мне спланировать бюджет на следующий месяц по этим данным:\n\n[monthlyStats]\n\n[recentTrends]\n\nДля каждой категории предложите конкретную сумму и объясните, как уложиться в бюджет. Ответьте на русском языке.';

  @override
  String get aiQuickCommandAbnormalExpenseTitle => 'Необычные расходы';

  @override
  String get aiQuickCommandAbnormalExpenseDesc => 'Поиск крупных или необычных расходов';

  @override
  String get aiQuickCommandAbnormalExpensePrompt => 'Проверьте, есть ли у меня необычные расходы, по этим данным:\n\n[recentTransactions]\n\n[monthlyStats]\n\nУкажите расходы, которые заметно выше обычных, и объясните возможные причины. Ответьте на русском языке.';

  @override
  String get aiQuickCommandSavingTipsTitle => 'Советы по экономии';

  @override
  String get aiQuickCommandSavingTipsDesc => 'Советы по экономии с учётом ваших привычек';

  @override
  String get aiQuickCommandSavingTipsPrompt => 'Предложите способы сэкономить на основе этих данных:\n\n[categoryStats]\n\n[recentTrends]\n\nДайте 3–5 конкретных и практичных советов. Ответьте на русском языке.';

  @override
  String get billCardUnknownLedger => 'Неизвестная ведомость';

  @override
  String get aiPromptEditTitle => 'Редактор подсказки';

  @override
  String get aiPromptEditSubtitle => 'Настройка подсказки ИИ для распознавания транзакций';

  @override
  String get aiPromptAdvancedSettings => 'Расширенные настройки';

  @override
  String get aiAdvancedSettingsDesc => 'Выбор модели, режим выполнения, локальная модель и подсказка';

  @override
  String get aiPromptEditEntry => 'Редактор подсказки';

  @override
  String get aiPromptEditEntryDesc => 'Подсказку ИИ для распознавания транзакций можно настроить и отправить другим пользователям';

  @override
  String get aiPromptVariables => 'Переменные';

  @override
  String get aiPromptVariablesHint => 'Нажмите, чтобы увидеть доступные переменные';

  @override
  String get aiPromptContent => 'Текст подсказки';

  @override
  String get aiPromptUnsaved => 'Не сохранено';

  @override
  String get aiPromptInputHint => 'Введите подсказку...';

  @override
  String get aiPromptPreview => 'Предпросмотр';

  @override
  String get aiPromptSave => 'Сохранить';

  @override
  String get aiPromptSaved => 'Подсказка сохранена';

  @override
  String get aiPromptResetDefault => 'Вернуть исходную';

  @override
  String get aiPromptResetConfirmTitle => 'Восстановление исходной подсказки';

  @override
  String get aiPromptResetConfirmMessage => 'Восстановить исходную подсказку? Ваши изменения будут потеряны.';

  @override
  String get aiPromptPasted => 'Вставлено';

  @override
  String get aiPromptPreviewTitle => 'Предпросмотр подсказки';

  @override
  String get aiPromptPreviewNote => 'Здесь вместо переменных показаны примеры. При выполнении будут использованы реальные данные.';

  @override
  String get aiPromptVarInputSource => 'Описание источника данных, например «Из приведённого ниже текста о платеже»';

  @override
  String get aiPromptVarCurrentTime => 'Текущие дата и время, например «2025-01-15 14:30»';

  @override
  String get aiPromptVarCurrentDate => 'Текущая дата, например «2025-01-15»';

  @override
  String get aiPromptVarOcrText => 'Текст, введённый пользователем';

  @override
  String get aiPromptVarCategories => 'Список категорий расходов и доходов';

  @override
  String get aiPromptVarAccounts => 'Список счетов пользователя (может быть пустым)';

  @override
  String get aiModelTitle => 'Модель анализа текста';

  @override
  String get aiVisionModelTitle => 'Модель для изображений';

  @override
  String get aiModelFast => 'Быстрее';

  @override
  String get aiModelAccurate => 'Точнее';

  @override
  String aiModelSwitched(String modelName) {
    return 'Выбрана модель $modelName';
  }

  @override
  String get aiCustomBaseUrlHelper => 'URL стандартного API для чата, например https://api.example.com/v1';

  @override
  String get aiTextModelTitle => 'Текстовая модель';

  @override
  String get aiAudioModelTitle => 'Речевая модель';

  @override
  String get tagManageTitle => 'Теги';

  @override
  String get tagManageSubtitle => 'Управляйте тегами транзакций';

  @override
  String get tagManageEmpty => 'Тегов пока нет';

  @override
  String get tagManageEmptyHint => 'Нажмите «+», чтобы добавить тег';

  @override
  String get tagManageGenerateDefault => 'Добавить готовые теги';

  @override
  String get tagManageGenerateDefaultConfirm => 'Добавить готовые теги? Существующие теги с такими же названиями не изменятся.';

  @override
  String get tagManageGenerateDefaultSuccess => 'Готовые теги добавлены';

  @override
  String get tagEditTitle => 'Изменение тега';

  @override
  String get tagAddTitle => 'Новый тег';

  @override
  String get tagNameLabel => 'Название тега';

  @override
  String get tagNameHint => 'Введите название тега';

  @override
  String get tagNameRequired => 'Укажите название тега';

  @override
  String get tagNameDuplicate => 'Тег с таким названием уже есть';

  @override
  String get tagColorLabel => 'Цвет тега';

  @override
  String get tagCreateSuccess => 'Тег создан';

  @override
  String get tagUpdateSuccess => 'Тег изменён';

  @override
  String get tagDeleteConfirmTitle => 'Удаление тега';

  @override
  String tagDeleteConfirmMessage(String name) {
    return 'Удалить тег «$name»? Связанные транзакции сохранятся.';
  }

  @override
  String get tagDeleteSuccess => 'Тег удалён';

  @override
  String get tagSelectTitle => 'Выбор тегов';

  @override
  String get tagSelectHint => 'Можно выбрать несколько';

  @override
  String get tagSelectCreateNew => 'Создать тег';

  @override
  String get tagSelectOwnerManaged => 'Тегами совместной ведомости управляет её владелец';

  @override
  String get tagSelectRecentlyUsed => 'Недавние';

  @override
  String get tagSelectAllTags => 'Все теги';

  @override
  String tagTransactionCount(int count) {
    return '$count шт.';
  }

  @override
  String get tagDetailTitle => 'Сведения о теге';

  @override
  String get tagDetailTotalCount => 'Транзакции';

  @override
  String get tagDetailTotalExpense => 'Всего расходов';

  @override
  String get tagDetailTotalIncome => 'Всего доходов';

  @override
  String get tagDetailTransactionList => 'Связанные транзакции';

  @override
  String get tagDetailNoTransactions => 'Связанных транзакций нет';

  @override
  String get tagDetailNoTransactionsHint => 'Здесь появятся транзакции с этим тегом';

  @override
  String get tagNotFound => 'Тег не найден';

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
  String get tagDefaultBusinessTrip => 'Командировка';

  @override
  String get tagDefaultTravel => 'Поездки';

  @override
  String get tagDefaultDining => 'Еда вне дома';

  @override
  String get tagDefaultOnlineShopping => 'Покупки онлайн';

  @override
  String get tagDefaultDaily => 'Повседневное';

  @override
  String get tagDefaultReimbursement => 'К возмещению';

  @override
  String get tagDefaultRefundable => 'Можно вернуть';

  @override
  String get tagDefaultRefunded => 'Возврат получен';

  @override
  String get tagDefaultVoiceBilling => 'Голос';

  @override
  String get tagDefaultImageBilling => 'Изображение';

  @override
  String get tagDefaultCameraBilling => 'Камера';

  @override
  String get tagDefaultAiBilling => 'ИИ';

  @override
  String get tagShare => 'Поделиться тегами';

  @override
  String get tagImport => 'Импортировать теги';

  @override
  String get tagClearUnused => 'Удалить неиспользуемые';

  @override
  String tagShareSuccess(String path) {
    return 'Сохранено: $path';
  }

  @override
  String get tagShareSubject => 'Настройки тегов BeeCount';

  @override
  String get tagShareFailed => 'Не удалось поделиться';

  @override
  String get tagImportInvalidFile => 'Выберите файл YAML';

  @override
  String get tagImportNoTags => 'В файле нет тегов';

  @override
  String get tagImportModeTitle => 'Режим импорта';

  @override
  String get tagImportModeMerge => 'Объединить';

  @override
  String get tagImportModeMergeDesc => 'Сохранить существующие теги и добавить новые';

  @override
  String get tagImportModeOverwrite => 'Заменить';

  @override
  String get tagImportModeOverwriteDesc => 'Удалить неиспользуемые теги перед импортом';

  @override
  String get tagImportSuccess => 'Импорт завершён';

  @override
  String get tagImportFailed => 'Не удалось импортировать теги';

  @override
  String get tagClearUnusedEmpty => 'Неиспользуемых тегов нет';

  @override
  String get tagClearUnusedTitle => 'Удаление неиспользуемых тегов';

  @override
  String tagClearUnusedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалить $count неиспользуемого тега?',
      many: 'Удалить $count неиспользуемых тегов?',
      few: 'Удалить $count неиспользуемых тега?',
      one: 'Удалить $count неиспользуемый тег?',
    );
    return '$_temp0';
  }

  @override
  String tagClearUnusedSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалено $count тега',
      many: 'Удалено $count тегов',
      few: 'Удалены $count тега',
      one: 'Удалён $count тег',
    );
    return '$_temp0';
  }

  @override
  String get tagClearUnusedFailed => 'Не удалось удалить теги';

  @override
  String get homeSwitchLedger => 'Выбрать ведомость';

  @override
  String get homeManageLedgers => 'Управление ведомостями';

  @override
  String get budgetTitle => 'Бюджет';

  @override
  String get budgetShowOnHome => 'Показывать бюджет на главной';

  @override
  String get budgetEmptyHint => 'Бюджет ещё не задан';

  @override
  String get budgetAddTotal => 'Добавить общий бюджет';

  @override
  String get budgetMonthlyBudget => 'Бюджет на месяц';

  @override
  String get budgetUsed => 'Потрачено';

  @override
  String get budgetRemaining => 'Осталось';

  @override
  String budgetDaysRemaining(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Осталось $days дня',
      many: 'Осталось $days дней',
      few: 'Осталось $days дня',
      one: 'Остался $days день',
    );
    return '$_temp0';
  }

  @override
  String budgetDailyAvailable(String amount) {
    return 'На день: $amount';
  }

  @override
  String get budgetCategoryBudgets => 'Бюджеты по категориям';

  @override
  String get budgetEditTitle => 'Изменение бюджета';

  @override
  String get budgetAddTitle => 'Новый бюджет';

  @override
  String get budgetTypeTotalLabel => 'Общий бюджет';

  @override
  String get budgetTypeCategoryLabel => 'Бюджет категории';

  @override
  String get budgetAmountLabel => 'Сумма бюджета';

  @override
  String get budgetAmountHint => 'Введите сумму бюджета';

  @override
  String get budgetCategoryLabel => 'Выбрать категорию';

  @override
  String get budgetCategoryHint => 'Выберите категорию бюджета';

  @override
  String get budgetStartDayLabel => 'День начала';

  @override
  String get budgetPeriodLabel => 'Период';

  @override
  String get budgetSaveSuccess => 'Бюджет сохранён';

  @override
  String get budgetDeleteConfirm => 'Удалить этот бюджет?';

  @override
  String get budgetDeleteSuccess => 'Бюджет удалён';

  @override
  String get attachmentAdd => 'Добавить изображение';

  @override
  String get attachmentTakePhoto => 'Сделать снимок';

  @override
  String get attachmentChooseFromGallery => 'Выбрать из галереи';

  @override
  String get attachmentMaxReached => 'Достигнут лимит вложений';

  @override
  String get attachmentDeleteConfirm => 'Удалить это вложение?';

  @override
  String attachmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count изображения',
      many: '$count изображений',
      few: '$count изображения',
      one: '$count изображение',
    );
    return '$_temp0';
  }

  @override
  String get commonDeleted => 'Удалено';

  @override
  String get attachmentExportTitle => 'Экспортировать вложения';

  @override
  String get attachmentExportSubtitle => 'Экспорт всех вложений в архив';

  @override
  String get attachmentImportTitle => 'Импортировать вложения';

  @override
  String get attachmentImportSubtitle => 'Импорт вложений из архива';

  @override
  String get attachmentExportEmpty => 'Нет вложений для экспорта';

  @override
  String attachmentExportProgress(int current, int total) {
    return 'Экспорт вложений ($current/$total)';
  }

  @override
  String attachmentExportProgressDetail(int attachmentCount, int iconCount, int current, int total) {
    return 'Экспорт: вложений — $attachmentCount, значков — $iconCount ($current/$total)';
  }

  @override
  String get attachmentExportSuccess => 'Вложения экспортированы';

  @override
  String attachmentExportSavedTo(String path) {
    return 'Сохранено в: $path';
  }

  @override
  String get attachmentImportConflictStrategy => 'Обработка конфликтов';

  @override
  String get attachmentImportConflictSkip => 'Пропустить существующие вложения';

  @override
  String get attachmentImportConflictOverwrite => 'Перезаписать существующие вложения';

  @override
  String attachmentImportProgress(int current, int total) {
    return 'Импорт вложений ($current/$total)';
  }

  @override
  String attachmentImportResult(int imported, int skipped, int overwritten, int failed) {
    return 'Импортировано: $imported, пропущено: $skipped, перезаписано: $overwritten, ошибок: $failed';
  }

  @override
  String get attachmentImportFailed => 'Не удалось импортировать вложения';

  @override
  String attachmentArchiveInfo(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вложения',
      many: '$count вложений',
      few: '$count вложения',
      one: '$count вложение',
    );
    return '$_temp0, дата экспорта: $date';
  }

  @override
  String get attachmentStartImport => 'Начать импорт';

  @override
  String get attachmentPreview => 'Предпросмотр вложений';

  @override
  String attachmentPreviewSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Всего $count изображения',
      many: 'Всего $count изображений',
      few: 'Всего $count изображения',
      one: 'Всего $count изображение',
    );
    return '$_temp0';
  }

  @override
  String get attachmentPreviewEmpty => 'Нет вложений';

  @override
  String get attachmentExportPreviewTitle => 'Предпросмотр экспорта';

  @override
  String get attachmentImportPreviewTitle => 'Предпросмотр импорта';

  @override
  String get shortcutsGuide => 'Быстрые команды';

  @override
  String get shortcutsGuideDesc => 'Быстрый доступ к голосовому вводу, распознаванию снимков и другим способам ввода';

  @override
  String get shortcutsIntroTitle => 'Быстрый ввод';

  @override
  String get shortcutsIntroDesc => 'Быстрые команды позволяют запускать голосовой ввод, распознавание снимков и другие функции с главного экрана, не открывая приложение.';

  @override
  String get availableShortcuts => 'Доступные быстрые команды';

  @override
  String get shortcutVoice => 'Голосовой ввод';

  @override
  String get shortcutVoiceDesc => 'Быстро добавляйте транзакции голосом';

  @override
  String get shortcutImage => 'Ввод по изображению';

  @override
  String get shortcutImageDesc => 'Распознавайте транзакции по изображениям из галереи';

  @override
  String get shortcutCamera => 'Ввод по снимку';

  @override
  String get shortcutCameraDesc => 'Сделайте снимок для распознавания транзакций';

  @override
  String get shortcutNewExpense => 'Добавить расход';

  @override
  String get shortcutNewExpenseDesc => 'Сразу открыть форму добавления расхода';

  @override
  String get shortcutNewIncome => 'Добавить доход';

  @override
  String get shortcutNewIncomeDesc => 'Сразу открыть форму добавления дохода';

  @override
  String get shortcutNewTransfer => 'Добавить перевод';

  @override
  String get shortcutNewTransferDesc => 'Сразу открыть форму добавления перевода';

  @override
  String get shortcutUrlCopied => 'URL скопирован в буфер обмена';

  @override
  String get howToAddShortcut => 'Как добавить быстрые команды';

  @override
  String get iosShortcutStep1 => 'Откройте приложение «Команды»';

  @override
  String get iosShortcutStep2 => 'Нажмите «+» в правом верхнем углу, чтобы создать быструю команду';

  @override
  String get iosShortcutStep3 => 'Добавьте действие «Открыть URL»';

  @override
  String get iosShortcutStep4 => 'Вставьте скопированный URL (например, beecount://voice)';

  @override
  String get iosShortcutStep5 => 'Сохраните команду и добавьте её на экран «Домой»';

  @override
  String get androidShortcutStep1 => 'Скачайте приложение для создания ярлыков (например, Shortcut Maker)';

  @override
  String get androidShortcutStep2 => 'Выберите «URL Shortcut» (ярлык URL)';

  @override
  String get androidShortcutStep3 => 'Вставьте скопированный URL (например, beecount://voice)';

  @override
  String get androidShortcutStep4 => 'Задайте значок и название, затем добавьте ярлык на главный экран';

  @override
  String get shortcutsTip => 'Советы';

  @override
  String get shortcutsTipDesc => 'Для быстрых команд нужны функции ИИ. Убедитесь, что распознавание включено и ключ API настроен.';

  @override
  String get shortcutOpenShortcutsApp => 'Открыть «Быстрые команды»';

  @override
  String get shortcutAutoAdd => 'API для автодобавления';

  @override
  String get shortcutAutoAddDesc => 'Автоматически добавляйте транзакции через параметры URL. Подходит для быстрых команд и других средств автоматизации.';

  @override
  String get shortcutAutoAddExample => 'Пример URL:';

  @override
  String get shortcutAutoAddParams => 'Поддерживаемые параметры:';

  @override
  String get shortcutParamAmount => 'Сумма (обязательно)';

  @override
  String get shortcutParamType => 'Тип: expense / income / transfer';

  @override
  String get shortcutParamCategory => 'Название категории (должно совпадать с существующим)';

  @override
  String get shortcutParamNote => 'Заметка';

  @override
  String get shortcutParamAccount => 'Название счёта (должно совпадать с существующим)';

  @override
  String get shortcutParamTags => 'Теги (через запятую)';

  @override
  String get shortcutParamDate => 'Дата (формат ISO, например 2024-01-15)';

  @override
  String get quickActionImage => 'Из галереи';

  @override
  String get quickActionCamera => 'Сделать снимок';

  @override
  String get quickActionVoice => 'Голосовой ввод';

  @override
  String get quickActionAiChat => 'ИИ-ассистент';

  @override
  String get calendarTitle => 'Календарь';

  @override
  String get calendarToday => 'Сегодня';

  @override
  String get calendarNoTransactions => 'Нет транзакций';

  @override
  String get calendarAddTransaction => 'Добавить на выбранный день';

  @override
  String get calendarAddTransactionTooltip => 'Добавить транзакцию на выбранный день';

  @override
  String get commonUncategorized => 'Без категории';

  @override
  String get commonSaved => 'Сохранено';

  @override
  String get aiProviderManageTitle => 'Поставщики ИИ';

  @override
  String get aiProviderManageSubtitle => 'Управление поставщиками ИИ';

  @override
  String get aiProviderAdd => 'Добавить поставщика';

  @override
  String get aiProviderBuiltIn => 'Встроенный';

  @override
  String get aiProviderEmpty => 'Поставщики не настроены';

  @override
  String get aiProviderNoApiKey => 'Ключ API не настроен';

  @override
  String get aiProviderTapToEdit => 'Нажмите, чтобы изменить';

  @override
  String get aiProviderDeleteTitle => 'Удаление поставщика';

  @override
  String aiProviderDeleteConfirm(String name) {
    return 'Удалить поставщика «$name»? Функции, которые его используют, переключатся на поставщика по умолчанию.';
  }

  @override
  String get aiProviderDeleted => 'Поставщик удалён';

  @override
  String get aiProviderEditTitle => 'Настройки поставщика';

  @override
  String get aiProviderAddTitle => 'Новый поставщик';

  @override
  String get aiProviderBasicInfo => 'Основные сведения';

  @override
  String get aiProviderName => 'Название поставщика';

  @override
  String get aiProviderNameHint => 'Например, SiliconFlow или DeepSeek';

  @override
  String get aiProviderNameRequired => 'Введите название поставщика';

  @override
  String get aiProviderBaseUrlRequired => 'Введите базовый URL';

  @override
  String get aiProviderModels => 'Настройка моделей';

  @override
  String get aiProviderModelsHint => 'Если для функции не указана модель, она не сможет использовать этого поставщика';

  @override
  String get aiCapabilityText => 'Текст';

  @override
  String get aiCapabilityVision => 'Изображения';

  @override
  String get aiCapabilitySpeech => 'Речь';

  @override
  String get aiCapabilitySelectTitle => 'Поставщики для функций ИИ';

  @override
  String get aiCapabilitySelectSubtitle => 'Выберите поставщика для каждой функции ИИ';

  @override
  String get aiCapabilityTextChat => 'Текстовый чат';

  @override
  String get aiCapabilityTextChatDesc => 'Для чата с ИИ и извлечения данных о транзакциях из текста';

  @override
  String get aiCapabilityImageUnderstand => 'Анализ изображений';

  @override
  String get aiCapabilityImageUnderstandDesc => 'Для распознавания транзакций на изображениях';

  @override
  String get aiCapabilitySpeechToText => 'Распознавание речи';

  @override
  String get aiCapabilitySpeechToTextDesc => 'Для голосового ввода';

  @override
  String get aiProviderTestRun => 'Нажмите для проверки';

  @override
  String get aiProviderTestRunning => 'Проверка...';

  @override
  String get aiProviderTestSuccess => 'Проверка пройдена';

  @override
  String get aiProviderTestFailed => 'Проверка не пройдена';

  @override
  String get aiProviderTestAll => 'Проверить всё';

  @override
  String get aiProviderTestAllRetry => 'Повторить проверку';

  @override
  String get aiModelInputHelper => 'Оставьте поле пустым, чтобы использовать модель по умолчанию';

  @override
  String get syncPreviewTitle => 'Предпросмотр синхронизации';

  @override
  String get syncPreviewSelectAll => 'Выбрать всё';

  @override
  String get syncPreviewDeselectAll => 'Снять выбор';

  @override
  String get syncPreviewAdded => 'Добавлено';

  @override
  String get syncPreviewModified => 'Изменено';

  @override
  String get syncPreviewDeleted => 'Удалено';

  @override
  String syncPreviewAddedCount(int count) {
    return 'Добавлено: $count';
  }

  @override
  String syncPreviewModifiedCount(int count) {
    return 'Изменено: $count';
  }

  @override
  String syncPreviewDeletedCount(int count) {
    return 'Удалено: $count';
  }

  @override
  String syncPreviewApply(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Применить $count изменения',
      many: 'Применить $count изменений',
      few: 'Применить $count изменения',
      one: 'Применить $count изменение',
    );
    return '$_temp0';
  }

  @override
  String get syncPreviewEmpty => 'Данные на устройстве и в облаке совпадают, синхронизация не нужна';

  @override
  String get syncPreviewOldFormat => 'Устаревший формат данных в облаке. Требуется полная замена';

  @override
  String get syncPreviewOldFormatMessage => 'В облачных данных нет идентификаторов синхронизации. Все данные текущей ведомости на устройстве будут удалены и заново загружены из облака.';

  @override
  String syncPreviewApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Применено $count изменения',
      many: 'Применено $count изменений',
      few: 'Применено $count изменения',
      one: 'Применено $count изменение',
    );
    return '$_temp0';
  }

  @override
  String get cloudSyncGuideTitle => 'Облачная синхронизация';

  @override
  String get cloudSyncGuideGotIt => 'Понятно';

  @override
  String get cloudSyncGuideHowItWorks => 'Как это работает';

  @override
  String get cloudSyncGuideHowItem1 => 'Отправка: все данные текущей ведомости загружаются в облако и заменяют предыдущие';

  @override
  String get cloudSyncGuideHowItem2 => 'Скачивание: приложение сравнивает данные из облака с данными на устройстве и показывает каждое изменение отдельно. Вы выбираете, какие изменения применить';

  @override
  String get cloudSyncGuideHowItem3 => 'В облаке хранится только последняя отправленная копия, без истории версий';

  @override
  String get cloudSyncGuideCorrect => 'Рекомендации';

  @override
  String get cloudSyncGuideCorrectItem1 => 'Вносите изменения на одном устройстве за раз и отправляйте их в облако, когда закончите';

  @override
  String get cloudSyncGuideCorrectItem2 => 'Прежде чем вносить изменения на другом устройстве, скачайте на него данные из облака';

  @override
  String get cloudSyncGuideCorrectItem3 => 'Внимательно проверьте каждое изменение, прежде чем применять его';

  @override
  String get cloudSyncGuideCorrectItem4 => 'Придерживайтесь порядка: внести изменения → отправить → сменить устройство → скачать → внести изменения';

  @override
  String get cloudSyncGuideWrong => 'Чего избегать';

  @override
  String get cloudSyncGuideWrongItem1 => 'Не редактируйте одну ведомость одновременно на двух устройствах: данные, отправленные позже, перезапишут те, что отправлены раньше';

  @override
  String get cloudSyncGuideWrongItem2 => 'Не скачивайте данные сразу после отправки: облачному сервису может потребоваться от нескольких секунд до нескольких минут на синхронизацию';

  @override
  String get cloudSyncGuideWrongItem3 => 'Не откладывайте синхронизацию надолго: при скачивании сразу большого числа изменений легко пропустить важные';

  @override
  String get cloudSyncGuideLimitations => 'Известные ограничения';

  @override
  String get cloudSyncGuideLimitItem1 => 'Нет синхронизации в реальном времени: отправлять и скачивать данные нужно вручную';

  @override
  String get cloudSyncGuideLimitItem2 => 'Изменения не объединяются автоматически: в облаке остаются данные последней отправки';

  @override
  String get cloudSyncGuideLimitItem3 => 'Задержка в облаке: в зависимости от сервиса данные могут появиться на других устройствах через несколько секунд или минут после отправки';

  @override
  String get cloudSyncGuideLimitItem4 => 'Без вложений: изображения из транзакций не синхронизируются. Их можно экспортировать отдельно в разделе «Управление данными»';

  @override
  String get mineMultiDeviceSyncTitle => 'Синхронизация устройств';

  @override
  String get mineMultiDeviceSyncSubtitle => 'Проверять изменения в облаке при открытии страницы';

  @override
  String get appLockTitle => 'Блокировка приложения';

  @override
  String get appLockDesc => 'Защита данных с помощью PIN-кода и биометрии';

  @override
  String get appLockEnable => 'Включить блокировку';

  @override
  String get appLockEnableDesc => 'Проверять личность при запуске и возврате в приложение';

  @override
  String get appLockSetPin => 'Задать PIN-код';

  @override
  String get appLockChangePin => 'Изменить PIN-код';

  @override
  String get appLockVerifyPin => 'Проверить PIN-код';

  @override
  String get appLockVerifyCurrentPin => 'Введите текущий PIN-код';

  @override
  String get appLockSetNewPin => 'Задайте новый PIN-код';

  @override
  String get appLockConfirmPin => 'Введите PIN-код ещё раз';

  @override
  String get appLockEnterPin => 'Введите PIN-код';

  @override
  String get appLockPinSetSuccess => 'PIN-код задан';

  @override
  String get appLockDisabled => 'Блокировка отключена';

  @override
  String get appLockBiometric => 'Разблокировка по биометрии';

  @override
  String get appLockBiometricDesc => 'Разблокировка с помощью Face ID или отпечатка пальца';

  @override
  String get appLockBiometricReason => 'Подтвердите личность, чтобы разблокировать BeeCount';

  @override
  String get appLockTimeout => 'Автоблокировка через';

  @override
  String get appLockTimeoutImmediate => 'Сразу';

  @override
  String get appLockTimeout1Min => 'Через 1 минуту';

  @override
  String get appLockTimeout5Min => 'Через 5 минут';

  @override
  String get appLockTimeout15Min => 'Через 15 минут';

  @override
  String get creditCardSettings => 'Настройки кредитной карты';

  @override
  String get accountTabValuation => 'Оценка активов';

  @override
  String get creditCardDaysRequired => 'Выберите день выписки и срок платежа';

  @override
  String get creditLimit => 'Кредитный лимит';

  @override
  String get creditLimitHint => 'Введите кредитный лимит';

  @override
  String get billingDay => 'День выписки';

  @override
  String get paymentDueDay => 'День платежа';

  @override
  String get creditUsed => 'Использовано';

  @override
  String get creditAvailable => 'Примерно доступно';

  @override
  String get creditCardOwed => 'Текущий долг';

  @override
  String dayOfMonth(int day) {
    return '$day-го числа каждого месяца';
  }

  @override
  String get creditCardReminderTitle => 'Напоминание о платеже';

  @override
  String get creditCardReminderDesc => 'Напоминать до срока платежа';

  @override
  String creditCardReminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'За $days дня',
      many: 'За $days дней',
      few: 'За $days дня',
      one: 'За $days день',
    );
    return '$_temp0';
  }

  @override
  String get creditCardInitialBalanceHint => 'Текущий долг (отрицательное число)';

  @override
  String get selectDay => 'Выбрать день';

  @override
  String get accountBankName => 'Банк';

  @override
  String get accountBankNameHint => 'Например: ICBC';

  @override
  String get accountCardLastFour => 'Последние 4 цифры карты';

  @override
  String get accountCardLastFourHint => 'Например: 1234';

  @override
  String get accountNote => 'Заметка';

  @override
  String get accountNoteHint => 'Добавить заметку';

  @override
  String get accountMetaInfo => 'О счёте';

  @override
  String get accountBalanceTrend => 'Динамика баланса';

  @override
  String get accountCategoryBreakdown => 'Разбивка по категориям';

  @override
  String get accountCategoryExpense => 'Расход';

  @override
  String get accountCategoryIncome => 'Доход';

  @override
  String get accountNoMoreData => 'Больше данных нет';

  @override
  String get totalAssets => 'Всего активов';

  @override
  String get totalLiabilities => 'Всего обязательств';

  @override
  String get assetAccounts => 'Счета активов';

  @override
  String get liabilityAccounts => 'Счета обязательств';

  @override
  String get assetComposition => 'Структура активов';

  @override
  String get accountTypeInvestment => 'Инвестиции';

  @override
  String get accountTypeLoan => 'Кредит';

  @override
  String get accountTypeReceivable => 'Долги вам';

  @override
  String get accountTypeRealEstate => 'Недвижимость';

  @override
  String get accountTypeVehicle => 'Транспорт';

  @override
  String get accountTypeInsurance => 'Страхование';

  @override
  String get accountTypeSocialFund => 'Жилищный и социальный фонды';

  @override
  String get valuationCurrentValue => 'Текущая стоимость';

  @override
  String get valuationCurrentDebt => 'Текущий долг';

  @override
  String get valuationUpdateValue => 'Обновить стоимость';

  @override
  String get valuationUpdateDebt => 'Обновить долг';

  @override
  String valuationLastUpdated(String date) {
    return 'Последнее обновление: $date';
  }

  @override
  String get valuationAccountHint => 'Введите текущую стоимость';

  @override
  String get valuationDebtHint => 'Введите текущую сумму долга';

  @override
  String get accountGroupTradable => 'Повседневные счета';

  @override
  String get accountGroupValuation => 'Активы и обязательства';

  @override
  String creditCardBillingInfo(int billingDay, int paymentDueDay) {
    return 'Выписка: $billingDay-го числа · Платёж: до $paymentDueDay-го числа';
  }

  @override
  String creditCardDaysUntilPayment(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'До платежа $days дня',
      many: 'До платежа $days дней',
      few: 'До платежа $days дня',
      one: 'До платежа $days день',
    );
    return '$_temp0';
  }

  @override
  String get creditCardPaymentDueToday => 'Платёж нужно внести сегодня';

  @override
  String get creditCardQuickRepay => 'Записать погашение';

  @override
  String get budgetManagement => 'Бюджет';

  @override
  String get budgetManagementDesc => 'Планируйте бюджет на месяц и контролируйте расходы';

  @override
  String get budgetSetupHint => 'Установите бюджет, чтобы контролировать расходы за месяц';

  @override
  String get budgetSetupAction => 'Настроить';

  @override
  String get syncHealthTitle => 'Статус синхронизации';

  @override
  String get cloudSyncHelpTitle => 'Как работает синхронизация · Почему она зависает';

  @override
  String get cloudSyncHelpModesTitle => 'Три режима синхронизации';

  @override
  String get cloudSyncHelpModesBody => '• Синхронизация изменений (автоматическая): когда вы добавляете или меняете транзакцию, передаётся только это изменение. Это быстро и не требует действий с вашей стороны. В обычной работе используется именно этот режим.\n• Полная отправка: при первом включении облачной синхронизации или если в облаке ещё нет данных этой ведомости, все данные с устройства отправляются в облако за один раз.\n• Полное скачивание: на новом устройстве, после переустановки приложения или при отсутствии данных на устройстве всё скачивается из облака.';

  @override
  String get cloudSyncHelpWhenFullTitle => 'Когда нужна полная синхронизация?';

  @override
  String get cloudSyncHelpWhenFullBody => 'Полная синхронизация запускается автоматически, только если на устройстве или в облаке нет данных: при первом включении синхронизации, на новом устройстве, после переустановки или очистки данных. Пока данные есть в обоих местах, синхронизируются только изменения. Чтобы запустить полную синхронизацию заново, сначала нужно очистить данные там, куда их нужно перенести.';

  @override
  String get cloudSyncHelpStuckTitle => 'Почему синхронизация зависает';

  @override
  String get cloudSyncHelpStuckBody => '• Полную отправку или скачивание нельзя продолжить с места остановки: если пропадёт сеть или система закроет приложение в фоне, передача начнётся заново. Если данных много, подключитесь к стабильной сети (лучше к Wi-Fi) и не переключайтесь на другое приложение до завершения передачи.\n• Синхронизация изменений может возобновляться после прерывания, поэтому в обычном режиме таких проблем нет.';

  @override
  String get cloudSyncHelpTroubleshootTitle => 'Устранение неполадок';

  @override
  String get cloudSyncHelpTroubleshootBody => '• Потяните эту страницу вниз, чтобы запустить «Глубокую проверку» и сравнить данные на устройстве и в облаке.\n• Если проблема осталась, откройте «Журнал событий». Там можно посмотреть ход синхронизации и причины сбоев, чтобы сообщить о проблеме.';

  @override
  String get cloudSyncHelpOpenLogCenter => 'Открыть журнал событий';

  @override
  String syncHealthCheckFailed(String msg) {
    return 'Не удалось проверить: $msg';
  }

  @override
  String get syncHealthHasDiff => 'Обнаружены различия, данные синхронизированы автоматически';

  @override
  String get syncHealthInSync => 'Данные на устройстве и в облаке совпадают';

  @override
  String get syncHealthGroupCurrentLedger => 'Текущая ведомость';

  @override
  String get syncHealthGroupAll => 'Все ведомости';

  @override
  String get syncHealthRowTx => 'Транзакции';

  @override
  String get syncHealthRowAttachment => 'Вложения';

  @override
  String get syncHealthRowCategoryIcon => 'Значки категорий';

  @override
  String get syncHealthRowBudget => 'Бюджеты';

  @override
  String get syncHealthRowAccount => 'Счета';

  @override
  String get syncHealthRowCategory => 'Категории';

  @override
  String get syncHealthRowTag => 'Теги';

  @override
  String get syncHealthRowUnpushed => 'Неотправленные изменения';

  @override
  String syncHealthValue(int local, int remote) {
    return 'На устройстве: $local · В облаке: $remote';
  }

  @override
  String syncHealthValueRemoteMissing(int local) {
    return 'На устройстве: $local · В облаке: —';
  }

  @override
  String get twofaChallengeTitle => 'Двухфакторная аутентификация';

  @override
  String get twofaMethodTotp => 'Код';

  @override
  String get twofaMethodRecovery => 'Код восстановления';

  @override
  String get twofaTotpHint => 'Введите шестизначный код из приложения-аутентификатора (Google Authenticator, 1Password, Authy и др.).';

  @override
  String get twofaRecoveryHint => 'Введите код восстановления, сохранённый при включении двухфакторной аутентификации (например, abcd-efgh). Каждый код можно использовать один раз.';

  @override
  String get twofaTotpInputPlaceholder => 'Шестизначный код';

  @override
  String get twofaRecoveryInputPlaceholder => 'Код восстановления';

  @override
  String twofaCountdown(String time) {
    return 'Осталось: $time';
  }

  @override
  String get twofaVerifyButton => 'Подтвердить';

  @override
  String get twofaStatusTitle => 'Двухфакторная аутентификация';

  @override
  String get twofaStatusEnabled => 'Включена ✓';

  @override
  String get twofaStatusDisabled => 'Не включена';

  @override
  String twofaStatusEnabledAt(String date) {
    return 'Дата включения: $date';
  }

  @override
  String get twofaStatusManageHint => 'Включить или выключить защиту и создать новые коды восстановления можно в веб-версии';

  @override
  String get twofaStatusOpenWeb => 'Включить в веб-версии →';

  @override
  String get sharedRoleOwner => 'Владелец';

  @override
  String get sharedRoleEditor => 'Редактор';

  @override
  String get sharedRoleViewer => 'Наблюдатель';

  @override
  String get commonCopied => 'Скопировано';

  @override
  String get commonRemove => 'Убрать';

  @override
  String get sharedJoinPageTitle => 'Присоединиться к ведомости';

  @override
  String get sharedJoinPageSubtitle => 'Введите код приглашения или откройте ссылку';

  @override
  String get sharedJoinEnterCode => 'Ввести код приглашения';

  @override
  String get sharedJoinEnterCodeHint => '6 символов: заглавные буквы и цифры. Если открыть ссылку-приглашение, этот шаг не нужен.';

  @override
  String get sharedJoinPreviewButton => 'Проверить код';

  @override
  String get sharedJoinAcceptButton => 'Присоединиться';

  @override
  String sharedJoinInvitedBy(String name) {
    return 'Вас приглашает $name';
  }

  @override
  String sharedJoinRoleLine(String role) {
    return 'Роль: $role';
  }

  @override
  String sharedJoinExpiresInMinutes(int n) {
    return 'Действует ещё $n мин';
  }

  @override
  String sharedJoinExpiresInHours(int n) {
    return 'Действует ещё $n ч';
  }

  @override
  String sharedJoinExpiresInDays(int n) {
    return 'Действует ещё $n дн.';
  }

  @override
  String sharedJoinSuccess(String name) {
    return 'Вы присоединились к ведомости «$name»';
  }

  @override
  String get sharedJoinCodeFormatError => 'Код приглашения должен состоять из 6 букв или цифр.';

  @override
  String get sharedJoinInvalidOrExpired => 'Код приглашения недействителен или просрочен. Попросите новый код у того, кто вас пригласил.';

  @override
  String get sharedJoinAlreadyMember => 'Вы уже участвуете в этой ведомости.';

  @override
  String get sharedJoinMemberLimit => 'Достигнут лимит участников ведомости. Обратитесь к владельцу.';

  @override
  String get sharedInvitePageTitle => 'Приглашение участника';

  @override
  String get sharedInviteFormRole => 'Роль';

  @override
  String get sharedInviteFormExpiry => 'Срок действия';

  @override
  String sharedInviteExpiryHours(int n) {
    return '$n ч';
  }

  @override
  String sharedInviteExpiryDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n дня',
      many: '$n дней',
      few: '$n дня',
      one: '$n день',
    );
    return '$_temp0';
  }

  @override
  String get sharedInviteGenerate => 'Создать код приглашения';

  @override
  String get sharedInviteGenerateAnother => 'Создать другой код';

  @override
  String get sharedInviteCopyCode => 'Скопировать код';

  @override
  String get sharedInviteCopyLink => 'Скопировать ссылку';

  @override
  String get sharedInviteShareLink => 'Поделиться ссылкой';

  @override
  String sharedInviteExpiresAt(String dt) {
    return 'Действует до $dt';
  }

  @override
  String get sharedInviteWarning => '⚠️ Не публикуйте коды приглашений в открытых чатах и соцсетях. Любой, у кого есть код, может присоединиться к ведомости. Если код попал к посторонним, отзовите его на экране «Участники» и создайте новый.';

  @override
  String get sharedInviteInstruction => 'Отправьте код или короткую ссылку. После установки BeeCount получатель сможет открыть ссылку или ввести код в разделе «Профиль → Присоединиться к ведомости».';

  @override
  String sharedInviteShareText(String ledger, String code, String url) {
    return 'Приглашаю вас в совместную ведомость «$ledger» в BeeCount.\n\nКод: $code\nСсылка: $url\n\nОткройте ссылку или выберите «Профиль → Присоединиться к ведомости» в BeeCount и введите код.';
  }

  @override
  String get sharedMembersPageTitle => 'Участники';

  @override
  String get sharedMembersYou => 'вы';

  @override
  String get sharedMembersInviteCta => 'Пригласить участника';

  @override
  String get sharedMembersLeaveCta => 'Покинуть ведомость';

  @override
  String get sharedMembersLeaveTitle => 'Выход из ведомости';

  @override
  String sharedMembersLeaveConfirm(String name) {
    return 'После выхода из ведомости «$name» вы потеряете доступ к её транзакциям. Продолжить?';
  }

  @override
  String get sharedMembersLeaveDone => 'Вы покинули ведомость';

  @override
  String get sharedMembersRemoveTitle => 'Удаление участника';

  @override
  String get sharedMembersRemoveCta => 'Удалить участника';

  @override
  String sharedMembersRemoveConfirm(String name) {
    return 'Удалить участника «$name»? Доступ к ведомости будет закрыт сразу.';
  }

  @override
  String get sharedMembersRemoved => 'Участник удалён';

  @override
  String get sharedMembersTransferTitle => 'Передача прав владельца';

  @override
  String get sharedMembersTransferTo => 'Передать права участнику';

  @override
  String sharedMembersTransferConfirm(String name) {
    return 'Передать права владельца участнику «$name»? Вы станете редактором и больше не сможете приглашать участников, переименовывать или удалять ведомость.';
  }

  @override
  String get sharedMembersTransferConfirmCta => 'Передать';

  @override
  String get sharedMembersTransferDone => 'Права владельца переданы';

  @override
  String sharedTxRecordedBy(String name) {
    return 'автор: $name';
  }

  @override
  String sharedTxCreatedBy(String name) {
    return 'Автор: $name';
  }

  @override
  String sharedTxEditedBy(String name) {
    return 'Последнее изменение: $name';
  }

  @override
  String sharedTxCreatedAndEditedBy(String name) {
    return 'Автор и редактор: $name';
  }

  @override
  String get sharedRequiresCloudSync => 'Сначала включите облачную синхронизацию';

  @override
  String get sharedMembersStatsTitle => 'Доходы и расходы участников';

  @override
  String get sharedMembersStatsEmpty => 'За этот период транзакций пока нет';

  @override
  String get sharedMembersStatsLoading => 'Загрузка…';

  @override
  String get sharedMembersStatsIncome => 'Доходы';

  @override
  String get sharedMembersStatsExpense => 'Расходы';

  @override
  String sharedMembersStatsTxCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count транзакции',
      many: '$count транзакций',
      few: '$count транзакции',
      one: '$count транзакция',
    );
    return '$_temp0';
  }

  @override
  String get maintenanceOrphanCleanupTitle => 'Очистка данных';

  @override
  String get maintenanceOrphanCleanupSubtitle => 'Найти и удалить локальные данные без связей';

  @override
  String get maintenanceOrphanRescan => 'Проверить снова';

  @override
  String get maintenanceOrphanEmpty => 'Локальные данные в порядке: элементов без связей нет';

  @override
  String get maintenanceOrphanGroupDb => 'Записи БД без связей';

  @override
  String get maintenanceOrphanGroupFile => 'Файлы без связей';

  @override
  String get maintenanceOrphanGroupSync => 'Данные синхронизации без связей';

  @override
  String maintenanceOrphanSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Найдено $count проблемы',
      many: 'Найдено $count проблем',
      few: 'Найдены $count проблемы',
      one: 'Найдена $count проблема',
    );
    return '$_temp0';
  }

  @override
  String maintenanceOrphanSummarySize(String size) {
    return 'Можно освободить около $size';
  }

  @override
  String get maintenanceOrphanSelectAll => 'Выбрать всё';

  @override
  String get maintenanceOrphanDeselectAll => 'Снять выбор';

  @override
  String get maintenanceOrphanDeleteOne => 'Удалить';

  @override
  String maintenanceOrphanSelectedHint(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get maintenanceOrphanCleanSelected => 'Удалить выбранное';

  @override
  String get maintenanceOrphanConfirmTitle => 'Подтверждение очистки';

  @override
  String maintenanceOrphanConfirmDeleteOne(String title) {
    return 'Удалить «$title»? Это действие нельзя отменить.';
  }

  @override
  String maintenanceOrphanConfirmDeleteBatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалить $count выбранного элемента?',
      many: 'Удалить $count выбранных элементов?',
      few: 'Удалить $count выбранных элемента?',
      one: 'Удалить $count выбранный элемент?',
    );
    return '$_temp0 Это действие нельзя отменить.';
  }

  @override
  String maintenanceOrphanCleanSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалено $count элемента',
      many: 'Удалено $count элементов',
      few: 'Удалены $count элемента',
      one: 'Удалён $count элемент',
    );
    return '$_temp0';
  }

  @override
  String maintenanceOrphanCleanPartial(int ok, int fail) {
    return 'Удалено: $ok, не удалось удалить: $fail';
  }

  @override
  String get syncProgressTitle => 'Синхронизация';

  @override
  String syncProgressCount(int applied, int total) {
    return '$applied / $total';
  }

  @override
  String get exchangeRatePageTitle => 'Курсы валют';

  @override
  String get exchangeRateEntrySubtitle => 'Курсы загружаются автоматически, но их можно изменить вручную';

  @override
  String get baseCurrencyLabel => 'Основная валюта';

  @override
  String get rateSourceAuto => 'Авто';

  @override
  String get rateSourceManual => 'Вручную';

  @override
  String rateUpdatedAt(String date) {
    return 'Обновлено: $date';
  }

  @override
  String get rateNotFetched => 'Курс не загружен';

  @override
  String get rateTapToSet => 'Нажмите, чтобы задать курс';

  @override
  String get rateEditTitle => 'Изменение курса';

  @override
  String rateInverseHint(String base, String rate, String quote) {
    return 'Обратный курс: 1 $base ≈ $rate $quote';
  }

  @override
  String get rateResetToAuto => 'Вернуть автокурс';

  @override
  String get rateRefreshSuccess => 'Курсы обновлены';

  @override
  String get rateRefreshFailed => 'Не удалось загрузить курсы. Их можно задать вручную';

  @override
  String get ratesEmptyHint => 'Курсы появятся здесь, когда у ваших счетов будут разные валюты';

  @override
  String get rateDisclaimer => 'Источник: открытые данные о курсах валют, обновляемые ежедневно. Пересчёт справочный: курсы могут отличаться от банковских.';

  @override
  String convertedNetWorth(String currency) {
    return 'Чистые активы (в $currency)';
  }

  @override
  String convertedFootnote(String date) {
    return 'Пересчёт по курсам на $date. Нажмите, чтобы изменить курсы';
  }

  @override
  String convertedPartialWarning(String currencies) {
    return 'Нет пересчёта для $currencies. Нажмите, чтобы задать курсы';
  }

  @override
  String get unconvertedBadge => 'Без пересчёта';

  @override
  String get commonDetail => 'Подробнее';

  @override
  String get conversionDetailTitle => 'Детали пересчёта';

  @override
  String get assetConversionToggle => 'Пересчитать в основную валюту';

  @override
  String rateManualApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Применено $count курса, заданного вручную',
      many: 'Применено $count курсов, заданных вручную',
      few: 'Применены $count курса, заданных вручную',
      one: 'Применён $count курс, заданный вручную',
    );
    return '$_temp0';
  }

  @override
  String get netWorthTrendTitle => 'Динамика чистых активов';

  @override
  String get netWorthTrend3M => '3 мес.';

  @override
  String get netWorthTrend6M => '6 мес.';

  @override
  String get netWorthTrend12M => '12 мес.';

  @override
  String get netWorthTrendAll => 'Всё';

  @override
  String get netWorthTrendLineNet => 'Чистые активы';

  @override
  String get netWorthTrendLineAssets => 'Всего активов';

  @override
  String get netWorthTrendLineLiabilities => 'Всего обязательств';

  @override
  String get netWorthTrendMultiCurrencyNote => 'Суммы пересчитаны в основную валюту по текущим курсам. Счета без курса не учтены.';

  @override
  String get txFlagExcludeFromStats => 'Исключить из доходов и расходов';

  @override
  String get txFlagExcludeFromBudget => 'Не учитывать в бюджете';

  @override
  String get txFlagMoreOptions => 'Другие настройки';

  @override
  String get txFlagDialogTitle => 'Настройки учёта транзакции';

  @override
  String get txFlagExcludeFromStatsHint => 'Не влияет на статистику доходов и расходов, но учитывается в балансе счёта';

  @override
  String get txFlagExcludeFromBudgetHint => 'Не уменьшает остаток бюджета';

  @override
  String get txFlagExcludedTag => 'Вне статистики';

  @override
  String get txFlagBudgetExcludedTag => 'Вне бюджета';

  @override
  String get txCurrencyLabel => 'Валюта';

  @override
  String get txRateLabel => 'Курс';

  @override
  String get transactionDoubleTapHint => 'Дважды нажмите для повтора';

  @override
  String get transactionSavedNextCategory => 'Сохранено. Выберите категорию для следующей транзакции.';

  @override
  String txConvertedPreview(Object amount, Object currency) {
    return '≈ $amount $currency';
  }

  @override
  String get txRateMissingHint => 'Укажите курс для этой транзакции перед сохранением';

  @override
  String get txCrossCurrencyTransferBlocked => 'Переводы между счетами в разных валютах пока не поддерживаются. Добавьте две транзакции или используйте счета в одной валюте.';

  @override
  String get ledgerBaseCurrencyLabel => 'Основная валюта';

  @override
  String statsConvertedFootnote(Object currency) {
    return 'Суммы в иностранной валюте пересчитаны в $currency по курсам на момент ввода транзакций';
  }

  @override
  String get ledgerCurrencyChangeRecalcHint => 'При смене основной валюты все прошлые транзакции будут пересчитаны по текущим курсам';

  @override
  String get recalcForeignTxBanner => 'В этой ведомости есть транзакции в иностранной валюте без пересчёта';

  @override
  String get recalcForeignTxAction => 'Пересчитать по текущим курсам';

  @override
  String recalcForeignTxDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Пересчитано $count транзакции в иностранной валюте',
      many: 'Пересчитано $count транзакций в иностранной валюте',
      few: 'Пересчитаны $count транзакции в иностранной валюте',
      one: 'Пересчитана $count транзакция в иностранной валюте',
    );
    return '$_temp0';
  }

  @override
  String get txCurrencyPickerTitle => 'Выбор валюты';

  @override
  String recalcSyncCountHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Будет пересчитано и синхронизировано $count транзакции',
      many: 'Будет пересчитано и синхронизировано $count транзакций',
      few: 'Будут пересчитаны и синхронизированы $count транзакции',
      one: 'Будет пересчитана и синхронизирована $count транзакция',
    );
    return '$_temp0';
  }

  @override
  String get exportCsvHeaderCurrency => 'Валюта';

  @override
  String get importFieldCurrency => 'Валюта';

  @override
  String get currencyMOP => 'Патака Макао';

  @override
  String get currencyMNT => 'Монгольский тугрик';

  @override
  String get currencyKPW => 'Северокорейская вона';

  @override
  String get currencyKHR => 'Камбоджийский риель';

  @override
  String get currencyLAK => 'Лаосский кип';

  @override
  String get currencyBND => 'Брунейский доллар';

  @override
  String get currencyNPR => 'Непальская рупия';

  @override
  String get currencyBTN => 'Бутанский нгултрум';

  @override
  String get currencyMVR => 'Мальдивская руфия';

  @override
  String get currencyAFN => 'Афганский афгани';

  @override
  String get currencyUZS => 'Узбекский сум';

  @override
  String get currencyTJS => 'Таджикский сомони';

  @override
  String get currencyTMT => 'Туркменский манат';

  @override
  String get currencyKGS => 'Киргизский сом';

  @override
  String get currencyQAR => 'Катарский риал';

  @override
  String get currencyKWD => 'Кувейтский динар';

  @override
  String get currencyBHD => 'Бахрейнский динар';

  @override
  String get currencyOMR => 'Оманский риал';

  @override
  String get currencyJOD => 'Иорданский динар';

  @override
  String get currencyLBP => 'Ливанский фунт';

  @override
  String get currencyIQD => 'Иракский динар';

  @override
  String get currencyIRR => 'Иранский риал';

  @override
  String get currencyYER => 'Йеменский риал';

  @override
  String get currencySYP => 'Сирийский фунт';

  @override
  String get currencyGEL => 'Грузинский лари';

  @override
  String get currencyAMD => 'Армянский драм';

  @override
  String get currencyAZN => 'Азербайджанский манат';

  @override
  String get currencyRON => 'Румынский лей';

  @override
  String get currencyBGN => 'Болгарский лев';

  @override
  String get currencyRSD => 'Сербский динар';

  @override
  String get currencyISK => 'Исландская крона';

  @override
  String get currencyMDL => 'Молдавский лей';

  @override
  String get currencyALL => 'Албанский лек';

  @override
  String get currencyMKD => 'Македонский денар';

  @override
  String get currencyBAM => 'Конвертируемая марка Боснии и Герцеговины';

  @override
  String get currencyGIP => 'Гибралтарский фунт';

  @override
  String get currencyGTQ => 'Гватемальский кетсаль';

  @override
  String get currencyHNL => 'Гондурасская лемпира';

  @override
  String get currencyNIO => 'Никарагуанская кордоба';

  @override
  String get currencyCRC => 'Костариканский колон';

  @override
  String get currencyPAB => 'Панамский бальбоа';

  @override
  String get currencyDOP => 'Доминиканское песо';

  @override
  String get currencyCUP => 'Кубинское песо';

  @override
  String get currencyJMD => 'Ямайский доллар';

  @override
  String get currencyTTD => 'Доллар Тринидада и Тобаго';

  @override
  String get currencyBSD => 'Багамский доллар';

  @override
  String get currencyBBD => 'Барбадосский доллар';

  @override
  String get currencyBZD => 'Белизский доллар';

  @override
  String get currencyHTG => 'Гаитянский гурд';

  @override
  String get currencyXCD => 'Восточно-карибский доллар';

  @override
  String get currencyKYD => 'Доллар Каймановых островов';

  @override
  String get currencyAWG => 'Арубанский флорин';

  @override
  String get currencyANG => 'Нидерландский антильский гульден';

  @override
  String get currencyBMD => 'Бермудский доллар';

  @override
  String get currencyUYU => 'Уругвайское песо';

  @override
  String get currencyPYG => 'Парагвайский гуарани';

  @override
  String get currencyBOB => 'Боливийский боливиано';

  @override
  String get currencyVES => 'Венесуэльский боливар';

  @override
  String get currencyGYD => 'Гайанский доллар';

  @override
  String get currencySRD => 'Суринамский доллар';

  @override
  String get currencyFJD => 'Доллар Фиджи';

  @override
  String get currencyPGK => 'Кина Папуа — Новой Гвинеи';

  @override
  String get currencySBD => 'Доллар Соломоновых Островов';

  @override
  String get currencyTOP => 'Тонганская паанга';

  @override
  String get currencyVUV => 'Вануатский вату';

  @override
  String get currencyWST => 'Самоанская тала';

  @override
  String get currencyXPF => 'Тихоокеанский франк';

  @override
  String get currencyKES => 'Кенийский шиллинг';

  @override
  String get currencyGHS => 'Ганский седи';

  @override
  String get currencyMAD => 'Марокканский дирхам';

  @override
  String get currencyDZD => 'Алжирский динар';

  @override
  String get currencyTND => 'Тунисский динар';

  @override
  String get currencyLYD => 'Ливийский динар';

  @override
  String get currencyETB => 'Эфиопский быр';

  @override
  String get currencyUGX => 'Угандийский шиллинг';

  @override
  String get currencyTZS => 'Танзанийский шиллинг';

  @override
  String get currencyRWF => 'Руандийский франк';

  @override
  String get currencyXAF => 'Франк КФА (Центральная Африка)';

  @override
  String get currencyXOF => 'Франк КФА (Западная Африка)';

  @override
  String get currencyMUR => 'Маврикийская рупия';

  @override
  String get currencyBWP => 'Ботсванская пула';

  @override
  String get currencyNAD => 'Намибийский доллар';

  @override
  String get currencyZMW => 'Замбийская квача';

  @override
  String get currencyMWK => 'Малавийская квача';

  @override
  String get currencyMZN => 'Мозамбикский метикал';

  @override
  String get currencyAOA => 'Ангольская кванза';

  @override
  String get currencyCDF => 'Конголезский франк';

  @override
  String get currencyGMD => 'Гамбийский даласи';

  @override
  String get currencyGNF => 'Гвинейский франк';

  @override
  String get currencyLRD => 'Либерийский доллар';

  @override
  String get currencySLE => 'Леоне Сьерра-Леоне';

  @override
  String get currencySDG => 'Суданский фунт';

  @override
  String get currencySSP => 'Южносуданский фунт';

  @override
  String get currencySOS => 'Сомалийский шиллинг';

  @override
  String get currencyDJF => 'Франк Джибути';

  @override
  String get currencyERN => 'Эритрейская накфа';

  @override
  String get currencyBIF => 'Бурундийский франк';

  @override
  String get currencyCVE => 'Эскудо Кабо-Верде';

  @override
  String get currencySTN => 'Добра Сан-Томе и Принсипи';

  @override
  String get currencySCR => 'Сейшельская рупия';

  @override
  String get currencyKMF => 'Франк Коморских Островов';

  @override
  String get currencyLSL => 'Лоти Лесото';

  @override
  String get currencySZL => 'Лилангени Эсватини';

  @override
  String get currencyMGA => 'Малагасийский ариари';

  @override
  String get currencyMRU => 'Мавританская угия';

  @override
  String get agentAssistantSettingsTitle => 'ИИ-ассистент';

  @override
  String get agentAssistantSettingsSubtitle => 'Настройте, как ассистент использует локальные данные и инструменты.';

  @override
  String get agentAssistantPermissionsEntry => 'Разрешения';

  @override
  String get agentAssistantPermissionsEntryDescription => 'Выберите, когда ассистенту нужно ваше разрешение на изменение данных.';

  @override
  String get agentAssistantMemoryEntry => 'Локальная память';

  @override
  String get agentAssistantMemoryEntryDescription => 'Просматривайте и удаляйте записи, которые хранятся только на этом устройстве.';

  @override
  String get agentAssistantActivityEntry => 'Недавние действия';

  @override
  String get agentAssistantActivityEntryDescription => 'Просматривайте, какие локальные инструменты запускались и с каким результатом.';

  @override
  String get agentExecutionDepthEntry => 'Лимит шагов';

  @override
  String get agentExecutionDepthEntryDescription => 'Чем выше лимит, тем больше шагов может выполнить ассистент, но тем дольше может занять ответ.';

  @override
  String agentExecutionDepthSelected(int turns) {
    String _temp0 = intl.Intl.pluralLogic(
      turns,
      locale: localeName,
      other: 'Не более $turns шага модели',
      many: 'Не более $turns шагов модели',
      few: 'Не более $turns шагов модели',
      one: 'Не более $turns шага модели',
    );
    return '$_temp0';
  }

  @override
  String get agentExecutionDepthChooseTitle => 'Глубина выполнения';

  @override
  String get agentExecutionDepthQuick => 'Быстро';

  @override
  String get agentExecutionDepthStandard => 'Стандартно';

  @override
  String get agentExecutionDepthDeep => 'Подробно';

  @override
  String get agentExecutionDepthCustom => 'Вручную';

  @override
  String get agentMemoryTitle => 'Локальная память';

  @override
  String get agentMemoryIntro => 'Эти сведения хранятся только на этом устройстве и используются только в текущей ведомости.';

  @override
  String get agentMemoryEmpty => 'Пока ничего не сохранено.';

  @override
  String get agentMemoryDeleteTitle => 'Удалить из памяти?';

  @override
  String get agentMemoryDeleteDescription => 'Ассистент больше не будет использовать эти сведения.';

  @override
  String get agentMemoryClear => 'Очистить память ведомости';

  @override
  String get agentMemoryClearTitle => 'Очистить всю память текущей ведомости?';

  @override
  String get agentMemoryClearDescription => 'Все сведения из локальной памяти этой ведомости будут удалены. Отменить это действие нельзя.';

  @override
  String get agentActivityTitle => 'Недавние действия';

  @override
  String get agentActivityIntro => 'История действий хранится только на этом устройстве и не синхронизируется.';

  @override
  String get agentActivityEmpty => 'Ассистент пока не выполнял никаких действий.';

  @override
  String get agentActivityCompleted => 'Завершено';

  @override
  String get agentActivityFailed => 'Ошибка';

  @override
  String get agentActivityRunning => 'Выполняется';

  @override
  String get agentActivityCancelled => 'Отменено';

  @override
  String get agentActivityTools => 'Инструменты';

  @override
  String get agentActivityToolCompleted => 'Завершено';

  @override
  String get agentActivityToolDenied => 'Отказано';

  @override
  String get agentActivityToolFailed => 'Ошибка';

  @override
  String get agentRunCancelled => 'Выполнение остановлено.';

  @override
  String get agentRunStop => 'Остановить';

  @override
  String get agentQueryValidationFailed => 'Не удалось исправить параметры запроса и получить надёжный результат. Попробуйте ещё раз.';

  @override
  String get annualReportInsightsTitle => 'Аналитика за год';

  @override
  String get annualReportInsightsSubtitle => 'Узнайте из отчёта, как вы тратите деньги';

  @override
  String get annualReportAveragePerRecord => 'Средний расход за транзакцию';

  @override
  String get annualReportAveragePerRecordDesc => 'Средняя сумма расходной транзакции';

  @override
  String get annualReportDailyAverage => 'Средний расход за день';

  @override
  String get annualReportDailyAverageDesc => 'Сколько в среднем вы тратите в день';

  @override
  String get annualReportMonthlyAverage => 'Средний расход за месяц';

  @override
  String get annualReportMonthlyAverageDesc => 'Сколько в среднем вы тратите в месяц';

  @override
  String get annualReportBusiestMonth => 'Самый активный месяц';

  @override
  String get annualReportBusiestMonthDesc => 'Месяц с наибольшим числом транзакций';

  @override
  String get annualReportCategoryCount => 'Категории расходов';

  @override
  String get annualReportCategoryCountDesc => 'Сколько категорий расходов вы использовали';

  @override
  String annualReportCategoryCountValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count категории',
      many: '$count категорий',
      few: '$count категории',
      one: '$count категория',
    );
    return '$_temp0';
  }

  @override
  String get annualReportSavingsRate => 'Доля сбережений';

  @override
  String get annualReportSavingsRatePositive => 'Какую долю дохода вы отложили за год';

  @override
  String get annualReportSavingsRateNegative => 'В этом году расходы превысили доходы';

  @override
  String get annualReportComparisonTitle => 'Доходы и расходы';

  @override
  String get annualReportComparisonSubtitle => 'Сравнение доходов и расходов по месяцам';

  @override
  String get annualReportHighestIncome => 'Пик доходов';

  @override
  String get annualReportHighestExpense => 'Пик расходов';

  @override
  String get annualReportConsistency => 'Серия дней учёта';

  @override
  String annualReportDaysValue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня',
      many: '$days дней',
      few: '$days дня',
      one: '$days день',
    );
    return '$_temp0';
  }

  @override
  String get annualReportSavingsPositive => 'Поздравляем с накоплениями';

  @override
  String get annualReportSavingsNegative => 'В этом году расходы превысили доходы';

  @override
  String get annualReportMonthlyExpenseTrend => 'Динамика расходов по месяцам';

  @override
  String get annualReportAchieved => 'Достигнуто';

  @override
  String get annualReportNotAchieved => 'Не достигнуто';

  @override
  String get annualReportDownloadHint => 'Отсканируйте код, чтобы скачать BeeCount и начать вести учёт';

  @override
  String get attachmentKeepOriginal => 'Сохранять оригиналы вложений';

  @override
  String get attachmentKeepOriginalDesc => 'Занимает больше места и расходует больше трафика при синхронизации';

  @override
  String get transactionCopyAction => 'Копировать как новую';

  @override
  String get transactionCopyUnavailable => 'Не удалось скопировать транзакцию. Проверьте ведомость и права доступа.';

  @override
  String get aiChatGenericFailure => 'Извините, что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get aiChatRecordSuccessOne => '✅ Транзакция добавлена';

  @override
  String aiChatRecordSuccessMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '✅ Добавлено $count транзакции',
      many: '✅ Добавлено $count транзакций',
      few: '✅ Добавлены $count транзакции',
      one: '✅ Добавлена $count транзакция',
    );
    return '$_temp0';
  }

  @override
  String get agentEmptyFinalReply => 'Готово.';

  @override
  String creditCardReminderDueSoonTitle(String accountName) {
    return 'Скоро платёж по счёту «$accountName»';
  }

  @override
  String creditCardReminderDueBody(int paymentDueDay) {
    return 'Дата платежа — $paymentDueDay-е число каждого месяца. Внесите платёж вовремя';
  }

  @override
  String get reminderBackupChannelName => 'Напоминание об учёте (резервный канал)';

  @override
  String get reminderBackupChannelDescription => 'Резервный канал для напоминаний об учёте';

  @override
  String get autoBillingChannelName => 'Распознавание скриншотов';

  @override
  String get autoBillingChannelDescription => 'Уведомления об автоматическом распознавании скриншотов';

  @override
  String get appLinkOpenVoiceBilling => 'Открыть голосовой ввод';

  @override
  String get appLinkOpenImageBilling => 'Открыть ввод по изображению';

  @override
  String get appLinkOpenCameraBilling => 'Открыть ввод по фото';

  @override
  String get appLinkOpenAiAssistant => 'Открыть ИИ-ассистент';

  @override
  String get appLinkOpenManualBilling => 'Открыть ручной ввод';

  @override
  String get appLinkNoTargetPage => 'Не указана целевая страница';

  @override
  String appLinkOpenPage(String page) {
    return 'Открыть страницу: $page';
  }

  @override
  String appLinkUnknownAction(String action) {
    return 'Неизвестное действие: $action';
  }

  @override
  String get appLinkNoLedger => 'Сначала выберите ведомость';

  @override
  String get appLinkMissingAmount => 'Транзакция не добавлена: введите корректную сумму';

  @override
  String get appLinkMissingCategory => 'Транзакция не добавлена: укажите категорию';

  @override
  String appLinkCategoryNotFound(String name) {
    return 'Транзакция не добавлена: категории «$name» нет';
  }

  @override
  String get appLinkTypeIncome => 'Доход';

  @override
  String get appLinkTypeExpense => 'Расход';

  @override
  String get appLinkTypeTransfer => 'Перевод';

  @override
  String appLinkRecorded(String type, String amount) {
    return 'Добавлена транзакция ($type): $amount';
  }

  @override
  String get appLinkRecordSuccess => 'Транзакция добавлена';

  @override
  String appLinkParamError(String message) {
    return 'Некорректные параметры: $message';
  }

  @override
  String appLinkRecordFailed(String error) {
    return 'Не удалось добавить транзакцию: $error';
  }

  @override
  String get appLinkTextDone => 'Текст обработан';

  @override
  String appLinkTextFailed(String error) {
    return 'Не удалось добавить транзакцию из текста: $error';
  }

  @override
  String get appLinkNoText => 'Текст не передан';

  @override
  String orphanBudgetTitle(String id) {
    return 'Бюджет № $id';
  }

  @override
  String orphanBudgetNoLedger(String type, String amount, String id) {
    return '$type · ¥$amount · ведомость удалена (id=$id)';
  }

  @override
  String orphanAttachmentRowTitle(String id) {
    return 'Запись о вложении № $id';
  }

  @override
  String orphanAttachmentNoTx(String fileName, String id) {
    return '$fileName · транзакция удалена (txId=$id)';
  }

  @override
  String orphanTagLinkTitle(String id) {
    return 'Связь с тегом № $id';
  }

  @override
  String orphanTagLinkNoTx(String txId, String tagId) {
    return 'транзакция удалена (txId=$txId, tagId=$tagId)';
  }

  @override
  String orphanTagLinkNoTag(String txId, String tagId) {
    return 'тег удалён (txId=$txId, tagId=$tagId)';
  }

  @override
  String orphanTxTitle(String id) {
    return 'Транзакция № $id';
  }

  @override
  String orphanTxNoMissing(String type, String amount, String missing) {
    return '$type · ¥$amount · удалено: $missing';
  }

  @override
  String orphanTxNoCategory(String type, String amount, String id) {
    return '$type · ¥$amount · категория удалена (categoryId=$id)';
  }

  @override
  String orphanSubcategoryTitle(String name, String id) {
    return 'Подкатегория «$name» № $id';
  }

  @override
  String orphanSubcategoryNoParent(String kind, String id) {
    return '$kind · родительская категория удалена (parentId=$id)';
  }

  @override
  String orphanBudgetNoCategory(String type, String amount, String id) {
    return '$type · ¥$amount · категория удалена (categoryId=$id)';
  }

  @override
  String orphanSharedSubcategoryTitle(String name) {
    return 'Совместная подкатегория «$name»';
  }

  @override
  String orphanSharedSubcategoryNoParent(String id) {
    return 'родительская категория удалена (parentSyncId=$id)';
  }

  @override
  String get orphanSharedTagOverrideTitle => 'Переопределение совместного тега';

  @override
  String orphanSharedTagNoTx(String txId, String tagId) {
    return 'транзакция удалена (txSyncId=$txId, tagSyncId=$tagId)';
  }

  @override
  String get orphanFileNoRef => 'В базе данных нет ссылки на файл вложения';

  @override
  String get orphanCustomIconNoRef => 'В базе данных нет ссылки на пользовательский значок категории';

  @override
  String get orphanSharedIconNoRef => 'В базе данных нет ссылки на кэш значка совместной категории';

  @override
  String orphanSyncChangeTitle(String id) {
    return 'Изменение для синхронизации № $id';
  }

  @override
  String orphanSyncChangeNoEntity(String entityType, String action, String id) {
    return '$entityType · $action · объект удалён (syncId=$id)';
  }

  @override
  String get customIconFileMissing => 'Файл изображения не найден';

  @override
  String get customIconFileTooLarge => 'Файл изображения слишком большой (макс. 5 МБ)';

  @override
  String get customIconUnsupportedFormat => 'Формат изображения не поддерживается';

  @override
  String get customIconCompressFailed => 'Не удалось сжать изображение';

  @override
  String customIconSaveFailed(String error) {
    return 'Не удалось сохранить значок: $error';
  }

  @override
  String get sharePosterAppText => 'BeeCount — простой учёт';

  @override
  String get sharePosterDefaultLedgerName => 'Основная ведомость';

  @override
  String get aiProviderNotConfiguredText => 'Поставщик для текстового чата не настроен';

  @override
  String aiProviderMissingTextModelFor(String name) {
    return 'У поставщика «$name» не настроена текстовая модель';
  }

  @override
  String get aiProviderNotConfiguredTextUsable => 'Нет доступного поставщика для текстового чата';

  @override
  String get aiProviderNotConfiguredVision => 'Поставщик для анализа изображений не настроен';

  @override
  String get aiProviderNotConfiguredSpeech => 'Поставщик для распознавания речи не настроен';

  @override
  String get aiProviderNoVisionModel => 'Модель для изображений не настроена';

  @override
  String get aiProviderNoSpeechModel => 'Речевая модель не настроена';

  @override
  String get aiProviderEmptyResponse => 'API вернул пустой ответ';

  @override
  String get xlsxEmptyFile => 'Файл Excel пуст или не читается';

  @override
  String get xlsxEmptySheet => 'Лист пуст';

  @override
  String xlsxParseFailed(String error) {
    return 'Не удалось обработать файл Excel: $error';
  }

  @override
  String rateFetchAllSourcesFailed(String errors) {
    return 'Не удалось получить курсы ни из одного источника: $errors';
  }

  @override
  String rateFetchSourcePayloadInvalid(String source) {
    return 'Источник курсов $source вернул данные в неожиданном формате';
  }

  @override
  String donationPurchaseFailedWith(String error) {
    return 'Не удалось совершить покупку: $error';
  }

  @override
  String get donationPurchaseRequestFailed => 'Не удалось отправить запрос на покупку';

  @override
  String get donationUnknownError => 'Неизвестная ошибка';

  @override
  String get donationVerificationFailed => 'Не удалось подтвердить покупку';

  @override
  String donationRestoreFailed(String error) {
    return 'Не удалось восстановить покупки: $error';
  }

  @override
  String get updateDownloadDone => 'Готово';

  @override
  String get attachmentArchiveMissing => 'Архив не найден';

  @override
  String get attachmentArchiveInvalidFormat => 'Неверный формат архива: нет файла metadata.json';

  @override
  String get categoryPackageCompressFailed => 'Не удалось создать архив';

  @override
  String get categoryPackageFileMissing => 'Файл не существует';

  @override
  String get categoryPackageMissingYaml => 'Некорректный архив категорий: нет файла categories.yaml';

  @override
  String get categoryPackageInvalidFormat => 'Неверный формат файла настроек';

  @override
  String get configExportInvalidYaml => 'Неверный формат YAML';

  @override
  String get configExportTransferCategoryMissing => 'Категория переводов не найдена';

  @override
  String configExportFileMissing(String path) {
    return 'Файл не найден: $path';
  }

  @override
  String ledgerTargetIdExists(String id) {
    return 'ID целевой ведомости уже существует: $id';
  }

  @override
  String get ledgerMissing => 'Ведомость не существует';

  @override
  String get sharedLedgerBalanceRestricted => 'Участники совместной ведомости не могут менять баланс счетов';

  @override
  String get accountMissing => 'Счёт не существует';

  @override
  String get syncCloudUnavailable => 'Облачный сервис недоступен. Проверьте настройки или убедитесь, что вы вошли в аккаунт';

  @override
  String syncHealthLedgerMissing(String id) {
    return 'Ведомость $id не найдена на устройстве';
  }

  @override
  String get logExportTitle => '=== Экспорт журналов BeeCount ===';

  @override
  String logExportTime(String time) {
    return 'Время экспорта: $time';
  }

  @override
  String logExportCount(int count) {
    return 'Записей в журнале: $count';
  }

  @override
  String get creditCardOverpayment => 'Переплата';

  @override
  String get creditCardDebtHint => 'Укажите общую сумму долга положительным числом. Если долга нет, введите 0.';

  @override
  String get creditCardOverpaymentHint => 'Укажите положительную сумму, оставшуюся на карте после переплаты.';

  @override
  String get creditCardAmountInvalid => 'Введите корректную сумму: долг и переплата по кредитной карте не могут быть отрицательными.';

  @override
  String get creditCardReminderDueRequired => 'Укажите день платежа, прежде чем включать напоминания.';

  @override
  String get creditCardEstimateHint => 'Сумма рассчитана по транзакциям в приложении. Точную доступную сумму уточняйте в банке.';

  @override
  String get accountAllFlows => 'Все транзакции';

  @override
  String get accountOutflows => 'Расходы и исходящие переводы';

  @override
  String get accountInflows => 'Доходы и входящие переводы';

  @override
  String get positiveAssetBalance => 'Положительные остатки по активам';

  @override
  String get negativeAssetBalanceHint => 'Отрицательные остатки на счетах уменьшают общую сумму активов.';

  @override
  String get importAccountCurrencyPreview => 'Подтвердить валюты счетов';

  @override
  String get importAccountCurrencyPreviewHint => 'Счета создаются или подбираются по валюте транзакций в файле. Если у одноимённых счетов валюты различаются, транзакции распределяются по отдельным счетам без изменения существующих. Если валюта не указана, используется валюта существующего счёта, другая однозначно определяемая валюта счёта или валюта ведомости.';

  @override
  String get importCurrencyInvalid => 'Недопустимая валюта. Исправьте строку:';

  @override
  String get transactionReceiptAction => 'Создать квитанцию';

  @override
  String get transactionReceiptTitle => 'Квитанция по транзакции';

  @override
  String get transactionReceiptFields => 'Выберите, что показать в квитанции';

  @override
  String get transactionReceiptLedger => 'Ведомость';

  @override
  String get transactionReceiptTags => 'Теги';

  @override
  String get transactionReceiptFooter => 'Моменты жизни, бережно сохранённые';

  @override
  String get transactionReceiptUnavailable => 'Не удалось создать квитанцию. Проверьте, не удалена ли транзакция.';

  @override
  String get transactionReceiptShareFailed => 'Не удалось поделиться. Попробуйте ещё раз.';

  @override
  String get v4RecordingMoreCategories => 'Ещё категории';

  @override
  String get v4RecordingCalculationHint => 'Для расчётов: + − × ÷';

  @override
  String get v4RecordingSaveNext => 'Ещё одну';

  @override
  String get v4RecordingClearAmount => 'Очистить сумму';

  @override
  String get v4RecordingSelectCategory => 'Выберите категорию';

  @override
  String get v4RecordingSaveFailed => 'Не удалось сохранить. Попробуйте ещё раз.';

  @override
  String get v4RecordingCategoriesFailed => 'Не удалось загрузить категории';

  @override
  String get v4RecordingRetry => 'Повторить';

  @override
  String get v4RecordingDiscardTitle => 'Отменить ввод?';

  @override
  String get v4RecordingDiscardMessage => 'Сумма, заметка и выбранные параметры не сохранятся.';

  @override
  String get v4RateInvalid => 'Введите курс больше 0';

  @override
  String v4RecordingConvertedLabel(String currency) {
    return 'В $currency';
  }

  @override
  String get v4CategoryToolsTitle => 'Управление категориями';

  @override
  String get v4CategoryToolsHint => 'Сортировка, импорт, обмен и стандартные категории';

  @override
  String get v4AttachmentPending => 'Не сохранено';

  @override
  String get v4ClearSelection => 'Снять выбор';

  @override
  String get v4HomeAllTransactions => 'Все транзакции';

  @override
  String get v4HomeBatch => 'Выбрать';

  @override
  String get v4HomeMonthShare => 'Поделиться итогами месяца';

  @override
  String get v4HomeBrandShow => 'Показать логотип BeeCount';

  @override
  String get v4HomeBrandHide => 'Скрыть логотип BeeCount';

  @override
  String get v4HomeMonthExpense => 'Расходы за месяц';

  @override
  String get v4HomeMonthIncome => 'Доходы за месяц';

  @override
  String get v4HomeMonthBalance => 'Баланс за месяц';

  @override
  String get v4AmountsShow => 'Показать суммы';

  @override
  String get v4AmountsHide => 'Скрыть суммы';

  @override
  String get v4SearchTitle => 'Поиск транзакций';

  @override
  String get v4SearchRecent => 'Недавние запросы';

  @override
  String get v4SearchClearHistory => 'Очистить историю поиска';

  @override
  String get v4SearchInvert => 'Изменить выбор на обратный';

  @override
  String get v4SearchScope => 'Изменить область поиска';

  @override
  String get v4SearchOriginalAmount => 'Сумма в исходной валюте';

  @override
  String get v4SearchLedgerAmount => 'Сумма после пересчёта';

  @override
  String get v4SearchInvalidRange => 'Введите неотрицательные суммы и проверьте границы диапазона';

  @override
  String get v4SearchSetTags => 'Задать теги';

  @override
  String get v4SearchTagsSaved => 'Теги выбранных транзакций обновлены';

  @override
  String get v4SearchAll => 'Все';

  @override
  String get v4SearchHint => 'Поиск по заметкам, категориям, суммам и тегам';

  @override
  String get v4SearchFilterActive => 'Фильтры применены';

  @override
  String v4SearchSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Выбрано $count транзакции',
      many: 'Выбрано $count транзакций',
      few: 'Выбраны $count транзакции',
      one: 'Выбрана $count транзакция',
    );
    return '$_temp0';
  }

  @override
  String get v4DetailMonth => 'Этот месяц';

  @override
  String get v4DetailYear => 'Этот год';

  @override
  String get v4DetailCumulative => 'За всё время';

  @override
  String get v4DetailCustom => 'Свой период';

  @override
  String get v4DetailTrend => 'Накопленная сумма';

  @override
  String get v4DetailShare => 'Доля';

  @override
  String get v4DetailMissingCategory => 'Этой категории больше нет';

  @override
  String get v4DetailRecent => 'Недавние транзакции';

  @override
  String get v4DetailCollapse => 'Свернуть';

  @override
  String v4DetailCategoryChildren(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count подкатегории',
      many: '$count подкатегорий',
      few: '$count подкатегории',
      one: '$count подкатегория',
    );
    return 'Родительская категория · $_temp0';
  }

  @override
  String v4DetailAmountLabel(String period, String kind) {
    return '$kind · $period';
  }

  @override
  String v4DetailAllTransactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Показать все транзакции ($count)',
      many: 'Показать все $count транзакций',
      few: 'Показать все $count транзакции',
      one: 'Показать все транзакции ($count)',
    );
    return '$_temp0';
  }

  @override
  String v4DetailRecord(String name) {
    return 'Добавить транзакцию · $name';
  }

  @override
  String get v4MineCloudGroup => 'Облако и синхронизация';

  @override
  String get v4MineFeaturesGroup => 'Функции';

  @override
  String get v4MineHelpGroup => 'Справка и информация';

  @override
  String get v4MineSupportGroup => 'Поддержать нас';

  @override
  String get v4ConfigImportWarning => 'При импорте текущие настройки будут заменены. Сначала создайте их резервную копию.';

  @override
  String get v4CategoryPresetIcons => 'Стандартные значки';

  @override
  String get v4CategoryCommonIcons => 'Популярные';

  @override
  String get v4CategoryImageHint => 'Цвета и прозрачность сохранятся. Выберите изображение и обрежьте его до квадрата.';

  @override
  String get welcomePreferencesLater => 'Эти настройки можно изменить позже.';

  @override
  String get welcomeRestoreTitle => 'С возвращением.';

  @override
  String get welcomeRestoreDescription => 'Восстановите свои ведомости и продолжайте вести учёт.';

  @override
  String get welcomeReadyDescription => 'Ведите учёт спокойно: данные остаются под вашим контролем.';

  @override
  String get welcomeCloudLater => 'Сейчас ничего настраивать не нужно. Синхронизацию можно включить позже в разделе «Профиль → Облачный сервис».';

  @override
  String get welcomeSelectBackup => 'Выбрать резервную копию';

  @override
  String get welcomeRestoreContinue => 'Импортировать и продолжить';

  @override
  String get welcomeRestoreLedgersAccounts => 'Ведомости и счета';

  @override
  String get welcomeRestoreCategoriesTags => 'Категории и теги';

  @override
  String get welcomeRestoreSettings => 'Настройки приложения';

  @override
  String get welcomeAttachmentRestoreTitle => 'Верните и свои воспоминания.';

  @override
  String get welcomeAttachmentRestoreDescription => 'Восстановите чеки вместе с их привязкой к транзакциям или импортируйте их позже.';

  @override
  String get welcomeAttachmentBackupDescription => 'TAR.GZ · Чеки, скриншоты и другие вложения';

  @override
  String get welcomeImportAttachmentsContinue => 'Импортировать вложения и завершить';

  @override
  String get v4QuickAddSlideHint => 'Нажмите и удерживайте, затем проведите пальцем к нужному действию и отпустите';

  @override
  String get v4AccountDetailTitle => 'Сведения о счёте';

  @override
  String get v4AmountInvalid => 'Введите допустимую сумму';

  @override
  String get v4TagCategories => 'Связанные категории';

  @override
  String get v4TagRecord => 'Добавить транзакцию с тегом';

  @override
  String get v4TagDistribution => 'По категориям';

  @override
  String get v4TagOriginalLedgerTotals => 'Для итогов используются исходные суммы каждой ведомости';

  @override
  String get v4TagToolsTitle => 'Управление тегами';

  @override
  String get v4TagToolsHint => 'Добавление, импорт, создание стандартных тегов и очистка';

  @override
  String get v4TrendClosing => 'Баланс на конец';

  @override
  String get v4TrendOpening => 'Баланс на начало';

  @override
  String get v4TrendChange => 'Изменение за период';

  @override
  String get v4TrendChangeRate => 'Изменение в %';

  @override
  String get v4DataBills => 'Транзакции';

  @override
  String get v4DataCategories => 'Категории и теги';

  @override
  String get v4DataConfiguration => 'Настройки и хранилище';

  @override
  String get v4DataAttachments => 'Вложения';

  @override
  String get v4CustomIcons => 'Свои значки';

  @override
  String get v4AnalyticsTrend => 'Динамика доходов и расходов';

  @override
  String get v4AnalyticsShowRanking => 'Показать рейтинг категорий';

  @override
  String get v4AnalyticsShowPie => 'Показать диаграмму по категориям';

  @override
  String get v4AnalyticsView => 'Вид статистики';

  @override
  String get v4AnalyticsRecalculate => 'Пересчитать суммы';

  @override
  String get aiProviderShowKey => 'Показать ключ API';

  @override
  String get aiProviderHideKey => 'Скрыть ключ API';

  @override
  String get aiPromptShare => 'Поделиться подсказкой';

  @override
  String get aiPromptPaste => 'Вставить подсказку';

  @override
  String get v4AIChatSend => 'Отправить сообщение';

  @override
  String get v4RecurringLastGeneratedLabel => 'Последняя транзакция';

  @override
  String get v4TransactionDetailTitle => 'Детали транзакции';

  @override
  String get v4TransactionDetailSnapshot => 'Пересчёт на дату транзакции';

  @override
  String get v4TransactionDetailSnapshotRate => 'Курс на момент ввода';

  @override
  String v4DetailConvertedScope(String currency) {
    return 'Итоги пересчитаны в валюту текущей ведомости: $currency';
  }

  @override
  String v4DetailMissingConversion(int count, String currencies) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Не пересчитано $count транзакции',
      many: 'Не пересчитано $count транзакций',
      few: 'Не пересчитаны $count транзакции',
      one: 'Не пересчитана $count транзакция',
    );
    return '$_temp0 · $currencies. Итоги пока недоступны.';
  }

  @override
  String v4DetailRateDate(String date) {
    return 'Дата курса: $date';
  }

  @override
  String v4DetailRatesStale(String date) {
    return 'Курс старше 7 дней · $date';
  }

  @override
  String get v4ShareCardTitle => 'Карточка для публикации';

  @override
  String get v4ShareCardProfile => 'Мой профиль';

  @override
  String get v4InsightsCategoryShare => 'Доля категории';

  @override
  String get v4InsightsShareHint => 'Нажмите на категорию, чтобы узнать её долю в общей сумме';

  @override
  String get v4InsightsTapBar => 'Нажмите на столбец, чтобы узнать сумму';

  @override
  String get v4InsightsAverageTitle => 'Как считается среднее';

  @override
  String get v4InsightsAverageDays => 'Учитываются дни периода по сегодня включительно, даже если транзакций не было. Будущие дни не учитываются.';

  @override
  String get v4InsightsAverageMonths => 'Учитываются месяцы с начала года по текущий включительно, даже если транзакций не было. Будущие месяцы не учитываются.';

  @override
  String get v4InsightsAverageYears => 'Учитываются все годы, охваченные ведомостью, даже если транзакций не было. Будущие годы не учитываются.';

  @override
  String get v4InsightsDaysUnit => 'дн.';

  @override
  String get v4InsightsMonthsUnit => 'мес.';

  @override
  String get v4InsightsYearsUnit => 'г.';

  @override
  String get v4InsightsBalanceComposition => 'Доходы и расходы';

  @override
  String get v4InsightsBalanceEquation => 'Баланс = доходы − расходы';

  @override
  String get v4InsightsPreviousPeriod => 'Предыдущий период';

  @override
  String get v4InsightsNextPeriod => 'Следующий период';

  @override
  String get v4InsightsOtherCategories => 'Другие категории';

  @override
  String get v4InsightsSortedByAmount => 'По сумме';

  @override
  String get v4InsightsNoData => 'Выберите другой период или переключитесь между расходами, доходами и балансом на вкладках выше.';

  @override
  String v4InsightsTrendTitle(String type) {
    return 'Динамика: $type';
  }

  @override
  String v4InsightsAmountUnit(String currency) {
    return 'Валюта: $currency';
  }

  @override
  String get v4InsightsCollapseCategories => 'Свернуть категории';

  @override
  String v4InsightsAllCategories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Все категории ($count)',
      many: 'Все $count категорий',
      few: 'Все $count категории',
      one: 'Все категории ($count)',
    );
    return '$_temp0';
  }

  @override
  String get v4AssetsAllAccounts => 'Все счета';

  @override
  String get v4AssetsByCurrency => 'По валютам';

  @override
  String get v4AssetsUnifiedConversion => 'Итог в основной валюте';

  @override
  String get v4AssetsCurrencyView => 'Отображение сумм';

  @override
  String get v4AssetsHiddenIncluded => 'Скрытые счета по-прежнему учитываются в чистых активах.';

  @override
  String v4AssetsIncludesHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Учтено $count скрытого счёта',
      many: 'Учтено $count скрытых счетов',
      few: 'Учтены $count скрытых счёта',
      one: 'Учтён $count скрытый счёт',
    );
    return '$_temp0';
  }

  @override
  String get v4AssetsOrder => 'Порядок счетов';

  @override
  String get v4AssetsOrderHint => 'Меняйте порядок счетов внутри одного типа. Баланс не изменится.';

  @override
  String get v4AssetsSeparateCurrencyHint => 'Суммы показаны отдельно по каждой валюте и не складываются.';

  @override
  String get v4AssetsOriginal => 'Исходная валюта';

  @override
  String get v4AssetsDefaultExpense => 'Счёт для расходов по умолчанию';

  @override
  String get v4AssetsDefaultIncome => 'Счёт для доходов по умолчанию';

  @override
  String get v4AssetsTrend => 'Динамика';

  @override
  String get v4AssetsComposition => 'Состав';

  @override
  String get v4TransactionRowFieldsTitle => 'Поля транзакции';

  @override
  String v4TransactionRowMoreFields(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ещё $count поля',
      many: 'Ещё $count полей',
      few: 'Ещё $count поля',
      one: 'Ещё $count поле',
    );
    return '$_temp0';
  }

  @override
  String get v4TransactionRowReadOnly => 'Только чтение';

  @override
  String get v4TransactionRowAccess => 'Доступ';

  @override
  String get v4SharePosterProfileEyebrow => 'Как я веду учёт';

  @override
  String get v4SharePosterDayCaption => 'дн. осознанного учёта.';

  @override
  String get v4SharePosterProfileJourney => 'Вести учёт — маленькая привычка, которая остаётся с вами.';

  @override
  String get v4SharePosterPromoInvite => 'Давайте вести учёт каждый день.';

  @override
  String get v4SharePosterOpenSourceBody => 'Ваши данные остаются у вас. Наш код открыт.\nВместе мы делаем учёт проще.';

  @override
  String get v4SharePosterOpenSourceAction => 'Посмотреть исходный код';

  @override
  String get v4SharePosterRecommend => 'Посоветовать другу';

  @override
  String get v4SharePosterTopIncome => 'Топ-3 по доходам';

  @override
  String get v4SharePosterAverageRecords => 'Транзакций в день';

  @override
  String get v4ResourceParent => 'Родительская категория';

  @override
  String get v4AccountNetWorthLabel => 'Учёт в чистых активах';

  @override
  String get v4AccountIncluded => 'Учтён';

  @override
  String get v4AccountLinkedBooks => 'Связанные ведомости';

  @override
  String get v4AccountCashflow => 'Движение средств по счёту';

  @override
  String get v4AccountNetFlow => 'Чистый приток';

  @override
  String get v4AccountFlowRules => 'Переводы учтены, транзакции вне статистики исключены';

  @override
  String get v4AccountBalanceRangeNote => 'Текущий баланс не зависит от выбранного периода.';

  @override
  String get v4AccountNoTrend => 'За этот период нет данных о балансе';

  @override
  String get v4AccountNoPeer => 'Чтобы сделать перевод, добавьте ещё один счёт в этой валюте.';

  @override
  String get v4AccountActions => 'Действия со счётом';

  @override
  String get v4DetailAllTime => 'За всё время';

  @override
  String v4AccountLedgerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ведомости',
      many: '$count ведомостей',
      few: '$count ведомости',
      one: '$count ведомость',
    );
    return '$_temp0';
  }

  @override
  String get appearanceCardMaterial => 'Оформление карточек';

  @override
  String get appearanceCardMaterialDescription => 'Настройте прозрачность и размытие карточек поверх скина. Для всех строк списка используется одна карточка. Нижняя панель навигации остаётся непрозрачной.';

  @override
  String get appearanceCardTransparency => 'Прозрачность карточек';

  @override
  String get appearanceCardOpaque => 'Непрозрачные';

  @override
  String get appearanceCardTransparent => 'Прозрачнее';

  @override
  String get appearanceCardBlur => 'Степень размытия';

  @override
  String get appearanceCardBlurOff => 'Без размытия';

  @override
  String get appearanceCardBlurStrong => 'Сильнее';

  @override
  String get appearanceCardMaterialReset => 'Сбросить параметры карточек';

  @override
  String get appearanceCardMaterialPreview => 'Предпросмотр';

  @override
  String get appearanceCardMaterialPreviewBody => 'Текст и значки остаются чёткими';

  @override
  String appearanceCardMaterialSummary(int transparency, int blur) {
    return 'Прозрачность $transparency% · Размытие $blur';
  }

  @override
  String get aboutBrandStatement => 'Записывайте события жизни. Храните данные у себя.';

  @override
  String get aboutHelpSupport => 'Помощь и поддержка';

  @override
  String get aboutProductDetails => 'Узнать о продукте';

  @override
  String get v4HomeBudgetAvailable => 'Остаток бюджета';

  @override
  String get v4HomeUseCompactSummary => 'Показать краткую сводку';

  @override
  String get v4HomeUseStandardSummary => 'Показать полную сводку';

  @override
  String get v4HomeSummaryStyle => 'Summary style';

  @override
  String get v4HomeSummaryFull => 'Full';

  @override
  String get v4HomeSummaryCompact => 'Compact';

  @override
  String get v4HomeSummarySliding => 'Sliding';

  @override
  String v4HomeSummaryStyleOption(String style) {
    return '$style summary';
  }

  @override
  String get v4HomeSummaryFullDescription => 'Emphasizes spending above income, balance, and budget';

  @override
  String get v4HomeSummaryCompactDescription => 'Shows the budget ring with spending, income, and balance';

  @override
  String get v4HomeSummarySlidingDescription => 'Keeps the budget ring in place while you swipe between totals';

  @override
  String get v4HomeBudgetExceeded => 'Перерасход';

  @override
  String get recordingProgressSaving => 'Сохранение транзакций';

  @override
  String get recordingProgressRecognizing => 'Распознавание чека';

  @override
  String get recordingProgressRecognizingDetail => 'Определяем суммы, категории и заметки';

  @override
  String get recordingProgressSavingDetail => 'Сохраняем распознанные транзакции';

  @override
  String get recordingProgressSlow => 'Обработка продолжается и займёт немного больше времени.';

  @override
  String get v4RecurringNotGeneratedYet => 'Транзакций пока нет';

  @override
  String v4RecurringNextToday(String date) {
    return 'Далее: $date · сегодня';
  }

  @override
  String v4RecurringNextTomorrow(String date) {
    return 'Далее: $date · завтра';
  }

  @override
  String v4RecurringNextInDays(String date, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'через $days дня',
      many: 'через $days дней',
      few: 'через $days дня',
      one: 'через $days день',
    );
    return 'Далее: $date · $_temp0';
  }

  @override
  String get v4RecurringStatusPaused => 'На паузе';

  @override
  String get v4RecurringStatusCompleted => 'Завершено';

  @override
  String get v4RecurringStatusBlocked => 'Счёт недоступен';

  @override
  String v4RecurringAccountHiddenWarning(String account) {
    return 'Счёт «$account» скрыт. Автоматическое добавление транзакций приостановлено';
  }

  @override
  String v4RecurringToAccountHiddenWarning(String account) {
    return 'Счёт получателя «$account» скрыт. Автоматическое добавление транзакций приостановлено';
  }

  @override
  String get v4RecurringAccountMissingWarning => 'Связанный счёт не найден. Выберите счёт заново';

  @override
  String v4RecurringMonthlyOnDay(String freq, int day) {
    return '$freq · $day-го числа';
  }

  @override
  String v4RecurringWithAnchor(String freq, String anchor) {
    return '$freq · $anchor';
  }

  @override
  String get v4RecurringPreviewTitle => 'Ближайшие даты';

  @override
  String v4RecurringPreviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Далее: $count даты',
      many: 'Далее: $count дат',
      few: 'Далее: $count даты',
      one: 'Далее: $count дата',
    );
    return '$_temp0';
  }

  @override
  String get v4RecurringPreviewEmptyEnded => 'Срок действия правила истёк. Новых транзакций по этому расписанию не будет.';

  @override
  String get v4RecurringPreviewPausedHint => 'Правило на паузе. Включите его, чтобы снова добавлять транзакции автоматически.';

  @override
  String get v4RecurringPreviewDueToday => 'Сегодня · добавится при сохранении';

  @override
  String get v4RecurringPreviewPendingCatchUp => 'Дата уже прошла · добавится при сохранении';

  @override
  String get v4RecurringPreviewTomorrow => 'Завтра';

  @override
  String v4RecurringPreviewInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'через $days дня',
      many: 'через $days дней',
      few: 'через $days дня',
      one: 'через $days день',
    );
    return '$_temp0';
  }

  @override
  String v4RecurringPreviewMonthEndTag(String when) {
    return '$when · конец месяца';
  }

  @override
  String v4RecurringPreviewPreservedNote(String date) {
    return 'Последняя дата ($date) сохранена. Изменение суммы или заметки не создаст ещё одну транзакцию за текущий период.';
  }

  @override
  String v4RecurringPreviewMonthEndNote(int day) {
    return 'Если в месяце нет $day-го числа, транзакция добавится в последний день месяца. Со следующего месяца вернётся обычное расписание.';
  }

  @override
  String get v4RecurringAccountHiddenBadge => '(Скрыт)';

  @override
  String get v4RecurringAmountExpense => 'На один расход';

  @override
  String get v4RecurringAmountIncome => 'На одно поступление';

  @override
  String get v4RecurringAmountTransfer => 'На один перевод';

  @override
  String get v4RecurringAutomatic => 'Автоматический учёт';

  @override
  String v4RecurringNextCaption(String when) {
    return 'Следующая транзакция · $when';
  }

  @override
  String get v4RecurringUsageSummary => 'Транзакции с наступившей датой добавляются при открытии приложения или возвращении в него. Нажмите на правило, чтобы изменить расписание.';
}
