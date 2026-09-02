import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/xray/controller.dart';
import 'package:onexray/pages/core/log/config_file_viewer/params.dart';
import 'package:onexray/pages/core/log/log_file_viewer/params.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';

/// Embedded in the root Advanced tab. Child details use the root router.
class XrayRuntimePage extends StatefulWidget {
  const XrayRuntimePage({
    super.key,
    required this.onGeodata,
    required this.onUpdates,
    required this.onSpeedTest,
    required this.onLog,
    required this.onConfig,
  });
  final void Function(BuildContext) onGeodata;
  final void Function(BuildContext) onUpdates;
  final void Function(BuildContext) onSpeedTest;
  final void Function(BuildContext, LogFileViewerParams) onLog;
  final void Function(BuildContext, ConfigFileViewerParams) onConfig;
  @override
  State<XrayRuntimePage> createState() => _XrayRuntimePageState();
}

class _XrayRuntimePageState extends State<XrayRuntimePage> {
  final controller = XrayRuntimeController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context)!;
      final disabled = controller.busy;
      return Scaffold(
        bottomNavigationBar: controller.base == null
            ? null
            : PageActionBar(
                children: [
                  OutlinedButton.icon(
                    onPressed: disabled ? null : controller.restoreDefaults,
                    icon: const Icon(LucideIcons.rotateCcw, size: 18),
                    label: Text(l.prototypeRestoreDefaults),
                  ),
                  TextButton(
                    onPressed: controller.busy ? null : controller.load,
                    child: Text(l.prototypeCancel),
                  ),
                  FilledButton(
                    onPressed: disabled || !controller.dirty
                        ? null
                        : () => controller.save(context),
                    child: Text(
                      controller.connected
                          ? l.prototypeSaveAndReconnect
                          : l.prototypeSave,
                    ),
                  ),
                ],
              ),
        body: controller.loading
            ? const Center(child: CircularProgressIndicator())
            : controller.base == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.prototypeTemporarilyUnavailable),
                    TextButton(
                      onPressed: controller.load,
                      child: Text(l.prototypeRetry),
                    ),
                  ],
                ),
              )
            : SettingsPageScroll(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingSection(
                      title: l.prototypeRuntimeStatus,
                      children: [
                        SettingRow(
                          title: l.prototypeXrayCore,
                          leading: const Icon(LucideIcons.activity),
                          value: controller.reader.statusLabel(l),
                        ),
                        SettingRow(
                          title: l.prototypeVersion,
                          value: controller.reader.state.xrayVersion,
                        ),
                        SettingRow(
                          title: l.prototypeUptime,
                          value: controller.reader.state.uptime,
                        ),
                      ],
                    ),
                    SettingSection(
                      title: l.prototypeRoutingData,
                      children: [
                        SettingRow(
                          title: l.prototypeRoutingDataSummary,
                          leading: const Icon(LucideIcons.hardDrive),
                          showChevron: true,
                          onTap: () => widget.onGeodata(context),
                        ),
                      ],
                    ),
                    SettingSection(
                      title: l.prototypeDataUpdates,
                      children: [
                        SettingRow(
                          title: l.prototypeDataUpdateIntervals,
                          leading: const Icon(LucideIcons.refreshCw),
                          showChevron: true,
                          onTap: () => widget.onUpdates(context),
                        ),
                      ],
                    ),
                    SettingSection(
                      title: l.prototypeSpeedTest,
                      children: [
                        SettingRow(
                          title: l.prototypeSpeedTestSummary,
                          subtitle: controller.speedSummary(l),
                          leading: const Icon(LucideIcons.zap),
                          showChevron: true,
                          onTap: () => widget.onSpeedTest(context),
                        ),
                      ],
                    ),
                    SettingSection(
                      title: l.prototypeLogs,
                      description: l.prototypeManagedLogNotice,
                      children: [
                        SwitchListTile(
                          title: Text(l.prototypeRecordXrayLogs),
                          value: controller.logsEnabled,
                          onChanged: disabled
                              ? null
                              : (value) => controller.setLog('enabled', value),
                        ),
                        if (controller.logsEnabled) ...[
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(controller.level),
                              initialValue: controller.level,
                              decoration: InputDecoration(
                                labelText: l.prototypeErrorLogLevel,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'error',
                                  child: Text(l.prototypeErrorsOnly),
                                ),
                                DropdownMenuItem(
                                  value: 'warning',
                                  child: Text(l.prototypeWarning),
                                ),
                                const DropdownMenuItem(
                                  value: 'info',
                                  child: Text('Info'),
                                ),
                                const DropdownMenuItem(
                                  value: 'debug',
                                  child: Text('Debug'),
                                ),
                              ],
                              onChanged: disabled ? null : controller.setLevel,
                            ),
                          ),
                          SwitchListTile(
                            title: Text(l.prototypeRecordDnsQueries),
                            value: controller.recordDns,
                            onChanged: disabled
                                ? null
                                : (value) =>
                                      controller.setLog('recordDns', value),
                          ),
                          SwitchListTile(
                            title: Text(l.prototypeHideLogIpAddresses),
                            value: controller.maskIp,
                            onChanged: disabled
                                ? null
                                : (value) => controller.setLog('maskIp', value),
                          ),
                        ],
                        SettingRow(
                          title: l.prototypeAccessLog,
                          subtitle: l.prototypeAccessLogHint,
                          leading: const Icon(LucideIcons.fileText),
                          showChevron: true,
                          enabled: controller.logPath(true) != null,
                          onTap: () =>
                              controller.openLog(context, true, widget.onLog),
                        ),
                        SettingRow(
                          title: l.prototypeErrorLog,
                          subtitle: l.prototypeErrorLogHint,
                          leading: const Icon(LucideIcons.terminal),
                          showChevron: true,
                          enabled: controller.logPath(false) != null,
                          onTap: () =>
                              controller.openLog(context, false, widget.onLog),
                        ),
                      ],
                    ),
                    SettingSection(
                      title: l.prototypeRuntimeConfiguration,
                      children: [
                        SettingRow(
                          title: l.prototypeRecentXrayConfiguration,
                          subtitle: l.prototypeReadOnlyRuntimeConfiguration,
                          leading: const Icon(LucideIcons.fileJson),
                          showChevron: true,
                          enabled: controller.plan != null,
                          onTap: () =>
                              controller.openConfig(context, widget.onConfig),
                        ),
                      ],
                    ),
                    if (controller.failed)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          l.prototypeTemporarilyUnavailable,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      );
    },
  );
}
