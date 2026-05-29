import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/data/seed_service.dart';

/// 分类工具类
/// 负责处理分类名称的显示、翻译等
class CategoryUtils {
  CategoryUtils._();

  /// 分隔符：用于在翻译字符串中分隔多个分类名称
  static const String separator = '-';

  /// 判断分类名称是否为key格式（新系统）
  /// 如果包含下划线或在默认分类列表中，则认为是key
  static bool isCategoryKey(String name) {
    // 包含下划线的肯定是key（如 dining_breakfast）
    if (name.contains('_')) return true;

    // 检查是否在默认分类key列表中
    return SeedService.flatExpenseCategoryKeys.contains(name) ||
           SeedService.flatIncomeCategoryKeys.contains(name) ||
           SeedService.hierarchicalExpenseCategories.containsKey(name) ||
           SeedService.hierarchicalIncomeCategories.containsKey(name);
  }

  /// 获取分类的显示名称
  ///
  /// - 如果是key格式（新系统），通过 l10n 翻译
  /// - 否则直接返回分类名称（老用户或自定义分类）
  static String getDisplayName(String? categoryName, BuildContext context, {String kind = 'expense'}) {
    if (categoryName == null || categoryName.isEmpty) {
      return AppLocalizations.of(context).categoryDefaultTitle;
    }

    final l10n = AppLocalizations.of(context);

    // 如果是key格式（新系统），进行翻译
    if (isCategoryKey(categoryName)) {
      return _translateCategoryKey(categoryName, kind, l10n);
    }

    // 直接返回分类名称（老用户或自定义分类）
    return categoryName;
  }

  /// 翻译分类key为显示名称
  static String _translateCategoryKey(String key, String kind, AppLocalizations l10n) {
    // 获取对应的翻译字符串
    final translationString = _getCategoryTranslationString(key, kind, l10n);

    if (translationString.isEmpty) {
      // 如果没有找到翻译，返回key本身
      return key;
    }

    // 解析翻译字符串
    return _parseCategoryName(key, kind, translationString);
  }

  /// 获取分类的翻译字符串
  static String _getCategoryTranslationString(String key, String kind, AppLocalizations l10n) {
    // 判断是一级分类还是二级分类
    if (key.contains('_')) {
      // 二级分类：key格式为 parent_child，如 dining_breakfast
      final parts = key.split('_');
      if (parts.length >= 2) {
        final parentKey = parts[0];

        // 根据kind选择对应的翻译
        if (kind == 'expense') {
          return _getExpenseSubcategoryTranslation(parentKey, l10n);
        } else {
          return _getIncomeSubcategoryTranslation(parentKey, l10n);
        }
      }
    } else {
      // 一级分类
      if (kind == 'expense') {
        return l10n.categoryExpense;
      } else {
        return l10n.categoryIncome;
      }
    }

    return '';
  }

  /// 获取支出类二级分类的翻译字符串
  static String _getExpenseSubcategoryTranslation(String parentKey, AppLocalizations l10n) {
    switch (parentKey) {
      case 'dining': return l10n.categoryExpenseDining;
      case 'snacks': return l10n.categoryExpenseSnacks;
      case 'fruit': return l10n.categoryExpenseFruit;
      case 'beverage': return l10n.categoryExpenseBeverage;
      case 'pastry': return l10n.categoryExpensePastry;
      case 'cooking': return l10n.categoryExpenseCooking;
      case 'shopping': return l10n.categoryExpenseShopping;
      case 'pets': return l10n.categoryExpensePets;
      case 'transport': return l10n.categoryExpenseTransport;
      case 'car': return l10n.categoryExpenseCar;
      case 'clothing': return l10n.categoryExpenseClothing;
      case 'daily_goods': return l10n.categoryExpenseDailyGoods;
      case 'education': return l10n.categoryExpenseEducation;
      case 'invest_loss': return l10n.categoryExpenseInvestLoss;
      case 'entertainment': return l10n.categoryExpenseEntertainment;
      case 'game': return l10n.categoryExpenseGame;
      case 'health_products': return l10n.categoryExpenseHealthProducts;
      case 'subscription': return l10n.categoryExpenseSubscription;
      case 'sports': return l10n.categoryExpenseSports;
      case 'housing': return l10n.categoryExpenseHousing;
      case 'home': return l10n.categoryExpenseHome;
      case 'beauty': return l10n.categoryExpenseBeauty;
      default: return '';
    }
  }

