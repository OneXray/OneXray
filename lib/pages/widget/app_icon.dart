import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onexray/service/app_icon/service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Shows the launcher icon of [packageName], falling back to a generic glyph
/// while the icon is loading or when the platform has none.
class AppIconView extends StatefulWidget {
  final String packageName;

  /// Overrides the shared icon cache so widget tests can stay off the bridge.
  @visibleForTesting
  final AppIconService? service;

  const AppIconView({super.key, required this.packageName, this.service});

  @override
  State<AppIconView> createState() => _AppIconViewState();
}

class _AppIconViewState extends State<AppIconView> {
  late final AppIconService _service = widget.service ?? AppIconService();
  Uint8List? _icon;

  @override
  void initState() {
    super.initState();
    _resolveIcon();
  }

  @override
  void didUpdateWidget(AppIconView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // List rows are recycled, so the same state can be reused for another app.
    if (oldWidget.packageName != widget.packageName) {
      _resolveIcon();
    }
  }

  void _resolveIcon() {
    final packageName = widget.packageName;
    if (_service.isResolved(packageName)) {
      _icon = _service.resolved(packageName);
      return;
    }
    _icon = null;
    unawaited(_loadIcon(packageName));
  }

  Future<void> _loadIcon(String packageName) async {
    final icon = await _service.load(packageName);
    if (!mounted || widget.packageName != packageName) {
      return;
    }
    setState(() => _icon = icon);
  }

  @override
  Widget build(BuildContext context) {
    final icon = _icon;
    if (icon == null) {
      return const Icon(LucideIcons.package);
    }
    // Launcher icons already carry their own shape from the platform icon
    // mask, so they are drawn as-is instead of being clipped again. Sizing is
    // left to the caller's constraints.
    return Image.memory(icon, excludeFromSemantics: true);
  }
}
