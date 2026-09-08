import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:onexray/core/ffi/base_ffi_api.dart';
import 'package:onexray/core/ffi/windows/exe_ffi_api.dart';
import 'package:onexray/core/ffi/windows/mode.dart';
import 'package:onexray/core/ffi/windows/model.dart';
import 'package:onexray/core/ffi/windows/msix_ffi_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:path/path.dart' as p;

abstract class WindowsFfiApi extends BaseFfiApi {
  static final WindowsFfiApi _singleton = switch (windowsBuildMode) {
    WindowsMode.exe => WindowsExeFfiApi(),
    WindowsMode.msix => WindowsMsixFfiApi(),
  };

  factory WindowsFfiApi() => _singleton;

  WindowsFfiApi.base();

  Future<void> ensureRuntime();

  Future<bool?> cleanupStaleCore() async => null;

  @override
  Future<NativeVpnCommandResult> startVpn({
    String? configYaml,
    WindowsVpnNetworkSettings? networkSettings,
    WindowsVpnPolicy policy = const WindowsVpnPolicy(
      alwaysOn: false,
      allowLocalNetwork: true,
      excludedCidrs: [],
    ),
  });

  @protected
  Future<void> checkRuntimeFiles(List<String> names) async {
    for (final name in names) {
      if (!await File(p.join(p.dirname(Platform.resolvedExecutable), name))
          .exists()) {
        throw StateError('Windows runtime file is unavailable: $name');
      }
    }
  }
}
