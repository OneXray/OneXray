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
    final navigationTheme = NavigationBarTheme.of(context);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar:
          navigationShell
                  .shellRouteContext
                  .match
                  .matches
                  .last
                  .matchedLocation !=
              AppPrimaryRoute.values[navigationShell.currentIndex].rootPath
          ? null
          : Material(
              color: navigationTheme.backgroundColor,
              child: SafeArea(
                top: false,
                child: Container(
                  key: const ValueKey('primary-mobile-navigation'),
                  constraints: BoxConstraints(
                    minHeight:
                        navigationTheme.height ??
                        AppLayout.mobileNavigationHeight,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: ColorManager.palette(context).border,
                      ),
                    ),
                  ),
                  // Let large system text grow the bar; normal size stays 92.
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final primary in AppPrimaryRoute.values)
                          Expanded(
                            child: _bottomDestination(
                              context,
                              primary,
                              appUpdateAvailable,
                              navigationTheme,
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

  Widget _bottomDestination(
    BuildContext context,
    AppPrimaryRoute primary,
    bool appUpdateAvailable,
    NavigationBarThemeData theme,
  ) {
    final selected = primary.index == navigationShell.currentIndex;
    final states = <WidgetState>{if (selected) WidgetState.selected};
    final label = _label(context, primary);
    return Semantics(
      key: ValueKey('primary-navigation-${primary.name}'),
      label: label,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => context.goPrimary(navigationShell, primary),
        hoverColor: theme.overlayColor?.resolve({WidgetState.hovered}),
        highlightColor: theme.overlayColor?.resolve({WidgetState.pressed}),
        focusColor: Theme.of(context).focusColor,
        splashFactory: NoSplash.splashFactory,
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: theme.iconTheme?.resolve(states) ?? IconTheme.of(context),
                child: _navigationIcon(context, primary, appUpdateAvailable),
              ),
              const SizedBox(height: AppSpacing.mobileNavigationGap),
              Text(
                label,
                style: theme.labelTextStyle?.resolve(states),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _railScaffold(
    BuildContext context,
    double width,
    AppUpdateInfo? appUpdateInfo,
  ) {
    final sidebarWidth = width > AppLayout.compactDesktopBreakpoint
        ? AppLayout.desktopSidebarWidth
        : AppLayout.compactSidebarWidth;
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            bottom: false,
            child: SizedBox(
              width: sidebarWidth,
              child: Column(
                children: [
                  Expanded(
                    child: NavigationRail(
                      extended: true,
                      minExtendedWidth: sidebarWidth,
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: (index) => context.goPrimary(
                        navigationShell,
                        AppPrimaryRoute.values[index],
                      ),
                      destinations: AppPrimaryRoute.values
                          .map(
                            (primary) => NavigationRailDestination(
                              icon: Icon(_icon(primary)),
                              selectedIcon: Icon(_icon(primary)),
                              label: Text(_label(context, primary)),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  if (appUpdateInfo != null)
                    _DesktopUpdateReminder(
                      onTap: () => _showDesktopUpdate(context, appUpdateInfo),
                    ),
                ],
              ),
            ),
          ),
          VerticalDivider(
            width: 1,
            color: ColorManager.palette(context).sidebarBorder,
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }

  void _showDesktopUpdate(BuildContext context, AppUpdateInfo updateInfo) {
    context.goPrimary(navigationShell, AppPrimaryRoute.settings);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        context.pushAppUpdateDialog(updateInfo);
      }
    });
  }

  Widget _navigationIcon(
    BuildContext context,
    AppPrimaryRoute primary,
    bool appUpdateAvailable,
  ) {
    final icon = Icon(_icon(primary));
    if (primary != AppPrimaryRoute.settings || !appUpdateAvailable) {
      return icon;
    }
    return _UpdateBadge(child: icon);
  }

  IconData _icon(AppPrimaryRoute primary) {
    return switch (primary) {
      AppPrimaryRoute.home => LucideIcons.link,
      AppPrimaryRoute.subscriptions => LucideIcons.layers3,
      AppPrimaryRoute.core => LucideIcons.terminal,
      AppPrimaryRoute.settings => LucideIcons.settings,
    };
  }

  String _label(BuildContext context, AppPrimaryRoute primary) {
    final localizations = AppLocalizations.of(context)!;
    return switch (primary) {
      AppPrimaryRoute.home => localizations.prototypeConnect,
      AppPrimaryRoute.subscriptions => localizations.prototypeServers,
      AppPrimaryRoute.core => localizations.prototypeAdvanced,
      AppPrimaryRoute.settings => localizations.prototypeSettings,
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
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 12),
      child: Tooltip(
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
                        style: AppTypography.navigationLabel.copyWith(
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

  final AppPrimaryRoute primary;

  @override
  Widget build(BuildContext context) {
    return switch (primary) {
      AppPrimaryRoute.home => const ConnectPage(),
      AppPrimaryRoute.subscriptions => const ServersPage(),
      AppPrimaryRoute.core => const AdvancedRootPage(),
      AppPrimaryRoute.settings => const PreferencesPage(),
    };
  }
}
