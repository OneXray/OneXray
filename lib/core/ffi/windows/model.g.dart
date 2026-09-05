// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$WindowsNativeInvokeRequestToJson(
  WindowsNativeInvokeRequest instance,
) => <String, dynamic>{
  'bridgeVersion': instance.bridgeVersion,
  'method': _$WindowsNativeMethodEnumMap[instance.method]!,
  'payload': instance.payload,
};

const _$WindowsNativeMethodEnumMap = {
  WindowsNativeMethod.getEnvironment: 'getEnvironment',
  WindowsNativeMethod.getVpnStatus: 'getVpnStatus',
  WindowsNativeMethod.startVpn: 'startVpn',
  WindowsNativeMethod.stopVpn: 'stopVpn',
  WindowsNativeMethod.getStartupTaskStatus: 'getStartupTaskStatus',
  WindowsNativeMethod.setStartupTaskEnabled: 'setStartupTaskEnabled',
};

WindowsNativeInvokeResponse _$WindowsNativeInvokeResponseFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['success', 'data', 'error'],
    requiredKeys: const ['data'],
  );
  return WindowsNativeInvokeResponse(
    json['success'] as bool,
    json['data'] as Map<String, dynamic>?,
    json['error'] as String,
  );
}

Map<String, dynamic> _$WindowsNativeInvokeResponseToJson(
  WindowsNativeInvokeResponse instance,
) => <String, dynamic>{
  'success': instance.success,
  'data': instance.data,
  'error': instance.error,
};

WindowsPackageEnvironment _$WindowsPackageEnvironmentFromJson(
  Map<String, dynamic> json,
) => WindowsPackageEnvironment(
  packageFamilyName: json['packageFamilyName'] as String,
  packageLocalDataDir: json['packageLocalDataDir'] as String,
);

Map<String, dynamic> _$WindowsPackageEnvironmentToJson(
  WindowsPackageEnvironment instance,
) => <String, dynamic>{
  'packageFamilyName': instance.packageFamilyName,
  'packageLocalDataDir': instance.packageLocalDataDir,
};

WindowsVpnProfileState _$WindowsVpnProfileStateFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const ['status', 'snapshotToken'],
    requiredKeys: const ['snapshotToken'],
  );
  return WindowsVpnProfileState(
    $enumDecode(_$WindowsVpnStatusEnumMap, json['status']),
    json['snapshotToken'] as String?,
  );
}

Map<String, dynamic> _$WindowsVpnProfileStateToJson(
  WindowsVpnProfileState instance,
) => <String, dynamic>{
  'status': _$WindowsVpnStatusEnumMap[instance.status]!,
  'snapshotToken': instance.snapshotToken,
};

const _$WindowsVpnStatusEnumMap = {
  WindowsVpnStatus.disconnecting: 'disconnecting',
  WindowsVpnStatus.disconnected: 'disconnected',
  WindowsVpnStatus.connecting: 'connecting',
  WindowsVpnStatus.connected: 'connected',
};

