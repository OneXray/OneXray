import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/xray/full_config/state.dart';
import 'package:onexray/service/xray/full_config/state_writer.dart';
import 'package:onexray/service/xray/json_writer.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:tuple/tuple.dart';

extension XrayFullConfigStateValidator on XrayFullConfigState {
  Future<Tuple2<bool, String>> validate() async {
    if (!EmptyTool.checkString(name)) {
      return Tuple2(false, appLocalizationsNoContext().validationNameRequired);
    }
    removeWhitespace();
    final proxy = _proxyOutboundExists();
    if (!proxy) {
      return Tuple2(false, appLocalizationsNoContext().validationProxyRequired);
    }
    if (!_tagsAreUnique()) {
      return Tuple2(false, appLocalizationsNoContext().validationTagUnique);
    }
    final xrayJson = this.xrayJson;
    final pingInbound = InboundPingState()
      ..port = "${NetConstants.defaultPingPort}";
    xrayJson.inbounds = [pingInbound.xrayJson];
    final res = await xrayJson.test();
    if (res.isNotEmpty) {
      return Tuple2(false, res);
    }
    return const Tuple2(true, "");
  }

  bool _proxyOutboundExists() {
    return outbounds.outbounds.any(
      (outbound) => outbound.tag == RoutingOutboundTag.proxy.name,
    );
  }

  bool _tagsAreUnique() {
    final tags = <String>{};
    for (final tag in outbounds.outboundTags) {
      if (!EmptyTool.checkString(tag)) {
        return false;
      }
      if (!tags.add(tag)) {
        return false;
      }
    }
    return true;
  }

  void removeWhitespace() {
    name = name.removeWhitespace;
    outbounds.removeWhitespace();
    routing.removeWhitespace();
    dns.removeWhitespace();
  }
}
