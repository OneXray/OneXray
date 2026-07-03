import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/core/xray/profile/dns/params.dart';
import 'package:onexray/pages/core/xray/profile/dns_hosts/params.dart';
import 'package:onexray/pages/core/xray/profile/dns_server/params.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/xray/profile/dns_server_state.dart';
import 'package:onexray/service/xray/profile/dns_state.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/pages/main/navigation.dart';

class DnsPageState {
  final DnsState dnsState;
  final int version;

  const DnsPageState({required this.dnsState, this.version = 0});

  factory DnsPageState.initial() => DnsPageState(dnsState: DnsState());

  DnsPageState bumped() =>
      DnsPageState(dnsState: dnsState, version: version + 1);
}

class DnsController extends Cubit<DnsPageState> {
  final DnsParams params;
  DnsController(this.params) : super(DnsPageState.initial()) {
    _initParams();
  }

  @override
  Future<void> close() {
    clientIpController.dispose();
    serveExpiredTTLController.dispose();
    return super.close();
  }

  void _initParams() {
    _initInput(params.state);
    emit(DnsPageState(dnsState: params.state, version: 1));
  }

  void _initInput(DnsState state) {
    clientIpController.text = state.clientIp;
    serveExpiredTTLController.text = state.serveExpiredTTL;
  }

  final clientIpController = TextEditingController();
  final serveExpiredTTLController = TextEditingController();

  void updateQueryStrategy(String value) {
    final queryStrategy = DnsQueryStrategy.fromString(value);
    if (queryStrategy != null) {
      state.dnsState.queryStrategy = queryStrategy;
      emit(state.bumped());
    }
  }

  void updateDisableCache(bool value) {
    state.dnsState.disableCache = value;
    emit(state.bumped());
  }

  void updateServeStale(bool value) {
    state.dnsState.serveStale = value;
    emit(state.bumped());
  }

  void updateDisableFallback(bool value) {
    state.dnsState.disableFallback = value;
    emit(state.bumped());
  }

  void updateDisableFallbackIfMatch(bool value) {
    state.dnsState.disableFallbackIfMatch = value;
    emit(state.bumped());
  }

  void updateEnableParallelQuery(bool value) {
    state.dnsState.enableParallelQuery = value;
    emit(state.bumped());
  }

  void updateUseSystemHosts(bool value) {
    state.dnsState.useSystemHosts = value;
    emit(state.bumped());
  }

  Future<void> editHosts(BuildContext context) async {
    final params = DnsHostsParams(state.dnsState.hosts);
    final hosts = await context.pushScoped<Map<String, List<String>>>(
      AppSecondaryDestination.dnsHosts,
      extra: params,
    );
    if (hosts != null) {
      state.dnsState.hosts = hosts;
      emit(state.bumped());
    }
  }

  void appendServer() {
    state.dnsState.servers.add(DnsServerState());
    emit(state.bumped());
  }

  void sortServer(int oldIndex, int newIndex) {
    final servers = state.dnsState.servers;
    final server = servers.removeAt(oldIndex);
    var index = newIndex;
    if (newIndex > oldIndex) {
      index = newIndex - 1;
    }
    servers.insert(index, server);
    state.dnsState.servers = servers;
    emit(state.bumped());
  }

  Future<void> editServer(BuildContext context, int index) async {
    final params = DnsServerParams(state.dnsState.servers[index]);
    final server = await context.pushScoped<DnsServerState>(
      AppSecondaryDestination.dnsServer,
      extra: params,
    );
    if (server != null) {
      state.dnsState.servers[index] = server;
      emit(state.bumped());
    }
  }

  void moreAction(IconMenuId menuId, int serverIndex) async {
    state.dnsState.servers.removeAt(serverIndex);
    emit(state.bumped());
  }

  Future<void> save(BuildContext context) async {
    _mergeInputToState(state.dnsState);
    context.pop<DnsState>(state.dnsState);
  }

  void _mergeInputToState(DnsState state) {
    state.clientIp = clientIpController.text;
    state.serveExpiredTTL = serveExpiredTTLController.text;
    state.removeWhitespace();
  }
}
