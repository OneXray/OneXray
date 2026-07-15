import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/main/page.dart';
import 'package:onexray/pages/core/main/page.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/settings/main/page.dart';
import 'package:onexray/pages/subscriptions/list/page.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/service/app_update/service.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';

class AdaptiveMainShell extends StatelessWidget {
  const AdaptiveMainShell({super.key, required this.navigationShell});

  static const double railBreakpoint = 700;
  static const double _extendedRailBreakpoint = 900;

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<AppEventBus, AppEventBusState, AppUpdateInfo?>(
      selector: (state) => state.appUpdateInfo,
      builder: (context, appUpdateInfo) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= railBreakpoint) {
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) =>
            context.goPrimary(navigationShell, AppPrimaryRoute.values[index]),
        destinations: AppPrimaryRoute.values
            .map(
              (primary) => NavigationDestination(
                icon: _navigationIcon(context, primary, appUpdateAvailable),
                selectedIcon: _navigationIcon(
                  context,
                  primary,
                  appUpdateAvailable,
                ),
                label: _label(context, primary),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _railScaffold(
    BuildContext context,
    double width,
    AppUpdateInfo? appUpdateInfo,
  ) {
    final extended = width >= _extendedRailBreakpoint;
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            bottom: false,
            child: SizedBox(
              width: extended ? 220 : 72,
              child: Column(
                children: [
                  Expanded(
                    child: NavigationRail(
                      extended: extended,
                      minWidth: 72,
                      minExtendedWidth: 220,
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
                      extended: extended,
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
      AppPrimaryRoute.home => LucideIcons.house,
      AppPrimaryRoute.subscriptions => LucideIcons.layers3,
      AppPrimaryRoute.core => LucideIcons.slidersHorizontal,
      AppPrimaryRoute.settings => LucideIcons.settings,
    };
  }

  String _label(BuildContext context, AppPrimaryRoute primary) {
    final localizations = AppLocalizations.of(context)!;
    return switch (primary) {
      AppPrimaryRoute.home => localizations.homePageTitle,
      AppPrimaryRoute.subscriptions => localizations.subscriptionListPageTitle,
      AppPrimaryRoute.core => localizations.mainNavigationCore,
      AppPrimaryRoute.settings => localizations.settingsPageTitle,
    };
  }
}

class _DesktopUpdateReminder extends StatelessWidget {
  const _DesktopUpdateReminder({required this.extended, required this.onTap});

  final bool extended;
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
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: extended
                  ? Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 12,
                      ),
                      child: Row(
                        children: [
                          const _UpdateBadge(
                            child: Icon(LucideIcons.download, size: 19),
                          ),
                          const SizedBox(width: 10),
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
                    )
                  : const Center(
                      child: _UpdateBadge(
                        child: Icon(LucideIcons.download, size: 19),
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
      AppPrimaryRoute.home => const HomePage(),
      AppPrimaryRoute.subscriptions => const SubscriptionListPage(),
      AppPrimaryRoute.core => const CorePage(),
      AppPrimaryRoute.settings => const SettingsPage(),
    };
  }
}
