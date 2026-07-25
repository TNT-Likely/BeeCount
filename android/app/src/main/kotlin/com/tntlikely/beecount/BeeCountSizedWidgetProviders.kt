package com.tntlikely.beecount

/**
 * 各内容类型的「按尺寸拆分的选择器入口」——全部是**空子类**,完整复用父类
 * 的按尺寸选图(`getAppWidgetOptions`)与点击逻辑,只靠各自独立的
 * `appwidget-provider` info(minWidth/minHeight,见 `res/xml` 下的 `*_widget_info.xml`)
 * 让 Android 选择器里直接出现"中号/大号"入口、添加即为对应默认大小。
 *
 * 背景(2026-07 真机反馈):Android 选择器不像 iOS 的 widget family 会按
 * 尺寸分档展示——一个 provider 只有一条入口,默认落最小档,中/大号只能
 * "先加小的再长按拉伸"才能得到,用户根本不知道有这些档位("中尺寸预算、
 * 净资产,大尺寸净资产还是没有")。拆 provider 后选择器 1:1 对齐
 * `lib/widget/widget_spec.dart` 的 12 个 (type, size) 组合。
 *
 * 老的父类 provider 保持原类名与注册不变(存量放置不受影响),作为各类型
 * **最小档**的入口;所有档位入口都可继续自由拉伸(父类逻辑按实际尺寸选图)。
 */

/** 净资产·中(默认 4×2)。 */
class BeeCountNetWorthMediumWidgetProvider : BeeCountNetWorthWidgetProvider()

/** 净资产·大(默认 4×4)。 */
class BeeCountNetWorthLargeWidgetProvider : BeeCountNetWorthWidgetProvider()

/** 预算进度·中(默认 4×2)。 */
class BeeCountBudgetMediumWidgetProvider : BeeCountBudgetWidgetProvider()

/** 快速记账·中(默认 4×2)。 */
class BeeCountQuickAddMediumWidgetProvider : BeeCountQuickAddWidgetProvider()

/** 最近交易·大(默认 4×4)。 */
class BeeCountRecentLargeWidgetProvider : BeeCountRecentWidgetProvider()
