import 'package:onexray/service/xray/constants.dart';
import 'package:onexray/service/xray/profile/dns_state.dart';
import 'package:onexray/service/xray/profile/fake_dns_state.dart';
import 'package:onexray/service/xray/profile/outbounds_state.dart';
import 'package:onexray/service/xray/profile/routing_state.dart';

class XrayFullConfigState {
  var name = XrayStateConstants.defaultName;

  var outbounds = OutboundsState();
  var routing = RoutingState();
  var dns = DnsState();
  var fakeDns = FakeDnsPoolsState();
}
