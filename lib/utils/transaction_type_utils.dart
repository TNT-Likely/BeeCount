/// 交易类型常量。
///
/// 平账不是收入或支出，必须使用独立类型参与账户余额计算，同时从收支
/// 统计中排除。UI 展示名统一为“平账”，不要把内部编码暴露给用户。
const balanceAdjustmentTransactionType = 'balance_adjustment';
const balanceAdjustmentTagName = '平账';

bool isBalanceAdjustmentTransaction(String type) =>
    type == balanceAdjustmentTransactionType;
