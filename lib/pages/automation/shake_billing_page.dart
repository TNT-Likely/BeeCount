import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/ui/primary_header.dart';
import '../../widgets/ui/toast.dart';

import '../../providers.dart';
import '../../services/platform/shake_billing_service.dart';
import '../../l10n/app_localizations.dart';

/// 摇一摇自动记账设置页面
class ShakeBillingPage extends ConsumerStatefulWidget {
  const ShakeBillingPage({super.key});

  @override
  ConsumerState<ShakeBillingPage> createState() => _ShakeBillingPageState();
}

class _ShakeBillingPageState extends ConsumerState<ShakeBillingPage> with WidgetsBindingObserver {
  late final ShakeBillingService _shakeBilling;
  bool _isShakeBillingEnabled = false;
  bool _isAccessibilityServiceEnabled = false;
  bool _isLoading = true;
  bool _isInitialized = false;

  /// 保活综合状态（由 Kotlin 端返回）
  Map<String, dynamic> _keepAliveStatus = {};

  /// 摇一摇记账结果通知渠道信息
  Map<String, dynamic> _shakeResultChannelInfo = {};

  /// 通知渠道是否满足横幅弹窗条件
  bool get _notifChannelOk =>
      _shakeResultChannelInfo['isEnabled'] == true &&
      (_shakeResultChannelInfo['importance'] == 'high' ||
       _shakeResultChannelInfo['importance'] == 'max');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final container = ProviderScope.containerOf(context);
      _shakeBilling = ShakeBillingService(container);
      _loadMonitorStatus();
      _isInitialized = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _loadMonitorStatus();
    }
  }

  Future<void> _loadMonitorStatus() async {
    final shakeEnabled = await _shakeBilling.isShakeBillingEnabled();

    bool accessibilityEnabled = false;
    try {
      accessibilityEnabled = await _shakeBilling.checkAccessibilityServiceEnabled();
    } catch (e) {
      print('检查无障碍服务状态失败: $e');
    }

    Map<String, dynamic> keepAliveStatus = {};
    try {
      keepAliveStatus = await _shakeBilling.getKeepAliveStatus();
    } catch (e) {
      print('查询保活状态失败: $e');
    }

    // 查询摇一摇记账结果通知渠道信息
    Map<String, dynamic> channelInfo = {};
    try {
      channelInfo = await _shakeBilling.getNotificationChannelInfo('shake_result');
      print('📢 通知渠道 shake_result: $channelInfo');
    } catch (e) {
      print('查询通知渠道信息失败: $e');
    }

    setState(() {
      _isShakeBillingEnabled = shakeEnabled;
      _isAccessibilityServiceEnabled = accessibilityEnabled;
      _keepAliveStatus = keepAliveStatus;
      _shakeResultChannelInfo = channelInfo;
      _isLoading = false;
    });
  }

  Future<void> _toggleShakeBilling(bool value) async {
    final l10n = AppLocalizations.of(context);

    try {
      if (value) {
        await _shakeBilling.enableShakeBilling();
        setState(() => _isShakeBillingEnabled = true);
        if (mounted) showToast(context, l10n.enableSuccess);

        final enabled = await _shakeBilling.checkAccessibilityServiceEnabled();
        setState(() => _isAccessibilityServiceEnabled = enabled);

        _loadMonitorStatus();

        if (!enabled && mounted) {
          showToast(context, '请前往系统设置 - 无障碍 - 已安装的应用 - 蜜蜂记账，开启摇一摇自动记账服务', duration: const Duration(seconds: 4));
        }
      } else {
        await _shakeBilling.disableShakeBilling();
        setState(() => _isShakeBillingEnabled = false);
        _loadMonitorStatus();
        if (mounted) showToast(context, l10n.disableSuccess);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, '${l10n.enableFailed}: $e', duration: const Duration(seconds: 3));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = ref.watch(primaryColorProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          PrimaryHeader(
            title: '摇一摇自动记账',
            showBack: true,
            leadingIcon: Icons.sensors,
            leadingPlain: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── 功能介绍 ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: primaryColor, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              '功能介绍',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '摇动手机，通过无障碍服务截取当前屏幕，自动识别账单信息并完成记账。\n\n'
                              '• 摇动手机即可触发自动记账\n'
                              '• 所有版本均可用（包括 Google Play 版）\n'
                              '• 需开启无障碍服务权限',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── 摇动示例图 ──
                _ShakeGuideIllustration(),

                const SizedBox(height: 20),

                // ── 摇一摇自动记账开关 ──
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    '摇一摇自动记账',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.sensors, color: primaryColor, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '摇一摇自动记账',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isShakeBillingEnabled
                                    ? (_isAccessibilityServiceEnabled ? '已开启' : '已开启（无障碍未授权）')
                                    : '已关闭',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _isShakeBillingEnabled
                                      ? primaryColor
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isShakeBillingEnabled,
                          onChanged: _isLoading ? null : _toggleShakeBilling,
                        ),
                      ],
                    ),
                  ),
                ),

                // 无障碍服务引导卡片
                if (_isShakeBillingEnabled && !_isAccessibilityServiceEnabled) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.orange.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.accessibility_new, color: Colors.orange, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                '需要无障碍服务权限',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '启用摇一摇自动记账需要在系统无障碍设置中开启「蜜蜂记账」服务。\n\n'
                            '操作步骤：\n'
                            '1. 点击下方按钮打开无障碍设置\n'
                            '2. 找到「已安装的应用」或「已安装服务」\n'
                            '3. 点击「蜜蜂记账」\n'
                            '4. 打开服务开关并确认启用',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () async {
                                await _shakeBilling.openAccessibilitySettings();
                                await Future.delayed(const Duration(seconds: 1));
                                if (mounted) {
                                  final enabled = await _shakeBilling.checkAccessibilityServiceEnabled();
                                  setState(() => _isAccessibilityServiceEnabled = enabled);
                                }
                              },
                              icon: const Icon(Icons.settings),
                              label: const Text('打开无障碍设置'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── 后台保活状态 ──
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    '后台保活',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
                if (_isShakeBillingEnabled)
                  _buildKeepAliveStatusCard(context, primaryColor, l10n)
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.shield_outlined, color: Colors.grey, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '保活服务已关闭',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '开启摇一摇自动记账后自动启用保活，无需手动操作',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeepAliveStatusCard(
    BuildContext context,
    Color primaryColor,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final batteryOpt = _keepAliveStatus['isIgnoringBatteryOptimizations'] == true;
    final accessibilityRunning = _keepAliveStatus['accessibilityServiceRunning'] == true;
    final keepAliveRunning = _keepAliveStatus['keepAliveServiceRunning'] == true;

    final importance = _shakeResultChannelInfo['importance'] as String? ?? '';
    final notifChannelDescription = _notifChannelOk
        ? '渠道重要性 $importance，可弹出横幅通知'
        : '重要性 $importance，需设为高才能弹出横幅通知';

    final healthItems = <_HealthItem>[
      _HealthItem(
        icon: Icons.accessible,
        label: '无障碍服务',
        description: '系统级权限，后台常驻不被系统杀死',
        ok: accessibilityRunning,
        okText: '运行中',
        failText: '未运行',
      ),
      _HealthItem(
        icon: Icons.battery_std,
        label: '电池优化',
        description: '豁免后系统不会在后台限制应用活动',
        ok: batteryOpt,
        okText: '已豁免',
        failText: '未优化',
      ),
      _HealthItem(
        icon: Icons.shield,
        label: '保活前台服务',
        description: '前台通知保活，关闭摇一摇后自动停止',
        ok: keepAliveRunning,
        okText: '运行中',
        failText: '未运行',
      ),
      _HealthItem(
        icon: Icons.notifications_active,
        label: '记账结果横幅',
        description: notifChannelDescription,
        ok: _notifChannelOk,
        okText: '已开启',
        failText: '需设置',
      ),
    ];

    final okCount = healthItems.where((e) => e.ok).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (okCount == healthItems.length ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    okCount == healthItems.length ? Icons.shield : Icons.shield_outlined,
                    color: okCount == healthItems.length ? Colors.green : Colors.orange,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '保活健康度 $okCount/${healthItems.length}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        okCount == healthItems.length
                            ? '所有保活机制运行正常'
                            : '部分保活项未就绪，建议优化',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: okCount == healthItems.length ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Health status list
                ...healthItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(item.icon, size: 20, color: item.ok ? Colors.green : Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.label, style: theme.textTheme.bodyMedium),
                            Text(
                              item.description,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (item.ok ? Colors.green : Colors.grey).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.ok ? item.okText : item.failText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: item.ok ? Colors.green : Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            // 通知横幅设置引导
            if (!_notifChannelOk) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _shakeBilling.openNotificationChannelSettings('shake_result');
                    await Future.delayed(const Duration(seconds: 2));
                    _loadMonitorStatus();
                  },
                  icon: const Icon(Icons.notifications, size: 18),
                  label: const Text('前往通知设置，开启横幅通知'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '部分手机默认关闭横幅通知，需手动开启。请进入「通知」→「摇一摇记账结果」→ 打开「通知横幅/悬浮通知」',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange[700],
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            // Action buttons for non-optimized items
            if (!batteryOpt) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _shakeBilling.openBatteryOptimizationSettings();
                  },
                  icon: const Icon(Icons.battery_std, size: 18),
                  label: const Text('前往电池优化设置'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                  ),
                ),
              ),
            ],
            if (!accessibilityRunning) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _shakeBilling.openAccessibilitySettings();
                  },
                  icon: const Icon(Icons.accessibility_new, size: 18),
                  label: const Text('前往无障碍设置'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final opened = await _shakeBilling.openAutoStartSettings();
                  if (!opened && context.mounted) {
                    _showAutoStartGuideDialog(context);
                  }
                },
                icon: const Icon(Icons.power_settings_new, size: 18),
                label: const Text('自启动管理'),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '无法自动检测自启动状态，不同手机路径不同：设置 → 应用管理 → BeeCount → 自启动',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '保活前台服务会在通知栏显示一条静默通知，保持应用在后台不被系统清理。开启摇一摇自动记账后自动启用，关闭后自动停止，无需手动操作。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.blue[700],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 自启动引导弹窗
