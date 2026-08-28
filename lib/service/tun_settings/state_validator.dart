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
    InternetAddress? tunAddressIPv4;
    InternetAddress? tunAddressIPv6;
    if (AppPlatform.isWindows) {
      tunAddressIPv4 = InternetAddress.tryParse(tunIPv4);
      if (tunAddressIPv4 == null ||
          tunAddressIPv4.type != InternetAddressType.IPv4) {
        return Tuple2(false, appLocalizationsNoContext().validationIPv4Invalid);
      }
      tunAddressIPv6 = InternetAddress.tryParse(tunIPv6);
      if (tunAddressIPv6 == null ||
          tunAddressIPv6.type != InternetAddressType.IPv6) {
        return Tuple2(false, appLocalizationsNoContext().validationIPv6Invalid);
      }
    }

    if (!EmptyTool.checkString(tunDnsIPv4)) {
      return Tuple2(false, appLocalizationsNoContext().validationDnsRequired);
    }

    final ipv4 = InternetAddress.tryParse(tunDnsIPv4);
    if (ipv4 == null) {
      return Tuple2(false, appLocalizationsNoContext().validationIPv4Invalid);
    }

    if (ipv4.type != InternetAddressType.IPv4 ||
        ipv4.address == tunAddressIPv4?.address) {
      return Tuple2(false, appLocalizationsNoContext().validationIPv4Invalid);
    }

    if (!EmptyTool.checkString(tunDnsIPv6)) {
      return Tuple2(false, appLocalizationsNoContext().validationDnsRequired);
    }

    final ipv6 = InternetAddress.tryParse(tunDnsIPv6);
    if (ipv6 == null) {
      return Tuple2(false, appLocalizationsNoContext().validationIPv6Invalid);
    }

    if (ipv6.type != InternetAddressType.IPv6 ||
        ipv6.address == tunAddressIPv6?.address) {
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
    tunIPv4 = tunIPv4.removeWhitespace;
    tunIPv6 = tunIPv6.removeWhitespace;
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
