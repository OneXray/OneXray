import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/xray/profile/state.dart';
import 'package:onexray/core/model/xray_standard.dart';

extension XrayProfileStateWriter on XrayProfileState {
  XrayJson get xrayJson {
    final xrayJson = XrayJsonStandard.standard;
    xrayJson.name = name;

    xrayJson.log = log.xrayJson;
    xrayJson.dns = dns.xrayJson;
    xrayJson.fakeDns = fakeDns.xrayJson(dns.queryStrategy);
    xrayJson.routing = routing.xrayJson;
    xrayJson.inbounds = inbounds.xrayJson;
    xrayJson.outbounds = outbounds.xrayJson;

    return xrayJson;
  }
}
