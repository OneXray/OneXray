import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/pages/core/tun/app_icon/controller.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Shows the launcher icon of [packageName], falling back to a generic glyph
/// while the icon is loading or when the platform has none.
///
/// Must be built under a [TunAppIconController] provider, which owns the icons
/// of the page this row belongs to.
class AppIconView extends StatefulWidget {
  final String packageName;

  const AppIconView({super.key, required this.packageName});

  @override
  State<AppIconView> createState() => _AppIconViewState();
}

class _AppIconViewState extends State<AppIconView> {
  @override
  void initState() {
    super.initState();
    _requestIcon();
  }

  @override
  void didUpdateWidget(AppIconView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // List rows are recycled, so the same state can be reused for another app.
    if (oldWidget.packageName != widget.packageName) {
      _requestIcon();
    }
  }

  void _requestIcon() {
    context.read<TunAppIconController>().requestIcon(widget.packageName);
  }

  @override
  Widget build(BuildContext context) {
    final icon = context.select<TunAppIconController, ImageProvider?>(
      (controller) => controller.state.icons[widget.packageName],
    );
    if (icon == null) {
      return const Icon(LucideIcons.package);
    }
    // Launcher icons already carry their own shape from the platform icon
    // mask, so they are drawn as-is instead of being clipped again. Sizing is
    // left to the caller's constraints.
    return Image(image: icon, excludeFromSemantics: true);
  }
}
