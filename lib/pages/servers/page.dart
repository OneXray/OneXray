import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/controller.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/settings.dart';

class ServersPage extends StatefulWidget {
  const ServersPage({super.key, this.picker = false});
  final bool picker;
  @override
  State<ServersPage> createState() => _ServersPageState();
}

class _ServersPageState extends State<ServersPage> {
  final controller = ConnectController();
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
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.picker ? l.prototypeConnectionLocation : l.prototypeServers,
        ),
        actions: [
          IconButton(
            tooltip: l.prototypeAddServers,
            onPressed: () => controller.addServers(context),
            icon: const Icon(LucideIcons.plus),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            controller,
            controller.coordinator.state,
          ]),
          builder: (context, _) {
            if (controller.failed) {
              return Center(
                child: FilledButton(
                  onPressed: () =>
                      controller.initialize(context, services: false),
                  child: Text(l.prototypeRetry),
                ),
              );
            }
            if (!controller.ready) {
              return const Center(child: CircularProgressIndicator());
            }
            final view = controller.coordinator.state.value;
            final running = view.phase == ConnectionPhase.connected
                ? view.plan?.nodeIds ?? <int>{}
                : <int>{};
            final selection = controller.configuration.connection.selection;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ResponsiveContent(
                child: Column(
                  children: [
                    if (widget.picker)
                      ListTile(
                        leading: const Icon(LucideIcons.sparkles),
                        title: Text(l.prototypeAutomaticSelection),
                        subtitle: Text(l.prototypeChooseBySpeedAvailability),
                        selected: selection.kind == SelectionKind.automatic,
                        onTap: view.busy
                            ? null
                            : () => controller.selectServer(
                                context,
                                const ServerSelection.automatic(),
                                close: widget.picker,
                              ),
                      ),
                    if (controller.servers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Text(
                              l.prototypeFirstConnectionHint,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => controller.addServers(context),
                              icon: const Icon(LucideIcons.plus),
                              label: Text(l.prototypeAddServers),
                            ),
                          ],
                        ),
                      ),
                    for (final server in controller.servers)
                      ListTile(
                        selected: running.contains(server.id),
                        leading: Icon(
                          running.contains(server.id)
                              ? LucideIcons.circleCheck
                              : LucideIcons.server,
                        ),
                        title: Text(controller.serverName(server)),
                        subtitle: Text(
                          server.tags
                              .split(',')
                              .where((tag) => tag.isNotEmpty)
                              .join(' | ')
                              .toUpperCase(),
                          textDirection: TextDirection.ltr,
                        ),
                        trailing: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            if (server.delay > 0)
                              Text(
                                '${server.delay} ms',
                                textDirection: TextDirection.ltr,
                              ),
                            if (selection.kind == SelectionKind.server &&
                                selection.id == server.id)
                              const Icon(LucideIcons.check),
                          ],
                        ),
                        onTap: view.busy
                            ? null
                            : () => controller.selectServer(
                                context,
                                ServerSelection.server(server.id),
                                close: widget.picker,
                              ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
