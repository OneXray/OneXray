import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/component/nodes/controller.dart';
import 'package:onexray/pages/home/component/nodes/view.dart';
import 'package:onexray/pages/home/main/actions.dart';
import 'package:onexray/pages/home/main/controller.dart';
import 'package:onexray/pages/home/main/state.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/core_routing_mode/state.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeController(context),
      child: BlocBuilder<HomeController, HomePageState>(
        builder: (context, homeState) {
          final controller = context.read<HomeController>();
          return BlocBuilder<AppEventBus, AppEventBusState>(
            builder: (context, eventState) {
              final connection = controller.buildConnectionViewState(
                context,
                homeState,
                eventState,
              );
              return Scaffold(
                appBar: AppBar(
                  title: Text(AppLocalizations.of(context)!.homePageTitle),
                  actions: [
                    Tooltip(
                      message: homeState.nodeSearchVisible
                          ? AppLocalizations.of(context)!.homePageCloseSearch
                          : AppLocalizations.of(context)!.homePageSearchNodes,
                      child: ShadIconButton.ghost(
                        icon: Icon(
                          homeState.nodeSearchVisible
                              ? LucideIcons.x
                              : LucideIcons.search,
                        ),
                        onPressed: controller.toggleNodeSearch,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (eventState.downloading)
                      const IconButton(
                        onPressed: null,
                        icon: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      HomeAddMenuButton(onSelected: controller.addMenuAction),
                  ],
                ),
                body: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      _HomeConnectionFrame(
                        connection: connection,
                        xrayProfileName: homeState.xrayProfileName,
                        routingMode: eventState.coreRoutingMode,
                        pendingRoutingMode: homeState.pendingRoutingMode,
                        onToggleConnection: controller.startVpn,
                        onShowNodeInfo: controller.gotoNodeInfo,
                        onShowXrayProfile: controller.gotoXrayProfile,
                        onRoutingModeChanged: controller.switchRoutingMode,
                      ),
                      Expanded(
                        child: HomeNodePanel(
                          showSearch: homeState.nodeSearchVisible,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HomeConnectionFrame extends StatelessWidget {
  const _HomeConnectionFrame({
    required this.connection,
    required this.xrayProfileName,
    required this.routingMode,
    required this.pendingRoutingMode,
    required this.onToggleConnection,
    required this.onShowNodeInfo,
    required this.onShowXrayProfile,
    required this.onRoutingModeChanged,
  });

  final HomeConnectionViewPageState connection;
  final String xrayProfileName;
  final CoreRoutingMode routingMode;
  final CoreRoutingMode? pendingRoutingMode;
  final VoidCallback onToggleConnection;
  final VoidCallback onShowNodeInfo;
  final VoidCallback onShowXrayProfile;
  final ValueChanged<CoreRoutingMode> onRoutingModeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 8),
      child: Align(
        alignment: AlignmentDirectional.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: HomeConnectionSummary(
            connection: connection,
            xrayProfileName: xrayProfileName,
            routingMode: routingMode,
            pendingRoutingMode: pendingRoutingMode,
            onToggleConnection: onToggleConnection,
            onShowNodeInfo: onShowNodeInfo,
            onShowXrayProfile: onShowXrayProfile,
            onRoutingModeChanged: onRoutingModeChanged,
          ),
        ),
      ),
    );
  }
}

class HomeAddMenuButton extends StatelessWidget {
  const HomeAddMenuButton({super.key, required this.onSelected});

  final ValueChanged<HomeAddMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return AppMenuButton<HomeAddMenuAction>(
      triggerBuilder: (toggleMenu) => Tooltip(
        message: localizations.homePageAddNode,
        child: ShadIconButton(
          icon: const Icon(LucideIcons.plus),
          onPressed: toggleMenu,
        ),
      ),
      entries: [
        AppMenuEntry<HomeAddMenuAction>.submenu(
          title: IconMenuId.manualInput.title,
          icon: LucideIcons.folderInput,
          children: [
            AppMenuEntry<HomeAddMenuAction>.item(
              value: HomeAddMenuAction.manualOutbound,
              title: localizations.homeManualInputOutbound,
              icon: LucideIcons.server,
            ),
            AppMenuEntry<HomeAddMenuAction>.item(
              value: HomeAddMenuAction.manualFull,
              title: localizations.homeManualInputFullConfig,
              icon: LucideIcons.slidersHorizontal,
            ),
            AppMenuEntry<HomeAddMenuAction>.item(
              value: HomeAddMenuAction.manualRaw,
              title: localizations.homeManualInputRawJson,
              icon: LucideIcons.braces,
            ),
          ],
        ),
        _menuItem(IconMenuId.subscribeLink, HomeAddMenuAction.subscribeLink),
        if (AppPlatform.isMobile)
          _menuItem(IconMenuId.scanQRCode, HomeAddMenuAction.scanQRCode),
        _menuItem(IconMenuId.pickImage, HomeAddMenuAction.pickImage),
        _menuItem(IconMenuId.pickFile, HomeAddMenuAction.pickFile),
        _menuItem(IconMenuId.readPasteboard, HomeAddMenuAction.readPasteboard),
      ],
      onSelected: onSelected,
    );
  }

  AppMenuEntry<HomeAddMenuAction> _menuItem(
    IconMenuId menu,
    HomeAddMenuAction action,
  ) {
    return AppMenuEntry<HomeAddMenuAction>.item(
      value: action,
      title: menu.title,
      icon: menu.icon,
    );
  }
}

class HomeNodePanel extends StatelessWidget {
  const HomeNodePanel({super.key, required this.showSearch});

  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    final selectedId = context.select<HomeController, int>(
      (controller) => controller.state.configId,
    );
    return HomeNodeView(
      queryType: HomeNodeQueryType.homeNodes,
      showSearch: showSearch,
      selectedId: selectedId,
      onSelect: (config) =>
          context.read<HomeController>().updateConfigId(config.id),
    );
  }
}

class HomeConnectionSummary extends StatelessWidget {
  const HomeConnectionSummary({
    super.key,
    required this.connection,
    required this.xrayProfileName,
    required this.routingMode,
    required this.pendingRoutingMode,
    required this.onToggleConnection,
    required this.onShowNodeInfo,
    required this.onShowXrayProfile,
    required this.onRoutingModeChanged,
  });

  final HomeConnectionViewPageState connection;
  final String xrayProfileName;
  final CoreRoutingMode routingMode;
  final CoreRoutingMode? pendingRoutingMode;
  final VoidCallback onToggleConnection;
  final VoidCallback onShowNodeInfo;
  final VoidCallback onShowXrayProfile;
  final ValueChanged<CoreRoutingMode> onRoutingModeChanged;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      padding: EdgeInsets.zero,
      radius: BorderRadius.circular(8),
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 820) {
            return _wideLayout(context);
          }
          if (constraints.maxWidth >= 560) {
            return _mediumLayout(context);
          }
          return _compactLayout(context);
        },
      ),
    );
  }

  Widget _wideLayout(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 112),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 14, 14),
        child: Row(
          children: [
            Expanded(child: _nodeEntry(context, endPadding: 18)),
            SizedBox(
              width: 190,
              child: _profileEntry(context, borderStart: true),
            ),
            SizedBox(
              width: 300,
              child: _routingAndTraffic(context, borderStart: true),
            ),
            SizedBox(
              width: 58,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: _powerButton(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediumLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Row(
              children: [
                Expanded(child: _nodeEntry(context, endPadding: 14)),
                SizedBox(
                  width: 180,
                  child: _profileEntry(context, borderStart: true),
                ),
                SizedBox(
                  width: 56,
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: _powerButton(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsetsDirectional.only(top: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: ColorManager.border(context)),
              ),
            ),
            child: Row(
              children: [
                SizedBox(width: 300, child: _routingControl()),
                const SizedBox(width: 18),
                Expanded(child: _traffic(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactLayout(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 0),
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 58),
                child: Row(
                  children: [
                    Expanded(child: _nodeEntry(context, endPadding: 10)),
                    _powerButton(context),
                  ],
                ),
              ),
              _profileEntry(context, borderTop: true, inline: true),
            ],
          ),
        ),
        Divider(height: 1, color: ColorManager.border(context)),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 10, 8),
          child: _routingControl(),
        ),
      ],
    );
  }

  Widget _nodeEntry(BuildContext context, {required double endPadding}) {
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onShowNodeInfo,
        child: Padding(
          padding: EdgeInsetsDirectional.only(end: endPadding),
          child: Row(
            children: [
              _connectionIcon(context),
              const SizedBox(width: 12),
              Expanded(child: _connectionCopy(context)),
              const SizedBox(width: 4),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: ColorManager.secondaryText(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _connectionIcon(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        connection.statusIcon,
        size: 21,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _connectionCopy(BuildContext context) {
    final palette = ColorManager.palette(context);
    final indicatorColor = switch (connection.tone) {
      HomeConnectionTone.connected => palette.running,
      HomeConnectionTone.connecting ||
      HomeConnectionTone.waitingForApproval => palette.restarting,
      HomeConnectionTone.failed => Theme.of(context).colorScheme.error,
      HomeConnectionTone.disconnected => ColorManager.secondaryText(context),
    };
    final statusColor = switch (connection.tone) {
      HomeConnectionTone.connected => palette.runningText,
      HomeConnectionTone.connecting ||
      HomeConnectionTone.waitingForApproval => palette.restartingText,
      HomeConnectionTone.failed => Theme.of(context).colorScheme.error,
      HomeConnectionTone.disconnected => ColorManager.secondaryText(context),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: indicatorColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                connection.statusText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.supporting.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 7),
            ShadBadge.secondary(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              child: Text(connection.runModeText, style: AppTypography.badge),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          connection.nodeName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.listSectionTitle.copyWith(
            color: ColorManager.primaryText(context),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          connection.locationText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.supporting.copyWith(
            color: ColorManager.secondaryText(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        if (connection.summaryDetailText case final detail?) ...[
          const SizedBox(height: 4),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.supporting.copyWith(
              color: ColorManager.secondaryText(context),
            ),
          ),
        ],
      ],
    );
  }

  Widget _profileEntry(
    BuildContext context, {
    bool borderStart = false,
    bool borderTop = false,
    bool inline = false,
  }) {
    final localizations = AppLocalizations.of(context)!;
    final border = borderStart
        ? BorderDirectional(
            start: BorderSide(color: ColorManager.border(context)),
          )
        : borderTop
        ? Border(top: BorderSide(color: ColorManager.border(context)))
        : null;
    final content = inline
        ? Row(
            children: [
              Icon(
                LucideIcons.settings2,
                size: 14,
                color: ColorManager.secondaryText(context),
              ),
              const SizedBox(width: 8),
              Text(
                localizations.homeOutboundViewXrayProfile,
                style: AppTypography.badge.copyWith(
                  color: ColorManager.secondaryText(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  xrayProfileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.navigationLabel.copyWith(
                    color: ColorManager.primaryText(context),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                LucideIcons.chevronRight,
                size: 14,
                color: ColorManager.secondaryText(context),
              ),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.settings2,
                    size: 13,
                    color: ColorManager.secondaryText(context),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      localizations.homeOutboundViewXrayProfile,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.badge.copyWith(
                        color: ColorManager.secondaryText(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      xrayProfileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.rowTitle.copyWith(
                        color: ColorManager.primaryText(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 14,
                    color: ColorManager.secondaryText(context),
                  ),
                ],
              ),
            ],
          );
    return Container(
      decoration: BoxDecoration(border: border),
      child: Semantics(
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onShowXrayProfile,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: inline ? 40 : 60),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                borderStart ? 16 : 0,
                borderTop ? 7 : 0,
                12,
                borderTop ? 7 : 0,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _routingAndTraffic(BuildContext context, {required bool borderStart}) {
    return Container(
      padding: EdgeInsetsDirectional.only(start: borderStart ? 16 : 0),
      decoration: BoxDecoration(
        border: borderStart
            ? BorderDirectional(
                start: BorderSide(color: ColorManager.border(context)),
              )
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _routingControl(),
          const SizedBox(height: 6),
          _traffic(context),
        ],
      ),
    );
  }

  Widget _routingControl() {
    return RoutingModeControl(
      value: routingMode,
      pendingValue: pendingRoutingMode,
      disabled: connection.loading,
      expanded: true,
      onChanged: onRoutingModeChanged,
    );
  }

  Widget _traffic(BuildContext context) {
    return Row(
      children: [
        Text(
          AppLocalizations.of(context)!.nodeInfoPageTraffic,
          style: AppTypography.badge.copyWith(
            color: ColorManager.secondaryText(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _trafficValue(
            context,
            LucideIcons.arrowDown,
            connection.downloadText,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _trafficValue(
            context,
            LucideIcons.arrowUp,
            connection.uploadText,
          ),
        ),
      ],
    );
  }

  Widget _trafficValue(BuildContext context, IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 13, color: ColorManager.secondaryText(context)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.numeric.copyWith(
              color: ColorManager.secondaryText(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _powerButton(BuildContext context) {
    final destructive = connection.destructiveAction;
    final palette = ColorManager.palette(context);
    final connected = connection.tone == HomeConnectionTone.connected;
    final backgroundColor = connected ? palette.runningBadge : palette.primary;
    final foregroundColor = connected
        ? palette.runningBadgeForeground
        : palette.primaryForeground;
    final darkMode = Theme.of(context).brightness == Brightness.dark;
    final destructiveBackgroundAlpha = darkMode ? 0.2 : 0.1;
    final destructiveHoverAlpha = darkMode ? 0.3 : 0.2;
    final button = ShadIconButton.raw(
      variant: ShadButtonVariant.primary,
      icon: connection.loading
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foregroundColor,
              ),
            )
          : const Icon(LucideIcons.power),
      iconSize: 18,
      width: 40,
      height: 40,
      backgroundColor: backgroundColor,
      hoverBackgroundColor: destructive
          ? palette.destructive.withValues(alpha: destructiveHoverAlpha)
          : connected
          ? palette.primary
          : null,
      pressedBackgroundColor: destructive
          ? palette.destructive.withValues(alpha: destructiveBackgroundAlpha)
          : connected
          ? palette.primary
          : null,
      foregroundColor: foregroundColor,
      hoverForegroundColor: destructive
          ? palette.destructive
          : connected
          ? palette.primaryForeground
          : null,
      pressedForegroundColor: destructive
          ? palette.destructive
          : connected
          ? palette.primaryForeground
          : null,
      decoration: const ShadDecoration(
        shape: BoxShape.circle,
        border: ShadBorder.none,
        focusedBorder: ShadBorder.none,
        secondaryBorder: ShadBorder.none,
        secondaryFocusedBorder: ShadBorder.none,
      ),
      onPressed: connection.loading ? null : onToggleConnection,
    );
    return Tooltip(message: connection.actionLabel, child: button);
  }
}

class RoutingModeControl extends StatelessWidget {
  const RoutingModeControl({
    super.key,
    required this.value,
    required this.pendingValue,
    required this.disabled,
    required this.onChanged,
    this.expanded = false,
  });

  final CoreRoutingMode value;
  final CoreRoutingMode? pendingValue;
  final bool disabled;
  final bool expanded;
  final ValueChanged<CoreRoutingMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final displayValue = pendingValue ?? value;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsetsDirectional.fromSTEB(9, 5, 5, 5),
      decoration: BoxDecoration(
        color: ColorManager.tagBackground(context).withValues(alpha: 0.55),
        border: Border.all(color: ColorManager.border(context)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.of(context)!.coreRoutingModeTitle,
            style: AppTypography.badge.copyWith(
              color: ColorManager.secondaryText(context),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: ColorManager.surface(context),
                border: Border.all(color: ColorManager.border(context)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
                children: CoreRoutingMode.values
                    .map(
                      (mode) => expanded
                          ? Expanded(
                              child: _modeButton(context, mode, displayValue),
                            )
                          : _modeButton(context, mode, displayValue),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeButton(
    BuildContext context,
    CoreRoutingMode mode,
    CoreRoutingMode displayValue,
  ) {
    final selected = displayValue == mode;
    final foreground = selected
        ? Theme.of(context).colorScheme.onPrimary
        : disabled
        ? ColorManager.secondaryText(context).withValues(alpha: 0.55)
        : ColorManager.primaryText(context);
    final button = Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: disabled || mode == value ? null : () => onChanged(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 40,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (pendingValue == mode) ...[
                SizedBox.square(
                  dimension: 11,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: foreground,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  mode.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.navigationLabel.copyWith(
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return expanded ? button : SizedBox(width: 62, child: button);
  }
}
