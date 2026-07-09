import 'package:collection/collection.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/simple_state_model.dart';

class XrayProfileSimple {
  static const simpleId = -1;
  static const simpleName = "Simple";
  var routing = SimpleRouting();
  var dns = SimpleDns.cloudflareProxy;
  var enableLog = false;
  var fakeDns = false;
  int? finalOutboundId;

  Future<void> readFromPreferences() async {
    final jsonMap = await PreferencesKey().readXrayProfileSimple();
    if (!EmptyTool.checkMap(jsonMap)) {
      return;
    }
    final model = XrayProfileSimpleModel.fromJson(jsonMap!);
    routing.readFromModel(model);
    if (model.dnsId != null) {
      dns = SimpleDns.fromInt(model.dnsId!);
    }
    if (model.enableLog != null) {
      enableLog = model.enableLog!;
    }
    if (model.fakeDns != null) {
      fakeDns = model.fakeDns!;
    }
    if (model.finalOutboundId != null) {
      finalOutboundId = model.finalOutboundId;
    }
  }

  Future<void> saveToPreferences() async {
    await PreferencesKey().saveXrayProfileSimple(_model.toJson());
  }

  XrayProfileSimpleModel get _model => XrayProfileSimpleModel(
    routing.model,
    dns.id,
    enableLog,
    fakeDns,
    finalOutboundId,
  );
}

class SimpleRouting {
  var domainStrategy = RoutingDomainStrategy.ipIfNonMatch;
  var directSet = SimpleCountry.cn;
  var appleDirect = true;
  var localDirect = true;
  var enableIPRule = true;
  var localDns = true;
  var blockAds = false;

  void readFromModel(XrayProfileSimpleModel model) {
    if (model.routing == null) {
      return;
    }
    final routing = model.routing!;

    if (EmptyTool.checkString(routing.domainStrategy)) {
      final domainStrategy = RoutingDomainStrategy.fromString(
        routing.domainStrategy!,
      );
      if (domainStrategy != null) {
        this.domainStrategy = domainStrategy;
      }
    }
    if (EmptyTool.checkString(routing.directSet)) {
      final directSet = SimpleCountry.fromString(routing.directSet!);
      if (directSet != null) {
        this.directSet = directSet;
      }
    }
    if (routing.appleDirect != null) {
      appleDirect = routing.appleDirect!;
    }
    if (routing.localDirect != null) {
      localDirect = routing.localDirect!;
    }
    if (routing.enableIPRule != null) {
      enableIPRule = routing.enableIPRule!;
    }
    if (routing.localDns != null) {
      localDns = routing.localDns!;
    }
    if (routing.blockAds != null) {
      blockAds = routing.blockAds!;
    }
  }

  SimpleRoutingModel get model => SimpleRoutingModel(
    domainStrategy.name,
    null,
    directSet.name,
    appleDirect,
    localDirect,
    enableIPRule,
    localDns,
    blockAds,
  );
}

enum _SimpleDnsAddress {
  cloudflare("tcp://1.1.1.1"),
  cloudflareDoH("https://1.1.1.1/dns-query");

  const _SimpleDnsAddress(this.name);

  final String name;

  @override
  String toString() => name;
}

enum SimpleDns {
  cloudflareProxy(0),
  cloudflareDoH(2);

  const SimpleDns(this.id);

  final int id;

  @override
  String toString() => id.toString();

  static SimpleDns fromInt(int? id) {
    if (id == null) {
      return SimpleDns.cloudflareProxy;
    }
    final dns = SimpleDns.values.firstWhereOrNull((e) => e.id == id);
    return dns ?? SimpleDns.cloudflareProxy;
  }

  static List<int> get ids {
    return SimpleDns.values.map((e) => e.id).toList();
  }

  String get address {
    switch (this) {
      case SimpleDns.cloudflareProxy:
        return _SimpleDnsAddress.cloudflare.name;
      case SimpleDns.cloudflareDoH:
        return _SimpleDnsAddress.cloudflareDoH.name;
    }
  }

  RoutingOutboundTag get outbound {
    return RoutingOutboundTag.proxy;
  }
}
