import 'package:onexray/service/xray/outbound/state.dart';

class OutboundUIParams {
  final int id;
  final OutboundState state;
  final List<String> outboundTags;

  OutboundUIParams(this.id, this.state, this.outboundTags);
}
