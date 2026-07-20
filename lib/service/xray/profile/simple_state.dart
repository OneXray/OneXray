import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/simple_state_model.dart';

class XrayProfileSimple {
  static const simpleId = -1;
  static const simpleName = "Simple";
  var routing = SimpleRouting();
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
    directSet.name,
    appleDirect,
    localDirect,
    enableIPRule,
    localDns,
    blockAds,
  );
}
