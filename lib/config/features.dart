/// S1-01a 锁账功能开关。
///
/// 本卡只做数据通道,不接 UI / 拦截(归 S1-01b);开关先落地为常量,
/// 供后续端侧预校验入口读取。false = 不展示任何锁账交互。
const bool kEnableLockPeriod = false;
