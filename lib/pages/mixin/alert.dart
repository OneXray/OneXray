import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ContextAlert {
  static Future<void> showPermissionDialog(BuildContext context) async {
    final openSettings = await _showDialog<bool>(
      context: context,
      variant: ShadDialogVariant.alert,
      builder: (ctx) => ShadDialog.alert(
        title: _dialogTitle(
          ctx,
          icon: LucideIcons.shieldAlert,
          title: AppLocalizations.of(ctx)!.permissionDialogTitle,
        ),
        description: _dialogDescription(
          ctx,
          AppLocalizations.of(ctx)!.homePageOpenSettings,
        ),
        backgroundColor: _dialogBackground(ctx),
        closeIcon: const SizedBox.shrink(),
        constraints: _dialogConstraints(ctx),
        padding: const EdgeInsets.all(20),
        gap: 20,
        removeBorderRadiusWhenTiny: false,
        titleTextAlign: TextAlign.start,
        descriptionTextAlign: TextAlign.start,
        scrollable: false,
        useSafeArea: false,
        actions: [
          ShadButton.outline(
            child: Text(AppLocalizations.of(ctx)!.buttonCancel),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ShadButton(
            child: Text(AppLocalizations.of(ctx)!.buttonOpenSettings),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (openSettings == true) {
      await openAppSettings();
    }
  }

  static Future<void> showPingResultDialog(
    BuildContext context,
    int delay,
  ) async {
    final content = PingService().parsePingResponse(delay);
    await showOKDialog(
      context,
      AppLocalizations.of(context)!.outboundPageRealPingResult,
      content,
    );
  }

  static Future<void> showOKDialog(
    BuildContext context,
    String title,
    String content,
  ) async {
    await _showDialog<void>(
      context: context,
      builder: (ctx) => ShadDialog(
        title: _dialogTitle(ctx, icon: LucideIcons.info, title: title),
        description: _dialogDescription(ctx, content),
        backgroundColor: _dialogBackground(ctx),
        closeIcon: const SizedBox.shrink(),
        constraints: _dialogConstraints(ctx),
        padding: const EdgeInsets.all(20),
        gap: 20,
        removeBorderRadiusWhenTiny: false,
        titleTextAlign: TextAlign.start,
        descriptionTextAlign: TextAlign.start,
        scrollable: false,
        useSafeArea: false,
        actions: [
          ShadButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(ctx)!.buttonOK),
          ),
        ],
      ),
    );
  }

  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    String? confirmLabel,
  }) async {
    final confirmed = await _showDialog<bool>(
      context: context,
      variant: ShadDialogVariant.alert,
      builder: (ctx) => ShadDialog.alert(
        title: _dialogTitle(ctx, icon: LucideIcons.triangleAlert, title: title),
        description: _dialogDescription(ctx, content),
        backgroundColor: _dialogBackground(ctx),
        closeIcon: const SizedBox.shrink(),
        constraints: _dialogConstraints(ctx),
        padding: const EdgeInsets.all(20),
        gap: 20,
        removeBorderRadiusWhenTiny: false,
        titleTextAlign: TextAlign.start,
        descriptionTextAlign: TextAlign.start,
        scrollable: false,
        useSafeArea: false,
        actions: [
          ShadButton.outline(
            child: Text(AppLocalizations.of(ctx)!.buttonCancel),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ShadButton(
            child: Text(confirmLabel ?? AppLocalizations.of(ctx)!.buttonOK),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  static void showToast(BuildContext context, String message) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 600;
    final availableWidth = math.max(0.0, size.width - 32);
    final maxWidth = compact ? availableWidth : math.min(420.0, availableWidth);
    final minWidth = compact ? maxWidth : math.min(320.0, maxWidth);
    final colors = ShadTheme.of(context).colorScheme;
    ShadToaster.of(context).show(
      ShadToast(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.info, size: 18, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        alignment: compact ? Alignment.bottomCenter : Alignment.bottomRight,
        backgroundColor: colors.popover,
        constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 36, 14),
        crossAxisAlignment: CrossAxisAlignment.start,
        showCloseIconOnlyWhenHovered: false,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static Future<T?> _showDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    ShadDialogVariant variant = ShadDialogVariant.primary,
  }) {
    return showShadDialog<T>(
      context: context,
      builder: builder,
      variant: variant,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      opaque: false,
    );
  }

  static BoxConstraints _dialogConstraints(BuildContext context) {
    final availableWidth = math.max(0.0, MediaQuery.sizeOf(context).width - 32);
    final maxWidth = math.min(440.0, availableWidth);
    return BoxConstraints(
      minWidth: math.min(320.0, maxWidth),
      maxWidth: maxWidth,
    );
  }

  static Color _dialogBackground(BuildContext context) {
    return ShadTheme.of(context).colorScheme.popover;
  }

  static Widget _dialogDescription(BuildContext context, String content) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.48,
      ),
      child: SingleChildScrollView(
        child: SelectionArea(child: Text(content, textAlign: TextAlign.start)),
      ),
    );
  }

  static Widget _dialogTitle(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) {
    final colors = ShadTheme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.accent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: colors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title, textAlign: TextAlign.start)),
      ],
    );
  }
}
