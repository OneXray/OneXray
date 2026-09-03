import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/controller.dart';
import 'package:onexray/pages/advanced/tunnel/controller.dart';
import 'package:onexray/pages/advanced/tunnel/page.dart';
import 'package:onexray/pages/advanced/tunnel/widgets.dart';
import 'package:onexray/pages/main/page_visibility.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
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
          body: SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(15, 18, 15, 0),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 58),
                          child: SizedBox(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.prototypeAdvanced,
                                  style:
                                      MediaQuery.sizeOf(context).width <=
                                          AppLayout.mobileBreakpoint
                                      ? AppTypography.advancedPageTitle
                                      : AppTypography.pageTitle,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  l.prototypeAdvancedDescription,
                                  style: AppTypography.settingsValueLabel
                                      .copyWith(
                                        color: ColorManager.secondaryText(
                                          context,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: TabBar(
                          isScrollable:
                              MediaQuery.sizeOf(context).width >
                              AppLayout.mobileBreakpoint,
                          labelStyle: AppTypography.selectedAdvancedTab,
                          unselectedLabelStyle: AppTypography.advancedTab,
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          tabs: [
                            Tab(height: 38, text: l.prototypeVpnTunnel),
                            Tab(
                              height: 38,
                              text: l.prototypeXrayRuntimeDiagnostics,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              body: TabBarView(
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
