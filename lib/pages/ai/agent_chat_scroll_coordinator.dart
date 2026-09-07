import 'dart:async';

import 'package:flutter/material.dart';

/// Coordinates a response scroll with the message stream's layout.
///
/// A persisted assistant message can arrive in a later frame than the state
/// change that removes the live preview. Callers keep the request pending until
/// that target row is present, then this class reads the final extent after
/// layout instead of relying on a fixed delay.
final class AgentChatScrollCoordinator {
  AgentChatScrollCoordinator(this.controller);

  static const _initialRetryInterval = Duration(milliseconds: 120);
  static const _initialRetryTimeout = Duration(seconds: 3);
  static const _initialStabilityWindow = Duration(seconds: 2);

  final ScrollController controller;
  bool _pending = false;
  bool _frameScheduled = false;
  bool _disposed = false;
  bool _initialPositioningRequested = false;
  int _initialRetryFramesRemaining = 0;
  Timer? _initialRetryTimer;
  DateTime? _initialRetryDeadline;
  DateTime? _initialStabilityDeadline;

  void request() {
    _pending = true;
    _initialPositioningRequested = false;
    _initialStabilityDeadline = null;
    _cancelInitialRetry();
  }

  /// Requests the first visible position for an existing conversation.
  ///
  /// Kept separate from [request] so page code documents why it is scrolling:
  /// this is an initial history position, not a newly completed response.
  void requestInitialPositioning() {
    request();
    // A route can reach this point before its ListView attaches on a slower
    // device. Keep retrying until layout settles, with a short bounded
    // fallback window so a permanently empty/disposed list cannot poll.
    _initialPositioningRequested = true;
    _initialRetryFramesRemaining = 8;
    _initialRetryDeadline = DateTime.now().add(_initialRetryTimeout);
    _debug('已请求初始定位');
    _scheduleScrollAttempt();
  }

  /// Retries a pending request after the scrollable reports a new layout.
  ///
  /// A real device can attach a list before its message rows have produced a
  /// scroll range. Keeping the request pending lets a later metrics update
  /// position the same conversation once its content becomes scrollable.
  void onScrollMetricsChanged() {
    if (!_pending && !_isInitialStabilityActive) return;
    onContentLaidOut(targetReady: true);
  }

  void onContentLaidOut({required bool targetReady}) {
    if ((!_pending && !_isInitialStabilityActive) || !targetReady) return;
    // Message persistence is observed while the replacement ListView is
    // building. Wait for that same frame to compute its updated extent.
    _scheduleScrollAttempt();
  }

  void _scheduleScrollAttempt() {
    if (_disposed || _frameScheduled) return;
    _frameScheduled = true;
    // A post-frame callback alone is passive: if no other widget requests a
    // frame, it may wait indefinitely. Request the frame explicitly so both
    // the initial pass and metrics-driven corrections are deterministic.
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (_disposed) return;
      _scrollIfReady();
    });
  }

  void _scrollIfReady() {
    if (_disposed || (!_pending && !_isInitialStabilityActive)) return;
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

    final wasInitialPositioning = _initialPositioningRequested;
    _pending = false;
    _cancelInitialRetry();
    if (wasInitialPositioning) {
      _initialPositioningRequested = false;
      _initialStabilityDeadline = DateTime.now().add(_initialStabilityWindow);
    }

    if ((controller.position.pixels - target).abs() >= 0.5) {
      controller.jumpTo(target);
      _debug(
        '已定位到消息列表底部',
        offset: controller.position.pixels,
        maxScrollExtent: target,
      );
    }

    // Keep checking briefly after the first jump. A banner, inset change, or
    // a Markdown row that finishes measuring can increase maxScrollExtent
    // after the first successful layout.
    _scheduleInitialRetry();
  }

  void _scheduleInitialRetry() {
    // The delayed timer is only needed while the initial list is not ready.
    // Once the first extent exists, later extent changes are delivered through
    // ScrollMetricsNotification and handled by the stability window without
    // leaving a timer alive on an otherwise idle page.
    if (!_pending) return;
    final deadline = _initialRetryDeadline;
    if (deadline == null) return;

    if (_initialRetryFramesRemaining > 0) {
      _initialRetryFramesRemaining -= 1;
      _scheduleScrollAttempt();
    }

    if (_initialRetryTimer != null) return;

    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _debug('初始定位等待超时，保留当前滚动位置');
      _initialRetryDeadline = null;
      return;
    }

    final delay =
        remaining < _initialRetryInterval ? remaining : _initialRetryInterval;
    _initialRetryTimer = Timer(delay, () {
      _initialRetryTimer = null;
      if (_disposed || !_pending) return;
      _scheduleScrollAttempt();
    });
  }

  void _cancelInitialRetry() {
    _initialRetryTimer?.cancel();
    _initialRetryTimer = null;
    _initialRetryDeadline = null;
  }

  bool get _isInitialStabilityActive {
    final deadline = _initialStabilityDeadline;
    return deadline != null && DateTime.now().isBefore(deadline);
  }

  /// Releases the fallback timer when the chat page is disposed.
  void dispose() {
    _disposed = true;
    _pending = false;
    _initialStabilityDeadline = null;
    _cancelInitialRetry();
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
