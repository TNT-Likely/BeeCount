import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../system/logger_service.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// 种子数据服务
/// 负责生成应用初始化时的默认数据（账本、账户、分类等）
class SeedService {
  SeedService._();

  /// 固定命名空间,给默认 seed 数据生成**确定性** syncId(uuid v5)。
  /// ⚠️ 不要改这个常量 —— 改了会让同一份默认数据在新老版本算出不同 syncId,
  /// 反而制造重复。
  static const _seedSyncNamespace = 'b3e7c0de-0000-4000-8000-beec00000001';
  static const _seedUuid = Uuid();

  /// 默认分类的确定性 syncId。key 用**稳定的 seed key**(不是翻译后的名字),
  /// 这样任何设备、任何语言 seed 出来的同一个默认分类都得到同一个 syncId,
  /// 云端按 syncId 天然只留一份 —— 从源头杜绝多设备各自 seed 造成的重复。
  /// 收敛存量重复时的 keeper 规则见 data/repositories/entity_dedup.dart。
  static String deterministicCategorySyncId({
    required String kind,
    required int level,
    required String key,
  }) =>
      _seedUuid.v5(_seedSyncNamespace, 'cat:$kind:$level:$key');

  /// 默认账户的确定性 syncId。seed 每个 type(cash/bank_card/credit_card)
  /// 恰好一个,用 type 作 key。
  static String deterministicAccountSyncId(String type) =>
      _seedUuid.v5(_seedSyncNamespace, 'acc:$type');

  // ========== 一级分类模式的默认分类 key ==========

  /// 默认支出分类 key 列表（一级分类模式）
  static const List<String> flatExpenseCategoryKeys = [
    'dining', 'transport', 'shopping', 'entertainment', 'home', 'family',
    'communication', 'utilities', 'housing', 'medical', 'education',
    'pets', 'sports', 'digital', 'travel', 'alcohol_tobacco', 'baby_care',
    'beauty', 'repair', 'social', 'learning', 'car', 'taxi', 'subway',
    'delivery', 'property', 'parking', 'donation', 'gift', 'tax',
    'beverage', 'clothing', 'snacks', 'red_packet', 'fruit', 'game',
    'book', 'lover', 'decoration', 'daily_goods', 'lottery', 'stock',
    'social_security', 'express', 'work'
  ];

  /// 默认收入分类 key 列表（一级分类模式）
  static const List<String> flatIncomeCategoryKeys = [
    'salary', 'investment', 'red_packet', 'bonus', 'reimbursement',
    'part_time', 'gift', 'interest', 'refund', 'invest_income',
    'second_hand', 'social_benefit', 'tax_refund', 'provident_fund'
  ];

  // ========== 二级分类模式的默认分类（父分类 -> 子分类列表）==========

  /// 二级分类模式的默认支出分类
  static const Map<String, List<String>> hierarchicalExpenseCategories = {
    'dining': ['dining_breakfast', 'dining_lunch', 'dining_dinner', 'dining_meituan', 'dining_eleme', 'dining_jd', 'dining_restaurant', 'dining_food'],
    'snacks': ['snacks_biscuit', 'snacks_chips', 'snacks_candy', 'snacks_chocolate', 'snacks_nuts'],
    'fruit': ['fruit_apple', 'fruit_banana', 'fruit_orange', 'fruit_grape', 'fruit_watermelon', 'fruit_other'],
    'beverage': ['beverage_milk_tea', 'beverage_coffee', 'beverage_juice', 'beverage_soda', 'beverage_water'],
    'pastry': ['pastry_cake', 'pastry_bread', 'pastry_dessert', 'pastry_biscuit'],
    'cooking': ['cooking_vegetable', 'cooking_meat', 'cooking_seafood', 'cooking_seasoning', 'cooking_grain'],
    'shopping': ['shopping_clothing', 'shopping_shoes', 'shopping_bag', 'shopping_accessory', 'shopping_daily'],
    'pets': ['pets_food', 'pets_supplies', 'pets_medical', 'pets_grooming'],
    'transport': ['transport_subway', 'transport_bus', 'transport_taxi', 'transport_ride', 'transport_parking', 'transport_fuel'],
    'car': ['car_maintenance', 'car_repair', 'car_insurance', 'car_wash', 'car_fine'],
    'clothing': ['clothing_top', 'clothing_pants', 'clothing_skirt', 'clothing_shoes', 'clothing_accessory'],
    'daily_goods': ['daily_toiletries', 'daily_paper', 'daily_cleaning', 'daily_kitchen'],
    'education': ['education_tuition', 'education_training', 'education_books', 'education_stationery', 'education_office'],
    'invest_loss': ['invest_loss_stock', 'invest_loss_fund', 'invest_loss_other'],
    'entertainment': ['entertainment_movie', 'entertainment_ktv', 'entertainment_amusement', 'entertainment_bar', 'entertainment_other'],
    'game': ['game_recharge', 'game_equipment', 'game_membership'],
    'health_products': ['health_vitamin', 'health_food', 'health_nutrition'],
    'subscription': ['subscription_video', 'subscription_music', 'subscription_cloud', 'subscription_other'],
    'sports': ['sports_gym', 'sports_equipment', 'sports_course', 'sports_outdoor'],
    'housing': ['housing_rent', 'housing_property', 'housing_mortgage', 'housing_decoration'],
    'home': ['home_furniture', 'home_appliance', 'home_decor', 'home_bedding'],
    'beauty': ['beauty_skincare', 'beauty_cosmetics', 'beauty_salon', 'beauty_nail'],
  };

