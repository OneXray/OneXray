import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/pages/geo_data/list/params.dart';
import 'package:onexray/pages/home/xray/setting/routing_rule/params.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/service/xray/setting/routing_rule_state.dart';

class XrayRuleAttr {
  final key = TextEditingController();
  final value = TextEditingController();
}

class RoutingRuleCubitState {
  final RoutingRuleState ruleState;
  final ruleAttrs = <XrayRuleAttr>[];
  final outboundTags = <String>[];
  final int version;

  RoutingRuleCubitState({required this.ruleState, this.version = 0});

  factory RoutingRuleCubitState.initial() =>
      RoutingRuleCubitState(ruleState: RoutingRuleState());

  RoutingRuleCubitState bumped() =>
      RoutingRuleCubitState(ruleState: ruleState, version: version + 1);
}

class RoutingRuleController extends Cubit<RoutingRuleCubitState> {
  final RoutingRuleParams params;
  RoutingRuleController(this.params) : super(RoutingRuleCubitState.initial()) {
    _initParams();
  }

  @override
  Future<void> close() {
    portController.dispose();
    sourcePortController.dispose();
    localPortController.dispose();
    ruleTagController.dispose();
    for (final controller in domainControllers) {
      controller.dispose();
    }
    for (final controller in ipControllers) {
      controller.dispose();
    }
    for (final controller in sourceIPControllers) {
      controller.dispose();
    }
    for (final controller in localIPControllers) {
      controller.dispose();
    }
    for (final controller in state.ruleAttrs) {
      controller.key.dispose();
      controller.value.dispose();
    }
    return super.close();
  }

  void _initParams() {
    final initS = params.state;
    state.outboundTags.clear();
    state.outboundTags.addAll(params.outboundTags);
    initS.fixOutboundTag(params.outboundTags);
    _initInput(initS);
    _initInputs(initS);
    _initAttrs(initS);
    emit(RoutingRuleCubitState(ruleState: initS, version: 1));
  }

  void _initInput(RoutingRuleState state) {
    portController.text = state.port;
    sourcePortController.text = state.sourcePort;
    localPortController.text = state.localPort;
    ruleTagController.text = state.ruleTag;
  }

  void _initInputs(RoutingRuleState state) {
    final domainControllers = state.domain.map(
      (e) => TextEditingController(text: e),
    );
    this.domainControllers.clear();
    this.domainControllers.addAll(domainControllers);

    final ipControllers = state.ip.map((e) => TextEditingController(text: e));
    this.ipControllers.clear();
    this.ipControllers.addAll(ipControllers);

    final sourceIPControllers = state.sourceIP.map(
      (e) => TextEditingController(text: e),
    );
    this.sourceIPControllers.clear();
    this.sourceIPControllers.addAll(sourceIPControllers);

    final localIPControllers = state.localIP.map(
      (e) => TextEditingController(text: e),
    );
    this.localIPControllers.clear();
    this.localIPControllers.addAll(localIPControllers);
  }

  void _initAttrs(RoutingRuleState ruleState) {
    final attrs = <XrayRuleAttr>[];
    ruleState.attrs.forEach((k, v) {
      final attr = XrayRuleAttr();
      attr.key.text = k;
      attr.value.text = v;
      attrs.add(attr);
    });
    state.ruleAttrs.addAll(attrs);
  }

  final domainControllers = <TextEditingController>[];

  void appendDomain() {
    domainControllers.add(TextEditingController());
    state.ruleState.domain.add("");
    emit(state.bumped());
  }

  Future<void> importDomain(BuildContext context) async {
    final params = GeoDataListParams(
      GeoDataListType.domain,
      GeoDatCodesMode.select,
    );
    final codes = await context.push<Set<String>>(
      RouterPath.geoDataList,
      extra: params,
    );
    if (codes != null) {
      if (codes.isNotEmpty) {
        for (final code in codes) {
          domainControllers.add(TextEditingController(text: code));
        }
        state.ruleState.domain.addAll(codes);
        emit(state.bumped());
      }
    }
  }

  void deleteDomain(BuildContext context, int index) {
    final controller = domainControllers.removeAt(index);
    controller.dispose();
    state.ruleState.domain.removeAt(index);
    emit(state.bumped());
  }

