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

  void onContentLaidOut({required bool targetReady}) {
    if (!_pending || !targetReady) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pending) return;
      // The list can still be detached while the message provider is
      // transitioning. Keep the request pending; the next data build will
      // call us again once a scrollable exists.
      if (!controller.hasClients) return;
      if (!controller.position.hasContentDimensions) {
        onContentLaidOut(targetReady: true);
        return;
      }
      _pending = false;
      final target = controller.position.maxScrollExtent;
      if ((controller.position.pixels - target).abs() < 0.5) return;
      controller.jumpTo(target);
    });
  }
}
