# BeeCount Design Token 系统

> 文件位置：`lib/styles/tokens.dart`
>
> 统一的 Design Token 系统，包含颜色、尺寸、阴影、字体等所有设计令牌。
> 所有 UI 组件都应该使用 Token 而非直接使用颜色值，以确保暗黑模式正确适配。

## Token 使用方式

```dart
import '../../styles/tokens.dart';

// 在 Widget 中使用
Container(
  color: BeeTokens.surface(context),
  child: Text(
    'Hello',
    style: TextStyle(color: BeeTokens.textPrimary(context)),
  ),
)
```

同页的单选视图／流水筛选统一使用 `widgets/ui/ui.dart` 导出的
`CapsuleSwitcher<T>`：灰色 `surfaceCapsule` 轨道，日间默认黑底白字选中，
暗色模式使用主题色选中胶囊；选中文字由 `textOnColor` 根据背景明暗决定。
各页面直接使用组件默认配色。调用方持有选中值和业务筛选；
不另用默认 Material `ChoiceChip` 拼装 tabs。选项能完整放下时等宽，
窄屏或大字号下横向滚动；组件提供选中语义并遵循系统减少动画设置。

独立多选使用同一入口导出的 `BeeMultiSelect<T>`：日间黑底白字、暗色主题色选中，
未选项使用 `surfaceCapsule`，通过勾选/加号区分状态。选项自动换行，触控高度至少
44，提供复选语义并遵循减少动画设置。调用方持有选中集合，组件不修改输入集合；
不要用默认 Material `FilterChip` 拼装多选字段。

---

## 1. 背景色 Token (Surface)

| Token 名称 | 用途 | 亮色模式 | 暗黑模式 |
|-----------|------|---------|---------|
| `scaffoldBackground` | 页面背景（Scaffold） | `#FAFAFA` 灰50 | `#000000` 纯黑 |
| `surface` | 卡片背景 | `#FFFFFF` 白色 | `#1C1C1E` 深灰 |
| `surfaceSecondary` | 次级背景（嵌套卡片、输入框） | `#F5F5F5` 灰100 | `#2C2C2E` 更深灰 |
| `surfaceElevated` | 悬浮卡片（Dialog、BottomSheet） | `#FFFFFF` 白色 | `#2C2C2E` 略亮于普通卡片 |
| `surfaceHeader` | PrimaryHeader 背景 | 用户主题色 | `#000000` 纯黑 |
| `surfaceSheet` | BottomSheet 背景（金额输入等） | `#FFFFFF` 白色 | `#000000` 纯黑 |
| `surfaceKey` | 键盘按钮背景 | `#FFFFFF` 白色 | `#000000` 纯黑 |
| `surfaceKeySecondary` | 键盘次级按钮（日期、+/-） | `#F5F5F5` 灰100 | `#2C2C2E` 深灰 |
| `surfaceDisabled` | 禁用按钮背景 | `#E0E0E0` 灰300 | `#1C1C1E` 更深灰 |
| `surfaceInput` | 输入框背景 | `#F3F4F6` 浅灰 | `#2C2C2E` 深灰 |
| `surfaceChip` | 标签/Chip 背景（未选中） | `#EEEEEE` 灰200 | `#2C2C2E` 深灰 |
| `surfaceCapsule` | 胶囊切换器背景 | `rgba(0,0,0,0.06)` | `#2C2C2E` 深灰 |
| `surfacePopoverCard` | 弹出层内卡片（二级分类选择） | `#FFFFFF` 白色 | `#3A3A3C` 中灰 |
| `surfaceCategoryIcon` | 分类图标背景（未选中） | `#EEEEEE` 灰200 | `#48484A` 中灰 |
| `surfaceCategoryIconLight` | 分类图标背景（浅色/二级） | `#F5F5F5` 灰100 | `#3A3A3C` 深灰 |
| `surfaceSelected` | 选中状态背景 | 主题色 8% | 主题色 15% |
| `surfaceHover` | 悬停/按压状态 | `rgba(0,0,0,0.04)` | `rgba(255,255,255,0.08)` |

### 替换对照

| 旧写法 | 新写法 |
|-------|--------|
| `BeeColors.greyBg` | `BeeTokens.scaffoldBackground(context)` |
| `Colors.white` (卡片背景) | `BeeTokens.surface(context)` |
| `Colors.grey.shade50` | `BeeTokens.scaffoldBackground(context)` |
| `Colors.grey.shade100` | `BeeTokens.surfaceSecondary(context)` |
| `Colors.grey.shade200` | `BeeTokens.surfaceChip(context)` |

