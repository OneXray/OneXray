import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/tunnel/controller.dart';
import 'package:onexray/pages/advanced/tunnel/widgets.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/app_icon/service.dart';
import 'package:onexray/service/connection/policy_editor.dart';

class AndroidVpnPage extends StatefulWidget {
  final PolicyEditorDraft draft;
  final OpenAndroidApps openApps;
  const AndroidVpnPage({
    super.key,
    required this.draft,
    required this.openApps,
  });
  @override
  State<AndroidVpnPage> createState() => _AndroidVpnPageState();
}

class _AndroidVpnPageState extends State<AndroidVpnPage> {
  late final controller = PolicyEditorController(draft: widget.draft);
  @override
  void dispose() {
    controller.dispose();
    AppIconService().clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context)!;
      final mode = controller.group('android')['appScope'] as String;
      final included = mode == 'included';
      final names = controller.strings(
        'android',
        included ? 'includedAppPackageNames' : 'excludedAppPackageNames',
      );
      return PolicyDetailScaffold(
        title: l.prototypeAndroidSystemVpn,
        controller: controller,
        body: Column(
          children: [
            SettingSection(
              title: l.prototypeVpnAppScope,
              description: l.prototypeChooseAndroidApps,
              children: [
                for (final choice in ['all', 'included', 'excluded'])
                  SettingsChoiceRow(
                    title: switch (choice) {
                      'all' => l.prototypeAllApps,
                      'included' => l.prototypeOnlySelectedApps,
                      _ => l.prototypeAllExceptSelectedApps,
                    },
                    description: switch (choice) {
                      'all' => l.prototypeAllAppsUseVpn,
                      'included' => l.prototypeOnlySelectedAppsUseVpn,
                      _ => l.prototypeSelectedAppsBypassVpn,
                    },
                    selected: mode == choice,
                    onTap: controller.blocked
                        ? null
                        : () => controller.update(
                            'appScope',
                            choice,
                            section: 'android',
                          ),
                  ),
              ],
            ),
            if (mode != 'all')
              SettingSection(
                title: included
                    ? l.prototypeAppsUsingVpn
                    : l.prototypeAppsBypassingVpn,
                description: l.prototypeSeparateAppListsNotice,
                children: [
                  SettingRow(
                    title: l.prototypeSelectApps,
                    subtitle: names.isEmpty
                        ? l.prototypeNoAppsSelected
                        : l.prototypeAppsSelectedCount(names.length),
                    showChevron: true,
                    enabled: !controller.blocked,
                    onTap: () =>
                        controller.selectApps(context, widget.openApps),
                  ),
                  if (included && names.isEmpty)
                    SettingRow(title: l.prototypeNoAppsSelected),
                ],
              ),
          ],
        ),
      );
    },
  );
}
