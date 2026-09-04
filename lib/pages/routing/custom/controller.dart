import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/dialogs.dart';
import 'package:onexray/pages/routing/custom/rule_controller.dart';
import 'package:onexray/pages/widget/adaptive_dialog.dart';
import 'package:onexray/pages/widget/configuration_transfer.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/routing/custom_editor.dart';
import 'package:onexray/service/routing/document.dart';
import 'package:onexray/service/routing/state.dart';
import 'package:onexray/service/share/configuration_transfer.dart';

typedef OpenCustomRule = Future<RoutingRuleState?> Function(
  BuildContext context,
  RoutingRuleState? rule,
);

class CustomRoutingEditorController extends ChangeNotifier {
  final int? profileId;
  final String? initialText;
  final String? initialName;
  final CustomRoutingEditorService service;
  final name = TextEditingController();
  final rules = <RoutingRuleState>[];
  final ruleKeys = <Object>[];
  Object? selectedRuleKey;
  CustomRoutingRuleController? inlineRule;
  Object? _inlineRuleKey;
  bool _inlineEditing = false;
  List<RoutingProfileData> _rows = [];
  CustomRoutingEditorDraft? original;
  ConnectionConfiguration configuration = ConnectionConfiguration();
  int entryCount = 1;
  String domainStrategy = 'AsIs';
  bool _busy = true;
  bool saving = false;
  bool deleting = false;
  bool get busy => _busy || transfer.busy;
  bool get editingBlocked => deleting || transfer.busy;
  late final transfer = ConfigurationTransferController(
    kind: ConfigurationKind.custom,
    readText: () => previewState?.encode() ?? '',
    readName: () => name.text,
    hasContent: () => rules.isNotEmpty,
    onImport: (draft) => replaceTemplate(draft.text, name: draft.name),
  );
  bool _closed = false;
  String? error;

  CustomRoutingEditorController({
    this.profileId,
    this.initialText,
    this.initialName,
    CustomRoutingEditorService? service,
  }) : service = service ?? CustomRoutingEditorService() {
    name.addListener(_notify);
    transfer.addListener(_notify);
  }

  bool get loaded => original != null;
  int get routeCount => _rows.length + (profileId == null ? 1 : 0);

  Future<void> load(BuildContext context) async {
    try {
      final draft = await service.load(profileId);
      final rows = await service.rows;
      final settings = await service.coordinator.configuration;
      if (_closed) return;
      original = draft;
      _rows = rows;
      configuration = settings;
      name.text = draft.state.name;
      _setState(draft.state);
      if (initialText != null) replaceTemplate(initialText!, name: initialName);
      if (profileId == null &&
          initialText == null &&
          name.text.isEmpty &&
          context.mounted) {
        final used = _rows
            .map(
              (row) => int.tryParse(
                RegExp(r'(\d+)$').firstMatch(row.name)?.group(1) ?? '',
              ),
            )
            .toSet();
        var number = 1;
        while (used.contains(number)) {
          number++;
        }
        name.text =
            '${AppLocalizations.of(context)!.prototypeCustomRouting} $number';
      }
    } catch (_) {
      if (context.mounted) {
        error = AppLocalizations.of(context)!.prototypeCannotReadCustomRoute;
      }
    } finally {
      _busy = false;
      if (_closed) transfer.dispose();
      _notify();
    }
  }

  String? nameError(AppLocalizations l10n) {
    final value = name.text.trim();
    if (value.isEmpty || value.runes.length > 32) {
      return l10n.prototypeRouteNameRequired;
    }
    if (_rows.any(
      (row) =>
          row.id != profileId &&
          row.name.trim().toLowerCase() == value.toLowerCase(),
    )) {
      return l10n.prototypeRouteNameUnique;
    }
    return null;
  }

  RoutingProfileState get state => RoutingProfileState(
    id: profileId,
    name: name.text.trim(),
    entryCount: entryCount,
    domainStrategy: domainStrategy,
    rules: rules,
  );

  RoutingProfileState? get previewState {
    try {
      final value = state;
      value.validate();
      return value;
    } on FormatException {
      return null;
    }
  }

  ConnectionConfiguration get checkConfiguration => ConnectionConfiguration(
    connection: ConnectionSettings.fromJson({
      ...configuration.connection.toJson(),
      'expert': false,
      'trafficMode': TrafficMode.custom.name,
      'customId': profileId,
    }),
    policy: configuration.policy,
  );