---

## 2. 文字颜色 Token (Text)

| Token 名称 | 用途 | 亮色模式 | 暗黑模式 |
|-----------|------|---------|---------|
| `textPrimary` | 主要文字（标题、正文） | `#111827` 灰900 | `#FFFFFF` 白色 |
| `textSecondary` | 次要文字（副标题、说明） | `rgba(0,0,0,0.54)` | `rgba(255,255,255,0.7)` |
| `textTertiary` | 提示文字（placeholder、hint） | `#9CA3AF` 灰400 | `rgba(255,255,255,0.54)` |
| `textDisabled` | 禁用文字 | `rgba(0,0,0,0.26)` | `rgba(255,255,255,0.38)` |
| `textOnPrimary` | 反色文字（深色背景上） | `#FFFFFF` | `#FFFFFF` |
| `textLink` | 链接文字 | `#3B82F6` 蓝色 | `#60A5FA` 亮蓝色 |
| `textOnHeader` | Header 内主要文字 | `#FFFFFF` | `#FFFFFF` |
| `textOnHeaderSecondary` | Header 内次要文字 | `rgba(255,255,255,0.8)` | `rgba(255,255,255,0.7)` |

### 替换对照

| 旧写法 | 新写法 |
|-------|--------|
| `BeeColors.primaryText` | `BeeTokens.textPrimary(context)` |
| `BeeColors.secondaryText` | `BeeTokens.textSecondary(context)` |
| `BeeColors.hintText` | `BeeTokens.textTertiary(context)` |
| `Colors.black87` | `BeeTokens.textPrimary(context)` |
| `Colors.black54` | `BeeTokens.textSecondary(context)` |
| `Colors.white` (文字) | `BeeTokens.textOnPrimary(context)` |

---

## 3. 图标颜色 Token (Icon)

| Token 名称 | 用途 | 亮色模式 | 暗黑模式 |
|-----------|------|---------|---------|
| `iconPrimary` | 主要图标 | `#000000` 87% | `#FFFFFF` 白色 |
| `iconSecondary` | 次要图标 | `rgba(0,0,0,0.54)` | `rgba(255,255,255,0.7)` |
| `iconTertiary` | 提示图标 | `rgba(0,0,0,0.38)` | `rgba(255,255,255,0.54)` |
| `iconCategory` | 分类图标（未选中） | `#616161` 灰700 | `#AEAEB2` 浅灰 |

### 替换对照

| 旧写法 | 新写法 |
|-------|--------|
| `Colors.black87` (图标) | `BeeTokens.iconPrimary(context)` |
| `Colors.black54` (图标) | `BeeTokens.iconSecondary(context)` |
| `Colors.grey` (图标) | `BeeTokens.iconTertiary(context)` |
| `Colors.grey.shade700` | `BeeTokens.iconCategory(context)` |

---

## 4. 边框/分割线 Token (Border)

| Token 名称 | 用途 | 亮色模式 | 暗黑模式 |
|-----------|------|---------|---------|
| `divider` | 分割线 | `rgba(0,0,0,0.06)` | 主题色 30% |
| `border` | 卡片边框 | `transparent` | 主题色 30% |
| `borderStrong` | 强调边框 | `rgba(0,0,0,0.12)` | 主题色 30% |
| `borderThemed` | 主题色边框 | `transparent` | 主题色 30% |
| `cardOuterBorderColor` | 卡片外边框颜色 | `transparent` | `transparent` |
| `cardOuterBorderWidth` | 卡片外边框宽度 | `0` | `0` |
| `cardInnerDividerColor` | 卡片内分割线颜色 | `rgba(0,0,0,0.06)` | `transparent` |
| `cardInnerDividerHeight` | 卡片内分割线高度 | `1` | `0` |

### 替换对照

| 旧写法 | 新写法 |
|-------|--------|
| `BeeColors.divider` | `BeeTokens.divider(context)` |
| `const Divider(height: 1)` | `BeeTokens.cardDivider(context)` |
| `Colors.black.withOpacity(0.06)` | `BeeTokens.divider(context)` |

---

## 5. 语义色 Token (Semantic)

| Token 名称 | 用途 | 亮色模式 | 暗黑模式 |
|-----------|------|---------|---------|
| `success` | 成功状态 | `#22C55E` 绿色 | `#34D399` 亮绿 |
| `warning` | 警告状态 | `#F59E0B` 橙色 | `#FBBF24` 亮橙 |
| `error` | 错误状态 | `#EF4444` 红色 | `#F87171` 亮红 |
| `info` | 信息提示 | `#3B82F6` 蓝色 | `#60A5FA` 亮蓝 |

