import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/xray/full_config/state.dart';
import 'package:onexray/service/xray/profile/state.dart';
import 'package:onexray/service/xray/standard.dart';

extension XrayFullConfigStateWriter on XrayFullConfigState {
  XrayJson get xrayJson {
    final xrayJson = XrayJsonStandard.standard;
    xrayJson.name = name;
    xrayJson.outbounds = outbounds.xrayJson;
    xrayJson.routing = routing.xrayJson;
    xrayJson.dns = dns.xrayJson;
    xrayJson.fakeDns = fakeDns.xrayJson(dns.queryStrategy);
    return xrayJson;
  }

  void applyToXrayProfile(XrayProfileState profile) {
    profile.outbounds = outbounds;
    profile.routing = routing;
    profile.dns = dns;
    profile.fakeDns = fakeDns;
  }
}
