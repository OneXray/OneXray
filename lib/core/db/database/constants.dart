class DBConstants {
  static const defaultId = 0;
}

class PingDelayConstants {
  static const unknown = 9000;
  static const error = 10000;
  static const timeout = 11000;

  static bool isSuccessful(int delay) =>
      delay >= 0 && delay != unknown && delay != error && delay != timeout;
}