Future<void> _showAutoStartGuideDialog(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('开启自启动'),
      content: const Text(
        '当前设备不支持自动跳转，请手动操作：\n\n'
        '1. 打开手机「设置」\n'
        '2. 进入「应用管理」或「应用设置」\n'
        '3. 找到「BeeCount」\n'
        '4. 开启「自启动」或「允许自启动」权限\n\n'
        '开启后保活服务更稳定，不会被系统后台清理。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

/// 摇动手机示例图 — 带动画提示如何摇手机
class _ShakeGuideIllustration extends StatefulWidget {
  @override
  State<_ShakeGuideIllustration> createState() => _ShakeGuideIllustrationState();
}

class _ShakeGuideIllustrationState extends State<_ShakeGuideIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _shakeAnim = Tween<double>(begin: -16.0, end: 16.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    // 运动轨迹点 — 显示在手机左右两侧的短线
    Widget _trailDots({required bool left}) {
      return AnimatedBuilder(
        animation: _shakeAnim,
        builder: (_, __) {
          final progress = (_shakeAnim.value + 16) / 32; // 0→1
          final opacity = left ? (1 - progress) : progress;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final dotOpacity = ((left ? (2 - i) : i) / 2.0 * opacity)
                  .clamp(0.0, 0.7);
              return Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: dotOpacity),
                  shape: BoxShape.circle,
                ),
              );
            }),
          );
        },
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primaryColor.withValues(alpha: 0.15)),
      ),
      color: primaryColor.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 动画手机 + 轨迹点
            SizedBox(
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 左侧轨迹点
                  Positioned(left: 0, child: _trailDots(left: true)),
                  // 右侧轨迹点
                  Positioned(right: 0, child: _trailDots(left: false)),
                  // 手机图标 — 左右平移 + 轻微摆头模拟手腕弧线
                  AnimatedBuilder(
                    animation: _shakeAnim,
                    builder: (_, __) => Transform.translate(
                      offset: Offset(_shakeAnim.value, 0),
                      child: Transform.rotate(
                        angle: _shakeAnim.value * 0.012,
                        child: Icon(Icons.phone_android,
                            color: primaryColor, size: 48),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '握住手机两侧，以手腕为轴快速摇动 5~6 次',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 保活健康项数据模型
class _HealthItem {
  final IconData icon;
  final String label;

  /// 简短说明（如"前台通知保活，关闭摇一摇后自动停止"）
  final String description;

  final bool ok;
  final String okText;
  final String failText;

  _HealthItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.ok,
    required this.okText,
    required this.failText,
  });
}
