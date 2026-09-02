import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/routing/custom_template.dart';
import 'package:onexray/service/routing/geodata_suggestions.dart';

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
  final Map<String, dynamic> _original;
  String network = 'any';
  String action = 'proxy';
  String? error;
  bool _networkChanged = false;
  bool _closed = false;

  CustomRoutingRuleController({
    Map<String, dynamic>? rule,
    Future<RoutingGeodataIndex> Function()? loadIndex,
  }) : _original = jsonDecode(
         jsonEncode(rule ?? <String, dynamic>{}),
       ) as Map<String, dynamic>,
       loadIndex = loadIndex ?? (() => RoutingGeodataIndex.load()) {
    name.text = _original['ruleTag'] as String? ?? '';
    port.text = _original['port']?.toString() ?? '';
    final values = _original['network'];
    final networks = values is String ? values.split(',') : values as List?;
    final distinctNetworks = networks?.toSet();
    network = distinctNetworks?.length == 1
        ? distinctNetworks!.single as String
        : 'any';
    action = _original['outboundTag'] as String? ?? 'proxy';
    for (final value in _original['domain'] as List? ?? const []) {
      domains.add(RuleValueEntry(value as String));
    }
    for (final value in _original['ip'] as List? ?? const []) {
      ips.add(RuleValueEntry(value as String));
    }
    if (domains.isEmpty) domains.add(RuleValueEntry(''));
    if (ips.isEmpty) ips.add(RuleValueEntry(''));
  }

  void addValue(bool domain) {
    (domain ? domains : ips).add(RuleValueEntry(''));
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

  void setAction(String value) {
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

  Map<String, dynamic> buildRule() {
    List<String> clean(List<RuleValueEntry> values) => values
        .map((entry) => entry.text.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final domain = clean(domains);
    final ip = clean(ips);
    final rule = <String, dynamic>{
      'type': 'field',
      if (name.text.trim().isNotEmpty) 'ruleTag': name.text.trim(),
      if (domain.isNotEmpty) 'domain': domain,
      if (ip.isNotEmpty) 'ip': ip,
      if (port.text.trim().isNotEmpty)
        'port': port.text.trim() == _original['port']?.toString()
            ? _original['port']
            : port.text.trim(),
      if (network != 'any')
        'network': network
      else if (!_networkChanged && _original.containsKey('network'))
        'network': _original['network'],
      if (action == 'proxy') 'balancerTag': 'proxy' else 'outboundTag': action,
    };
    CustomRoutingTemplate.parse(
      jsonEncode({
        'outbounds': [{}],
        'routing': {
          'rules': [rule],
        },
      }),
    );
    return rule;
  }

  void save(BuildContext context) {
    try {
      Navigator.of(context).pop(buildRule());
    } on FormatException catch (failure) {
      final l10n = AppLocalizations.of(context)!;
      error = failure.message.contains('.port')
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
