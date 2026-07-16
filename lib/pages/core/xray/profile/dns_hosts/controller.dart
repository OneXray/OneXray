import 'package:onexray/core/tools/extensions.dart';
import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/core/xray/profile/dns_hosts/params.dart';

class XrayHostAddress {
  final host = TextEditingController();
  final address = <TextEditingController>[];
}

class DnsHostsPageState {
  final List<XrayHostAddress> hosts;
  final int version;

  DnsHostsPageState({required this.hosts, this.version = 0});

  factory DnsHostsPageState.initial() => DnsHostsPageState(hosts: []);

  DnsHostsPageState bumped() =>
      DnsHostsPageState(hosts: hosts, version: version + 1);
}

class DnsHostsController extends PageCubit<DnsHostsPageState> {
  final DnsHostsParams params;
  DnsHostsController(this.params) : super(DnsHostsPageState.initial()) {
    _initParams();
  }

  @override
  Future<void> disposePageResources() async {
    for (final host in state.hosts) {
      host.host.dispose();
      for (final address in host.address) {
        address.dispose();
      }
    }
  }

  void _initParams() {
    final hostAddresses = <XrayHostAddress>[];
    final hosts = params.hosts;
    hosts.forEach((k, v) {
      final hostAddress = XrayHostAddress();
      hostAddress.host.text = k;
      final address = v.map((s) => TextEditingController(text: s)).toList();
      hostAddress.address.clear();
      hostAddress.address.addAll(address);
      hostAddresses.add(hostAddress);
    });
    emit(DnsHostsPageState(hosts: hostAddresses, version: 1));
  }

  void appendHostAddress() {
    state.hosts.add(XrayHostAddress());
    emit(state.bumped());
  }

  void deleteHostAddress(BuildContext context, int index) {
    final host = state.hosts.removeAt(index);
    host.host.dispose();
    for (final address in host.address) {
      address.dispose();
    }
    emit(state.bumped());
  }

  void appendAddress(BuildContext context, int hostIndex) {
    state.hosts[hostIndex].address.add(TextEditingController());
    emit(state.bumped());
  }

  void deleteAddress(BuildContext context, int hostIndex, int addressIndex) {
    final address = state.hosts[hostIndex].address.removeAt(addressIndex);
    address.dispose();
    emit(state.bumped());
  }

  Future<void> save(BuildContext context) async {
    final newHosts = <String, List<String>>{};
    for (final hostAddress in state.hosts) {
      final key = hostAddress.host.text.removeWhitespace;
      if (key.isNotEmpty) {
        final values = <String>[];
        for (final controller in hostAddress.address) {
          final value = controller.text.removeWhitespace;
          if (value.isNotEmpty) {
            values.add(value);
          }
        }
        if (values.isNotEmpty) {
          newHosts[key] = values;
        }
      }
    }
    context.pop<Map<String, List<String>>>(newHosts);
  }
}
