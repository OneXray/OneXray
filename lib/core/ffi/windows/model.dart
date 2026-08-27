import 'package:json_annotation/json_annotation.dart';

part 'model.g.dart';

enum WindowsNativeMethod {
  getEnvironment,
  getVpnStatus,
  startVpn,
  stopVpn,
  getStartupTaskStatus,
  setStartupTaskEnabled,
}

@JsonSerializable(createFactory: false)
final class WindowsNativeInvokeRequest {
  final int bridgeVersion;
  final WindowsNativeMethod method;
  final Map<String, Object?> payload;

  const WindowsNativeInvokeRequest({
    required this.method,
    this.payload = const {},
  }) : bridgeVersion = 2;

  Map<String, dynamic> toJson() => _$WindowsNativeInvokeRequestToJson(this);
}

@JsonSerializable(disallowUnrecognizedKeys: true)
final class WindowsNativeInvokeResponse {
  final bool success;
  @JsonKey(required: true)
  final Map<String, dynamic>? data;
  final String error;

  const WindowsNativeInvokeResponse(this.success, this.data, this.error);

  factory WindowsNativeInvokeResponse.fromJson(Map<String, dynamic> json) =>
      _$WindowsNativeInvokeResponseFromJson(json);

  Map<String, dynamic> toJson() => _$WindowsNativeInvokeResponseToJson(this);
}

enum WindowsVpnStatus { disconnecting, disconnected, connecting, connected }

enum WindowsStartupTaskState {
  enabled,
  disabled,
  requiresApproval,
  unavailable,
}

@JsonSerializable()
final class WindowsPackageEnvironment {
  final String packageFamilyName;
  final String packageLocalDataDir;

  const WindowsPackageEnvironment({
    required this.packageFamilyName,
    required this.packageLocalDataDir,
  });

  factory WindowsPackageEnvironment.fromJson(Map<String, dynamic> json) =>
      _$WindowsPackageEnvironmentFromJson(json);

  Map<String, dynamic> toJson() => _$WindowsPackageEnvironmentToJson(this);
}

@JsonSerializable(disallowUnrecognizedKeys: true)
final class WindowsVpnProfileState {
  final WindowsVpnStatus status;
  @JsonKey(required: true)
  final String? snapshotToken;

  const WindowsVpnProfileState(this.status, this.snapshotToken);

  factory WindowsVpnProfileState.fromJson(Map<String, dynamic> json) =>
      _$WindowsVpnProfileStateFromJson(json);

  Map<String, dynamic> toJson() => _$WindowsVpnProfileStateToJson(this);
}

@JsonSerializable()
final class WindowsManagedProcess {
  final String executableRelativePath;
  final List<String> arguments;

  const WindowsManagedProcess({
    required this.executableRelativePath,
    required this.arguments,
  });

  factory WindowsManagedProcess.fromJson(Map<String, dynamic> json) =>
      _$WindowsManagedProcessFromJson(json);

  Map<String, dynamic> toJson() => _$WindowsManagedProcessToJson(this);
}

@JsonSerializable(explicitToJson: true)
final class WindowsSessionBackend {
  final List<WindowsManagedProcess> processes;

  const WindowsSessionBackend({required this.processes});

  factory WindowsSessionBackend.fromJson(Map<String, dynamic> json) =>
      _$WindowsSessionBackendFromJson(json);

  Map<String, dynamic> toJson() => _$WindowsSessionBackendToJson(this);
}

@JsonSerializable()
final class WindowsVpnNetworkSettings {
  final String ipv4Address;
  final String ipv6Address;
  final String dnsIpv4Address;
  final String dnsIpv6Address;

  const WindowsVpnNetworkSettings({
    required this.ipv4Address,
    required this.ipv6Address,
    required this.dnsIpv4Address,
    required this.dnsIpv6Address,
  });

  factory WindowsVpnNetworkSettings.fromJson(Map<String, dynamic> json) =>
      _$WindowsVpnNetworkSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$WindowsVpnNetworkSettingsToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
final class WindowsStartVpnPayload {
  final String configYaml;
  final WindowsVpnNetworkSettings networkSettings;
  final WindowsSessionBackend? sessionBackend;

  const WindowsStartVpnPayload({
    required this.configYaml,
    required this.networkSettings,
    this.sessionBackend,
  });

  factory WindowsStartVpnPayload.fromJson(Map<String, dynamic> json) =>
      _$WindowsStartVpnPayloadFromJson(json);

  Map<String, dynamic> toJson() => _$WindowsStartVpnPayloadToJson(this);
}

@JsonSerializable()
final class WindowsSetStartupTaskEnabledPayload {
  final bool enabled;

  const WindowsSetStartupTaskEnabledPayload(this.enabled);

  factory WindowsSetStartupTaskEnabledPayload.fromJson(
    Map<String, dynamic> json,
  ) => _$WindowsSetStartupTaskEnabledPayloadFromJson(json);

  Map<String, dynamic> toJson() =>
      _$WindowsSetStartupTaskEnabledPayloadToJson(this);
}

@JsonSerializable(disallowUnrecognizedKeys: true)
final class WindowsStartupTaskStatus {
  final WindowsStartupTaskState state;

  const WindowsStartupTaskStatus(this.state);

  factory WindowsStartupTaskStatus.fromJson(Map<String, dynamic> json) =>
      _$WindowsStartupTaskStatusFromJson(json);

  Map<String, dynamic> toJson() => _$WindowsStartupTaskStatusToJson(this);
}
