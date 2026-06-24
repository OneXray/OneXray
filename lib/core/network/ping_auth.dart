import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/pigeon/model.dart';

export 'package:onexray/core/pigeon/model.dart' show PingAuth;

extension PingAuthNetwork on PingAuth {
  bool get isValid => user?.isNotEmpty == true && pass?.isNotEmpty == true;

  Map<String, dynamic> get xrayUser => <String, dynamic>{
    "user": user ?? "",
    "pass": pass ?? "",
  };

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

abstract final class PingAuthFactory {
  static PingAuth random() {
    return PingAuth(_token(18), _token(32));
  }

  static String _token(int bytes) {
    final random = Random.secure();
    final data = Uint8List.fromList(
      List.generate(bytes, (_) => random.nextInt(256)),
    );
    return base64Url.encode(data).replaceAll("=", "");
  }
}
