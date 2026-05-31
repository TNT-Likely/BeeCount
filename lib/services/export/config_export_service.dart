import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:drift/drift.dart' as d;
import '../../data/db.dart';
import '../../data/repositories/base_repository.dart';
import '../system/logger_service.dart';
import '../../ai/providers/ai_constants.dart';
import '../../ai/providers/ai_provider_config.dart';
import '../../ai/providers/ai_provider_manager.dart';

// 导入 OrderingTerm
typedef OrderingTerm = d.OrderingTerm;

/// 递归转换 Map 为 Map<String, dynamic>
/// YAML 解析后的 Map 可能是 YamlMap，键可能不是 String 类型
Map<String, dynamic> _convertToStringDynamicMap(Map map) {
  return map.map((key, value) {
    final stringKey = key.toString();
    if (value is Map) {
      return MapEntry(stringKey, _convertToStringDynamicMap(value));
    } else if (value is List) {
      return MapEntry(stringKey, value.map((item) {
        if (item is Map) {
          return _convertToStringDynamicMap(item);
        }
        return item;
      }).toList());
    }
    return MapEntry(stringKey, value);
  });
}

/// 导出选项 - 控制导出哪些内容
class ExportOptions {
  final bool ledgers;
  final bool categories;
  final bool accounts;
  final bool tags;
  final bool recurringTransactions;
  final bool budgets;
  final bool appSettings; // 包含云服务配置等
  final bool ai; // AI 服务商配置、能力绑定等
  /// 是否把 BeeCount Cloud 的登录态（access/refresh token）一起导出。
  /// 默认 false —— 只导出 base_url + email，密码 / token 不写进 yaml。
  /// 测试或跨设备快速登录时显式勾选。
  final bool beecountCloudCredentials;

  const ExportOptions({
    this.ledgers = true,
    this.categories = true,
    this.accounts = true,
    this.tags = true,
    this.recurringTransactions = true,
    this.budgets = true,
    this.appSettings = true,
    this.ai = true,
    this.beecountCloudCredentials = false,
  });

  /// 全选
  static const all = ExportOptions();

  /// 全不选
  static const none = ExportOptions(
    ledgers: false,
    categories: false,
    accounts: false,
    tags: false,
    recurringTransactions: false,
    budgets: false,
    appSettings: false,
    ai: false,
  );
}

/// 应用配置模型
class AppConfig {
  final SupabaseConfig? supabase;
  final WebdavConfig? webdav;
  final S3Config? s3;
  final BeeCountCloudConfig? beecountCloud;
  final AIConfig? ai;
  final AppSettingsConfig? appSettings;
  final LedgersConfig? ledgers;
  final RecurringTransactionsConfig? recurringTransactions;
  final AccountsConfig? accounts;
  final CategoriesConfig? categories;
  final TagsConfig? tags;
  final BudgetsConfig? budgets;

  const AppConfig({
    this.supabase,
    this.webdav,
    this.s3,
    this.beecountCloud,
    this.ai,
    this.appSettings,
    this.ledgers,
    this.recurringTransactions,
    this.accounts,
    this.categories,
    this.tags,
    this.budgets,
  });

  Map<String, dynamic> toYaml() {
    final map = <String, dynamic>{};

    if (supabase != null) {
      map['supabase'] = supabase!.toMap();
    }

    if (beecountCloud != null) {
      map['beecount_cloud'] = beecountCloud!.toMap();
    }

    if (webdav != null) {
      map['webdav'] = webdav!.toMap();
    }

    if (s3 != null) {
      map['s3'] = s3!.toMap();
    }

    if (ai != null) {
      map['ai'] = ai!.toMap();
    }

    if (appSettings != null) {
      map['app_settings'] = appSettings!.toMap();
    }

    if (ledgers != null) {
      map['ledgers'] = ledgers!.toMap();
    }

    if (recurringTransactions != null) {
      map['recurring_transactions'] = recurringTransactions!.toMap();
    }

    if (accounts != null) {
      map['accounts'] = accounts!.toMap();
    }

    if (categories != null) {
      map['categories'] = categories!.toMap();
    }

    if (tags != null) {
      map['tags'] = tags!.toMap();
    }

    if (budgets != null) {
      map['budgets'] = budgets!.toMap();
    }

    return map;
  }

  static AppConfig fromYaml(Map<dynamic, dynamic> yaml) {
    return AppConfig(
      supabase: yaml.containsKey('supabase')
          ? SupabaseConfig.fromMap(
              Map<String, dynamic>.from(yaml['supabase'] as Map))
          : null,
      webdav: yaml.containsKey('webdav')
          ? WebdavConfig.fromMap(
              Map<String, dynamic>.from(yaml['webdav'] as Map))
          : null,
      s3: yaml.containsKey('s3')
          ? S3Config.fromMap(
              Map<String, dynamic>.from(yaml['s3'] as Map))
          : null,
      beecountCloud: yaml.containsKey('beecount_cloud')
          ? BeeCountCloudConfig.fromMap(
              Map<String, dynamic>.from(yaml['beecount_cloud'] as Map))
          : null,
      ai: yaml.containsKey('ai')
          ? AIConfig.fromMap(_convertToStringDynamicMap(yaml['ai'] as Map))
          : null,
      appSettings: yaml.containsKey('app_settings')
          ? AppSettingsConfig.fromMap(
              Map<String, dynamic>.from(yaml['app_settings'] as Map))
          : null,
      ledgers: yaml.containsKey('ledgers')
          ? LedgersConfig.fromMap(
              Map<String, dynamic>.from(yaml['ledgers'] as Map))
          : null,
      recurringTransactions: yaml.containsKey('recurring_transactions')
          ? RecurringTransactionsConfig.fromMap(
              Map<String, dynamic>.from(yaml['recurring_transactions'] as Map))
          : null,
      accounts: yaml.containsKey('accounts')
          ? AccountsConfig.fromMap(
              Map<String, dynamic>.from(yaml['accounts'] as Map))
          : null,
      categories: yaml.containsKey('categories')
          ? CategoriesConfig.fromMap(
              Map<String, dynamic>.from(yaml['categories'] as Map))
          : null,
      tags: yaml.containsKey('tags')
          ? TagsConfig.fromMap(
              Map<String, dynamic>.from(yaml['tags'] as Map))
          : null,
      budgets: yaml.containsKey('budgets')
          ? BudgetsConfig.fromMap(
              Map<String, dynamic>.from(yaml['budgets'] as Map))
          : null,
    );
  }
}

/// Supabase配置
class SupabaseConfig {
  final String url;
  final String anonKey;
  final String? bucket;
  final String? email;
  final String? password;

  const SupabaseConfig({
    required this.url,
    required this.anonKey,
    this.bucket,
    this.email,
    this.password,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'url': url,
      'anon_key': anonKey,
    };
    if (bucket != null && bucket!.isNotEmpty) {
      map['bucket'] = bucket;
    }
    if (email != null && email!.isNotEmpty) {
      map['email'] = email;
    }
    if (password != null && password!.isNotEmpty) {
      map['password'] = password;
    }
    return map;
  }

  static SupabaseConfig fromMap(Map<String, dynamic> map) => SupabaseConfig(
        url: map['url'] as String,
        anonKey: map['anon_key'] as String,
        bucket: map['bucket'] as String?,
        email: map['email'] as String?,
        password: map['password'] as String?,
      );
}

/// BeeCount Cloud 配置（自部署 FastAPI 后端的 base URL + 可选登录态）
///
/// 多设备同步测试的便利入口：A 设备导出配置，B 设备导入就能直接进入 Cloud 模式
/// 而不用再手动敲 server URL / 登录。
///
/// 安全：accessToken / refreshToken 是登录态，导出的 yaml 文件要当作密钥级别
/// 保管。导出 UI 应默认不带 token，只有显式勾选"包含登录态"才会写进来。
class BeeCountCloudConfig {
  final String baseUrl;
  final String? email;
  final String? password;
  final String? accessToken;
  final String? refreshToken;
  final String? deviceId;

  const BeeCountCloudConfig({
    required this.baseUrl,
    this.email,
    this.password,
    this.accessToken,
    this.refreshToken,
    this.deviceId,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'base_url': baseUrl,
    };
    if (email != null && email!.isNotEmpty) map['email'] = email;
    if (password != null && password!.isNotEmpty) map['password'] = password;
    if (accessToken != null && accessToken!.isNotEmpty) {
      map['access_token'] = accessToken;
    }
    if (refreshToken != null && refreshToken!.isNotEmpty) {
      map['refresh_token'] = refreshToken;
    }
    if (deviceId != null && deviceId!.isNotEmpty) map['device_id'] = deviceId;
    return map;
  }

  static BeeCountCloudConfig fromMap(Map<String, dynamic> map) =>
      BeeCountCloudConfig(
        baseUrl: map['base_url'] as String,
        email: map['email'] as String?,
        password: map['password'] as String?,
        accessToken: map['access_token'] as String?,
        refreshToken: map['refresh_token'] as String?,
        deviceId: map['device_id'] as String?,
      );
}

/// WebDAV配置
class WebdavConfig {
  final String url;
  final String username;
  final String password;
  final String? remotePath;

  const WebdavConfig({
    required this.url,
    required this.username,
    required this.password,
    this.remotePath,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'url': url,
      'username': username,
      'password': password,
    };
    if (remotePath != null && remotePath!.isNotEmpty) {
      map['remote_path'] = remotePath;
    }
    return map;
  }

  static WebdavConfig fromMap(Map<String, dynamic> map) => WebdavConfig(
        url: map['url'] as String,
        username: map['username'] as String,
        password: map['password'] as String,
        remotePath: map['remote_path'] as String?,
      );
}

/// S3配置
class S3Config {
  final String endpoint;
  final String region;
  final String accessKey;
  final String secretKey;
  final String bucket;
  final bool? useSSL;
  final int? port;

  const S3Config({
    required this.endpoint,
    required this.region,
    required this.accessKey,
    required this.secretKey,
    required this.bucket,
    this.useSSL,
    this.port,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'endpoint': endpoint,
      'region': region,
      'access_key': accessKey,
      'secret_key': secretKey,
      'bucket': bucket,
    };
    if (useSSL != null) {
      map['use_ssl'] = useSSL;
    }
    if (port != null) {
      map['port'] = port;
    }
    return map;
  }

  static S3Config fromMap(Map<String, dynamic> map) => S3Config(
        endpoint: map['endpoint'] as String,
        region: map['region'] as String,
        accessKey: map['access_key'] as String,
        secretKey: map['secret_key'] as String,
        bucket: map['bucket'] as String,
        useSSL: map['use_ssl'] as bool?,
        port: map['port'] as int?,
      );
}

/// AI配置
class AIConfig {
  // 基础设置（向后兼容）
  final String? glmApiKey;
  final String? glmModel;
  final String? glmVisionModel;
  final String? strategy;
  final bool? enabled;
  final bool? useVision;

  // 新增：服务商列表
  final List<AIServiceProviderConfig>? providers;

  // 新增：能力绑定
  final AICapabilityBinding? capabilityBinding;

