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
  void readVpnStatus();

  @async
  void startVpn();

  @async
  void stopVpn();

  @async
  String getFreePorts(int num);

  @async
  String convertShareLinksToXrayJson(String base64Text);

  @async
  String convertXrayJsonToShareLinks(String base64Text);

  @async
  String countGeoData(String base64Text);

  @async
  String readGeoFiles(String base64Text);

  @async
  String ping(String base64Text);

  @async
  String testXray(String base64Text);

  @async
  String runXray(String base64Text);

  @async
  String stopXray();

  @async
  String xrayVersion();

  @async
  String buildMphCache(String base64Text);

  //platform======================
  @async
  bool checkVpnPermission();

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

class AndroidAppInfo {
  AndroidAppInfo({required this.name, required this.packageName});

  final String name;
  final String packageName;
}

@FlutterApi()
abstract class BridgeFlutterApi {
  @async
  void vpnStatusChanged(VpnStatus status);
}
