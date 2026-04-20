import 'package:collection/collection.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/model/ping_json.dart';
import 'package:onexray/core/tools/empty.dart';

enum PingUrl {
  cloudflare("Cloudflare", "https://cp.cloudflare.com/"),
  google("Google", "https://www.google.com/generate_204"),
  apple("Apple", "https://www.apple.com/library/test/success.html"),
  custom("Custom", "");

  const PingUrl(this.name, this.url);

  final String name;
  final String url;

  @override
  String toString() => name;

  static PingUrl? fromString(String name) =>
      PingUrl.values.firstWhereOrNull((value) => value.name == name);

  static List<String> get names {
    return PingUrl.values.map((e) => e.name).toList();
  }
}

class PingTimeout {
  static const min = 3.0;
  static const max = 8.0;
  static const divisions = 5;
  static const defaultValue = 5.0;
}

class PingConcurrency {
  static const min = 1.0;
  static const max = 5.0;
  static const divisions = 4;
  static const defaultValue = 3.0;
}

class PingState {
  var timeout = PingTimeout.defaultValue;
  var concurrency = PingConcurrency.defaultValue;
  var url = PingUrl.cloudflare;
  var customUrl = "";

  String get realUrl {
    if (url == PingUrl.custom) {
      return customUrl;
    } else {
      return url.url;
    }
  }

  Future<void> readFromPreferences() async {
    final jsonMap = await PreferencesKey().readPingState();
    if (!EmptyTool.checkMap(jsonMap)) {
      return;
    }
    final pingJson = PingJson.fromJson(jsonMap!);
    if (pingJson.timeout != null) {
      var timeout = pingJson.timeout!;
      if (timeout < PingTimeout.min) {
        timeout = PingTimeout.min;
      } else if (timeout > PingTimeout.max) {
        timeout = PingTimeout.max;
      }
      this.timeout = timeout;
    }
    if (pingJson.concurrency != null) {
      var concurrency = pingJson.concurrency!;
      if (concurrency < PingConcurrency.min) {
        concurrency = PingConcurrency.min;
      } else if (concurrency > PingConcurrency.max) {
        concurrency = PingConcurrency.max;
      }
      this.concurrency = concurrency;
    }
    if (EmptyTool.checkString(pingJson.url)) {
      final url = PingUrl.fromString(pingJson.url!);
      if (url != null) {
        this.url = url;
      }
    }
    if (EmptyTool.checkString(pingJson.customUrl)) {
      customUrl = pingJson.customUrl!;
    }
  }

  Future<void> saveToPreferences() async {
    final pingJson = PingJson(timeout, concurrency, url.name, customUrl);
    await PreferencesKey().savePingState(pingJson.toJson());
  }
}
