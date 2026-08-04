import 'dart:convert';

import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/share/app_link_model.dart';
import 'package:onexray/service/share/app_link_parser.dart';
import 'package:onexray/service/subscription/model.dart';

enum _SubscriptionAgeMode { none, x25519, hybrid, invalid }

abstract final class OneXrayAppLinkGenerator {
  static Uri? config(CoreConfigData config) {
    final type = switch (CoreConfigType.fromString(config.type)) {
      CoreConfigType.outbound => OneXrayConfigLinkType.outbound,
      CoreConfigType.profile => OneXrayConfigLinkType.profile,
      CoreConfigType.full => OneXrayConfigLinkType.full,
      CoreConfigType.raw => OneXrayConfigLinkType.raw,
      null => null,
    };
    final data = config.data?.trim();
    if (type == null || data == null || data.isEmpty) {
      return null;
    }

    return _verified(
      Uri(
        scheme: OneXrayAppLinkParser.scheme,
        host: OneXrayAppLinkParser.host,
        path: OneXrayAppLinkParser.configPath,
        queryParameters: {'type': type.name, 'data': data},
        fragment: config.name,
      ),
    );
  }

  static Uri? subscription(SubscriptionData subscription) {
    final url = SubscriptionUrl.normalize(subscription.url);
    final ageMode = _subscriptionAgeMode(subscription);
    if (ageMode == _SubscriptionAgeMode.invalid) {
      return null;
    }
    final ageType = switch (ageMode) {
      _SubscriptionAgeMode.x25519 => 'x25519',
      _SubscriptionAgeMode.hybrid => 'hybrid',
      _SubscriptionAgeMode.none || _SubscriptionAgeMode.invalid => null,
    };

    return _verified(
      Uri(
        scheme: OneXrayAppLinkParser.scheme,
        host: OneXrayAppLinkParser.host,
        path: OneXrayAppLinkParser.subscriptionPath,
        queryParameters: {'url': url, 'age': ?ageType},
        fragment: subscription.name,
      ),
    );
  }

  static Uri? geoData(GeoDataData geoData) {
    final type = GeoDataType.fromString(geoData.type);
    if (type == null) {
      return null;
    }

    return _verified(
      Uri(
        scheme: OneXrayAppLinkParser.scheme,
        host: OneXrayAppLinkParser.host,
        path: OneXrayAppLinkParser.geoDataPath,
        queryParameters: {'type': type.name, 'url': geoData.url},
        fragment: geoData.name,
      ),
    );
  }

  static Set<String> referencedGeoDataNames(CoreConfigData config) {
    final data = config.data?.trim();
    if (data == null || data.isEmpty) {
      return const <String>{};
    }

    try {
      final text = utf8.decode(base64Decode(data));
      final decoded = JsonTool.decoder.convert(text);
      if (decoded is! Map<String, dynamic>) {
        return const <String>{};
      }
      final names = <String>{};
      _collectRoutingGeoDataNames(decoded, names);
      _collectDnsGeoDataNames(decoded, names);
      return names;
    } catch (_) {
      return const <String>{};
    }
  }

  static _SubscriptionAgeMode _subscriptionAgeMode(
    SubscriptionData subscription,
  ) {
    final secretKey = subscription.ageSecretKey?.trim() ?? '';
    final publicKey = subscription.agePublicKey?.trim() ?? '';
    if (secretKey.isEmpty && publicKey.isEmpty) {
      return _SubscriptionAgeMode.none;
    }
    if (secretKey.isEmpty || publicKey.isEmpty) {
      return _SubscriptionAgeMode.invalid;
    }
    if (secretKey.startsWith('AGE-SECRET-KEY-PQ-1')) {
      return _SubscriptionAgeMode.hybrid;
    }
    if (secretKey.startsWith('AGE-SECRET-KEY-1')) {
      return _SubscriptionAgeMode.x25519;
    }
    return _SubscriptionAgeMode.invalid;
  }

  static Uri? _verified(Uri uri) {
    return OneXrayAppLinkParser.parse(uri) == null ? null : uri;
  }

  static void _collectGeoDataNames(Iterable<String>? rules, Set<String> names) {
    for (final rule in rules ?? const <String>[]) {
      final match = RegExp(r'^ext:([^:]+\.dat):.+$').firstMatch(rule);
      final fileName = match?.group(1);
      if (fileName == null || fileName.length <= 4) {
        continue;
      }
      names.add(fileName.substring(0, fileName.length - 4));
    }
  }

  static void _collectRoutingGeoDataNames(
    Map<String, dynamic> json,
    Set<String> names,
  ) {
    final routing = json['routing'];
    if (routing is! Map<String, dynamic>) {
      return;
    }
    final rules = routing['rules'];
    if (rules is! List) {
      return;
    }
    for (final Object? value in rules) {
      if (value is! Map<String, dynamic>) {
        continue;
      }
      try {
        final rule = XrayRoutingRule.fromJson(value);
        _collectGeoDataNames(rule.domain, names);
        _collectGeoDataNames(rule.ip, names);
      } catch (_) {
        continue;
      }
    }
  }

  static void _collectDnsGeoDataNames(
    Map<String, dynamic> json,
    Set<String> names,
  ) {
    final dns = json['dns'];
    if (dns is! Map<String, dynamic>) {
      return;
    }
    final servers = dns['servers'];
    if (servers is! List) {
      return;
    }
    for (final Object? value in servers) {
      if (value is! Map<String, dynamic>) {
        continue;
      }
      try {
        final server = XrayDnsServer.fromJson(value);
        _collectGeoDataNames(server.domains, names);
        _collectGeoDataNames(server.expectedIPs, names);
      } catch (_) {
        continue;
      }
    }
  }
}
