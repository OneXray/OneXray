import 'package:onexray/service/xray/outbound/state.dart';

class OutboundUIParams {
  final int id;
  final OutboundState state;
  final List<String> outboundTags;
  final bool saveToDb;
  final String fixedTag;
  final bool editableTag;

  OutboundUIParams(
    this.id,
    this.state,
    this.outboundTags, {
    this.saveToDb = true,
    this.fixedTag = "",
    this.editableTag = false,
  });
}