  final ipControllers = <TextEditingController>[];

  void appendIp() {
    ipControllers.add(TextEditingController());
    state.ruleState.ip.add("");
    emit(state.bumped());
  }

  Future<void> importIp(BuildContext context) async {
    final params = GeoDataListParams(
      GeoDataListType.ip,
      GeoDatCodesMode.select,
    );
    final codes = await context.push<Set<String>>(
      RouterPath.geoDataList,
      extra: params,
    );
    if (codes != null) {
      if (codes.isNotEmpty) {
        for (final code in codes) {
          ipControllers.add(TextEditingController(text: code));
        }
        state.ruleState.ip.addAll(codes);
        emit(state.bumped());
      }
    }
  }

  void deleteIp(BuildContext context, int index) {
    final controller = ipControllers.removeAt(index);
    controller.dispose();
    state.ruleState.ip.removeAt(index);
    emit(state.bumped());
  }

  final portController = TextEditingController();
  final sourcePortController = TextEditingController();
  final localPortController = TextEditingController();

  void updateNetwork(String value) {
    final network = RoutingRuleNetwork.fromString(value);
    if (network != null) {
      state.ruleState.network = network;
      emit(state.bumped());
    }
  }

  final sourceIPControllers = <TextEditingController>[];

  void appendSourceIP() {
    sourceIPControllers.add(TextEditingController());
    state.ruleState.sourceIP.add("");
    emit(state.bumped());
  }

  void deleteSourceIP(BuildContext context, int index) {
    final controller = sourceIPControllers.removeAt(index);
    controller.dispose();
    state.ruleState.sourceIP.removeAt(index);
    emit(state.bumped());
  }

  final localIPControllers = <TextEditingController>[];
  void appendLocalIP() {
    localIPControllers.add(TextEditingController());
    state.ruleState.localIP.add("");
    emit(state.bumped());
  }

  void deleteLocalIP(BuildContext context, int index) {
    final controller = localIPControllers.removeAt(index);
    controller.dispose();
    state.ruleState.localIP.removeAt(index);
    emit(state.bumped());
  }

  void updateInboundTag(bool selected, String value) {
    if (selected) {
      state.ruleState.inboundTag.add(value);
    } else {
      state.ruleState.inboundTag.remove(value);
    }
    emit(state.bumped());
  }

  void updateProtocol(bool selected, RoutingRuleProtocol value) {
    if (selected) {
      state.ruleState.protocol.add(value);
    } else {
      state.ruleState.protocol.remove(value);
    }
    emit(state.bumped());
  }

  void appendAttr() {
    state.ruleAttrs.add(XrayRuleAttr());
  }

  final ruleTagController = TextEditingController();

  void updateOutboundTag(String value) {
    state.ruleState.outboundTag = value;
    if (value.isNotEmpty) {
      state.ruleState.balancerTag = "";
    }
    emit(state.bumped());
  }

  void save(BuildContext context) {
    _mergeInputToState(state.ruleState);
    emit(state.bumped());
    context.pop<RoutingRuleState>(state.ruleState);
  }

  void _mergeInputToState(RoutingRuleState state) {
    _mergeInput(state);
    _mergeInputs(state);
    _mergeAttrs(state);

    state.removeWhitespace();
  }

  void _mergeInput(RoutingRuleState state) {
    state.port = portController.text;
    state.sourcePort = sourcePortController.text;
    state.localPort = localPortController.text;
    state.ruleTag = ruleTagController.text;
  }

  void _mergeInputs(RoutingRuleState state) {
    state.domain = domainControllers.map((c) => c.text).toList();
    state.ip = ipControllers.map((c) => c.text).toList();
    state.sourceIP = sourceIPControllers.map((c) => c.text).toList();
    state.localIP = localIPControllers.map((c) => c.text).toList();
  }

  void _mergeAttrs(RoutingRuleState ruleState) {
    final newAttrs = <String, String>{};
    for (final attr in state.ruleAttrs) {
      final key = attr.key.text.removeWhitespace;
      if (key.isNotEmpty) {
        final value = attr.value.text.removeWhitespace;
        if (value.isNotEmpty) {
          newAttrs[key] = value;
        }
      }
    }
    ruleState.attrs = newAttrs;
  }
}
