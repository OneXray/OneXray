import 'package:flutter/material.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/tunnel/controller.dart';
import 'package:onexray/pages/advanced/tunnel/apple_widgets.dart';
import 'package:onexray/pages/advanced/tunnel/widgets.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/connection/policy_editor.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
      return PolicyDetailScaffold(
        title: l.prototypeAppleSystemVpn,
        controller: controller,
        canSave: controller.capabilities != null,
        contentPadding: EdgeInsets.zero,
        body: AppleVpnView(
          controller: controller,
          capabilities: controller.capabilities,
          capabilityLoading: controller.capabilityLoading,
          onRetry: controller.readCapabilities,
          onEditWifi: () => controller.openChild(context, widget.openWifi),
        ),
      );
    },
  );
}

/// Presentation can be exercised without invoking Apple system APIs.
class AppleVpnView extends StatelessWidget {
  final PolicyEditorController controller;
  final AppleVpnCapabilities? capabilities;
  final bool capabilityLoading;
  final VoidCallback? onRetry;
  final VoidCallback? onEditWifi;

  const AppleVpnView({
    super.key,
    required this.controller,
    required this.capabilities,
    this.capabilityLoading = false,
    this.onRetry,
    this.onEditWifi,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context)!;
      final apple = controller.group('apple');
      final width = MediaQuery.sizeOf(context).width;
      final mobile = width <= AppLayout.mobileBreakpoint;
      final gutter = mobile ? 14.0 : AppSpacing.advancedDesktopGutter(width);
      Widget toggle(
        String field,
        String title,
        String description, {
        bool nested = false,
        bool supported = true,
      }) => AppleSettingToggle(
        key: ValueKey(field),
        title: title,
        description: description,
        nested: nested,
        value: apple[field] as bool,
        onChanged: controller.blocked || !supported
            ? null
            : (value) => controller.update(field, value, section: 'apple'),
      );
      return Padding(
        padding: EdgeInsets.fromLTRB(
          gutter,
          mobile ? 14 : 48,
          gutter,
          mobile ? 18 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (capabilities == null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: capabilityLoading
                    ? const CircularProgressIndicator()
                    : Column(
                        children: [
                          Text(l.prototypeTemporarilyUnavailable),
                          TextButton(
                            onPressed: onRetry,
                            child: Text(l.prototypeRetry),
                          ),
                        ],
                      ),
              ),
            SettingSection(
              title: '',
              padding: EdgeInsets.zero,
              dividerIndent: 0,
              children: [
                toggle(
                  'captureAllTraffic',
                  l.prototypeCaptureAllTraffic,
                  l.prototypeCaptureAllTrafficHint,
                ),
                if (apple['captureAllTraffic'] == true) ...[
                  toggle(
                    'allowLocalNetwork',
                    l.prototypeAllowLocalNetwork,
                    l.prototypeAllowLocalNetworkHint,
                    nested: true,
                  ),
                  toggle(
                    'bypassCellularServices',
                    l.prototypeBypassCellularServices,
                    capabilities?.serviceExclusions == true
                        ? l.prototypeBypassCellularServicesHint
                        : l.tunSettingsPageExcludeCellularServicesTip,
                    nested: true,
                    supported: capabilities?.serviceExclusions ?? false,
                  ),
                  toggle(
                    'bypassApplePushNotifications',
                    l.prototypeBypassApplePush,
                    capabilities?.serviceExclusions == true
                        ? l.prototypeBypassApplePushHint
                        : l.tunSettingsPageExcludeAPNsTip,
                    nested: true,
                    supported: capabilities?.serviceExclusions ?? false,
                  ),
                  toggle(
                    'allowDeviceCommunication',
                    l.prototypeAllowDeviceCommunication,
                    capabilities?.deviceCommunication == true
                        ? l.prototypeAllowDeviceCommunicationHint
                        : l.tunSettingsPageExcludeDeviceCommunicationTip,
                    nested: true,
                    supported: capabilities?.deviceCommunication ?? false,
                  ),
                ],
                toggle(
                  'dnsOverTls',
                  l.prototypeUseDnsOverTls,
                  l.prototypeUseDnsOverTlsHint,
                ),
              ],
            ),
            SizedBox(height: mobile ? 16 : 20),
            Text(
              l.prototypeAutomaticConnectionDisconnection,
              style: mobile
                  ? AppTypography.appleAutoTitle
                  : AppTypography.appleAutoTitleDesktop,
            ),
            SizedBox(height: mobile ? 8 : 10),
            SettingSection(
              title: '',
              padding: EdgeInsets.zero,
              dividerIndent: 0,
              children: [
                toggle(
                  'alwaysOn',
                  l.prototypeAlwaysOn,
                  l.prototypeAlwaysOnHint,
                ),
                if (apple['alwaysOn'] == false) ...[
                  toggle(
                    'onDemandEnabled',
                    l.prototypeConnectOnDemand,
                    l.prototypeConnectOnDemandHint,
                  ),
                  if (apple['onDemandEnabled'] == true)
                    Padding(
                      padding: mobile
                          ? const EdgeInsets.all(10)
                          : const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: AppleWifiPreview(
                        controller: controller,
                        showNetwork: true,
                        onEdit: controller.blocked ? null : onEditWifi,
                        editable: true,
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
      );
    },
  );
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
        contentPadding: EdgeInsets.zero,
        body: AppleWifiView(controller: controller),
      );
    },
  );
}

class AppleWifiView extends StatelessWidget {
  final PolicyEditorController controller;
  const AppleWifiView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context)!;
      final width = MediaQuery.sizeOf(context).width;
      final mobile = width <= AppLayout.mobileBreakpoint;
      final gutter = mobile ? 14.0 : AppSpacing.advancedDesktopGutter(width);
      final palette = ColorManager.palette(context);
      final gap = mobile ? 18.0 : 24.0;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          gutter,
          mobile ? 17 : 48,
          gutter,
          mobile ? 18 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final connect in [true, false])
              Padding(
                padding: EdgeInsets.only(bottom: gap, top: connect ? 0 : 2),
                child: AppleWifiEditorSection(
                  key: ValueKey(connect),
                  title: connect
                      ? l.prototypeWifiConnectNetworks
                      : l.prototypeWifiDisconnectNetworks,
                  description: connect
                      ? l.prototypeWifiConnectNetworksHint
                      : l.prototypeWifiDisconnectNetworksHint,
                  values: controller.strings(
                    'apple',
                    connect ? 'connectWifiSsids' : 'disconnectWifiSsids',
                  ),
                  otherValues: controller.strings(
                    'apple',
                    connect ? 'disconnectWifiSsids' : 'connectWifiSsids',
                  ),
                  onChanged: (values) => controller.update(
                    connect ? 'connectWifiSsids' : 'disconnectWifiSsids',
                    values,
                    section: 'apple',
                  ),
                  enabled: !controller.blocked,
                ),
              ),
            if (controller.wifiConflict)
              Semantics(
                liveRegion: true,
                child: Text(
                  l.prototypeWifiActionConflict,
                  style:
                      (mobile
                              ? AppTypography.appleWifiDescription
                              : AppTypography.appleWifiDescriptionDesktop)
                          .copyWith(color: palette.destructive),
                ),
              )
            else
              AppleWifiPreview(controller: controller),
            SizedBox(height: gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.info,
                  size: 17,
                  color: palette.mutedForeground,
                ),
                SizedBox(width: mobile ? 7 : 8),
                Expanded(
                  child: Text(
                    l.prototypeWifiExactMatchNotice,
                    style:
                        (mobile
                                ? AppTypography.appleWifiMatchNote
                                : AppTypography.appleWifiMatchNoteDesktop)
                            .copyWith(color: palette.mutedForeground),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
