import 'package:onexray/service/xray/profile/outbounds_state.dart';

class XrayFullConfigOutboundsParams {
  final OutboundsState state;

  XrayFullConfigOutboundsParams(this.state);
}

class XrayFullConfigOutboundsResult {
  final OutboundsState outbounds;
  final Map<String, String> tagRenames;

  XrayFullConfigOutboundsResult(this.outbounds, this.tagRenames);
}
