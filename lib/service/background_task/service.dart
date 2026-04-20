import 'dart:async';

import 'package:onexray/service/subscription/service.dart';

class BackgroundTaskService {
  static final BackgroundTaskService _singleton =
      BackgroundTaskService._internal();

  factory BackgroundTaskService() => _singleton;

  BackgroundTaskService._internal();

  //==========================
  Timer? _timer;

  Future<void> asyncInit() async {
    final interval = const Duration(hours: 1);
    _timer = Timer.periodic(interval, (_) => checkSubscriptionUpdate());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> checkSubscriptionUpdate() async {
    await SubscriptionService().refreshOutdatedSubscription();
  }
}
