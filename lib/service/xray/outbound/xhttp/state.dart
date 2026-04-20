import 'package:onexray/service/xray/outbound/xhttp/download/state.dart';

class XhttpExtraState {
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

  var downloadSettings = XhttpDownloadState();
}
