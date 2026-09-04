import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/routing/custom/rule_controller.dart';
import 'package:onexray/pages/routing/widgets.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/service/routing/state.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class CustomRoutingRulePage extends StatefulWidget {
  final RoutingRuleState? rule;
  const CustomRoutingRulePage({super.key, this.rule});

  @override
  State<CustomRoutingRulePage> createState() => _CustomRoutingRulePageState();
}

class _CustomRoutingRulePageState extends State<CustomRoutingRulePage> {
  late final controller = CustomRoutingRuleController(rule: widget.rule);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (widget.rule == null) {
        controller.name.text = AppLocalizations.of(context)!.prototypeNewRule;
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    return Scaffold(
      appBar: AppBar(title: Text(l.prototypeEditRule)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            mobile ? 14 : 28,
            12,
            mobile ? 14 : 28,
            18,
          ),
          child: ResponsiveContent(
            desktopMaxWidth: 800,
            child: CustomRoutingRuleForm(controller: controller),
          ),
        ),
      ),
      bottomNavigationBar: PageActionBar(
        children: [
          ShadButton.outline(
            onPressed: () => controller.cancel(context),
            child: Text(l.prototypeCancel),
          ),
          ShadButton(
            onPressed: () => controller.save(context),
            child: Text(l.prototypeSave),
          ),
        ],
      ),
    );
  }
}

