import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/navigation/app_route_observer.dart';

mixin RouteRefreshMixin<T extends ConsumerStatefulWidget> on ConsumerState<T>
    implements RouteAware {
  ModalRoute<dynamic>? _route;

  void refreshRouteData();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route == route || route == null) return;

    if (_route != null) {
      appRouteObserver.unsubscribe(this);
    }

    _route = route;
    appRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    refreshRouteData();
  }

  @override
  void didPop() {}

  @override
  void didPush() {}

  @override
  void didPushNext() {}
}
