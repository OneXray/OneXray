import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/controller.dart';
import 'package:onexray/pages/connect/view.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});
  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final controller = ConnectController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.initialize(context);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context)!.prototypeConnect)),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([
          controller,
          controller.coordinator.state,
        ]),
        builder: (context, _) {
          final l = AppLocalizations.of(context)!;
          if (controller.failed) {
            return Center(
              child: FilledButton(
                onPressed: () => controller.initialize(context),
                child: Text(l.prototypeRetry),
              ),
            );
          }
          if (!controller.ready) {
            return Center(
              child: Semantics(
                label: l.prototypePleaseWait,
                child: const CircularProgressIndicator(),
              ),
            );
          }
          return ConnectView(
            view: controller.coordinator.state.value,
            hasServers: controller.servers.isNotEmpty,
            expert: controller.expertView,
            raws: controller.raws,
            activeRawId: controller.configuration.connection.expert
                ? controller.configuration.connection.rawId
                : null,
            location: controller.selectionTitle(l),
            runningPath: controller.runningRoute?.path,
            method: controller.methodTitle(l),
            onConnection: () => controller.connectionAction(context),
            onAddServers: () => controller.addServers(context),
            onExpert: (value) => controller.toggleExpert(context, value),
            onServer: () => controller.chooseServer(context),
            onMethod: () => controller.chooseTrafficMethod(context),
            onWhy: () => controller.showWhy(context),
            onTraffic: () => controller.showTraffic(context),
            onRawAdd: () => controller.editRaw(context),
            onRawSelect: (row) => controller.selectRaw(context, row.id),
            onRawEdit: (row) => controller.editRaw(context, row.id),
            onRawDelete: (row) => controller.deleteRaw(context, row),
          );
        },
      ),
    ),
  );
}
