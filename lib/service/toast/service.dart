import 'dart:async';

class ToastService {
  static final ToastService _singleton = ToastService._internal();
  factory ToastService() => _singleton;
  ToastService._internal();

  //==========================
  void init() {}
  void dispose() {
    toastBroadcast.close();
  }

  final toastBroadcast = StreamController<String>.broadcast();
  void showToast(String message) {
    toastBroadcast.add(message);
  }

  //==========================
}
