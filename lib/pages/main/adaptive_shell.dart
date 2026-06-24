import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/home/page.dart';
import 'package:onexray/pages/core/main/page.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/settings/main/page.dart';
import 'package:onexray/pages/subscriptions/list/page.dart';
import 'package:onexray/pages/theme/color.dart';

class AdaptiveMainShell extends StatelessWidget {
  const AdaptiveMainShell({super.key, required this.navigationShell});

  static const double railBreakpoint = 700;
  static const double _extendedRailBreakpoint = 1180;

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= railBreakpoint) {
          return _railScaffold(context, constraints.maxWidth);
        }
        return _bottomNavigationScaffold(context);
      },
    );
  }

  Widget _bottomNavigationScaffold(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) =>
            context.goPrimary(navigationShell, AppPrimaryRoute.values[index]),
        destinations: AppPrimaryRoute.values
            .map(
              (primary) => NavigationDestination(
                icon: Icon(_icon(primary, selected: false)),
                selectedIcon: Icon(_icon(primary, selected: true)),
                label: _label(context, primary),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _railScaffold(BuildContext context, double width) {
    final extended = width >= _extendedRailBreakpoint;
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            bottom: false,
            child: NavigationRail(
              extended: extended,
              minExtendedWidth: 220,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => context.goPrimary(
                navigationShell,
                AppPrimaryRoute.values[index],
              ),
              destinations: AppPrimaryRoute.values
                  .map(
                    (primary) => NavigationRailDestination(
                      icon: Icon(_icon(primary, selected: false)),
                      selectedIcon: Icon(_icon(primary, selected: true)),
                      label: Text(_label(context, primary)),
                    ),
                  )
                  .toList(),
            ),
          ),
          VerticalDivider(width: 1, color: ColorManager.border(context)),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }

  IconData _icon(AppPrimaryRoute primary, {required bool selected}) {
    return switch (primary) {
      AppPrimaryRoute.home => selected ? Icons.home : Icons.home_outlined,
      AppPrimaryRoute.subscriptions =>
        selected ? Icons.dynamic_feed : Icons.dynamic_feed_outlined,
      AppPrimaryRoute.core => selected ? Icons.tune : Icons.tune_outlined,
      AppPrimaryRoute.settings =>
        selected ? Icons.settings : Icons.settings_outlined,
    };
  }

  String _label(BuildContext context, AppPrimaryRoute primary) {
    final localizations = AppLocalizations.of(context)!;
    return switch (primary) {
      AppPrimaryRoute.home => localizations.homePageTitle,
      AppPrimaryRoute.subscriptions => localizations.subscriptionListPageTitle,
      AppPrimaryRoute.core => localizations.mainNavigationCore,
      AppPrimaryRoute.settings => localizations.settingPageTitle,
    };
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
      AppPrimaryRoute.settings => const SettingPage(),
    };
  }
}
