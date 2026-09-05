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

  void request() {
    _pending = true;
  }

  /// Requests the first visible position for an existing conversation.
  ///
  /// Kept separate from [request] so page code documents why it is scrolling:
  /// this is an initial history position, not a newly completed response.
  void requestInitialPositioning() {
    request();
    // This is called while the first ListView is being built. A single
    // post-frame attempt runs after that ListView has attached and calculated
    // its extent. Do not nest another post-frame callback here: an initial
    // route can otherwise have no subsequent frame to flush it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollIfReady());
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollIfReady());
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
      return;
    }

    final target = controller.position.maxScrollExtent;
    if (target <= 0) {
      _debug(
        '消息列表暂未形成滚动范围，保持待定位状态',
        offset: controller.position.pixels,
        maxScrollExtent: target,
      );
      return;
    }

    _pending = false;
    if ((controller.position.pixels - target).abs() < 0.5) return;
    controller.jumpTo(target);
    _debug(
      '已定位到消息列表底部',
      offset: controller.position.pixels,
      maxScrollExtent: target,
    );
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
