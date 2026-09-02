import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/routing/custom/rule_controller.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class CustomRoutingRulePage extends StatefulWidget {
  final Map<String, dynamic>? rule;
  const CustomRoutingRulePage({super.key, this.rule});

  @override
  State<CustomRoutingRulePage> createState() => _CustomRoutingRulePageState();
}

class _CustomRoutingRulePageState extends State<CustomRoutingRulePage> {
  late final controller = CustomRoutingRuleController(rule: widget.rule);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final l10n = AppLocalizations.of(context)!;
      return Scaffold(
        appBar: AppBar(title: Text(l10n.prototypeEditRule)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
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
              child: Text(l10n.prototypeCancel),
            ),
            ShadButton(
              onPressed: () => controller.save(context),
              child: Text(l10n.prototypeSave),
            ),
          ],
        ),
      );
    },
  );
}

/// The same field composition can be hosted beside a wide-screen rule list.
class CustomRoutingRuleForm extends StatelessWidget {
  final CustomRoutingRuleController controller;
  const CustomRoutingRuleForm({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.prototypeRuleEditHint, style: textTheme.bodyMedium),
        const SizedBox(height: 16),
        TextField(
          controller: controller.name,
          decoration: InputDecoration(labelText: l10n.prototypeRuleName),
        ),
        const SizedBox(height: 24),
        Text(l10n.prototypeMatchWhen, style: textTheme.titleMedium),
        const SizedBox(height: 8),
        _conditions(context, domain: true),
        _conditions(context, domain: false),
        ExpansionTile(
          leading: const Icon(LucideIcons.terminal),
          title: Text(l10n.prototypeTargetPort),
          initiallyExpanded: controller.port.text.isNotEmpty,
          childrenPadding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: controller.port,
              textDirection: TextDirection.ltr,
              style: AppTypography.code,
              decoration: InputDecoration(
                labelText: l10n.prototypeTargetPort,
                hintText: '80, 443, 1000-2000',
              ),
            ),
          ],
        ),
        ExpansionTile(
          leading: const Icon(LucideIcons.wifi),
          title: Text(l10n.prototypeNetworkType),
          subtitle: Text(
            controller.network == 'any'
                ? l10n.prototypeAny
                : controller.network.toUpperCase(),
          ),
          childrenPadding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final network in const ['any', 'tcp', 'udp'])
                  ChoiceChip(
                    label: Text(
                      network == 'any'
                          ? l10n.prototypeAny
                          : network.toUpperCase(),
                    ),
                    selected: controller.network == network,
                    onSelected: (_) => controller.setNetwork(network),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(l10n.prototypeRuleConditionsHint, style: textTheme.bodySmall),
        const SizedBox(height: 24),
        Text(l10n.prototypeThen, style: textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in {
              'proxy': l10n.prototypeUseVpn,
              'direct': l10n.prototypeDirect,
              'block': l10n.prototypeBlock,
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: controller.action == entry.key,
                onSelected: (_) => controller.setAction(entry.key),
              ),
          ],
        ),
        if (controller.action == 'proxy')
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(l10n.prototypeVpnRuleHint, style: textTheme.bodySmall),
          ),
        if (controller.error case final error?)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _conditions(BuildContext context, {required bool domain}) {
    final l10n = AppLocalizations.of(context)!;
    final entries = domain ? controller.domains : controller.ips;
    final title = domain
        ? l10n.prototypeWebsitesDomains
        : l10n.prototypeIpAddressesRanges;
    return ExpansionTile(
      leading: Icon(domain ? LucideIcons.globe : LucideIcons.network),
      title: Text(title),
      initiallyExpanded: entries.any((entry) => entry.text.text.isNotEmpty),
      childrenPadding: const EdgeInsets.all(16),
      children: [
        for (final entry in entries)
          Padding(
            key: ObjectKey(entry),
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RawAutocomplete<String>(
                    textEditingController: entry.text,
                    focusNode: entry.focus,
                    optionsBuilder: (value) =>
                        controller.suggestions(value.text, domain),
                    fieldViewBuilder: (context, text, focus, submit) =>
                        TextField(
                          controller: text,
                          focusNode: focus,
                          textDirection: TextDirection.ltr,
                          style: AppTypography.code,
                          onSubmitted: (_) => submit(),
                          decoration: InputDecoration(
                            labelText: '$title ${entries.indexOf(entry) + 1}',
                            hintText: domain
                                ? l10n.prototypeDomainGeositeRule
                                : l10n.prototypeIpCidrGeoipRule,
                          ),
                        ),
                    optionsViewBuilder: (context, select, options) => Align(
                      alignment: AlignmentDirectional.topStart,
                      child: Material(
                        elevation: 4,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: 240,
                            maxWidth: MediaQuery.sizeOf(context).width - 80,
                          ),
                          child: SizedBox(
                            width: 440,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) => ListTile(
                                selected:
                                    AutocompleteHighlightedOption.of(context) ==
                                    index,
                                title: Text(
                                  options.elementAt(index),
                                  textDirection: TextDirection.ltr,
                                  style: AppTypography.code,
                                ),
                                onTap: () => select(options.elementAt(index)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.prototypeRemoveEntry,
                  onPressed: () => controller.removeValue(domain, entry),
                  icon: const Icon(LucideIcons.trash2),
                ),
              ],
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ShadButton.ghost(
            leading: const Icon(LucideIcons.plus),
            onPressed: () => controller.addValue(domain),
            child: Text(l10n.prototypeAddAnother),
          ),
        ),
      ],
    );
  }
}
