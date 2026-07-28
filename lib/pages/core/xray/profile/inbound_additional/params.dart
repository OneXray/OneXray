import 'package:onexray/service/xray/profile/additional_inbound_state.dart';

class AdditionalInboundParams {
  final AdditionalInboundState state;
  final Set<String> unavailableTags;
  final Set<int> unavailablePorts;

  const AdditionalInboundParams(
    this.state, {
    this.unavailableTags = const <String>{},
    this.unavailablePorts = const <int>{},
  });
}
