import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:onexray/service/localizations/service.dart';

typedef TextSelectCallback<T extends Object> = Function(T selected);

class TextMenuPicker<T extends Object> extends StatelessWidget {
  final String title;
  final List<T> selections;
  final TextSelectCallback<T> callback;

  TextMenuPicker({
    super.key,
    required this.title,
    required this.selections,
    required this.callback,
  });

  final _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    final children = selections
        .map(
          (selection) => MenuItemButton(
            child: Text("$selection"),
            onPressed: () => callback(selection),
          ),
        )
        .toList();
    return MenuAnchor(
      menuChildren: children,
      controller: _controller,
      builder: (_, _, _) =>
          TextButton(onPressed: () => _onTap(), child: Text(title)),
      child: Text(title),
    );
  }

  void _onTap() {
    if (_controller.isOpen) {
      _controller.close();
    } else {
      _controller.open();
    }
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

  static IconMenuId? fromString(String name) =>
      IconMenuId.values.firstWhereOrNull((value) => value.name == name);

  static List<String> get names {
    return IconMenuId.values.map((e) => e.name).toList();
  }

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

typedef IconMenuCallback = Function(String id);

class IconMenuPicker extends StatelessWidget {
  final IconData icon;
  final List<IconMenuId> menus;
  final IconMenuCallback callback;

  IconMenuPicker({
    super.key,
    required this.icon,
    required this.menus,
    required this.callback,
  });

  final _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    final children = menus
        .map(
          (menu) => MenuItemButton(
            leadingIcon: Icon(menu.icon),
            child: Text(menu.title),
            onPressed: () => callback(menu.name),
          ),
        )
        .toList();
    return MenuAnchor(
      menuChildren: children,
      controller: _controller,
      builder: (_, _, _) =>
          IconButton(onPressed: () => _onTap(), icon: Icon(icon)),
      child: Icon(icon),
    );
  }

  void _onTap() {
    if (_controller.isOpen) {
      _controller.close();
    } else {
      _controller.open();
    }
  }
}
