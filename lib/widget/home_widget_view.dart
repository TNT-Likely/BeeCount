import 'package:flutter/material.dart';

/// Flutter widget that will be rendered as the home screen widget
class HomeWidgetView extends StatelessWidget {
  final String todayExpense;
  final String todayIncome;
  final String monthExpense;
  final String monthIncome;
  final Color themeColor;
  final bool redForIncome;
  final String appName;
  final String monthSuffix;
  final String todayExpenseLabel;
  final String todayIncomeLabel;
  final String monthExpenseLabel;
  final String monthIncomeLabel;
  final double width;
  final double height;

  const HomeWidgetView({
    super.key,
    required this.todayExpense,
    required this.todayIncome,
    required this.monthExpense,
    required this.monthIncome,
    required this.themeColor,
    required this.redForIncome,
    required this.appName,
    required this.monthSuffix,
    required this.todayExpenseLabel,
    required this.todayIncomeLabel,
    required this.monthExpenseLabel,
    required this.monthIncomeLabel,
    required this.width,
    required this.height,
  });

  static const Color _redColor = Color(0xFFFF6B6B);
  static const Color _greenColor = Color(0xFF51CF66);

  Color get _incomeColor => redForIncome ? _redColor : _greenColor;
  Color get _expenseColor => redForIncome ? _greenColor : _redColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            themeColor,
            Color.lerp(themeColor, Colors.black, 0.15)!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                appName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(38),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 11,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${DateTime.now().month}$monthSuffix',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Main content - 2x2 grid
          Expanded(
            child: Row(
              children: [
                // Today's expense
                Expanded(
                  child: _buildStatCard(
                    todayExpenseLabel,
                    todayExpense,
                    _expenseColor,
                    Icons.arrow_upward,
                    true,
                  ),
                ),
                const SizedBox(width: 10),
                // Today's income
                Expanded(
                  child: _buildStatCard(
                    todayIncomeLabel,
                    todayIncome,
                    _incomeColor,
                    Icons.arrow_downward,
                    true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                // Month's expense
                Expanded(
                  child: _buildStatCard(
                    monthExpenseLabel,
                    monthExpense,
                    _expenseColor,
                    Icons.trending_up,
                    false,
                  ),
                ),
                const SizedBox(width: 10),
                // Month's income
                Expanded(
                  child: _buildStatCard(
                    monthIncomeLabel,
                    monthIncome,
                    _incomeColor,
                    Icons.trending_down,
                    false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    IconData icon,
    bool isToday,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  icon,
                  size: 10,
                  color: color,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isToday ? 16 : 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.add_circle_outline,
                size: 12,
                color: Colors.grey[400],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
