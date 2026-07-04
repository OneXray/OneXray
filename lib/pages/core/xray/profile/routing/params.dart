import 'package:onexray/service/xray/profile/routing_state.dart';

class RoutingParams {
  final RoutingState state;
  final List<String> outboundTags;
  final List<String> inboundTags;

  RoutingParams(this.state, this.outboundTags, this.inboundTags);
}
