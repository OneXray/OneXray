import 'dart:io';

import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/tun_setting/state.dart';
import 'package:tuple/tuple.dart';

extension TunSettingStateValidator on TunSettingState {
  Future<Tuple2<bool, String>> validate() async {
    if (!EmptyTool.checkString(tunPriority)) {
      return Tuple2(
        false,
        appLocalizationsNoContext().validationPriorityRequired,
      );
    }
    if (!EmptyTool.checkString(tunDnsIPv4)) {
      return Tuple2(false, appLocalizationsNoContext().validationDnsRequired);
    }

    final ipv4 = InternetAddress.tryParse(tunDnsIPv4);
    if (ipv4 == null) {
      return Tuple2(false, appLocalizationsNoContext().validationIPv4Invalid);
    }

    if (ipv4.type != InternetAddressType.IPv4) {
      return Tuple2(false, appLocalizationsNoContext().validationIPv4Invalid);
    }

    if (!EmptyTool.checkString(tunDnsIPv6)) {
      return Tuple2(false, appLocalizationsNoContext().validationDnsRequired);
    }

    final ipv6 = InternetAddress.tryParse(tunDnsIPv6);
    if (ipv6 == null) {
      return Tuple2(false, appLocalizationsNoContext().validationIPv6Invalid);
    }

    if (ipv6.type != InternetAddressType.IPv6) {
      return Tuple2(false, appLocalizationsNoContext().validationIPv6Invalid);
    }

    if (enableDot) {
      if (!EmptyTool.checkString(dnsServerName)) {
        return Tuple2(false, appLocalizationsNoContext().validationDnsRequired);
      }
    }

    return const Tuple2(true, "");
  }

  void removeWhitespace() {
    tunPriority = tunPriority.removeWhitespace;
    tunDnsIPv4 = tunDnsIPv4.removeWhitespace;
    tunDnsIPv6 = tunDnsIPv6.removeWhitespace;
    dnsServerName = dnsServerName.removeWhitespace;

    bindInterface = bindInterface.removeWhitespace;

    for (final rule in onDemandRules) {
      rule.removeWhitespace();
    }

    allowAppList = allowAppList.removeWhitespace;
    disallowAppList = disallowAppList.removeWhitespace;
  }
}

extension OnDemandRuleStateValidator on OnDemandRuleState {
  void removeWhitespace() {
    ssid = ssid.removeWhitespace;
  }
}
