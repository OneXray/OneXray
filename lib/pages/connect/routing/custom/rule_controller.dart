import 'package:material_ui/material_ui.dart';
import 'package:onexray/pages/shared/page_cubit.dart';
import 'package:onexray/service/connect/routing/custom/geodata_suggestions.dart';
import 'package:onexray/service/connect/routing/custom/state.dart';

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

enum RoutingRuleCondition { domains, ips, port, network }

class CustomRoutingRuleState {
  final String name;
  final String port;
  final List<String> domains;
  final List<String> ips;
  final String network;
  final RoutingRuleAction action;
  final Set<RoutingRuleCondition> expandedConditions;

  CustomRoutingRuleState({
    this.name = '',
    this.port = '',
    Iterable<String> domains = const [''],
    Iterable<String> ips = const [''],
    this.network = 'any',
    this.action = RoutingRuleAction.proxy,
    Iterable<RoutingRuleCondition> expandedConditions = const [],
  }) : domains = List.unmodifiable(domains),
       ips = List.unmodifiable(ips),
       expandedConditions = Set.unmodifiable(expandedConditions);

  CustomRoutingRuleState copyWith({
    String? name,
    String? port,
    Iterable<String>? domains,
    Iterable<String>? ips,
    String? network,
    RoutingRuleAction? action,
    Iterable<RoutingRuleCondition>? expandedConditions,
  }) => CustomRoutingRuleState(
    name: name ?? this.name,
    port: port ?? this.port,
    domains: domains ?? this.domains,
    ips: ips ?? this.ips,
    network: network ?? this.network,
    action: action ?? this.action,
    expandedConditions: expandedConditions ?? this.expandedConditions,
  );
}

CustomRoutingRuleState _initialRuleState(RoutingRuleState rule) {
  final values = rule.network;
  final networks = values is String
      ? values.split(',')
      : values is List
      ? values
      : null;
  final distinctNetworks = networks?.toSet();
  return CustomRoutingRuleState(
    name: rule.ruleTag,
    port: rule.port?.toString() ?? '',
    domains: rule.domain.isEmpty ? const [''] : rule.domain,
    ips: rule.ip.isEmpty ? const [''] : rule.ip,
    network: distinctNetworks?.length == 1 && distinctNetworks!.single is String
        ? distinctNetworks.single as String
        : 'any',
    action: rule.action,
  );
}

class CustomRoutingRuleController extends PageCubit<CustomRoutingRuleState> {
  final name = TextEditingController();
  final port = TextEditingController();
  final List<RuleValueEntry> domains = [];
  final List<RuleValueEntry> ips = [];
  final Future<RoutingGeodataIndex> Function() loadIndex;
  final RoutingRuleState _original;
  bool _networkChanged = false;

  CustomRoutingRuleController({
    RoutingRuleState? rule,
    Future<RoutingGeodataIndex> Function()? loadIndex,
  }) : _original = rule ?? RoutingRuleState(),
       loadIndex = loadIndex ?? (() => RoutingGeodataIndex.load()),
       super(_initialRuleState(rule ?? RoutingRuleState())) {
    name.text = state.name;
    port.text = state.port;
    for (final value in state.domains) {
      domains.add(_entry(value));
    }
    for (final value in state.ips) {
      ips.add(_entry(value));
    }
    name.addListener(_changed);
    port.addListener(_changed);
  }

  RuleValueEntry _entry(String value) =>
      RuleValueEntry(value)..text.addListener(_changed);

  void _changed() {
    if (!isPageActive) return;
    emit(
      state.copyWith(
        name: name.text,
        port: port.text,
        domains: domains.map((entry) => entry.text.text),
        ips: ips.map((entry) => entry.text.text),
      ),
    );
  }

  void addValue(bool domain) {
    (domain ? domains : ips).add(_entry(''));
    _changed();
  }

  void removeValue(bool domain, RuleValueEntry entry) {
    final entries = domain ? domains : ips;
    if (entries.length == 1) {
      entry.text.clear();
      return;
    }
    entries.remove(entry);
    _changed();
    // The old Autocomplete still references this controller until its unmount.
    WidgetsBinding.instance.addPostFrameCallback((_) => entry.dispose());
  }

  void setNetwork(String value) {
    _networkChanged = true;
    emit(state.copyWith(network: value));
  }

  void setAction(RoutingRuleAction value) {
    emit(state.copyWith(action: value));
  }

  void toggleCondition(RoutingRuleCondition condition) {
    final expanded = state.expandedConditions.toSet();
    if (!expanded.remove(condition)) expanded.add(condition);
    emit(state.copyWith(expandedConditions: expanded));
  }

  Future<Iterable<String>> suggestions(String query, bool domain) async {
    if (query.trim().isEmpty) return const [];
    try {
      final index = await loadIndex();
      if (!isPageActive) return const [];
      return index.suggestions(query, domain: domain);
    } catch (_) {
      return const [];
    }
  }

  /// Incomplete fields stay in the route draft while another rule is edited.
  /// libXray validates the complete profile when its parent editor saves.
  RoutingRuleState get draftRule {
    List<String> clean(List<String> values) => values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final domain = clean(state.domains);
    final ip = clean(state.ips);
    final portText = state.port.trim();
    return RoutingRuleState(
      ruleTag: state.name.trim(),
      domain: domain,
      ip: ip,
      port: portText.isEmpty
          ? null
          : portText == _original.port?.toString()
          ? _original.port
          : portText,
      network: state.network != 'any'
          ? state.network
          : !_networkChanged
          ? _original.network
          : null,
      action: state.action,
    );
  }

  void save(BuildContext context) => Navigator.of(context).pop(draftRule);

  void cancel(BuildContext context) => Navigator.of(context).pop();

  @override
  void disposePageResources() {
    name.dispose();
    port.dispose();
    for (final entry in [...domains, ...ips]) {
      entry.dispose();
    }
  }
}
