import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/routing/checker.dart';
import 'package:onexray/pages/routing/smart/controller.dart';
import 'package:onexray/pages/routing/widgets.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/button_progress.dart';
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
      final mobile =
          MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
      return Scaffold(
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
                  desktopMaxWidth: 1220,
                  padding: EdgeInsetsDirectional.fromSTEB(
                    mobile ? AppSpacing.mobilePage : AppSpacing.page,
                    12,
                    mobile ? AppSpacing.mobilePage : AppSpacing.page,
                    mobile ? 18 : 42,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!mobile) ...[
                        Text(
                          l.prototypeSmartRulesMaintained,
                          style: AppTypography.rowValue.copyWith(
                            color: ColorManager.secondaryText(context),
                          ),
                        ),
                        const SizedBox(height: 22),
                      ],
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final settings = _settings(context);
                          final preview = _preview(context);
                          if (constraints.maxWidth < 900) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                settings,
                                SizedBox(height: mobile ? 12 : 16),
                                preview,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 25, child: settings),
                              const SizedBox(width: 16),
                              Expanded(flex: 24, child: preview),
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
            if (controller.error case final error?)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
            PageActionBar(
              children: [
                if (!mobile)
                  OutlinedButton(
                    onPressed: () => controller.cancel(context),
                    child: Text(l.prototypeCancel),
                  ),
                FilledButton(
                  onPressed: controller.busy || controller.original == null
                      ? null
                      : () => controller.save(context),
                  child: ButtonProgress(
                    busy: controller.busy && controller.original != null,
                    child: Text(l.prototypeSave),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  Widget _settings(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final smart = controller.draft;
    return RoutingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RoutingCardHeader(title: l.prototypeSmartRoutingSettings),
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
            LucideIcons.earth,
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
          RoutingEntryCountRow(
            value: smart.entryCount,
            onChanged: (count) => controller.update('entryCount', count),
          ),
          RoutingSettingRow(
            icon: LucideIcons.earth,
            title: l.prototypeDirectRegions,
            description: l.prototypeDirectRegionsHint,
            value: controller.regionsSummary(l),
            enabled: !controller.busy,
            onTap: () => controller.chooseRegions(context, widget.openRegions),
          ),
          RoutingSettingRow(
            icon: LucideIcons.server,
            title: l.prototypeVpnFinalExit,
            description: l.prototypeVpnFinalExitHint,
            value: smart.finalExitId == null
                ? l.prototypeNotSet
                : controller.finalExitName ?? l.prototypeTemporarilyUnavailable,
            enabled: !controller.busy,
            divider: false,
            onTap: () =>
                controller.chooseFinalExit(context, widget.openFinalExit),
          ),
        ],
      ),
    );
  }

  Widget _switch(
    String title,
    String description,
    IconData icon,
    String key,
    bool value,
  ) => RoutingSettingRow(
    icon: icon,
    title: title,
    description: description,
    enabled: controller.original != null,
    trailing: Semantics(
      label: title,
      child: ShadSwitch(
        value: value,
        enabled: controller.original != null,
        onChanged: (value) => controller.update(key, value),
      ),
    ),
  );

  Widget _preview(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    return RoutingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RoutingCardHeader(
            title: l.prototypeRoutingPreview,
            description: l.prototypeRoutingPreviewHint,
          ),
          _result(
            context,
            l.prototypeDirect,
            controller.directPreview(l),
            palette.runningText,
            palette.runningSurface,
          ),
          _result(
            context,
            'VPN',
            controller.vpnPath(l),
            palette.primary,
            palette.selectedSurface,
            hint: controller.effectiveEntryCount > 1
                ? l.prototypeDistributedEntries(controller.effectiveEntryCount)
                : null,
          ),
          _result(
            context,
            l.prototypeBlock,
            controller.blockPreview(l),
            palette.destructive,
            palette.destructiveSurface,
          ),
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: palette.border),
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.prototypeSmartRuleSummary(
                    controller.rulesFor('direct').length,
                  ),
                  style: AppTypography.routingPreviewMeta.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.prototypeRuleOrderMaintained,
                  style: AppTypography.routingPreviewMeta.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          RouteChecker(configuration: controller.checkConfiguration),
          SizedBox(height: mobile ? 8 : 12),
        ],
      ),
    );
  }

  Widget _result(
    BuildContext context,
    String title,
    String description,
    Color foreground,
    Color background, {
    String? hint,
  }) {
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    return Container(
      constraints: BoxConstraints(minHeight: mobile ? 64 : 74),
      margin: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: foreground,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.routingPreviewTitle.copyWith(
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            description,
            style: AppTypography.routingPreviewBody.copyWith(color: foreground),
          ),
          if (hint != null) ...[
            const SizedBox(height: 5),
            Text(
              hint,
              style: AppTypography.routingPreviewHint.copyWith(
                color: foreground.withValues(alpha: .8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