  /// 获取收入类二级分类的翻译字符串
  static String _getIncomeSubcategoryTranslation(String parentKey, AppLocalizations l10n) {
    switch (parentKey) {
      case 'salary': return l10n.categoryIncomeSalary;
      case 'investment': return l10n.categoryIncomeInvestment;
      case 'red_packet': return l10n.categoryIncomeRedPacket;
      case 'bonus': return l10n.categoryIncomeBonus;
      case 'reimbursement': return l10n.categoryIncomeReimbursement;
      case 'part_time': return l10n.categoryIncomePartTime;
      case 'gift': return l10n.categoryIncomeGift;
      case 'interest': return l10n.categoryIncomeInterest;
      case 'refund': return l10n.categoryIncomeRefund;
      case 'invest_income': return l10n.categoryIncomeInvestIncome;
      case 'second_hand': return l10n.categoryIncomeSecondHand;
      case 'social_benefit': return l10n.categoryIncomeSocialBenefit;
      case 'tax_refund': return l10n.categoryIncomeTaxRefund;
      case 'provident_fund': return l10n.categoryIncomeProvidentFund;
      default: return '';
    }
  }

  /// 从翻译字符串中解析出对应的分类名称
  ///
  /// 例如：
  /// - key = "dining", kind = "expense", translationString = "餐饮-交通-购物-..." -> "餐饮"
  /// - key = "dining_breakfast", kind = "expense", translationString = "早餐-午餐-晚餐-..." -> "早餐"
  static String _parseCategoryName(String key, String kind, String translationString) {
    final names = translationString.split(separator);

    if (key.contains('_')) {
      // 二级分类：需要找到对应的索引
      final parts = key.split('_');
      if (parts.length >= 2) {
        final parentKey = parts[0];
        final childKey = key; // 完整的key，如 dining_breakfast

        // 获取父分类的子分类列表
        final childKeys = kind == 'expense'
            ? (SeedService.hierarchicalExpenseCategories[parentKey] ?? [])
            : (SeedService.hierarchicalIncomeCategories[parentKey] ?? []);

        // 找到当前key在列表中的索引
        final index = childKeys.indexOf(childKey);
        if (index >= 0 && index < names.length) {
          return names[index].trim();
        }
      }
    } else {
      // 一级分类：需要找到对应的索引
      final keys = kind == 'expense'
          ? SeedService.flatExpenseCategoryKeys
          : SeedService.flatIncomeCategoryKeys;

      final index = keys.indexOf(key);
      if (index >= 0 && index < names.length) {
        return names[index].trim();
      }
    }

    // 如果找不到，返回key本身
    return key;
  }

  /// 获取所有一级分类的显示名称列表
  static List<String> getAllCategoryDisplayNames(String kind, AppLocalizations l10n) {
    final translationString = kind == 'expense'
        ? l10n.categoryExpense
        : l10n.categoryIncome;

    return translationString.split(separator).map((e) => e.trim()).toList();
  }

  /// 获取指定父分类的所有子分类显示名称列表
  static List<String> getSubcategoryDisplayNames(String parentKey, String kind, AppLocalizations l10n) {
    final translationString = _getCategoryTranslationString('${parentKey}_', kind, l10n);

    if (translationString.isEmpty) {
      return [];
    }

    return translationString.split(separator).map((e) => e.trim()).toList();
  }

  /// 获取父级分类的显示名称
  ///
  /// 对于二级分类的key格式（如 "dining_breakfast"），提取父级key（"dining"）
  /// 并返回其翻译后的显示名称（"餐饮"）。
  /// 如果是一级分类，返回null。
  static String? getParentDisplayName(String? categoryName, String kind, BuildContext context) {
    if (categoryName == null || !categoryName.contains('_')) return null;
    final parentKey = categoryName.split('_').first;
    return getDisplayName(parentKey, context, kind: kind);
  }
}
