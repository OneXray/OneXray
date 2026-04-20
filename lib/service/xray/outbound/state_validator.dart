import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/xray/json_writer.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/outbound/state_writer.dart';
import 'package:onexray/service/xray/outbound/xhttp/state_validator.dart';
import 'package:onexray/service/xray/setting/inbounds_state.dart';
import 'package:onexray/service/xray/standard.dart';
import 'package:tuple/tuple.dart';

extension OutboundStateValidator on OutboundState {
  Future<Tuple2<bool, String>> validate() async {
    if (!EmptyTool.checkString(name)) {
      return Tuple2(false, appLocalizationsNoContext().validationNameRequired);
    }
    final xrayJson = XrayJsonStandard.standard;

    final pingInbound = InboundPingState();
    pingInbound.port = "${NetConstants.defaultPingPort}";

    xrayJson.inbounds = [pingInbound.xrayJson];
    xrayJson.outbounds = [this.xrayJson];

    final res = await xrayJson.test();
    if (res.isNotEmpty) {
      return Tuple2(false, res);
    }
    return const Tuple2(true, "");
  }

  void removeWhitespace() {
    name = name.removeWhitespace;

    address = address.removeWhitespace;
    port = port.removeWhitespace;

    vlessId = vlessId.removeWhitespace;
    vlessEncryption = vlessEncryption.removeWhitespace;
    vlessReverseTag = vlessReverseTag.removeWhitespace;

    vmessId = vmessId.removeWhitespace;

    shadowsocksPassword = shadowsocksPassword.removeWhitespace;

    trojanPassword = trojanPassword.removeWhitespace;

    socksUser = socksUser.removeWhitespace;
    socksPass = socksPass.removeWhitespace;

    tag = tag.removeWhitespace;

    rawPath = rawPath.removeWhitespace;
    rawHost = rawHost.removeWhitespace;

    xhttpHost = xhttpHost.removeWhitespace;
    xhttpPath = xhttpPath.removeWhitespace;
    xhttpExtra.removeWhitespace();

    kcpHeaderDomain = kcpHeaderDomain.removeWhitespace;
    kcpSeed = kcpSeed.removeWhitespace;

    wsPath = wsPath.removeWhitespace;
    wsHost = wsHost.removeWhitespace;

    grpcAuthority = grpcAuthority.removeWhitespace;
    grpcServiceName = grpcServiceName.removeWhitespace;

    httpupgradeHost = httpupgradeHost.removeWhitespace;
    httpupgradePath = httpupgradePath.removeWhitespace;

    hysteriaAuth = hysteriaAuth.removeWhitespace;
    hysteriaUp = hysteriaUp.removeWhitespace;
    hysteriaDown = hysteriaDown.removeWhitespace;
    hysteriaUdphopPort = hysteriaUdphopPort.removeWhitespace;
    hysteriaUdphopInterval = hysteriaUdphopInterval.removeWhitespace;

    serverName = serverName.removeWhitespace;
    pinnedPeerCertSha256 = pinnedPeerCertSha256.removeWhitespace;
    verifyPeerCertByName = verifyPeerCertByName.removeWhitespace;
    echConfigList = echConfigList.removeWhitespace;
    password = password.removeWhitespace;
    shortId = shortId.removeWhitespace;
    mldsa65Verify = mldsa65Verify.removeWhitespace;
    spiderX = spiderX.removeWhitespace;

    muxConcurrency = muxConcurrency.removeWhitespace;
    muxXudpConcurrency = muxXudpConcurrency.removeWhitespace;

    dialerProxy = dialerProxy.removeWhitespace;
    interface = interface.removeWhitespace;
  }
}
