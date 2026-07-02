import 'package:flutter/material.dart';
import 'package:onexray/service/localizations/service.dart';

class AppMenuEntry<T extends Object> {
  final T? value;
  final String title;
  final IconData? icon;
  final List<AppMenuEntry<T>> children;

  const AppMenuEntry.item({required this.value, required this.title, this.icon})
    : children = const [];

  const AppMenuEntry.submenu({
    required this.title,
    required this.children,
    this.icon,
  }) : value = null;

  bool get isSubmenu => children.isNotEmpty;
}

class AppMenuButton<T extends Object> extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final List<AppMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;

  const AppMenuButton({
    super.key,
    this.icon,
    this.child,
    required this.entries,
    required this.onSelected,
  }) : assert(icon != null || child != null);

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
      menuChildren: _menuChildren(entries),
    );
  }

  List<Widget> _menuChildren(List<AppMenuEntry<T>> entries) {
    return entries.map(_menuEntry).toList();
  }

  Widget _menuEntry(AppMenuEntry<T> entry) {
    final leadingIcon = entry.icon == null ? null : Icon(entry.icon);
    if (entry.isSubmenu) {
      return SubmenuButton(
        leadingIcon: leadingIcon,
        menuChildren: _menuChildren(entry.children),
        child: Text(entry.title),
      );
    }
    return MenuItemButton(
      leadingIcon: leadingIcon,
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
        return Icons.edit;
      case IconMenuId.share:
        return Icons.share;
      case IconMenuId.save:
        return Icons.save;
      case IconMenuId.copy:
        return Icons.copy;
      case IconMenuId.delete:
        return Icons.delete;
      case IconMenuId.clean:
        return Icons.clear;
      case IconMenuId.refresh:
        return Icons.refresh;
      case IconMenuId.manualInput:
        return Icons.edit;
      case IconMenuId.subscribeLink:
        return Icons.link;
      case IconMenuId.scanQRCode:
        return Icons.qr_code_scanner;
      case IconMenuId.pickImage:
        return Icons.image;
      case IconMenuId.pickFile:
        return Icons.file_open;
      case IconMenuId.readPasteboard:
        return Icons.paste;
    }
  }
}

extension IconMenuEntry on IconMenuId {
  AppMenuEntry<IconMenuId> get menuEntry {
    return AppMenuEntry<IconMenuId>.item(value: this, title: title, icon: icon);
  }
}

List<AppMenuEntry<IconMenuId>> iconMenuEntries(List<IconMenuId> menus) {
  return menus.map((menu) => menu.menuEntry).toList();
}
