import 'package:onexray/service/xray/profile/outbounds_state.dart';

class OutboundDnsParams {
  final OutboundDnsState state;
  final List<String> outboundTags;

  OutboundDnsParams(this.state, this.outboundTags);
}
