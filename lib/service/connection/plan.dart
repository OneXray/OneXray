import 'dart:convert';

import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/connection/compiler.dart';
import 'package:onexray/service/connection/platform_policy.dart';
import 'package:onexray/service/connection/settings.dart';

/// One database value for all settings which can change a running connection.
class ConnectionConfiguration {
  final ConnectionSettings connection;
  final PlatformPolicy policy;

  ConnectionConfiguration({
    ConnectionSettings? connection,
    PlatformPolicy? policy,
  }) : connection = connection ?? ConnectionSettings(),
       policy = policy ?? PlatformPolicy.defaults();

  factory ConnectionConfiguration.fromJson(Map<String, dynamic> json) =>
      ConnectionConfiguration(
        connection: ConnectionSettings.fromJson(
          json['connection'] as Map<String, dynamic>? ?? {},
        ),
        policy: PlatformPolicy.fromJson(
          json['policy'] as Map<String, dynamic>? ?? {},
        ),
      );

  Map<String, dynamic> toJson() => {
    'connection': connection.toJson(),
    'policy': policy.toJson(),
  };
  String encode() => jsonEncode(toJson());
}

/// A frozen, private startup value. A later database edit cannot change it.
/// planId identifies this input; the native core creates a new sessionId on
/// every actual start, including Android tiles and Apple On Demand restarts.
class ConnectionPlan {
  final String _json;

  ConnectionPlan._(Map<String, dynamic> value) : _json = jsonEncode(value);

  factory ConnectionPlan.create({
    required String id,
    required ConnectionConfiguration configuration,
    required CompiledConnection compiled,
    required ConnectionPlatform platform,
    required StartVpnRequest request,
    String? notice,
  }) => ConnectionPlan._({
    'version': 1,
    'id': id,
    'platform': platform.name,
    'configuration': configuration.toJson(),
    'request': request.toJson(),
    'xrayJson': compiled.xrayJson,
    'entries': [for (final entry in compiled.entries) entry.toJson()],
    'finalExit': compiled.finalExit?.toJson(),
    'nodeTags': compiled.nodeTags,
    'ruleTags': {
      for (final entry in compiled.ruleTags.entries)
        entry.key: {'index': entry.value.index, 'name': entry.value.name},
    },
    'assetDirectory': compiled.assetDirectory,
    'notice': ?notice,
  });

  factory ConnectionPlan.decode(String text) {
    final json = jsonDecode(text) as Map<String, dynamic>;
    if (json['version'] != 1 ||
        json['id'] is! String ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(json['id'] as String)) {
      throw const FormatException('Invalid connection plan');
    }
    final plan = ConnectionPlan._(json);
    if (plan.runtime.planId != plan.id) {
      throw const FormatException('Runtime plan identity differs');
    }
    return plan;
  }

  Map<String, dynamic> toJson() => jsonDecode(_json) as Map<String, dynamic>;
  String encode() => _json;
  String get id => toJson()['id'] as String;
  String get xrayJson => toJson()['xrayJson'] as String;
  String get assetDirectory => toJson()['assetDirectory'] as String;
  String? get notice => toJson()['notice'] as String?;
  ConnectionPlatform get platform =>
      ConnectionPlatform.values.byName(toJson()['platform'] as String);
  ConnectionConfiguration get configuration => ConnectionConfiguration.fromJson(
    toJson()['configuration'] as Map<String, dynamic>,
  );
  StartVpnRequest get request =>
      StartVpnRequest.fromJson(toJson()['request'] as Map<String, dynamic>);
  ManagedRuntimeRequest get runtime =>
      LibXrayRunConfig.fromInvokeText(request.coreInvokeText!).request.runtime!;
  Set<int> get nodeIds {
    final json = toJson();
    return {
      for (final entry in json['entries'] as List) entry['id'] as int,
      if (json['finalExit'] != null) json['finalExit']['id'] as int,
    };
  }
}
