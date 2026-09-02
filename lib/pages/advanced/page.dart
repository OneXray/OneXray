import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/controller.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/connection/platform_policy.dart';

class AdvancedPage extends StatelessWidget {
  const AdvancedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocProvider(
      create: (_) => AdvancedController(),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.prototypeAdvanced),
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: l10n.prototypeVpnTunnel),
                Tab(text: l10n.prototypeXrayRuntimeDiagnostics),
              ],
            ),
          ),
          body: SafeArea(
            child: BlocBuilder<AdvancedController, AdvancedPageState>(
              builder: (context, state) {
                final controller = context.read<AdvancedController>();
                if (state.failed) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.prototypeTemporarilyUnavailable),
                        TextButton(
                          onPressed: controller.reload,
                          child: Text(l10n.prototypeRetry),
                        ),
                      ],
                    ),
                  );
                }
                final policy = state.policy;
                if (policy == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final status = controller.statusLabel(l10n);
                return TabBarView(
                  children: [
                    SettingsPageScroll(
                      child: Column(
                        children: [
                          SettingSection(
                            title: l10n.prototypeConnectionStatus,
                            children: [
                              SettingRow(
                                title: l10n.prototypeSystemVpn,
                                leading: const Icon(LucideIcons.shield),
                                value: status,
                              ),
                            ],
                          ),
                          SettingSection(
                            title: l10n.prototypeVpnTunnel,
                            children: [
                              _ValueRow(
                                label: l10n.prototypeIpv4TunAddress,
                                value: '${PlatformPolicy.tunIpv4Address}/15',
                              ),
                              _ValueRow(
                                label: l10n.prototypeIpv6TunAddress,
                                value: '${PlatformPolicy.tunIpv6Address}/64',
                              ),
                            ],
                          ),
                          SettingSection(
                            title: l10n.prototypeTunnelDns,
                            children: [
                              _ValueRow(
                                label: l10n.prototypeIpv4Dns,
                                value: PlatformPolicy.dnsIpv4Address,
                              ),
                              _ValueRow(
                                label: l10n.prototypeIpv6Dns,
                                value: PlatformPolicy.dnsIpv6Address,
                              ),
                              _ValueRow(
                                label: l10n.prototypeDomain,
                                value: PlatformPolicy.dnsServerName,
                              ),
                            ],
                          ),
                          SettingSection(
                            title: 'IPv6',
                            description: l10n.prototypeReadOnly,
                            children: [
                              _FlagRow(
                                label: l10n.prototypeUseIpv6,
                                value: policy.ipv6Enabled,
                              ),
                            ],
                          ),
                          if (controller.showInterface)
                            SettingSection(
                              title: l10n.prototypeXrayOutboundInterface,
                              description: l10n.prototypeReadOnly,
                              children: [
                                _ValueRow(
                                  label: l10n.prototypeXrayOutboundInterface,
                                  value:
                                      policy.xrayOutboundInterfaceName.isEmpty
                                      ? l10n.prototypeNotSelected
                                      : policy.xrayOutboundInterfaceName,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    SettingsPageScroll(
                      child: Column(
                        children: [
                          SettingSection(
                            title: l10n.prototypeRuntimeStatus,
                            children: [
                              SettingRow(
                                title: l10n.prototypeXrayCore,
                                value: status,
                                leading: const Icon(LucideIcons.activity),
                              ),
                              _ValueRow(
                                label: l10n.prototypeVersion,
                                value: state.xrayVersion,
                              ),
                              _ValueRow(
                                label: l10n.prototypeUptime,
                                value: state.uptime,
                              ),
                            ],
                          ),
                          SettingSection(
                            title: l10n.prototypeLogs,
                            description: l10n.prototypeManagedLogNotice,
                            children: [
                              _FlagRow(
                                label: l10n.prototypeRecordXrayLogs,
                                value: policy.logEnabled,
                              ),
                              if (policy.logEnabled) ...[
                                _ValueRow(
                                  label: l10n.prototypeErrorLogLevel,
                                  value: policy.logLevel,
                                ),
                                _FlagRow(
                                  label: l10n.prototypeRecordDnsQueries,
                                  value: policy.recordDns,
                                ),
                                _FlagRow(
                                  label: l10n.prototypeHideLogIpAddresses,
                                  value: policy.maskAddress.isNotEmpty,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String label;
  final String value;
  const _ValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => SettingRow(
    title: label,
    subtitleWidget: SelectableText(
      value,
      textDirection: TextDirection.ltr,
      style: AppTypography.code,
    ),
  );
}

class _FlagRow extends StatelessWidget {
  final String label;
  final bool value;
  const _FlagRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => SettingRow(
    title: label,
    trailing: Semantics(
      toggled: value,
      readOnly: true,
      child: Icon(value ? LucideIcons.check : LucideIcons.x),
    ),
  );
}
