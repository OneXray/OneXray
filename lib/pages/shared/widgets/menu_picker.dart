import 'package:flutter/material.dart';

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

enum IconMenuId { share, save, delete }