  const AIConfig({
    this.glmApiKey,
    this.glmModel,
    this.glmVisionModel,
    this.strategy,
    this.enabled,
    this.useVision,
    this.providers,
    this.capabilityBinding,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    // 基础设置（向后兼容）
    if (glmApiKey != null && glmApiKey!.isNotEmpty) {
      map[AIConstants.keyGlmApiKey] = glmApiKey;
    }
    if (glmModel != null && glmModel!.isNotEmpty) {
      map[AIConstants.keyGlmModel] = glmModel;
    }
    if (glmVisionModel != null && glmVisionModel!.isNotEmpty) {
      map[AIConstants.keyGlmVisionModel] = glmVisionModel;
    }
    if (strategy != null && strategy!.isNotEmpty) {
      map[AIConstants.keyAiStrategy] = strategy;
    }
    if (enabled != null) {
      map[AIConstants.keyAiBillExtractionEnabled] = enabled;
    }
    if (useVision != null) {
      map[AIConstants.keyAiUseVision] = useVision;
    }

    // 服务商列表
    if (providers != null && providers!.isNotEmpty) {
      map['providers'] = providers!.map((p) => p.toJson()).toList();
    }

    // 能力绑定
    if (capabilityBinding != null) {
      map['capability_binding'] = capabilityBinding!.toJson();
    }

    return map;
  }

  static AIConfig fromMap(Map<String, dynamic> map) {
    logger.debug('AIConfig', 'fromMap keys: ${map.keys.toList()}');

    // 解析服务商列表
    List<AIServiceProviderConfig>? providers;
    if (map['providers'] != null) {
      final providersList = map['providers'] as List;
      providers = providersList
          .map((p) => AIServiceProviderConfig.fromJson(_convertToStringDynamicMap(p as Map)))
          .toList();
      logger.debug('AIConfig', '解析到 ${providers.length} 个服务商');
    }

    // 解析能力绑定
    AICapabilityBinding? capabilityBinding;
    if (map['capability_binding'] != null) {
      logger.debug('AIConfig', 'capability_binding raw: ${map['capability_binding']}');
      final bindingMap = _convertToStringDynamicMap(map['capability_binding'] as Map);
      logger.debug('AIConfig', 'capability_binding converted: $bindingMap');
      capabilityBinding = AICapabilityBinding.fromJson(bindingMap);
      logger.debug('AIConfig', '解析到能力绑定: text=${capabilityBinding.textProviderId}, vision=${capabilityBinding.visionProviderId}');
    } else {
      logger.debug('AIConfig', 'capability_binding 为 null');
    }

    return AIConfig(
      glmApiKey: map[AIConstants.keyGlmApiKey] as String?,
      glmModel: map[AIConstants.keyGlmModel] as String?,
      glmVisionModel: map[AIConstants.keyGlmVisionModel] as String?,
      strategy: map[AIConstants.keyAiStrategy] as String?,
      enabled: map[AIConstants.keyAiBillExtractionEnabled] as bool?,
      useVision: map[AIConstants.keyAiUseVision] as bool?,
      providers: providers,
      capabilityBinding: capabilityBinding,
    );
  }
}

/// 应用设置配置
class AppSettingsConfig {
  // 账户管理
  final bool? accountFeatureEnabled;
  final String? defaultIncomeAccountName; // 默认收入账户名称（用于导出/导入匹配）
  final String? defaultExpenseAccountName; // 默认支出账户名称（用于导出/导入匹配）

  // 记账提醒
  final bool? reminderEnabled;
  final int? reminderHour;
  final int? reminderMinute;

  // 语言设置
  final String? languageCode;
  final String? countryCode;

  // 个性化设置
  final int? primaryColor;
  final int? fontScaleLevel;
  final double? customFontScale;

  // 外观设置
  final String? themeMode;
  final String? darkModePatternStyle;
  final bool? compactAmount;
  final bool? showTransactionTime;
  final bool? incomeExpenseColorScheme; // 收支颜色方案：true=红色收入/绿色支出，false=红色支出/绿色收入

  // 云服务选择
  final String? cloudServiceType;
  final bool? autoSync; // 自动同步

  // 自动记账功能
  final bool? autoScreenshotEnabled;
  final bool? shortcutPreferCamera;

  const AppSettingsConfig({
    this.accountFeatureEnabled,
    this.defaultIncomeAccountName,
    this.defaultExpenseAccountName,
    this.reminderEnabled,
    this.reminderHour,
    this.reminderMinute,
    this.languageCode,
    this.countryCode,
    this.primaryColor,
    this.fontScaleLevel,
    this.customFontScale,
    this.themeMode,
    this.darkModePatternStyle,
    this.compactAmount,
    this.showTransactionTime,
    this.incomeExpenseColorScheme,
    this.cloudServiceType,
    this.autoSync,
    this.autoScreenshotEnabled,
    this.shortcutPreferCamera,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    if (accountFeatureEnabled != null) {
      map['account_feature_enabled'] = accountFeatureEnabled;
    }
    if (defaultIncomeAccountName != null) {
      map['default_income_account_name'] = defaultIncomeAccountName;
    }
    if (defaultExpenseAccountName != null) {
      map['default_expense_account_name'] = defaultExpenseAccountName;
    }
    if (reminderEnabled != null) {
      map['reminder_enabled'] = reminderEnabled;
    }
    if (reminderHour != null) {
      map['reminder_hour'] = reminderHour;
    }
    if (reminderMinute != null) {
      map['reminder_minute'] = reminderMinute;
    }
    if (languageCode != null && languageCode!.isNotEmpty) {
      map['language_code'] = languageCode;
    }
    if (countryCode != null && countryCode!.isNotEmpty) {
      map['country_code'] = countryCode;
    }
    if (primaryColor != null) {
      map['primary_color'] = primaryColor;
    }
    if (fontScaleLevel != null) {
      map['font_scale_level'] = fontScaleLevel;
    }
    if (customFontScale != null) {
      map['custom_font_scale'] = customFontScale;
    }
    if (themeMode != null && themeMode!.isNotEmpty) {
      map['theme_mode'] = themeMode;
    }
    if (darkModePatternStyle != null && darkModePatternStyle!.isNotEmpty) {
      map['dark_mode_pattern_style'] = darkModePatternStyle;
    }
    if (compactAmount != null) {
      map['compact_amount'] = compactAmount;
    }
    if (showTransactionTime != null) {
      map['show_transaction_time'] = showTransactionTime;
    }
    if (incomeExpenseColorScheme != null) {
      map['income_expense_color_scheme'] = incomeExpenseColorScheme;
    }
    if (cloudServiceType != null && cloudServiceType!.isNotEmpty) {
      map['cloud_service_type'] = cloudServiceType;
    }
    if (autoSync != null) {
      map['auto_sync'] = autoSync;
    }
    if (autoScreenshotEnabled != null) {
      map['auto_screenshot_enabled'] = autoScreenshotEnabled;
    }
    if (shortcutPreferCamera != null) {
      map['shortcut_prefer_camera'] = shortcutPreferCamera;
    }

    return map;
  }

  static AppSettingsConfig fromMap(Map<String, dynamic> map) =>
      AppSettingsConfig(
        accountFeatureEnabled: map['account_feature_enabled'] as bool?,
        defaultIncomeAccountName: map['default_income_account_name'] as String?,
        defaultExpenseAccountName: map['default_expense_account_name'] as String?,
        reminderEnabled: map['reminder_enabled'] as bool?,
        reminderHour: map['reminder_hour'] as int?,
        reminderMinute: map['reminder_minute'] as int?,
        languageCode: map['language_code'] as String?,
        countryCode: map['country_code'] as String?,
        primaryColor: map['primary_color'] as int?,
        fontScaleLevel: map['font_scale_level'] as int?,
        customFontScale: map['custom_font_scale'] != null
            ? (map['custom_font_scale'] as num).toDouble()
            : null,
        themeMode: map['theme_mode'] as String?,
        darkModePatternStyle: map['dark_mode_pattern_style'] as String?,
        compactAmount: map['compact_amount'] as bool?,
        showTransactionTime: map['show_transaction_time'] as bool?,
        incomeExpenseColorScheme: map['income_expense_color_scheme'] as bool?,
        cloudServiceType: map['cloud_service_type'] as String?,
        autoSync: map['auto_sync'] as bool?,
        autoScreenshotEnabled: map['auto_screenshot_enabled'] as bool?,
        shortcutPreferCamera: map['shortcut_prefer_camera'] as bool?,
      );
}

/// 账本配置
class LedgersConfig {
  final List<LedgerItem> items;

  const LedgersConfig({required this.items});

  Map<String, dynamic> toMap() {
    return {
      'items': items.map((item) => item.toMap()).toList(),
    };
  }

