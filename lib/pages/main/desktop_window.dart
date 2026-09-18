import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/service/shared/menu/window/service.dart';
import 'package:window_manager/window_manager.dart';

/// Window chrome outside the Router, so dialogs, Setup and compact layouts
/// cannot cover window controls. Page AppBars and navigation stay unchanged.
class DesktopWindowFrame extends StatefulWidget {
  const DesktopWindowFrame({super.key, required this.child});

  final Widget child;

  static bool hasNativeSidebar(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.macOS &&
      WindowService().hasSidebarMaterial;

  @override
  State<DesktopWindowFrame> createState() => _DesktopWindowFrameState();
}

class _DesktopWindowFrameState extends State<DesktopWindowFrame> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Theme.of(context).platform == TargetPlatform.macOS) {
      unawaited(WindowService().updateAppearance(Theme.of(context).brightness));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.platform != TargetPlatform.macOS &&
        theme.platform != TargetPlatform.windows &&
        theme.platform != TargetPlatform.linux) {
      return widget.child;
    }
    final palette = ColorManager.palette(context);
    final macOS = theme.platform == TargetPlatform.macOS;
    final nativeSidebar = DesktopWindowFrame.hasNativeSidebar(context);
    return Column(
      children: [
        SizedBox(
          key: const ValueKey('desktop-window-caption'),
          height: macOS
              ? WindowService().titlebarHeight ?? AppLayout.macOSTitlebarHeight
              : kWindowCaptionHeight,
          width: double.infinity,
          child: macOS
              ? DragToMoveArea(
                  child: ColoredBox(
                    color: nativeSidebar ? Colors.transparent : palette.header,
                  ),
                )
              : Directionality(
                  // OS caption buttons stay on the right in RTL languages.
                  textDirection: TextDirection.ltr,
                  // window_manager still uses Flutter's legacy Material theme.
                  // ignore: deprecated_member_use
                  child: MaterialUiCompatibilityBridge(
                    child: WindowCaption(
                      backgroundColor: palette.header,
                      brightness: theme.brightness,
                      title: Text(
                        'OneXray',
                        style: AppTypography.supporting.copyWith(
                          color: palette.foreground,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => MediaQuery(
              // Viewport-based page and dialog sizing excludes window chrome.
              data: MediaQuery.of(context).copyWith(size: constraints.biggest),
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}
