import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/widget/configuration_transfer.dart';
import 'package:onexray/service/connection/plan.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/routing/custom_editor.dart';
import 'package:onexray/service/routing/custom_template.dart';
import 'package:onexray/service/share/configuration_transfer.dart';

typedef OpenCustomRule = Future<Map<String, dynamic>?> Function(
  BuildContext context,
  Map<String, dynamic>? rule,
);

class CustomRoutingEditorController extends ChangeNotifier {
  final int? profileId;
  final String? initialText;
  final String? initialName;
  final CustomRoutingEditorService service;
  final name = TextEditingController();
  final rules = <Map<String, dynamic>>[];
  final ruleKeys = <Object>[];
  List<CustomRoutingProfileData> _rows = [];
  CustomRoutingEditorDraft? original;
  Map<String, dynamic> _document = {};
  ConnectionConfiguration configuration = ConnectionConfiguration();
  int entryCount = 1;
  bool _busy = true;
  bool get busy => _busy || transfer.busy;
  late final transfer = ConfigurationTransferController(
    kind: ConfigurationKind.custom,
    readText: () => previewTemplate?.encode() ?? '',
    readName: () => name.text,
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

  Future<void> load(BuildContext context) async {
    try {
      final draft = await service.load(profileId);
      final rows = await service.rows;
      final settings = await service.coordinator.configuration;
      if (_closed) return;
      original = draft;
      _rows = rows;
      configuration = settings;
      name.text = draft.name;
      _setTemplate(draft.template);
      if (initialText != null) replaceTemplate(initialText!, name: initialName);
    } catch (_) {
      if (context.mounted) {
        error = AppLocalizations.of(context)!.prototypeCannotReadCustomRoute;
      }
    } finally {
      _busy = false;
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

  CustomRoutingTemplate get template {
    final root = {..._document}..remove('name');
    final routing = Map<String, dynamic>.from(root['routing'] as Map? ?? {});
    routing['rules'] = rules;
    root['routing'] = routing;
    root['outbounds'] = [
      for (var index = 0; index < entryCount; index++) <String, dynamic>{},
      for (final outbound in _document['outbounds'] as List? ?? const [])
        if ((outbound as Map).isNotEmpty) outbound,
    ];
    if (name.text.trim().isNotEmpty) root['name'] = name.text.trim();
    return CustomRoutingTemplate.parse(jsonEncode(root));
  }

  CustomRoutingTemplate? get previewTemplate {
    try {
      return template;
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

  void _setTemplate(CustomRoutingTemplate value) {
    _document = value.toJson();
    entryCount = value.entryCount;
    rules
      ..clear()
      ..addAll(value.rules);
    ruleKeys
      ..clear()
      ..addAll(List.generate(rules.length, (_) => Object()));
  }

  /// Import tools stage their dependencies separately before calling this.
  /// Persistence remains a deliberate Save action, never activation.
  void replaceTemplate(String text, {String? name}) {
    final value = CustomRoutingTemplate.parse(text);
    if (value.assets.isNotEmpty) {
      throw const CustomRoutingEditorException('assets');
    }
    _setTemplate(value);
    this.name.text = name ?? value.name ?? this.name.text;
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
    if (busy) return;
    final rule = index == null ? null : rules[index];
    final edited = await open(context, rule);
    if (_closed || edited == null) return;
    if (index == null) {
      rules.add(edited);
      ruleKeys.add(Object());
    } else {
      rules[index] = edited;
    }
    _notify();
  }

  void deleteRule(int index) {
    if (busy) return;
    rules.removeAt(index);
    ruleKeys.removeAt(index);
    _notify();
  }

  void reorder(int from, int to) {
    if (busy) return;
    rules.insert(to, rules.removeAt(from));
    ruleKeys.insert(to, ruleKeys.removeAt(from));
    _notify();
  }

  String ruleName(int index, AppLocalizations l10n) =>
      rules[index]['ruleTag'] as String? ?? l10n.prototypeNewRule;

  String ruleSummary(int index) {
    final rule = rules[index];
    return [
      for (final key in const ['domain', 'ip', 'port', 'network'])
        if (rule[key] != null)
          rule[key] is List ? (rule[key] as List).join(', ') : '${rule[key]}',
    ].join(' · ');
  }

  String ruleAction(int index, AppLocalizations l10n) =>
      switch (rules[index]['outboundTag']) {
        'direct' => l10n.prototypeDirect,
        'block' => l10n.prototypeBlock,
        _ => l10n.prototypeUseVpn,
      };

  void close(BuildContext context) {
    if (!busy) Navigator.of(context).pop();
  }

  Future<void> save(BuildContext context) async {
    if (busy || original == null) return;
    final l10n = AppLocalizations.of(context)!;
    if (nameError(l10n) != null) return;
    _busy = true;
    error = null;
    _notify();
    try {
      final id = await service.save(
        CustomRoutingEditorDraft(
          original: original!.original,
          name: name.text,
          template: template,
        ),
        confirmReconnect: () => context.mounted
            ? ContextAlert.showConfirmDialog(
                context,
                title: l10n.prototypeApplyChange,
                content: l10n.prototypeReconnectNotice,
                confirmLabel: l10n.prototypeApplyAndReconnect,
              )
            : Future.value(false),
        geodata: transfer.pending,
      );
      if (id != null && context.mounted) Navigator.of(context).pop(id);
    } catch (failure) {
      error = _failureMessage(l10n, failure);
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> delete(BuildContext context) async {
    final row = original?.original;
    if (busy || row == null) return;
    final l10n = AppLocalizations.of(context)!;
    _busy = true;
    error = null;
    _notify();
    try {
      final deleted = await service.delete(
        row,
        confirm: (selected, reconnect) => context.mounted
            ? ContextAlert.showConfirmDialog(
                context,
                title: l10n.prototypeDeleteName(row.name),
                content: reconnect
                    ? l10n.prototypeDeletingRouteReconnectNotice
                    : selected
                    ? l10n.prototypeDeletedRouteSmartNotice
                    : l10n.prototypeRemoveRouteNotice,
                confirmLabel: reconnect
                    ? l10n.prototypeDeleteAndReconnect
                    : selected
                    ? l10n.prototypeDeleteAndUseSmartRouting
                    : l10n.prototypeDelete,
              )
            : Future.value(false),
      );
      if (deleted && context.mounted) Navigator.of(context).pop(row.id);
    } catch (failure) {
      error = _failureMessage(l10n, failure);
    } finally {
      _busy = false;
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
    transfer.removeListener(_notify);
    transfer.dispose();
    name.dispose();
    super.dispose();
  }
}
