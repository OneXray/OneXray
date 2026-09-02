import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/policy_editor.dart';
import 'package:onexray/service/connection/settings.dart';

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

class PolicyEditorController extends ChangeNotifier {
  final PolicyEditorService service;
  PolicyEditorDraft? draft;
  bool busy = false;
  String? error;
  bool _closed = false;

  PolicyEditorController({
    PolicyEditorDraft? draft,
    PolicyEditorService? service,
  }) : draft = draft?.copy(),
       service = service ?? PolicyEditorService() {
    this.service.coordinator.state.addListener(notify);
  }

  ConnectionPlatform get platform => service.platform;
  bool get connected =>
      service.coordinator.state.value.phase == ConnectionPhase.connected;
  bool get blocked => busy || service.coordinator.state.value.busy;
  Map<String, dynamic> get value => draft!.policy;
  Map<String, dynamic> group(String key) => value[key] as Map<String, dynamic>;
  List<String> strings(String groupName, String key) =>
      List<String>.from(group(groupName)[key] as List);

  Future<void> load(BuildContext context) async {
    busy = true;
    error = null;
    notify();
    try {
      final loaded = await service.load();
      if (!_closed) {
        draft = loaded;
      }
    } catch (_) {
      if (context.mounted) {
        error = AppLocalizations.of(context)!.prototypeTemporarilyUnavailable;
      }
    } finally {
      busy = false;
      notify();
    }
  }

  void update(String key, Object value, {String? section}) {
    if (blocked) {
      return;
    }
    (section == null ? this.value : group(section))[key] = value;
    error = null;
    notify();
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
    if (blocked || draft == null) {
      return false;
    }
    final l = AppLocalizations.of(context)!;
    error = validationHint(l);
    if (error != null) {
      notify();
      return false;
    }
    try {
      service.validate(draft!);
    } on FormatException {
      error = platform == ConnectionPlatform.windows
          ? l.prototypeBypassNetworkInputHint
          : l.buttonSaveFailed;
      notify();
      return false;
    }
    busy = true;
    notify();
    try {
      final saved = await service.save(
        draft: draft!,
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
      if (saved && !_closed) {
        if (pop && context.mounted) {
          Navigator.of(context).pop(true);
        } else {
          draft = await service.load();
        }
      }
      return saved;
    } catch (_) {
      error = l.buttonSaveFailed;
      return false;
    } finally {
      busy = false;
      notify();
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
    if (saved == true && context.mounted && !_closed) {
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
    if (!_closed && selected != null) {
      update(key, selected, section: 'android');
    }
  }

  void cancel(BuildContext context) {
    if (!blocked) {
      Navigator.of(context).pop();
    }
  }

  void discard() {
    if (blocked || draft == null) {
      return;
    }
    draft = PolicyEditorDraft(draft!.original);
    error = null;
    notify();
  }

  void notify() {
    if (!_closed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _closed = true;
    service.coordinator.state.removeListener(notify);
    super.dispose();
  }
}
