import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/platform_policy.dart';
import 'package:onexray/service/connection/preparation.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/connection/runtime_host.dart';
import 'package:onexray/service/connection/settings.dart';

/// Subpages carry the same original configuration and their own JSON draft.
/// Invalid intermediate text stays here, never in the database or runtime.
class PolicyEditorDraft {
  final ConnectionConfiguration original;
  final Map<String, dynamic> policy;

  PolicyEditorDraft(this.original, [Map<String, dynamic>? policy])
    : policy = jsonDecode(
        jsonEncode(policy ?? original.policy.toJson()),
      ) as Map<String, dynamic>;

  PolicyEditorDraft copy() => PolicyEditorDraft(original, policy);
}

class PolicyEditorService {
  final ConnectionCoordinator coordinator;
  final ConnectionPlatform platform;

  PolicyEditorService({
    ConnectionCoordinator? coordinator,
    ConnectionPlatform? platform,
  }) : coordinator = coordinator ?? ConnectionCoordinator.instance,
       platform = platform ?? connectionPlatform;

  Future<PolicyEditorDraft> load() async {
    await coordinator.initialize();
    return PolicyEditorDraft(await coordinator.configuration);
  }

  bool get requiresInterface =>
      platform == ConnectionPlatform.windows ||
      platform == ConnectionPlatform.linux;

  static bool emptyAndroidScope(PlatformPolicy policy) {
    final android = policy.toJson()['android'] as Map<String, dynamic>;
    return android['appScope'] == 'included' &&
        (android['includedAppPackageNames'] as List).isEmpty;
  }

  PlatformPolicy validate(PolicyEditorDraft draft) {
    final value = draft.copy().policy;
    value['windows']['excludedCidrs'] =
        (value['windows']['excludedCidrs'] as List)
            .cast<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList();
    final policy = PlatformPolicy.fromJson(value);
    if (requiresInterface && policy.xrayOutboundInterfaceName.trim().isEmpty) {
      throw const FormatException('Network interface is required');
    }
    if (platform == ConnectionPlatform.windows) {
      policy.toWindowsPolicy();
    }
    return policy;
  }

  Future<bool> save({
    required PolicyEditorDraft draft,
    required Future<bool> Function(bool disconnect) confirm,
  }) async {
    final policy = validate(draft);
    await coordinator.initialize();
    await coordinator.refresh();
    if ((await coordinator.configuration).encode() != draft.original.encode()) {
      throw const ConnectionHostException('configurationChanged');
    }
    final changed = !sameRuntime(draft.original.policy, policy, platform);
    final disconnect =
        platform == ConnectionPlatform.android && emptyAndroidScope(policy);
    var allowed = false;
    if (changed && coordinator.state.value.phase == ConnectionPhase.connected) {
      allowed = await confirm(disconnect);
      if (!allowed) {
        return false;
      }
    }
    await coordinator.apply(
      ConnectionConfiguration(
        connection: draft.original.connection,
        policy: policy,
      ),
      affectsRuntime: changed,
      disconnect: disconnect && changed,
      expectedConfiguration: draft.original.encode(),
      allowReconnect: allowed,
    );
    return true;
  }

  /// Inactive platform settings and inactive Android lists are storage only.
  static bool sameRuntime(
    PlatformPolicy a,
    PlatformPolicy b,
    ConnectionPlatform platform,
  ) {
    Object effective(PlatformPolicy policy) {
      final json = policy.toJson();
      final result = <String, dynamic>{
        'ipv6': policy.ipv6Enabled,
        'log': json['log'],
      };
      if (platform == ConnectionPlatform.android) {
        final android = json['android'] as Map<String, dynamic>;
        final scope = android['appScope'];
        final packages = switch (scope) {
          'included' => List<String>.from(android['includedAppPackageNames']),
          'excluded' => List<String>.from(android['excludedAppPackageNames']),
          _ => <String>[],
        }..sort();
        result['android'] = {'scope': scope, 'packages': packages};
      } else if (platform == ConnectionPlatform.ios ||
          platform == ConnectionPlatform.macos) {
        result['apple'] = policy.toTun(platform).toJson();
      } else {
        result['interface'] = policy.xrayOutboundInterfaceName;
        if (platform == ConnectionPlatform.windows) {
          result['windows'] = json['windows'];
        }
      }
      return result;
    }

    return const DeepCollectionEquality().equals(effective(a), effective(b));
  }
}
