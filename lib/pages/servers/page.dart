import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/servers/controller.dart';
import 'package:onexray/pages/servers/view.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/widget/responsive_content.dart';

class ServersPage extends StatefulWidget {
  const ServersPage({super.key});
  @override
  State<ServersPage> createState() => _ServersPageState();
}

class _ServersPageState extends State<ServersPage> {
  final controller = ServersController();
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.initialize(context, services: false);
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, controller.coordinator.state]),
    builder: (context, _) {
      final l = AppLocalizations.of(context)!;
      final mobileRoot =
          MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
      return Scaffold(
        appBar: AppBar(
          title: Text(l.prototypeServers),
          actions: [
            if (!mobileRoot)
              IconButton(
                tooltip: l.prototypeManageSources,
                onPressed: () => controller.openSources(context),
                icon: const Icon(LucideIcons.refreshCw),
              ),
            IconButton(
              style: mobileRoot ? AppTheme.mobileHeaderAction(context) : null,
              tooltip: l.prototypeAddServers,
              onPressed: () => controller.addServers(context),
              icon: const Icon(LucideIcons.plus),
            ),
          ],
        ),
        body: SafeArea(
          child: ServerLoadState(
            controller: controller,
            child: ResponsiveContent(
              desktopMaxWidth: 1200,
              child: ServerBrowser(controller: controller, scroll: scroll),
            ),
          ),
        ),
      );
    },
  );
}

class ServerGroupPage extends StatelessWidget {
  final ServerGroupParams params;
  const ServerGroupPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    final controller = params.controller;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.coordinator.state]),
      builder: (context, _) {
        final l = AppLocalizations.of(context)!;
        final group = controller
            .groups(l)
            .where((row) => row.id == params.groupId)
            .firstOrNull;
        return Scaffold(
          appBar: AppBar(title: Text(group?.name ?? l.prototypeServers)),
          body: SafeArea(
            child: ResponsiveContent(
              child: group == null
                  ? Center(child: Text(l.prototypeNoServersYet))
                  : ServerGroupView(
                      controller: controller,
                      group: group,
                      groupPage: true,
                    ),
            ),
          ),
        );
      },
    );
  }
}

class ServerLoadState extends StatelessWidget {
  final ServersController controller;
  final Widget child;
  const ServerLoadState({
    super.key,
    required this.controller,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (controller.failed) {
      return Center(
        child: FilledButton(
          onPressed: () => controller.initialize(context, services: false),
          child: Text(l.prototypeRetry),
        ),
      );
    }
    if (!controller.ready) {
      return const Center(child: CircularProgressIndicator());
    }
    return child;
  }
}
