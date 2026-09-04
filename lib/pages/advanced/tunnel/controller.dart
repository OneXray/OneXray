import 'package:flutter/material.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/policy_editor.dart';
import 'package:onexray/service/connection/platform_policy.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/tun_settings/interface.dart';

enum TunnelDestination { apple, android, windows, interface }

typedef OpenTunnelPage = Future<bool?> Function(
  BuildContext context,
  TunnelDestination destination,
  PolicyEditorDraft draft,
);
typedef OpenPolicyChild = Future<bool?> Function(
  BuildContext context,
  PolicyEditorDraft draft,
);
typedef OpenAndroidApps = Future<List<String>?> Function(
  BuildContext context,
  String mode,
  List<String> selected,
);

const _notProvided = Object();

@immutable
class PolicyEditorPageState {
  final PolicyEditorDraft? draft;
  final bool busy;
  final String? error;
  final Map<String, String> androidAppNames;
  final ConnectionView connection;
  final AppleVpnCapabilities? appleCapabilities;
  final bool appleCapabilitiesLoading;
  final List<OutboundInterfaceOption> interfaces;
  final bool interfacesLoading;
  final bool interfacesFailed;

  PolicyEditorPageState({
    this.draft,
    this.busy = false,
    this.error,
    Map<String, String> androidAppNames = const {},
    this.connection = const ConnectionView(),
    this.appleCapabilities,
    this.appleCapabilitiesLoading = false,
    List<OutboundInterfaceOption> interfaces = const [],
    this.interfacesLoading = true,
    this.interfacesFailed = false,
  }) : androidAppNames = Map<String, String>.unmodifiable(androidAppNames),
       interfaces = List<OutboundInterfaceOption>.unmodifiable(interfaces);

  PolicyEditorPageState copyWith({
    Object? draft = _notProvided,
    bool? busy,
    Object? error = _notProvided,
    Map<String, String>? androidAppNames,
    ConnectionView? connection,
    Object? appleCapabilities = _notProvided,
    bool? appleCapabilitiesLoading,
    List<OutboundInterfaceOption>? interfaces,
    bool? interfacesLoading,
    bool? interfacesFailed,
  }) => PolicyEditorPageState(
    draft: identical(draft, _notProvided)
        ? this.draft
        : draft as PolicyEditorDraft?,
    busy: busy ?? this.busy,
    error: identical(error, _notProvided) ? this.error : error as String?,
    androidAppNames: androidAppNames ?? this.androidAppNames,
    connection: connection ?? this.connection,
    appleCapabilities: identical(appleCapabilities, _notProvided)
        ? this.appleCapabilities
        : appleCapabilities as AppleVpnCapabilities?,
    appleCapabilitiesLoading:
        appleCapabilitiesLoading ?? this.appleCapabilitiesLoading,
    interfaces: interfaces ?? this.interfaces,
    interfacesLoading: interfacesLoading ?? this.interfacesLoading,
    interfacesFailed: interfacesFailed ?? this.interfacesFailed,
  );
}

class PolicyEditorController extends PageCubit<PolicyEditorPageState> {
  final PolicyEditorService service;

  PolicyEditorController({
    PolicyEditorDraft? draft,
    PolicyEditorService? service,
  }) : this._(draft, service ?? PolicyEditorService());

  PolicyEditorController._(PolicyEditorDraft? draft, this.service)
    : super(
        PolicyEditorPageState(
          draft: draft?.copy(),
          connection: service.coordinator.state.value,
        ),
      ) {
    service.coordinator.state.addListener(_connectionChanged);
  }

  ConnectionPlatform get platform => service.platform;
  PolicyEditorDraft? get draft => state.draft;
  bool get busy => state.busy;
  String? get error => state.error;
  bool get connected => state.connection.phase == ConnectionPhase.connected;
  bool get blocked => state.busy;
  bool get runtimeBusy => state.connection.busy;
  Map<String, dynamic> get value => state.draft!.policy;
  Map<String, dynamic> group(String key) => value[key] as Map<String, dynamic>;
  List<String> strings(String groupName, String key) =>
      List<String>.unmodifiable(
        List<String>.from(group(groupName)[key] as List),
      );

  String androidAppName(String packageName) =>
      state.androidAppNames[packageName] ?? packageName;

  Future<void> loadAndroidAppNames() async {
    final apps = await AppHostApi().getInstalledApps();
    if (!isPageActive) return;
    emit(
      state.copyWith(
        androidAppNames: {
          for (final app in apps)
            if (app.name.isNotEmpty) app.packageName: app.name,
        },
      ),
    );
  }

