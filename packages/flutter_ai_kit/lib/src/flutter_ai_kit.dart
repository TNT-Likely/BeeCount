import 'dart:async';
import 'dart:io';

import 'core/ai_provider.dart';
import 'core/ai_task.dart';
import 'core/ai_result.dart';
import 'core/ai_execution_context.dart';
import 'strategies/ai_execution_strategy.dart';
import 'strategies/local_first_strategy.dart';

/// Flutter AI Kit 核心类
///
/// 示例:
/// ```dart
/// final aiKit = FlutterAIKit();
///
/// // 注册Provider
/// aiKit.registerProvider(MyLocalProvider());
/// aiKit.registerProvider(MyCloudProvider());
///
/// // 设置策略
/// aiKit.setStrategy(LocalFirstStrategy());
///
/// // 执行任务
/// final result = await aiKit.execute(myTask);
/// ```
class FlutterAIKit {
  final List<AIProvider> _providers = [];
  AIExecutionStrategy _strategy = const LocalFirstStrategy();

  /// 注册Provider
  void registerProvider(AIProvider provider) {
    // 检查是否已存在相同ID的Provider
    final existingIndex = _providers.indexWhere((p) => p.id == provider.id);
    if (existingIndex != -1) {
      // 替换已存在的Provider
      _providers[existingIndex] = provider;
    } else {
      _providers.add(provider);
    }
  }

  /// 注销Provider
  void unregisterProvider(String providerId) {
    _providers.removeWhere((p) => p.id == providerId);
  }

  /// 清空所有Provider
  void clearProviders() {
    _providers.clear();
  }

  /// 设置执行策略
  void setStrategy(AIExecutionStrategy strategy) {
    _strategy = strategy;
  }

  /// 获取所有已注册的Provider
  List<AIProvider> get providers => List.unmodifiable(_providers);

  /// 获取当前执行策略
  AIExecutionStrategy get strategy => _strategy;

  /// 执行AI任务
  ///
  /// [task] 要执行的任务
  /// [context] 执行上下文（可选，默认自动检测网络）
  ///
  /// 返回 [AIResult] 包含执行结果或错误信息
  Future<AIResult<TOutput>> execute<TInput, TOutput>(
    AITask<TInput, TOutput> task, {
    AIExecutionContext? context,
  }) async {
    // 使用提供的context或创建默认context
    final ctx = context ??
        AIExecutionContext(
          hasNetwork: await _checkNetwork(),
        );

    // 1. 使用策略选择Provider执行顺序
    final selectedProviders = await _strategy.selectProviders(
      _providers,
      task,
      ctx,
    );

    if (selectedProviders.isEmpty) {
      return AIResult.failure(
        'No available provider for task: ${task.taskType}',
        Duration.zero,
      );
    }

    // 2. 按顺序尝试执行
    AIResult<TOutput>? lastResult;

    for (final provider in selectedProviders) {
      print('🚀 [FlutterAIKit] Trying provider: ${provider.name}');

      try {
        // 执行任务（带超时）
        final result =
            await provider.execute(task as AITask<dynamic, dynamic>).timeout(
                  ctx.timeout ?? const Duration(seconds: 30),
                ) as AIResult<TOutput>;

        if (result.success) {
          print(
              '✅ [FlutterAIKit] Success with ${provider.name} in ${result.duration.inMilliseconds}ms');
          return result;
        }

        lastResult = result;
        print('⚠️ [FlutterAIKit] ${provider.name} failed: ${result.error}');
      } on TimeoutException {
        lastResult = AIResult.failure(
          'Provider timeout after ${ctx.timeout?.inSeconds ?? 30}s',
          ctx.timeout ?? const Duration(seconds: 30),
          metadata: AIResultMetadata(providerName: provider.name),
        );
        print('⏱️ [FlutterAIKit] ${provider.name} timed out');
      } catch (e) {
        lastResult = AIResult.failure(
          e.toString(),
          Duration.zero,
          metadata: AIResultMetadata(providerName: provider.name),
        );
        print('❌ [FlutterAIKit] ${provider.name} threw exception: $e');
      }
    }

    // 3. 所有Provider都失败
    return lastResult ??
        AIResult.failure(
          'All providers failed',
          Duration.zero,
        );
  }

  /// 检查网络连接
  Future<bool> _checkNetwork() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
