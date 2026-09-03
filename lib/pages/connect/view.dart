import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/service/connection/coordinator.dart';

class ConnectView extends StatelessWidget {
  const ConnectView({
    super.key,
    required this.view,
    required this.hasServers,
    required this.expert,
    required this.raws,
    required this.activeRawId,
    required this.location,
    this.runningPath,
    required this.method,
    required this.onConnection,
    required this.onAddServers,
    required this.onExpert,
    required this.onServer,
    required this.onMethod,
    required this.onWhy,
    required this.onTraffic,
    required this.onRawAdd,
    required this.onRawSelect,
    required this.onRawEdit,
    required this.onRawDelete,
  });
  final ConnectionView view;
  final bool hasServers;
  final bool expert;
  final List<CoreConfigData> raws;
  final int? activeRawId;
  final String location;
  final String? runningPath;
  final String method;
  final VoidCallback onConnection,
      onAddServers,
      onServer,
      onMethod,
      onWhy,
      onTraffic,
      onRawAdd;
  final ValueChanged<bool> onExpert;
  final ValueChanged<CoreConfigData> onRawSelect, onRawEdit, onRawDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final connected = view.phase == ConnectionPhase.connected;
    if (!hasServers &&
        !expert &&
        activeRawId == null &&
        !connected &&
        !view.busy) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.layers3, size: 40),
              const SizedBox(height: 20),
              Text(
                l.prototypeStartUsingOneXray,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(l.prototypeFirstConnectionHint, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAddServers,
                icon: const Icon(LucideIcons.plus),
                label: Text(l.prototypeAddServers),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => onExpert(true),
                child: Text(
                  l.prototypeUseCompleteRawJson,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ResponsiveContent(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final main = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _status(context),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          title: Text(l.prototypeExpertMode),
                          value: expert,
                          onChanged: view.busy ? null : onExpert,
                        ),
                        const Divider(),
                        if (expert)
                          _raws(context)
                        else ...[
                          _choice(
                            context,
                            LucideIcons.globe,
                            l.prototypeConnectionLocation,
                            location,
                            onServer,
                            detail: runningPath,
                          ),
                          _choice(
                            context,
                            LucideIcons.shieldCheck,
                            l.prototypeTrafficMethod,
                            method,
                            onMethod,
                          ),
                          ListTile(
                            leading: const Icon(LucideIcons.circleHelp),
                            title: Text(l.prototypeWhyThisConnection),
                            trailing: const Icon(LucideIcons.chevronRightDir),
                            onTap: onWhy,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
            final traffic = Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      l.prototypeTraffic,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    trailing: const Icon(LucideIcons.chevronRightDir),
                    onTap: onTraffic,
                  ),
                  TrafficReadout(view: view),
                ],
              ),
            );
            if (constraints.maxWidth >= 780) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: main),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: traffic),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [main, const SizedBox(height: 16), traffic],
            );
          },
        ),
      ),
    );
  }

  Widget _status(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final connected = view.phase == ConnectionPhase.connected;
    final failed = view.failed && !connected;
    final presentationPhase = failed ? ConnectionPhase.failed : view.phase;
    final title = switch (presentationPhase) {
      ConnectionPhase.disconnected => l.prototypeDisconnected,
      ConnectionPhase.preparing ||
      ConnectionPhase.connecting => l.prototypeConnecting,
      ConnectionPhase.connected => l.prototypeConnected,
      ConnectionPhase.disconnecting => l.prototypeDisconnecting,
      ConnectionPhase.recovering => l.prototypeReconnecting,
      ConnectionPhase.failed => l.prototypeConnectionFailed,
    };
    final startedAt = view.traffic?.startedAtMs;
    final elapsed = startedAt == null
        ? 0
        : DateTime.now()
              .difference(DateTime.fromMillisecondsSinceEpoch(startedAt))
              .inMinutes;
    final detail = switch (presentationPhase) {
      ConnectionPhase.disconnected => l.prototypeReadyToProtectConnection,
      ConnectionPhase.preparing ||
      ConnectionPhase.connecting => l.prototypePreparingSecureConnection,
      ConnectionPhase.connected =>
        elapsed < 1
            ? l.prototypeJustConnected
            : elapsed < 60
            ? l.prototypeProtectedMinutes(elapsed)
            : l.prototypeProtectedHoursMinutes(elapsed ~/ 60, elapsed % 60),
      ConnectionPhase.disconnecting => l.prototypeFinishingConnection,
      ConnectionPhase.recovering => l.prototypeApplyingConnectionSettings,
      ConnectionPhase.failed =>
        view.permission != null
            ? l.prototypeVpnPermissionRequired
            : l.prototypeCheckNetwork,
    };
    final color = failed
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                connected
                    ? LucideIcons.shieldCheck
                    : failed
                    ? LucideIcons.circleAlert
                    : LucideIcons.shield,
                color: color,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(detail, style: Theme.of(context).textTheme.bodyMedium),
          if (view.issue == 'selectionReset')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l.prototypeNameActive(l.prototypeAutomaticSelection),
                ),
              ),
            ),
          if (view.failed && !failed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l.prototypeCheckNetwork,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: view.phase == ConnectionPhase.disconnecting
                ? null
                : onConnection,
            style: connected
                ? FilledButton.styleFrom(
                    backgroundColor: ColorManager.palette(context)
                        .destructiveSolid,
                    foregroundColor: ColorManager.palette(context)
                        .destructiveForeground,
                  )
                : null,
            icon: Icon(
              connected
                  ? LucideIcons.power
                  : view.busy
                  ? LucideIcons.x
                  : LucideIcons.power,
            ),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                connected
                    ? l.prototypeDisconnect
                    : view.busy
                    ? l.prototypeCancel
                    : failed
                    ? l.prototypeTryAgain
                    : l.prototypeConnect,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _choice(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    VoidCallback onTap, {
    String? detail,
  }) => ListTile(
    enabled: !view.busy,
    leading: Icon(icon),
    title: Text(label, style: Theme.of(context).textTheme.bodySmall),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        if (detail != null)
          Text(detail, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
    trailing: const Icon(LucideIcons.chevronRightDir),
    onTap: onTap,
  );

  Widget _raws(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Raw JSON',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text('${raws.length} / 3', textDirection: TextDirection.ltr),
            ],
          ),
          if (view.phase == ConnectionPhase.connected && activeRawId == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(l.prototypeOrdinaryConnectionRunning),
            ),
          if (raws.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const Icon(LucideIcons.fileJson, size: 32),
                  const SizedBox(height: 12),
                  Text(l.prototypeNoRawJson, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(l.prototypeAddRawJsonHint, textAlign: TextAlign.center),
                ],
              ),
            ),
          for (final row in raws)
            ListTile(
              contentPadding: EdgeInsets.zero,
              selected: activeRawId == row.id,
              leading: Icon(
                activeRawId == row.id
                    ? LucideIcons.circleCheck
                    : LucideIcons.circle,
              ),
              title: Text(row.name),
              subtitle: Text(
                activeRawId == row.id
                    ? l.prototypeActiveConfiguration
                    : l.prototypeCompleteXrayConfiguration,
              ),
              onTap: view.busy ? null : () => onRawSelect(row),
              trailing: PopupMenuButton<String>(
                tooltip: l.prototypeMoreActions,
                icon: const Icon(LucideIcons.ellipsis),
                onSelected: (action) =>
                    action == 'edit' ? onRawEdit(row) : onRawDelete(row),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    enabled: !view.busy,
                    child: Text(l.prototypeEditRawJson),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    enabled: !view.busy,
                    child: Text(l.prototypeDelete),
                  ),
                ],
              ),
            ),
          if (raws.length < 3)
            OutlinedButton.icon(
              onPressed: view.busy ? null : onRawAdd,
              icon: const Icon(LucideIcons.plus),
              label: Text(l.prototypeAddRawJson),
            ),
          const SizedBox(height: 16),
          Text(
            l.prototypeRawRuntimeOverrideNotice,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class TrafficReadout extends StatelessWidget {
  const TrafficReadout({super.key, required this.view});
  final ConnectionView view;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final live =
        view.phase == ConnectionPhase.connected && view.metricsAvailable;
    final traffic = view.traffic;
    return Column(
      children: [
        _group(
          context,
          l.prototypeCurrentSpeed,
          live ? '${formatTraffic(view.downloadSpeed)}/s' : '—',
          live ? '${formatTraffic(view.uploadSpeed)}/s' : '—',
        ),
        const Divider(height: 1),
        _group(
          context,
          view.phase == ConnectionPhase.connected
              ? l.prototypeThisConnection
              : l.prototypeLastConnection,
          formatTraffic(traffic?.downlink ?? 0),
          formatTraffic(traffic?.uplink ?? 0),
        ),
        const Divider(height: 1),
        _group(
          context,
          l.prototypeTotalTraffic,
          formatTraffic(traffic?.totalDownlink ?? 0),
          formatTraffic(traffic?.totalUplink ?? 0),
        ),
      ],
    );
  }

  Widget _group(
    BuildContext context,
    String title,
    String download,
    String upload,
  ) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _metric(
                context,
                LucideIcons.arrowDown,
                l.prototypeDownload,
                download,
              ),
              _metric(context, LucideIcons.arrowUp, l.prototypeUpload, upload),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) => Semantics(
    label: '$label $value',
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textDirection: TextDirection.ltr,
          style: AppTypography.numeric,
        ),
      ],
    ),
  );
}

String formatTraffic(int bytes) {
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}
