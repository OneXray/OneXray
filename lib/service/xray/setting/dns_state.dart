import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/service/xray/setting/dns_server_state.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/state.dart';
import 'package:onexray/service/xray/standard.dart';

class DnsState {
  var hosts = <String, List<String>>{};
  var servers = <DnsServerState>[DnsServerState()];
  final tag = DNSServerTag.dnsQuery;
  var queryStrategy = DnsQueryStrategy.useIPv4;
  var disableCache = false;
  var disableFallback = false;
  var disableFallbackIfMatch = false;
  var useSystemHosts = false;

  void removeWhitespace() {
    final newHosts = <String, List<String>>{};
    hosts.forEach((key, value) {
      final newKey = key.removeWhitespace;
      if (newKey.isNotEmpty) {
        final newValue = value.removeWhitespace;
        if (newValue.isNotEmpty) {
          newHosts[newKey] = newValue;
        }
      }
    });
    hosts = newHosts;

    for (final server in servers) {
      server.removeWhitespace();
    }
  }

  void readFromXrayJson(XrayJson xrayJson) {
    if (xrayJson.dns == null) {
      return;
    }
    final dns = xrayJson.dns!;
    if (EmptyTool.checkMap(dns.hosts)) {
      hosts = dns.hosts!;
    }
    if (EmptyTool.checkList(dns.servers)) {
      servers = dns.servers!
          .map((e) => DnsServerState()..readFromDnsServer(e))
          .toList();
    }
    if (EmptyTool.checkString(dns.queryStrategy)) {
      final queryStrategy = DnsQueryStrategy.fromString(dns.queryStrategy!);
      if (queryStrategy != null) {
        this.queryStrategy = queryStrategy;
      }
    }
    if (dns.disableCache != null) {
      disableCache = dns.disableCache!;
    }
    if (dns.disableFallback != null) {
      disableFallback = dns.disableFallback!;
    }
    if (dns.disableFallbackIfMatch != null) {
      disableFallbackIfMatch = dns.disableFallbackIfMatch!;
    }
    if (dns.useSystemHosts != null) {
      useSystemHosts = dns.useSystemHosts!;
    }
  }

  XrayDns get xrayJson {
    final dns = XrayDnsStandard.standard;
    if (hosts.isNotEmpty) {
      dns.hosts = hosts;
    }
    if (servers.isNotEmpty) {
      dns.servers = servers.map((e) => e.xrayJson).toList();
    }
    dns.tag = tag;
    dns.queryStrategy = queryStrategy.name;
    if (disableCache) {
      dns.disableCache = disableCache;
    }
    if (disableFallback) {
      dns.disableFallback = disableFallback;
    }
    if (disableFallbackIfMatch) {
      dns.disableFallbackIfMatch = disableFallbackIfMatch;
    }
    if (useSystemHosts) {
      dns.useSystemHosts = useSystemHosts;
    }

    return dns;
  }

  List<String> get inboundTags {
    final tags = <String>[tag];

    if (servers.isNotEmpty) {
      for (final server in servers) {
        if (server.tag.isNotEmpty) {
          tags.add(server.tag);
        }
      }
    }

    return tags;
  }
}
