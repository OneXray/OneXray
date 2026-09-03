import 'package:flutter/material.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
    this.locationDetail,
    this.locationHealth,
    required this.method,
    this.methodDetail,
    required this.onConnection,
    required this.onAddServers,
    required this.onExpert,
    required this.onServer,
    required this.onMethod,
    required this.onWhy,
    required this.onTraffic,
    required this.onRawAdd,
    required this.onRawSelect,
    required this.onRawActions,
  });
  final ConnectionView view;
  final bool hasServers;
  final bool expert;
  final List<CoreConfigData> raws;
  final int? activeRawId;
  final String location;
  final String? runningPath;
  final String? locationDetail, locationHealth, methodDetail;
  final String method;
  final VoidCallback onConnection,
      onAddServers,
      onServer,
      onMethod,
      onWhy,
      onTraffic,
      onRawAdd;
  final ValueChanged<bool> onExpert;
  final ValueChanged<CoreConfigData> onRawSelect, onRawActions;

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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.connectPageHorizontal,
        AppSpacing.connectPageTop,
        AppSpacing.connectPageHorizontal,
        AppSpacing.connectPageBottom,
      ),
      child: ResponsiveContent(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final main = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _status(context),
                const SizedBox(height: 14),
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(1),
                    child: Column(
                      children: [
                        _expertSwitch(context),
                        if (expert)
                          _raws(context)
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Column(
                              children: [
                                _choice(
                                  context,
                                  LucideIcons.earth,
                                  l.prototypeConnectionLocation,
                                  location,
                                  onServer,
                                  detail: locationDetail ?? runningPath,
                                  meta: connected ? locationHealth : null,
                                ),
                                _choice(
                                  context,
                                  LucideIcons.shieldCheck,
                                  l.prototypeTrafficMethod,
                                  method,
                                  onMethod,
                                  detail: methodDetail,
                                  minHeight: 113,
                                ),
                                _why(context),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
            final traffic = Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 15, 13, 1),
                child: Column(
                  children: [
                    InkWell(
                      onTap: onTraffic,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 29),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                l.prototypeTraffic,
                                style: AppTypography.connectTrafficTitle,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Icon(
                                LucideIcons.chevronRightDir,
                                size: 17,
                                color: ColorManager.palette(context)
                                    .mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    TrafficReadout(view: view),
                  ],
                ),
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
              children: [main, const SizedBox(height: 13), traffic],
            );
          },
        ),
      ),
    );
  }

  Widget _expertSwitch(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return Container(
      constraints: const BoxConstraints(
        minHeight: AppLayout.connectExpertRowMinHeight,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    l.prototypeExpertMode,
                    style: AppTypography.connectCaption,
                  ),
                ),
                const SizedBox(width: 7),
                ExcludeSemantics(
                  child: Icon(
                    LucideIcons.info,
                    size: 15,
                    color: palette.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Semantics(
            label: l.prototypeExpertMode,
            child: ShadSwitch(
              value: expert,
              enabled: !view.busy,
              onChanged: onExpert,
            ),
          ),
        ],
      ),
    );
  }

  Widget _why(BuildContext context) {
    final palette = ColorManager.palette(context);
    return InkWell(
      onTap: onWhy,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 49),
        child: Row(
          children: [
            Icon(LucideIcons.circleHelp, size: 20, color: palette.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.prototypeWhyThisConnection,
                style: AppTypography.connectWhy.copyWith(
                  color: palette.primary,
                ),
              ),
            ),
            Icon(LucideIcons.chevronRightDir, size: 19, color: palette.primary),
          ],
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
    final palette = ColorManager.palette(context);
    final color = failed
        ? palette.destructive
        : connected
        ? palette.running
        : view.busy
        ? palette.primary
        : palette.mutedStrong;
    return Card(
      margin: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppLayout.connectStatusMinHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 25, 15, 17),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (view.busy)
                    SizedBox.square(
                      dimension: 24,
                      child: MediaQuery.disableAnimationsOf(context)
                          ? Icon(
                              LucideIcons.loaderCircle,
                              color: color,
                              size: 24,
                            )
                          : CircularProgressIndicator(
                              strokeWidth: 2,
                              color: color,
                            ),
                    )
                  else if (connected)
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.check,
                        size: 14,
                        color: palette.primaryForeground,
                      ),
                    )
                  else
                    Icon(
                      failed ? LucideIcons.circleAlert : LucideIcons.shield,
                      color: color,
                      size: 24,
                    ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      title,
                      style: AppTypography.connectStatusTitle.copyWith(
                        color: color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: AppTypography.connectStatusDetail.copyWith(
                  color: palette.mutedStrong,
                ),
              ),
              if (view.issue == 'selectionReset')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      l.prototypeNameActive(l.prototypeAutomaticSelection),
                      textAlign: TextAlign.center,
                      style: AppTypography.metadata,
                    ),
                  ),
                ),
              if (view.failed && !failed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l.prototypeCheckNetwork,
                    style: AppTypography.supporting.copyWith(
                      color: palette.destructive,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: view.phase == ConnectionPhase.disconnecting
                    ? null
                    : onConnection,
                style: AppTheme.connectionButton(
                  context,
                  destructive: connected,
                ),
                child: Text(
                  connected
                      ? l.prototypeDisconnect
                      : view.phase == ConnectionPhase.disconnecting
                      ? l.prototypePleaseWait
                      : view.busy
                      ? l.prototypeCancel
                      : failed
                      ? l.prototypeTryAgain
                      : l.prototypeConnect,
                ),
              ),
            ],
          ),
        ),
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
    String? meta,
    double minHeight = 0,
  }) {
    final palette = ColorManager.palette(context);
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.only(top: 13, bottom: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: AppTypography.connectChoiceLabel.copyWith(
              color: palette.mutedStrong,
            ),
          ),
          const SizedBox(height: 7),
          InkWell(
            onTap: view.busy ? null : onTap,
            child: Opacity(
              opacity: view.busy ? .52 : 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppLayout.connectChoiceMinHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 1, bottom: 3),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 23,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? palette.foreground
                            : palette.scannerBackground,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              value,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.connectChoiceTitle,
                            ),
                            if (detail != null && detail.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                detail,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.connectChoiceDetail
                                    .copyWith(color: palette.mutedForeground),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 13),
                      if (meta != null) ...[
                        Text(
                          meta,
                          style: AppTypography.connectChoiceMeta.copyWith(
                            color: palette.running,
                          ),
                        ),
                        const SizedBox(width: 13),
                      ],
                      const Icon(LucideIcons.chevronRightDir, size: 19),
                      if (meta == null) const SizedBox(width: 13),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _raws(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 47),
            child: Row(
              children: [
                Expanded(
                  child: Text('Raw JSON', style: AppTypography.connectRawTitle),
                ),
                Text(
                  '${raws.length} / 3',
                  textDirection: TextDirection.ltr,
                  style: AppTypography.connectRawCount.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (view.phase == ConnectionPhase.connected && activeRawId == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                l.prototypeOrdinaryConnectionRunning,
                style: AppTypography.supporting.copyWith(
                  color: palette.mutedForeground,
                ),
              ),
            ),
          if (raws.isEmpty)
            Card(
              margin: EdgeInsets.zero,
              shape: AppDashedBorder(
                side: BorderSide(color: palette.borderStrong),
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 160),
                child: Padding(
                  padding: const EdgeInsets.all(19),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.filePlus,
                        size: 27,
                        color: palette.mutedStrong,
                      ),
                      const SizedBox(height: 11),
                      Text(
                        l.prototypeNoRawJson,
                        textAlign: TextAlign.center,
                        style: AppTypography.connectRawEmptyTitle,
                      ),
                      const SizedBox(height: 9),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 270),
                        child: Text(
                          l.prototypeAddRawJsonHint,
                          textAlign: TextAlign.center,
                          style: AppTypography.connectRawEmptyDetail.copyWith(
                            color: palette.mutedForeground,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: view.busy ? null : onRawAdd,
                        icon: const Icon(LucideIcons.plus, size: 17),
                        label: Text(l.prototypeAddRawJson),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (raws.isNotEmpty)
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final row in raws) ...[
                    if (row != raws.first) const Divider(),
                    _rawRow(context, row),
                  ],
                ],
              ),
            ),
          if (raws.isNotEmpty && raws.length < 3)
            Padding(
              padding: const EdgeInsets.only(top: 11),
              child: OutlinedButton.icon(
                onPressed: view.busy ? null : onRawAdd,
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.primary,
                  shape: AppDashedBorder(
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                ),
                icon: const Icon(LucideIcons.plus, size: 17),
                label: Text(l.prototypeAddRawJson),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.info, size: 16, color: palette.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.prototypeRawRuntimeOverrideNotice,
                  style: AppTypography.connectRawNotice.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rawRow(BuildContext context, CoreConfigData row) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final active = activeRawId == row.id;
    return ColoredBox(
      color: active
          ? Color.lerp(palette.card, palette.selectedSurface, .6)!
          : palette.card,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 62),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: view.busy ? null : () => onRawSelect(row),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.fileJson,
                        size: 21,
                        color: palette.primary,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.connectRawRowTitle,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              active
                                  ? l.prototypeActiveConfiguration
                                  : l.prototypeCompleteXrayConfiguration,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.connectRawRowDetail.copyWith(
                                color: palette.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 11),
                      Icon(
                        active ? LucideIcons.check : LucideIcons.circle,
                        size: active ? 19 : 18,
                        color: active
                            ? palette.primary
                            : palette.mutedForeground,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 42,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    border: BorderDirectional(
                      start: BorderSide(color: palette.border),
                    ),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: '${l.prototypeMoreActions}: ${row.name}',
                    onPressed: () => onRawActions(row),
                    icon: const Icon(LucideIcons.ellipsis, size: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrafficReadout extends StatelessWidget {
  const TrafficReadout({
    super.key,
    required this.view,
    this.expandedGroups = false,
  });
  final ConnectionView view;
  final bool expandedGroups;
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
          live
              ? '${formatTraffic(view.downloadSpeed, connection: true)}/s'
              : '—',
          live ? '${formatTraffic(view.uploadSpeed, connection: true)}/s' : '—',
        ),
        _group(
          context,
          view.phase == ConnectionPhase.connected
              ? l.prototypeThisConnection
              : l.prototypeLastConnection,
          formatTraffic(traffic?.downlink ?? 0, connection: true),
          formatTraffic(traffic?.uplink ?? 0, connection: true),
        ),
        _group(
          context,
          l.prototypeTotalTraffic,
          formatTraffic(traffic?.totalDownlink ?? 0, connection: true),
          formatTraffic(traffic?.totalUplink ?? 0, connection: true),
          divider: false,
        ),
      ],
    );
  }

  Widget _group(
    BuildContext context,
    String title,
    String download,
    String upload, {
    bool divider = true,
  }) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return Container(
      constraints: BoxConstraints(
        minHeight: expandedGroups
            ? 130
            : AppLayout.connectTrafficGroupMinHeight,
      ),
      padding: const EdgeInsets.symmetric(vertical: 10.5),
      decoration: BoxDecoration(
        border: divider
            ? Border(bottom: BorderSide(color: palette.border))
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppTypography.connectTrafficGroupTitle.copyWith(
              color: palette.mutedStrong,
            ),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _metric(
                    context,
                    LucideIcons.arrowDown,
                    l.prototypeDownload,
                    download,
                    palette.primary,
                  ),
                ),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: BorderDirectional(
                        start: BorderSide(color: palette.border),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 1),
                      child: _metric(
                        context,
                        LucideIcons.arrowUp,
                        l.prototypeUpload,
                        upload,
                        palette.running,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
    Color color,
  ) => Semantics(
    label: '$label $value',
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 8, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 24, bottom: 5),
            child: Text(
              label,
              style: AppTypography.connectTrafficLabel.copyWith(
                color: ColorManager.palette(context).mutedStrong,
              ),
            ),
          ),
          Row(
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  value,
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.connectTrafficValue,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

String formatTraffic(int bytes, {bool connection = false}) {
  // Keep the App's 1024-byte conversion. The connection UI uses the approved
  // prototype labels and precision; other consumers retain IEC units.
  final units = connection
      ? const ['B', 'KB', 'MB', 'GB', 'TB']
      : const ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  var number = value.toStringAsFixed(
    unit == 0
        ? 0
        : connection
        ? 2
        : 1,
  );
  if (connection && number.contains('.')) {
    number = number.replaceFirst(RegExp(r'\.?0+$'), '');
  }
  return '$number ${units[unit]}';
}
