import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SettingsPageScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final VoidCallback? onSave;
  final bool saveLoading;
  final String? saveLabel;
  final List<Widget> actions;

  const SettingsPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.onSave,
    this.saveLoading = false,
    this.saveLabel,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...actions,
          if (onSave != null || saveLoading) _saveButton(context),
        ],
      ),
      body: SafeArea(child: body),
    );
  }

  Widget _saveButton(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final icon = saveLoading
        ? const SizedBox.square(
            dimension: 15,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(LucideIcons.save);
    if (compact || saveLabel == null) {
      final button = ShadIconButton(
        icon: icon,
        onPressed: saveLoading ? null : onSave,
      );
      final label = saveLabel;
      return label == null ? button : Tooltip(message: label, child: button);
    }
    return ShadButton(
      leading: icon,
      onPressed: saveLoading ? null : onSave,
      child: Text(saveLabel!),
    );
  }
}

class SettingsPageScroll extends StatelessWidget {
  final Widget child;
  final double desktopMaxWidth;
  final EdgeInsetsGeometry padding;
  final AlignmentGeometry alignment;

  const SettingsPageScroll({
    super.key,
    required this.child,
    this.desktopMaxWidth = AppLayout.standardMaxWidth,
    this.padding = const EdgeInsetsDirectional.only(bottom: 24),
    this.alignment = AlignmentDirectional.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      child: ResponsiveContent(
        desktopMaxWidth: desktopMaxWidth,
        alignment: alignment,
        child: child,
      ),
    );
  }
}

class SettingsChoiceIndicator extends StatelessWidget {
  final bool selected;

  const SettingsChoiceIndicator({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? primary : Colors.transparent,
        border: Border.all(
          color: selected ? primary : ColorManager.border(context),
        ),
        shape: BoxShape.circle,
      ),
      child: selected
          ? Icon(
              LucideIcons.check,
              size: 13,
              color: Theme.of(context).colorScheme.onPrimary,
            )
          : null,
    );
  }
}

class SettingsChoiceRow extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? leading;
  final bool selected;
  final VoidCallback? onTap;

  const SettingsChoiceRow({
    super.key,
    required this.title,
    this.description,
    this.leading,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SettingRow(
      title: title,
      subtitle: description,
      leading: leading,
      onTap: onTap,
      trailing: SettingsChoiceIndicator(selected: selected),
    );
  }
}

class AppConfirmationDialog extends StatelessWidget {
  final String title;
  final String? subject;
  final String content;
  final String cancelLabel;
  final String confirmLabel;
  final bool destructive;
  final bool expandConfirm;
  final bool barrierDismissible;

  const AppConfirmationDialog({
    super.key,
    required this.title,
    this.subject,
    required this.content,
    required this.cancelLabel,
    required this.confirmLabel,
    this.destructive = false,
    this.expandConfirm = false,
    this.barrierDismissible = true,
  });

