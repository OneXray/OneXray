import 'package:onexray/service/xray/outbound/enum.dart';

class XhttpDownloadState {
  var address = "";
  var port = "";

  final network = StreamSettingsNetwork.xhttp;

  var xhttpHost = "";
  var xhttpPath = "";
  var xhttpMode = XhttpMode.auto;

  var security = StreamSettingsSecurity.tls;
  var serverName = "";
  var alpn = <StreamSettingsSecurityALPN>{};
  var fingerprint = StreamSettingsSecurityFingerprint.none;
  var pinnedPeerCertSha256 = "";
  var verifyPeerCertByName = "";
  var echConfigList = "";
  var echForceQuery = StreamSettingsEchForceQuery.full;
  var password = "";
  var shortId = "";
  var mldsa65Verify = "";
  var spiderX = "";

  var headers = <String, String>{};
  var xPaddingBytes = "";
  var noGRPCHeader = false;
  var scMaxEachPostBytes = "";
  var scMinPostsIntervalMs = "";

  var maxConcurrency = "0";
  var maxConnections = "0";
  var cMaxReuseTimes = "0";
  var hMaxReusableSecs = "0";
  var hMaxRequestTimes = "0";
  var hKeepAlivePeriod = "0";
}
