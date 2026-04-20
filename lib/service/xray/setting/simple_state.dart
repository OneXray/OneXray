import 'package:collection/collection.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/simple_state_model.dart';

class XraySettingSimple {
  static const simpleId = -1;
  static const simpleName = "Simple";
  var routing = SimpleRouting();
  var dns = SimpleDns.cloudflareProxy;
  var enableLog = false;

  Future<void> readFromPreferences() async {
    final jsonMap = await PreferencesKey().readXraySettingSimple();
    if (!EmptyTool.checkMap(jsonMap)) {
      return;
    }
    final model = XraySettingSimpleModel.fromJson(jsonMap!);
    routing.readFromModel(model);
    if (model.dnsId != null) {
      dns = SimpleDns.fromInt(model.dnsId!);
    }
    if (model.enableLog != null) {
      enableLog = model.enableLog!;
    }
  }

  Future<void> saveToPreferences() async {
    await PreferencesKey().saveXraySettingSimple(_model.toJson());
  }

  XraySettingSimpleModel get _model =>
      XraySettingSimpleModel(routing.model, dns.id, enableLog);
}

class SimpleRouting {
  var domainStrategy = RoutingDomainStrategy.ipIfNonMatch;
  var queryStrategy = DnsQueryStrategy.useIPv4;
  var directSet = SimpleCountry.cn;
  var appleDirect = true;
  var localDirect = true;
  var enableIPRule = true;
  var localDns = true;

  void readFromModel(XraySettingSimpleModel model) {
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
    if (EmptyTool.checkString(routing.queryStrategy)) {
      final queryStrategy = DnsQueryStrategy.fromString(routing.queryStrategy!);
      if (queryStrategy != null) {
        this.queryStrategy = queryStrategy;
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
  }

  SimpleRoutingModel get model => SimpleRoutingModel(
    domainStrategy.name,
    queryStrategy.name,
    directSet.name,
    appleDirect,
    localDirect,
    enableIPRule,
    localDns,
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
  cloudflareDirect(1),
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
      case SimpleDns.cloudflareDirect:
        return _SimpleDnsAddress.cloudflare.name;
      case SimpleDns.cloudflareDoH:
        return _SimpleDnsAddress.cloudflareDoH.name;
    }
  }

  RoutingOutboundTag get outbound {
    switch (this) {
      case SimpleDns.cloudflareDirect:
        return RoutingOutboundTag.direct;
      case SimpleDns.cloudflareProxy:
      case SimpleDns.cloudflareDoH:
        return RoutingOutboundTag.proxy;
    }
  }

  String get nonIPQueryDns {
    switch (this) {
      case SimpleDns.cloudflareProxy:
      case SimpleDns.cloudflareDirect:
        return _SimpleDnsAddress.cloudflare.name;
      case SimpleDns.cloudflareDoH:
        return _SimpleDnsAddress.cloudflareDoH.name;
    }
  }
}
