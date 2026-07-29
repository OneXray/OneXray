final class AdditionalInboundViewData {
  final String pageTitle;
  final AdditionalInboundListenerViewData listener;
  final bool showsAuthentication;
  final bool showsUdp;
  final AdditionalInboundTargetViewData? target;

  const AdditionalInboundViewData({
    required this.pageTitle,
    required this.listener,
    required this.showsAuthentication,
    required this.showsUdp,
    required this.target,
  });
}

final class AdditionalInboundListenerViewData {
  final bool editable;
  final String value;
  final String displayValue;
  final String? warning;
  final String protocolName;
  final List<AdditionalInboundOptionViewData> options;

  const AdditionalInboundListenerViewData({
    required this.editable,
    required this.value,
    required this.displayValue,
    required this.warning,
    required this.protocolName,
    required this.options,
  });
}

final class AdditionalInboundTargetViewData {
  final String network;
  final List<AdditionalInboundOptionViewData> networkOptions;

  const AdditionalInboundTargetViewData({
    required this.network,
    required this.networkOptions,
  });
}

final class AdditionalInboundOptionViewData {
  final String value;
  final String title;

  const AdditionalInboundOptionViewData({
    required this.value,
    required this.title,
  });
}
