import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/main/menu/controller.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';

class MenuMainScaffold extends StatefulWidget {
  const MenuMainScaffold({super.key, required this.child});

  final Widget child;

  @override
  State<MenuMainScaffold> createState() => _MenuMainScaffoldState();
}

class _MenuMainScaffoldState extends State<MenuMainScaffold> {
  final controller = MenuPageController();

  static const _appMenu = PlatformMenu(
    label: 'OneXray',
    menus: <PlatformMenuItem>[
      PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.about),
      PlatformProvidedMenuItem(
        type: PlatformProvidedMenuItemType.servicesSubmenu,
      ),
      PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hide),
      PlatformProvidedMenuItem(
        type: PlatformProvidedMenuItemType.hideOtherApplications,
      ),
      PlatformProvidedMenuItem(
        type: PlatformProvidedMenuItemType.showAllApplications,
      ),
      PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppEventBus, AppEventBusState>(
      builder: (context, state) => _body(context, state),
    );
  }

  Widget _body(BuildContext context, AppEventBusState state) {
    if (state.windowClosed) {
      return _closedWindow(context);
    } else {
      return _focusedWindow(context);
    }
  }

  Widget _focusedWindow(BuildContext context) {
    return Scaffold(
      body: PlatformMenuBar(
        menus: <PlatformMenuItem>[
          _appMenu,
          PlatformMenu(
            label: AppLocalizations.of(context)!.menuBarView,
            menus: <PlatformMenuItem>[
              const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.toggleFullScreen,
              ),
            ],
          ),
          PlatformMenu(
            label: AppLocalizations.of(context)!.menuBarWindow,
            menus: <PlatformMenuItem>[
              const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.minimizeWindow,
              ),
              const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.zoomWindow,
              ),
              const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.arrangeWindowsInFront,
              ),
            ],
          ),
        ],
        child: widget.child,
      ),
    );
  }

  Widget _closedWindow(BuildContext context) {
    return Scaffold(
      body: PlatformMenuBar(
        menus: <PlatformMenuItem>[
          _appMenu,
          PlatformMenu(
            label: AppLocalizations.of(context)!.menuBarWindow,
            menus: <PlatformMenuItem>[
              PlatformMenuItem(
                label: AppLocalizations.of(context)!.menuBarShowWindow,
                onSelected: () => controller.showWindow(),
              ),
            ],
          ),
        ],
        child: widget.child,
      ),
    );
  }
}
