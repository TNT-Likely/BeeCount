/// S1-01b 锁账功能开关(App 侧)。
///
/// false = 不展示任何锁账交互:入口(账本长按菜单)、只读态区块、锁图标
/// 全部短路。三处必须同读这一个开关 —— 漏掉任何一处都会露出半套锁账
/// 交互(比如入口藏了,但流水列表里出现了锁图标)。
///
/// 通过 `--dart-define=BEECOUNT_LOCK_PERIOD_ENABLED=true` 打开,便于单卡
/// 验收时手动验证写路径;正式发布前保持默认关闭。
const bool kEnableLockPeriod =
    bool.fromEnvironment('BEECOUNT_LOCK_PERIOD_ENABLED', defaultValue: false);
