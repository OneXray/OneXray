/// Local automation credentials are device preferences, never connection data.
final class LocalApiSettings {
  static const defaultPort = 18587;

  final bool enabled;
  final int port;
  final String token;

  const LocalApiSettings({
    this.enabled = false,
    this.port = defaultPort,
    this.token = '',
  });

  String get endpoint => 'http://127.0.0.1:$port';

  factory LocalApiSettings.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'];
    final port = json['port'];
    final token = json['token'];
    if (enabled is! bool ||
        port is! int ||
        port < 1024 ||
        port > 65535 ||
        token is! String ||
        (token.isNotEmpty && !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) ||
        (enabled && token.isEmpty)) {
      throw const FormatException('Invalid local API settings');
    }
    return LocalApiSettings(enabled: enabled, port: port, token: token);
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'port': port,
    'token': token,
  };
}
