import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/dialogs.dart';
import 'package:onexray/pages/launch/setup/selectors.dart';
import 'package:onexray/pages/servers/controller.dart';
import 'package:onexray/service/connection/compiler.dart';
import 'package:onexray/service/connection/plan.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/routing/smart_editor.dart';

typedef OpenDirectRegions = Future<List<String>?> Function(
  BuildContext context,
  List<String> selectedCodes,
);
typedef OpenFinalExit = Future<ServerExitChoice?> Function(
  BuildContext context,
  ServerExitPickerParams params,
);

class SmartRoutingEditorController extends ChangeNotifier {
  final SmartRoutingEditorService service;
  SmartRoutingEditorDraft? original;
  SmartRoutingSettings draft = SmartRoutingSettings();
  String? finalExitName;
  String? error;
  bool busy = true;
  bool _closed = false;

  SmartRoutingEditorController({SmartRoutingEditorService? service})
    : service = service ?? SmartRoutingEditorService();

  Future<void> load(BuildContext context) async {
    busy = true;
    error = null;
    _notify();
    try {
      final value = await service.load();
      if (_closed) return;
      original = value;
      draft = value.configuration.connection.smart;
      finalExitName = value.finalExitName;
    } catch (_) {
      if (context.mounted) {
        error = AppLocalizations.of(context)!.prototypeTemporarilyUnavailable;
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  void update(String key, Object? value) {
    if (original == null) return;
    draft = SmartRoutingSettings.fromJson({...draft.toJson(), key: value});
    error = null;
    _notify();
  }

  ConnectionConfiguration get checkConfiguration {
    final current = original!.configuration;
    return ConnectionConfiguration(
      connection: ConnectionSettings.fromJson({
        ...current.connection.toJson(),
        'smart': draft.toJson(),
        'expert': false,
        'trafficMode': TrafficMode.smart.name,
      }),
      policy: current.policy,
    );
  }

  List<Map<String, dynamic>> rulesFor(String action) => original == null
      ? []
      : ConnectionCompiler.smartRules(
          draft,
          original!.regions,
        ).where((rule) => rule['outboundTag'] == action).toList();

  String directPreview(AppLocalizations l) {
    final tags = rulesFor('direct').map((rule) => rule['ruleTag']).toSet();
    final regions = original?.regions.regionCodes ?? const <String>[];
    final labels = <String>{
      if (tags.contains('app-smart-private-domain') ||
          tags.contains('app-smart-private-ip'))
        l.prototypeLocalNetworkPrivateAddresses,
      if (tags.contains('app-smart-apple')) l.prototypeAppleServices,
      for (final code in draft.directRegions)
        if (regions.contains(code.toUpperCase()))
          setupRegionLabel(l, code.toUpperCase()),
    };
    return labels.isEmpty ? l.prototypeNone : labels.join(' / ');
  }

  String blockPreview(AppLocalizations l) =>
      rulesFor('block').isEmpty ? l.prototypeNone : l.prototypeCommonAdDomains;

  String regionsSummary(AppLocalizations l) {
    final names = draft.directRegions
        .map((code) => setupRegionLabel(l, code))
        .toList();
    if (names.isEmpty) return l.prototypeNoDirectRegions;
    if (names.length <= 2) return names.join(' · ');
    return l.prototypeMoreRegions(names.first, names.length - 1);
  }

  int get effectiveEntryCount =>
      original?.configuration.connection.selection.kind == SelectionKind.server
      ? 1
      : draft.entryCount;

  String vpnPath(AppLocalizations l) {
    final selection = original!.configuration.connection.selection;
    final entry = switch (selection.kind) {
      SelectionKind.automatic => l.prototypeAutomaticEntries(
        effectiveEntryCount,
      ),
      SelectionKind.region =>
        '${setupRegionLabel(l, selection.region!)} · ${l.prototypeAutomaticEntries(effectiveEntryCount)}',
      SelectionKind.source =>
        '${original!.selectionName ?? l.prototypeTemporarilyUnavailable} · ${l.prototypeUseEntryServers(effectiveEntryCount)}',
      SelectionKind.server =>
        original!.selectionName ?? l.prototypeTemporarilyUnavailable,
    };
    return draft.finalExitId == null
        ? entry
        : '$entry → ${finalExitName ?? l.prototypeTemporarilyUnavailable}';
  }

  Future<void> chooseRegions(
    BuildContext context,
    OpenDirectRegions open,
  ) async {
    if (busy) return;
    final selected = await open(context, List.of(draft.directRegions));
    if (_closed || selected == null) return;
    try {
      final regions = await service.regions();
      if (_closed) return;
      final previous = original!;
      original = SmartRoutingEditorDraft(
        configuration: previous.configuration,
        regions: regions,
        selectionName: previous.selectionName,
        finalExitName: previous.finalExitName,
      );
      update('directRegions', selected);
    } catch (_) {
      if (context.mounted) {
        error = AppLocalizations.of(context)!.prototypeTemporarilyUnavailable;
        _notify();
      }
    }
  }

  Future<void> chooseFinalExit(BuildContext context, OpenFinalExit open) async {
    if (busy || original == null) return;
    final selection = original!.configuration.connection.selection;
    final choice = await open(
      context,
      ServerExitPickerParams(
        selectedId: draft.finalExitId,
        excludedIds: {
          if (selection.kind == SelectionKind.server) selection.id!,
        },
      ),
    );
    if (_closed || choice == null) return;
    try {
      final name = await service.serverName(choice.id);
      if (_closed) return;
      if (choice.id != null && name == null) {
        throw const FormatException('Final exit is missing');
      }
      finalExitName = name;
      update('finalExitId', choice.id);
    } catch (_) {
      if (context.mounted) {
        error = AppLocalizations.of(context)!.prototypeTemporarilyUnavailable;
        _notify();
      }
    }
  }

  Future<void> save(BuildContext context) async {
    if (busy || original == null) return;
    final l = AppLocalizations.of(context)!;
    busy = true;
    error = null;
    _notify();
    try {
      final saved = await service.save(
        original: original!.configuration,
        smart: draft,
        confirmReconnect: () => context.mounted
            ? showApplyAndReconnectDialog(
                context,
                label: l.prototypeSmartRouting,
              )
            : Future.value(false),
      );
      if (saved &&
          context.mounted &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      error = l.buttonSaveFailed;
    } finally {
      busy = false;
      _notify();
    }
  }

  void cancel(BuildContext context) {
    Navigator.of(context).pop();
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
