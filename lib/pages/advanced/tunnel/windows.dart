import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/tunnel/controller.dart';
import 'package:onexray/pages/advanced/tunnel/widgets.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/connection/policy_editor.dart';

class WindowsVpnPage extends StatefulWidget {
  final PolicyEditorDraft draft;
  final OpenPolicyChild openInterface;
  const WindowsVpnPage({
    super.key,
    required this.draft,
    required this.openInterface,
  });
  @override
  State<WindowsVpnPage> createState() => _WindowsVpnPageState();
}

class _WindowsVpnPageState extends State<WindowsVpnPage> {
  late final controller = PolicyEditorController(draft: widget.draft);
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
      return PolicyDetailScaffold(
        title: l.prototypeWindowsSystemVpn,
        controller: controller,
        body: Column(
          children: [
            SettingSection(
              title: l.prototypeSystemVpnPolicy,
              description: l.prototypeWindowsBypassNotice,
              children: [
                PolicyToggle(
                  controller: controller,
                  section: 'windows',
                  field: 'alwaysOn',
                  title: l.prototypeAlwaysOn,
                  subtitle: l.prototypeWindowsAutoConnectNotice,
                ),
                PolicyToggle(
                  controller: controller,
                  section: 'windows',
                  field: 'allowLocalNetwork',
                  title: l.prototypeBypassLocalSubnets,
                  subtitle: l.prototypeBypassLocalSubnetsHint,
                ),
              ],
            ),
            SettingSection(
              title: l.prototypeBypassNetworks,
              description: l.prototypeBypassNetworksHint,
              children: [
                PolicyStringList(
                  label: l.prototypeBypassNetworks,
                  values: controller.strings('windows', 'excludedCidrs'),
                  onChanged: (values) => controller.update(
                    'excludedCidrs',
                    values,
                    section: 'windows',
                  ),
                  enabled: !controller.blocked,
                  addLabel: l.prototypeAddNetwork,
                  removeLabel: l.prototypeRemoveEntry,
                  maxItems: 64,
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l.prototypeBypassNetworkInputHint),
                ),
                if (controller.value['ipv6Enabled'] == false)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      controller.ipv6Conflict
                          ? l.prototypeIpv6BypassConflict
                          : l.prototypeEnableIpv6ForBypass,
                    ),
                  ),
              ],
            ),
            if ((controller.value['xrayOutboundInterfaceName'] as String)
                .isEmpty)
              SettingSection(
                title: l.prototypeXrayOutboundInterface,
                description: l.prototypeChooseInterfaceBeforeSaving,
                children: [
                  SettingRow(
                    title: l.prototypeChooseInterface,
                    enabled: !controller.blocked,
                    showChevron: true,
                    onTap: () =>
                        controller.openChild(context, widget.openInterface),
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );
}