  Future<bool> show(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: barrierDismissible,
        useSafeArea: false,
        barrierColor: AppPalette.restoreOverlay,
        builder: (_) => this,
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    final size = MediaQuery.sizeOf(context);
    final mobile = size.width <= AppLayout.mobileBreakpoint;
    final buttonStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(
          0,
          mobile ? AppLayout.mobileButtonMinHeight : AppLayout.buttonMinHeight,
        ),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.buttonHorizontal),
      ),
      textStyle: WidgetStatePropertyAll(AppTypography.control),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.control)),
        ),
      ),
    );
    final confirm = FilledButton(
      onPressed: () => Navigator.pop(context, true),
      style: destructive
          ? buttonStyle.merge(AppTheme.destructiveButton(context))
          : buttonStyle,
      child: Text(confirmLabel, textAlign: TextAlign.center),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        SafeArea(
          child: Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: mobile ? 19 : 20,
              vertical: 24,
            ),
            backgroundColor: palette.card,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: mobile
                  ? const BorderRadius.vertical(
                      top: Radius.circular(AppRadii.mobileDialog),
                    )
                  : const BorderRadius.all(Radius.circular(AppRadii.dialog)),
              side: BorderSide(color: palette.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppLayout.dialogWidth,
                maxHeight: math.min(
                  AppLayout.dialogMaxHeight,
                  size.height *
                      (mobile
                          ? AppLayout.dialogMobileHeightFactor
                          : AppLayout.dialogDesktopHeightFactor),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            constraints: BoxConstraints(
                              minHeight: mobile
                                  ? AppLayout.dialogMobileHeaderMinHeight
                                  : AppLayout.dialogHeaderMinHeight,
                            ),
                            padding: mobile
                                ? const EdgeInsets.fromLTRB(16, 17, 16, 14)
                                : const EdgeInsets.fromLTRB(21, 20, 21, 17),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: palette.border),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style:
                                        (mobile
                                                ? AppTypography.dialogTitle
                                                : AppTypography
                                                      .confirmationDesktopTitle)
                                            .copyWith(
                                              color: palette.foreground,
                                            ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  autofocus: true,
                                  tooltip: AppLocalizations.of(context)!
                                      .prototypeCloseDialog,
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  style: IconButton.styleFrom(
                                    foregroundColor: palette.mutedStrong,
                                    minimumSize: const Size.square(
                                      AppLayout.dialogCloseSize,
                                    ),
                                    maximumSize: const Size.square(
                                      AppLayout.dialogCloseSize,
                                    ),
                                    padding: EdgeInsets.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(LucideIcons.x, size: 20),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 15,
                              children: [
                                if (subject != null)
                                  Text(
                                    subject!,
                                    style: AppTypography.confirmationSubject
                                        .copyWith(color: palette.foreground),
                                  ),
                                Text(
                                  content,
                                  style: AppTypography.confirmationBody
                                      .copyWith(color: palette.foreground),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(minHeight: 70),
                    padding: EdgeInsets.symmetric(
                      horizontal: mobile ? 16 : 20,
                      vertical: mobile ? 12 : 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: palette.border)),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) => Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth * .62,
                            ),
                            child: IntrinsicWidth(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context, false),
                                style: buttonStyle.copyWith(
                                  side: WidgetStatePropertyAll(
                                    BorderSide(color: palette.borderStrong),
                                  ),
                                ),
                                child: Text(
                                  cancelLabel,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.actionGap),
                          if (mobile && expandConfirm)
                            Expanded(child: confirm)
                          else
                            Flexible(child: confirm),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SettingsJsonEditor extends StatefulWidget {
  final TextEditingController controller;
  final int lineCount;

  const SettingsJsonEditor({
    super.key,
    required this.controller,
    required this.lineCount,
  });

  @override
  State<SettingsJsonEditor> createState() => _SettingsJsonEditorState();
}

class _SettingsJsonEditorState extends State<SettingsJsonEditor> {
  final _editorScrollController = ScrollController();
  final _lineScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _editorScrollController.addListener(_syncLineNumbers);
  }

  @override
  void dispose() {
    _editorScrollController
      ..removeListener(_syncLineNumbers)
      ..dispose();
    _lineScrollController.dispose();
    super.dispose();
  }

  void _syncLineNumbers() {
    if (!_lineScrollController.hasClients) {
      return;
    }
    final target = _editorScrollController.offset.clamp(
      _lineScrollController.position.minScrollExtent,
      _lineScrollController.position.maxScrollExtent,
    );
    _lineScrollController.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: palette.muted,
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 47,
              color: Color.lerp(palette.card, palette.surfaceHover, .76),
              child: SingleChildScrollView(
                controller: _lineScrollController,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 14,
                ),
                child: Text(
                  List.generate(
                    math.max(16, widget.lineCount),
                    (index) => index + 1,
                  ).join("\n"),
                  textAlign: TextAlign.start,
                  style: AppTypography.code.copyWith(
                    color: ColorManager.secondaryText(context),
                  ),
                ),
              ),
            ),
            VerticalDivider(width: 1, color: ColorManager.border(context)),
            Expanded(
              child: TextField(
                controller: widget.controller,
                scrollController: _editorScrollController,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.all(14),
                ),
                keyboardType: TextInputType.multiline,
                autocorrect: false,
                enableSuggestions: false,
                style: AppTypography.code,
                minLines: null,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
