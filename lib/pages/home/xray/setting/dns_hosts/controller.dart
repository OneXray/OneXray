import 'package:onexray/core/tools/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/home/xray/setting/dns_hosts/params.dart';

class XrayHostAddress {
  final host = TextEditingController();
  final address = <TextEditingController>[];
}

class DnsHostsCubitState {
  final List<XrayHostAddress> hosts;
  final int version;

  DnsHostsCubitState({
    required this.hosts,
    this.version = 0,
  });

  factory DnsHostsCubitState.initial() => DnsHostsCubitState(
        hosts: [],
      );

  DnsHostsCubitState bumped() => DnsHostsCubitState(
        hosts: hosts,
        version: version + 1,
      );
}

class DnsHostsController extends Cubit<DnsHostsCubitState> {
  final DnsHostsParams params;
  DnsHostsController(this.params) : super(DnsHostsCubitState.initial()) {
    _initParams();
  }

  @override
  Future<void> close() {
    for (final host in state.hosts) {
      host.host.dispose();
      for (final address in host.address) {
        address.dispose();
      }
    }
    return super.close();
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
    emit(DnsHostsCubitState(hosts: hostAddresses, version: 1));
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
