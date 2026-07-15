import 'package:flutter/material.dart';

class AppDialogPage<T> extends Page<T> {
  final WidgetBuilder builder;
  final bool barrierDismissible;
  final Color? barrierColor;
  final String? barrierLabel;
  final bool useSafeArea;

  const AppDialogPage({
    required this.builder,
    this.barrierDismissible = true,
    this.barrierColor,
    this.barrierLabel,
    this.useSafeArea = true,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  @override
  Route<T> createRoute(BuildContext context) {
    final theme = Theme.of(context);
    return DialogRoute<T>(
      context: context,
      settings: this,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor:
          barrierColor ??
          theme.dialogTheme.barrierColor ??
          theme.colorScheme.scrim.withValues(alpha: 0.42),
      barrierLabel:
          barrierLabel ??
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      useSafeArea: useSafeArea,
    );
  }
}