/// The same field composition can be hosted beside a wide-screen rule list.
class CustomRoutingRuleForm extends StatelessWidget {
  final CustomRoutingRuleController controller;
  const CustomRoutingRuleForm({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context)!;
      final palette = ColorManager.palette(context);
      final mobile =
          MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
      return RoutingCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!mobile)
              RoutingCardHeader(
                title: l.prototypeEditRule,
                description: l.prototypeRuleEditHint,
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 7,
                children: [
                  Text(
                    l.prototypeRuleName,
                    style: AppTypography.routeIdentityLabel.copyWith(
                      color: palette.mutedStrong,
                    ),
                  ),
                  ShadInput(
                    controller: controller.name,
                    constraints: const BoxConstraints(minHeight: 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    style: AppTypography.routeIdentityLabel,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                mobile ? 12 : 16,
                14,
                mobile ? 12 : 16,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.prototypeMatchWhen,
                    style: AppTypography.conditionTitle.copyWith(
                      color: palette.mutedStrong,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      border: Border.all(color: palette.border),
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _conditions(context, domain: true),
                        const Divider(),
                        _conditions(context, domain: false),
                        const Divider(),
                        ValueListenableBuilder(
                          valueListenable: controller.port,
                          builder: (context, value, _) => _ConditionField(
                            icon: LucideIcons.terminal,
                            title: l.prototypeTargetPort,
                            summary: value.text.trim().isEmpty
                                ? l.prototypeNotSet
                                : value.text,
                            child: _input(
                              context,
                              controller: controller.port,
                              hint: '80, 443, 1000-2000',
                            ),
                          ),
                        ),
                        const Divider(),
                        _ConditionField(
                          icon: LucideIcons.wifi,
                          title: l.prototypeNetworkType,
                          summary: controller.network == 'any'
                              ? l.prototypeAny
                              : controller.network.toUpperCase(),
                          child: _network(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 7,
                    children: [
                      Icon(
                        LucideIcons.info,
                        size: 14,
                        color: palette.mutedForeground,
                      ),
                      Expanded(
                        child: Text(
                          l.prototypeRuleConditionsHint,
                          style: AppTypography.conditionRelation.copyWith(
                            color: palette.mutedForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                mobile ? 12 : 16,
                14,
                mobile ? 12 : 16,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.prototypeThen,
                    style: AppTypography.conditionTitle.copyWith(
                      color: palette.mutedStrong,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _actions(context),
                  if (controller.action == RoutingRuleAction.proxy)
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: Text(
                        l.prototypeVpnRuleHint,
                        style: AppTypography.actionHelp.copyWith(
                          color: palette.mutedForeground,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (controller.error case final error?)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: AppTypography.actionHelp.copyWith(
                      color: palette.destructive,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _conditions(BuildContext context, {required bool domain}) {
    final l = AppLocalizations.of(context)!;
    final entries = domain ? controller.domains : controller.ips;
    final title = domain
        ? l.prototypeWebsitesDomains
        : l.prototypeIpAddressesRanges;
    return AnimatedBuilder(
      animation: Listenable.merge(entries.map((entry) => entry.text).toList()),
      builder: (context, _) {
        final values = entries
            .map((entry) => entry.text.text.trim())
            .where((value) => value.isNotEmpty)
            .join(', ');
        return _ConditionField(
          icon: domain ? LucideIcons.globe : LucideIcons.network,
          title: title,
          summary: values.isEmpty ? l.prototypeNotSet : values,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 7,
            children: [
              for (final entry in entries)
                Row(
                  key: ObjectKey(entry),
                  spacing: 7,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) => RawAutocomplete<String>(
                          textEditingController: entry.text,
                          focusNode: entry.focus,
                          optionsBuilder: (value) =>
                              controller.suggestions(value.text, domain),
                          fieldViewBuilder: (context, text, focus, submit) =>
                              Semantics(
                                label: '$title ${entries.indexOf(entry) + 1}',
                                child: _input(
                                  context,
                                  controller: text,
                                  focus: focus,
                                  hint: domain
                                      ? l.prototypeDomainGeositeRule
                                      : l.prototypeIpCidrGeoipRule,
                                  onSubmitted: (_) => submit(),
                                ),
                              ),
                          optionsViewBuilder: (context, select, options) => Align(
                            alignment: AlignmentDirectional.topStart,
                            child: Material(
                              elevation: 4,
                              color: ColorManager.palette(context).card,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.control,
                                ),
                                side: BorderSide(
                                  color: ColorManager.palette(context).border,
                                ),
                              ),
                              child: SizedBox(
                                width: constraints.maxWidth,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 240,
                                  ),
                                  child: ListView(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    children: [
                                      for (final (index, option)
                                          in options.indexed)
                                        InkWell(
                                          onTap: () => select(option),
                                          child: ColoredBox(
                                            color:
                                                AutocompleteHighlightedOption.of(
                                                      context,
                                                    ) ==
                                                    index
                                                ? ColorManager.palette(context)
                                                      .selectedSurface
                                                : ColorManager.palette(context)
                                                      .card,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                              child: Text(
                                                option,
                                                textDirection:
                                                    TextDirection.ltr,
                                                style:
                                                    AppTypography.routingInput,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (entries.length > 1 || entry.text.text.isNotEmpty)
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: IconButton(
                          tooltip: l.prototypeRemoveEntry,
                          onPressed: () =>
                              controller.removeValue(domain, entry),
                          style: IconButton.styleFrom(
                            minimumSize: const Size.square(34),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: ColorManager.palette(context)
                                .mutedForeground,
                          ),
                          icon: const Icon(LucideIcons.trash2, size: 15),
                        ),
                      )
                    else
                      const SizedBox(width: 34),
                  ],
                ),
              TextButton.icon(
                onPressed: () => controller.addValue(domain),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: AppTypography.actionHelp,
                ),
                icon: const Icon(LucideIcons.plus, size: 15),
                label: Text(l.prototypeAddAnother),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _input(
    BuildContext context, {
    required TextEditingController controller,
    required String hint,
    FocusNode? focus,
    ValueChanged<String>? onSubmitted,
  }) => Directionality(
    textDirection: TextDirection.ltr,
    child: ShadInput(
      controller: controller,
      focusNode: focus,
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      style: AppTypography.routingInput,
      placeholder: Text(hint),
      placeholderStyle: AppTypography.routingInput.copyWith(
        color: ColorManager.palette(context).mutedForeground,
      ),
      autocorrect: false,
      enableSuggestions: false,
      onSubmitted: onSubmitted,
    ),
  );

  Widget _network(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final labels = {'any': l.prototypeAny, 'tcp': 'TCP', 'udp': 'UDP'};
    return AppMenuButton<String>(
      entries: [
        for (final entry in labels.entries)
          AppMenuEntry.item(value: entry.key, title: entry.value),
      ],
      onSelected: controller.setNetwork,
      triggerBuilder: (open) => OutlinedButton(
        onPressed: open,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(40),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: AppTypography.routingInput,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(labels[controller.network] ?? controller.network),
            ),
            const Icon(LucideIcons.chevronDown, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final actions = {
      RoutingRuleAction.proxy: l.prototypeUseVpn,
      RoutingRuleAction.direct: l.prototypeDirect,
      RoutingRuleAction.block: l.prototypeBlock,
    };
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (final (index, action) in actions.entries.indexed) ...[
              if (index > 0) const VerticalDivider(width: 1),
              Expanded(
                child: Semantics(
                  button: true,
                  selected: controller.action == action.key,
                  child: InkWell(
                    onTap: () => controller.setAction(action.key),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 38),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: controller.action == action.key
                            ? palette.selectedSurface
                            : palette.muted,
                        border: controller.action == action.key
                            ? Border.all(color: palette.primary)
                            : null,
                      ),
                      child: Text(
                        action.value,
                        textAlign: TextAlign.center,
                        style:
                            (controller.action == action.key
                                    ? AppTypography.selectedActionOption
                                    : AppTypography.actionOption)
                                .copyWith(
                                  color: controller.action == action.key
                                      ? palette.primary
                                      : palette.foreground,
                                ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConditionField extends StatefulWidget {
  const _ConditionField({
    required this.icon,
    required this.title,
    required this.summary,
    required this.child,
  });
  final IconData icon;
  final String title;
  final String summary;
  final Widget child;

  @override
  State<_ConditionField> createState() => _ConditionFieldState();
}

class _ConditionFieldState extends State<_ConditionField> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              color: _open ? palette.surfaceHover : palette.card,
              child: Row(
                spacing: 10,
                children: [
                  Icon(widget.icon, size: 18, color: palette.mutedStrong),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 3,
                      children: [
                        Text(widget.title, style: AppTypography.conditionTitle),
                        Text(
                          widget.summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.conditionSummary.copyWith(
                            color: palette.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _open
                        ? LucideIcons.chevronDown
                        : LucideIcons.chevronRightDir,
                    size: 17,
                    color: palette.foreground,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(39, 0, 10, 10),
            child: widget.child,
          ),
      ],
    );
  }
}
