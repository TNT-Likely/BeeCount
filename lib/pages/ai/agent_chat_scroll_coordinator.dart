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

  void onContentLaidOut({required bool targetReady}) {
    if (!_pending || !targetReady) return;
    // Message persistence is observed while the replacement ListView is
    // building. Wait for that same frame to compute its updated extent.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollIfReady());
  }

  void _scrollIfReady() {
    if (!_pending ||
        !controller.hasClients ||
        !controller.position.hasContentDimensions) {
      return;
    }
    _pending = false;
    final target = controller.position.maxScrollExtent;
    if ((controller.position.pixels - target).abs() < 0.5) return;
    controller.jumpTo(target);
  }
}
