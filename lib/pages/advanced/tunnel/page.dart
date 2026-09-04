import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/tunnel/controller.dart';
import 'package:onexray/pages/advanced/tunnel/widgets.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
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
      final width = MediaQuery.sizeOf(context).width;
      final mobile = width <= AppLayout.mobileBreakpoint;
      final gutter = mobile ? 15.0 : AppSpacing.advancedDesktopGutter(width);
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
          desktopMaxWidth: AppLayout.advancedMaxWidth,
          padding: EdgeInsets.zero,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              mobile ? 22 : 54,
              gutter,
              mobile ? 24 : 28,
            ),
            child: Column(
              spacing: mobile ? 25 : 28,
              children: [
                _section(
                  icon: LucideIcons.activity,
                  title: l.prototypeConnectionStatus,
                  children: [
                    SettingRow(
                      title: l.prototypeSystemVpn,
                      leading: Icon(
                        LucideIcons.circleCheck,
                        color: ColorManager.palette(context).running,
                      ),
                      decorateLeading: false,
                      minHeight: mobile ? 52 : 56,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: mobile ? 13 : 14,
                        vertical: 10,
                      ),
                      titleStyle:
                          (mobile
                                  ? AppTypography.settingsStatus
                                  : AppTypography.desktopSettingsStatus)
                              .copyWith(
                                color: ColorManager.palette(context).running,
                              ),
                      valueStyle:
                          (mobile
                                  ? AppTypography.settingsStatus
                                  : AppTypography.desktopSettingsStatus)
                              .copyWith(
                                color: ColorManager.primaryText(context),
                              ),
                      value: _status(l),
                    ),
                  ],
                ),
                _section(
                  icon: LucideIcons.network,
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
                _section(
                  icon: LucideIcons.globe2,
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
                _section(
                  icon: LucideIcons.network,
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
                  _section(
                    icon: LucideIcons.network,
                    title: l.prototypeXrayOutboundInterface,
                    description: l.prototypeManagedInterfaceNotice,
                    children: [
                      SettingRow(
                        title: l.prototypeXrayOutboundInterface,
                        value:
                            (controller.value['xrayOutboundInterfaceName']
                                    as String)
                                .isEmpty
                            ? l.prototypeChooseInterface
                            : controller.value['xrayOutboundInterfaceName']
                                  as String,
                        showChevron: true,
                        minHeight: mobile ? 52 : 56,
                        titleStyle: mobile
                            ? AppTypography.settingsValueLabel
                            : AppTypography.desktopSettingsValueLabel,
                        valueStyle:
                            (mobile
                                    ? AppTypography.settingsValue
                                    : AppTypography.desktopSettingsValue)
                                .copyWith(
                                  color: ColorManager.primaryText(context),
                                ),
                        enabled:
                            !controller.blocked && widget.openTunnel != null,
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
        ),
        bottomNavigationBar: PolicyActions(
          root: true,
          controller: controller,
          cancel: controller.restoreDefaults,
          cancelLabel: l.prototypeRestoreDefaults,
          cancelIcon: LucideIcons.rotateCcw,
          save: () => controller.save(context, pop: false),
        ),
      );
    },
  );

  Widget _platformEntry(
    String title,
    String description,
    TunnelDestination destination,
  ) => _section(
    icon: switch (destination) {
      TunnelDestination.apple => LucideIcons.apple,
      TunnelDestination.android => LucideIcons.appWindow,
      _ => LucideIcons.monitor,
    },
    title: title,
    children: [
      SettingRow(
        title: description,
        titleStyle: AppTypography.settingsRow,
        minHeight:
            MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint
            ? 52
            : 56,
        contentPadding: EdgeInsets.symmetric(
          horizontal:
              MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint
              ? 13
              : 14,
          vertical: 10,
        ),
        showChevron: true,
        enabled: !controller.blocked && widget.openTunnel != null,
        onTap: () => _open(destination),
      ),
    ],
  );

  Widget _section({
    required String title,
    required IconData icon,
    String? description,
    required List<Widget> children,
  }) => SettingSection(
    title: title,
    icon: icon,
    description: description,
    descriptionBelow: true,
    padding: EdgeInsets.zero,
    dividerIndent: 0,
    children: children,
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