  /// 二级分类模式的默认收入分类
  static const Map<String, List<String>> hierarchicalIncomeCategories = {
    'salary': ['salary_basic', 'salary_performance', 'salary_year_end', 'salary_overtime'],
    'investment': ['investment_fund', 'investment_dividend', 'investment_product', 'investment_other'],
    'red_packet': ['red_packet_festival', 'red_packet_birthday', 'red_packet_return'],
    'bonus': ['bonus_year_end', 'bonus_quarterly', 'bonus_project', 'bonus_other'],
    'reimbursement': ['reimbursement_travel', 'reimbursement_meal', 'reimbursement_other'],
    'part_time': ['part_time_income', 'part_time_extra'],
    'gift': ['gift_wedding', 'gift_birthday', 'gift_other'],
    'interest': ['interest_bank', 'interest_other'],
    'refund': ['refund_shopping', 'refund_service', 'refund_other'],
    'invest_income': ['invest_income_stock', 'invest_income_fund', 'invest_income_other'],
    'second_hand': ['second_hand_idle', 'second_hand_goods'],
    'social_benefit': ['social_benefit_unemployment', 'social_benefit_maternity', 'social_benefit_other'],
    'tax_refund': ['tax_refund_personal', 'tax_refund_other'],
    'provident_fund': ['provident_fund_withdrawal', 'provident_fund_interest'],
  };

  // ========== 分类图标映射 ==========

