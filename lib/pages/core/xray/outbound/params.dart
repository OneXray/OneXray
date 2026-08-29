class OutboundUIParams {
  final int id;
  final Map<String, dynamic> outbound;
  final bool saveToDb;
  final String fixedTag;

  OutboundUIParams(
    this.id,
    this.outbound, {
    this.saveToDb = true,
    this.fixedTag = "",
  });
}
