import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/outbound_freedom/controller.dart';
import 'package:onexray/pages/core/xray/profile/outbound_freedom/params.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class OutboundFreedomPage extends StatelessWidget {
  final OutboundFreedomParams params;

  const OutboundFreedomPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OutboundFreedomController(params),
      child: BlocBuilder<OutboundFreedomController, OutboundFreedomPageState>(
        builder: (context, state) {
          final controller = context.read<OutboundFreedomController>();
          final localizations = AppLocalizations.of(context)!;
          final editable = AppPlatform.isLinux || AppPlatform.isWindows;
          return SettingsPageScaffold(
            title: localizations.outboundFreedomPageTitle,
            onSave: editable ? () => controller.save(context) : null,
            body: SettingsPageScroll(
              desktopMaxWidth: 760,
              child: Column(
                children: [
                  SettingSection(
                    title: "",
                    children: [
                      SettingRow(
                        leading: const Icon(LucideIcons.waypoints),
                        title: localizations.outboundFreedomPageProtocol,
                        value: state.freedomState.protocol.name,
                      ),
                      SettingRow(
                        leading: const Icon(LucideIcons.tag),
                        title: localizations.outboundFreedomPageTag,
                        value: state.freedomState.tag.name,
                      ),
                    ],
                  ),
                  if (editable)
                    SettingSection(
                      title: localizations.outboundFreedomPageSockopt,
                      children: [
                        NavigationSettingRow(
                          leading: const Icon(LucideIcons.network),
                          title: localizations.outboundFreedomPageInterface,
                          value: state.freedomState.interface,
                          onTap: () => controller.editInterface(context),
                        ),
                      ],
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
