import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/core/tools/platform.dart';

final class NotificationService {
  static final NotificationService _singleton = NotificationService._internal();

  factory NotificationService() => _singleton;

  NotificationService._internal();

  //==========================
  final _localNotification = FlutterLocalNotificationsPlugin();

  Future<void> asyncInit() async {
    const initializationSettingsAndroid = AndroidInitializationSettings(
      'ic_launcher',
    );
    final initializationSettingsDarwin = DarwinInitializationSettings();
    final initializationSettingsLinux = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );
    final WindowsInitializationSettings initializationSettingsWindows =
        WindowsInitializationSettings(
          appName: 'OneXray',
          appUserModelId: 'net.yuandev.onexray',
          // Search online for GUID generators to make your own
          guid: '835d7bbd-85bb-4c73-97f8-ce0740f151a7',
        );
    final initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux,
      windows: initializationSettingsWindows,
    );
    await _localNotification.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onReceiveNotification,
    );

    if (AppPlatform.isAndroid) {
      await _localNotification
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  void dispose() {}

  Future<void> _onReceiveNotification(
    NotificationResponse notificationResponse,
  ) async {
    final payload = notificationResponse.payload;
    if (payload != null) {
      ygLogger(payload);
    }
  }

  Future<void> pushNotification(String message) async {
    if (AppPlatform.isAndroid) {
      await _pushAndroidNotification(message);
    } else {
      await _localNotification.show(id: 0, title: message);
    }
  }

  Future<void> _pushAndroidNotification(String message) async {
    const androidNotificationDetails = AndroidNotificationDetails(
      'net.yuandev.onexray',
      'OneXray',
      channelDescription: 'OneXray',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ticker: 'OneXray',
    );
    const notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );
    await _localNotification.show(
      id: 0,
      title: message,
      body: null,
      notificationDetails: notificationDetails,
    );
  }
}
