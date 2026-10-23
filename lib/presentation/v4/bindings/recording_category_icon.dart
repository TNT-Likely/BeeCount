import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../data/db.dart';
import '../../../widgets/category_icon.dart';

/// Map saved icon identifiers, never category names. Custom images keep their colors.
class RecordingCategoryIcon extends StatelessWidget {
  const RecordingCategoryIcon(
      {super.key, required this.category, this.size = 18, this.color});
  final Category category;
  final double size;
  final Color? color;

  static const _lineIcons = {
    'restaurant': 'Utensils',
    'restaurant_menu': 'Utensils',
    'food_bank': 'Utensils',
    'coffee': 'Coffee',
    'local_cafe': 'Coffee',
    'free_breakfast': 'Coffee',
    'train': 'TrainFront',
    'directions_railway': 'TrainFront',
    'directions_subway': 'TrainFront',
    'directions_transit': 'TrainFront',
    'shopping_basket': 'ShoppingBasket',
    'shopping_cart': 'ShoppingBasket',
    'shopping_bag': 'ShoppingBag',
    'home': 'House',
    'house': 'House',
    'movie': 'Clapperboard',
    'theaters': 'Clapperboard',
    'menu_book': 'BookOpen',
    'book': 'BookOpen',
    'category': 'Shapes',
    'more_horiz': 'Ellipsis',
    'fastfood': 'Sandwich',
    'lunch_dining': 'Utensils',
    'dinner_dining': 'Soup',
    'breakfast_dining': 'Coffee',
    'cake': 'CakeSlice',
    'local_bar': 'Wine',
    'card_giftcard': 'Gift',
    'redeem': 'Gift',
    'payments': 'Banknote',
    'attach_money': 'Banknote',
    'work': 'BriefcaseBusiness',
    'business_center': 'BriefcaseBusiness',
    'local_hospital': 'HeartPulse',
    'medical_services': 'HeartPulse',
    'directions_car': 'Car',
    'directions_bus': 'Bus',
    'flight': 'Plane',
    'checkroom': 'Shirt',
    'phone_android': 'Smartphone',
    'smartphone': 'Smartphone',
    'sports_esports': 'Gamepad2',
    'school': 'GraduationCap',
    'child_care': 'Baby',
    'pets': 'PawPrint',
    'fitness_center': 'Dumbbell',
    'local_gas_station': 'Fuel',
  };

  @override
  Widget build(BuildContext context) {
    final line = _lineIcons[category.icon];
    if (category.iconType == 'custom' || line == null) {
      return CategoryIconWidget(category: category, size: size, color: color);
    }
    return BeeLineIcon(line, size: size, color: color);
  }
}
