import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule_dns_dot/controller.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule_dns_dot/params.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RoutingRuleDnsDoTPage extends StatelessWidget {
  final RoutingRuleDnsDoTParams params;

  const RoutingRuleDnsDoTPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RoutingRuleDnsDoTController(params),
      child:
          BlocBuilder<RoutingRuleDnsDoTController, RoutingRuleDnsDoTPageState>(
            builder: (context, state) {
              final controller = context.read<RoutingRuleDnsDoTController>();
              final localizations = AppLocalizations.of(context)!;
              return SettingsPageScaffold(
                title: localizations.routingRulePageTitle,
                onSave: () => controller.save(context),
                body: SettingsPageScroll(
                  desktopMaxWidth: 760,
                  child: SettingSection(
                    title: state.ruleState.ruleTag,
                    children: [
                      SettingRow(
                        leading: const Icon(LucideIcons.logIn),
                        title: localizations.routingRulePageInboundTag,
                        value: state.ruleState.inboundTag.join(', '),
                      ),
                      SettingRow(
                        leading: const Icon(LucideIcons.radioTower),
                        title: localizations.routingRulePagePort,
                        value: state.ruleState.port,
                      ),
                      SelectSettingRow<String>(
                        leading: const Icon(LucideIcons.logOut),
                        title: localizations.routingRulePageOutboundTag,
                        value: state.ruleState.outboundTag,
                        selections: state.outboundTags,
                        onSelected: controller.updateOutboundTag,
                      ),
                      SettingRow(
                        leading: const Icon(LucideIcons.tag),
                        title: localizations.routingRulePageRuleTag,
                        value: state.ruleState.ruleTag,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}
