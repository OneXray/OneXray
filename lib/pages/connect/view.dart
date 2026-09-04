import 'package:flutter/material.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/button_progress.dart';
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
    this.pendingChange,
    this.deletingRawIds = const {},
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
  final String? pendingChange;
  final Set<int> deletingRawIds;
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
    final empty =
        !hasServers &&
        !expert &&
        activeRawId == null &&
        !view.canDisconnect &&
        !view.busy;
    if (MediaQuery.sizeOf(context).width > AppLayout.mobileBreakpoint) {
      return _desktop(context, empty: empty);
    }
    if (empty) {
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
                                  busy: pendingChange == 'method',
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [main, const SizedBox(height: 13), traffic],
            );
          },
        ),
      ),
    );
  }

  Widget _desktop(BuildContext context, {required bool empty}) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final viewport = MediaQuery.sizeOf(context);
    final compact = viewport.width <= AppLayout.compactDesktopBreakpoint;
    final connected = view.phase == ConnectionPhase.connected;
    final main = Card(
      key: const ValueKey('desktop-connection-panel'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _status(context, desktop: true),
          _expertSwitch(context, desktop: true),
          if (expert)
            _raws(context, desktop: true)
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 29),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _desktopChoice(
                    context,
                    LucideIcons.earth,
                    l.prototypeConnectionLocation,
                    location,
                    onServer,
                    detail: locationDetail ?? runningPath,
                    meta: connected ? locationHealth : null,
                  ),
                  const SizedBox(height: 25),
                  _desktopChoice(
                    context,
                    LucideIcons.shieldCheck,
                    l.prototypeTrafficMethod,
                    method,
                    onMethod,
                    detail: methodDetail,
                    busy: pendingChange == 'method',
                  ),
                  const SizedBox(height: 25),
                  _why(context, desktop: true),
                ],
              ),
            ),
        ],
      ),
    );
    final traffic = Card(
      key: const ValueKey('desktop-traffic-panel'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 27, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onTraffic,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: palette.border)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        l.prototypeTraffic,
                        style: AppTypography.connectDesktopTrafficTitle,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(
                        LucideIcons.chevronRightDir,
                        size: 17,
                        color: palette.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TrafficReadout(view: view, desktop: true),
          ],
        ),
      ),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.desktopPageTop,
        AppSpacing.page,
        AppSpacing.desktopPageBottom,
      ),
      child: empty
          ? _desktopEmpty(context)
          : compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 660),
                  child: main,
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 560),
                  child: traffic,
                ),
              ],
            )
          : ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    (viewport.height -
                            AppLayout.connectDesktopPanelViewportInset)
                        .clamp(0.0, double.infinity),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 104, child: main),
                    const SizedBox(width: 16),
                    Expanded(flex: 100, child: traffic),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _desktopEmpty(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return Container(
      constraints: BoxConstraints(
        minHeight:
            (MediaQuery.sizeOf(context).height -
                    AppLayout.connectDesktopEmptyViewportInset)
                .clamp(0.0, double.infinity),
      ),
      decoration: ShapeDecoration(
        shape: AppDashedBorder(
          side: BorderSide(color: palette.borderStrong),
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.layers3, size: 34),
          const SizedBox(height: 13),
          Text(
            l.prototypeStartUsingOneXray,
            style: AppTypography.panelTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 13),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              l.prototypeFirstConnectionHint,
              textAlign: TextAlign.center,
              style: AppTypography.connectDesktopEmptyDetail,
            ),
          ),
          const SizedBox(height: 13),
          FilledButton.icon(
            onPressed: onAddServers,
            icon: const Icon(LucideIcons.plus, size: 17),
            label: Text(l.prototypeAddServers),
          ),
          const SizedBox(height: 13),
          TextButton(
            onPressed: () => onExpert(true),
            child: Text(
              l.prototypeUseCompleteRawJson,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopChoice(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    VoidCallback onTap, {
    String? detail,
    String? meta,
    bool busy = false,
  }) {
    final palette = ColorManager.palette(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2),
          child: Text(
            label,
            style: AppTypography.connectDesktopChoiceLabel.copyWith(
              color: palette.mutedStrong,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: palette.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
            side: BorderSide(color: palette.border),
          ),
          child: InkWell(
            onTap: view.busy ? null : onTap,
            borderRadius: BorderRadius.circular(AppRadii.small),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppLayout.connectDesktopChoiceMinHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    if (busy)
                      const ButtonProgressIndicator()
                    else
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.connectDesktopChoiceTitle,
                          ),
                          if (detail != null && detail.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              detail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.connectDesktopChoiceDetail
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
                        style: AppTypography.connectDesktopChoiceMeta.copyWith(
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
    );
  }

  Widget _expertSwitch(BuildContext context, {bool desktop = false}) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return Container(
      constraints: BoxConstraints(
        minHeight: desktop
            ? AppLayout.connectDesktopExpertRowMinHeight
            : AppLayout.connectExpertRowMinHeight,
      ),
      padding: EdgeInsets.symmetric(horizontal: desktop ? 18 : 12),
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
                    style: desktop
                        ? AppTypography.connectDesktopCaption
                        : AppTypography.connectCaption,
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
          if (pendingChange == 'expert') ...[
            const ButtonProgressIndicator(),
            const SizedBox(width: 8),
          ],
          Semantics(
            label: l.prototypeExpertMode,
            child: ShadSwitch(
              value: expert,
              enabled: !view.busy && pendingChange == null,
              onChanged: onExpert,
            ),
          ),
        ],
      ),
    );
  }

  Widget _why(BuildContext context, {bool desktop = false}) {
    final palette = ColorManager.palette(context);
    final action = InkWell(
      onTap: onWhy,
      borderRadius: desktop ? BorderRadius.circular(AppRadii.small) : null,
      child: Container(
        constraints: BoxConstraints(minHeight: desktop ? 53 : 49),
        padding: desktop ? const EdgeInsets.symmetric(horizontal: 14) : null,
        child: Row(
          children: [
            Icon(LucideIcons.circleHelp, size: 20, color: palette.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.prototypeWhyThisConnection,
                style:
                    (desktop
                            ? AppTypography.connectDesktopWhy
                            : AppTypography.connectWhy)
                        .copyWith(color: palette.primary),
              ),
            ),
            Icon(LucideIcons.chevronRightDir, size: 19, color: palette.primary),
          ],
        ),
      ),
    );
    if (!desktop) return action;
    return Material(
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.small),
        side: BorderSide(color: palette.border),
      ),
      child: action,
    );
  }

  Widget _status(BuildContext context, {bool desktop = false}) {
    final l = AppLocalizations.of(context)!;
    final connected = view.phase == ConnectionPhase.connected;
    final canDisconnect = view.canDisconnect;
    final failed = view.failed && !connected;
    final presentationPhase = failed ? ConnectionPhase.failed : view.phase;
    final title = switch (presentationPhase) {
      ConnectionPhase.disconnected => l.prototypeDisconnected,
      ConnectionPhase.preparing ||
      ConnectionPhase.connecting => l.prototypeConnecting,
      ConnectionPhase.connected => l.prototypeConnected,
      ConnectionPhase.disconnecting => l.prototypeDisconnecting,
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
      ConnectionPhase.failed =>
        view.issue == 'permissionRequired'
            ? l.prototypeVpnPermissionRequired
            : view.issue == 'interfaceRequired' ||
                  view.issue == 'interfaceUnavailable'
            ? l.prototypeChooseInterfaceNotice
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
    final button = FilledButton(
      onPressed: view.phase == ConnectionPhase.disconnecting
          ? null
          : onConnection,
      style: desktop
          ? AppTheme.connectionButton(
              context,
              destructive: canDisconnect,
            ).copyWith(
              minimumSize: const WidgetStatePropertyAll(
                Size(
                  AppLayout.connectDesktopButtonWidth,
                  AppLayout.connectDesktopButtonMinHeight,
                ),
              ),
              textStyle: WidgetStatePropertyAll(
                AppTypography.connectDesktopAction,
              ),
            )
          : AppTheme.connectionButton(context, destructive: canDisconnect),
      child: ButtonProgress(
        busy: desktop && view.busy,
        child: Text(
          canDisconnect
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
    );
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: desktop
            ? AppLayout.connectDesktopStatusMinHeight
            : AppLayout.connectStatusMinHeight,
      ),
      child: Padding(
        padding: desktop
            ? const EdgeInsets.fromLTRB(20, 66, 20, 39)
            : const EdgeInsets.fromLTRB(15, 25, 15, 17),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (view.busy)
                  SizedBox.square(
                    dimension: desktop ? 29 : 24,
                    child: MediaQuery.disableAnimationsOf(context)
                        ? Icon(
                            LucideIcons.loaderCircle,
                            color: color,
                            size: desktop ? 29 : 24,
                          )
                        : CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color,
                          ),
                  )
                else if (connected)
                  Container(
                    width: desktop ? 29 : 24,
                    height: desktop ? 29 : 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.check,
                      size: desktop ? 19 : 14,
                      color: palette.primaryForeground,
                    ),
                  )
                else
                  Icon(
                    failed ? LucideIcons.circleAlert : LucideIcons.shield,
                    color: color,
                    size: desktop ? 29 : 24,
                  ),
                SizedBox(width: desktop ? 12 : 10),
                Flexible(
                  child: Text(
                    title,
                    style:
                        (desktop
                                ? AppTypography.connectDesktopStatusTitle
                                : AppTypography.connectStatusTitle)
                            .copyWith(color: color),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            SizedBox(height: desktop ? 16 : 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style:
                  (desktop
                          ? AppTypography.connectDesktopStatusDetail
                          : AppTypography.connectStatusDetail)
                      .copyWith(color: palette.mutedStrong),
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
            SizedBox(height: desktop ? 30 : 18),
            if (desktop)
              Align(
                child: SizedBox(
                  width: AppLayout.connectDesktopButtonWidth,
                  child: button,
                ),
              )
            else
              button,
          ],
        ),
      ),
    );
    if (!desktop) return Card(margin: EdgeInsets.zero, child: content);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: content,
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
    bool busy = false,
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
            onTap: onTap,
            child: Opacity(
              opacity: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppLayout.connectChoiceMinHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 1, bottom: 3),
                  child: Row(
                    children: [
                      if (busy)
                        const ButtonProgressIndicator()
                      else
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

  Widget _raws(BuildContext context, {bool desktop = false}) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return Padding(
      padding: desktop
          ? const EdgeInsets.fromLTRB(18, 0, 18, 14)
          : const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: desktop ? 52 : 47),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Raw JSON',
                    style: desktop
                        ? AppTypography.connectDesktopRawTitle
                        : AppTypography.connectRawTitle,
                  ),
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
                constraints: BoxConstraints(
                  minHeight: desktop
                      ? AppLayout.connectDesktopRawEmptyMinHeight
                      : 160,
                ),
                child: Padding(
                  padding: EdgeInsets.all(desktop ? 24 : 19),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: desktop
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      Icon(
                        LucideIcons.filePlus,
                        size: desktop ? 32 : 27,
                        color: palette.mutedStrong,
                      ),
                      const SizedBox(height: 11),
                      Text(
                        l.prototypeNoRawJson,
                        textAlign: TextAlign.center,
                        style: desktop
                            ? AppTypography.connectDesktopRawEmptyTitle
                            : AppTypography.connectRawEmptyTitle,
                      ),
                      const SizedBox(height: 9),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: desktop ? 330 : 270,
                        ),
                        child: Text(
                          l.prototypeAddRawJsonHint,
                          textAlign: TextAlign.center,
                          style:
                              (desktop
                                      ? AppTypography
                                            .connectDesktopRawEmptyDetail
                                      : AppTypography.connectRawEmptyDetail)
                                  .copyWith(color: palette.mutedForeground),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: onRawAdd,
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
                    _rawRow(context, row, desktop: desktop),
                  ],
                ],
              ),
            ),
          if (raws.isNotEmpty && raws.length < 3)
            Padding(
              padding: const EdgeInsets.only(top: 11),
              child: OutlinedButton.icon(
                onPressed: onRawAdd,
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

  Widget _rawRow(
    BuildContext context,
    CoreConfigData row, {
    bool desktop = false,
  }) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final active = activeRawId == row.id;
    return ColoredBox(
      color: active
          ? Color.lerp(palette.card, palette.selectedSurface, .6)!
          : palette.card,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: desktop ? 66 : 62),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap:
                    view.busy ||
                        pendingChange != null ||
                        deletingRawIds.contains(row.id)
                    ? null
                    : () => onRawSelect(row),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: desktop ? 13 : 11,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      if (pendingChange == 'raw:${row.id}')
                        const ButtonProgressIndicator()
                      else
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
              width: desktop ? 46 : 42,
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
                    onPressed: deletingRawIds.contains(row.id)
                        ? null
                        : () => onRawActions(row),
                    icon: deletingRawIds.contains(row.id)
                        ? const ButtonProgressIndicator()
                        : const Icon(LucideIcons.ellipsis, size: 18),
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
    this.desktop = false,
  });
  final ConnectionView view;
  final bool expandedGroups;
  final bool desktop;
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
        minHeight: desktop
            ? AppLayout.connectDesktopTrafficGroupMinHeight
            : expandedGroups
            ? 130
            : AppLayout.connectTrafficGroupMinHeight,
      ),
      padding: EdgeInsets.symmetric(vertical: desktop ? 22 : 10.5),
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
            style:
                (desktop
                        ? AppTypography.connectDesktopTrafficGroupTitle
                        : AppTypography.connectTrafficGroupTitle)
                    .copyWith(color: palette.mutedStrong),
          ),
          SizedBox(height: desktop ? 24 : 10),
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
      padding: desktop
          ? const EdgeInsetsDirectional.fromSTEB(40, 0, 18, 0)
          : const EdgeInsetsDirectional.fromSTEB(12, 0, 8, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: desktop ? 30 : 24,
              bottom: desktop ? 10 : 5,
            ),
            child: Text(
              label,
              style:
                  (desktop
                          ? AppTypography.connectDesktopTrafficLabel
                          : AppTypography.connectTrafficLabel)
                      .copyWith(
                        color: ColorManager.palette(context).mutedStrong,
                      ),
            ),
          ),
          Row(
            children: [
              Icon(icon, size: desktop ? 24 : 19, color: color),
              SizedBox(width: desktop ? 13 : 7),
              Flexible(
                child: Text(
                  value,
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: desktop
                      ? AppTypography.metric
                      : AppTypography.connectTrafficValue,
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
