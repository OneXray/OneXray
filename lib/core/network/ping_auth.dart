import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/network/constants.dart';

export 'package:onexray/core/model/xray_json.dart' show XrayInboundAccount;

extension XrayInboundAccountNetwork on XrayInboundAccount {
  bool get isValid => user?.isNotEmpty == true && pass?.isNotEmpty == true;

  String proxyUrl(String port) {
    final parsedPort = int.tryParse(port);
    if (!isValid || parsedPort == null) {
      return "http://${NetConstants.proxyHost}:$port";
    }
    return Uri(
      scheme: "http",
      userInfo: "${user!}:${pass!}",
      host: NetConstants.proxyHost,
      port: parsedPort,
    ).toString();
  }
}

abstract final class XrayInboundAccountFactory {
  static XrayInboundAccount random() {
    return XrayInboundAccount(_token(18), _token(32));
  }

  static String _token(int bytes) {
    final random = Random.secure();
    final data = Uint8List.fromList(
      List.generate(bytes, (_) => random.nextInt(256)),
    );
    return base64Url.encode(data).replaceAll("=", "");
  }
}
