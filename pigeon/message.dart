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
  @async
  String getTunFilesDir();

  @async
  NativeVpnCommandResult readVpnStatus();

  @async
  NativeVpnCommandResult startVpn();

  @async
  NativeVpnCommandResult stopVpn();

  @async
  String invoke(String requestJson);

  //platform======================
  @async
  bool checkVpnPermission();

  @async
  PlatformPermissionResult queryPlatformPermission();

  @async
  PlatformPermissionResult requestPlatformPermission();

  //android=======================

  @async
  List<AndroidAppInfo> getInstalledApps();

  //macOS======================
  @async
  bool useSystemExtension();

  //iOS======================
  @async
  bool setAppIcon(String appIcon);

  @async
  String getCurrentAppIcon();
}

enum VpnStatus { disconnecting, disconnected, connecting, connected }

// macOS only
enum RefreshVpnResult { installed, notInstalled, waitForApproval }

enum PlatformPermissionKind { none, androidVpn, macosSystemExtension }

enum PlatformPermissionState {
  notRequired,
  notDetermined,
  awaitingUserApproval,
  granted,
  denied,
  failed,
}

enum NativeVpnCommandState { success, waitingForPlatformPermission, failed }

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
  @async
  void vpnStatusChanged(VpnStatus status);

  @async
  void refreshVpn(RefreshVpnResult result);
}
