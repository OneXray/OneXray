import 'package:macos_window_utils/widgets/macos_toolbar_passthrough.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/pages/main/desktop_window.dart';

/// Keeps the themed AppBar while forwarding clicks on controls that overlap
/// the native macOS titlebar. Empty titlebar space keeps native window gestures.
class PageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PageAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.bottom,
  });

  final Widget title;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  // Retain AppBar's theme-aware preferred size, including its optional tabs.
  @override
  Size get preferredSize => AppBar(bottom: bottom).preferredSize;

  @override
  Widget build(BuildContext context) {
    final insets = MacOSWindowInsets.maybeOf(context);
    final route = ModalRoute.of(context);
    final forwardClicks =
        insets != null &&
        insets.titlebarHeight > 0 &&
        MediaQuery.paddingOf(context).top == 0 &&
        TickerMode.valuesOf(context).enabled &&
        (route?.isCurrent ?? true);
    var effectiveLeading = leading;
    if (forwardClicks && effectiveLeading == null) {
      if (Scaffold.maybeOf(context)?.hasDrawer ?? false) {
        effectiveLeading = const DrawerButton();
      } else if (route?.impliesAppBarDismissal ?? false) {
        effectiveLeading = route!.fullscreenDialog
            ? const CloseButton()
            : const BackButton();
      }
    }
    return AppBar(
      title: title,
      leading: forwardClicks && effectiveLeading != null
          ? MacosToolbarPassthrough(child: effectiveLeading)
          : effectiveLeading,
      actions: forwardClicks
          ? actions
                ?.map((child) => MacosToolbarPassthrough(child: child))
                .toList()
          : actions,
      bottom: bottom,
    );
  }
}
