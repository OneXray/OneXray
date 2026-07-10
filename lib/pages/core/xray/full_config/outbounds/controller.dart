import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/full_config/outbounds/params.dart';
import 'package:onexray/pages/core/xray/outbound/params.dart';
import 'package:onexray/pages/core/xray/profile/outbound_dns/params.dart';
import 'package:onexray/pages/core/xray/profile/outbound_fragment/params.dart';
import 'package:onexray/pages/core/xray/profile/outbound_freedom/params.dart';
import 'package:onexray/pages/home/outbound_select/params.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/outbound/state_reader.dart';
import 'package:onexray/service/xray/outbound/state_writer.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/outbounds_state.dart';

class XrayFullConfigOutboundsPageState {
  final OutboundsState outboundsState;
  final int version;

  const XrayFullConfigOutboundsPageState({
    required this.outboundsState,
    this.version = 0,
  });

  factory XrayFullConfigOutboundsPageState.initial() =>
      XrayFullConfigOutboundsPageState(outboundsState: OutboundsState());

  XrayFullConfigOutboundsPageState bumped() => XrayFullConfigOutboundsPageState(
    outboundsState: outboundsState,
    version: version + 1,
  );
}

class XrayFullConfigOutboundsController
    extends Cubit<XrayFullConfigOutboundsPageState> {
  final XrayFullConfigOutboundsParams params;
  final _tagRenames = <String, String>{};

  XrayFullConfigOutboundsController(this.params)
    : super(XrayFullConfigOutboundsPageState.initial()) {
    emit(XrayFullConfigOutboundsPageState(outboundsState: params.state));
  }

  OutboundState? get primaryProxy {
    for (final outbound in state.outboundsState.outbounds) {
      if (outbound.tag == RoutingOutboundTag.proxy.name) {
        return outbound;
      }
    }
    return null;
  }

  List<OutboundState> get customOutbounds => state.outboundsState.outbounds
      .where((outbound) => outbound.tag != RoutingOutboundTag.proxy.name)
      .toList();

  Future<void> editPrimaryProxy(BuildContext context) async {
    final proxy = primaryProxy;
    final outbound = proxy == null ? OutboundState() : _cloneOutbound(proxy);
    final edited = await _editOutbound(
      context,
      outbound,
      fixedTag: RoutingOutboundTag.proxy.name,
    );
    if (edited != null) {
      edited.tag = RoutingOutboundTag.proxy.name;
      _replacePrimaryProxy(edited);
    }
  }

  Future<void> importPrimaryProxy(BuildContext context) async {
    final outbound = await _selectOutbound(context);
    if (outbound == null) {
      return;
    }
    outbound.tag = RoutingOutboundTag.proxy.name;
    outbound.dialerProxy = "";
    _replacePrimaryProxy(outbound);
  }

  Future<void> addCustomOutbound(BuildContext context) async {
    final outbound = OutboundState()..tag = _nextCustomTag();
    final edited = await _editOutbound(context, outbound, editableTag: true);
    if (edited != null) {
      if (!context.mounted) {
        return;
      }
      _appendCustomOutbound(context, edited);
    }
  }

  Future<void> importCustomOutbound(BuildContext context) async {
    final outbound = await _selectOutbound(context);
    if (outbound == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    if (!_isCustomTagAvailable(outbound.tag)) {
      outbound.tag = _nextCustomTag();
    }
    _appendCustomOutbound(context, outbound);
  }

  Future<void> editCustomOutbound(
    BuildContext context,
    OutboundState outbound,
  ) async {
    final edited = await _editOutbound(
      context,
      _cloneOutbound(outbound),
      editableTag: true,
    );
    if (edited != null) {
      if (!context.mounted) {
        return;
      }
      _replaceCustomOutbound(context, outbound, edited);
    }
  }

  void deleteCustomOutbound(OutboundState outbound) {
    state.outboundsState.outbounds.remove(outbound);
    state.outboundsState.fixDnsDialerProxy();
    emit(state.bumped());
  }

  Future<void> editFreedom(BuildContext context) async {
    final params = OutboundFreedomParams(state.outboundsState.freedom);
    final freedom = await context.pushScoped<OutboundFreedomState>(
      AppSecondaryDestination.outboundFreedom,
      extra: params,
    );
    if (freedom != null) {
      state.outboundsState.freedom = freedom;
      emit(state.bumped());
    }
  }

  Future<void> editFragment(BuildContext context) async {
    final params = OutboundFragmentParams(state.outboundsState.fragment);
    final fragment = await context.pushScoped<OutboundFragmentState>(
      AppSecondaryDestination.outboundFragment,
      extra: params,
    );
    if (fragment != null) {
      state.outboundsState.fragment = fragment;
      emit(state.bumped());
    }
  }

  Future<void> editBlackHole(BuildContext context) async {
    await context.pushScoped(AppSecondaryDestination.outboundBlackHole);
  }

  Future<void> editDns(BuildContext context) async {
    final params = OutboundDnsParams(
      state.outboundsState.dns,
      state.outboundsState.dnsDialerProxyTags,
    );
    final dns = await context.pushScoped<OutboundDnsState>(
      AppSecondaryDestination.outboundDns,
      extra: params,
    );
    if (dns != null) {
      state.outboundsState.dns = dns;
      emit(state.bumped());
    }
  }

  void customMenuAction(IconMenuId menu, OutboundState outbound) {
    switch (menu) {
      case IconMenuId.delete:
        deleteCustomOutbound(outbound);
        break;
      default:
        break;
    }
  }

  void save(BuildContext context) {
    context.pop<XrayFullConfigOutboundsResult>(
      XrayFullConfigOutboundsResult(state.outboundsState, Map.of(_tagRenames)),
    );
  }

  Future<OutboundState?> _editOutbound(
    BuildContext context,
    OutboundState outbound, {
    String fixedTag = "",
    bool editableTag = false,
  }) {
    final params = OutboundUIParams(
      DBConstants.defaultId,
      outbound,
      _dialerProxyTags(outbound),
      saveToDb: false,
      fixedTag: fixedTag,
      editableTag: editableTag,
    );
    return context.pushScoped<OutboundState>(
      AppSecondaryDestination.outboundUI,
      extra: params,
    );
  }

  List<String> _dialerProxyTags(OutboundState outbound) {
    final tags = state.outboundsState.outboundTags
        .where((tag) => tag != outbound.tag)
        .where((tag) => !_nonDialerProxyTags.contains(tag))
        .toList();
    return tags;
  }

  Future<OutboundState?> _selectOutbound(BuildContext context) async {
    final row = await context.pushScoped<CoreConfigData>(
      AppSecondaryDestination.outboundSelect,
      extra: OutboundSelectParams(),
    );
    if (row == null) {
      return null;
    }
    final outbound = OutboundState();
    var valid = false;
    try {
      valid = outbound.readFromDbData(row);
    } catch (_) {
      valid = false;
    }
    if (!valid) {
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.vpnOutboundInvalid,
        );
      }
      return null;
    }
    outbound.name = row.name;
    return outbound;
  }

  void _replacePrimaryProxy(OutboundState outbound) {
    state.outboundsState.outbounds.removeWhere(
      (item) => item.tag == RoutingOutboundTag.proxy.name,
    );
    state.outboundsState.outbounds.insert(0, outbound);
    emit(state.bumped());
  }

  void _appendCustomOutbound(BuildContext context, OutboundState outbound) {
    if (!_validateCustomTag(context, outbound.tag)) {
      return;
    }
    state.outboundsState.outbounds.add(outbound);
    emit(state.bumped());
  }

  void _replaceCustomOutbound(
    BuildContext context,
    OutboundState oldOutbound,
    OutboundState newOutbound,
  ) {
    if (!_validateCustomTag(context, newOutbound.tag, except: oldOutbound)) {
      return;
    }
    _recordTagRename(oldOutbound.tag, newOutbound.tag);
    _renameDialerProxy(oldOutbound.tag, newOutbound.tag);
    final index = state.outboundsState.outbounds.indexOf(oldOutbound);
    if (index >= 0) {
      state.outboundsState.outbounds[index] = newOutbound;
      emit(state.bumped());
    }
  }

  bool _isCustomTagAvailable(String tag, {OutboundState? except}) {
    if (tag.isEmpty || tag == RoutingOutboundTag.proxy.name) {
      return false;
    }
    if (_systemTags.contains(tag)) {
      return false;
    }
    return !state.outboundsState.outbounds.any(
      (outbound) => outbound != except && outbound.tag == tag,
    );
  }

  bool _validateCustomTag(
    BuildContext context,
    String tag, {
    OutboundState? except,
  }) {
    if (tag.isEmpty) {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(context)!.validationTagRequired,
      );
      return false;
    }
    if (!_isCustomTagAvailable(tag, except: except)) {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(context)!.validationTagUnique,
      );
      return false;
    }
    return true;
  }

  void _recordTagRename(String oldTag, String newTag) {
    if (oldTag == newTag) {
      return;
    }
    var sourceTag = oldTag;
    for (final entry in _tagRenames.entries) {
      if (entry.value == oldTag) {
        sourceTag = entry.key;
        break;
      }
    }
    _tagRenames[sourceTag] = newTag;
    _tagRenames.removeWhere((key, value) => key == value);
  }

  void _renameDialerProxy(String oldTag, String newTag) {
    if (oldTag == newTag) {
      return;
    }
    for (final outbound in state.outboundsState.outbounds) {
      if (outbound.dialerProxy == oldTag) {
        outbound.dialerProxy = newTag;
      }
    }
    if (state.outboundsState.dns.dialerProxy == oldTag) {
      state.outboundsState.dns.dialerProxy = newTag;
    }
  }

  String _nextCustomTag() {
    var index = 1;
    while (true) {
      final tag = "custom$index";
      if (_isCustomTagAvailable(tag)) {
        return tag;
      }
      index += 1;
    }
  }

  Set<String> get _systemTags => {
    RoutingOutboundTag.direct.name,
    RoutingOutboundTag.fragment.name,
    RoutingOutboundTag.block.name,
    RoutingOutboundTag.dnsOut.name,
    RoutingOutboundTag.chainProxy.name,
  };

  Set<String> get _nonDialerProxyTags => {
    RoutingOutboundTag.block.name,
    RoutingOutboundTag.dnsOut.name,
  };

  OutboundState _cloneOutbound(OutboundState outbound) {
    final clone = OutboundState();
    clone.readFromOutbound(outbound.xrayJson);
    clone.name = outbound.name;
    return clone;
  }
}
