import 'package:flutter/material.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/tunnel/controller.dart';
import 'package:onexray/pages/advanced/tunnel/widgets.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/connection/policy_editor.dart';
import 'package:onexray/service/connection/settings.dart';

class AppleVpnController extends PolicyEditorController {
  AppleVpnCapabilities? capabilities;
  bool capabilityLoading = false;
  bool _disposed = false;
  AppleVpnController({required PolicyEditorDraft draft}) : super(draft: draft);

  Future<void> readCapabilities() async {
    capabilityLoading = true;
    notify();
    try {
      final value = await AppHostApi().appleVpnCapabilities();
      if (!_disposed) {
        capabilities = value;
      }
    } catch (_) {
      // Do not infer a product version from Darwin's kernel version.
      capabilities = null;
    } finally {
      capabilityLoading = false;
      notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AppleVpnPage extends StatefulWidget {
  final PolicyEditorDraft draft;
  final OpenPolicyChild openWifi;
  const AppleVpnPage({super.key, required this.draft, required this.openWifi});

  @override
  State<AppleVpnPage> createState() => _AppleVpnPageState();
}

class _AppleVpnPageState extends State<AppleVpnPage> {
  late final controller = AppleVpnController(draft: widget.draft)
    ..readCapabilities();

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
      final apple = controller.group('apple');
      final supported = controller.capabilities;
      return PolicyDetailScaffold(
        title: l.prototypeAppleSystemVpn,
        controller: controller,
        canSave: supported != null,
        body: Column(
          children: [
            if (supported == null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: controller.capabilityLoading
                    ? const CircularProgressIndicator()
                    : Column(
                        children: [
                          Text(l.prototypeTemporarilyUnavailable),
                          TextButton(
                            onPressed: controller.readCapabilities,
                            child: Text(l.prototypeRetry),
                          ),
                        ],
                      ),
              ),
            SettingSection(
              title: l.prototypeSystemVpnPolicy,
              children: [
                PolicyToggle(
                  controller: controller,
                  section: 'apple',
                  field: 'captureAllTraffic',
                  title: l.prototypeCaptureAllTraffic,
                  subtitle: l.prototypeCaptureAllTrafficHint,
                ),
                if (apple['captureAllTraffic'] == true) ...[
                  PolicyToggle(
                    controller: controller,
                    section: 'apple',
                    field: 'allowLocalNetwork',
                    title: l.prototypeAllowLocalNetwork,
                    subtitle: l.prototypeAllowLocalNetworkHint,
                  ),
                  PolicyToggle(
                    controller: controller,
                    section: 'apple',
                    field: 'bypassCellularServices',
                    supported: supported?.serviceExclusions ?? false,
                    title: l.prototypeBypassCellularServices,
                    subtitle: supported?.serviceExclusions == true
                        ? l.prototypeBypassCellularServicesHint
                        : l.tunSettingsPageExcludeCellularServicesTip,
                  ),
                  PolicyToggle(
                    controller: controller,
                    section: 'apple',
                    field: 'bypassApplePushNotifications',
                    supported: supported?.serviceExclusions ?? false,
                    title: l.prototypeBypassApplePush,
                    subtitle: supported?.serviceExclusions == true
                        ? l.prototypeBypassApplePushHint
                        : l.tunSettingsPageExcludeAPNsTip,
                  ),
                  PolicyToggle(
                    controller: controller,
                    section: 'apple',
                    field: 'allowDeviceCommunication',
                    supported: supported?.deviceCommunication ?? false,
                    title: l.prototypeAllowDeviceCommunication,
                    subtitle: supported?.deviceCommunication == true
                        ? l.prototypeAllowDeviceCommunicationHint
                        : l.tunSettingsPageExcludeDeviceCommunicationTip,
                  ),
                ],
                PolicyToggle(
                  controller: controller,
                  section: 'apple',
                  field: 'dnsOverTls',
                  title: l.prototypeUseDnsOverTls,
                  subtitle: l.prototypeUseDnsOverTlsHint,
                ),
              ],
            ),
            SettingSection(
              title: l.prototypeAutomaticConnectionDisconnection,
              children: [
                PolicyToggle(
                  controller: controller,
                  section: 'apple',
                  field: 'alwaysOn',
                  title: l.prototypeAlwaysOn,
                  subtitle: l.prototypeAlwaysOnHint,
                ),
                if (apple['alwaysOn'] == false) ...[
                  PolicyToggle(
                    controller: controller,
                    section: 'apple',
                    field: 'onDemandEnabled',
                    title: l.prototypeConnectOnDemand,
                    subtitle: l.prototypeConnectOnDemandHint,
                  ),
                  if (apple['onDemandEnabled'] == true) ...[
                    AppleWifiPreview(controller: controller),
                    _NetworkChoice(controller: controller),
                    SettingRow(
                      title: l.prototypeEditWifiRules,
                      showChevron: true,
                      enabled: !controller.blocked,
                      onTap: () =>
                          controller.openChild(context, widget.openWifi),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _NetworkChoice extends StatelessWidget {
  final PolicyEditorController controller;
  const _NetworkChoice({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final ios = controller.platform == ConnectionPlatform.ios;
    final field = ios ? 'cellularAction' : 'ethernetAction';
    return SettingSubsection(
      title: ios ? l.prototypeCellularNetwork : l.prototypeEthernet,
      children: [
        SettingRow(
          title: ios
              ? l.prototypeWhenUsingCellular
              : l.prototypeWhenUsingEthernet,
        ),
        for (final choice in ['connect', 'disconnect'])
          SettingsChoiceRow(
            title: choice == 'connect'
                ? l.prototypeConnectAutomatically
                : l.prototypeDisconnectVpn,
            selected: controller.group('apple')[field] == choice,
            onTap: controller.blocked
                ? null
                : () => controller.update(field, choice, section: 'apple'),
          ),
      ],
    );
  }
}

class AppleWifiPage extends StatefulWidget {
  final PolicyEditorDraft draft;
  const AppleWifiPage({super.key, required this.draft});
  @override
  State<AppleWifiPage> createState() => _AppleWifiPageState();
}

class _AppleWifiPageState extends State<AppleWifiPage> {
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
        title: l.prototypeWifiRules,
        controller: controller,
        canSave: !controller.wifiConflict,
        body: Column(
          children: [
            for (final connect in [true, false])
              SettingSection(
                title: connect
                    ? l.prototypeWifiConnectNetworks
                    : l.prototypeWifiDisconnectNetworks,
                description: connect
                    ? l.prototypeWifiConnectNetworksHint
                    : l.prototypeWifiDisconnectNetworksHint,
                children: [
                  PolicyStringList(
                    key: ValueKey(connect),
                    label: connect
                        ? l.prototypeWifiConnectNetworks
                        : l.prototypeWifiDisconnectNetworks,
                    values: controller.strings(
                      'apple',
                      connect ? 'connectWifiSsids' : 'disconnectWifiSsids',
                    ),
                    onChanged: (values) => controller.update(
                      connect ? 'connectWifiSsids' : 'disconnectWifiSsids',
                      values,
                      section: 'apple',
                    ),
                    enabled: !controller.blocked,
                    addLabel: l.prototypeAddWifi,
                    removeLabel: l.prototypeRemoveWifi,
                  ),
                ],
              ),
            if (controller.wifiConflict)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l.prototypeWifiActionConflict,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              )
            else
              AppleWifiPreview(controller: controller),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.prototypeWifiExactMatchNotice),
            ),
          ],
        ),
      );
    },
  );
}

class AppleWifiPreview extends StatelessWidget {
  final PolicyEditorController controller;
  const AppleWifiPreview({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final connect = controller
        .strings('apple', 'connectWifiSsids')
        .where((name) => name.trim().isNotEmpty)
        .toList();
    final disconnect = controller
        .strings('apple', 'disconnectWifiSsids')
        .where((name) => name.trim().isNotEmpty)
        .toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (connect.isEmpty && disconnect.isEmpty) ...[
            Text(l.prototypeNoWifiRules),
            Text(
              l.prototypeOtherNetworkRulesApply,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          for (final group in [connect, disconnect])
            if (group.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(l.prototypeConnectTo),
                    ...group.map((name) => Chip(label: Text(name))),
                    Text(
                      identical(group, connect)
                          ? l.prototypeThenConnectVpn
                          : l.prototypeThenDisconnectVpn,
                    ),
                  ],
                ),
              ),
          Text(
            l.prototypeOtherWifiNetworks,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(l.prototypeKeepCurrentConnection),
          Text(
            l.prototypeKeepCurrentConnectionHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
