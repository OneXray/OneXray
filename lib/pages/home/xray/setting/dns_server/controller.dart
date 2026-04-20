import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/geo_data/list/params.dart';
import 'package:onexray/pages/home/xray/setting/dns_server/params.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/service/xray/setting/dns_server_state.dart';
import 'package:onexray/service/xray/setting/enum.dart';

class DnsServerCubitState {
  final DnsServerState serverState;
  final int version;

  DnsServerCubitState({
    required this.serverState,
    this.version = 0,
  });

  factory DnsServerCubitState.initial() => DnsServerCubitState(
        serverState: DnsServerState(),
      );

  DnsServerCubitState bumped() => DnsServerCubitState(
        serverState: serverState,
        version: version + 1,
      );
}

class DnsServerController extends Cubit<DnsServerCubitState> {
  final DnsServerParams params;
  DnsServerController(this.params) : super(DnsServerCubitState.initial()) {
    _initParams();
  }

  @override
  Future<void> close() {
    addressController.dispose();
    portController.dispose();
    tagController.dispose();

    for (final controller in domainsControllers) {
      controller.dispose();
    }
    for (final controller in expectedIPsControllers) {
      controller.dispose();
    }
    for (final controller in unexpectedIPsControllers) {
      controller.dispose();
    }
    return super.close();
  }

  void _initParams() {
    final initS = params.state;
    _initInput(initS);
    _initInputs(initS);
    emit(DnsServerCubitState(serverState: initS, version: 1));
  }

  void _initInput(DnsServerState state) {
    addressController.text = state.address;
    portController.text = state.port;
    tagController.text = state.tag;
  }

  void _initInputs(DnsServerState state) {
    final domainsControllers = state.domains.map(
      (e) => TextEditingController(text: e),
    );
    this.domainsControllers.clear();
    this.domainsControllers.addAll(domainsControllers);

    final expectedIPsControllers = state.expectedIPs.map(
      (e) => TextEditingController(text: e),
    );
    this.expectedIPsControllers.clear();
    this.expectedIPsControllers.addAll(expectedIPsControllers);

    final unexpectedIPsControllers = state.unexpectedIPs.map(
      (e) => TextEditingController(text: e),
    );
    this.unexpectedIPsControllers.clear();
    this.unexpectedIPsControllers.addAll(unexpectedIPsControllers);
  }

  final addressController = TextEditingController();
  final portController = TextEditingController();

  void updateSkipFallback(bool value) {
    state.serverState.skipFallback = value; emit(state.bumped());
  }

  final domainsControllers = <TextEditingController>[];

  void appendDomains() {
    domainsControllers.add(TextEditingController());
    state.serverState.domains.add("");
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
          domainsControllers.add(TextEditingController(text: code));
        }
        state.serverState.domains.addAll(codes); emit(state.bumped());
      }
    }
  }

  void deleteDomains(BuildContext context, int index) {
    final controller = domainsControllers.removeAt(index);
    controller.dispose();
    state.serverState.domains.removeAt(index); emit(state.bumped());
  }

  final expectedIPsControllers = <TextEditingController>[];

  void appendExpectedIPs() {
    expectedIPsControllers.add(TextEditingController());
    state.serverState.expectedIPs.add("");
    emit(state.bumped());
  }

  Future<void> importExpectedIPs(BuildContext context) async {
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
          expectedIPsControllers.add(TextEditingController(text: code));
        }
        state.serverState.expectedIPs.addAll(codes); emit(state.bumped());
      }
    }
  }

  void deleteExpectedIPs(BuildContext context, int index) {
    final controller = expectedIPsControllers.removeAt(index);
    controller.dispose();
    state.serverState.expectedIPs.removeAt(index); emit(state.bumped());
  }

  final unexpectedIPsControllers = <TextEditingController>[];

  void appendUnexpectedIPs() {
    unexpectedIPsControllers.add(TextEditingController());
    state.serverState.unexpectedIPs.add("");
    emit(state.bumped());
  }

  Future<void> importUnexpectedIPs(BuildContext context) async {
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
          unexpectedIPsControllers.add(TextEditingController(text: code));
        }
        state.serverState.unexpectedIPs.addAll(codes); emit(state.bumped());
      }
    }
  }

  void deleteUnexpectedIPs(BuildContext context, int index) {
    final controller = unexpectedIPsControllers.removeAt(index);
    controller.dispose();
    state.serverState.unexpectedIPs.removeAt(index); emit(state.bumped());
  }

  void updateQueryStrategy(String value) {
    final queryStrategy = DnsQueryStrategy.fromString(value);
    if (queryStrategy != null) {
      state.serverState.queryStrategy = queryStrategy; emit(state.bumped());
    }
  }

  final tagController = TextEditingController();

  void updateDisableCache(bool value) {
    state.serverState.disableCache = value; emit(state.bumped());
  }

  void updateFinalQuery(bool value) {
    state.serverState.finalQuery = value; emit(state.bumped());
  }

  void save(BuildContext context) {
    _mergeInputToState(state.serverState);
    emit(state.bumped());
    context.pop<DnsServerState>(state.serverState);
  }

  void _mergeInputToState(DnsServerState state) {
    _mergeInput(state);
    _mergeInputs(state);

    state.removeWhitespace();
  }

  void _mergeInput(DnsServerState state) {
    state.address = addressController.text;
    state.port = portController.text;
    state.tag = tagController.text;
  }

  void _mergeInputs(DnsServerState state) {
    state.domains = domainsControllers.map((c) => c.text).toList();
    state.expectedIPs = expectedIPsControllers.map((c) => c.text).toList();
    state.unexpectedIPs = unexpectedIPsControllers.map((c) => c.text).toList();
  }
}
