import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/outbound_fragment/controller.dart';
import 'package:onexray/pages/core/xray/profile/outbound_fragment/params.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class OutboundFragmentPage extends StatelessWidget {
  final OutboundFragmentParams params;

  const OutboundFragmentPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OutboundFragmentController(params),
      child: BlocBuilder<OutboundFragmentController, OutboundFragmentPageState>(
        builder: (context, state) {
          final controller = context.read<OutboundFragmentController>();
          final localizations = AppLocalizations.of(context)!;
          return SettingsPageScaffold(
            title: localizations.outboundFragmentPageTitle,
            onSave: () => controller.save(context),
            body: SettingsPageScroll(
              desktopMaxWidth: 860,
              child: SettingsResponsiveColumns(
                firstFlex: 4,
                secondFlex: 6,
                first: [
                  SettingSection(
                    title: "",
                    children: [
                      SettingRow(
                        leading: const Icon(LucideIcons.waypoints),
                        title: localizations.outboundFragmentPageProtocol,
                        value: state.fragmentState.protocol.name,
                      ),
                      SettingRow(
                        leading: const Icon(LucideIcons.tag),
                        title: localizations.outboundFragmentPageTag,
                        value: state.fragmentState.tag.name,
                      ),
                    ],
                  ),
                  if (AppPlatform.isLinux || AppPlatform.isWindows)
                    SettingSection(
                      title: localizations.outboundFragmentPageSockopt,
                      children: [
                        NavigationSettingRow(
                          leading: const Icon(LucideIcons.network),
                          title: localizations.outboundFragmentPageInterface,
                          value: state.fragmentState.interface,
                          onTap: () => controller.editInterface(context),
                        ),
                      ],
                    ),
                ],
                second: [
                  SettingSection(
                    title: localizations.outboundFragmentPageSettings,
                    children: [
                      TextFieldSettingRow(
                        controller: controller.packetsController,
                        label: localizations.outboundFragmentPagePackets,
                        hintText: localizations.outboundFragmentPagePackets,
                      ),
                      TextFieldSettingRow(
                        controller: controller.lengthController,
                        label: localizations.outboundFragmentPageLength,
                        hintText: localizations.outboundFragmentPageLength,
                      ),
                      TextFieldSettingRow(
                        controller: controller.intervalController,
                        label: localizations.outboundFragmentPageInterval,
                        hintText: localizations.outboundFragmentPageInterval,
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
