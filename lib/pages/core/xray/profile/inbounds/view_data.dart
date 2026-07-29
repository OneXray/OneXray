import 'package:flutter/widgets.dart';
import 'package:onexray/service/xray/profile/additional_inbound_state.dart';

final class InboundsViewData {
  final List<AdditionalInboundMenuItemViewData> addItems;
  final List<AdditionalInboundRowViewData> additionalRows;

  const InboundsViewData({
    required this.addItems,
    required this.additionalRows,
  });
}

final class AdditionalInboundMenuItemViewData {
  final AdditionalInboundType type;
  final String title;

  const AdditionalInboundMenuItemViewData({
    required this.type,
    required this.title,
  });
}

final class AdditionalInboundRowViewData {
  final int index;
  final IconData icon;
  final String title;
  final String subtitle;

  const AdditionalInboundRowViewData({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
