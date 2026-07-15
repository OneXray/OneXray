import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/toolbox/controller.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ToolboxPage extends StatelessWidget {
  const ToolboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ToolboxController(),
      child: BlocBuilder<ToolboxController, ToolboxPageState>(
        builder: (context, state) {
          final controller = context.read<ToolboxController>();
          final l10n = AppLocalizations.of(context)!;
          return SettingsPageScaffold(
            title: l10n.toolboxPageTitle,
            body: SettingsPageScroll(
              desktopMaxWidth: 720,
              child: SettingSection(
                title: "macOS",
                children: [
                  SwitchSettingRow(
                    title: l10n.toolboxPageHideDockIcon,
                    subtitle: l10n.toolboxPageHideDockIconDescription,
                    leading: const Icon(LucideIcons.monitorCog),
                    value: state.hideDockIcon,
                    onChanged: controller.updateHideDockIcon,
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