  /// 获取分类的默认图标
  /// 注意：这里只提供默认图标，不做名称匹配
  static String getDefaultIcon(String categoryKey) {
    // 支出分类图标
    const expenseIcons = {
      // 一级分类
      'dining': 'restaurant',
      'transport': 'directions_car',
      'shopping': 'shopping_cart',
      'entertainment': 'movie',
      'home': 'home',
      'family': 'family_restroom',
      'communication': 'phone',
      'utilities': 'flash_on',
      'housing': 'home_work',
      'medical': 'local_hospital',
      'education': 'school',
      'pets': 'pets',
      'sports': 'fitness_center',
      'digital': 'smartphone',
      'travel': 'flight',
      'alcohol_tobacco': 'local_bar',
      'baby_care': 'child_care',
      'beauty': 'face',
      'repair': 'handyman',
      'social': 'group',
      'learning': 'school',
      'car': 'directions_car',
      'taxi': 'local_taxi',
      'subway': 'directions_subway',
      'delivery': 'delivery_dining',
      'property': 'apartment',
      'parking': 'local_parking',
      'donation': 'volunteer_activism',
      'gift': 'card_giftcard',
      'tax': 'receipt_long',
      'beverage': 'local_cafe',
      'clothing': 'checkroom',
      'snacks': 'fastfood',
      'red_packet': 'wallet',
      'fruit': 'eco',
      'pastry': 'cake',
      'cooking': 'kitchen',
      'game': 'sports_esports',
      'book': 'menu_book',
      'invest_loss': 'trending_down',
      'health_products': 'medication',
      'subscription': 'subscriptions',
      'lover': 'favorite',
      'decoration': 'home_repair_service',
      'daily_goods': 'local_laundry_service',
      'lottery': 'confirmation_number',
      'stock': 'trending_up',
      'social_security': 'security',
      'express': 'local_shipping',
      'work': 'work_outline',

      // 餐饮二级分类
      'dining_breakfast': 'free_breakfast',
      'dining_lunch': 'lunch_dining',
      'dining_dinner': 'dinner_dining',
      'dining_meituan': 'delivery_dining',
      'dining_eleme': 'delivery_dining',
      'dining_jd': 'delivery_dining',
      'dining_restaurant': 'restaurant',
      'dining_food': 'fastfood',

      // 零食二级分类
      'snacks_biscuit': 'cookie',
      'snacks_chips': 'ramen_dining',
      'snacks_candy': 'candy',
      'snacks_chocolate': 'chocolate',
      'snacks_nuts': 'grain',

      // 水果二级分类
      'fruit_apple': 'apple',
      'fruit_banana': 'sports_cricket',
      'fruit_orange': 'circle',
      'fruit_grape': 'bubble_chart',
      'fruit_watermelon': 'pie_chart',
      'fruit_other': 'eco',

      // 饮品二级分类
      'beverage_milk_tea': 'local_cafe',
      'beverage_coffee': 'coffee',
      'beverage_juice': 'juice',
      'beverage_soda': 'liquor',
      'beverage_water': 'water_drop',

      // 糕点二级分类
      'pastry_cake': 'cake',
      'pastry_bread': 'bakery_dining',
      'pastry_dessert': 'icecream',
      'pastry_biscuit': 'cookie',

      // 做饭食材二级分类
      'cooking_vegetable': 'yard',
      'cooking_meat': 'lunch_dining',
      'cooking_seafood': 'set_meal',
      'cooking_seasoning': 'blender',
      'cooking_grain': 'grain',

      // 购物二级分类
      'shopping_clothing': 'checkroom',
      'shopping_shoes': 'accessibility',
      'shopping_bag': 'shopping_bag',
      'shopping_accessory': 'watch',
      'shopping_daily': 'shopping_cart',

      // 宠物二级分类
      'pets_food': 'pet_supplies',
      'pets_supplies': 'inventory_2',
      'pets_medical': 'medical_services',
      'pets_grooming': 'shower',

      // 交通二级分类
      'transport_subway': 'directions_subway',
      'transport_bus': 'directions_bus',
      'transport_taxi': 'local_taxi',
      'transport_ride': 'directions_bike',
      'transport_parking': 'local_parking',
      'transport_fuel': 'local_gas_station',

      // 汽车二级分类
      'car_maintenance': 'build',
      'car_repair': 'handyman',
      'car_insurance': 'security',
      'car_wash': 'local_car_wash',
      'car_fine': 'report_problem',

      // 服饰二级分类
      'clothing_top': 'checkroom',
      'clothing_pants': 'diamond',
      'clothing_skirt': 'auto_awesome',
      'clothing_shoes': 'hiking',
      'clothing_accessory': 'watch',

      // 日用品二级分类
      'daily_toiletries': 'shower',
      'daily_paper': 'receipt',
      'daily_cleaning': 'cleaning_services',
      'daily_kitchen': 'kitchen',

      // 教育二级分类
      'education_tuition': 'school',
      'education_training': 'model_training',
      'education_books': 'menu_book',
      'education_stationery': 'edit',
      'education_office': 'business_center',

      // 投资亏损二级分类
      'invest_loss_stock': 'trending_down',
      'invest_loss_fund': 'show_chart',
      'invest_loss_other': 'money_off',

      // 娱乐二级分类
      'entertainment_movie': 'movie',
      'entertainment_ktv': 'mic',
      'entertainment_amusement': 'attractions',
      'entertainment_bar': 'local_bar',
      'entertainment_other': 'celebration',

      // 游戏二级分类
      'game_recharge': 'payments',
      'game_equipment': 'sports_esports',
      'game_membership': 'workspace_premium',

      // 保健品二级分类
      'health_vitamin': 'medication',
      'health_food': 'biotech',
      'health_nutrition': 'health_and_safety',

      // 订阅服务二级分类
      'subscription_video': 'play_circle',
      'subscription_music': 'music_note',
      'subscription_cloud': 'cloud',
      'subscription_other': 'subscriptions',

      // 运动二级分类
      'sports_gym': 'fitness_center',
      'sports_equipment': 'sports',
      'sports_course': 'sports_martial_arts',
      'sports_outdoor': 'hiking',

      // 住房二级分类
      'housing_rent': 'home',
      'housing_property': 'home_work',
      'housing_mortgage': 'account_balance',
      'housing_decoration': 'construction',

      // 居家二级分类
      'home_furniture': 'weekend',
      'home_appliance': 'devices',
      'home_decor': 'palette',
      'home_bedding': 'bed',

      // 美容二级分类
      'beauty_skincare': 'face',
      'beauty_cosmetics': 'face_retouching_natural',
      'beauty_salon': 'content_cut',
      'beauty_nail': 'back_hand',
    };

    // 收入分类图标
    const incomeIcons = {
      // 一级分类
      'salary': 'work',
      'investment': 'account_balance',
      'bonus': 'emoji_events',
      'reimbursement': 'receipt',
      'part_time': 'schedule',
      'gift': 'card_giftcard',
      'interest': 'monetization_on',
      'refund': 'undo',
      'invest_income': 'trending_up',
      'second_hand': 'sell',
      'social_benefit': 'health_and_safety',
      'tax_refund': 'receipt_long',
      'provident_fund': 'account_balance_wallet',

      // 工资二级分类
      'salary_basic': 'payments',
      'salary_performance': 'star',
      'salary_year_end': 'card_giftcard',
      'salary_overtime': 'access_time',

      // 理财二级分类
      'investment_fund': 'account_balance',
      'investment_dividend': 'trending_up',
      'investment_product': 'savings',
      'investment_other': 'monetization_on',

      // 红包二级分类
      'red_packet_festival': 'celebration',
      'red_packet_birthday': 'cake',
      'red_packet_return': 'card_giftcard',

      // 奖金二级分类
      'bonus_year_end': 'emoji_events',
      'bonus_quarterly': 'star',
      'bonus_project': 'workspace_premium',
      'bonus_other': 'military_tech',

      // 报销二级分类
      'reimbursement_travel': 'flight',
      'reimbursement_meal': 'restaurant',
      'reimbursement_other': 'receipt',

      // 兼职二级分类
      'part_time_income': 'schedule',
      'part_time_extra': 'attach_money',

      // 礼物二级分类
      'gift_wedding': 'favorite',
      'gift_birthday': 'cake',
      'gift_other': 'card_giftcard',

      // 利息二级分类
      'interest_bank': 'account_balance',
      'interest_other': 'monetization_on',

      // 退款二级分类
      'refund_shopping': 'shopping_cart',
      'refund_service': 'build',
      'refund_other': 'undo',

      // 投资收益二级分类
      'invest_income_stock': 'trending_up',
      'invest_income_fund': 'account_balance',
      'invest_income_other': 'attach_money',

      // 二手交易二级分类
      'second_hand_idle': 'sell',
      'second_hand_goods': 'storefront',

      // 社会福利二级分类
      'social_benefit_unemployment': 'health_and_safety',
      'social_benefit_maternity': 'child_care',
      'social_benefit_other': 'favorite',

      // 退税二级分类
      'tax_refund_personal': 'receipt_long',
      'tax_refund_other': 'description',

      // 公积金二级分类
      'provident_fund_withdrawal': 'account_balance_wallet',
      'provident_fund_interest': 'savings',
    };

    return expenseIcons[categoryKey] ?? incomeIcons[categoryKey] ?? 'category';
  }

