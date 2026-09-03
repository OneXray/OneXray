import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/controller.dart';
import 'package:onexray/pages/advanced/tunnel/controller.dart';
import 'package:onexray/pages/advanced/tunnel/page.dart';
import 'package:onexray/pages/advanced/tunnel/widgets.dart';
import 'package:onexray/pages/main/page_visibility.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';

class AdvancedPage extends StatelessWidget {
  final WidgetBuilder? xrayBuilder;
  final OpenTunnelPage? openTunnel;
  const AdvancedPage({super.key, this.xrayBuilder, this.openTunnel});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return BlocProvider(
      create: (_) => AdvancedController(),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(l.prototypeAdvanced),
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: l.prototypeVpnTunnel),
                Tab(text: l.prototypeXrayRuntimeDiagnostics),
              ],
            ),
          ),
          body: SafeArea(
            child: TabBarView(
              children: [
                VpnTunnelPane(openTunnel: openTunnel),
                Builder(
                  builder: (context) {
                    final tabs = DefaultTabController.of(context);
                    return ListenableBuilder(
                      listenable: tabs,
                      builder: (_, child) =>
                          TickerMode(enabled: tabs.index == 1, child: child!),
                      child: Builder(builder: xrayBuilder ?? _runtimeSummary),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _runtimeSummary(BuildContext context) =>
      BlocBuilder<AdvancedController, AdvancedPageState>(
        builder: (context, state) {
          final l = AppLocalizations.of(context)!;
          final controller = context.read<AdvancedController>();
          return PageVisibility(
            onChanged: controller.setVisible,
            child: SettingsPageScroll(
              child: SettingSection(
                title: l.prototypeRuntimeStatus,
                children: [
                  SettingRow(
                    title: l.prototypeXrayCore,
                    value: controller.statusLabel(l),
                    leading: const Icon(LucideIcons.activity),
                  ),
                  PolicyValueRow(
                    title: l.prototypeVersion,
                    value: state.xrayVersion,
                  ),
                  PolicyValueRow(title: l.prototypeUptime, value: state.uptime),
                ],
              ),
            ),
          );
        },
      );
}
