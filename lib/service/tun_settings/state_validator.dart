import 'dart:io';

import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/tun_settings/interface.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:tuple/tuple.dart';

extension TunSettingsStateValidator on TunSettingsState {
  Future<Tuple2<bool, String>> validate() async {
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

    if ((AppPlatform.isWindows || AppPlatform.isLinux) &&
        !await _selectedInterfaceExists()) {
      return Tuple2(
        false,
        appLocalizationsNoContext().validationInterfaceRequired,
      );
    }

    return const Tuple2(true, "");
  }

  void removeWhitespace() {
    tunDnsIPv4 = tunDnsIPv4.removeWhitespace;
    tunDnsIPv6 = tunDnsIPv6.removeWhitespace;
    dnsServerName = dnsServerName.removeWhitespace;

    outboundsInterface = outboundsInterface.trim();

    for (final rule in onDemandRules) {
      rule.removeWhitespace();
    }

    allowAppList = allowAppList.removeWhitespace;
    disallowAppList = disallowAppList.removeWhitespace;
  }

  Future<bool> _selectedInterfaceExists() async {
    if (outboundsInterface.isEmpty) {
      return false;
    }
    try {
      final interfaces = await queryInterfaceList();
      return interfaces.any((value) => value.name == outboundsInterface);
    } catch (_) {
      return false;
    }
  }
}

extension OnDemandRuleStateValidator on OnDemandRuleState {
  void removeWhitespace() {
    ssid = ssid.removeWhitespace;
  }
}