### 替换对照

| 旧写法 | 新写法 |
|-------|--------|
| `BeeColors.success` | `BeeTokens.success(context)` |
| `BeeColors.warning` | `BeeTokens.warning(context)` |
| `BeeColors.danger` | `BeeTokens.error(context)` |
| `Colors.green` | `BeeTokens.success(context)` |
| `Colors.orange` | `BeeTokens.warning(context)` |
| `Colors.red` | `BeeTokens.error(context)` |

---

## 6. 交互色 Token (Interactive)

| Token 名称 | 用途 | 亮色模式 | 暗黑模式 |
|-----------|------|---------|---------|
| `buttonPrimary` | 主按钮背景 | 主题色 | 主题色 |
| `buttonSecondary` | 次要按钮背景 | `transparent` | `transparent` |
| `buttonPrimaryText` | 主按钮文字 | `#FFFFFF` | `#FFFFFF` |
| `buttonSecondaryText` | 次要按钮文字 | 主题色 | 主题色 |
| `buttonDisabled` | 禁用按钮背景 | `#E5E7EB` | `#3C3C3E` |
| `switchActiveTrack` | Switch 开启轨道 | 主题色 | 主题色 |
| `switchInactiveTrack` | Switch 关闭轨道 | `#E5E7EB` | `#3C3C3E` |

---

## 7. 品牌图标色 Token (Brand Icons)

这些颜色是各服务的品牌色，在亮暗模式下保持一致。

| Token 名称 | 用途 | 颜色值 |
|-----------|------|--------|
| `brandLocal` | 本地存储图标 | `#9E9E9E` 灰色 |
| `brandSupabase` | Supabase 图标 | `#3ECF8E` 绿色 |
| `brandWebdav` | WebDAV 图标 | `#FF9800` 橙色 |
| `brandCloud` | 云服务通用图标 | `#2196F3` 蓝色 |

### 替换对照

| 旧写法 | 新写法 |
|-------|--------|
| `Colors.grey` (本地存储) | `BeeTokens.brandLocal` |
| `Colors.blue` (云服务) | `BeeTokens.brandCloud` |
| `Colors.orange` (WebDAV) | `BeeTokens.brandWebdav` |

---

## 8. 状态指示器 Token (Status Indicators)

| Token 名称 | 用途 | 亮色模式 | 暗黑模式 |
|-----------|------|---------|---------|
| `statusOnline` | 在线/连接成功 | `#22C55E` | `#34D399` |
| `statusOffline` | 离线/断开连接 | `#9CA3AF` | `rgba(255,255,255,0.38)` |
| `statusPending` | 待处理/等待中 | `#F59E0B` | `#FBBF24` |

---

## 9. 图表/统计色 Token (Chart Colors)

| Token 名称 | 用途 | 亮色模式 | 暗黑模式 |
|-----------|------|---------|---------|
| `chartIncome` | 收入颜色 | `#22C55E` | `#34D399` |
| `chartExpense` | 支出颜色 | `#EF4444` | `#F87171` |
| `chartTransfer` | 转账颜色 | `#3B82F6` | `#60A5FA` |

---

## 10. 遮罩层 Token (Overlay)

| Token 名称 | 用途 | 亮色模式 | 暗黑模式 |
|-----------|------|---------|---------|
| `overlay` | 模态遮罩层 | `rgba(0,0,0,0.5)` | `rgba(0,0,0,0.7)` |
| `overlayLight` | 轻量遮罩层 | `rgba(0,0,0,0.05)` | `rgba(255,255,255,0.05)` |

---

## 辅助方法

```dart
// 判断当前是否为暗黑模式
final isDark = BeeTokens.isDark(context);

// 根据语义获取颜色
final color = BeeTokens.semantic(context, 'success'); // success/warning/error/info
```

---

## 11. 尺寸令牌 (BeeDimens)

统一间距、圆角等尺寸。

| Token 名称 | 值 | 用途 |
|-----------|-----|------|
| `BeeDimens.p8` | `8` | 小间距 |
| `BeeDimens.p12` | `12` | 中间距 |
| `BeeDimens.p16` | `16` | 大间距 |
| `BeeDimens.radius12` | `12` | 小圆角 |
| `BeeDimens.radius16` | `16` | 大圆角 |
| `BeeDimens.listHeaderVertical` | `6` | 列表头垂直内边距 |
| `BeeDimens.listRowVertical` | `8` | 列表行垂直内边距 |