  // ========== 种子数据生成方法 ==========

  /// 生成默认账本
  static Future<int> createDefaultLedger(
    BeeDatabase db,
    AppLocalizations l10n,
    String currency,
  ) async {
    final ledgerId = await db.into(db.ledgers).insert(
      LedgersCompanion.insert(
        name: l10n.ledgerDefaultName,
        currency: Value(currency),
      ),
    );
    return ledgerId;
  }

  /// 生成默认账户（3个：现金、银行卡、信用卡）
  static Future<void> createDefaultAccounts(
    BeeDatabase db,
    int ledgerId,
    AppLocalizations l10n,
    String currency,
  ) async {
    // 1. 现金账户
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        ledgerId: ledgerId,
        name: l10n.accountTypeCash,
        type: const Value('cash'),
        currency: Value(currency),
        initialBalance: const Value(0.0),
        syncId: Value(deterministicAccountSyncId('cash')),
      ),
    );

    // 2. 银行卡账户
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        ledgerId: ledgerId,
        name: l10n.accountTypeBankCard,
        type: const Value('bank_card'),
        currency: Value(currency),
        initialBalance: const Value(0.0),
        syncId: Value(deterministicAccountSyncId('bank_card')),
      ),
    );

    // 3. 信用卡账户
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        ledgerId: ledgerId,
        name: l10n.accountTypeCreditCard,
        type: const Value('credit_card'),
        currency: Value(currency),
        initialBalance: const Value(0.0),
        syncId: Value(deterministicAccountSyncId('credit_card')),
      ),
    );
  }

  /// 获取翻译后的分类名称（用于一级分类模式）
  static String _getTranslatedCategoryName(
    String key,
    String kind,
    AppLocalizations l10n,
  ) {
    final translationString = kind == 'expense' ? l10n.categoryExpenseList : l10n.categoryIncomeList;
    final names = translationString.split('-');
    final keys = kind == 'expense' ? flatExpenseCategoryKeys : flatIncomeCategoryKeys;

    final index = keys.indexOf(key);
    if (index >= 0 && index < names.length) {
      return names[index].trim();
    }

    return key; // fallback
  }

  /// 获取翻译后的父分类名称（用于二级分类模式）
  static String _getTranslatedParentCategoryName(
    String key,
    String kind,
    AppLocalizations l10n,
  ) {
    if (kind == 'expense') {
      switch (key) {
        case 'dining': return l10n.categoryExpenseDining.split('-')[0].trim();
        case 'snacks': return l10n.categoryExpenseSnacks.split('-')[0].trim();
        case 'fruit': return l10n.categoryExpenseFruit.split('-')[0].trim();
        case 'beverage': return l10n.categoryExpenseBeverage.split('-')[0].trim();
        case 'pastry': return l10n.categoryExpensePastry.split('-')[0].trim();
        case 'cooking': return l10n.categoryExpenseCooking.split('-')[0].trim();
        case 'shopping': return l10n.categoryExpenseShopping.split('-')[0].trim();
        case 'pets': return l10n.categoryExpensePets.split('-')[0].trim();
        case 'transport': return l10n.categoryExpenseTransport.split('-')[0].trim();
        case 'car': return l10n.categoryExpenseCar.split('-')[0].trim();
        case 'clothing': return l10n.categoryExpenseClothing.split('-')[0].trim();
        case 'daily_goods': return l10n.categoryExpenseDailyGoods.split('-')[0].trim();
        case 'education': return l10n.categoryExpenseEducation.split('-')[0].trim();
        case 'invest_loss': return l10n.categoryExpenseInvestLoss.split('-')[0].trim();
        case 'entertainment': return l10n.categoryExpenseEntertainment.split('-')[0].trim();
        case 'game': return l10n.categoryExpenseGame.split('-')[0].trim();
        case 'health_products': return l10n.categoryExpenseHealthProducts.split('-')[0].trim();
        case 'subscription': return l10n.categoryExpenseSubscription.split('-')[0].trim();
        case 'sports': return l10n.categoryExpenseSports.split('-')[0].trim();
        case 'housing': return l10n.categoryExpenseHousing.split('-')[0].trim();
        case 'home': return l10n.categoryExpenseHome.split('-')[0].trim();
        case 'beauty': return l10n.categoryExpenseBeauty.split('-')[0].trim();
        default: return key;
      }
    } else {
      switch (key) {
        case 'salary': return l10n.categoryIncomeSalary.split('-')[0].trim();
        case 'investment': return l10n.categoryIncomeInvestment.split('-')[0].trim();
        case 'red_packet': return l10n.categoryIncomeRedPacket.split('-')[0].trim();
        case 'bonus': return l10n.categoryIncomeBonus.split('-')[0].trim();
        case 'reimbursement': return l10n.categoryIncomeReimbursement.split('-')[0].trim();
        case 'part_time': return l10n.categoryIncomePartTime.split('-')[0].trim();
        case 'gift': return l10n.categoryIncomeGift.split('-')[0].trim();
        case 'interest': return l10n.categoryIncomeInterest.split('-')[0].trim();
        case 'refund': return l10n.categoryIncomeRefund.split('-')[0].trim();
        case 'invest_income': return l10n.categoryIncomeInvestIncome.split('-')[0].trim();
        case 'second_hand': return l10n.categoryIncomeSecondHand.split('-')[0].trim();
        case 'social_benefit': return l10n.categoryIncomeSocialBenefit.split('-')[0].trim();
        case 'tax_refund': return l10n.categoryIncomeTaxRefund.split('-')[0].trim();
        case 'provident_fund': return l10n.categoryIncomeProvidentFund.split('-')[0].trim();
        default: return key;
      }
    }
  }

  /// 获取翻译后的子分类名称
  static String _getTranslatedSubCategoryName(
    String key,
    String kind,
    AppLocalizations l10n,
  ) {
    // 从父分类列表中查找包含此子分类的父分类
    final categoryMap = kind == 'expense'
        ? hierarchicalExpenseCategories
        : hierarchicalIncomeCategories;

    String? parentKey;
    for (final entry in categoryMap.entries) {
      if (entry.value.contains(key)) {
        parentKey = entry.key;
        break;
      }
    }

    if (parentKey == null) return key;

    // 获取父分类的翻译字符串
    String translationString;
    if (kind == 'expense') {
      switch (parentKey) {
        case 'dining': translationString = l10n.categoryExpenseDining; break;
        case 'snacks': translationString = l10n.categoryExpenseSnacks; break;
        case 'fruit': translationString = l10n.categoryExpenseFruit; break;
        case 'beverage': translationString = l10n.categoryExpenseBeverage; break;
        case 'pastry': translationString = l10n.categoryExpensePastry; break;
        case 'cooking': translationString = l10n.categoryExpenseCooking; break;
        case 'shopping': translationString = l10n.categoryExpenseShopping; break;
        case 'pets': translationString = l10n.categoryExpensePets; break;
        case 'transport': translationString = l10n.categoryExpenseTransport; break;
        case 'car': translationString = l10n.categoryExpenseCar; break;
        case 'clothing': translationString = l10n.categoryExpenseClothing; break;
        case 'daily_goods': translationString = l10n.categoryExpenseDailyGoods; break;
        case 'education': translationString = l10n.categoryExpenseEducation; break;
        case 'invest_loss': translationString = l10n.categoryExpenseInvestLoss; break;
        case 'entertainment': translationString = l10n.categoryExpenseEntertainment; break;
        case 'game': translationString = l10n.categoryExpenseGame; break;
        case 'health_products': translationString = l10n.categoryExpenseHealthProducts; break;
        case 'subscription': translationString = l10n.categoryExpenseSubscription; break;
        case 'sports': translationString = l10n.categoryExpenseSports; break;
        case 'housing': translationString = l10n.categoryExpenseHousing; break;
        case 'home': translationString = l10n.categoryExpenseHome; break;
        case 'beauty': translationString = l10n.categoryExpenseBeauty; break;
        default: return key;
      }
    } else {
      switch (parentKey) {
        case 'salary': translationString = l10n.categoryIncomeSalary; break;
        case 'investment': translationString = l10n.categoryIncomeInvestment; break;
        case 'red_packet': translationString = l10n.categoryIncomeRedPacket; break;
        case 'bonus': translationString = l10n.categoryIncomeBonus; break;
        case 'reimbursement': translationString = l10n.categoryIncomeReimbursement; break;
        case 'part_time': translationString = l10n.categoryIncomePartTime; break;
        case 'gift': translationString = l10n.categoryIncomeGift; break;
        case 'interest': translationString = l10n.categoryIncomeInterest; break;
        case 'refund': translationString = l10n.categoryIncomeRefund; break;
        case 'invest_income': translationString = l10n.categoryIncomeInvestIncome; break;
        case 'second_hand': translationString = l10n.categoryIncomeSecondHand; break;
        case 'social_benefit': translationString = l10n.categoryIncomeSocialBenefit; break;
        case 'tax_refund': translationString = l10n.categoryIncomeTaxRefund; break;
        case 'provident_fund': translationString = l10n.categoryIncomeProvidentFund; break;
        default: return key;
      }
    }

    final names = translationString.split('-');
    final childKeys = kind == 'expense'
        ? (hierarchicalExpenseCategories[parentKey] ?? [])
        : (hierarchicalIncomeCategories[parentKey] ?? []);

    final index = childKeys.indexOf(key);
    // names[0] is parent name, child names start from names[1]
    if (index >= 0 && index + 1 < names.length) {
      return names[index + 1].trim();
    }

    return key; // fallback
  }

  /// 生成默认分类（一级分类模式）
  static Future<void> createFlatCategories(BeeDatabase db, AppLocalizations l10n) async {
    // 创建支出分类
    for (var i = 0; i < flatExpenseCategoryKeys.length; i++) {
      final key = flatExpenseCategoryKeys[i];
      final translatedName = _getTranslatedCategoryName(key, 'expense', l10n);

      logger.info('seed_service', '创建支出分类: key=$key, name=$translatedName');

      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: translatedName, // 使用翻译后的名称
          kind: 'expense',
          icon: Value(getDefaultIcon(key)),
          sortOrder: Value(i),
          level: const Value(1),
          syncId: Value(
              deterministicCategorySyncId(kind: 'expense', level: 1, key: key)),
        ),
      );
    }

    // 创建收入分类
    for (var i = 0; i < flatIncomeCategoryKeys.length; i++) {
      final key = flatIncomeCategoryKeys[i];
      final translatedName = _getTranslatedCategoryName(key, 'income', l10n);

      logger.info('seed_service', '创建收入分类: key=$key, name=$translatedName');

      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: translatedName, // 使用翻译后的名称
          kind: 'income',
          icon: Value(getDefaultIcon(key)),
          sortOrder: Value(i),
          level: const Value(1),
          syncId: Value(
              deterministicCategorySyncId(kind: 'income', level: 1, key: key)),
        ),
      );
    }
  }

  /// 生成默认分类（二级分类模式）
  static Future<void> createHierarchicalCategories(BeeDatabase db, AppLocalizations l10n) async {
    // 创建支出分类
    var sortOrder = 0;
    for (final entry in hierarchicalExpenseCategories.entries) {
      final parentKey = entry.key;
      final childKeys = entry.value;

      final parentTranslatedName = _getTranslatedParentCategoryName(parentKey, 'expense', l10n);
      logger.info('seed_service', '创建支出父分类: key=$parentKey, name=$parentTranslatedName');

      // 创建父分类
      final parentId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: parentTranslatedName, // 使用翻译后的名称
          kind: 'expense',
          icon: Value(getDefaultIcon(parentKey)),
          sortOrder: Value(sortOrder++),
          level: const Value(1),
          syncId: Value(deterministicCategorySyncId(
              kind: 'expense', level: 1, key: parentKey)),
        ),
      );

      // 创建子分类
      for (var i = 0; i < childKeys.length; i++) {
        final childKey = childKeys[i];
        final childTranslatedName = _getTranslatedSubCategoryName(childKey, 'expense', l10n);

        logger.info('seed_service', '创建支出子分类: key=$childKey, name=$childTranslatedName');

        await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: childTranslatedName, // 使用翻译后的名称
            kind: 'expense',
            icon: Value(getDefaultIcon(childKey)),
            sortOrder: Value(i),
            level: const Value(2),
            parentId: Value(parentId),
            syncId: Value(deterministicCategorySyncId(
                kind: 'expense', level: 2, key: childKey)),
          ),
        );
      }
    }

    // 创建收入分类
    sortOrder = 0;
    for (final entry in hierarchicalIncomeCategories.entries) {
      final parentKey = entry.key;
      final childKeys = entry.value;

      final parentTranslatedName = _getTranslatedParentCategoryName(parentKey, 'income', l10n);
      logger.info('seed_service', '创建收入父分类: key=$parentKey, name=$parentTranslatedName');

      // 创建父分类
      final parentId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: parentTranslatedName, // 使用翻译后的名称
          kind: 'income',
          icon: Value(getDefaultIcon(parentKey)),
          sortOrder: Value(sortOrder++),
          level: const Value(1),
          syncId: Value(deterministicCategorySyncId(
              kind: 'income', level: 1, key: parentKey)),
        ),
      );

      // 创建子分类
      for (var i = 0; i < childKeys.length; i++) {
        final childKey = childKeys[i];
        final childTranslatedName = _getTranslatedSubCategoryName(childKey, 'income', l10n);

        logger.info('seed_service', '创建收入子分类: key=$childKey, name=$childTranslatedName');

        await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: childTranslatedName, // 使用翻译后的名称
            kind: 'income',
            icon: Value(getDefaultIcon(childKey)),
            sortOrder: Value(i),
            level: const Value(2),
            parentId: Value(parentId),
            syncId: Value(deterministicCategorySyncId(
                kind: 'income', level: 2, key: childKey)),
          ),
        );
      }
    }
  }

  /// 完整的种子数据初始化
  ///
  /// [l10n] 国际化对象，用于获取翻译后的名称
  /// [currency] 默认货币代码（如 'CNY', 'USD'）
  /// [useHierarchicalCategories] 是否使用二级分类模式
  static Future<void> seedDatabase(
    BeeDatabase db,
    AppLocalizations l10n, {
    String currency = 'CNY',
    bool useHierarchicalCategories = false,
    bool skipCategories = false,
    bool createDefaultLedger = true,
  }) async {
    logger.info('seed', '开始初始化数据库');
    logger.info('seed', '货币: $currency');
    logger.info('seed', '创建默认账本: $createDefaultLedger');
    if (skipCategories) {
      logger.info('seed', '分类模式: 不创建分类');
    } else {
      logger.info('seed', '分类模式: ${useHierarchicalCategories ? "二级分类" : "一级分类"}');
    }
    logger.info('seed', '账本名称: ${l10n.ledgerDefaultName}');
    logger.info('seed', '现金账户名: ${l10n.accountTypeCash}');

    // 1. 创建默认账本(可选 — 关掉之后用户进首页空状态自己新建,避免每次测试
    //    清数据都在 server 上留一个默认账本)
    if (createDefaultLedger) {
      final ledgerId = await SeedService.createDefaultLedger(db, l10n, currency);
      logger.info('seed', '已创建账本 ID: $ledgerId');
    } else {
      logger.info('seed', '跳过默认账本创建');
    }

    // 2. 创建默认分类（可选）
    if (!skipCategories) {
      if (useHierarchicalCategories) {
        await createHierarchicalCategories(db, l10n);
        logger.info('seed', '已创建二级分类');
      } else {
        await createFlatCategories(db, l10n);
        logger.info('seed', '已创建一级分类');
      }
    } else {
      logger.info('seed', '跳过分类创建');
    }

    // 3. 创建虚拟转账分类（用于自定义转账图标）
    await createTransferCategory(db, l10n);
    logger.info('seed', '已创建虚拟转账分类');

    // 4. 迁移旧转账记录的 category_id
    await migrateTransferTransactions(db);
    logger.info('seed', '已迁移转账记录');

    logger.info('seed', '数据库初始化完成');
  }

  /// 创建虚拟转账分类
  /// 此分类不在普通分类列表中显示，仅用于存储转账的自定义图标
  static Future<void> createTransferCategory(
    BeeDatabase db,
    AppLocalizations l10n,
  ) async {
    // 检查是否已存在
    final existing = await (db.select(db.categories)
      ..where((t) => t.kind.equals('transfer')))
        .getSingleOrNull();

    if (existing != null) {
      logger.info('seed_service', '虚拟转账分类已存在，跳过创建');
      return;
    }

    await db.into(db.categories).insert(
      CategoriesCompanion.insert(
        name: l10n.transferTitle, // 使用国际化的"转账"
        kind: 'transfer', // 特殊kind标识虚拟分类
        icon: const Value('swap_horiz'), // 默认图标
        sortOrder: const Value(-1), // 使用负数排序，确保不会影响正常分类
        level: const Value(1),
        syncId: Value(deterministicCategorySyncId(
            kind: 'transfer', level: 1, key: 'transfer')),
      ),
    );

    logger.info('seed_service', '虚拟转账分类已创建');
  }

  /// 迁移历史转账记录的 category_id
  /// 将所有 type='transfer' 且 category_id 为 NULL 的记录设置为虚拟转账分类 ID
  /// 此方法设计为幂等，可以多次调用
  static Future<void> migrateTransferTransactions(BeeDatabase db) async {
    // 获取虚拟转账分类
    final transferCategory = await (db.select(db.categories)
      ..where((t) => t.kind.equals('transfer')))
        .getSingleOrNull();

    if (transferCategory == null) {
      logger.warning('seed_service', '虚拟转账分类不存在，跳过迁移');
      return;
    }

    // 只更新 category_id 为 NULL 或不等于转账分类ID 的转账记录
    // 使用原始 SQL 以支持复杂的 WHERE 条件
    final affected = await db.customUpdate(
      'UPDATE transactions SET category_id = ?1 WHERE type = ?2 AND (category_id IS NULL OR category_id != ?1)',
      variables: [
        Variable<int>(transferCategory.id),
        const Variable<String>('transfer'),
      ],
      updates: {db.transactions},
    );

    if (affected > 0) {
      logger.info('seed_service', '已迁移 $affected 条转账记录的分类ID');
    } else {
      logger.debug('seed_service', '无需迁移转账记录（已是最新）');
    }
  }
}
