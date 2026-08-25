class OutboundUIParams {
  final int id;
  final Map<String, dynamic> outbound;
  final bool saveToDb;
  final String fixedTag;
  final bool editableTag;

  OutboundUIParams(
    this.id,
    this.outbound, {
    this.saveToDb = true,
    this.fixedTag = "",
    this.editableTag = false,
  });
}
