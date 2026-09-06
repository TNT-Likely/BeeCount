import 'package:flutter/material.dart';

/// Coordinates a response scroll with the message stream's layout.
///
/// A persisted assistant message can arrive in a later frame than the state
/// change that removes the live preview. Callers keep the request pending until
/// that target row is present, then this class reads the final extent after
/// layout instead of relying on a fixed delay.
final class AgentChatScrollCoordinator {
  AgentChatScrollCoordinator(this.controller);

  final ScrollController controller;
  bool _pending = false;
  bool _frameScheduled = false;
  int _initialRetryFramesRemaining = 0;

  void request() {
    _pending = true;
  }

  /// Requests the first visible position for an existing conversation.
  ///
  /// Kept separate from [request] so page code documents why it is scrolling:
  /// this is an initial history position, not a newly completed response.
  void requestInitialPositioning() {
    request();
    // A route can reach this point before its ListView attaches on a slower
    // device. Retry a bounded number of frames; later metrics changes remain
    // an independent retry path, so this never becomes a polling loop.
    _initialRetryFramesRemaining = 8;
    _debug('已请求初始定位');
    _scheduleScrollAttempt();
  }

  /// Retries a pending request after the scrollable reports a new layout.
  ///
  /// A real device can attach a list before its message rows have produced a
  /// scroll range. Keeping the request pending lets a later metrics update
  /// position the same conversation once its content becomes scrollable.
  void onScrollMetricsChanged() {
    if (!_pending) return;
    onContentLaidOut(targetReady: true);
  }

  void onContentLaidOut({required bool targetReady}) {
    if (!_pending || !targetReady) return;
    // Message persistence is observed while the replacement ListView is
    // building. Wait for that same frame to compute its updated extent.
    _scheduleScrollAttempt();
  }

  void _scheduleScrollAttempt() {
    if (_frameScheduled) return;
    _frameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      _scrollIfReady();
    });
  }

  void _scrollIfReady() {
    if (!_pending) return;
    if (!controller.hasClients || !controller.position.hasContentDimensions) {
      _debug(
        '等待消息列表挂载或完成布局',
        hasClients: controller.hasClients,
        hasContentDimensions: controller.hasClients
            ? controller.position.hasContentDimensions
            : false,
      );
      _scheduleInitialRetry();
      return;
    }

    final target = controller.position.maxScrollExtent;
    if (target <= 0) {
      _debug(
        '消息列表暂未形成滚动范围，保持待定位状态',
        offset: controller.position.pixels,
        maxScrollExtent: target,
      );
      _scheduleInitialRetry();
      return;
    }

    _pending = false;
    _initialRetryFramesRemaining = 0;
    if ((controller.position.pixels - target).abs() < 0.5) return;
    controller.jumpTo(target);
    _debug(
      '已定位到消息列表底部',
      offset: controller.position.pixels,
      maxScrollExtent: target,
    );
  }

  void _scheduleInitialRetry() {
    if (_initialRetryFramesRemaining <= 0) return;
    _initialRetryFramesRemaining -= 1;
    _scheduleScrollAttempt();
  }

  void _debug(
    String message, {
    bool? hasClients,
    bool? hasContentDimensions,
    double? offset,
    double? maxScrollExtent,
  }) {
    final data = <String, Object?>{
      if (hasClients != null) 'hasClients': hasClients,
      if (hasContentDimensions != null)
        'hasContentDimensions': hasContentDimensions,
      if (offset != null) 'offset': offset,
      if (maxScrollExtent != null) 'maxScrollExtent': maxScrollExtent,
    };
    debugPrint('[AIChatScroll] $message | Data: $data');
  }
}
