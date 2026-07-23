import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/service/xray/outbound/state.dart';

extension OutboundStateNormalizer on OutboundState {
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

    httpUser = httpUser.removeWhitespace;
    httpPass = httpPass.removeWhitespace;

    tag = tag.removeWhitespace;

    rawPath = rawPath.removeWhitespace;
    rawHost = rawHost.removeWhitespace;

    xhttpHost = xhttpHost.removeWhitespace;
    xhttpPath = xhttpPath.removeWhitespace;

    wsPath = wsPath.removeWhitespace;
    wsHost = wsHost.removeWhitespace;

    grpcAuthority = grpcAuthority.removeWhitespace;
    grpcServiceName = grpcServiceName.removeWhitespace;

    httpupgradeHost = httpupgradeHost.removeWhitespace;
    httpupgradePath = httpupgradePath.removeWhitespace;

    hysteriaAuth = hysteriaAuth.removeWhitespace;

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
    happyEyeballsTryDelayMs = happyEyeballsTryDelayMs.removeWhitespace;
    happyEyeballsInterleave = happyEyeballsInterleave.removeWhitespace;
    happyEyeballsMaxConcurrentTry =
        happyEyeballsMaxConcurrentTry.removeWhitespace;
  }
}
