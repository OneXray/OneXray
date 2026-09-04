import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/routing/geodata_suggestions.dart';
import 'package:onexray/service/routing/state.dart';

class RuleValueEntry {
  final text = TextEditingController();
  final focus = FocusNode();
  RuleValueEntry(String value) {
    text.text = value;
  }
  void dispose() {
    text.dispose();
    focus.dispose();
  }
}

class CustomRoutingRuleController extends ChangeNotifier {
  final name = TextEditingController();
  final port = TextEditingController();
  final List<RuleValueEntry> domains = [];
  final List<RuleValueEntry> ips = [];
  final Future<RoutingGeodataIndex> Function() loadIndex;
  final RoutingRuleState _original;
  String network = 'any';
  RoutingRuleAction action = RoutingRuleAction.proxy;
  String? error;
  bool _networkChanged = false;
  bool _closed = false;

  CustomRoutingRuleController({
    RoutingRuleState? rule,
    Future<RoutingGeodataIndex> Function()? loadIndex,
  }) : _original = rule ?? RoutingRuleState(),
       loadIndex = loadIndex ?? (() => RoutingGeodataIndex.load()) {
    name.text = _original.ruleTag;
    port.text = _original.port?.toString() ?? '';
    final values = _original.network;
    final networks = values is String ? values.split(',') : values as List?;
    final distinctNetworks = networks?.toSet();
    network = distinctNetworks?.length == 1
        ? distinctNetworks!.single as String
        : 'any';
    action = _original.action;
    for (final value in _original.domain) {
      domains.add(_entry(value));
    }
    for (final value in _original.ip) {
      ips.add(_entry(value));
    }
    if (domains.isEmpty) domains.add(_entry(''));
    if (ips.isEmpty) ips.add(_entry(''));
    name.addListener(_changed);
    port.addListener(_changed);
  }

  RuleValueEntry _entry(String value) =>
      RuleValueEntry(value)..text.addListener(_changed);

  void _changed() {
    if (!_closed) notifyListeners();
  }

  void addValue(bool domain) {
    (domain ? domains : ips).add(_entry(''));
    notifyListeners();
  }

  void removeValue(bool domain, RuleValueEntry entry) {
    final entries = domain ? domains : ips;
    if (entries.length == 1) {
      entry.text.clear();
      return;
    }
    entries.remove(entry);
    notifyListeners();
    // The old Autocomplete still references this controller until its unmount.
    WidgetsBinding.instance.addPostFrameCallback((_) => entry.dispose());
  }

  void setNetwork(String value) {
    network = value;
    _networkChanged = true;
    notifyListeners();
  }

  void setAction(RoutingRuleAction value) {
    action = value;
    notifyListeners();
  }

  Future<Iterable<String>> suggestions(String query, bool domain) async {
    if (query.trim().isEmpty) return const [];
    try {
      final index = await loadIndex();
      if (_closed) return const [];
      return index.suggestions(query, domain: domain);
    } catch (_) {
      return const [];
    }
  }

  /// Incomplete fields stay in the route draft while another rule is edited.
  /// Save still validates the complete rule through [buildRule].
  RoutingRuleState get draftRule {
    List<String> clean(List<RuleValueEntry> values) => values
        .map((entry) => entry.text.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final domain = clean(domains);
    final ip = clean(ips);
    final portText = port.text.trim();
    return RoutingRuleState(
      ruleTag: name.text.trim(),
      domain: domain,
      ip: ip,
      port: portText.isEmpty
          ? null
          : portText == _original.port?.toString()
          ? _original.port
          : portText,
      network: network != 'any'
          ? network
          : !_networkChanged
          ? _original.network
          : null,
      action: action,
    );
  }

  RoutingRuleState buildRule() {
    final rule = draftRule;
    rule.validate();
    return rule;
  }

  void save(BuildContext context) {
    try {
      Navigator.of(context).pop(buildRule());
    } on FormatException catch (failure) {
      final l10n = AppLocalizations.of(context)!;
      error = failure.message.contains('port')
          ? l10n.validationPortInvalid
          : l10n.prototypeNoMatchConditions;
      notifyListeners();
    }
  }

  void cancel(BuildContext context) => Navigator.of(context).pop();

  @override
  void dispose() {
    _closed = true;
    name.dispose();
    port.dispose();
    for (final entry in [...domains, ...ips]) {
      entry.dispose();
    }
    super.dispose();
  }
}
