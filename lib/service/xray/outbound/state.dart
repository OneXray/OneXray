import 'package:onexray/service/xray/constants.dart';
import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/setting/enum.dart';

class OutboundState {
  var name = XrayStateConstants.defaultName;

  var protocol = XrayOutboundProtocol.vless;

  // settings
  var address = "";
  var port = "";

  var vlessId = "";
  var vlessEncryption = "none";
  var vlessFlow = VLESSFlow.none;
  var vlessReverseTag = "";

  var vmessId = "";
  var vmessSecurity = VMessSecurity.auto;

  var shadowsocksMethod = ShadowsocksMethod.none;
  var shadowsocksPassword = "";

  var trojanPassword = "";

  var socksUser = "";
  var socksPass = "";

  var httpUser = "";
  var httpPass = "";
  var httpHeaders = <String, String>{};

  var tag = RoutingOutboundTag.proxy.name;
  var targetStrategy = XrayDomainStrategy.asIs;

  var network = StreamSettingsNetwork.raw;

  var rawHeaderType = RawHeaderType.none;
  var rawPath = <String>[];
  var rawHost = <String>[];

  var xhttpHost = "";
  var xhttpPath = "";
  var xhttpMode = XhttpMode.auto;
  var xhttpExtra = <String, dynamic>{};

  var grpcAuthority = "";
  var grpcServiceName = "";
  var grpcMultiMode = false;

  var wsPath = "";
  var wsHost = "";

  var httpupgradeHost = "";
  var httpupgradePath = "";

  final hysteriaVersion = "2";
  var hysteriaAuth = "";

  var finalMask = <String, dynamic>{};

  var security = StreamSettingsSecurity.none;
  var serverName = "";
  var alpn = <StreamSettingsSecurityALPN>{};
  var fingerprint = StreamSettingsSecurityFingerprint.none;
  var pinnedPeerCertSha256 = "";
  var verifyPeerCertByName = "";
  var echConfigList = "";
  var password = "";
  var shortId = "";
  var mldsa65Verify = "";
  var spiderX = "";

  var muxEnabled = false;
  var muxConcurrency = "8";
  var muxXudpConcurrency = "128";
  var muxXudpProxyUDP443 = MuxXudpProxyUDP443.reject;

  // sockopt
  var tcpFastOpen = false;
  var sockoptDomainStrategy = XrayDomainStrategy.asIs;
  var v6only = false;
  var dialerProxy = "";
  var interface = "";
  var tcpMptcp = false;
  var addressPortStrategy = AddressPortStrategy.none;
  var happyEyeballsEnabled = false;
  var happyEyeballsPrioritizeIPv6 = false;
  var happyEyeballsTryDelayMs = "0";
  var happyEyeballsInterleave = "1";
  var happyEyeballsMaxConcurrentTry = "4";
}
