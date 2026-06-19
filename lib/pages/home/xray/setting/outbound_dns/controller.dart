import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/pages/home/xray/setting/outbound_dns/params.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/outbounds_state.dart';

class OutboundDnsCubitState {
  final OutboundDnsState dnsState;
  final int version;

  OutboundDnsCubitState({required this.dnsState, this.version = 0});

  factory OutboundDnsCubitState.initial() =>
      OutboundDnsCubitState(dnsState: OutboundDnsState());

  OutboundDnsCubitState bumped() =>
      OutboundDnsCubitState(dnsState: dnsState, version: version + 1);
}

class OutboundDnsController extends Cubit<OutboundDnsCubitState> {
  final OutboundDnsParams params;
  OutboundDnsController(this.params) : super(OutboundDnsCubitState.initial()) {
    _initParams();
  }

  @override
  Future<void> close() {
    addressController.dispose();
    portController.dispose();
    for (final controller in ruleQTypeControllers) {
      controller.dispose();
    }
    for (final controller in ruleDomainControllers) {
      controller.dispose();
    }
    for (final controller in ruleRCodeControllers) {
      controller.dispose();
    }
    return super.close();
  }

  void _initParams() {
    final initS = params.state;
    _initInput(initS);
    _initRuleInputs(initS);
    emit(OutboundDnsCubitState(dnsState: initS, version: 1));
  }

  void _initInput(OutboundDnsState state) {
    addressController.text = state.address;
    portController.text = state.port;
  }

  void _initRuleInputs(OutboundDnsState state) {
    ruleQTypeControllers.clear();
    ruleDomainControllers.clear();
    ruleRCodeControllers.clear();
    for (final rule in state.rules) {
      ruleQTypeControllers.add(TextEditingController(text: rule.qType ?? ""));
      ruleDomainControllers.add(
        TextEditingController(text: _domainText(rule.domain)),
      );
      ruleRCodeControllers.add(
        TextEditingController(text: rule.rCode?.toString() ?? ""),
      );
    }
  }

  void updateNetwork(String value) {
    final network = DnsNetwork.fromString(value);
    if (network != null) {
      state.dnsState.network = network;
      emit(state.bumped());
    }
  }

  final addressController = TextEditingController();
  final portController = TextEditingController();

  final ruleQTypeControllers = <TextEditingController>[];
  final ruleDomainControllers = <TextEditingController>[];
  final ruleRCodeControllers = <TextEditingController>[];

  void appendRule() {
    state.dnsState.rules.add(
      XrayOutboundDnsRule(DnsOutboundRuleAction.direct.name, null, null, null),
    );
    ruleQTypeControllers.add(TextEditingController());
    ruleDomainControllers.add(TextEditingController());
    ruleRCodeControllers.add(TextEditingController());
    emit(state.bumped());
  }

  void deleteRule(int index) {
    state.dnsState.rules.removeAt(index);
    ruleQTypeControllers.removeAt(index).dispose();
    ruleDomainControllers.removeAt(index).dispose();
    ruleRCodeControllers.removeAt(index).dispose();
    emit(state.bumped());
  }

  void sortRule(int oldIndex, int index) {
    final rule = state.dnsState.rules.removeAt(oldIndex);
    state.dnsState.rules.insert(index, rule);
    _moveController(ruleQTypeControllers, oldIndex, index);
    _moveController(ruleDomainControllers, oldIndex, index);
    _moveController(ruleRCodeControllers, oldIndex, index);
    emit(state.bumped());
  }

  void updateRuleAction(int index, String value) {
    final action = DnsOutboundRuleAction.fromString(value);
    if (action != null) {
      state.dnsState.rules[index].action = action.name;
      emit(state.bumped());
    }
  }

  void save(BuildContext context) {
    _mergeInputToState(state.dnsState);
    emit(state.bumped());
    context.pop<OutboundDnsState>(state.dnsState);
  }

  void _mergeInputToState(OutboundDnsState state) {
    _mergeInput(state);
    _mergeRules(state);

    state.removeWhitespace();
  }

  void _mergeInput(OutboundDnsState state) {
    state.address = addressController.text;
    state.port = portController.text;
  }

  void _mergeRules(OutboundDnsState state) {
    final rules = <XrayOutboundDnsRule>[];
    for (var index = 0; index < state.rules.length; index++) {
      final rule = state.rules[index];
      final action = DnsOutboundRuleAction.fromString(rule.action ?? "");
      rules.add(
        XrayOutboundDnsRule(
          action?.name ?? DnsOutboundRuleAction.direct.name,
          _emptyToNull(ruleQTypeControllers[index].text.removeWhitespace),
          _domainFromText(ruleDomainControllers[index].text),
          int.tryParse(ruleRCodeControllers[index].text.removeWhitespace),
        ),
      );
    }
    state.rules = rules;
  }

  void _moveController(
    List<TextEditingController> controllers,
    int oldIndex,
    int index,
  ) {
    final controller = controllers.removeAt(oldIndex);
    controllers.insert(index, controller);
  }

  Object? _domainFromText(String text) {
    final domains = text
        .split(RegExp(r'[,\n]'))
        .map((domain) => domain.trim())
        .where((domain) => domain.isNotEmpty)
        .toList();
    if (domains.isEmpty) {
      return null;
    }
    if (domains.length == 1) {
      return domains.first;
    }
    return domains;
  }

  String _domainText(Object? domain) {
    if (domain == null) {
      return "";
    }
    if (domain is List) {
      return domain.join(", ");
    }
    return domain.toString();
  }

  String? _emptyToNull(String value) {
    if (value.isEmpty) {
      return null;
    }
    return value;
  }
}
