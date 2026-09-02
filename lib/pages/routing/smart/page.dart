import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/routing/checker.dart';
import 'package:onexray/pages/routing/smart/controller.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SmartRoutingEditorPage extends StatefulWidget {
  final OpenDirectRegions openRegions;
  final OpenFinalExit openFinalExit;
  const SmartRoutingEditorPage({
    super.key,
    required this.openRegions,
    required this.openFinalExit,
  });
  @override
  State<SmartRoutingEditorPage> createState() => _SmartRoutingEditorPageState();
}

class _SmartRoutingEditorPageState extends State<SmartRoutingEditorPage> {
  final controller = SmartRoutingEditorController();
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      controller.load(context);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context)!;
      return PopScope(
        canPop: !controller.busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(l.prototypeSmartRouting),
            leading: BackButton(onPressed: () => controller.cancel(context)),
          ),
          body: SafeArea(
            child: controller.original == null
                ? Center(
                    child: controller.busy
                        ? const CircularProgressIndicator()
                        : TextButton(
                            onPressed: () => controller.load(context),
                            child: Text(l.prototypeRetry),
                          ),
                  )
                : SettingsPageScroll(
                    desktopMaxWidth: 1200,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l.prototypeSmartRulesMaintained),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final settings = _settings(context);
                            final preview = _preview(context);
                            if (constraints.maxWidth < 900) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  settings,
                                  const SizedBox(height: 16),
                                  preview,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 6, child: settings),
                                const SizedBox(width: 20),
                                Expanded(flex: 5, child: preview),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.busy) const LinearProgressIndicator(),
              if (controller.error case final error?)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              PageActionBar(
                children: [
                  ShadButton.outline(
                    onPressed: controller.busy
                        ? null
                        : () => controller.cancel(context),
                    child: Text(l.prototypeCancel),
                  ),
                  ShadButton(
                    onPressed: controller.busy || controller.original == null
                        ? null
                        : () => controller.save(context),
                    child: Text(l.prototypeSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _settings(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final smart = controller.draft;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l.prototypeSmartRoutingSettings,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            _switch(
              l.prototypeDirectPrivateAddresses,
              l.prototypeDirectPrivateAddressesHint,
              LucideIcons.network,
              'directPrivate',
              smart.directPrivate,
            ),
            _switch(
              l.prototypeDirectAppleServices,
              l.prototypeDirectAppleServicesHint,
              LucideIcons.apple,
              'directApple',
              smart.directApple,
            ),
            _switch(
              l.prototypeResolveUnmatchedDomains,
              l.prototypeResolveUnmatchedDomainsHint,
              LucideIcons.terminal,
              'resolveIpOnNoMatch',
              smart.resolveIpOnNoMatch,
            ),
            _switch(
              l.prototypeDirectDns,
              l.prototypeDirectDnsHint,
              LucideIcons.globe,
              'directDns',
              smart.directDns,
            ),
            _switch(
              l.prototypeBlockAdDomains,
              l.prototypeBlockAdDomainsHint,
              LucideIcons.shieldCheck,
              'blockAds',
              smart.blockAds,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(LucideIcons.zap),
              title: Text(l.prototypeAutomaticEntryServers),
              subtitle: Text(l.prototypeAutomaticEntryServersHint),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final count in const [1, 2, 3])
                    Tooltip(
                      message: l.prototypeUseEntryServers(count),
                      child: ChoiceChip(
                        label: Text('$count'),
                        selected: smart.entryCount == count,
                        onSelected: controller.busy
                            ? null
                            : (_) => controller.update('entryCount', count),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(LucideIcons.globe),
              title: Text(l.prototypeDirectRegions),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.prototypeDirectRegionsHint),
                  Text(
                    controller.regionsSummary(l),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              trailing: const Icon(LucideIcons.chevronRightDir),
              onTap: controller.busy
                  ? null
                  : () => controller.chooseRegions(context, widget.openRegions),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(LucideIcons.server),
              title: Text(l.prototypeVpnFinalExit),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.prototypeVpnFinalExitHint),
                  Text(
                    smart.finalExitId == null
                        ? l.prototypeNotSet
                        : controller.finalExitName ??
                              l.prototypeTemporarilyUnavailable,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              trailing: const Icon(LucideIcons.chevronRightDir),
              onTap: controller.busy
                  ? null
                  : () => controller.chooseFinalExit(
                      context,
                      widget.openFinalExit,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switch(
    String title,
    String description,
    IconData icon,
    String key,
    bool value,
  ) => SwitchListTile(
    secondary: Icon(icon),
    title: Text(title),
    subtitle: Text(description),
    value: value,
    onChanged: controller.busy
        ? null
        : (value) => controller.update(key, value),
  );

  Widget _preview(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.prototypeRoutingPreview,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  l.prototypeRoutingPreviewHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                _result(context, l.prototypeDirect, 'direct'),
                const Divider(height: 24),
                Text(
                  l.prototypeUseVpn,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(controller.vpnPath(l)),
                Text(
                  l.prototypeWhenNoRuleMatches,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (controller.effectiveEntryCount > 1)
                  Text(
                    l.prototypeDistributedEntries(
                      controller.effectiveEntryCount,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const Divider(height: 24),
                _result(context, l.prototypeBlock, 'block'),
                const SizedBox(height: 16),
                Text(
                  l.prototypeRuleOrderMaintained,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        RouteChecker(configuration: controller.checkConfiguration),
      ],
    );
  }

  Widget _result(BuildContext context, String title, String action) {
    final l = AppLocalizations.of(context)!;
    final rules = controller.rulesFor(action);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            Text(
              l.prototypeRuleCount(rules.length),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        if (rules.isEmpty) Text(l.prototypeNone),
        for (final rule in rules)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(controller.ruleLabel(rule, l)),
                SelectableText(
                  controller.ruleValues(rule),
                  textDirection: TextDirection.ltr,
                  style: AppTypography.code,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
