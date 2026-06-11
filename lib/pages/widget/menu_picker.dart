import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/service/localizations/service.dart';

typedef TextSelectCallback<T extends Object> = Function(T selected);

class TextMenuPicker<T extends Object> extends StatelessWidget {
  final String title;
  final List<T> selections;
  final TextSelectCallback<T> callback;

  const TextMenuPicker({
    super.key,
    required this.title,
    required this.selections,
    required this.callback,
  });

  @override
  Widget build(BuildContext context) {
    final displayTitle = title.isEmpty ? "-" : title;
    return PopupMenuButton<T>(
      onSelected: callback,
      itemBuilder: (context) => selections
          .map(
            (selection) =>
                PopupMenuItem<T>(value: selection, child: Text("$selection")),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 8,
          vertical: 8,
        ),
        child: Text(
          displayTitle,
          style: TextStyle(
            color: ColorManager.interactiveText(context),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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

  const IconMenuPicker({
    super.key,
    required this.icon,
    required this.menus,
    required this.callback,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = ColorManager.secondaryText(context);
    final textColor = ColorManager.primaryText(context);
    return PopupMenuButton<IconMenuId>(
      icon: Icon(icon),
      onSelected: (menu) => callback(menu.name),
      itemBuilder: (context) => menus
          .map(
            (menu) => PopupMenuItem<IconMenuId>(
              value: menu,
              child: Row(
                children: [
                  Icon(menu.icon, color: iconColor),
                  const SizedBox(width: 12),
                  Text(menu.title, style: TextStyle(color: textColor)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
