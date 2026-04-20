import 'package:onexray/service/xray/setting/routing_state.dart';

class RoutingParams {
  final RoutingState state;
  final List<String> outboundTags;

  RoutingParams(this.state, this.outboundTags);
}