WindowsManagedProcess _$WindowsManagedProcessFromJson(
  Map<String, dynamic> json,
) => WindowsManagedProcess(
  executableRelativePath: json['executableRelativePath'] as String,
  arguments: (json['arguments'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$WindowsManagedProcessToJson(
  WindowsManagedProcess instance,
) => <String, dynamic>{
  'executableRelativePath': instance.executableRelativePath,
  'arguments': instance.arguments,
};

WindowsSessionBackend _$WindowsSessionBackendFromJson(
  Map<String, dynamic> json,
) => WindowsSessionBackend(
  processes: (json['processes'] as List<dynamic>)
      .map((e) => WindowsManagedProcess.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$WindowsSessionBackendToJson(
  WindowsSessionBackend instance,
) => <String, dynamic>{
  'processes': instance.processes.map((e) => e.toJson()).toList(),
};

WindowsVpnNetworkSettings _$WindowsVpnNetworkSettingsFromJson(
  Map<String, dynamic> json,
) => WindowsVpnNetworkSettings(
  ipv4Address: json['ipv4Address'] as String,
  ipv6Address: json['ipv6Address'] as String,
  dnsIpv4Address: json['dnsIpv4Address'] as String,
  dnsIpv6Address: json['dnsIpv6Address'] as String,
);

Map<String, dynamic> _$WindowsVpnNetworkSettingsToJson(
  WindowsVpnNetworkSettings instance,
) => <String, dynamic>{
  'ipv4Address': instance.ipv4Address,
  'ipv6Address': instance.ipv6Address,
  'dnsIpv4Address': instance.dnsIpv4Address,
  'dnsIpv6Address': instance.dnsIpv6Address,
};

WindowsVpnPolicy _$WindowsVpnPolicyFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const ['alwaysOn', 'allowLocalNetwork', 'excludedCidrs'],
    requiredKeys: const ['alwaysOn', 'allowLocalNetwork', 'excludedCidrs'],
  );
  return WindowsVpnPolicy(
    alwaysOn: json['alwaysOn'] as bool,
    allowLocalNetwork: json['allowLocalNetwork'] as bool,
    excludedCidrs: (json['excludedCidrs'] as List<dynamic>)
        .map((e) => e as String)
        .toList(),
  );
}

Map<String, dynamic> _$WindowsVpnPolicyToJson(WindowsVpnPolicy instance) =>
    <String, dynamic>{
      'alwaysOn': instance.alwaysOn,
      'allowLocalNetwork': instance.allowLocalNetwork,
      'excludedCidrs': instance.excludedCidrs,
    };

WindowsStartVpnPayload _$WindowsStartVpnPayloadFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(
    json,
    allowedKeys: const [
      'configYaml',
      'networkSettings',
      'policy',
      'sessionBackend',
    ],
    requiredKeys: const ['policy'],
  );
  return WindowsStartVpnPayload(
    configYaml: json['configYaml'] as String,
    networkSettings: WindowsVpnNetworkSettings.fromJson(
      json['networkSettings'] as Map<String, dynamic>,
    ),
    policy: WindowsVpnPolicy.fromJson(json['policy'] as Map<String, dynamic>),
    sessionBackend: json['sessionBackend'] == null
        ? null
        : WindowsSessionBackend.fromJson(
            json['sessionBackend'] as Map<String, dynamic>,
          ),
  );
}

Map<String, dynamic> _$WindowsStartVpnPayloadToJson(
  WindowsStartVpnPayload instance,
) => <String, dynamic>{
  'configYaml': instance.configYaml,
  'networkSettings': instance.networkSettings.toJson(),
  'policy': instance.policy.toJson(),
  'sessionBackend': ?instance.sessionBackend?.toJson(),
};

WindowsSetStartupTaskEnabledPayload
_$WindowsSetStartupTaskEnabledPayloadFromJson(Map<String, dynamic> json) =>
    WindowsSetStartupTaskEnabledPayload(json['enabled'] as bool);

Map<String, dynamic> _$WindowsSetStartupTaskEnabledPayloadToJson(
  WindowsSetStartupTaskEnabledPayload instance,
) => <String, dynamic>{'enabled': instance.enabled};

WindowsStartupTaskStatus _$WindowsStartupTaskStatusFromJson(
  Map<String, dynamic> json,
) {
  $checkKeys(json, allowedKeys: const ['state']);
  return WindowsStartupTaskStatus(
    $enumDecode(_$WindowsStartupTaskStateEnumMap, json['state']),
  );
}

Map<String, dynamic> _$WindowsStartupTaskStatusToJson(
  WindowsStartupTaskStatus instance,
) => <String, dynamic>{
  'state': _$WindowsStartupTaskStateEnumMap[instance.state]!,
};

const _$WindowsStartupTaskStateEnumMap = {
  WindowsStartupTaskState.enabled: 'enabled',
  WindowsStartupTaskState.disabled: 'disabled',
  WindowsStartupTaskState.requiresApproval: 'requiresApproval',
  WindowsStartupTaskState.unavailable: 'unavailable',
};
