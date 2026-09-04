import 'package:flutter/material.dart';
import 'package:onexray/pages/widget/button_progress.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/service/connection/plan.dart';
import 'package:onexray/service/routing/checker.dart';
import 'package:onexray/service/routing/custom_template.dart';

class RouteChecker extends StatefulWidget {
  final ConnectionConfiguration configuration;
  final CustomRoutingTemplate? customDraft;
  final Future<void> Function(String)? prepareAssets;
  const RouteChecker({
    super.key,
    required this.configuration,
    this.customDraft,
    this.prepareAssets,
  });

  @override
  State<RouteChecker> createState() => _RouteCheckerState();
}

class _RouteCheckerState extends State<RouteChecker> {
  final target = TextEditingController(text: 'github.com');
  final port = TextEditingController(text: '443');
  String network = 'tcp';
  RouteCheckOutcome? result;
  bool busy = false;
  bool failed = false;
  int revision = 0;
  bool expanded = false;

  void reset() {
    revision++;
    result = null;
    failed = false;
  }

  @override
  void didUpdateWidget(RouteChecker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configuration.encode() != widget.configuration.encode() ||
        oldWidget.customDraft?.encode() != widget.customDraft?.encode()) {
      reset();
    }
  }

  @override
  void dispose() {
    target.dispose();
    port.dispose();
    super.dispose();
  }

  Future<void> check() async {
    if (busy || target.text.trim().isEmpty) return;
    final currentRevision = revision;
    setState(() {
      busy = true;
      result = null;
      failed = false;
    });
    try {
      final value = await RouteCheckService().check(
        widget.configuration,
        target.text,
        customDraft: widget.customDraft,
        prepareAssets: widget.prepareAssets,
        port: widget.customDraft == null ? 443 : int.parse(port.text),
        network: network,
      );
      if (mounted && revision == currentRevision) {
        setState(() => result = value);
      }
    } catch (_) {
      if (mounted && revision == currentRevision) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final current = result;
    final vpn =
        current != null &&
        !{'direct', 'block'}.contains(current.route.outboundTag);
    final reason = switch (current?.ruleName) {
      'private-ip' || 'private-domain' => l.prototypeDirectPrivateAddresses,
      'apple' => l.prototypeDirectAppleServices,
      'regions-domain' || 'regions-ip' => l.prototypeDirectRegions,
      'ads' => l.prototypeBlockAdDomains,
      final name? => name,
      null => l.prototypeNoneDefault,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            expanded: expanded,
            child: InkWell(
              onTap: () => setState(() => expanded = !expanded),
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.globe, size: 18, color: palette.primary),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.customDraft == null
                                ? l.prototypeCheckWebsite
                                : l.prototypeCheckRules,
                            style: AppTypography.routingSelectionTitle,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            l.prototypeRuleCheckPrivacy,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.routingSelectionDescription
                                .copyWith(color: palette.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 11),
                    Icon(
                      expanded
                          ? LucideIcons.chevronDown
                          : LucideIcons.chevronRightDir,
                      size: 18,
                      color: palette.mutedForeground,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: TextField(
                            controller: target,
                            textDirection: TextDirection.ltr,
                            style: AppTypography.routingConditionInput,
                            decoration: InputDecoration(
                              hintText: l.prototypeWebsiteOrIpAddress,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                            onChanged: (_) => setState(reset),
                            onSubmitted: (_) => check(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          textStyle: AppTypography.configurationTool,
                        ),
                        onPressed: busy || target.text.trim().isEmpty
                            ? null
                            : check,
                        child: ButtonProgress(
                          busy: busy,
                          child: Text(l.prototypeCheck),
                        ),
                      ),
                    ],
                  ),
                  if (widget.customDraft != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.prototypeTargetPort,
                                style: AppTypography.routeIdentityLabel
                                    .copyWith(color: palette.mutedStrong),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 42,
                                child: TextField(
                                  controller: port,
                                  keyboardType: TextInputType.number,
                                  textDirection: TextDirection.ltr,
                                  style: AppTypography.routingConditionInput,
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                  ),
                                  onChanged: (_) => setState(reset),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.prototypeNetworkType,
                                style: AppTypography.routeIdentityLabel
                                    .copyWith(color: palette.mutedStrong),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 42,
                                child: DropdownButtonFormField<String>(
                                  initialValue: network,
                                  style: AppTypography.routingConditionInput
                                      .copyWith(color: palette.foreground),
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                  ),
                                  items: [
                                    for (final value in ['tcp', 'udp'])
                                      DropdownMenuItem(
                                        value: value,
                                        child: Text(value.toUpperCase()),
                                      ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        network = value;
                                        reset();
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      l.prototypeRuleCheckScope,
                      style: AppTypography.routingRowDescription.copyWith(
                        color: palette.mutedForeground,
                      ),
                    ),
                  ],
                  if (failed)
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: Text(
                        l.prototypeCheckNetwork,
                        style: AppTypography.routingRowDescription.copyWith(
                          color: palette.destructive,
                        ),
                      ),
                    ),
                  if (current != null)
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        margin: const EdgeInsets.only(top: 9),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: palette.muted,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: DefaultTextStyle(
                          style: AppTypography.routingRowDescription.copyWith(
                            color: palette.mutedForeground,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                vpn
                                    ? l.prototypeUseVpn
                                    : current.route.outboundTag == 'direct'
                                    ? l.prototypeDirect
                                    : l.prototypeBlock,
                                style: AppTypography.routingSelectionTitle
                                    .copyWith(
                                      color: vpn
                                          ? palette.primary
                                          : current.route.outboundTag ==
                                                'direct'
                                          ? palette.running
                                          : palette.destructive,
                                    ),
                              ),
                              const SizedBox(height: 5),
                              if (vpn)
                                Text(
                                  current.path,
                                  textDirection: TextDirection.ltr,
                                ),
                              Text('${l.prototypeMatchedRule}: $reason'),
                              const SizedBox(height: 5),
                              Text(
                                'DNS: ${current.dnsDirect == null
                                    ? '—'
                                    : current.dnsDirect!
                                    ? l.prototypeDirect
                                    : l.prototypeUseVpn}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