  Future<void> load(BuildContext context) async {
    emit(state.copyWith(busy: true, error: null));
    try {
      final loaded = await service.load();
      emit(state.copyWith(draft: loaded));
    } catch (_) {
      if (context.mounted) {
        emit(
          state.copyWith(
            error: AppLocalizations.of(context)!
                .prototypeTemporarilyUnavailable,
          ),
        );
      }
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  void update(String key, Object value, {String? section}) {
    final current = state.draft;
    if (blocked || current == null) {
      return;
    }
    final next = current.copy();
    final target = section == null
        ? next.policy
        : next.policy[section] as Map<String, dynamic>;
    target[key] = value;
    emit(state.copyWith(draft: next, error: null));
  }

  bool get emptyIncluded =>
      draft != null &&
      platform == ConnectionPlatform.android &&
      group('android')['appScope'] == 'included' &&
      strings('android', 'includedAppPackageNames').isEmpty;

  bool get ipv6Conflict =>
      draft != null &&
      platform == ConnectionPlatform.windows &&
      value['ipv6Enabled'] == false &&
      strings('windows', 'excludedCidrs').any((value) => value.contains(':'));

  bool get wifiConflict {
    if (draft == null) {
      return false;
    }
    final disconnect = strings('apple', 'disconnectWifiSsids').toSet();
    return strings(
      'apple',
      'connectWifiSsids',
    ).any((name) => name.trim().isNotEmpty && disconnect.contains(name));
  }

  String? validationHint(AppLocalizations l) {
    if (ipv6Conflict) {
      return l.prototypeIpv6BypassConflict;
    }
    if (wifiConflict) {
      return l.prototypeWifiActionConflict;
    }
    if (service.requiresInterface &&
        (value['xrayOutboundInterfaceName'] as String).trim().isEmpty) {
      return l.prototypeChooseInterfaceBeforeSaving;
    }
    return null;
  }

  String saveLabel(AppLocalizations l) => connected
      ? emptyIncluded
            ? l.prototypeDisconnectVpn
            : l.prototypeSaveAndReconnect
      : l.prototypeSave;

  Future<bool> save(BuildContext context, {bool pop = true}) async {
    final current = state.draft;
    if (blocked || runtimeBusy || current == null) {
      return false;
    }
    final l = AppLocalizations.of(context)!;
    final hint = validationHint(l);
    if (hint != null) {
      emit(state.copyWith(error: hint));
      return false;
    }
    try {
      service.validate(current);
    } on FormatException {
      emit(
        state.copyWith(
          error: platform == ConnectionPlatform.windows
              ? l.prototypeBypassNetworkInputHint
              : l.buttonSaveFailed,
        ),
      );
      return false;
    }
    emit(state.copyWith(busy: true, error: null));
    try {
      final saved = await service.save(
        draft: current,
        confirm: (disconnect) => context.mounted
            ? ContextAlert.showConfirmDialog(
                context,
                title: l.prototypeApplyChange,
                content: disconnect
                    ? '${l.prototypeNoAppsSelected}. ${l.prototypeDisconnectVpn}.'
                    : l.prototypeReconnectNotice,
                confirmLabel: disconnect
                    ? l.prototypeDisconnectVpn
                    : l.prototypeSaveAndReconnect,
              )
            : Future.value(false),
      );
      if (saved && isPageActive) {
        if (pop &&
            context.mounted &&
            ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pop(true);
        } else if (!pop) {
          emit(state.copyWith(draft: await service.load()));
        }
      }
      return saved;
    } catch (_) {
      emit(state.copyWith(error: l.buttonSaveFailed));
      return false;
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  Future<void> openChild(BuildContext context, OpenPolicyChild open) async {
    if (blocked || draft == null) {
      return;
    }
    final saved = await open(context, draft!.copy());
    if (saved == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> openPlatform(
    BuildContext context,
    TunnelDestination destination,
    OpenTunnelPage open,
  ) async {
    if (blocked || draft == null) {
      return;
    }
    final saved = await open(context, destination, draft!.copy());
    if (saved == true && context.mounted && isPageActive) {
      await load(context);
    }
  }

  Future<void> selectApps(BuildContext context, OpenAndroidApps open) async {
    if (blocked) {
      return;
    }
    final mode = group('android')['appScope'] as String;
    final key = mode == 'included'
        ? 'includedAppPackageNames'
        : 'excludedAppPackageNames';
    final selected = await open(context, mode, strings('android', key));
    if (isPageActive && selected != null) {
      update(key, selected, section: 'android');
    }
  }

  void cancel(BuildContext context) {
    Navigator.of(context).pop();
  }

  void restoreDefaults() {
    final current = state.draft;
    if (blocked || current == null) return;
    emit(
      state.copyWith(
        draft: PolicyEditorDraft(
          current.original,
          PlatformPolicy.defaults().toJson(),
        ),
        error: null,
      ),
    );
  }

  void _connectionChanged() {
    emit(state.copyWith(connection: service.coordinator.state.value));
  }

  @override
  void disposePageResources() {
    service.coordinator.state.removeListener(_connectionChanged);
  }
}
