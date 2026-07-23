import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';
import 'package:onexray/service/xray/outbound/state_reader.dart';
import 'package:onexray/service/xray/outbound/state_validator.dart';

class XrayShareReader {
  Future<List<CoreConfigCompanion>> parseShareFile(String filePath) async {
    final file = File(filePath);
    final text = await file.readAsString();
    await FileTool.deleteFileIfExists(filePath);
    return parseShareText(text);
  }

  Future<List<CoreConfigCompanion>> parseOutboundShareText(String text) async {
    final xrayJson = await AppHostApi().convertShareLinksToXrayJson(text);
    return readXrayJsonOutbounds(xrayJson);
  }

  Future<List<CoreConfigCompanion>> parseShareText(String text) async {
    return parseOutboundShareText(text);
  }

  @visibleForTesting
  Future<List<CoreConfigCompanion>> readXrayJsonOutbounds(
    XrayJson xrayJson,
  ) async {
    final res = <CoreConfigCompanion>[];
    final outbounds = xrayJson.outbounds;
    if (outbounds == null) {
      return res;
    }

    for (var index = 0; index < outbounds.length; index++) {
      if (index > 0 && index % 64 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final outbound = outbounds[index];
      try {
        final state = OutboundState();
        final success = state.readFromOutbound(outbound);
        if (!success) {
          continue;
        }
        state.removeWhitespace();
        if (_isImportable(state)) {
          res.add(state.outboundCompanion);
        } else {
          ygLogger("Invalid imported outbound: ${state.name}");
        }
      } catch (error, stackTrace) {
        ygLogger("Failed to read imported outbound: $error\n$stackTrace");
      }
    }
    return res;
  }

  bool _isImportable(OutboundState state) {
    final port = int.tryParse(state.port);
    final endpointValid =
        state.name.isNotEmpty &&
        state.address.isNotEmpty &&
        port != null &&
        port > 0 &&
        port <= 65535;
    if (!endpointValid) {
      return false;
    }
    return switch (state.protocol) {
      XrayOutboundProtocol.vless => state.vlessId.isNotEmpty,
      XrayOutboundProtocol.vmess => state.vmessId.isNotEmpty,
      XrayOutboundProtocol.shadowsocks =>
        state.shadowsocksMethod != ShadowsocksMethod.none &&
            state.shadowsocksPassword.isNotEmpty,
      XrayOutboundProtocol.trojan => state.trojanPassword.isNotEmpty,
      XrayOutboundProtocol.socks ||
      XrayOutboundProtocol.http ||
      XrayOutboundProtocol.hysteria => true,
      _ => false,
    };
  }
}
