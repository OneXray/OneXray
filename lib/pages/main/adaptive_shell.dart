import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/page.dart';
import 'package:onexray/pages/main/advanced.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/preferences/page.dart';
import 'package:onexray/pages/servers/page.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/service/app_update/service.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';

class AdaptiveMainShell extends StatelessWidget {
  const AdaptiveMainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<AppEventBus, AppEventBusState, AppUpdateInfo?>(
      selector: (state) => state.appUpdateInfo,
      builder: (context, appUpdateInfo) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > AppLayout.mobileBreakpoint) {
            return _railScaffold(context, constraints.maxWidth, appUpdateInfo);
          }
          return _bottomNavigationScaffold(context, appUpdateInfo != null);
        },
      ),
    );
  }

  Widget _bottomNavigationScaffold(
    BuildContext context,
    bool appUpdateAvailable,
  ) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar:
          navigationShell
                  .shellRouteContext
                  .match
                  .matches
                  .last
                  .matchedLocation !=
              AppPrimaryDestination
                  .values[navigationShell.currentIndex]
                  .rootPath
          ? null
          : DecoratedBox(
              key: const ValueKey('primary-mobile-navigation'),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: ColorManager.palette(context).border),
                ),
              ),
              child: NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: (index) => context.goPrimary(
                  navigationShell,
                  AppPrimaryDestination.values[index],
                ),
                destinations: [
                  for (final primary in AppPrimaryDestination.values)
                    NavigationDestination(
                      key: ValueKey('primary-navigation-${primary.name}'),
                      icon: _navigationIcon(
                        context,
                        primary,
                        appUpdateAvailable,
                      ),
                      label: _label(context, primary),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _railScaffold(
    BuildContext context,
    double width,
    AppUpdateInfo? appUpdateInfo,
  ) {
    final compact = width <= AppLayout.compactDesktopBreakpoint;
    final sidebarWidth = !compact
        ? AppLayout.desktopSidebarWidth
        : AppLayout.compactSidebarWidth;
    final palette = ColorManager.palette(context);
    return Scaffold(
      body: Row(
        children: [
          Container(
            key: const ValueKey('primary-desktop-navigation'),
            width: sidebarWidth,
            decoration: BoxDecoration(
              color: palette.sidebar,
              border: BorderDirectional(
                end: BorderSide(color: palette.sidebarBorder),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sidebarHorizontal,
                  vertical: AppSpacing.sidebarVertical,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        compact
                            ? AppSpacing.sidebarCompactBrandStart
                            : AppSpacing.sidebarBrandStart,
                        AppSpacing.sidebarBrandTop,
                        compact
                            ? AppSpacing.sidebarCompactBrandStart
                            : AppSpacing.sidebarBrandStart,
                        AppSpacing.sidebarBrandBottom,
                      ),
                      child: Text(
                        'OneXray',
                        style: AppTypography.desktopBrand.copyWith(
                          color: palette.brand,
                        ),
                      ),
                    ),
                    for (final primary in AppPrimaryDestination.values) ...[
                      if (primary.index > 0)
                        const SizedBox(height: AppSpacing.sidebarRowGap),
                      _desktopDestination(context, primary),
                    ],
                    const Spacer(),
                    if (appUpdateInfo != null)
                      _DesktopUpdateReminder(
                        onTap: () => _showDesktopUpdate(context, appUpdateInfo),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }

  Widget _desktopDestination(
    BuildContext context,
    AppPrimaryDestination primary,
  ) {
    final palette = ColorManager.palette(context);
    final selected = primary.index == navigationShell.currentIndex;
    final label = _label(context, primary);
    final color = selected ? palette.primary : palette.mutedStrong;
    return Semantics(
      key: ValueKey('primary-navigation-${primary.name}'),
      label: label,
      selected: selected,
      button: true,
      child: Material(
        color: selected ? palette.selectedSurface : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(
            color: selected
                ? Color.lerp(palette.border, palette.primary, .2)!
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          onTap: () => context.goPrimary(navigationShell, primary),
          borderRadius: BorderRadius.circular(AppRadii.card),
          hoverColor: palette.surfaceHover,
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.sidebarRowHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(_icon(primary), size: 22, color: color),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        style:
                            (selected
                                    ? AppTypography.selectedNavigationLabel
                                    : AppTypography.navigationLabel)
                                .copyWith(color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDesktopUpdate(BuildContext context, AppUpdateInfo updateInfo) {
    context.goPrimaryRoot(AppPrimaryDestination.settings);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        context.pushAppUpdateDialog(updateInfo);
      }
    });
  }

  Widget _navigationIcon(
    BuildContext context,
    AppPrimaryDestination primary,
    bool appUpdateAvailable,
  ) {
    final icon = Icon(_icon(primary));
    if (primary != AppPrimaryDestination.settings || !appUpdateAvailable) {
      return icon;
    }
    return _UpdateBadge(child: icon);
  }

  IconData _icon(AppPrimaryDestination primary) {
    return switch (primary) {
      AppPrimaryDestination.connect => LucideIcons.link,
      AppPrimaryDestination.servers => LucideIcons.layers3,
      AppPrimaryDestination.advanced => LucideIcons.terminal,
      AppPrimaryDestination.settings => LucideIcons.settings,
    };
  }

  String _label(BuildContext context, AppPrimaryDestination primary) {
    final localizations = AppLocalizations.of(context)!;
    return switch (primary) {
      AppPrimaryDestination.connect => localizations.prototypeConnect,
      AppPrimaryDestination.servers => localizations.prototypeServers,
      AppPrimaryDestination.advanced => localizations.prototypeAdvanced,
      AppPrimaryDestination.settings => localizations.prototypeSettings,
    };
  }
}

class _DesktopUpdateReminder extends StatelessWidget {
  const _DesktopUpdateReminder({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context)!.appUpdateAvailable;
    final palette = ColorManager.palette(context);
    return Tooltip(
      message: label,
      child: Material(
        color: palette.sidebarAccent,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.controlHorizontal,
              ),
              child: Row(
                children: [
                  const _UpdateBadge(
                    child: Icon(LucideIcons.download, size: 19),
                  ),
                  const SizedBox(width: AppSpacing.actionGap),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.desktopUpdateLabel.copyWith(
                        color: palette.sidebarAccentForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpdateBadge extends StatelessWidget {
  const _UpdateBadge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Badge(
      smallSize: 8,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: child,
    );
  }
}

class PrimaryRootContent extends StatelessWidget {
  const PrimaryRootContent({super.key, required this.primary});

  final AppPrimaryDestination primary;

  @override
  Widget build(BuildContext context) {
    return switch (primary) {
      AppPrimaryDestination.connect => const ConnectPage(),
      AppPrimaryDestination.servers => const ServersPage(),
      AppPrimaryDestination.advanced => const AdvancedRootPage(),
      AppPrimaryDestination.settings => const PreferencesPage(),
    };
  }
}
