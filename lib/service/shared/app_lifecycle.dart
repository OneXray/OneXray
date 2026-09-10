import 'package:flutter/widgets.dart' show AppLifecycleState;

/// An inactive view is still visible; losing input focus is not hiding the app.
bool isAppVisible(AppLifecycleState? state) => switch (state) {
  null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
  AppLifecycleState.hidden ||
  AppLifecycleState.paused ||
  AppLifecycleState.detached => false,
};
