import 'dart:io';

import 'package:onexray/core/ffi/linux_ffi_api.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/service/connection/platform_policy.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/tun_settings/interface.dart';
import 'package:path/path.dart' as p;

enum ConnectionPlatformRequirementFailure {
  outboundInterfaceRequired,
  outboundInterfaceUnavailable,
}

final class ConnectionPlatformRequirementException implements Exception {
  final ConnectionPlatformRequirementFailure failure;

  const ConnectionPlatformRequirementException(this.failure);

  String get reason => switch (failure) {
    ConnectionPlatformRequirementFailure.outboundInterfaceRequired =>
      'interfaceRequired',
    ConnectionPlatformRequirementFailure.outboundInterfaceUnavailable =>
      'interfaceUnavailable',
  };
}

/// Checks the platform requirements needed by every normal VPN session.
final class ConnectionPlatformRequirements {
  final ConnectionPlatform platform;
  final Future<Set<String>> Function() _interfaceNames;

  ConnectionPlatformRequirements({
    ConnectionPlatform? platform,
    Future<Set<String>> Function()? interfaceNames,
  }) : platform = platform ?? connectionPlatform,
       _interfaceNames = interfaceNames ?? _readInterfaceNames;

  static Future<Set<String>> _readInterfaceNames() async => {
    for (final value in await queryXrayOutboundInterfaceList()) value.name,
  };

  Future<void> ensureOutboundInterface(String name) async {
    if (platform != ConnectionPlatform.windows &&
        platform != ConnectionPlatform.linux) {
      return;
    }
    if (name.trim().isEmpty || name.contains('\u0000')) {
      throw const ConnectionPlatformRequirementException(
        ConnectionPlatformRequirementFailure.outboundInterfaceRequired,
      );
    }
    if (!(await _interfaceNames()).contains(name)) {
      throw const ConnectionPlatformRequirementException(
        ConnectionPlatformRequirementFailure.outboundInterfaceUnavailable,
      );
    }
  }

  Future<PlatformPermissionResult> check({bool request = false}) async {
    await ensureRuntime();
    final host = AppHostApi();
    final current = await host.queryPlatformPermission();
    if (!request || permissionReady(current)) return current;
    return host.requestPlatformPermission();
  }

  static bool permissionReady(PlatformPermissionResult value) =>
      value.state == PlatformPermissionState.granted ||
      value.state == PlatformPermissionState.notRequired;

  Future<void> ensureRuntime() async {
    if (platform == ConnectionPlatform.windows) {
      if (!AppHostApi().windowsPackageAvailable ||
          !await File(
            p.join(p.dirname(Platform.resolvedExecutable), 'OneXrayCore.exe'),
          ).exists()) {
        throw StateError('OneXrayCore / VCore is unavailable');
      }
      return;
    }
    if (platform != ConnectionPlatform.linux) return;

    final file = File(LinuxFfiApi().corePath);
    if (!await file.exists() ||
        ((await file.stat()).mode & 0x49) == 0 ||
        !await File('/dev/net/tun').exists()) {
      throw StateError('OneXrayCore / TUN is unavailable');
    }
    final status = await File('/proc/self/status').readAsString();
    if (RegExp(r'^Uid:\s+0\s+0\s+0\s+0$', multiLine: true).hasMatch(status)) {
      return;
    }
    final result = await Process.run('getcap', [
      file.path,
    ]).timeout(const Duration(seconds: 5));
    final capabilities = '${result.stdout}';
    if (result.exitCode != 0 ||
        !capabilities.contains('cap_net_admin') ||
        !capabilities.contains('cap_net_raw') ||
        !RegExp(r'=[eip]*e[eip]*\s*$').hasMatch(capabilities)) {
      throw StateError('cap_net_admin / cap_net_raw are unavailable');
    }
  }
}