---

## 12. 阴影令牌 (BeeShadows)

```dart
// 卡片阴影
boxShadow: BeeShadows.card,
```

---

## 13. 分割线令牌 (BeeDivider)

```dart
// 细分割线
BeeDivider.thin()

// 带缩进的分割线
BeeDivider.short(indent: 16, endIndent: 16)

// 自适应暗黑模式的卡片内分割线
BeeTokens.cardDivider(context)
```

---

## 14. 图表令牌 (BeeChartTokens)

| Token 名称 | 值 | 用途 |
|-----------|-----|------|
| `BeeChartTokens.lineWidth` | `2.0` | 折线宽度 |
| `BeeChartTokens.dotRadius` | `2.5` | 数据点半径 |
| `BeeChartTokens.cornerRadius` | `12.0` | 图表圆角 |
| `BeeChartTokens.xLabelFontSize` | `10.0` | X轴标签字号 |
| `BeeChartTokens.yLabelFontSize` | `10.0` | Y轴标签字号 |

---

## 15. 文本样式令牌 (BeeTextTokens)

**注意：** 这些方法已自动适配暗黑模式文字颜色。

```dart
// 标题样式（列表主标题）- 15px w400
BeeTextTokens.title(context)

// 强调标题（统计数字）- 15px w600
BeeTextTokens.strongTitle(context)

// 加粗标题（大额数字）- 18px w700
BeeTextTokens.boldTitle(context)

// 正文样式 - 14px w400
BeeTextTokens.body(context)

// 标签/说明样式 - 12px
BeeTextTokens.label(context)
```

---

## 16. 字体令牌 (BeeTypography)

用于构建主题的基础文本样式。

```dart
// 构建文本主题
final textTheme = BeeTypography.buildBase(
  Theme.of(context).textTheme,
  isIOS: Platform.isIOS,
);
```

---

## 17. 静态常量（无 context 场景）

用于 `CustomPainter`、主题定义等无法访问 `BuildContext` 的场景。

| Token 名称 | 值 | 用途 |
|-----------|-----|------|
| `BeeTokens.primaryTextStatic` | `#111827` | 主要文字（亮色模式） |
| `BeeTokens.secondaryTextStatic` | `#6B7280` | 次要文字（亮色模式） |
| `BeeTokens.hintTextStatic` | `#9CA3AF` | 提示文字（亮色模式） |
| `BeeTokens.black54Static` | `0x8A000000` | 54% 黑色（亮色模式） |
| `BeeTokens.dividerStatic` | `rgba(0,0,0,0.06)` | 分割线（亮色模式） |

---

## 暗黑模式设计原则

BeeCount 采用 **方案 D：纯黑背景 + 主题色边框** 的暗黑模式设计：

1. **全黑背景** (`#000000`) - OLED 友好，极简风格
2. **主题色点缀** - 通过边框展示用户个性化主题色
3. **视觉层次** - 使用不同深度的灰色区分层级：
   - 页面背景：`#000000`
   - 卡片背景：`#1C1C1E`
   - 悬浮卡片：`#2C2C2E`
   - 弹出层卡片：`#3A3A3C`
   - 分类图标：`#48484A`
4. **去除分割线** - 暗黑模式下卡片内不显示分割线
5. **主题色边框** - 卡片使用主题色 30% 透明度边框

---

## 迁移检查清单

在替换颜色时，请按以下顺序检查：

- [ ] `Scaffold.backgroundColor` → `BeeTokens.scaffoldBackground(context)`
- [ ] 卡片/容器背景 → `BeeTokens.surface(context)`
- [ ] BottomSheet 背景 → `BeeTokens.surfaceSheet(context)`
- [ ] 键盘按钮背景 → `BeeTokens.surfaceKey(context)` / `surfaceKeySecondary(context)`
- [ ] 输入框背景 → `BeeTokens.surfaceInput(context)`
- [ ] Chip/标签背景 → `BeeTokens.surfaceChip(context)`
- [ ] 文字颜色 → `textPrimary` / `textSecondary` / `textTertiary`
- [ ] 图标颜色 → `iconPrimary` / `iconSecondary` / `iconTertiary`
- [ ] 分割线 → 使用 `BeeTokens.cardDivider(context)`
- [ ] 状态颜色 → `success` / `warning` / `error` / `info`
- [ ] 品牌图标 → `brandLocal` / `brandSupabase` / `brandWebdav` / `brandCloud`

