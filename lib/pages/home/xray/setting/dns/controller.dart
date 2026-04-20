import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/home/xray/setting/dns/params.dart';
import 'package:onexray/pages/home/xray/setting/dns_hosts/params.dart';
import 'package:onexray/pages/home/xray/setting/dns_server/params.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/service/xray/setting/dns_server_state.dart';
import 'package:onexray/service/xray/setting/dns_state.dart';
import 'package:onexray/service/xray/setting/enum.dart';

class DnsCubitState {
  final DnsState dnsState;
  final int version;

  const DnsCubitState({
    required this.dnsState,
    this.version = 0,
  });

  factory DnsCubitState.initial() => DnsCubitState(
        dnsState: DnsState(),
      );

  DnsCubitState bumped() => DnsCubitState(
        dnsState: dnsState,
        version: version + 1,
      );
}

class DnsController extends Cubit<DnsCubitState> {
  final DnsParams params;
  DnsController(this.params) : super(DnsCubitState.initial()) {
    _initParams();
  }

  void _initParams() {
    emit(DnsCubitState(dnsState: params.state, version: 1));
  }

  void updateQueryStrategy(String value) {
    final queryStrategy = DnsQueryStrategy.fromString(value);
    if (queryStrategy != null) {
      state.dnsState.queryStrategy = queryStrategy; emit(state.bumped());
    }
  }

  void updateDisableCache(bool value) {
    state.dnsState.disableCache = value; emit(state.bumped());
  }

  void updateDisableFallback(bool value) {
    state.dnsState.disableFallback = value; emit(state.bumped());
  }

  void updateDisableFallbackIfMatch(bool value) {
    state.dnsState.disableFallbackIfMatch = value; emit(state.bumped());
  }

  void updateUseSystemHosts(bool value) {
    state.dnsState.useSystemHosts = value; emit(state.bumped());
  }

  Future<void> editHosts(BuildContext context) async {
    final params = DnsHostsParams(state.dnsState.hosts);
    final hosts = await context.push<Map<String, List<String>>>(
      RouterPath.dnsHosts,
      extra: params,
    );
    if (hosts != null) {
      state.dnsState.hosts = hosts; emit(state.bumped());
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
    final server = await context.push<DnsServerState>(
      RouterPath.dnsServer,
      extra: params,
    );
    if (server != null) {
      state.dnsState.servers[index] = server; emit(state.bumped());
    }
  }

  void moreAction(String menuId, int serverIndex) async {
    state.dnsState.servers.removeAt(serverIndex); emit(state.bumped());
  }

  Future<void> save(BuildContext context) async {
    context.pop<DnsState>(state.dnsState);
  }
}
