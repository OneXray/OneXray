import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/outbound/xhttp/state.dart';

class OutboundXhttpParams {
  final XhttpMode mode;
  final XhttpExtraState state;

  OutboundXhttpParams(this.mode, this.state);
}
