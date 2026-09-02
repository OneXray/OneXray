import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/pigeon/messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/app/src/main/kotlin/net/yuandev/onexray/pigeon/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: "net.yuandev.onexray.pigeon"),
    swiftOut: 'swift/App/pigeon/Messages.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'onexray',
  ),
)
@HostApi()
abstract class BridgeHostApi {
  @asyncCallback
  String getTunFilesDir();

  @asyncCallback
  NativeVpnCommandResult readVpnStatus();

  @asyncCallback
  NativeVpnCommandResult startVpn();

  @asyncCallback
  NativeVpnCommandResult stopVpn();

  @asyncCallback
  String invoke(String requestJson);

  //platform======================
  @asyncCallback
  PlatformPermissionResult queryPlatformPermission();

  @asyncCallback
  PlatformPermissionResult requestPlatformPermission();

  //android=======================

  @asyncCallback
  List<AndroidAppInfo> getInstalledApps();

  @asyncCallback
  Uint8List? getAppIcon(String packageName);

  //macOS======================
  @asyncCallback
  bool useSystemExtension();

  @asyncCallback
  AppleVpnCapabilities appleVpnCapabilities();

  // System Extension-owned session files only; removal IDs are already settled.
  @asyncCallback
  String? readRuntimeState(List<String> removeSessionIds);

  // Fixed System Extension plan logs. Offset -1 reads the bounded file tail.
  @asyncCallback
  NativeLogChunk? readLog(String planId, bool access, int offset, int limit);

  @asyncCallback
  NativeLaunchAtLoginResult queryLaunchAtLogin();

  @asyncCallback
  NativeLaunchAtLoginResult setLaunchAtLogin(bool enabled);

  @asyncCallback
  bool openLaunchAtLoginSettings();

  //Apple app icon======================
  @asyncCallback
  bool setAppIcon(String appIcon);

  @asyncCallback
  String getCurrentAppIcon();
}

enum VpnStatus { disconnecting, disconnected, connecting, connected }

class AppleVpnCapabilities {
  AppleVpnCapabilities({
    required this.serviceExclusions,
    required this.deviceCommunication,
  });
  final bool serviceExclusions;
  final bool deviceCommunication;
}

class NativeLogChunk {
  NativeLogChunk({
    required this.data,
    required this.offset,
    required this.size,
    required this.fileId,
  });

  final Uint8List data;
  final int offset;
  final int size;
  final String fileId;
}

// Apple VPN profile and System Extension readiness.
enum RefreshVpnResult { installed, notInstalled, waitForApproval }

enum PlatformPermissionKind { none, androidVpn, macosSystemExtension, appleVpn }

enum PlatformPermissionState {
  notRequired,
  notDetermined,
  awaitingUserApproval,
  granted,
  denied,
  failed,
}

enum NativeVpnCommandState { success, waitingForPlatformPermission, failed }

enum NativeLaunchAtLoginState {
  enabled,
  disabled,
  requiresApproval,
  unavailable,
  error,
}

class NativeLaunchAtLoginResult {
  NativeLaunchAtLoginResult({required this.state, this.message});

  final NativeLaunchAtLoginState state;
  final String? message;
}

class PlatformPermissionResult {
  PlatformPermissionResult({
    required this.kind,
    required this.state,
    this.message,
  });

  final PlatformPermissionKind kind;
  final PlatformPermissionState state;
  final String? message;
}

class NativeVpnCommandResult {
  NativeVpnCommandResult({required this.state, this.permission, this.message});

  final NativeVpnCommandState state;
  final PlatformPermissionResult? permission;
  final String? message;
}

class AndroidAppInfo {
  AndroidAppInfo({required this.name, required this.packageName});

  final String name;
  final String packageName;
}

@FlutterApi()
abstract class BridgeFlutterApi {
  @asyncCallback
  void vpnStatusChanged(VpnStatus status);

  @asyncCallback
  void refreshVpn(RefreshVpnResult result);
}
