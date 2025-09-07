import 'package:flutter/material.dart';

// 统一的分类名称到图标映射，供列表与分类选择共用，保证一致性
IconData iconForCategory(String name) {
  final n = name;
  if (n.contains('餐') ||
      n.contains('饭') ||
      n.contains('吃') ||
      n.contains('外卖')) {
    return Icons.restaurant_outlined;
  }
  if (n.contains('交通') ||
      n.contains('出行') ||
      n.contains('打车') ||
      n.contains('地铁') ||
      n.contains('公交') ||
      n.contains('高铁') ||
      n.contains('火车') ||
      n.contains('飞机')) {
    return Icons.directions_transit_outlined;
  }
  // 车辆相关（未被上面交通覆盖的“车/车辆/车贷/购车/爱车”）
  if (n == '车' ||
      n.contains('车辆') ||
      n.contains('车贷') ||
      n.contains('购车') ||
      n.contains('爱车')) {
    return Icons.directions_car_outlined;
  }
  if (n.contains('购物') || n.contains('百货')) return Icons.shopping_bag_outlined;
  if (n.contains('服饰') ||
      n.contains('衣') ||
      n.contains('鞋') ||
      n.contains('裤') ||
      n.contains('帽')) {
    return Icons.checkroom_outlined;
  }
  if (n.contains('超市') ||
      n.contains('生鲜') ||
      n.contains('菜') ||
      n.contains('粮油') ||
      n.contains('蔬菜') ||
      n.contains('水果')) {
    return Icons.local_grocery_store_outlined;
  }
  if (n.contains('娱乐') || n.contains('游戏'))
    return Icons.sports_esports_outlined;
  if (n.contains('居家') ||
      n.contains('家') ||
      n.contains('家居') ||
      n.contains('物业') ||
      n.contains('维修')) {
    return Icons.chair_outlined;
  }
  if (n.contains('美妆') ||
      n.contains('化妆') ||
      n.contains('护肤') ||
      n.contains('美容')) {
    return Icons.brush_outlined;
  }
  if (n.contains('通讯') || n.contains('话费') || n.contains('宽带'))
    return Icons.phone_iphone_outlined;
  if (n.contains('订阅') || n.contains('会员') || n.contains('流媒体'))
    return Icons.subscriptions_outlined;
  if (n.contains('礼物') || n.contains('红包') || n.contains('礼金'))
    return Icons.card_giftcard_outlined;
  if (n.contains('水') || n.contains('电') || n.contains('煤') || n.contains('燃气'))
    return Icons.water_drop_outlined;
  if (n.contains('房贷') || n.contains('按揭') || n.contains('贷款'))
    return Icons.account_balance_outlined;
  if (n.contains('房') || n.contains('租')) return Icons.home_outlined;
  if (n.contains('工资') ||
      n.contains('收入') ||
      n.contains('奖金') ||
      n.contains('报销') ||
      n.contains('兼职')) {
    return Icons.attach_money_outlined;
  }
  if (n.contains('理财') ||
      n.contains('利息') ||
      n.contains('基金') ||
      n.contains('股票') ||
      n.contains('退款')) {
    return Icons.savings_outlined;
  }
  if (n.contains('教育') || n.contains('学习') || n.contains('培训'))
    return Icons.menu_book_outlined;
  if (n.contains('医疗') || n.contains('医院') || n.contains('药'))
    return Icons.medical_services_outlined;
  if (n.contains('宠物') || n.contains('猫') || n.contains('狗'))
    return Icons.pets_outlined;
  if (n.contains('运动') || n.contains('健身') || n.contains('球'))
    return Icons.fitness_center_outlined;
  if (n.contains('数码') || n.contains('电子') || n.contains('手机'))
    return Icons.devices_other_outlined;
  if (n.contains('旅行') || n.contains('旅游') || n.contains('出差'))
    return Icons.card_travel_outlined;
  if (n.contains('酒店') || n.contains('住宿') || n.contains('民宿'))
    return Icons.hotel_outlined;
  if (n.contains('烟') || n.contains('酒') || n.contains('茶'))
    return Icons.local_bar_outlined;
  if (n.contains('母婴') || n.contains('孩子') || n.contains('奶粉'))
    return Icons.child_friendly_outlined;
  if (n.contains('停车') ||
      n.contains('加油') ||
      n.contains('汽车') ||
      n.contains('保养')) return Icons.local_gas_station_outlined;
  if (n.contains('快递') || n.contains('邮寄'))
    return Icons.local_shipping_outlined;
  if (n.contains('税') || n.contains('社保') || n.contains('公积金'))
    return Icons.receipt_long_outlined;
  if (n.contains('捐赠') || n.contains('公益'))
    return Icons.volunteer_activism_outlined;
  return Icons.circle_outlined;
}