  void _setState(RoutingProfileState value) {
    entryCount = value.entryCount;
    domainStrategy = value.domainStrategy;
    rules
      ..clear()
      ..addAll(value.rules);
    ruleKeys
      ..clear()
      ..addAll(List.generate(rules.length, (_) => Object()));
    selectedRuleKey = ruleKeys.isEmpty
        ? null
        : ruleKeys[ruleKeys.length > 1 ? 1 : 0];
    _syncInlineRule();
  }

  void setInlineEditing(bool value) {
    if (_inlineEditing == value) return;
    _inlineEditing = value;
    _syncInlineRule();
    _notify();
  }

  void _syncInlineRule({bool refresh = false}) {
    final key = _inlineEditing ? selectedRuleKey : null;
    if (_inlineRuleKey == key && !refresh) return;
    final previous = inlineRule;
    previous?.removeListener(_inlineRuleChanged);
    _inlineRuleKey = key;
    final index = key == null ? -1 : ruleKeys.indexOf(key);
    inlineRule = index < 0
        ? null
        : (CustomRoutingRuleController(rule: rules[index])
            ..addListener(_inlineRuleChanged));
    // Inputs from the previous rule unmount on the next frame.
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  void _inlineRuleChanged() {
    final key = _inlineRuleKey;
    final index = key == null ? -1 : ruleKeys.indexOf(key);
    if (_closed || index < 0 || inlineRule == null) return;
    rules[index] = inlineRule!.draftRule;
    _notify();
  }

  /// Import tools stage their dependencies separately before calling this.
  /// Persistence remains a deliberate Save action, never activation.
  void replaceTemplate(String text, {String? name}) {
    final document = RoutingProfileDocument.parse(text);
    if (document.assets.isNotEmpty) {
      throw const CustomRoutingEditorException('assets');
    }
    _setState(document.state);
    this.name.text =
        name ??
        (document.state.name.isEmpty ? this.name.text : document.state.name);
    error = null;
    _notify();
  }

  void setEntryCount(int value) {
    entryCount = value;
    _notify();
  }

  Future<void> editRule(
    BuildContext context,
    OpenCustomRule open, [
    int? index,
  ]) async {
    if (!loaded || editingBlocked) return;
    if (_inlineEditing) {
      if (index == null) {
        rules.add(
          RoutingRuleState(
            ruleTag: AppLocalizations.of(context)!.prototypeNewRule,
          ),
        );
        ruleKeys.add(Object());
        selectedRuleKey = ruleKeys.last;
      } else {
        selectedRuleKey = ruleKeys[index];
      }
      _syncInlineRule();
      _notify();
      return;
    }
    final rule = index == null ? null : rules[index];
    if (index != null) {
      selectedRuleKey = ruleKeys[index];
      _notify();
    }
    final edited = await open(context, rule);
    if (_closed || edited == null) return;
    if (index == null) {
      rules.add(edited);
      ruleKeys.add(Object());
      selectedRuleKey = ruleKeys.last;
    } else {
      rules[index] = edited;
    }
    _syncInlineRule(refresh: true);
    _notify();
  }

  void deleteRule(int index) {
    if (!loaded || editingBlocked) return;
    final selected = selectedRuleKey == ruleKeys[index];
    rules.removeAt(index);
    ruleKeys.removeAt(index);
    if (selected) {
      selectedRuleKey = ruleKeys.isEmpty
          ? null
          : ruleKeys[index.clamp(0, ruleKeys.length - 1)];
    }
    _syncInlineRule();
    _notify();
  }

  void reorder(int from, int to) {
    if (!loaded || editingBlocked) return;
    rules.insert(to, rules.removeAt(from));
    ruleKeys.insert(to, ruleKeys.removeAt(from));
    _notify();
  }

  String ruleName(int index, AppLocalizations l10n) =>
      rules[index].ruleTag.isEmpty
      ? l10n.prototypeNewRule
      : rules[index].ruleTag;

  String ruleSummary(int index, AppLocalizations l10n) {
    final rule = rules[index];
    final domains = rule.domain;
    final ips = rule.ip;
    if (domains.isNotEmpty) {
      return domains.first.startsWith('geosite:')
          ? '${l10n.prototypeWebsiteSet} · ${domains.first.substring(8)}'
          : domains.join(', ');
    }
    if (ips.isNotEmpty) {
      return ips.first.startsWith('geoip:')
          ? '${l10n.prototypeIpSet} · ${ips.first.substring(6)}'
          : 'IP · ${ips.join(', ')}';
    }
    final port = rule.port;
    final network = rule.network;
    return [
      if (port != null) '${l10n.prototypeTargetPort} · $port',
      if (network != null)
        '${l10n.prototypeNetworkType} · ${network is List ? network.join(', ') : network}',
    ].join(' · ');
  }

  String ruleAction(int index, AppLocalizations l10n) =>
      switch (rules[index].action) {
        RoutingRuleAction.direct => l10n.prototypeDirect,
        RoutingRuleAction.block => l10n.prototypeBlock,
        RoutingRuleAction.proxy => l10n.prototypeUseVpn,
      };

  void close(BuildContext context) {
    Navigator.of(context).pop();
  }

  Future<void> save(BuildContext context) async {
    if (busy || original == null) return;
    final l10n = AppLocalizations.of(context)!;
    if (nameError(l10n) != null) return;
    _busy = true;
    saving = true;
    error = null;
    _notify();
    try {
      final id = await service.save(
        CustomRoutingEditorDraft(original: original!.original, state: state),
        confirmReconnect: () => context.mounted
            ? showApplyAndReconnectDialog(context, label: name.text.trim())
            : Future.value(false),
        geodata: transfer.pending,
      );
      if (id != null &&
          context.mounted &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(id);
      }
    } catch (failure) {
      error = _failureMessage(l10n, failure);
    } finally {
      _busy = false;
      saving = false;
      if (_closed) transfer.dispose();
      _notify();
    }
  }

  Future<void> delete(BuildContext context) async {
    final row = original?.original;
    if (busy || row == null) return;
    final l10n = AppLocalizations.of(context)!;
    _busy = true;
    deleting = true;
    error = null;
    _notify();
    try {
      final deleted = await service.delete(
        row,
        confirm: (selected, reconnect) async =>
            context.mounted &&
            await showAppDialog<bool>(
                  context,
                  (dialogContext) => AppDialog(
                    title: l10n.prototypeDeleteName(row.name),
                    subtitle: reconnect
                        ? l10n.prototypeDeletingRouteReconnectNotice
                        : selected
                        ? l10n.prototypeDeletedRouteSmartNotice
                        : l10n.prototypeRemoveRouteNotice,
                    body: ConnectCallout(
                      icon: LucideIcons.circleAlert,
                      text: l10n.prototypeCannotUndo,
                      warning: true,
                    ),
                    actions: [
                      ConnectDialogButton(
                        label: l10n.prototypeCancel,
                        secondary: true,
                        onPressed: () => Navigator.pop(dialogContext, false),
                      ),
                      ConnectDialogButton(
                        label: reconnect
                            ? l10n.prototypeSwitchAndReconnect
                            : selected
                            ? l10n.prototypeDeleteAndUseSmartRouting
                            : l10n.prototypeDeleteRoute,
                        destructive: true,
                        icon: LucideIcons.trash2,
                        onPressed: () => Navigator.pop(dialogContext, true),
                      ),
                    ],
                  ),
                ) ==
                true,
      );
      if (deleted &&
          context.mounted &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(row.id);
      }
    } catch (failure) {
      error = _failureMessage(l10n, failure);
    } finally {
      _busy = false;
      deleting = false;
      if (_closed) transfer.dispose();
      _notify();
    }
  }

  String _failureMessage(AppLocalizations l10n, Object failure) =>
      switch (failure) {
        CustomRoutingEditorException(reason: 'name') =>
          l10n.prototypeRouteNameRequired,
        CustomRoutingEditorException(reason: 'duplicate') =>
          l10n.prototypeRouteNameUnique,
        CustomRoutingEditorException(reason: 'limit') =>
          l10n.prototypeCustomRouteLimit,
        _ => l10n.buttonSaveFailed,
      };

  void _notify() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    inlineRule?.removeListener(_inlineRuleChanged);
    inlineRule?.dispose();
    transfer.removeListener(_notify);
    if (!_busy) transfer.dispose();
    name.dispose();
    super.dispose();
  }
}
