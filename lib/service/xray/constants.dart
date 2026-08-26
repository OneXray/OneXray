import 'package:onexray/core/pigeon/constants.dart';
import 'package:path/path.dart' as p;

class XrayStateConstants {
  static const defaultName = "xray";
  static const accessLog = "access.log";
  static const errorLog = "error.log";
  static const configFile = "xray.json";

  static String get accessLogPath => p.join(VpnConstants.runDir, accessLog);

  static String get errorLogPath => p.join(VpnConstants.runDir, errorLog);

  static String get configFilePath => p.join(VpnConstants.runDir, configFile);
}

abstract final class RoutingRuleTag {
  static const dnsQuery = "dnsQuery";
  static const dnsOut = "dnsOut";
  static const dnsDoT = "dnsDoT";
  static const ping = "ping";
  static const localDnsDirect = "localDnsDirect";
  static const defaultDnsProxy = "defaultDnsProxy";
  static const adBlock = "adBlock";
  static const domainDirect = "domainDirect";
  static const ipDirect = "IPDirect";
}

abstract final class DNSServerTag {
  static const dnsQuery = "dnsQuery";
  static const localDns = "localDns";
  static const defaultDns = "defaultDns";
}
