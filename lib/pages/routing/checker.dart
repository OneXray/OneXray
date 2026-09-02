import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
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
  final target = TextEditingController();
  final port = TextEditingController(text: '443');
  String network = 'tcp';
  RouteCheckOutcome? result;
  bool busy = false;
  bool failed = false;
  int revision = 0;

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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.prototypeCheckWebsite,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: target,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: l.prototypeDomain,
                hintText: 'github.com',
              ),
              onChanged: (_) => setState(reset),
              onSubmitted: (_) => check(),
            ),
            if (widget.customDraft != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: port,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: l.prototypeTargetPort),
                onChanged: (_) => setState(reset),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: network,
                decoration: InputDecoration(labelText: l.prototypeNetworkType),
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
            ],
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton(
                onPressed: busy || target.text.trim().isEmpty ? null : check,
                child: Text(busy ? l.prototypePleaseWait : l.prototypeCheck),
              ),
            ),
            if (failed)
              Text(
                l.prototypeCheckNetwork,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (current != null)
              Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      vpn
                          ? l.prototypeUseVpn
                          : current.route.outboundTag == 'direct'
                          ? l.prototypeDirect
                          : l.prototypeBlock,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (vpn)
                      Text(current.path, textDirection: TextDirection.ltr),
                    Text('${l.prototypeMatchedRule}: $reason'),
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
          ],
        ),
      ),
    );
  }
}
