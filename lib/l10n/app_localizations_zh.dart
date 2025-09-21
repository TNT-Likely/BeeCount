import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '蜜蜂记账';

  @override
  String get tabHome => '明细';

  @override
  String get tabAnalytics => '图表';

  @override
  String get tabLedgers => '账本';

  @override
  String get tabMine => '我的';

  @override
  String get commonCancel => '取消';

  @override
  String get commonConfirm => '确认';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '删除';

  @override
  String get commonEdit => '编辑';

  @override
  String get commonAdd => '添加';

  @override
  String get commonOk => '确定';

  @override
  String get commonYes => '是';

  @override
  String get commonNo => '否';

  @override
  String get commonLoading => '加载中...';

  @override
  String get commonEmpty => '暂无数据';

  @override
  String get commonError => '错误';

  @override
  String get commonSuccess => '成功';

  @override
  String get commonFailed => '失败';

  @override
  String get commonRetry => '重试';

  @override
  String get commonBack => '返回';

  @override
  String get commonNext => '下一步';

  @override
  String get commonPrevious => '上一步';

  @override
  String get commonFinish => '完成';

  @override
  String get commonClose => '关闭';

  @override
  String get commonCopy => '复制';

  @override
  String get commonSearch => '搜索';

  @override
  String get commonNoteHint => '备注…';

  @override
  String get commonFilter => '筛选';

  @override
  String get commonClear => '清除';

  @override
  String get commonSelectAll => '全选';

  @override
  String get commonSettings => '设置';

  @override
  String get commonHelp => '帮助';

  @override
  String get commonAbout => '关于';

  @override
  String get commonLanguage => '语言';

  @override
  String get commonWeekdayMonday => '星期一';

  @override
  String get commonWeekdayTuesday => '星期二';

  @override
  String get commonWeekdayWednesday => '星期三';

  @override
  String get commonWeekdayThursday => '星期四';

  @override
  String get commonWeekdayFriday => '星期五';

  @override
  String get commonWeekdaySaturday => '星期六';

  @override
  String get commonWeekdaySunday => '星期日';

  @override
  String get homeTitle => '蜜蜂记账';

  @override
  String get homeIncome => '收入';

  @override
  String get homeExpense => '支出';

  @override
  String get homeBalance => '结余';

  @override
  String get homeTotal => '总';

  @override
  String get homeAverage => '平均值';

  @override
  String get homeDailyAvg => '日均';

  @override
  String get homeMonthlyAvg => '月均';

  @override
  String get homeNoRecords => '还没有记账';

  @override
  String get homeAddRecord => '点击底部加号，马上记一笔';

  @override
  String get homeHideAmounts => '隐藏金额';

  @override
  String get homeShowAmounts => '显示金额';

  @override
  String get homeSelectDate => '选择日期';

  @override
  String get homeAppTitle => '蜜蜂记账';

  @override
  String get homeSearch => '搜索';

  @override
  String get homeShowAmount => '显示金额';

  @override
  String get homeHideAmount => '隐藏金额';

  @override
  String homeYear(int year) {
    return '$year年';
  }

  @override
  String homeMonth(String month) {
    return '$month月';
  }

  @override
  String get homeNoRecordsSubtext => '点击底部加号，马上记一笔';

  @override
  String get searchTitle => '搜索';

  @override
  String get searchHint => '搜索备注、分类或金额...';

  @override
  String get searchAmountRange => '金额范围筛选';

  @override
  String get searchMinAmount => '最小金额';

  @override
  String get searchMaxAmount => '最大金额';

  @override
  String get searchTo => '至';

  @override
  String get searchNoInput => '输入关键词开始搜索';

  @override
  String get searchNoResults => '未找到匹配的结果';

  @override
  String get searchResultsEmpty => '未找到匹配的结果';

  @override
  String get searchResultsEmptyHint => '请尝试其他关键词或调整筛选条件';

  @override
  String get analyticsTitle => '分析';

  @override
  String get analyticsMonth => '月';

  @override
  String get analyticsYear => '年';

  @override
  String get analyticsAll => '全部';

  @override
  String get analyticsSummary => '汇总';

  @override
  String get analyticsCategoryRanking => '分类排行';

  @override
  String get analyticsCurrentPeriod => '当前周期';

  @override
  String get analyticsNoDataSubtext => '可左右滑动切换 收入/支出，或用上方周期切换';

  @override
  String get analyticsSwipeHint => '左右滑动切换周期';

  @override
  String get analyticsTipContent => '1) 顶部左右滑动可在\"月/年/全部\"切换\\n2) 图表区域左右滑动可切换上一/下一周期\\n3) 点击月份或年份可快速选择';

  @override
  String analyticsSwitchTo(String type) {
    return '切换到$type';
  }

  @override
  String get analyticsTipHeader => '提示：顶部胶囊可切换 月/年/全部';

  @override
  String get analyticsSwipeToSwitch => '横滑切换';

  @override
  String get analyticsAllYears => '全部年份';

  @override
  String get analyticsToday => '今天';

  @override
  String get splashAppName => '蜜蜂记账';

  @override
  String get splashSlogan => '一笔一蜜';

  @override
  String get splashSecurityTitle => '开源数据安全';

  @override
  String get splashSecurityFeature1 => '• 数据本地存储，隐私完全自控';

  @override
  String get splashSecurityFeature2 => '• 开源代码透明，安全值得信赖';

  @override
  String get splashSecurityFeature3 => '• 可选云端同步，多设备数据一致';

  @override
  String get splashInitializing => '正在初始化数据...';

  @override
  String get ledgersTitle => '账本管理';

  @override
  String get ledgersNew => '新建账本';

  @override
  String get ledgersClear => '清空当前账本';

  @override
  String get ledgersClearConfirm => '清空当前账本？';

  @override
  String get ledgersClearMessage => '将删除该账本下所有交易记录，且不可恢复。';

  @override
  String get ledgersEdit => '编辑账本';

  @override
  String get ledgersDelete => '删除账本';

  @override
  String get ledgersDeleteConfirm => '删除账本';

  @override
  String get ledgersDeleteMessage => '确定要删除该账本及其全部记录吗？此操作不可恢复。\\n若云端存在备份，也会一并删除。';

  @override
  String get ledgersDeleted => '已删除';

  @override
  String get ledgersDeleteFailed => '删除失败';

  @override
  String ledgersRecordsDeleted(int count) {
    return '已删除 $count 条记录';
  }

  @override
  String get ledgersName => '名称';

  @override
  String get ledgersDefaultLedgerName => '默认账本';

  @override
  String get ledgersDefaultAccountName => '现金';

  @override
  String get ledgersCurrency => '币种';

  @override
  String get ledgersSelectCurrency => '选择币种';

  @override
  String get ledgersSearchCurrency => '搜索：中文或代码';

  @override
  String get ledgersCreate => '创建';

  @override
  String get ledgersActions => '操作';

  @override
  String ledgersRecords(String count) {
    return '笔数：$count';
  }

  @override
  String ledgersBalance(String balance) {
    return '余额：$balance';
  }

  @override
  String get categoryTitle => '分类管理';

  @override
  String get categoryNew => '新建分类';

  @override
  String get categoryExpense => '支出分类';

  @override
  String get categoryIncome => '收入分类';

  @override
  String get categoryEmpty => '暂无分类';

  @override
  String get categoryDefault => '默认分类';

  @override
  String categoryLoadFailed(String error) {
    return '加载失败: $error';
  }

  @override
  String get iconPickerTitle => '选择图标';

  @override
  String get iconCategoryFood => '餐饮';

  @override
  String get iconCategoryTransport => '交通';

  @override
  String get iconCategoryShopping => '购物';

  @override
  String get iconCategoryEntertainment => '娱乐';

  @override
  String get iconCategoryLife => '生活';

  @override
  String get iconCategoryHealth => '健康';

  @override
  String get iconCategoryEducation => '学习';

  @override
  String get iconCategoryWork => '工作';

  @override
  String get iconCategoryFinance => '理财';

  @override
  String get iconCategoryReward => '奖励';

  @override
  String get iconCategoryOther => '其他';

  @override
  String get iconCategoryDining => '餐饮';

  @override
  String get importTitle => '导入账单';

  @override
  String get importSelectFile => '请选择 CSV/TSV 文件进行导入（默认第一行为表头）';

  @override
  String get importChooseFile => '选择文件';

  @override
  String get importNoFileSelected => '未选择文件';

  @override
  String get importHint => '提示：请选择一个 CSV/TSV 文件开始导入';

  @override
  String get importReading => '读取文件中…';

  @override
  String get importPreparing => '准备中…';

  @override
  String importColumnNumber(Object number) {
    return '第 $number 列';
  }

  @override
  String get importConfirmMapping => '确认映射';

  @override
  String get importCategoryMapping => '分类映射';

  @override
  String get importNoDataParsed => '未解析到任何数据，请返回上一页检查 CSV 内容或分隔符。';

  @override
  String get importFieldDate => '日期';

  @override
  String get importFieldType => '类型';

  @override
  String get importFieldAmount => '金额';

  @override
  String get importFieldCategory => '分类';

  @override
  String get importFieldNote => '备注';

  @override
  String get importPreview => '预览：';

  @override
  String importPreviewLimit(Object shown, Object total) {
    return '仅预览前 $shown 行，共 $total 行';
  }

  @override
  String get importCategoryNotSelected => '未选择\"分类\"列，请点击\"上一步\"返回并设置\"分类\"的列，再继续。';

  @override
  String get importCategoryMappingDescription => '请将左侧\"源分类名\"映射到系统内已有分类（或保持原名自动创建/合并）';

  @override
  String get importKeepOriginalName => '保持原名（自动创建/合并）';

  @override
  String importProgress(Object fail, Object ok) {
    return '导入中… 成功 $ok，失败 $fail';
  }

  @override
  String get importCancelImport => '取消导入';

  @override
  String get importCompleteTitle => '导入完成';

  @override
  String importCompletedCount(Object count) {
    return '成功导入 $count 条记录';
  }

  @override
  String get importFailed => '导入失败';

  @override
  String importFailedMessage(Object error) {
    return '导入失败：$error';
  }

  @override
  String get importSelectCategoryFirst => '请先选择\"分类\"列再继续';

  @override
  String get importNextStep => '下一步';

  @override
  String get importPreviousStep => '上一步';

  @override
  String get importStartImport => '开始导入';

  @override
  String get importAutoDetect => '自动';

  @override
  String get importInProgress => '正在导入…';

  @override
  String importProgressDetail(Object done, Object fail, Object ok, Object total) {
    return '已完成：$done/$total，成功 $ok，失败 $fail';
  }

  @override
  String get importBackgroundImport => '后台导入';

  @override
  String get importCancelled => '（已取消）';

  @override
  String importCompleted(Object cancelled, Object fail, Object ok) {
    return '导入完成$cancelled：成功 $ok 条，失败 $fail 条';
  }

  @override
  String importFileOpenError(String error) {
    return '无法打开文件选择器：$error';
  }

  @override
  String get mineTitle => '我的';

  @override
  String get mineSettings => '设置';

  @override
  String get mineTheme => '主题设置';

  @override
  String get mineFont => '字体设置';

  @override
  String get mineReminder => '提醒设置';

  @override
  String get mineData => '数据管理';

  @override
  String get mineImport => '导入数据';

  @override
  String get mineExport => '导出数据';

  @override
  String get mineCloud => '云服务';

  @override
  String get mineAbout => '关于';

  @override
  String get mineVersion => '版本';

  @override
  String get mineUpdate => '检查更新';

  @override
  String get mineLanguageSettings => '语言设置';

  @override
  String get mineLanguageSettingsSubtitle => '切换应用语言';

  @override
  String get languageTitle => '语言设置';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystemDefault => '跟随系统';

  @override
  String get deleteConfirmTitle => '删除确认';

  @override
  String get deleteConfirmMessage => '确定要删除这条记账吗？';

  @override
  String get logCopied => '日志已复制';

  @override
  String get waitingRestore => '等待恢复任务启动…';

  @override
  String get restoreTitle => '云端恢复';

  @override
  String get copyLog => '复制日志';

  @override
  String restoreProgress(Object current, Object total) {
    return '恢复中 ($current/$total)';
  }

  @override
  String get restorePreparing => '准备中…';

  @override
  String restoreLedgerProgress(String ledger, int done, int total) {
    return '账本：$ledger  记录：$done/$total';
  }

  @override
  String get mineSlogan => '蜜蜂记账，一笔一蜜';

  @override
  String get mineDaysCount => '记账天数';

  @override
  String get mineTotalRecords => '总笔数';

  @override
  String get mineCurrentBalance => '当前余额';

  @override
  String get mineCloudService => '云服务';

  @override
  String get mineCloudServiceLoading => '加载中…';

  @override
  String mineCloudServiceError(Object error) {
    return '错误: $error';
  }

  @override
  String get mineCloudServiceDefault => '默认云服务 (已启用)';

  @override
  String get mineCloudServiceOffline => '默认模式 (离线)';

  @override
  String get mineCloudServiceCustom => '自定义 Supabase';

  @override
  String get mineFirstFullUpload => '首次全量上传';

  @override
  String get mineFirstFullUploadSubtitle => '将所有本地账本上传到当前 Supabase';

  @override
  String get mineFirstFullUploadComplete => '完成';

  @override
  String get mineFirstFullUploadMessage => '已上传当前账本。其它账本请切换后再上传。';

  @override
  String get mineFirstFullUploadFailed => '失败';

  @override
  String get mineSyncTitle => '同步';

  @override
  String get mineSyncNotLoggedIn => '未登录';

  @override
  String get mineSyncNotConfigured => '未配置云端';

  @override
  String get mineSyncNoRemote => '云端暂无备份';

  @override
  String mineSyncInSync(Object count) {
    return '已同步 (本地$count条)';
  }

  @override
  String mineSyncLocalNewer(Object count) {
    return '本地较新 (本地$count条, 建议上传)';
  }

  @override
  String get mineSyncCloudNewer => '云端较新 (建议下载并合并)';

  @override
  String get mineSyncDifferent => '本地与云端不同步';

  @override
  String get mineSyncError => '状态获取失败';

  @override
  String get mineSyncDetailTitle => '同步状态详情';

  @override
  String mineSyncLocalRecords(Object count) {
    return '本地记录数: $count';
  }

  @override
  String mineSyncCloudRecords(Object count) {
    return '云端记录数: $count';
  }

  @override
  String mineSyncCloudLatest(Object time) {
    return '云端最新记账时间: $time';
  }

  @override
  String mineSyncLocalFingerprint(Object fingerprint) {
    return '本地指纹: $fingerprint';
  }

  @override
  String mineSyncCloudFingerprint(Object fingerprint) {
    return '云端指纹: $fingerprint';
  }

  @override
  String mineSyncMessage(Object message) {
    return '说明: $message';
  }

  @override
  String get mineUploadTitle => '上传';

  @override
  String get mineUploadNeedLogin => '需登录';

  @override
  String get mineUploadInProgress => '正在上传中…';

  @override
  String get mineUploadRefreshing => '刷新中…';

  @override
  String get mineUploadSynced => '已同步';

  @override
  String get mineUploadSuccess => '已上传';

  @override
  String get mineUploadSuccessMessage => '当前账本已同步到云端';

  @override
  String get mineDownloadTitle => '下载';

  @override
  String get mineDownloadComplete => '完成';

  @override
  String mineDownloadResult(Object deleted, Object inserted, Object skipped) {
    return '新增导入：$inserted 条\n已存在跳过：$skipped 条\n清理历史重复：$deleted 条';
  }

  @override
  String get mineLoginTitle => '登录 / 注册';

  @override
  String get mineLoginSubtitle => '仅在同步时需要';

  @override
  String get mineLoggedInEmail => '已登录';

  @override
  String get mineLogoutSubtitle => '点击可退出登录';

  @override
  String get mineLogoutConfirmTitle => '退出登录';

  @override
  String get mineLogoutConfirmMessage => '确定要退出当前账号登录吗？\n退出后将无法使用云同步功能。';

  @override
  String get mineLogoutButton => '退出';

  @override
  String get mineAutoSyncTitle => '自动同步账本';

  @override
  String get mineAutoSyncSubtitle => '记账后自动上传到云端';

  @override
  String get mineAutoSyncNeedLogin => '需登录后可开启';

  @override
  String get mineImportProgressTitle => '后台导入中…';

  @override
  String mineImportProgressSubtitle(Object done, Object fail, Object ok, Object total) {
    return '进度：$done/$total，成功 $ok，失败 $fail';
  }

  @override
  String get mineImportCompleteTitle => '导入完成';

  @override
  String mineImportCompleteSubtitle(Object fail, Object ok) {
    return '成功 $ok，失败 $fail';
  }

  @override
  String get mineCategoryManagement => '分类管理';

  @override
  String get mineCategoryManagementSubtitle => '编辑自定义分类';

  @override
  String get mineCategoryMigration => '分类迁移';

  @override
  String get mineCategoryMigrationSubtitle => '将分类数据迁移到其他分类';

  @override
  String get mineReminderSettings => '记账提醒';

  @override
  String get mineReminderSettingsSubtitle => '设置每日记账提醒';

  @override
  String get minePersonalize => '个性装扮';

  @override
  String get mineDisplayScale => '显示缩放';

  @override
  String get mineDisplayScaleSubtitle => '调整文字和界面元素大小';

  @override
  String get mineAboutTitle => '关于';

  @override
  String mineAboutMessage(Object version) {
    return '应用：蜜蜂记账\n版本：$version\n开源地址：https://github.com/TNT-Likely/BeeCount\n开源协议：详见仓库 LICENSE';
  }

  @override
  String get mineAboutOpenGitHub => '打开 GitHub';

  @override
  String get mineCheckUpdate => '检测更新';

  @override
  String get mineCheckUpdateInProgress => '检测更新中...';

  @override
  String get mineCheckUpdateSubtitle => '正在检查最新版本';

  @override
  String get mineUpdateDownload => '下载更新';

  @override
  String get mineRefreshStats => '刷新统计信息（临时）';

  @override
  String get mineRefreshStatsSubtitle => '触发全局统计 Provider 重新计算';

  @override
  String get mineRefreshSync => '刷新同步状态（临时）';

  @override
  String get mineRefreshSyncSubtitle => '触发同步状态 Provider 重新获取';

  @override
  String get categoryEditTitle => '编辑分类';

  @override
  String get categoryNewTitle => '新建分类';

  @override
  String get categoryDetailTooltip => '分类详情';

  @override
  String get categoryMigrationTooltip => '分类迁移';

  @override
  String get categoryMigrationTitle => '分类迁移';

  @override
  String get categoryMigrationDescription => '分类迁移说明';

  @override
  String get categoryMigrationDescriptionContent => '• 将指定分类的所有交易记录迁移到另一个分类\n• 迁移后，原分类的交易数据将全部转移到目标分类\n• 此操作不可撤销，请谨慎选择';

  @override
  String get categoryMigrationFromLabel => '迁出分类';

  @override
  String get categoryMigrationFromHint => '选择要迁出的分类';

  @override
  String get categoryMigrationToLabel => '迁入分类';

  @override
  String get categoryMigrationToHint => '选择迁入的分类';

  @override
  String get categoryMigrationToHintFirst => '请先选择迁出分类';

  @override
  String get categoryMigrationStartButton => '开始迁移';

  @override
  String categoryMigrationTransactionCount(int count) {
    return '$count笔';
  }

  @override
  String get categoryMigrationCannotTitle => '无法迁移';

  @override
  String get categoryMigrationCannotMessage => '选择的分类无法进行迁移，请检查分类状态。';

  @override
  String get categoryExpenseType => '支出分类';

  @override
  String get categoryIncomeType => '收入分类';

  @override
  String get categoryDefaultTitle => '默认分类';

  @override
  String get categoryDefaultMessage => '默认分类不可修改名称和图标，但可以查看详情和迁移数据';

  @override
  String get categoryNameDining => '餐饮';

  @override
  String get categoryNameTransport => '交通';

  @override
  String get categoryNameShopping => '购物';

  @override
  String get categoryNameEntertainment => '娱乐';

  @override
  String get categoryNameHome => '居家';

  @override
  String get categoryNameFamily => '家庭';

  @override
  String get categoryNameCommunication => '通讯';

  @override
  String get categoryNameUtilities => '水电';

  @override
  String get categoryNameHousing => '住房';

  @override
  String get categoryNameMedical => '医疗';

  @override
  String get categoryNameEducation => '教育';

  @override
  String get categoryNamePets => '宠物';

  @override
  String get categoryNameSports => '运动';

  @override
  String get categoryNameDigital => '数码';

  @override
  String get categoryNameTravel => '旅行';

  @override
  String get categoryNameAlcoholTobacco => '烟酒';

  @override
  String get categoryNameBabyCare => '母婴';

  @override
  String get categoryNameBeauty => '美容';

  @override
  String get categoryNameRepair => '维修';

  @override
  String get categoryNameSocial => '社交';

  @override
  String get categoryNameLearning => '学习';

  @override
  String get categoryNameCar => '汽车';

  @override
  String get categoryNameTaxi => '打车';

  @override
  String get categoryNameSubway => '地铁';

  @override
  String get categoryNameDelivery => '外卖';

  @override
  String get categoryNameProperty => '物业';

  @override
  String get categoryNameParking => '停车';

  @override
  String get categoryNameDonation => '捐赠';

  @override
  String get categoryNameGift => '礼金';

  @override
  String get categoryNameTax => '纳税';

  @override
  String get categoryNameBeverage => '饮料';

  @override
  String get categoryNameClothing => '服装';

  @override
  String get categoryNameSnacks => '零食';

  @override
  String get categoryNameRedPacket => '红包';

  @override
  String get categoryNameFruit => '水果';

  @override
  String get categoryNameGame => '游戏';

  @override
  String get categoryNameBook => '书';

  @override
  String get categoryNameLover => '爱人';

  @override
  String get categoryNameDecoration => '装修';

  @override
  String get categoryNameDailyGoods => '日用品';

  @override
  String get categoryNameLottery => '彩票';

  @override
  String get categoryNameStock => '股票';

  @override
  String get categoryNameSocialSecurity => '社保';

  @override
  String get categoryNameExpress => '快递';

  @override
  String get categoryNameWork => '工作';

  @override
  String get categoryNameSalary => '工资';

  @override
  String get categoryNameInvestment => '理财';

  @override
  String get categoryNameBonus => '奖金';

  @override
  String get categoryNameReimbursement => '报销';

  @override
  String get categoryNamePartTime => '兼职';

  @override
  String get categoryNameInterest => '利息';

  @override
  String get categoryNameRefund => '退款';

  @override
  String get categoryNameSecondHand => '二手转卖';

  @override
  String get categoryNameSocialBenefit => '社会保障';

  @override
  String get categoryNameTaxRefund => '退税退费';

  @override
  String get categoryNameProvidentFund => '公积金';

  @override
  String get categoryNameLabel => '分类名称';

  @override
  String get categoryNameHint => '请输入分类名称';

  @override
  String get categoryNameHintDefault => '默认分类名称不可修改';

  @override
  String get categoryNameRequired => '请输入分类名称';

  @override
  String get categoryNameTooLong => '分类名称不能超过4个字';

  @override
  String get categoryIconLabel => '分类图标';

  @override
  String get categoryIconDefaultMessage => '默认分类图标不可修改';

  @override
  String get categoryDangerousOperations => '危险操作';

  @override
  String get categoryDeleteTitle => '删除分类';

  @override
  String get categoryDeleteSubtitle => '删除后无法恢复';

  @override
  String get categoryDefaultCannotSave => '默认分类不可保存';

  @override
  String get categorySaveError => '保存失败';

  @override
  String categoryUpdated(Object name) {
    return '分类\"$name\"已更新';
  }

  @override
  String categoryCreated(Object name) {
    return '分类\"$name\"已创建';
  }

  @override
  String get categoryCannotDelete => '无法删除';

  @override
  String categoryCannotDeleteMessage(Object count) {
    return '该分类下还有 $count 笔交易记录，请先处理这些记录。';
  }

  @override
  String get categoryDeleteConfirmTitle => '删除分类';

  @override
  String categoryDeleteConfirmMessage(Object name) {
    return '确定要删除分类\"$name\"吗？此操作无法撤销。';
  }

  @override
  String get categoryDeleteError => '删除失败';

  @override
  String categoryDeleted(Object name) {
    return '分类\"$name\"已删除';
  }

  @override
  String get personalizeTitle => '个性化';

  @override
  String get personalizeCustomColor => '选择自定义颜色';

  @override
  String get personalizeCustomTitle => '自定义';

  @override
  String personalizeHue(Object value) {
    return '色相 ($value°)';
  }

  @override
  String personalizeSaturation(Object value) {
    return '饱和度 ($value%)';
  }

  @override
  String personalizeBrightness(Object value) {
    return '亮度 ($value%)';
  }

  @override
  String get personalizeSelectColor => '选择此颜色';

  @override
  String get fontSettingsTitle => '显示缩放';

  @override
  String fontSettingsCurrentScale(Object scale) {
    return '当前缩放：x$scale';
  }

  @override
  String get fontSettingsPreview => '实时预览';

  @override
  String get fontSettingsPreviewText => '今天吃饭花了 23.50 元，记一笔；\n本月已记账 45 天，共 320 条记录；\n坚持就是胜利！';

  @override
  String fontSettingsCurrentLevel(Object level, Object scale) {
    return '当前档位：$level  (倍率 x$scale)';
  }

  @override
  String get fontSettingsQuickLevel => '快速档位';

  @override
  String get fontSettingsCustomAdjust => '自定义调整';

  @override
  String get fontSettingsDescription => '说明：此设置确保所有设备在1.0倍时显示效果一致，设备差异已自动补偿；调整数值可在一致基础上进行个性化缩放。';

  @override
  String get fontSettingsExtraSmall => '极小';

  @override
  String get fontSettingsVerySmall => '很小';

  @override
  String get fontSettingsSmall => '较小';

  @override
  String get fontSettingsStandard => '标准';

  @override
  String get fontSettingsLarge => '较大';

  @override
  String get fontSettingsBig => '大';

  @override
  String get fontSettingsVeryBig => '很大';

  @override
  String get fontSettingsExtraBig => '极大';

  @override
  String get fontSettingsMoreStyles => '更多风格';

  @override
  String get fontSettingsPageTitle => '页面标题';

  @override
  String get fontSettingsBlockTitle => '区块标题';

  @override
  String get fontSettingsBodyExample => '正文示例';

  @override
  String get fontSettingsLabelExample => '标签说明';

  @override
  String get fontSettingsStrongNumber => '强调数字';

  @override
  String get fontSettingsListTitle => '列表项标题';

  @override
  String get fontSettingsListSubtitle => '辅助说明文本';

  @override
  String get fontSettingsScreenInfo => '屏幕适配信息';

  @override
  String get fontSettingsScreenDensity => '屏幕密度';

  @override
  String get fontSettingsScreenWidth => '屏幕宽度';

  @override
  String get fontSettingsDeviceScale => '设备缩放';

  @override
  String get fontSettingsUserScale => '用户缩放';

  @override
  String get fontSettingsFinalScale => '最终缩放';

  @override
  String get fontSettingsBaseDevice => '基准设备';

  @override
  String get fontSettingsRecommendedScale => '推荐缩放';

  @override
  String get fontSettingsYes => '是';

  @override
  String get fontSettingsNo => '否';

  @override
  String get fontSettingsScaleExample => '此方框和间距会根据设备自动缩放';

  @override
  String get fontSettingsPreciseAdjust => '精确调整';

  @override
  String get fontSettingsResetTo1x => '重置到1.0x';

  @override
  String get fontSettingsAdaptBase => '适配基准';

  @override
  String get reminderTitle => '记账提醒';

  @override
  String get reminderSubtitle => '设置每日记账提醒时间';

  @override
  String get reminderDailyTitle => '每日记账提醒';

  @override
  String get reminderDailySubtitle => '开启后将在指定时间提醒您记账';

  @override
  String get reminderTimeTitle => '提醒时间';

  @override
  String get reminderTestNotification => '发送测试通知';

  @override
  String get reminderTestSent => '测试通知已发送';

  @override
  String get reminderQuickTest => '快速测试 (15秒后)';

  @override
  String get reminderQuickTestMessage => '已设置15秒后的快速测试，请保持应用在后台';

  @override
  String get reminderFlutterTest => '🔧 测试Flutter通知点击（开发）';

  @override
  String get reminderFlutterTestMessage => '已发送Flutter测试通知，点击查看是否能打开应用';

  @override
  String get reminderAlarmTest => '🔧 测试AlarmManager通知点击（开发）';

  @override
  String get reminderAlarmTestMessage => '已设置AlarmManager测试通知（1秒后），点击查看是否能打开应用';

  @override
  String get reminderDirectTest => '🔧 直接测试NotificationReceiver（开发）';

  @override
  String get reminderDirectTestMessage => '已直接调用NotificationReceiver创建通知，查看点击是否有效';

  @override
  String get reminderCheckStatus => '🔧 检查通知状态（开发）';

  @override
  String get reminderNotificationStatus => '通知状态';

  @override
  String reminderPendingCount(Object count) {
    return '待处理通知数量: $count';
  }

  @override
  String get reminderNoPending => '当前没有待处理的通知';

  @override
  String get reminderCheckBattery => '检查电池优化状态';

  @override
  String get reminderBatteryStatus => '电池优化状态';

  @override
  String reminderManufacturer(Object value) {
    return '设备制造商: $value';
  }

  @override
  String reminderModel(Object value) {
    return '设备型号: $value';
  }

  @override
  String reminderAndroidVersion(Object value) {
    return 'Android版本: $value';
  }

  @override
  String get reminderBatteryIgnored => '电池优化状态: 已忽略 ✅';

  @override
  String get reminderBatteryNotIgnored => '电池优化状态: 未忽略 ⚠️';

  @override
  String get reminderBatteryAdvice => '建议关闭电池优化以确保通知正常工作';

  @override
  String get reminderGoToSettings => '去设置';

  @override
  String get reminderCheckChannel => '检查通知渠道设置';

  @override
  String get reminderChannelStatus => '通知渠道状态';

  @override
  String get reminderChannelEnabled => '渠道启用: 是 ✅';

  @override
  String get reminderChannelDisabled => '渠道启用: 否 ❌';

  @override
  String reminderChannelImportance(Object value) {
    return '重要性: $value';
  }

  @override
  String get reminderChannelSoundOn => '声音: 开启 🔊';

  @override
  String get reminderChannelSoundOff => '声音: 关闭 🔇';

  @override
  String get reminderChannelVibrationOn => '震动: 开启 📳';

  @override
  String get reminderChannelVibrationOff => '震动: 关闭';

  @override
  String get reminderChannelDndBypass => '勿扰模式: 可绕过';

  @override
  String get reminderChannelDndNoBypass => '勿扰模式: 不可绕过';

  @override
  String get reminderChannelAdvice => '⚠️ 建议设置：';

  @override
  String get reminderChannelAdviceImportance => '• 重要性：紧急或高';

  @override
  String get reminderChannelAdviceSound => '• 开启声音和震动';

  @override
  String get reminderChannelAdviceBanner => '• 允许横幅通知';

  @override
  String get reminderChannelAdviceXiaomi => '• 小米手机需单独设置每个渠道';

  @override
  String get reminderChannelGood => '✅ 通知渠道配置良好';

  @override
  String get reminderOpenAppSettings => '打开应用设置';

  @override
  String get reminderAppSettingsMessage => '请在设置中允许通知、关闭电池优化';

  @override
  String get reminderIOSTest => '🍎 iOS通知调试测试';

  @override
  String get reminderIOSTestTitle => 'iOS通知测试';

  @override
  String get reminderIOSTestMessage => '已发送测试通知。\n\n🍎 iOS模拟器限制：\n• 通知可能不会在通知中心显示\n• 横幅提醒可能不工作\n• 但Xcode控制台会显示日志\n\n💡 调试方法：\n• 查看Xcode控制台输出\n• 检查Flutter日志信息\n• 使用真机测试获得完整体验';

  @override
  String get reminderDescription => '提示：开启记账提醒后，系统会在每天指定时间发送通知提醒您记录收支。';

  @override
  String get reminderIOSInstructions => '🍎 iOS通知设置：\n• 设置 > 通知 > 蜜蜂记账\n• 开启\"允许通知\"\n• 设置通知样式：横幅或提醒\n• 开启声音和震动\n\n⚠️ iOS模拟器限制：\n• 模拟器通知功能有限\n• 建议使用真机测试\n• 查看Xcode控制台了解通知状态\n\n如果在模拟器中测试，请观察：\n• Xcode控制台日志输出\n• Flutter Debug Console信息\n• 应用内弹窗确认通知发送';

  @override
  String get reminderAndroidInstructions => '如果通知无法正常工作，请检查：\n• 已允许应用发送通知\n• 关闭应用的电池优化/省电模式\n• 允许应用在后台运行和自启动\n• Android 12+需要精确闹钟权限\n\n📱 小米手机特殊设置：\n• 设置 > 应用管理 > 蜜蜂记账 > 通知管理\n• 点击\"记账提醒\"渠道\n• 设置重要性为\"紧急\"或\"高\"\n• 开启\"横幅通知\"、\"声音\"、\"震动\"\n• 安全中心 > 应用管理 > 权限 > 自启动\n\n🔒 锁定后台方法：\n• 最近任务中找到蜜蜂记账\n• 向下拉动应用卡片显示锁定图标\n• 点击锁定图标防止被清理';

  @override
  String get categoryDetailLoadFailed => '加载失败';

  @override
  String get categoryDetailSummaryTitle => '分类汇总';

  @override
  String get categoryDetailTotalCount => '总笔数';

  @override
  String get categoryDetailTotalAmount => '总金额';

  @override
  String get categoryDetailAverageAmount => '平均金额';

  @override
  String get categoryDetailSortTitle => '排序';

  @override
  String get categoryDetailSortTimeDesc => '时间↓';

  @override
  String get categoryDetailSortTimeAsc => '时间↑';

  @override
  String get categoryDetailSortAmountDesc => '金额↓';

  @override
  String get categoryDetailSortAmountAsc => '金额↑';

  @override
  String get categoryDetailNoTransactions => '暂无交易记录';

  @override
  String get categoryDetailNoTransactionsSubtext => '该分类下还没有任何交易记录';

  @override
  String get categoryDetailDeleteFailed => '删除失败';

  @override
  String get categoryMigrationConfirmTitle => '确认迁移';

  @override
  String categoryMigrationConfirmMessage(Object count, Object fromName, Object toName) {
    return '确定要将「$fromName」的 $count 笔交易迁移到「$toName」吗？\n\n此操作不可撤销！';
  }

  @override
  String get categoryMigrationConfirmOk => '确认迁移';

  @override
  String get categoryMigrationCompleteTitle => '迁移完成';

  @override
  String categoryMigrationCompleteMessage(Object count, Object fromName, Object toName) {
    return '成功将 $count 笔交易从「$fromName」迁移到「$toName」。';
  }

  @override
  String get categoryMigrationFailedTitle => '迁移失败';

  @override
  String categoryMigrationFailedMessage(Object error) {
    return '迁移过程中发生错误：$error';
  }

  @override
  String categoryMigrationTransactionLabel(int count) {
    return '$count笔';
  }

  @override
  String get categoryPickerExpenseTab => '支出';

  @override
  String get categoryPickerIncomeTab => '收入';

  @override
  String get categoryPickerCancel => '取消';

  @override
  String get categoryPickerEmpty => '暂无分类';

  @override
  String get cloudBackupFound => '发现云端备份';

  @override
  String get cloudBackupRestoreMessage => '检测到云端与本地账本不一致，是否恢复到本地？\n(将进入恢复进度页)';

  @override
  String get cloudBackupRestoreFailed => '恢复失败';

  @override
  String get mineCloudBackupRestoreTitle => '发现云端备份';

  @override
  String get mineAutoSyncRemoteDesc => '记账后自动上传到云端';

  @override
  String get mineAutoSyncLoginRequired => '需登录后可开启';

  @override
  String get mineImportCompleteAllSuccess => '全部成功';

  @override
  String get mineImportCompleteTitleShort => '导入完成';

  @override
  String get mineAboutAppName => '应用：蜜蜂记账';

  @override
  String mineAboutVersion(Object version) {
    return '版本：$version';
  }

  @override
  String get mineAboutRepo => '开源地址：https://github.com/TNT-Likely/BeeCount';

  @override
  String get mineAboutLicense => '开源协议：详见仓库 LICENSE';

  @override
  String get mineCheckUpdateDetecting => '检测更新中...';

  @override
  String get mineCheckUpdateSubtitleDetecting => '正在检查最新版本';

  @override
  String get mineUpdateDownloadTitle => '下载更新';

  @override
  String get mineDebugRefreshStats => '刷新统计信息（临时）';

  @override
  String get mineDebugRefreshStatsSubtitle => '触发全局统计 Provider 重新计算';

  @override
  String get mineDebugRefreshSync => '刷新同步状态（临时）';

  @override
  String get mineDebugRefreshSyncSubtitle => '触发同步状态 Provider 重新获取';

  @override
  String get cloudCurrentService => '当前云服务';

  @override
  String get cloudConnected => '已连接';

  @override
  String get cloudOfflineMode => '离线模式';

  @override
  String get cloudAvailableServices => '可用云服务';

  @override
  String get cloudReadCustomConfigFailed => '读取自定义配置失败';

  @override
  String get cloudFirstUploadNotComplete => '首次全量上传尚未完成';

  @override
  String get cloudFirstUploadInstruction => '登录后在\"我的/同步\"中手动执行\"上传\"完成初始化';

  @override
  String get cloudNotConfigured => '未配置';

  @override
  String get cloudNotTested => '未测试';

  @override
  String get cloudConnectionNormal => '连接正常';

  @override
  String get cloudConnectionFailed => '连接失败';

  @override
  String get cloudAddCustomService => '添加自定义云服务';

  @override
  String get cloudDefaultServiceName => '默认云服务';

  @override
  String get cloudUseYourSupabase => '使用你自己的 Supabase';

  @override
  String get cloudTest => '测试';

  @override
  String get cloudSwitchService => '切换云服务';

  @override
  String get cloudSwitchToBuiltinConfirm => '确定要切换到默认云服务吗？这将退出当前登录状态。';

  @override
  String get cloudSwitchToCustomConfirm => '确定要切换到自定义云服务吗？这将退出当前登录状态。';

  @override
  String get cloudSwitched => '已切换';

  @override
  String get cloudSwitchedToBuiltin => '已切换到默认云服务并已退出登录';

  @override
  String get cloudSwitchFailed => '切换失败';

  @override
  String get cloudActivateFailed => '启用失败';

  @override
  String get cloudActivateFailedMessage => '已保存的配置无效';

  @override
  String get cloudActivated => '已启用';

  @override
  String get cloudActivatedMessage => '已切换到自定义云服务并已退出登录，请重新登录';

  @override
  String get cloudEditCustomService => '编辑自定义云服务';

  @override
  String get cloudAddCustomServiceTitle => '添加自定义云服务';

  @override
  String get cloudSupabaseUrlLabel => 'Supabase URL';

  @override
  String get cloudSupabaseUrlHint => 'https://xxx.supabase.co';

  @override
  String get cloudAnonKeyLabel => 'Anon Key';

  @override
  String get cloudAnonKeyHint => '提示：不要填写 service_role Key；Anon Key 为公开可用。';

  @override
  String get cloudInvalidInput => '无效输入';

  @override
  String get cloudValidationEmptyFields => 'URL 与 Key 均不能为空';

  @override
  String get cloudValidationHttpsRequired => 'URL 需以 https:// 开头';

  @override
  String get cloudValidationKeyTooShort => 'Key 长度过短，可能无效';

  @override
  String get cloudValidationServiceRoleKey => '禁止使用 service_role Key';

  @override
  String get cloudConfigUpdated => '配置已更新';

  @override
  String get cloudConfigSaved => '配置已保存';

  @override
  String get cloudTestComplete => '测试完成';

  @override
  String get cloudTestSuccess => '连接测试成功！';

  @override
  String get cloudTestFailed => '连接测试失败，请检查配置是否正确。';

  @override
  String get cloudTestError => '测试失败';

  @override
  String get cloudClearConfig => '清空配置';

  @override
  String get cloudClearConfigConfirm => '确定要清空自定义云服务配置吗？（仅开发环境可用）';

  @override
  String get cloudConfigCleared => '自定义云服务配置已清空';

  @override
  String get cloudClearFailed => '清空失败';

  @override
  String get cloudServiceDescription => '应用内置的云端服务（免费但可能不稳定，建议使用自己的或定期备份）';

  @override
  String get cloudServiceDescriptionNotConfigured => '当前构建未内置云服务配置';

  @override
  String cloudServiceDescriptionCustom(String url) {
    return '服务器: $url';
  }

  @override
  String get authLogin => '登录';

  @override
  String get authSignup => '注册';

  @override
  String get authRegister => '注册';

  @override
  String get authEmail => '邮箱';

  @override
  String get authPassword => '密码';

  @override
  String get authPasswordRequirement => '密码（至少 6 位，需包含字母和数字）';

  @override
  String get authConfirmPassword => '确认密码';

  @override
  String get authInvalidEmail => '请输入有效的邮箱地址';

  @override
  String get authPasswordRequirementShort => '密码需包含字母和数字，长度至少 6 位';

  @override
  String get authPasswordMismatch => '两次输入的密码不一致';

  @override
  String get authResendVerification => '重发验证邮件';

  @override
  String get authSignupSuccess => '注册成功';

  @override
  String get authVerificationEmailSent => '验证邮件已发送，请前往邮箱完成验证后再登录。';

  @override
  String get authBackToMinePage => '返回我的页面';

  @override
  String get authVerificationEmailResent => '验证邮件已重新发送。';

  @override
  String get authResendAction => '重发验证';

  @override
  String get authErrorInvalidCredentials => '邮箱或密码不正确。';

  @override
  String get authErrorEmailNotConfirmed => '邮箱未验证，请先到邮箱完成验证再登录。';

  @override
  String get authErrorRateLimit => '操作过于频繁，请稍后再试。';

  @override
  String get authErrorNetworkIssue => '网络异常，请检查网络后重试。';

  @override
  String get authErrorLoginFailed => '登录失败，请稍后再试。';

  @override
  String get authErrorEmailInvalid => '邮箱地址无效，请检查是否拼写有误。';

  @override
  String get authErrorEmailExists => '该邮箱已注册，请直接登录或重置密码。';

  @override
  String get authErrorWeakPassword => '密码过于简单，请包含字母和数字，长度至少 6 位。';

  @override
  String get authErrorSignupFailed => '注册失败，请稍后再试。';

  @override
  String authErrorUserNotFound(String action) {
    return '邮箱未注册，无法$action。';
  }

  @override
  String authErrorEmailNotVerified(String action) {
    return '邮箱未验证，无法$action。';
  }

  @override
  String authErrorActionFailed(String action) {
    return '$action失败，请稍后再试。';
  }

  @override
  String get importSelectCsvFile => '请选择 CSV/TSV 文件进行导入（默认第一行为表头）';

  @override
  String get exportTitle => '导出';

  @override
  String get exportDescription => '点击下方按钮选择保存位置，开始导出当前账本为 CSV 文件。';

  @override
  String get exportButtonIOS => '导出并分享 (iOS)';

  @override
  String get exportButtonAndroid => '选择文件夹并导出';

  @override
  String exportSavedTo(String path) {
    return '已保存到：$path';
  }

  @override
  String get exportSelectFolder => '选择导出文件夹';

  @override
  String get exportCsvHeaderType => '类型';

  @override
  String get exportCsvHeaderCategory => '分类';

  @override
  String get exportCsvHeaderAmount => '金额';

  @override
  String get exportCsvHeaderNote => '备注';

  @override
  String get exportCsvHeaderTime => '时间';

  @override
  String get exportShareText => 'BeeCount 导出文件';

  @override
  String get exportSuccessTitle => '导出成功';

  @override
  String exportSuccessMessageIOS(String path) {
    return '已保存并可在分享历史中找到：\n$path';
  }

  @override
  String exportSuccessMessageAndroid(String path) {
    return '已保存到：\n$path';
  }

  @override
  String get exportFailedTitle => '导出失败';

  @override
  String get exportTypeIncome => '收入';

  @override
  String get exportTypeExpense => '支出';

  @override
  String get exportTypeTransfer => '转账';

  @override
  String get personalizeThemeHoney => '蜜蜂黄';

  @override
  String get personalizeThemeOrange => '火焰橙';

  @override
  String get personalizeThemeGreen => '琉璃绿';

  @override
  String get personalizeThemePurple => '青莲紫';

  @override
  String get personalizeThemePink => '樱绯红';

  @override
  String get personalizeThemeBlue => '晴空蓝';

  @override
  String get personalizeThemeMint => '林间月';

  @override
  String get personalizeThemeSand => '黄昏沙丘';

  @override
  String get personalizeThemeLavender => '雪与松';

  @override
  String get personalizeThemeSky => '迷雾仙境';

  @override
  String get personalizeThemeWarmOrange => '暖阳橘';

  @override
  String get personalizeThemeMintGreen => '薄荷青';

  @override
  String get personalizeThemeRoseGold => '玫瑰金';

  @override
  String get personalizeThemeDeepBlue => '深海蓝';

  @override
  String get personalizeThemeMapleRed => '枫叶红';

  @override
  String get personalizeThemeEmerald => '翡翠绿';

  @override
  String get personalizeThemeLavenderPurple => '薰衣草';

  @override
  String get personalizeThemeAmber => '琥珀黄';

  @override
  String get personalizeThemeRouge => '胭脂红';

  @override
  String get personalizeThemeIndigo => '靛青蓝';

  @override
  String get personalizeThemeOlive => '橄榄绿';

  @override
  String get personalizeThemeCoral => '珊瑚粉';

  @override
  String get personalizeThemeDarkGreen => '墨绿色';

  @override
  String get personalizeThemeViolet => '紫罗兰';

  @override
  String get personalizeThemeSunset => '日落橙';

  @override
  String get personalizeThemePeacock => '孔雀蓝';

  @override
  String get personalizeThemeLime => '柠檬绿';

  @override
  String get analyticsMonthlyAvg => '月均';

  @override
  String get analyticsDailyAvg => '日均';

  @override
  String get analyticsOverallAvg => '平均值';

  @override
  String get analyticsTotalIncome => '总收入： ';

  @override
  String get analyticsTotalExpense => '总支出： ';

  @override
  String get analyticsBalance => '结余： ';

  @override
  String analyticsAvgIncome(String avgLabel) {
    return '$avgLabel收入： ';
  }

  @override
  String analyticsAvgExpense(String avgLabel) {
    return '$avgLabel支出： ';
  }

  @override
  String get analyticsExpense => '支出';

  @override
  String get analyticsIncome => '收入';

  @override
  String analyticsTotal(String type) {
    return '总$type： ';
  }

  @override
  String analyticsAverage(String avgLabel) {
    return '$avgLabel： ';
  }

  @override
  String get updateCheckTitle => '检查更新';

  @override
  String get updateNewVersionFound => '发现新版本';

  @override
  String updateNewVersionTitle(String version) {
    return '发现新版本 $version';
  }

  @override
  String get updateNoApkFound => '未找到APK下载链接';

  @override
  String get updateAlreadyLatest => '当前已是最新版本';

  @override
  String get updateCheckFailed => '检查更新失败';

  @override
  String get updatePermissionDenied => '权限被拒绝';

  @override
  String get updateUserCancelled => '用户取消';

  @override
  String get updateDownloadTitle => '下载更新';

  @override
  String updateDownloading(String percent) {
    return '下载中: $percent%';
  }

  @override
  String get updateDownloadBackgroundHint => '可以将应用切换到后台，下载会继续进行';

  @override
  String get updateCancelButton => '取消';

  @override
  String get updateBackgroundDownload => '后台下载';

  @override
  String get updateLaterButton => '稍后';

  @override
  String get updateDownloadButton => '下载';

  @override
  String get updateFoundCachedTitle => '发现已下载版本';

  @override
  String updateFoundCachedMessage(String path) {
    return '已找到之前下载的安装包，是否直接安装？\\n\\n点击\\\"确定\\\"立即安装，点击\\\"取消\\\"关闭此弹窗。\\n\\n文件路径: $path';
  }

  @override
  String get updateInstallingCachedApk => '正在安装缓存的APK';

  @override
  String get updateDownloadComplete => '下载完成';

  @override
  String get updateInstallStarted => '下载完成，安装程序已启动';

  @override
  String get updateInstallFailed => '安装失败';

  @override
  String get updateDownloadCompleteManual => '下载完成，可以手动安装';

  @override
  String get updateDownloadCompleteException => '下载完成，请手动安装（弹窗异常）';

  @override
  String get updateDownloadCompleteManualContext => '下载完成，请手动安装';

  @override
  String get updateDownloadFailed => '下载失败';

  @override
  String get updateInstallTitle => '下载完成';

  @override
  String get updateInstallMessage => 'APK文件下载完成，是否立即安装？\\n\\n注意：安装时应用会暂时退到后台，这是正常现象。';

  @override
  String get updateInstallNow => '立即安装';

  @override
  String get updateInstallLater => '稍后安装';

  @override
  String get updateNotificationTitle => '蜜蜂记账更新下载';

  @override
  String get updateNotificationBody => '正在下载新版本...';

  @override
  String get updateNotificationComplete => '下载完成，点击安装';

  @override
  String get updateNotificationPermissionTitle => '通知权限被拒绝';

  @override
  String get updateNotificationPermissionMessage => '无法获得通知权限，下载进度将不会在通知栏显示，但下载功能正常。';

  @override
  String get updateNotificationGuideTitle => '如需开启通知，请按以下步骤操作：';

  @override
  String get updateNotificationStep1 => '打开系统设置';

  @override
  String get updateNotificationStep2 => '找到「应用管理」或「应用设置」';

  @override
  String get updateNotificationStep3 => '找到「蜜蜂记账」应用';

  @override
  String get updateNotificationStep4 => '点击「权限管理」或「通知管理」';

  @override
  String get updateNotificationStep5 => '开启「通知权限」';

  @override
  String get updateNotificationMiuiHint => 'MIUI用户：小米系统对通知权限管控较严，可能需要在安全中心中额外设置';

  @override
  String get updateNotificationGotIt => '知道了';

  @override
  String get updateCheckFailedTitle => '检测更新失败';

  @override
  String get updateDownloadFailedTitle => '下载失败';

  @override
  String get updateGoToGitHub => '前往GitHub';

  @override
  String get updateCannotOpenLink => '无法打开链接';

  @override
  String get updateManualVisit => '请手动在浏览器中访问：\\nhttps://github.com/TNT-Likely/BeeCount/releases';

  @override
  String get updateNoLocalApkTitle => '未找到更新包';

  @override
  String get updateNoLocalApkMessage => '没有找到已下载的更新包文件。\\n\\n请先通过\\\"检查更新\\\"下载新版本。';

  @override
  String get updateInstallPackageTitle => '安装更新包';

  @override
  String get updateMultiplePackagesTitle => '找到多个更新包';

  @override
  String updateMultiplePackagesMessage(int count, String path) {
    return '找到 $count 个更新包文件。\\n\\n建议使用最新下载的版本，或手动到文件管理器中安装。\\n\\n文件位置：$path';
  }

  @override
  String get updateSearchFailedTitle => '查找失败';

  @override
  String updateSearchFailedMessage(String error) {
    return '查找本地更新包时发生错误：$error';
  }

  @override
  String get updateFoundCachedPackageTitle => '发现已下载的更新包';

  @override
  String updateFoundCachedPackageMessage(String fileName, String fileSize) {
    return '检测到之前下载的更新包：\\n\\n文件名：$fileName\\n大小：${fileSize}MB\\n\\n是否立即安装？';
  }

  @override
  String get updateIgnoreButton => '忽略';

  @override
  String get updateInstallFailedTitle => '安装失败';

  @override
  String get updateInstallFailedMessage => '无法启动APK安装程序，请检查文件权限。';

  @override
  String get updateErrorTitle => '错误';

  @override
  String updateReadCacheFailedMessage(String error) {
    return '读取缓存更新包失败：$error';
  }

  @override
  String get updateCheckingPermissions => '检查权限...';

  @override
  String get updateCheckingCache => '检查本地缓存...';

  @override
  String get updatePreparingDownload => '准备下载...';

  @override
  String get updateUserCancelledDownload => '用户取消下载';

  @override
  String get updateStartingInstaller => '正在启动安装...';

  @override
  String get updateInstallerStarted => '安装程序已启动';

  @override
  String get updateInstallationFailed => '安装失败';

  @override
  String get updateDownloadCompleted => '下载完成';

  @override
  String get updateDownloadCompletedManual => '下载完成，可以手动安装';

  @override
  String get updateDownloadCompletedDialog => '下载完成，请手动安装（弹窗异常）';

  @override
  String get updateDownloadCompletedContext => '下载完成，请手动安装';

  @override
  String get updateDownloadFailedGeneric => '下载失败';

  @override
  String get updateCheckingUpdate => '正在检查更新...';

  @override
  String get updateCurrentLatestVersion => '当前已是最新版本';

  @override
  String get updateCheckFailedGeneric => '检查更新失败';

  @override
  String updateDownloadProgress(String percent) {
    return '下载中: $percent%';
  }

  @override
  String get updateNoApkFoundError => '未找到APK下载链接';

  @override
  String updateCheckingUpdateError(String error) {
    return '检查更新失败: $error';
  }

  @override
  String get updateNotificationChannelName => '更新下载';

  @override
  String get updateNotificationDownloadingIndeterminate => '正在下载新版本...';

  @override
  String updateNotificationDownloadingProgress(String progress) {
    return '下载进度: $progress%';
  }

  @override
  String get updateNotificationDownloadCompleteTitle => '下载完成';

  @override
  String get updateNotificationDownloadCompleteMessage => '新版本已下载完成，点击安装';

  @override
  String get updateUserCancelledDownloadDialog => '用户取消下载';

  @override
  String get updateCannotOpenLinkError => '无法打开链接';

  @override
  String get updateNoLocalApkFoundMessage => '没有找到已下载的更新包文件。\n\n请先通过\"检查更新\"下载新版本。';

  @override
  String updateInstallPackageFoundMessage(String fileName, String fileSize, String time) {
    return '找到更新包：\n\n文件名：$fileName\n大小：${fileSize}MB\n下载时间：$time\n\n是否立即安装？';
  }

  @override
  String updateMultiplePackagesFoundMessage(int count, String path) {
    return '找到 $count 个更新包文件。\n\n建议使用最新下载的版本，或手动到文件管理器中安装。\n\n文件位置：$path';
  }

  @override
  String updateSearchLocalApkError(String error) {
    return '查找本地更新包时发生错误：$error';
  }

  @override
  String updateCachedPackageFoundMessage(String fileName, String fileSize) {
    return '检测到之前下载的更新包：\n\n文件名：$fileName\n大小：${fileSize}MB\n\n是否立即安装？';
  }

  @override
  String updateReadCachedPackageError(String error) {
    return '读取缓存更新包失败：$error';
  }

  @override
  String get reminderQuickTestSent => '已设置15秒后的快速测试，请保持应用在后台';

  @override
  String get reminderFlutterTestSent => '已发送Flutter测试通知，点击查看是否能打开应用';

  @override
  String get reminderAlarmTestSent => '已设置AlarmManager测试通知（1秒后），点击查看是否能打开应用';

  @override
  String get updateOk => '知道了';

  @override
  String get updateCannotOpenLinkTitle => '无法打开链接';

  @override
  String get updateCachedVersionTitle => '发现已下载版本';

  @override
  String get updateCachedVersionMessage => '已找到之前下载的安装包...点击\\\"确定\\\"立即安装，点击\\\"取消\\\"关闭...';

  @override
  String get updateConfirmDownload => '立即下载并安装';

  @override
  String get updateDownloadCompleteTitle => '下载完成';

  @override
  String get updateInstallConfirmMessage => '新版本已下载完成，是否立即安装？';

  @override
  String get updateNotificationPermissionGuideText => '下载进度通知被关闭，但不影响下载功能。如需查看进度：';

  @override
  String get updateNotificationGuideStep1 => '进入系统设置 > 应用管理';

  @override
  String get updateNotificationGuideStep2 => '找到\\\"蜜蜂记账\\\"应用';

  @override
  String get updateNotificationGuideStep3 => '开启通知权限';

  @override
  String get updateNotificationGuideInfo => '即使不开启通知，下载也会在后台正常进行';

  @override
  String get currencyCNY => '人民币';

  @override
  String get currencyUSD => '美元';

  @override
  String get currencyEUR => '欧元';

  @override
  String get currencyJPY => '日元';

  @override
  String get currencyHKD => '港币';

  @override
  String get currencyTWD => '新台币';

  @override
  String get currencyGBP => '英镑';

  @override
  String get currencyAUD => '澳元';

  @override
  String get currencyCAD => '加元';

  @override
  String get currencyKRW => '韩元';

  @override
  String get currencySGD => '新加坡元';

  @override
  String get currencyTHB => '泰铢';

  @override
  String get currencyIDR => '印尼卢比';

  @override
  String get currencyINR => '印度卢比';

  @override
  String get currencyRUB => '卢布';

  @override
  String get cloudDefaultServiceDisplayName => '默认云服务';

  @override
  String get cloudNotConfiguredDisplay => '未配置';

  @override
  String get syncNotConfiguredMessage => '未配置云端';

  @override
  String get syncNotLoggedInMessage => '未登录';

  @override
  String get syncCloudBackupCorruptedMessage => '云端备份内容无法解析，可能是早期版本编码问题造成的损坏。请点击\\\"上传当前账本到云端\\\"覆盖修复。';

  @override
  String get syncNoCloudBackupMessage => '云端暂无备份';

  @override
  String get syncAccessDeniedMessage => '403 拒绝访问（检查 storage RLS 策略与路径）';
}
