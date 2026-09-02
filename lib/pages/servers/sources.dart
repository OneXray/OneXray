import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/servers/controller.dart';
import 'package:onexray/pages/servers/page.dart';
import 'package:onexray/pages/servers/view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';

class ServerSourcesPage extends StatefulWidget {
  const ServerSourcesPage({super.key});
  @override
  State<ServerSourcesPage> createState() => _ServerSourcesPageState();
}

class _ServerSourcesPageState extends State<ServerSourcesPage> {
  final controller = ServersController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.initialize(context, services: false);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, controller.coordinator.state]),
    builder: (context, _) {
      final l = AppLocalizations.of(context)!;
      final material = MaterialLocalizations.of(context);
      return Scaffold(
        appBar: AppBar(
          title: Text(l.prototypeUpdatesAndSources),
          actions: [
            IconButton(
              tooltip: l.prototypeAddServers,
              icon: const Icon(LucideIcons.plus),
              onPressed: controller.busy
                  ? null
                  : () => controller.addServers(context),
            ),
          ],
        ),
        body: SafeArea(
          child: ServerLoadState(
            controller: controller,
            child: ResponsiveContent(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    l.prototypeSourceUpdateGuard,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (controller.actionBusy) const LinearProgressIndicator(),
                  if (controller.sources.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l.prototypeNoServersYet),
                    ),
                  for (final source in controller.sources)
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(source.name),
                              subtitle: Text(
                                l.prototypeServerCount(
                                  controller.sourceCount(source.id),
                                ),
                              ),
                              trailing: SourceMenu(
                                controller: controller,
                                source: source,
                              ),
                            ),
                            Text(
                              '${l.prototypeLastSuccessfulUpdate}: ${material.formatMediumDate(source.timestamp.toLocal())} '
                              '${material.formatTimeOfDay(TimeOfDay.fromDateTime(source.timestamp.toLocal()))}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (controller.sourceErrors[source.id] != null)
                              Text(
                                controller.sourceErrors[source.id]!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                              ),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text(l.prototypeAutomaticChecks),
                              value: source.autoUpdate,
                              onChanged: controller.busy
                                  ? null
                                  : (value) => controller.setAutomatic(
                                      context,
                                      source,
                                      value,
                                    ),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: controller.busy
                                      ? null
                                      : () => controller.sourceAction(
                                          context,
                                          source,
                                          SourceAction.update,
                                        ),
                                  icon: const Icon(LucideIcons.refreshCw),
                                  label: Text(l.prototypeCheckForUpdates),
                                ),
                                TextButton(
                                  onPressed: controller.busy
                                      ? null
                                      : () => controller.sourceAction(
                                          context,
                                          source,
                                          SourceAction.edit,
                                        ),
                                  child: Text(l.prototypeEdit),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
