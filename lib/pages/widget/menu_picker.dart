import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/service/localizations/service.dart';

class AppMenuEntry<T extends Object> {
  final T? value;
  final String title;
  final IconData? icon;
  final List<AppMenuEntry<T>> children;
  final bool destructive;
  final bool separator;

  const AppMenuEntry.item({
    required this.value,
    required this.title,
    this.icon,
    this.destructive = false,
  }) : children = const [],
       separator = false;

  const AppMenuEntry.submenu({
    required this.title,
    required this.children,
    this.icon,
  }) : value = null,
       destructive = false,
       separator = false;

  const AppMenuEntry.separator()
    : value = null,
      title = "",
      icon = null,
      children = const [],
      destructive = false,
      separator = true;

  bool get isSubmenu => children.isNotEmpty;
}

class AppMenuButton<T extends Object> extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final Widget Function(VoidCallback toggleMenu)? triggerBuilder;
  final List<AppMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;

  const AppMenuButton({
    super.key,
    this.icon,
    this.child,
    this.triggerBuilder,
    required this.entries,
    required this.onSelected,
  }) : assert(icon != null || child != null || triggerBuilder != null);

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, menuController, _) {
        void toggleMenu() {
          if (menuController.isOpen) {
            menuController.close();
          } else {
            menuController.open();
          }
        }

        final triggerBuilder = this.triggerBuilder;
        if (triggerBuilder != null) {
          return triggerBuilder(toggleMenu);
        }

        final icon = this.icon;
        if (icon != null) {
          return IconButton(icon: Icon(icon), onPressed: toggleMenu);
        }
        return InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: toggleMenu,
          child: child,
        );
      },
      menuChildren: _menuChildren(context, entries),
    );
  }

  List<Widget> _menuChildren(
    BuildContext context,
    List<AppMenuEntry<T>> entries,
  ) {
    return entries.map((entry) => _menuEntry(context, entry)).toList();
  }

  Widget _menuEntry(BuildContext context, AppMenuEntry<T> entry) {
    if (entry.separator) {
      return const Divider(height: 1);
    }
    final leadingIcon = entry.icon == null ? null : Icon(entry.icon);
    if (entry.isSubmenu) {
      return SubmenuButton(
        leadingIcon: leadingIcon,
        menuChildren: _menuChildren(context, entry.children),
        child: Text(entry.title),
      );
    }
    return MenuItemButton(
      leadingIcon: leadingIcon,
      style: entry.destructive
          ? ButtonStyle(
              foregroundColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.error,
              ),
              iconColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.error,
              ),
            )
          : null,
      onPressed: entry.value == null ? null : () => onSelected(entry.value!),
      child: Text(entry.title),
    );
  }
}

enum IconMenuId {
  edit("edit"),
  share("share"),
  save("save"),
  copy("copy"),
  delete("delete"),
  clean("clean"),
  refresh("refresh"),
  manualInput("manualInput"),
  subscribeLink("subscribeLink"),
  scanQRCode("scanQRCode"),
  pickImage("pickImage"),
  pickFile("pickFile"),
  readPasteboard("readPasteboard");

  const IconMenuId(this.name);

  final String name;

  @override
  String toString() => name;

  String get title {
    switch (this) {
      case IconMenuId.edit:
        return appLocalizationsNoContext().menuEdit;
      case IconMenuId.share:
        return appLocalizationsNoContext().menuShare;
      case IconMenuId.save:
        return appLocalizationsNoContext().menuSave;
      case IconMenuId.copy:
        return appLocalizationsNoContext().menuCopy;
      case IconMenuId.delete:
        return appLocalizationsNoContext().menuDelete;
      case IconMenuId.clean:
        return appLocalizationsNoContext().menuClean;
      case IconMenuId.refresh:
        return appLocalizationsNoContext().menuRefresh;
      case IconMenuId.manualInput:
        return appLocalizationsNoContext().menuManualInput;
      case IconMenuId.subscribeLink:
        return appLocalizationsNoContext().menuSubscribeLink;
      case IconMenuId.scanQRCode:
        return appLocalizationsNoContext().menuScanQRCode;
      case IconMenuId.pickImage:
        return appLocalizationsNoContext().menuPickImage;
      case IconMenuId.pickFile:
        return appLocalizationsNoContext().menuPickFile;
      case IconMenuId.readPasteboard:
        return appLocalizationsNoContext().menuReadPasteboard;
    }
  }

  IconData get icon {
    switch (this) {
      case IconMenuId.edit:
        return LucideIcons.pencil;
      case IconMenuId.share:
        return LucideIcons.share2;
      case IconMenuId.save:
        return LucideIcons.save;
      case IconMenuId.copy:
        return LucideIcons.copy;
      case IconMenuId.delete:
        return LucideIcons.trash2;
      case IconMenuId.clean:
        return LucideIcons.listX;
      case IconMenuId.refresh:
        return LucideIcons.refreshCw;
      case IconMenuId.manualInput:
        return LucideIcons.folderInput;
      case IconMenuId.subscribeLink:
        return LucideIcons.link;
      case IconMenuId.scanQRCode:
        return LucideIcons.scanLine;
      case IconMenuId.pickImage:
        return LucideIcons.image;
      case IconMenuId.pickFile:
        return LucideIcons.fileJson;
      case IconMenuId.readPasteboard:
        return LucideIcons.clipboardPaste;
    }
  }
}

extension IconMenuEntry on IconMenuId {
  AppMenuEntry<IconMenuId> get menuEntry {
    return AppMenuEntry<IconMenuId>.item(
      value: this,
      title: title,
      icon: icon,
      destructive: this == IconMenuId.delete,
    );
  }
}

List<AppMenuEntry<IconMenuId>> iconMenuEntries(List<IconMenuId> menus) {
  return menus.map((menu) => menu.menuEntry).toList();
}