  static LedgersConfig fromMap(Map<String, dynamic> map) {
    final itemsList = map['items'] as List<dynamic>? ?? [];
    return LedgersConfig(
      items: itemsList
          .map((item) =>
              LedgerItem.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}

/// 账本项
class LedgerItem {
  final String name;
  final String currency;
  final String? type; // personal / shared
  final String? createdAt; // ISO 8601 format

  const LedgerItem({
    required this.name,
    required this.currency,
    this.type,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'currency': currency,
    };
    if (type != null && type!.isNotEmpty) map['type'] = type;
    if (createdAt != null) map['created_at'] = createdAt;
    return map;
  }

  static LedgerItem fromMap(Map<String, dynamic> map) {
    return LedgerItem(
      name: map['name'] as String,
      currency: map['currency'] as String? ?? 'CNY',
      type: map['type'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  factory LedgerItem.fromDb(Ledger ledger) {
    return LedgerItem(
      name: ledger.name,
      currency: ledger.currency,
      type: ledger.type,
      createdAt: ledger.createdAt.toIso8601String(),
    );
  }
}

/// 周期账单配置
class RecurringTransactionsConfig {
  final List<RecurringTransactionItem> items;

  const RecurringTransactionsConfig({required this.items});

  Map<String, dynamic> toMap() {
    return {
      'items': items.map((item) => item.toMap()).toList(),
    };
  }

  static RecurringTransactionsConfig fromMap(Map<String, dynamic> map) {
    final itemsList = map['items'] as List<dynamic>? ?? [];
    return RecurringTransactionsConfig(
      items: itemsList
          .map((item) =>
              RecurringTransactionItem.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}

/// 周期账单项
class RecurringTransactionItem {
  final String ledgerName; // 账本名称（用于导出/导入匹配）
  final String type; // expense / income / transfer
  final double amount;
  final String? categoryName; // 分类名称（用于导出/导入匹配）
  final String? accountName; // 账户名称（用于导出/导入匹配）
  final String? toAccountName; // 转账目标账户名称（用于导出/导入匹配）
  final String? note;
  final String frequency; // daily / weekly / monthly / yearly
  final int interval;
  final int? dayOfMonth;
  final int? dayOfWeek;
  final int? monthOfYear;
  final String startDate; // ISO 8601 format
  final String? endDate;
  final bool enabled;

  const RecurringTransactionItem({
    required this.ledgerName,
    required this.type,
    required this.amount,
    this.categoryName,
    this.accountName,
    this.toAccountName,
    this.note,
    required this.frequency,
    required this.interval,
    this.dayOfMonth,
    this.dayOfWeek,
    this.monthOfYear,
    required this.startDate,
    this.endDate,
    required this.enabled,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'ledger_name': ledgerName,
      'type': type,
      'amount': amount,
      'frequency': frequency,
      'interval': interval,
      'start_date': startDate,
      'enabled': enabled,
    };
    if (categoryName != null) map['category_name'] = categoryName;
    if (accountName != null) map['account_name'] = accountName;
    if (toAccountName != null) map['to_account_name'] = toAccountName;
    if (note != null && note!.isNotEmpty) map['note'] = note;
    if (dayOfMonth != null) map['day_of_month'] = dayOfMonth;
    if (dayOfWeek != null) map['day_of_week'] = dayOfWeek;
    if (monthOfYear != null) map['month_of_year'] = monthOfYear;
    if (endDate != null) map['end_date'] = endDate;
    return map;
  }

  static RecurringTransactionItem fromMap(Map<String, dynamic> map) {
    return RecurringTransactionItem(
      ledgerName: map['ledger_name'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryName: map['category_name'] as String?,
      accountName: map['account_name'] as String?,
      toAccountName: map['to_account_name'] as String?,
      note: map['note'] as String?,
      frequency: map['frequency'] as String,
      interval: map['interval'] as int,
      dayOfMonth: map['day_of_month'] as int?,
      dayOfWeek: map['day_of_week'] as int?,
      monthOfYear: map['month_of_year'] as int?,
      startDate: map['start_date'] as String,
      endDate: map['end_date'] as String?,
      enabled: map['enabled'] as bool,
    );
  }

  /// 从数据库实体创建，需要传入名称映射
  factory RecurringTransactionItem.fromDb(
    RecurringTransaction rt, {
    required Map<int, String> ledgerIdToName,
    required Map<int, String> categoryIdToName,
    required Map<int, String> accountIdToName,
  }) {
    return RecurringTransactionItem(
      ledgerName: ledgerIdToName[rt.ledgerId] ?? 'Unknown',
      type: rt.type,
      amount: rt.amount,
      categoryName: rt.categoryId != null ? categoryIdToName[rt.categoryId] : null,
      accountName: rt.accountId != null ? accountIdToName[rt.accountId] : null,
      toAccountName: rt.toAccountId != null ? accountIdToName[rt.toAccountId] : null,
      note: rt.note,
      frequency: rt.frequency,
      interval: rt.interval,
      dayOfMonth: rt.dayOfMonth,
      dayOfWeek: rt.dayOfWeek,
      monthOfYear: rt.monthOfYear,
      startDate: rt.startDate.toIso8601String(),
      endDate: rt.endDate?.toIso8601String(),
      enabled: rt.enabled,
    );
  }
}

/// 账户配置
class AccountsConfig {
  final List<AccountItem> items;

  const AccountsConfig({required this.items});

  Map<String, dynamic> toMap() {
    return {
      'items': items.map((item) => item.toMap()).toList(),
    };
  }

  static AccountsConfig fromMap(Map<String, dynamic> map) {
    final itemsList = map['items'] as List<dynamic>? ?? [];
    return AccountsConfig(
      items: itemsList
          .map((item) =>
              AccountItem.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}

/// 账户项
class AccountItem {
  final String name;
  final String type;
  final String currency;
  final double initialBalance;
  final String? createdAt; // ISO 8601 format
  final double? creditLimit; // 信用额度
  final int? billingDay; // 账单日 (1-28)
  final int? paymentDueDay; // 还款日 (1-28)
  final String? bankName; // 开户行
  final String? cardLastFour; // 卡号后四位
  final String? note; // 备注

  const AccountItem({
    required this.name,
    required this.type,
    required this.currency,
    required this.initialBalance,
    this.createdAt,
    this.creditLimit,
    this.billingDay,
    this.paymentDueDay,
    this.bankName,
    this.cardLastFour,
    this.note,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'type': type,
      'currency': currency,
      'initial_balance': initialBalance,
    };
    if (createdAt != null) map['created_at'] = createdAt;
    if (creditLimit != null) map['credit_limit'] = creditLimit;
    if (billingDay != null) map['billing_day'] = billingDay;
    if (paymentDueDay != null) map['payment_due_day'] = paymentDueDay;
    if (bankName != null) map['bank_name'] = bankName;
    if (cardLastFour != null) map['card_last_four'] = cardLastFour;
    if (note != null) map['note'] = note;
    return map;
  }

  static AccountItem fromMap(Map<String, dynamic> map) {
    return AccountItem(
      name: map['name'] as String,
      type: map['type'] as String,
      currency: map['currency'] as String? ?? 'CNY',
      initialBalance: (map['initial_balance'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'] as String?,
      creditLimit: (map['credit_limit'] as num?)?.toDouble(),
      billingDay: map['billing_day'] as int?,
      paymentDueDay: map['payment_due_day'] as int?,
      bankName: map['bank_name'] as String?,
      cardLastFour: map['card_last_four'] as String?,
      note: map['note'] as String?,
    );
  }

  factory AccountItem.fromDb(Account account) {
    return AccountItem(
      name: account.name,
      type: account.type,
      currency: account.currency,
      initialBalance: account.initialBalance,
      createdAt: account.createdAt?.toIso8601String(),
      creditLimit: account.creditLimit,
      billingDay: account.billingDay,
      paymentDueDay: account.paymentDueDay,
      bankName: account.bankName,
      cardLastFour: account.cardLastFour,
      note: account.note,
    );
  }
}

/// 分类配置
class CategoriesConfig {
  final List<CategoryItem> items;

  const CategoriesConfig({required this.items});

  Map<String, dynamic> toMap() {
    return {
      'items': items.map((item) => item.toMap()).toList(),
    };
  }

  static CategoriesConfig fromMap(Map<String, dynamic> map) {
    final itemsList = map['items'] as List<dynamic>? ?? [];
    return CategoriesConfig(
      items: itemsList
          .map((item) =>
              CategoryItem.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}

/// 分类项
class CategoryItem {
  final String name;
  final String kind; // expense / income
  final String? icon;
  final int sortOrder;
  final String? parentName; // 使用父分类名称而非ID
  final int level;
  final String? iconType; // material / custom / community
  final String? customIconPath; // 自定义图标相对路径
  final String? communityIconId; // 社区图标ID

  const CategoryItem({
    required this.name,
    required this.kind,
    this.icon,
    required this.sortOrder,
    this.parentName,
    required this.level,
    this.iconType,
    this.customIconPath,
    this.communityIconId,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'kind': kind,
      'sort_order': sortOrder,
      'level': level,
    };
    if (icon != null) map['icon'] = icon;
    if (parentName != null) map['parent_name'] = parentName;
    if (iconType != null) map['icon_type'] = iconType;
    if (customIconPath != null) map['custom_icon_path'] = customIconPath;
    if (communityIconId != null) map['community_icon_id'] = communityIconId;
    return map;
  }

  static CategoryItem fromMap(Map<String, dynamic> map) {
    return CategoryItem(
      name: map['name'] as String,
      kind: map['kind'] as String,
      icon: map['icon'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      parentName: map['parent_name'] as String?,
      level: map['level'] as int? ?? 1,
      iconType: map['icon_type'] as String?,
      customIconPath: map['custom_icon_path'] as String?,
      communityIconId: map['community_icon_id'] as String?,
    );
  }

  factory CategoryItem.fromDb(Category category, String? parentName) {
    return CategoryItem(
      name: category.name,
      kind: category.kind,
      icon: category.icon,
      sortOrder: category.sortOrder,
      parentName: parentName,
      level: category.level,
      iconType: category.iconType,
      customIconPath: category.customIconPath,
      communityIconId: category.communityIconId,
    );
  }
}

/// 标签配置
class TagsConfig {
  final List<TagItem> items;

  const TagsConfig({required this.items});

  Map<String, dynamic> toMap() {
    return {
      'items': items.map((item) => item.toMap()).toList(),
    };
  }

  static TagsConfig fromMap(Map<String, dynamic> map) {
    final itemsList = map['items'] as List<dynamic>? ?? [];
    return TagsConfig(
      items: itemsList
          .map((item) =>
              TagItem.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}

/// 标签项
class TagItem {
  final String name;
  final String? color;

  const TagItem({
    required this.name,
    this.color,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
    };
    if (color != null && color!.isNotEmpty) {
      map['color'] = color;
    }
    return map;
  }

  static TagItem fromMap(Map<String, dynamic> map) {
    return TagItem(
      name: map['name'] as String,
      color: map['color']?.toString(),
    );
  }

  factory TagItem.fromDb(Tag tag) {
    return TagItem(
      name: tag.name,
      color: tag.color,
    );
  }
}

/// 预算配置
class BudgetsConfig {
  final List<BudgetItem> items;

  const BudgetsConfig({required this.items});

  Map<String, dynamic> toMap() {
    return {
      'items': items.map((item) => item.toMap()).toList(),
    };
  }

  static BudgetsConfig fromMap(Map<String, dynamic> map) {
    final itemsList = map['items'] as List<dynamic>? ?? [];
    return BudgetsConfig(
      items: itemsList
          .map((item) =>
              BudgetItem.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}

/// 预算项
class BudgetItem {
  final String ledgerName; // 账本名称（用于导出/导入匹配）
  final String type; // total / category
  final String? categoryName; // 分类名称（用于导出/导入匹配）
  final double amount;
  final int startDay;

  const BudgetItem({
    required this.ledgerName,
    required this.type,
    this.categoryName,
    required this.amount,
    required this.startDay,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'ledger_name': ledgerName,
      'type': type,
      'amount': amount,
      'start_day': startDay,
    };
    if (categoryName != null) map['category_name'] = categoryName;
    return map;
  }

  static BudgetItem fromMap(Map<String, dynamic> map) {
    return BudgetItem(
      ledgerName: map['ledger_name'] as String,
      type: map['type'] as String,
      categoryName: map['category_name'] as String?,
      amount: (map['amount'] as num).toDouble(),
      startDay: map['start_day'] as int? ?? 1,
    );
  }
}

/// 配置内容检测结果
class ConfigContentInfo {
  final bool hasLedgers;
  final bool hasCategories;
  final bool hasAccounts;
  final bool hasTags;
  final bool hasRecurringTransactions;
  final bool hasBudgets;
  final bool hasAppSettings; // 包含云服务配置、应用设置
  final bool hasAi; // AI 服务商配置、能力绑定

  const ConfigContentInfo({
    this.hasLedgers = false,
    this.hasCategories = false,
    this.hasAccounts = false,
    this.hasTags = false,
    this.hasRecurringTransactions = false,
    this.hasBudgets = false,
    this.hasAppSettings = false,
    this.hasAi = false,
  });
}

/// 配置导入导出服务
class ConfigExportService {
  /// 检测 YAML 内容中包含哪些配置项
  static ConfigContentInfo detectContent(String yamlContent) {
    try {
      final doc = loadYaml(yamlContent);
      if (doc is! Map) {
        return const ConfigContentInfo();
      }

      return ConfigContentInfo(
        hasLedgers: doc.containsKey('ledgers'),
        hasCategories: doc.containsKey('categories'),
        hasAccounts: doc.containsKey('accounts'),
        hasTags: doc.containsKey('tags'),
        hasRecurringTransactions: doc.containsKey('recurring_transactions'),
        hasBudgets: doc.containsKey('budgets'),
        hasAppSettings: doc.containsKey('supabase') ||
            doc.containsKey('webdav') ||
            doc.containsKey('s3') ||
            doc.containsKey('app_settings'),
        hasAi: doc.containsKey('ai'),
      );
    } catch (_) {
      return const ConfigContentInfo();
    }
  }

  /// 导出配置到YAML字符串
  /// [repository] 数据仓库实例，用于导出周期账单等数据
  /// [ledgerId] 账本ID，用于过滤导出的周期账单
  /// [options] 导出选项，控制导出哪些内容
  static Future<String> exportToYaml({
    BaseRepository? repository,
    int? ledgerId,
    ExportOptions options = ExportOptions.all,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 读取Supabase配置
    SupabaseConfig? supabaseConfig;
    final supabaseCfgRaw = prefs.getString('cloud_supabase_cfg');
    if (supabaseCfgRaw != null) {
      try {
        final cfg = decodeCloudConfig(supabaseCfgRaw);
        if (cfg.supabaseUrl != null && cfg.supabaseAnonKey != null) {
          supabaseConfig = SupabaseConfig(
            url: cfg.supabaseUrl!,
            anonKey: cfg.supabaseAnonKey!,
            bucket: cfg.supabaseBucket,
            email: cfg.supabaseEmail,
            password: cfg.supabasePassword,
          );
        }
      } catch (e) {
        logger.warning('ConfigExport', '读取Supabase配置失败: $e');
      }
    }

    // 读取WebDAV配置
    WebdavConfig? webdavConfig;
    final webdavCfgRaw = prefs.getString('cloud_webdav_cfg');
    if (webdavCfgRaw != null) {
      try {
        final cfg = decodeCloudConfig(webdavCfgRaw);
        if (cfg.webdavUrl != null &&
            cfg.webdavUsername != null &&
            cfg.webdavPassword != null) {
          webdavConfig = WebdavConfig(
            url: cfg.webdavUrl!,
            username: cfg.webdavUsername!,
            password: cfg.webdavPassword!,
            remotePath: cfg.webdavRemotePath,
          );
        }
      } catch (e) {
        logger.warning('ConfigExport', '读取WebDAV配置失败: $e');
      }
    }

    // 读取S3配置
    S3Config? s3Config;
    final s3CfgRaw = prefs.getString('cloud_s3_cfg');
    if (s3CfgRaw != null) {
      try {
        final cfg = decodeCloudConfig(s3CfgRaw);
        if (cfg.s3Endpoint != null &&
            cfg.s3Region != null &&
            cfg.s3AccessKey != null &&
            cfg.s3SecretKey != null &&
            cfg.s3Bucket != null) {
          s3Config = S3Config(
            endpoint: cfg.s3Endpoint!,
            region: cfg.s3Region!,
            accessKey: cfg.s3AccessKey!,
            secretKey: cfg.s3SecretKey!,
            bucket: cfg.s3Bucket!,
            useSSL: cfg.s3UseSSL,
            port: cfg.s3Port,
          );
        }
      } catch (e) {
        logger.warning('ConfigExport', '读取S3配置失败: $e');
      }
    }

    // 读取 BeeCount Cloud 配置。base_url + email 总是导出（方便 B 设备导入
    // 快速填回登录表单）；access/refresh token 属于登录态，需 options 显式
    // 勾选才带上。当前实现：cloud_beecount_cloud_cfg 里只存 base_url+email，
    // session token 另一把 SharedPreferences key 管 —— 导出 yaml 只取前者。
    BeeCountCloudConfig? beecountCloudConfig;
    final beecountCfgRaw = prefs.getString('cloud_beecount_cloud_cfg');
    if (beecountCfgRaw != null) {
      try {
        final cfg = decodeCloudConfig(beecountCfgRaw);
        final baseUrl = cfg.beecountCloudBaseUrl ?? '';
        if (baseUrl.isNotEmpty) {
          beecountCloudConfig = BeeCountCloudConfig(
            baseUrl: baseUrl,
            email: cfg.beecountCloudEmail,
            // 跟 Supabase 一样：如果用户在 mobile 勾过 "记住账号密码"，
            // beecountCloudPassword 就会在 SharedPreferences 里，带上它方便
            // B 设备导入后无感登录。没勾就是 null，yaml 也不写这一行。
            password: cfg.beecountCloudPassword,
            // access/refresh token 走独立 session storage（key 里带 baseUrl
            // sha1），跨设备迁移风险高，导出 yaml 不带。
          );
        }
      } catch (e) {
        logger.warning('ConfigExport', '读取 BeeCount Cloud 配置失败: $e');
      }
    }

    // 读取AI配置
    AIConfig? aiConfig;
    final glmApiKey = prefs.getString(AIConstants.keyGlmApiKey);
    final glmModel = prefs.getString(AIConstants.keyGlmModel);
    final glmVisionModel = prefs.getString(AIConstants.keyGlmVisionModel);
    final aiStrategy = prefs.getString(AIConstants.keyAiStrategy);
    final aiEnabled = prefs.getBool(AIConstants.keyAiBillExtractionEnabled);
    final aiUseVision = prefs.getBool(AIConstants.keyAiUseVision);

    // 读取服务商列表和能力绑定
    List<AIServiceProviderConfig>? aiProviders;
    AICapabilityBinding? aiCapabilityBinding;
    try {
      aiProviders = await AIProviderManager.getProviders();
      aiCapabilityBinding = await AIProviderManager.getCapabilityBinding();
      logger.info('ConfigExport', 'AI服务商数量: ${aiProviders.length}');
      for (final p in aiProviders) {
        logger.info('ConfigExport', '  服务商: ${p.name} (${p.id}), isBuiltIn=${p.isBuiltIn}');
      }
      logger.info('ConfigExport', 'AI能力绑定: text=${aiCapabilityBinding.textProviderId}, vision=${aiCapabilityBinding.visionProviderId}, speech=${aiCapabilityBinding.speechProviderId}');
    } catch (e) {
      logger.warning('ConfigExport', '读取AI服务商配置失败: $e');
    }

    if (glmApiKey != null || aiStrategy != null || aiEnabled != null ||
        aiUseVision != null || glmModel != null || glmVisionModel != null ||
        aiProviders != null || aiCapabilityBinding != null) {
      aiConfig = AIConfig(
        glmApiKey: glmApiKey,
        glmModel: glmModel,
        glmVisionModel: glmVisionModel,
        strategy: aiStrategy,
        enabled: aiEnabled,
        useVision: aiUseVision,
        providers: aiProviders,
        capabilityBinding: aiCapabilityBinding,
      );
    }

    // 预先获取所有账本、分类、账户的名称映射（用于关联数据导出）
    Map<int, String> ledgerIdToName = {};
    Map<int, String> categoryIdToName = {};
    Map<int, String> accountIdToName = {};

    if (repository != null) {
      try {
        final ledgers = await repository.getAllLedgers();
        ledgerIdToName = {for (var l in ledgers) l.id: l.name};

        final categories = await repository.getAllCategories();
        categoryIdToName = {for (var c in categories) c.id: c.name};

        final accounts = await repository.getAllAccounts();
        accountIdToName = {for (var a in accounts) a.id: a.name};
      } catch (e) {
        logger.warning('ConfigExport', '获取名称映射失败: $e');
      }
    }

    // 收集需要强制导出的关联数据ID
    final Set<int> requiredLedgerIds = {};
    final Set<int> requiredCategoryIds = {};
    final Set<int> requiredAccountIds = {};

    // 读取应用设置
    AppSettingsConfig? appSettings;
    final accountFeatureEnabled = prefs.getBool('account_feature_enabled');
    final defaultIncomeAccountId = prefs.getInt('default_income_account_id');
    final defaultExpenseAccountId = prefs.getInt('default_expense_account_id');
    final reminderEnabled = prefs.getBool('reminder_enabled');
    final reminderHour = prefs.getInt('reminder_hour');
    final reminderMinute = prefs.getInt('reminder_minute');
    final languageCode = prefs.getString('selected_language');
    final countryCode = prefs.getString('selected_language_country');
    final primaryColor = prefs.getInt('primaryColor');
    final fontScaleLevel = prefs.getInt('fontScaleLevel');
    final customFontScale = prefs.getDouble('customFontScale');
    final themeMode = prefs.getString('themeMode');
    final darkModePatternStyle = prefs.getString('darkModePatternStyle');
    final compactAmount = prefs.getBool('compactAmount');
    final showTransactionTime = prefs.getBool('showTransactionTime');
    final incomeExpenseColorScheme = prefs.getBool('incomeExpenseColorScheme');
    final cloudServiceType = prefs.getString('cloud_active_type');
    final autoSync = prefs.getBool('auto_sync');
    final autoScreenshotEnabled = prefs.getBool('auto_screenshot_billing_enabled');
    final shortcutPreferCamera = prefs.getBool('shortcut_prefer_camera');

    // 获取默认账户名称并收集需要强制导出的账户
    String? defaultIncomeAccountName;
    String? defaultExpenseAccountName;
    if (defaultIncomeAccountId != null) {
      defaultIncomeAccountName = accountIdToName[defaultIncomeAccountId];
      if (defaultIncomeAccountName != null) {
        requiredAccountIds.add(defaultIncomeAccountId);
      }
    }
    if (defaultExpenseAccountId != null) {
      defaultExpenseAccountName = accountIdToName[defaultExpenseAccountId];
      if (defaultExpenseAccountName != null) {
        requiredAccountIds.add(defaultExpenseAccountId);
      }
    }

    // 如果有任何应用设置，就创建配置对象
    if (accountFeatureEnabled != null ||
        defaultIncomeAccountName != null ||
        defaultExpenseAccountName != null ||
        reminderEnabled != null ||
        reminderHour != null ||
        reminderMinute != null ||
        languageCode != null ||
        countryCode != null ||
        primaryColor != null ||
        fontScaleLevel != null ||
        customFontScale != null ||
        themeMode != null ||
        darkModePatternStyle != null ||
        compactAmount != null ||
        showTransactionTime != null ||
        incomeExpenseColorScheme != null ||
        cloudServiceType != null ||
        autoSync != null ||
        autoScreenshotEnabled != null ||
        shortcutPreferCamera != null) {
      appSettings = AppSettingsConfig(
        accountFeatureEnabled: accountFeatureEnabled,
        defaultIncomeAccountName: defaultIncomeAccountName,
        defaultExpenseAccountName: defaultExpenseAccountName,
        reminderEnabled: reminderEnabled,
        reminderHour: reminderHour,
        reminderMinute: reminderMinute,
        languageCode: languageCode,
        countryCode: countryCode,
        primaryColor: primaryColor,
        fontScaleLevel: fontScaleLevel,
        customFontScale: customFontScale,
        themeMode: themeMode,
        darkModePatternStyle: darkModePatternStyle,
        compactAmount: compactAmount,
        showTransactionTime: showTransactionTime,
        incomeExpenseColorScheme: incomeExpenseColorScheme,
        cloudServiceType: cloudServiceType,
        autoSync: autoSync,
        autoScreenshotEnabled: autoScreenshotEnabled,
        shortcutPreferCamera: shortcutPreferCamera,
      );
    }

    // 读取周期账单配置（导出全部账本的周期记账）
    RecurringTransactionsConfig? recurringConfig;
    if (options.recurringTransactions && repository != null) {
      try {
        final recurringList = await repository.getAllRecurringTransactions();

        if (recurringList.isNotEmpty) {
          // 收集周期账单关联的账本、分类、账户ID
          for (final rt in recurringList) {
            requiredLedgerIds.add(rt.ledgerId);
            if (rt.categoryId != null) {
              requiredCategoryIds.add(rt.categoryId!);
            }
            if (rt.accountId != null) {
              requiredAccountIds.add(rt.accountId!);
            }
            if (rt.toAccountId != null) {
              requiredAccountIds.add(rt.toAccountId!);
            }
          }

          recurringConfig = RecurringTransactionsConfig(
            items: recurringList
                .map((rt) => RecurringTransactionItem.fromDb(
                      rt,
                      ledgerIdToName: ledgerIdToName,
                      categoryIdToName: categoryIdToName,
                      accountIdToName: accountIdToName,
                    ))
                .toList(),
          );
        }
      } catch (e) {
        logger.warning('ConfigExport', '读取周期账单配置失败: $e');
      }
    }

    // 读取账本配置（导出全部账本，或强制导出关联的账本）
    LedgersConfig? ledgersConfig;
    if (repository != null && (options.ledgers || requiredLedgerIds.isNotEmpty)) {
      try {
        final ledgersList = await repository.getAllLedgers();

        if (ledgersList.isNotEmpty) {
          // 如果用户选择了导出账本，则导出全部
          // 如果用户没有选择但有关联数据需要账本，则只导出关联的账本
          final itemsToExport = options.ledgers
              ? ledgersList
              : ledgersList.where((l) => requiredLedgerIds.contains(l.id)).toList();

          if (itemsToExport.isNotEmpty) {
            ledgersConfig = LedgersConfig(
              items: itemsToExport
                  .map((ledger) => LedgerItem.fromDb(ledger))
                  .toList(),
            );
          }
        }
      } catch (e) {
        logger.warning('ConfigExport', '读取账本配置失败: $e');
      }
    }

    // 读取账户配置（导出全部账户，或强制导出关联的账户）
    AccountsConfig? accountsConfig;
    if (repository != null && (options.accounts || requiredAccountIds.isNotEmpty)) {
      try {
        final accountsList = await repository.getAllAccounts();

        if (accountsList.isNotEmpty) {
          // 如果用户选择了导出账户，则导出全部
          // 如果用户没有选择但有关联数据需要账户，则只导出关联的账户
          final itemsToExport = options.accounts
              ? accountsList
              : accountsList.where((a) => requiredAccountIds.contains(a.id)).toList();

          if (itemsToExport.isNotEmpty) {
            accountsConfig = AccountsConfig(
              items: itemsToExport
                  .map((account) => AccountItem.fromDb(account))
                  .toList(),
            );
          }
        }
      } catch (e) {
        logger.warning('ConfigExport', '读取账户配置失败: $e');
      }
    }

    // 读取分类配置（导出全部分类，或强制导出关联的分类）
    CategoriesConfig? categoriesConfig;
    if (repository != null && (options.categories || requiredCategoryIds.isNotEmpty)) {
      try {
        // 获取所有分类（收入、支出和转账）
        final expenseCategories = await repository.getTopLevelCategories('expense');
        final incomeCategories = await repository.getTopLevelCategories('income');
        final categoriesList = <Category>[];
        categoriesList.addAll(expenseCategories);
        categoriesList.addAll(incomeCategories);

        // 获取虚拟转账分类
        try {
          final transferCategory = await repository.getTransferCategory();
          categoriesList.add(transferCategory);
        } catch (e) {
          // 转账分类不存在时忽略
        }

        // 获取所有子分类
        for (final category in [...expenseCategories, ...incomeCategories]) {
          final subCategories = await repository.getSubCategories(category.id);
          categoriesList.addAll(subCategories);
        }

        if (categoriesList.isNotEmpty) {
          // 构建 ID 到分类的映射，用于查找父分类名称
          final categoryMap = <int, Category>{
            for (var cat in categoriesList) cat.id: cat
          };

          // 如果用户选择了导出分类，则导出全部
          // 如果用户没有选择但有关联数据需要分类，则只导出关联的分类及其父分类
          List<Category> itemsToExport;
          if (options.categories) {
            itemsToExport = categoriesList;
          } else {
            // 收集需要导出的分类（包括父分类）
            final idsToExport = <int>{};
            for (final id in requiredCategoryIds) {
              if (categoryMap.containsKey(id)) {
                idsToExport.add(id);
                // 如果是子分类，也要导出父分类
                final parentId = categoryMap[id]!.parentId;
                if (parentId != null) {
                  idsToExport.add(parentId);
                }
              }
            }
            itemsToExport = categoriesList.where((c) => idsToExport.contains(c.id)).toList();
          }

          if (itemsToExport.isNotEmpty) {
            categoriesConfig = CategoriesConfig(
              items: itemsToExport.map((category) {
                // 查找父分类名称
                String? parentName;
                if (category.parentId != null && categoryMap.containsKey(category.parentId)) {
                  parentName = categoryMap[category.parentId]!.name;
                }
                return CategoryItem.fromDb(category, parentName);
              }).toList(),
            );
          }
        }
      } catch (e) {
        logger.warning('ConfigExport', '读取分类配置失败: $e');
      }
    }

    // 读取标签配置（导出全部标签）
    TagsConfig? tagsConfig;
    if (options.tags && repository != null) {
      try {
        final tagsList = await repository.getAllTags();

        if (tagsList.isNotEmpty) {
          tagsConfig = TagsConfig(
            items: tagsList.map((tag) => TagItem.fromDb(tag)).toList(),
          );
        }
      } catch (e) {
        logger.warning('ConfigExport', '读取标签配置失败: $e');
      }
    }

    // 读取预算配置（导出全部预算）
    BudgetsConfig? budgetsConfig;
    if (options.budgets && repository != null) {
      try {
        final budgetsList = await repository.getAllBudgetsForExport();

        if (budgetsList.isNotEmpty) {
          // 获取账本和分类的名称映射
          final ledgers = await repository.getAllLedgers();
          final ledgerMap = {for (var l in ledgers) l.id: l.name};

          final categories = await repository.getAllCategories();
          final categoryMap = {for (var c in categories) c.id: c.name};

          budgetsConfig = BudgetsConfig(
            items: budgetsList.map((budget) => BudgetItem(
              ledgerName: ledgerMap[budget.ledgerId] ?? 'Unknown',
              type: budget.type,
              categoryName: budget.categoryId != null
                  ? categoryMap[budget.categoryId]
                  : null,
              amount: budget.amount,
              startDay: budget.startDay,
            )).toList(),
          );
        }
      } catch (e) {
        logger.warning('ConfigExport', '读取预算配置失败: $e');
      }
    }

    // 根据选项过滤云服务和AI配置
    final exportSupabase = options.appSettings ? supabaseConfig : null;
    final exportWebdav = options.appSettings ? webdavConfig : null;
    final exportS3 = options.appSettings ? s3Config : null;
    final exportBeecountCloud =
        options.appSettings ? beecountCloudConfig : null;
    final exportAi = options.ai ? aiConfig : null;
    final exportAppSettings = options.appSettings ? appSettings : null;

    logger.info('ConfigExport', '导出选项: ai=${options.ai}, aiConfig是否存在=${aiConfig != null}');
    if (exportAi != null) {
      logger.info('ConfigExport', '导出AI配置: providers数量=${exportAi.providers?.length ?? 0}');
    }

    final config = AppConfig(
      supabase: exportSupabase,
      webdav: exportWebdav,
      s3: exportS3,
      beecountCloud: exportBeecountCloud,
      ai: exportAi,
      appSettings: exportAppSettings,
      ledgers: ledgersConfig,
      recurringTransactions: recurringConfig,
      accounts: accountsConfig,
      categories: categoriesConfig,
      tags: tagsConfig,
      budgets: budgetsConfig,
    );

    // 转换为YAML格式
    final yamlMap = config.toYaml();

    // 手动构建YAML字符串以保持良好格式
    final buffer = StringBuffer();
    buffer.writeln('# BeeCount 应用配置');
    buffer.writeln('# 导出时间: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    if (yamlMap.containsKey('supabase')) {
      buffer.writeln('supabase:');
      final sb = yamlMap['supabase'] as Map<String, dynamic>;
      buffer.writeln('  url: "${sb['url']}"');
      buffer.writeln('  anon_key: "${sb['anon_key']}"');
      if (sb.containsKey('bucket')) {
        buffer.writeln('  # Storage bucket 名称，留空则使用默认值 beecount-backups');
        buffer.writeln('  bucket: "${sb['bucket']}"');
      }
      if (sb.containsKey('email') || sb.containsKey('password')) {
        buffer.writeln('  # 记住账号密码功能：导入后登录页面会自动填充');
      }
      if (sb.containsKey('email')) {
        buffer.writeln('  email: "${sb['email']}"');
      }
      if (sb.containsKey('password')) {
        buffer.writeln('  password: "${sb['password']}"');
      }
      buffer.writeln();
    }

    if (yamlMap.containsKey('webdav')) {
      buffer.writeln('webdav:');
      final wd = yamlMap['webdav'] as Map<String, dynamic>;
      buffer.writeln('  url: "${wd['url']}"');
      buffer.writeln('  username: "${wd['username']}"');
      buffer.writeln('  password: "${wd['password']}"');
      if (wd.containsKey('remote_path')) {
        buffer.writeln('  remote_path: "${wd['remote_path']}"');
      }
      buffer.writeln();
    }

    if (yamlMap.containsKey('s3')) {
      buffer.writeln('s3:');
      final s3 = yamlMap['s3'] as Map<String, dynamic>;
      buffer.writeln('  endpoint: "${s3['endpoint']}"');
      buffer.writeln('  region: "${s3['region']}"');
      buffer.writeln('  access_key: "${s3['access_key']}"');
      buffer.writeln('  secret_key: "${s3['secret_key']}"');
      buffer.writeln('  bucket: "${s3['bucket']}"');
      if (s3.containsKey('use_ssl')) {
        buffer.writeln('  use_ssl: ${s3['use_ssl']}');
      }
      if (s3.containsKey('port')) {
        buffer.writeln('  port: ${s3['port']}');
      }
      buffer.writeln();
    }

    if (yamlMap.containsKey('beecount_cloud')) {
      buffer.writeln('beecount_cloud:');
      final bc = yamlMap['beecount_cloud'] as Map<String, dynamic>;
      buffer.writeln('  # BeeCount Cloud 自部署后端配置');
      buffer.writeln('  base_url: "${bc['base_url']}"');
      if (bc.containsKey('email') || bc.containsKey('password')) {
        buffer.writeln('  # 记住账号密码功能：导入后登录页面会自动填充');
      }
      if (bc.containsKey('email')) {
        buffer.writeln('  email: "${bc['email']}"');
      }
      if (bc.containsKey('password')) {
        buffer.writeln('  password: "${bc['password']}"');
      }
      if (bc.containsKey('access_token')) {
        buffer.writeln('  access_token: "${bc['access_token']}"');
      }
      if (bc.containsKey('refresh_token')) {
        buffer.writeln('  refresh_token: "${bc['refresh_token']}"');
      }
      if (bc.containsKey('device_id')) {
        buffer.writeln('  device_id: "${bc['device_id']}"');
      }
      buffer.writeln();
    }

    if (yamlMap.containsKey('ai')) {
      buffer.writeln('ai:');
      final ai = yamlMap['ai'] as Map<String, dynamic>;
      if (ai.containsKey(AIConstants.keyGlmApiKey)) {
        buffer.writeln('  ${AIConstants.keyGlmApiKey}: "${ai[AIConstants.keyGlmApiKey]}"');
      }
      if (ai.containsKey(AIConstants.keyGlmModel)) {
        buffer.writeln('  ${AIConstants.keyGlmModel}: "${ai[AIConstants.keyGlmModel]}"');
      }
      if (ai.containsKey(AIConstants.keyGlmVisionModel)) {
        buffer.writeln('  ${AIConstants.keyGlmVisionModel}: "${ai[AIConstants.keyGlmVisionModel]}"');
      }
      if (ai.containsKey(AIConstants.keyAiStrategy)) {
        buffer.writeln('  ${AIConstants.keyAiStrategy}: "${ai[AIConstants.keyAiStrategy]}"');
      }
      if (ai.containsKey(AIConstants.keyAiBillExtractionEnabled)) {
        buffer.writeln('  ${AIConstants.keyAiBillExtractionEnabled}: ${ai[AIConstants.keyAiBillExtractionEnabled]}');
      }
      if (ai.containsKey(AIConstants.keyAiUseVision)) {
        buffer.writeln('  ${AIConstants.keyAiUseVision}: ${ai[AIConstants.keyAiUseVision]}');
      }
      // 服务商列表
      if (ai.containsKey('providers')) {
        buffer.writeln('  providers:');
        final providers = ai['providers'] as List;
        for (final p in providers) {
          final provider = p as Map<String, dynamic>;
          buffer.writeln('    - id: "${provider['id']}"');
          buffer.writeln('      name: "${provider['name']}"');
          buffer.writeln('      isBuiltIn: ${provider['isBuiltIn']}');
          if (provider['apiKey'] != null && (provider['apiKey'] as String).isNotEmpty) {
            buffer.writeln('      apiKey: "${provider['apiKey']}"');
          }
          if (provider['baseUrl'] != null && (provider['baseUrl'] as String).isNotEmpty) {
            buffer.writeln('      baseUrl: "${provider['baseUrl']}"');
          }
          if (provider['textModel'] != null && (provider['textModel'] as String).isNotEmpty) {
            buffer.writeln('      textModel: "${provider['textModel']}"');
          }
          if (provider['visionModel'] != null && (provider['visionModel'] as String).isNotEmpty) {
            buffer.writeln('      visionModel: "${provider['visionModel']}"');
          }
          if (provider['audioModel'] != null && (provider['audioModel'] as String).isNotEmpty) {
            buffer.writeln('      audioModel: "${provider['audioModel']}"');
          }
        }
      }
      // 能力绑定
      if (ai.containsKey('capability_binding')) {
        buffer.writeln('  capability_binding:');
        final binding = ai['capability_binding'] as Map<String, dynamic>;
        if (binding['textProviderId'] != null) {
          buffer.writeln('    textProviderId: "${binding['textProviderId']}"');
        }
        if (binding['visionProviderId'] != null) {
          buffer.writeln('    visionProviderId: "${binding['visionProviderId']}"');
        }
        if (binding['speechProviderId'] != null) {
          buffer.writeln('    speechProviderId: "${binding['speechProviderId']}"');
        }
      }
      buffer.writeln();
    }

    if (yamlMap.containsKey('app_settings')) {
      buffer.writeln('app_settings:');
      final settings = yamlMap['app_settings'] as Map<String, dynamic>;

      if (settings.containsKey('account_feature_enabled') ||
          settings.containsKey('default_income_account_name') ||
          settings.containsKey('default_expense_account_name')) {
        buffer.writeln('  # 账户管理');
        if (settings.containsKey('account_feature_enabled')) {
          buffer.writeln('  account_feature_enabled: ${settings['account_feature_enabled']}');
        }
        if (settings.containsKey('default_income_account_name')) {
          buffer.writeln('  default_income_account_name: "${settings['default_income_account_name']}"');
        }
        if (settings.containsKey('default_expense_account_name')) {
          buffer.writeln('  default_expense_account_name: "${settings['default_expense_account_name']}"');
        }
      }

      if (settings.containsKey('reminder_enabled') ||
          settings.containsKey('reminder_hour') ||
          settings.containsKey('reminder_minute')) {
        buffer.writeln('  # 记账提醒');
        if (settings.containsKey('reminder_enabled')) {
          buffer.writeln('  reminder_enabled: ${settings['reminder_enabled']}');
        }
        if (settings.containsKey('reminder_hour')) {
          buffer.writeln('  reminder_hour: ${settings['reminder_hour']}');
        }
        if (settings.containsKey('reminder_minute')) {
          buffer.writeln('  reminder_minute: ${settings['reminder_minute']}');
        }
      }

      if (settings.containsKey('language_code') || settings.containsKey('country_code')) {
        buffer.writeln('  # 语言设置');
        if (settings.containsKey('language_code')) {
          buffer.writeln('  language_code: "${settings['language_code']}"');
        }
        if (settings.containsKey('country_code')) {
          buffer.writeln('  country_code: "${settings['country_code']}"');
        }
      }

      if (settings.containsKey('primary_color') ||
          settings.containsKey('font_scale_level') ||
          settings.containsKey('custom_font_scale')) {
        buffer.writeln('  # 个性化设置');
        if (settings.containsKey('primary_color')) {
          buffer.writeln('  primary_color: ${settings['primary_color']}');
        }
        if (settings.containsKey('font_scale_level')) {
          buffer.writeln('  font_scale_level: ${settings['font_scale_level']}');
        }
        if (settings.containsKey('custom_font_scale')) {
          buffer.writeln('  custom_font_scale: ${settings['custom_font_scale']}');
        }
      }

      if (settings.containsKey('theme_mode') ||
          settings.containsKey('dark_mode_pattern_style') ||
          settings.containsKey('compact_amount') ||
          settings.containsKey('show_transaction_time')) {
        buffer.writeln('  # 外观设置');
        if (settings.containsKey('theme_mode')) {
          buffer.writeln('  theme_mode: "${settings['theme_mode']}"');
        }
        if (settings.containsKey('dark_mode_pattern_style')) {
          buffer.writeln('  dark_mode_pattern_style: "${settings['dark_mode_pattern_style']}"');
        }
        if (settings.containsKey('compact_amount')) {
          buffer.writeln('  compact_amount: ${settings['compact_amount']}');
        }
        if (settings.containsKey('show_transaction_time')) {
          buffer.writeln('  show_transaction_time: ${settings['show_transaction_time']}');
        }
      }

      if (settings.containsKey('cloud_service_type') ||
          settings.containsKey('auto_sync')) {
        buffer.writeln('  # 云服务');
        if (settings.containsKey('cloud_service_type')) {
          buffer.writeln('  cloud_service_type: "${settings['cloud_service_type']}"');
        }
        if (settings.containsKey('auto_sync')) {
          buffer.writeln('  auto_sync: ${settings['auto_sync']}');
        }
      }

      if (settings.containsKey('auto_screenshot_enabled') ||
          settings.containsKey('shortcut_prefer_camera')) {
        buffer.writeln('  # 自动记账');
        if (settings.containsKey('auto_screenshot_enabled')) {
          buffer.writeln('  auto_screenshot_enabled: ${settings['auto_screenshot_enabled']}');
        }
        if (settings.containsKey('shortcut_prefer_camera')) {
          buffer.writeln('  shortcut_prefer_camera: ${settings['shortcut_prefer_camera']}');
        }
      }
    }

    // 账本
    if (yamlMap.containsKey('ledgers')) {
      buffer.writeln('# 账本');
      buffer.writeln('ledgers:');
      final ledgers = yamlMap['ledgers'] as Map<String, dynamic>;
      final items = ledgers['items'] as List;

      if (items.isNotEmpty) {
        buffer.writeln('  items:');
        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          buffer.writeln('    - name: "${itemMap['name']}"');
          buffer.writeln('      currency: "${itemMap['currency']}"');
          if (itemMap.containsKey('type') && itemMap['type'] != null) {
            buffer.writeln('      type: "${itemMap['type']}"');
          }
          if (itemMap.containsKey('created_at') && itemMap['created_at'] != null) {
            buffer.writeln('      created_at: "${itemMap['created_at']}"');
          }
        }
      }
      buffer.writeln();
    }

    // 周期账单
    if (yamlMap.containsKey('recurring_transactions')) {
      buffer.writeln('# 周期账单');
      buffer.writeln('recurring_transactions:');
      final recurring = yamlMap['recurring_transactions'] as Map<String, dynamic>;
      final items = recurring['items'] as List;

      if (items.isNotEmpty) {
        buffer.writeln('  items:');
        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          buffer.writeln('    - ledger_name: "${itemMap['ledger_name']}"');
          buffer.writeln('      type: "${itemMap['type']}"');
          buffer.writeln('      amount: ${itemMap['amount']}');

          if (itemMap.containsKey('category_name') && itemMap['category_name'] != null) {
            buffer.writeln('      category_name: "${itemMap['category_name']}"');
          }
          if (itemMap.containsKey('account_name') && itemMap['account_name'] != null) {
            buffer.writeln('      account_name: "${itemMap['account_name']}"');
          }
          if (itemMap.containsKey('to_account_name') && itemMap['to_account_name'] != null) {
            buffer.writeln('      to_account_name: "${itemMap['to_account_name']}"');
          }
          if (itemMap.containsKey('note') && itemMap['note'] != null) {
            buffer.writeln('      note: "${itemMap['note']}"');
          }

          buffer.writeln('      frequency: "${itemMap['frequency']}"');
          buffer.writeln('      interval: ${itemMap['interval']}');

          if (itemMap.containsKey('day_of_month')) {
            buffer.writeln('      day_of_month: ${itemMap['day_of_month']}');
          }
          if (itemMap.containsKey('day_of_week')) {
            buffer.writeln('      day_of_week: ${itemMap['day_of_week']}');
          }
          if (itemMap.containsKey('month_of_year')) {
            buffer.writeln('      month_of_year: ${itemMap['month_of_year']}');
          }

          buffer.writeln('      start_date: "${itemMap['start_date']}"');
          if (itemMap.containsKey('end_date') && itemMap['end_date'] != null) {
            buffer.writeln('      end_date: "${itemMap['end_date']}"');
          }
          buffer.writeln('      enabled: ${itemMap['enabled']}');
        }
      }
      buffer.writeln();
    }

    // 账户
    if (yamlMap.containsKey('accounts')) {
      buffer.writeln('# 账户');
      buffer.writeln('accounts:');
      final accounts = yamlMap['accounts'] as Map<String, dynamic>;
      final items = accounts['items'] as List;

      if (items.isNotEmpty) {
        buffer.writeln('  items:');
        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          buffer.writeln('    - name: "${itemMap['name']}"');
          buffer.writeln('      type: "${itemMap['type']}"');
          buffer.writeln('      currency: "${itemMap['currency']}"');
          buffer.writeln('      initial_balance: ${itemMap['initial_balance']}');
          if (itemMap.containsKey('created_at') && itemMap['created_at'] != null) {
            buffer.writeln('      created_at: "${itemMap['created_at']}"');
          }
          if (itemMap.containsKey('credit_limit') && itemMap['credit_limit'] != null) {
            buffer.writeln('      credit_limit: ${itemMap['credit_limit']}');
          }
          if (itemMap.containsKey('billing_day') && itemMap['billing_day'] != null) {
            buffer.writeln('      billing_day: ${itemMap['billing_day']}');
          }
          if (itemMap.containsKey('payment_due_day') && itemMap['payment_due_day'] != null) {
            buffer.writeln('      payment_due_day: ${itemMap['payment_due_day']}');
          }
          if (itemMap.containsKey('bank_name') && itemMap['bank_name'] != null) {
            buffer.writeln('      bank_name: "${itemMap['bank_name']}"');
          }
          if (itemMap.containsKey('card_last_four') && itemMap['card_last_four'] != null) {
            buffer.writeln('      card_last_four: "${itemMap['card_last_four']}"');
          }
          if (itemMap.containsKey('note') && itemMap['note'] != null) {
            buffer.writeln('      note: "${itemMap['note']}"');
          }
        }
      }
      buffer.writeln();
    }

    // 分类
    if (yamlMap.containsKey('categories')) {
      buffer.writeln('# 分类');
      buffer.writeln('categories:');
      final categories = yamlMap['categories'] as Map<String, dynamic>;
      final items = categories['items'] as List;

      if (items.isNotEmpty) {
        buffer.writeln('  items:');
        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          buffer.writeln('    - name: "${itemMap['name']}"');
          buffer.writeln('      kind: "${itemMap['kind']}"');
          if (itemMap.containsKey('icon') && itemMap['icon'] != null) {
            buffer.writeln('      icon: "${itemMap['icon']}"');
          }
          buffer.writeln('      sort_order: ${itemMap['sort_order']}');
          if (itemMap.containsKey('parent_name') && itemMap['parent_name'] != null) {
            buffer.writeln('      parent_name: "${itemMap['parent_name']}"');
          }
          buffer.writeln('      level: ${itemMap['level']}');
          // 自定义图标字段
          if (itemMap.containsKey('icon_type') && itemMap['icon_type'] != null) {
            buffer.writeln('      icon_type: "${itemMap['icon_type']}"');
          }
          if (itemMap.containsKey('custom_icon_path') && itemMap['custom_icon_path'] != null) {
            buffer.writeln('      custom_icon_path: "${itemMap['custom_icon_path']}"');
          }
          if (itemMap.containsKey('community_icon_id') && itemMap['community_icon_id'] != null) {
            buffer.writeln('      community_icon_id: "${itemMap['community_icon_id']}"');
          }
        }
      }
      buffer.writeln();
    }

    // 标签
    if (yamlMap.containsKey('tags')) {
      buffer.writeln('# 标签');
      buffer.writeln('tags:');
      final tags = yamlMap['tags'] as Map<String, dynamic>;
      final items = tags['items'] as List;

      if (items.isNotEmpty) {
        buffer.writeln('  items:');
        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          buffer.writeln('    - name: "${itemMap['name']}"');
          if (itemMap.containsKey('color') && itemMap['color'] != null) {
            buffer.writeln('      color: "${itemMap['color']}"');
          }
        }
      }
      buffer.writeln();
    }

    // 预算
    if (yamlMap.containsKey('budgets')) {
      buffer.writeln('# 预算');
      buffer.writeln('budgets:');
      final budgets = yamlMap['budgets'] as Map<String, dynamic>;
      final items = budgets['items'] as List;

      if (items.isNotEmpty) {
        buffer.writeln('  items:');
        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          buffer.writeln('    - ledger_name: "${itemMap['ledger_name']}"');
          buffer.writeln('      type: "${itemMap['type']}"');
          if (itemMap.containsKey('category_name') && itemMap['category_name'] != null) {
            buffer.writeln('      category_name: "${itemMap['category_name']}"');
          }
          buffer.writeln('      amount: ${itemMap['amount']}');
          buffer.writeln('      start_day: ${itemMap['start_day']}');
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// 从YAML字符串导入配置
  /// [yamlContent] YAML内容
  /// [repository] 数据仓库实例，用于导入周期账单等数据
  /// [ledgerId] 账本ID，用于导入周期账单到指定账本
  /// [options] 导入选项，控制导入哪些内容
  static Future<void> importFromYaml(
    String yamlContent, {
    BaseRepository? repository,
    int? ledgerId,
    ExportOptions options = ExportOptions.all,
  }) async {
    final doc = loadYaml(yamlContent);

    if (doc is! Map) {
      throw const FormatException('无效的YAML格式');
    }

    final config = AppConfig.fromYaml(doc);
    final prefs = await SharedPreferences.getInstance();

    // 导入Supabase配置
    if (options.appSettings && config.supabase != null) {
      final supabaseCfg = CloudServiceConfig(
        type: CloudBackendType.supabase,
        name: 'Supabase',
        supabaseUrl: config.supabase!.url,
        supabaseAnonKey: config.supabase!.anonKey,
        supabaseBucket: config.supabase!.bucket ?? 'beecount-backups',  // 导入时也提供默认值
        supabaseEmail: config.supabase!.email,
        supabasePassword: config.supabase!.password,
      );
      await prefs.setString(
          'cloud_supabase_cfg', encodeCloudConfig(supabaseCfg));
      logger.info('ConfigImport', 'Supabase配置已导入');
    }

    // 导入WebDAV配置
    if (options.appSettings && config.webdav != null) {
      final webdavCfg = CloudServiceConfig(
        type: CloudBackendType.webdav,
        name: 'WebDAV',
        webdavUrl: config.webdav!.url,
        webdavUsername: config.webdav!.username,
        webdavPassword: config.webdav!.password,
        webdavRemotePath: config.webdav!.remotePath,
      );
      await prefs.setString('cloud_webdav_cfg', encodeCloudConfig(webdavCfg));
      logger.info('ConfigImport', 'WebDAV配置已导入');
    }

    // 导入S3配置
    if (options.appSettings && config.s3 != null) {
      final s3Cfg = CloudServiceConfig(
        type: CloudBackendType.s3,
        name: 'S3',
        s3Endpoint: config.s3!.endpoint,
        s3Region: config.s3!.region,
        s3AccessKey: config.s3!.accessKey,
        s3SecretKey: config.s3!.secretKey,
        s3Bucket: config.s3!.bucket,
        s3UseSSL: config.s3!.useSSL,
        s3Port: config.s3!.port,
      );
      await prefs.setString('cloud_s3_cfg', encodeCloudConfig(s3Cfg));
      logger.info('ConfigImport', 'S3配置已导入');
    }

    // 导入 BeeCount Cloud 配置（base_url + 可选 email/password）。
    // 有 email+password 时跟 Supabase 一样，导入后 app 启动可自动登录；
    // 只有 email 时登录页预填邮箱，等用户输密码。
    if (options.appSettings && config.beecountCloud != null) {
      final bcCfg = CloudServiceConfig(
        type: CloudBackendType.beecountCloud,
        name: 'BeeCount Cloud',
        beecountCloudBaseUrl: config.beecountCloud!.baseUrl,
        beecountCloudEmail: config.beecountCloud!.email,
        beecountCloudPassword: config.beecountCloud!.password,
      );
      await prefs.setString(
          'cloud_beecount_cloud_cfg', encodeCloudConfig(bcCfg));
      logger.info(
          'ConfigImport',
          'BeeCount Cloud 配置已导入 url=${config.beecountCloud!.baseUrl} '
              'hasEmail=${config.beecountCloud!.email != null} '
              'hasPassword=${config.beecountCloud!.password != null}');
    }

    // 导入AI配置
    if (options.ai && config.ai != null) {
      // 基础设置（向后兼容）
      if (config.ai!.glmApiKey != null) {
        await prefs.setString(AIConstants.keyGlmApiKey, config.ai!.glmApiKey!);
      }
      if (config.ai!.glmModel != null) {
        await prefs.setString(AIConstants.keyGlmModel, config.ai!.glmModel!);
      }
      if (config.ai!.glmVisionModel != null) {
        await prefs.setString(AIConstants.keyGlmVisionModel, config.ai!.glmVisionModel!);
      }
      if (config.ai!.strategy != null) {
        await prefs.setString(AIConstants.keyAiStrategy, config.ai!.strategy!);
      }
      if (config.ai!.enabled != null) {
        await prefs.setBool(AIConstants.keyAiBillExtractionEnabled, config.ai!.enabled!);
      }
      if (config.ai!.useVision != null) {
        await prefs.setBool(AIConstants.keyAiUseVision, config.ai!.useVision!);
      }

      // 导入服务商列表
      if (config.ai!.providers != null && config.ai!.providers!.isNotEmpty) {
        // 获取现有服务商
        final existingProviders = await AIProviderManager.getProviders();
        final existingIds = existingProviders.map((p) => p.id).toSet();
        final existingNames = existingProviders.map((p) => p.name).toSet();

        for (final provider in config.ai!.providers!) {
          if (provider.isBuiltIn) {
            // 内置服务商：更新配置（如API Key）
            final existingIndex = existingProviders.indexWhere((p) => p.id == provider.id);
            if (existingIndex >= 0) {
              final updated = existingProviders[existingIndex].copyWith(
                apiKey: provider.apiKey.isNotEmpty ? provider.apiKey : null,
                textModel: provider.textModel.isNotEmpty ? provider.textModel : null,
                visionModel: provider.visionModel.isNotEmpty ? provider.visionModel : null,
                audioModel: provider.audioModel.isNotEmpty ? provider.audioModel : null,
              );
              await AIProviderManager.updateProvider(updated);
            }
          } else {
            // 自定义服务商：保留原始 ID 导入
            if (existingIds.contains(provider.id)) {
              // ID 已存在，更新配置
              await AIProviderManager.updateProvider(provider);
            } else if (existingNames.contains(provider.name)) {
              // 名称已存在但 ID 不同，跳过避免重复
              logger.info('ConfigImport', '跳过已存在的服务商: ${provider.name}');
            } else {
              // 直接添加，保留原始 ID（用于能力绑定匹配）
              await AIProviderManager.addProviderWithConfig(provider);
            }
          }
        }
        logger.info('ConfigImport', 'AI服务商配置已导入 (${config.ai!.providers!.length}个)');
      }

      // 导入能力绑定
      if (config.ai!.capabilityBinding != null) {
        final binding = config.ai!.capabilityBinding!;
        logger.info('ConfigImport', '准备导入AI能力绑定: text=${binding.textProviderId}, vision=${binding.visionProviderId}, speech=${binding.speechProviderId}');
        await AIProviderManager.saveCapabilityBinding(binding);
        logger.info('ConfigImport', 'AI能力绑定已导入');
      } else {
        logger.warning('ConfigImport', 'AI配置中没有能力绑定');
      }

      logger.info('ConfigImport', 'AI配置已导入');
    }

    // 导入应用设置（除了默认账户，稍后处理）
    String? pendingDefaultIncomeAccountName;
    String? pendingDefaultExpenseAccountName;

    if (options.appSettings && config.appSettings != null) {
      final settings = config.appSettings!;

      // 账户管理
      if (settings.accountFeatureEnabled != null) {
        await prefs.setBool('account_feature_enabled', settings.accountFeatureEnabled!);
      }
      // 默认账户通过名称查找ID（需要先导入账户再处理此配置）
      pendingDefaultIncomeAccountName = settings.defaultIncomeAccountName;
      pendingDefaultExpenseAccountName = settings.defaultExpenseAccountName;

      // 记账提醒
      if (settings.reminderEnabled != null) {
        await prefs.setBool('reminder_enabled', settings.reminderEnabled!);
      }
      if (settings.reminderHour != null) {
        await prefs.setInt('reminder_hour', settings.reminderHour!);
      }
      if (settings.reminderMinute != null) {
        await prefs.setInt('reminder_minute', settings.reminderMinute!);
      }

      // 语言设置
      if (settings.languageCode != null) {
        await prefs.setString('selected_language', settings.languageCode!);
      }
      if (settings.countryCode != null) {
        await prefs.setString('selected_language_country', settings.countryCode!);
      }

      // 个性化设置
      if (settings.primaryColor != null) {
        await prefs.setInt('primaryColor', settings.primaryColor!);
      }
      if (settings.fontScaleLevel != null) {
        await prefs.setInt('fontScaleLevel', settings.fontScaleLevel!);
      }
      if (settings.customFontScale != null) {
        await prefs.setDouble('customFontScale', settings.customFontScale!);
      }

      // 外观设置
      if (settings.themeMode != null) {
        await prefs.setString('themeMode', settings.themeMode!);
      }
      if (settings.darkModePatternStyle != null) {
        await prefs.setString('darkModePatternStyle', settings.darkModePatternStyle!);
      }
      if (settings.compactAmount != null) {
        await prefs.setBool('compactAmount', settings.compactAmount!);
      }
      if (settings.showTransactionTime != null) {
        await prefs.setBool('showTransactionTime', settings.showTransactionTime!);
      }
      if (settings.incomeExpenseColorScheme != null) {
        await prefs.setBool('incomeExpenseColorScheme', settings.incomeExpenseColorScheme!);
      }

      // 云服务
      if (settings.cloudServiceType != null) {
        await prefs.setString('cloud_active_type', settings.cloudServiceType!);
      }
      if (settings.autoSync != null) {
        await prefs.setBool('auto_sync', settings.autoSync!);
      }

      // 自动记账
      if (settings.autoScreenshotEnabled != null) {
        await prefs.setBool('auto_screenshot_billing_enabled', settings.autoScreenshotEnabled!);
      }
      if (settings.shortcutPreferCamera != null) {
        await prefs.setBool('shortcut_prefer_camera', settings.shortcutPreferCamera!);
      }

      logger.info('ConfigImport', '应用设置已导入（默认账户待处理）');
    }

    // === 按依赖顺序导入数据 ===
    // 1. 导入账本（周期账单、预算依赖账本）
    if (options.ledgers && config.ledgers != null && repository != null) {
      try {
        final items = config.ledgers!.items;

        // 获取现有账本名称集合
        final existingLedgers = await repository.getAllLedgers();
        final existingNames = existingLedgers.map((l) => l.name.toLowerCase()).toSet();

        // 过滤掉已存在的账本（按名称去重）
        final newItems = items.where((item) =>
          !existingNames.contains(item.name.toLowerCase())
        ).toList();

        if (newItems.isNotEmpty) {
          for (final item in newItems) {
            await repository.createLedger(
              name: item.name,
              currency: item.currency,
            );
          }
          logger.info('ConfigImport', '账本已导入: ${newItems.length}条 (跳过已存在: ${items.length - newItems.length}条)');
        } else {
          logger.info('ConfigImport', '账本全部已存在，跳过导入');
        }
      } catch (e) {
        logger.error('ConfigImport', '导入账本失败: $e');
      }
    }

    // 2. 导入分类（周期账单、预算依赖分类）
    if (options.categories && config.categories != null && repository != null) {
      try {
        final items = config.categories!.items;

        // 获取现有分类名称集合（用于去重）
        final existingCategories = await repository.getAllCategories();
        // 按 (name, kind) 去重,允许跨 kind 同名(收入/支出可同名)
        final existingKeys =
            existingCategories.map((c) => '${c.name.toLowerCase()}|${c.kind}').toSet();

        // 特殊处理：更新虚拟转账分类（如果存在）
        final transferItem = items.firstWhere(
          (item) => item.kind == 'transfer',
          orElse: () => CategoryItem(name: '', kind: '', sortOrder: 0, level: 1),
        );
        if (transferItem.name.isNotEmpty) {
          try {
            final existingTransfer = existingCategories.firstWhere(
              (c) => c.kind == 'transfer',
              orElse: () => throw Exception('转账分类不存在'),
            );
            // 更新现有转账分类的图标设置
            await repository.updateCategoryIcon(
              existingTransfer.id,
              iconType: transferItem.iconType ?? 'material',
              icon: transferItem.icon,
              customIconPath: transferItem.customIconPath,
              communityIconId: transferItem.communityIconId,
            );
            logger.info('ConfigImport', '转账分类图标已更新');
          } catch (e) {
            // 转账分类不存在，将在后续插入逻辑中创建
            logger.debug('ConfigImport', '转账分类不存在，将创建: $e');
          }
        }

        // 第一步：过滤并批量插入一级分类
        final level1Items = items.where((item) => item.parentName == null).toList();
        final newLevel1Items = level1Items.where((item) =>
          !existingKeys.contains('${item.name.toLowerCase()}|${item.kind}')
        ).toList();

        if (newLevel1Items.isNotEmpty) {
          final level1Companions = newLevel1Items.map((item) => CategoriesCompanion.insert(
            name: item.name,
            kind: item.kind,
            icon: d.Value(item.icon),
            sortOrder: d.Value(item.sortOrder),
            parentId: const d.Value(null),
            level: d.Value(item.level),
            iconType: d.Value(item.iconType ?? 'material'),
            customIconPath: d.Value(item.customIconPath),
            communityIconId: d.Value(item.communityIconId),
          )).toList();

          await repository.batchInsertCategories(level1Companions);
        }

        // 第二步：查询所有分类，构建名称到ID的映射
        final allCategories = await repository.getAllCategories();
        final keyToId = <String, int>{
          for (var cat in allCategories) '${cat.name.toLowerCase()}|${cat.kind}': cat.id
        };

        // 更新现有分类集合（包含刚插入的一级分类），按 (name, kind)
        final updatedKeys = allCategories.map((c) => '${c.name.toLowerCase()}|${c.kind}').toSet();

        // 第三步：过滤并批量插入二级分类
        final level2Items = items.where((item) => item.parentName != null).toList();
        final newLevel2Items = level2Items.where((item) =>
          !updatedKeys.contains('${item.name.toLowerCase()}|${item.kind}')
        ).toList();
        final level2Companions = <CategoriesCompanion>[];

        for (final item in newLevel2Items) {
          // 父分类与子分类同 kind,按 (parentName, kind) 查父 id
          final parentId = keyToId['${item.parentName?.toLowerCase()}|${item.kind}'];
          if (parentId != null) {
            level2Companions.add(CategoriesCompanion.insert(
              name: item.name,
              kind: item.kind,
              icon: d.Value(item.icon),
              sortOrder: d.Value(item.sortOrder),
              parentId: d.Value(parentId),
              level: d.Value(item.level),
              iconType: d.Value(item.iconType ?? 'material'),
              customIconPath: d.Value(item.customIconPath),
              communityIconId: d.Value(item.communityIconId),
            ));
          } else {
            logger.warning('ConfigImport', '找不到父分类 "${item.parentName}"，跳过二级分类: ${item.name}');
          }
        }

        if (level2Companions.isNotEmpty) {
          await repository.batchInsertCategories(level2Companions);
        }

        final skippedCount = (level1Items.length - newLevel1Items.length) +
                             (level2Items.length - newLevel2Items.length);
        logger.info('ConfigImport',
          '分类已批量导入: 一级${newLevel1Items.length}条, 二级${level2Companions.length}条'
          '${skippedCount > 0 ? ' (跳过已存在: $skippedCount条)' : ''}');
      } catch (e) {
        logger.error('ConfigImport', '导入分类失败: $e');
      }
    }

    // 3. 导入账户（周期账单、默认账户依赖账户）
    if (options.accounts && config.accounts != null && repository != null) {
      try {
        final items = config.accounts!.items;

        // 获取现有账户名称集合
        final existingAccounts = await repository.getAllAccounts();
        final existingNames = existingAccounts.map((a) => a.name.toLowerCase()).toSet();

        // 过滤掉已存在的账户（按名称去重）
        final newItems = items.where((item) =>
          !existingNames.contains(item.name.toLowerCase())
        ).toList();

        if (newItems.isNotEmpty) {
          // 准备批量插入的数据
          final accountsToInsert = newItems.map((item) => AccountsCompanion.insert(
            ledgerId: 0, // 保留字段，但不再使用（v2迁移后会移除）
            name: item.name,
            type: d.Value(item.type),
            currency: d.Value(item.currency),
            initialBalance: d.Value(item.initialBalance),
            createdAt: d.Value(
                item.createdAt != null ? DateTime.parse(item.createdAt!) : null),
            updatedAt: d.Value(DateTime.now()),
            creditLimit: d.Value(item.creditLimit),
            billingDay: d.Value(item.billingDay),
            paymentDueDay: d.Value(item.paymentDueDay),
            bankName: d.Value(item.bankName),
            cardLastFour: d.Value(item.cardLastFour),
            note: d.Value(item.note),
          )).toList();

          // 使用 repository 方法进行批量插入
          await repository.batchInsertAccounts(accountsToInsert);

          logger.info('ConfigImport', '账户已导入: ${newItems.length}条 (跳过已存在: ${items.length - newItems.length}条)');
        } else {
          logger.info('ConfigImport', '账户全部已存在，跳过导入');
        }
      } catch (e) {
        logger.error('ConfigImport', '导入账户失败: $e');
      }
    }

    // 4. 导入标签
    if (options.tags && config.tags != null && repository != null) {
      try {
        final items = config.tags!.items;

        // 获取现有标签名称集合
        final existingTags = await repository.getAllTags();
        final existingNames = existingTags.map((t) => t.name.toLowerCase()).toSet();

        // 过滤掉已存在的标签（按名称去重）
        final newItems = items.where((item) =>
          !existingNames.contains(item.name.toLowerCase())
        ).toList();

        if (newItems.isNotEmpty) {
          // 准备批量插入的数据
          final tagsToInsert = newItems.map((item) => TagsCompanion.insert(
            name: item.name,
            color: d.Value(item.color),
          )).toList();

          // 使用 repository 方法进行批量插入
          await repository.batchInsertTags(tagsToInsert);

          logger.info('ConfigImport', '标签已导入: ${newItems.length}条 (跳过已存在: ${items.length - newItems.length}条)');
        } else {
          logger.info('ConfigImport', '标签全部已存在，跳过导入');
        }
      } catch (e) {
        logger.error('ConfigImport', '导入标签失败: $e');
      }
    }

    // 5. 导入周期账单（依赖账本、分类、账户）
    if (options.recurringTransactions && config.recurringTransactions != null && repository != null) {
      try {
        final items = config.recurringTransactions!.items;

        // 构建名称到ID的映射
        final ledgers = await repository.getAllLedgers();
        final ledgerNameToId = {for (var l in ledgers) l.name: l.id};

        final categories = await repository.getAllCategories();
        // 按 (name, kind) 映射,跨 kind 同名各自命中
        final catKeyToId = {for (var c in categories) '${c.name.toLowerCase()}|${c.kind}': c.id};

        final accounts = await repository.getAllAccounts();
        final accountNameToId = {for (var a in accounts) a.name: a.id};

        int importedCount = 0;
        int skippedCount = 0;

        for (final item in items) {
          // 通过名称查找账本ID
          final targetLedgerId = ledgerNameToId[item.ledgerName];
          if (targetLedgerId == null) {
            logger.warning('ConfigImport', '找不到账本: ${item.ledgerName}，跳过周期账单');
            skippedCount++;
            continue;
          }

          // 通过名称查找分类ID
          int? categoryId;
          if (item.categoryName != null) {
            // 周期账单 type(expense/income/transfer)即分类 kind
            categoryId = catKeyToId['${item.categoryName!.toLowerCase()}|${item.type}'];
            if (categoryId == null) {
              logger.warning('ConfigImport', '找不到分类: ${item.categoryName}，跳过周期账单');
              skippedCount++;
              continue;
            }
          }

          // 通过名称查找账户ID
          int? accountId;
          if (item.accountName != null) {
            accountId = accountNameToId[item.accountName];
            if (accountId == null) {
              logger.warning('ConfigImport', '找不到账户: ${item.accountName}，跳过周期账单');
              skippedCount++;
              continue;
            }
          }

          // 通过名称查找转账目标账户ID
          int? toAccountId;
          if (item.toAccountName != null) {
            toAccountId = accountNameToId[item.toAccountName];
            if (toAccountId == null) {
              logger.warning('ConfigImport', '找不到转账目标账户: ${item.toAccountName}，跳过周期账单');
              skippedCount++;
              continue;
            }
          }

          await repository.addRecurringTransaction(
            ledgerId: targetLedgerId,
            type: item.type,
            amount: item.amount,
            categoryId: categoryId,
            accountId: accountId,
            toAccountId: toAccountId,
            note: item.note,
            frequency: item.frequency,
            interval: item.interval,
            dayOfMonth: item.dayOfMonth,
            dayOfWeek: item.dayOfWeek,
            monthOfYear: item.monthOfYear,
            startDate: DateTime.parse(item.startDate),
            endDate: item.endDate != null ? DateTime.parse(item.endDate!) : null,
            enabled: item.enabled,
          );
          importedCount++;
        }

        logger.info('ConfigImport', '周期账单已导入: $importedCount条${skippedCount > 0 ? '，跳过: $skippedCount条' : ''}');
      } catch (e) {
        logger.error('ConfigImport', '导入周期账单失败: $e');
      }
    }

    // 6. 导入预算（依赖账本、分类）
    if (options.budgets && config.budgets != null && repository != null) {
      try {
        final items = config.budgets!.items;
        int importedCount = 0;
        int skippedCount = 0;

        // 构建名称到 ID 的映射
        final ledgers = await repository.getAllLedgers();
        final ledgerNameToId = {for (var l in ledgers) l.name: l.id};

        final categories = await repository.getAllCategories();
        // 分类预算只针对支出一级分类,按 (name, kind) 映射
        final catKeyToId = {for (var c in categories) '${c.name.toLowerCase()}|${c.kind}': c.id};

        for (final item in items) {
          // 通过名称查找账本 ID
          int? targetLedgerId = ledgerId; // 优先使用指定的账本
          if (targetLedgerId == null) {
            targetLedgerId = ledgerNameToId[item.ledgerName];
            if (targetLedgerId == null) {
              logger.warning('ConfigImport', '找不到账本: ${item.ledgerName}，跳过此预算');
              skippedCount++;
              continue;
            }
          }

          // 通过名称查找分类 ID（仅分类预算需要）
          int? categoryId;
          if (item.type == 'category' && item.categoryName != null) {
            // 分类预算针对支出分类
            categoryId = catKeyToId['${item.categoryName!.toLowerCase()}|expense'];
            if (categoryId == null) {
              logger.warning('ConfigImport', '找不到分类: ${item.categoryName}，跳过此预算');
              skippedCount++;
              continue;
            }
          }

          await repository.createBudget(
            ledgerId: targetLedgerId,
            type: item.type,
            categoryId: categoryId,
            amount: item.amount,
            startDay: item.startDay,
          );
          importedCount++;
        }

        logger.info('ConfigImport', '预算已导入: $importedCount条${skippedCount > 0 ? '，跳过: $skippedCount条' : ''}');
      } catch (e) {
        logger.error('ConfigImport', '导入预算失败: $e');
      }
    }

    // 7. 处理默认账户设置（所有数据导入完成后）
    if (repository != null && (pendingDefaultIncomeAccountName != null || pendingDefaultExpenseAccountName != null)) {
      try {
        final accounts = await repository.getAllAccounts();
        final accountNameToId = {for (var a in accounts) a.name: a.id};

        if (pendingDefaultIncomeAccountName != null) {
          final accountId = accountNameToId[pendingDefaultIncomeAccountName];
          if (accountId != null) {
            await prefs.setInt('default_income_account_id', accountId);
            logger.info('ConfigImport', '默认收入账户已设置: $pendingDefaultIncomeAccountName');
          } else {
            logger.warning('ConfigImport', '找不到默认收入账户: $pendingDefaultIncomeAccountName');
          }
        }

        if (pendingDefaultExpenseAccountName != null) {
          final accountId = accountNameToId[pendingDefaultExpenseAccountName];
          if (accountId != null) {
            await prefs.setInt('default_expense_account_id', accountId);
            logger.info('ConfigImport', '默认支出账户已设置: $pendingDefaultExpenseAccountName');
          } else {
            logger.warning('ConfigImport', '找不到默认支出账户: $pendingDefaultExpenseAccountName');
          }
        }
      } catch (e) {
        logger.error('ConfigImport', '处理默认账户设置失败: $e');
      }
    }
  }

  /// 导出配置到文件
  static Future<void> exportToFile(
    String filePath, {
    BaseRepository? repository,
    int? ledgerId,
    ExportOptions options = ExportOptions.all,
  }) async {
    final yamlContent = await exportToYaml(
      repository: repository,
      ledgerId: ledgerId,
      options: options,
    );
    final file = File(filePath);
    await file.writeAsString(yamlContent);
    logger.info('ConfigExport', '配置已导出到: $filePath');
  }

  /// 从文件导入配置
  static Future<void> importFromFile(
    String filePath, {
    BaseRepository? repository,
    int? ledgerId,
    ExportOptions options = ExportOptions.all,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $filePath');
    }

    final yamlContent = await file.readAsString();
    await importFromYaml(yamlContent, repository: repository, ledgerId: ledgerId, options: options);
    logger.info('ConfigImport', '配置已从文件导入: $filePath');
  }
}
