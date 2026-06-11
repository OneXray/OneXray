import 'dart:async';

import 'package:onexray/service/data_update/service.dart';

class BackgroundTaskService {
  static final BackgroundTaskService _singleton =
      BackgroundTaskService._internal();

  factory BackgroundTaskService() => _singleton;

  BackgroundTaskService._internal();

  //==========================
  Timer? _timer;

  Future<void> asyncInit() async {
    if (_timer != null) {
      return;
    }
    final interval = const Duration(hours: 1);
    _timer = Timer.periodic(interval, (_) => checkDataUpdate());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> checkDataUpdate() async {
    await DataUpdateService().checkAndRun();
  }
}
