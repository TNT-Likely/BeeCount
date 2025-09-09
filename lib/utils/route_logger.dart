import 'package:flutter/widgets.dart';
import 'logger.dart';

class LoggingNavigatorObserver extends NavigatorObserver {
  String _name(Route<dynamic>? r) => r?.settings.name ?? r.toString();

  @override
  void didPush(Route route, Route? previousRoute) {
    logI('nav', 'push -> ${_name(route)} (from ${_name(previousRoute)})');
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    logI('nav', 'pop  -> ${_name(route)} (to ${_name(previousRoute)})');
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    logI('nav', 'remove -> ${_name(route)}');
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    logI('nav', 'replace ${_name(oldRoute)} -> ${_name(newRoute)}');
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
