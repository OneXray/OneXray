import 'package:flutter/material.dart';
import 'package:onexray/pages/advanced/page.dart';
import 'package:onexray/pages/advanced/tunnel/controller.dart';
import 'package:onexray/pages/advanced/xray/page.dart';
import 'package:onexray/pages/main/navigation.dart';

/// Route wiring stays in the shell; platform pages only edit their own drafts.
class AdvancedRootPage extends StatelessWidget {
  const AdvancedRootPage({super.key});

  @override
  Widget build(BuildContext context) => AdvancedPage(
    openTunnel: (context, destination, draft) =>
        context.pushScoped<bool>(switch (destination) {
          TunnelDestination.apple => AppSecondaryDestination.appleVpn,
          TunnelDestination.android => AppSecondaryDestination.androidVpn,
          TunnelDestination.windows => AppSecondaryDestination.windowsVpn,
          TunnelDestination.interface =>
            AppSecondaryDestination.outboundInterface,
        }, extra: draft),
    xrayBuilder: (context) => XrayRuntimePage(
      onGeodata: (context) =>
          context.pushScoped(AppSecondaryDestination.routingData),
      onUpdates: (context) =>
          context.pushScoped(AppSecondaryDestination.autoUpdate),
      onSpeedTest: (context) =>
          context.pushScoped(AppSecondaryDestination.ping),
      onLog: (context, params) =>
          context.pushScoped(AppSecondaryDestination.logFile, extra: params),
      onConfig: (context, params) => context.pushScoped(
        AppSecondaryDestination.configFileViewer,
        extra: params,
      ),
    ),
  );
}
