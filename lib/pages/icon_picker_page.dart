import 'package:flutter/material.dart';
import '../widgets/ui/ui.dart';
import '../l10n/app_localizations.dart';

class IconPickerPage extends StatefulWidget {
  final String? currentIcon;
  final String kind; // expense 或 income
  
  const IconPickerPage({
    super.key,
    this.currentIcon,
    required this.kind,
  });
  
  @override
  State<IconPickerPage> createState() => _IconPickerPageState();
}

class _IconPickerPageState extends State<IconPickerPage> with TickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedIcon;
  
  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.currentIcon;
    final categories = _getIconCategories();
    _tabController = TabController(length: categories.length, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final categories = _getIconCategories();
    
    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: AppLocalizations.of(context)!.iconPickerTitle,
            showBack: true,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(_selectedIcon);
                },
                child: Text(AppLocalizations.of(context)!.commonConfirm),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: categories.map((category) => Tab(text: category.name)).toList(),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: categories.map((category) {
                return _IconGrid(
                  icons: category.icons,
                  selectedIcon: _selectedIcon,
                  onIconSelected: (icon) {
                    setState(() {
                      _selectedIcon = icon;
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  
  List<_IconCategory> _getIconCategories() {
    if (widget.kind == 'expense') {
      return [
        _IconCategory(
          name: AppLocalizations.of(context)!.iconCategoryDining,
          icons: [
            _IconItem('restaurant', Icons.restaurant, '餐厅'),
            _IconItem('local_dining', Icons.local_dining, '用餐'),
            _IconItem('fastfood', Icons.fastfood, '快餐'),
            _IconItem('local_cafe', Icons.local_cafe, '咖啡'),
            _IconItem('local_bar', Icons.local_bar, '酒吧'),
            _IconItem('cake', Icons.cake, '蛋糕'),
            _IconItem('local_pizza', Icons.local_pizza, '披萨'),
            _IconItem('icecream', Icons.icecream, '冰淇淋'),
          ],
        ),
        _IconCategory(
          name: AppLocalizations.of(context)!.iconCategoryTransport,
          icons: [
            _IconItem('directions_car', Icons.directions_car, '汽车'),
            _IconItem('directions_bus', Icons.directions_bus, '公交'),
            _IconItem('directions_subway', Icons.directions_subway, '地铁'),
            _IconItem('local_taxi', Icons.local_taxi, '出租车'),
            _IconItem('flight', Icons.flight, '飞机'),
            _IconItem('train', Icons.train, '火车'),
            _IconItem('directions_bike', Icons.directions_bike, '自行车'),
            _IconItem('directions_walk', Icons.directions_walk, '步行'),
            _IconItem('local_gas_station', Icons.local_gas_station, '加油'),
            _IconItem('local_parking', Icons.local_parking, '停车'),
          ],
        ),
        _IconCategory(
          name: AppLocalizations.of(context)!.iconCategoryShopping,
          icons: [
            _IconItem('shopping_cart', Icons.shopping_cart, '购物车'),
            _IconItem('shopping_bag', Icons.shopping_bag, '购物袋'),
            _IconItem('store', Icons.store, '商店'),
            _IconItem('local_mall', Icons.local_mall, '商场'),
            _IconItem('local_grocery_store', Icons.local_grocery_store, '超市'),
            _IconItem('checkroom', Icons.checkroom, '服装'),
            _IconItem('watch', Icons.watch, '手表'),
            _IconItem('diamond', Icons.diamond, '珠宝'),
          ],
        ),
        _IconCategory(
          name: AppLocalizations.of(context)!.iconCategoryEntertainment,
          icons: [
            _IconItem('movie', Icons.movie, '电影'),
            _IconItem('music_note', Icons.music_note, '音乐'),
            _IconItem('sports_esports', Icons.sports_esports, '游戏'),
            _IconItem('sports_soccer', Icons.sports_soccer, '足球'),
            _IconItem('sports_basketball', Icons.sports_basketball, '篮球'),
            _IconItem('theater_comedy', Icons.theater_comedy, '娱乐'),
            _IconItem('camera_alt', Icons.camera_alt, '摄影'),
            _IconItem('palette', Icons.palette, '艺术'),
          ],
        ),
        _IconCategory(
          name: AppLocalizations.of(context)!.iconCategoryLife,
          icons: [
            _IconItem('home', Icons.home, '居家'),
            _IconItem('local_laundry_service', Icons.local_laundry_service, '洗衣'),
            _IconItem('cleaning_services', Icons.cleaning_services, '清洁'),
            _IconItem('plumbing', Icons.plumbing, '维修'),
            _IconItem('electrical_services', Icons.electrical_services, '电工'),
            _IconItem('handyman', Icons.handyman, '维护'),
            _IconItem('pets', Icons.pets, '宠物'),
            _IconItem('child_care', Icons.child_care, '母婴'),
          ],
        ),
        _IconCategory(
          name: AppLocalizations.of(context)!.iconCategoryHealth,
          icons: [
            _IconItem('local_hospital', Icons.local_hospital, '医院'),
            _IconItem('medical_services', Icons.medical_services, '医疗'),
            _IconItem('local_pharmacy', Icons.local_pharmacy, '药店'),
            _IconItem('fitness_center', Icons.fitness_center, '健身'),
            _IconItem('spa', Icons.spa, '美容'),
            _IconItem('psychology', Icons.psychology, '心理'),
            _IconItem('face', Icons.face, '护肤'),
            _IconItem('content_cut', Icons.content_cut, '理发'),
          ],
        ),
        _IconCategory(
          name: AppLocalizations.of(context)!.iconCategoryEducation,
          icons: [
            _IconItem('school', Icons.school, '学校'),
            _IconItem('library_books', Icons.library_books, '书籍'),
            _IconItem('computer', Icons.computer, '电脑'),
            _IconItem('phone', Icons.phone, '通讯'),
            _IconItem('language', Icons.language, '语言'),
            _IconItem('science', Icons.science, '科学'),
            _IconItem('calculate', Icons.calculate, '计算'),
            _IconItem('brush', Icons.brush, '绘画'),
          ],
        ),
        _IconCategory(
          name: AppLocalizations.of(context)!.iconCategoryOther,
          icons: [
            _IconItem('business', Icons.business, '商务'),
            _IconItem('work', Icons.work, '工作'),
            _IconItem('flash_on', Icons.flash_on, '水电'),
            _IconItem('wifi', Icons.wifi, '网络'),
            _IconItem('phone_android', Icons.phone_android, '手机'),
            _IconItem('smoking_rooms', Icons.smoking_rooms, '烟酒'),
            _IconItem('favorite', Icons.favorite, '捐赠'),
            _IconItem('category', Icons.category, '其他'),
          ],
        ),
      ];
    } else {
      // 收入分类图标
      return [
        _IconCategory(
          name: AppLocalizations.of(context)!.iconCategoryWork,
          icons: [
            _IconItem('work', Icons.work, '工资'),
            _IconItem('business_center', Icons.business_center, '商务'),
            _IconItem('engineering', Icons.engineering, '技术'),
            _IconItem('design_services', Icons.design_services, '设计'),
            _IconItem('agriculture', Icons.agriculture, '农业'),
            _IconItem('construction', Icons.construction, '建筑'),
            _IconItem('local_shipping', Icons.local_shipping, '物流'),
            _IconItem('restaurant_menu', Icons.restaurant_menu, '餐饮'),
          ],
        ),
        _IconCategory(
          name: AppLocalizations.of(context)!.iconCategoryFinance,
          icons: [
            _IconItem('account_balance', Icons.account_balance, '银行'),
            _IconItem('savings', Icons.savings, '储蓄'),
            _IconItem('trending_up', Icons.trending_up, '投资'),
            _IconItem('paid', Icons.paid, '利息'),
            _IconItem('currency_exchange', Icons.currency_exchange, '汇率'),
            _IconItem('wallet', Icons.wallet, '钱包'),
            _IconItem('credit_card', Icons.credit_card, '信用卡'),
            _IconItem('account_balance_wallet', Icons.account_balance_wallet, '余额'),
          ],
        ),
        _IconCategory(
          name: AppLocalizations.of(context)!.iconCategoryReward,
          icons: [
            _IconItem('card_giftcard', Icons.card_giftcard, '红包'),
            _IconItem('redeem', Icons.redeem, '奖金'),
            _IconItem('emoji_events', Icons.emoji_events, '奖励'),
            _IconItem('star', Icons.star, '评级'),
            _IconItem('grade', Icons.grade, '等级'),
            _IconItem('loyalty', Icons.loyalty, '积分'),
            _IconItem('volunteer_activism', Icons.volunteer_activism, '礼金'),
            _IconItem('celebration', Icons.celebration, '庆祝'),
          ],
        ),
        _IconCategory(
          name: AppLocalizations.of(context)!.iconCategoryOther,
          icons: [
            _IconItem('receipt_long', Icons.receipt_long, '报销'),
            _IconItem('part_time', Icons.schedule, '兼职'),
            _IconItem('undo', Icons.undo, '退款'),
            _IconItem('money', Icons.attach_money, '现金'),
            _IconItem('apartment', Icons.apartment, '租金'),
            _IconItem('handshake', Icons.handshake, '合作'),
            _IconItem('category', Icons.category, '其他'),
            _IconItem('help', Icons.help, '未分类'),
          ],
        ),
      ];
    }
  }
}

class _IconGrid extends StatelessWidget {
  final List<_IconItem> icons;
  final String? selectedIcon;
  final ValueChanged<String> onIconSelected;
  
  const _IconGrid({
    required this.icons,
    required this.selectedIcon,
    required this.onIconSelected,
  });
  
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: icons.length,
      itemBuilder: (context, index) {
        final icon = icons[index];
        final isSelected = selectedIcon == icon.key;
        
        return InkWell(
          onTap: () => onIconSelected(icon.key),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : null,
              border: Border.all(
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon.iconData,
                  size: 32,
                  color: isSelected 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).iconTheme.color,
                ),
                const SizedBox(height: 4),
                Text(
                  icon.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isSelected 
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IconCategory {
  final String name;
  final List<_IconItem> icons;
  
  const _IconCategory({
    required this.name,
    required this.icons,
  });
}

class _IconItem {
  final String key;
  final IconData iconData;
  final String label;
  
  const _IconItem(this.key, this.iconData, this.label);
}