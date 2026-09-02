import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/tunnel/controller.dart';
import 'package:onexray/pages/advanced/tunnel/widgets.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/platform_policy.dart';
import 'package:onexray/service/connection/settings.dart';

/// Embedded below Advanced's tabs; the footer belongs to this full-page body.
class VpnTunnelPane extends StatefulWidget {
  final OpenTunnelPage? openTunnel;
  const VpnTunnelPane({super.key, this.openTunnel});
  @override
  State<VpnTunnelPane> createState() => _VpnTunnelPaneState();
}

class _VpnTunnelPaneState extends State<VpnTunnelPane> {
  final controller = PolicyEditorController();
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
      if (controller.draft == null) {
        return Center(
          child: controller.busy
              ? const CircularProgressIndicator()
              : TextButton(
                  onPressed: () => controller.load(context),
                  child: Text(l.prototypeRetry),
                ),
        );
      }
      return Scaffold(
        body: SettingsPageScroll(
          child: Column(
            children: [
              SettingSection(
                title: l.prototypeConnectionStatus,
                children: [
                  SettingRow(
                    title: l.prototypeSystemVpn,
                    leading: const Icon(LucideIcons.shield),
                    value: _status(l),
                  ),
                ],
              ),
              SettingSection(
                title: l.prototypeTunAddress,
                children: [
                  PolicyValueRow(
                    title: l.prototypeIpv4TunAddress,
                    value: '${PlatformPolicy.tunIpv4Address}/15',
                  ),
                  PolicyValueRow(
                    title: l.prototypeIpv6TunAddress,
                    value: '${PlatformPolicy.tunIpv6Address}/64',
                  ),
                ],
              ),
              SettingSection(
                title: l.prototypeTunnelDns,
                children: [
                  PolicyValueRow(
                    title: l.prototypeIpv4Dns,
                    value: PlatformPolicy.dnsIpv4Address,
                  ),
                  PolicyValueRow(
                    title: l.prototypeIpv6Dns,
                    value: PlatformPolicy.dnsIpv6Address,
                  ),
                  PolicyValueRow(
                    title: l.prototypeDomain,
                    value: PlatformPolicy.dnsServerName,
                  ),
                ],
              ),
              SettingSection(
                title: 'IPv6',
                description: controller.ipv6Conflict
                    ? l.prototypeIpv6BypassConflict
                    : null,
                children: [
                  PolicyToggle(
                    controller: controller,
                    field: 'ipv6Enabled',
                    title: l.prototypeUseIpv6,
                  ),
                ],
              ),
              if (controller.service.requiresInterface)
                SettingSection(
                  title: l.prototypeXrayOutboundInterface,
                  description: l.prototypeManagedInterfaceNotice,
                  children: [
                    SettingRow(
                      title: l.prototypeXrayOutboundInterface,
                      subtitle:
                          (controller.value['xrayOutboundInterfaceName']
                                  as String)
                              .isEmpty
                          ? l.prototypeChooseInterface
                          : controller.value['xrayOutboundInterfaceName']
                                as String,
                      showChevron: true,
                      enabled: !controller.blocked && widget.openTunnel != null,
                      onTap: () => _open(TunnelDestination.interface),
                    ),
                  ],
                ),
              if (controller.platform == ConnectionPlatform.ios ||
                  controller.platform == ConnectionPlatform.macos)
                _platformEntry(
                  l.prototypeAppleSystemVpn,
                  l.prototypeAppleVpnDescription,
                  TunnelDestination.apple,
                ),
              if (controller.platform == ConnectionPlatform.android)
                _platformEntry(
                  l.prototypeAndroidSystemVpn,
                  l.prototypeAndroidVpnDescription,
                  TunnelDestination.android,
                ),
              if (controller.platform == ConnectionPlatform.windows)
                _platformEntry(
                  l.prototypeWindowsSystemVpn,
                  l.prototypeWindowsVpnDescription,
                  TunnelDestination.windows,
                ),
            ],
          ),
        ),
        bottomNavigationBar: PolicyActions(
          controller: controller,
          cancel: controller.discard,
          cancelLabel: l.prototypeCancel,
          save: () => controller.save(context, pop: false),
        ),
      );
    },
  );

  Widget _platformEntry(
    String title,
    String description,
    TunnelDestination destination,
  ) => SettingSection(
    title: title,
    children: [
      SettingRow(
        title: description,
        showChevron: true,
        enabled: !controller.blocked && widget.openTunnel != null,
        onTap: () => _open(destination),
      ),
    ],
  );

  void _open(TunnelDestination destination) {
    final open = widget.openTunnel;
    if (open != null) {
      controller.openPlatform(context, destination, open);
    }
  }

  String _status(AppLocalizations l) =>
      switch (controller.service.coordinator.state.value.phase) {
        ConnectionPhase.disconnected => l.prototypeDisconnected,
        ConnectionPhase.preparing ||
        ConnectionPhase.connecting => l.prototypeConnecting,
        ConnectionPhase.connected => l.prototypeConnected,
        ConnectionPhase.disconnecting => l.prototypeDisconnecting,
        ConnectionPhase.recovering => l.prototypeReconnecting,
        ConnectionPhase.failed => l.prototypeConnectionFailed,
      };
}
