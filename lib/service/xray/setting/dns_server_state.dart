import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/standard.dart';

class DnsServerState {
  var address = "1.1.1.1";
  var port = "";
  var skipFallback = false;
  var domains = <String>[];
  var expectedIPs = <String>[];
  var unexpectedIPs = <String>[];
  var queryStrategy = DnsQueryStrategy.useIPv4;
  var tag = "";
  var disableCache = false;
  var finalQuery = false;

  void removeWhitespace() {
    address = address.removeWhitespace;
    port = port.removeWhitespace;
    domains = domains.removeWhitespace;
    expectedIPs = expectedIPs.removeWhitespace;
    unexpectedIPs = unexpectedIPs.removeWhitespace;
    tag = tag.removeWhitespace;
  }

  void readFromDnsServer(XrayDnsServer server) {
    if (EmptyTool.checkString(server.address)) {
      address = server.address!;
    }
    if (server.port != null) {
      port = "${server.port}";
    }
    if (server.skipFallback != null) {
      skipFallback = server.skipFallback!;
    }
    if (EmptyTool.checkList(server.domains)) {
      domains = server.domains!;
    }
    if (EmptyTool.checkList(server.expectedIPs)) {
      expectedIPs = server.expectedIPs!;
    }
    if (EmptyTool.checkList(server.unexpectedIPs)) {
      unexpectedIPs = server.unexpectedIPs!;
    }
    if (EmptyTool.checkString(server.queryStrategy)) {
      final queryStrategy = DnsQueryStrategy.fromString(server.queryStrategy!);
      if (queryStrategy != null) {
        this.queryStrategy = queryStrategy;
      }
    }
    if (EmptyTool.checkString(server.tag)) {
      tag = server.tag!;
    }
    if (server.disableCache != null) {
      disableCache = server.disableCache!;
    }
    if (server.finalQuery != null) {
      finalQuery = server.finalQuery!;
    }
  }

  XrayDnsServer get xrayJson {
    final server = XrayDnsServerStandard.standard;
    if (address.isNotEmpty) {
      server.address = address;
    }
    if (port.isNotEmpty) {
      server.port = int.tryParse(port);
    }
    if (skipFallback) {
      server.skipFallback = skipFallback;
    }
    if (domains.isNotEmpty) {
      server.domains = domains;
    }
    if (expectedIPs.isNotEmpty) {
      server.expectedIPs = expectedIPs;
    }
    if (unexpectedIPs.isNotEmpty) {
      server.unexpectedIPs = unexpectedIPs;
    }
    server.queryStrategy = queryStrategy.name;
    if (tag.isNotEmpty) {
      server.tag = tag;
    }
    if (disableCache) {
      server.disableCache = disableCache;
    }
    if (finalQuery) {
      server.finalQuery = finalQuery;
    }
    return server;
  }
}
