import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

class AppJsonEditor extends StatelessWidget {
  const AppJsonEditor({super.key, required this.controller, this.textStyle});

  final CodeLineEditingController controller;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    final style = textStyle ?? AppTypography.code;
    final codeTheme = Map<String, TextStyle>.from(
      Theme.of(context).brightness == Brightness.dark
          ? atomOneDarkTheme
          : atomOneLightTheme,
    );
    final rootStyle = codeTheme['root'];
    if (rootStyle != null) {
      codeTheme['root'] = rootStyle.copyWith(
        backgroundColor: Colors.transparent,
      );
    }
    final lineNumberStyle = style.copyWith(
      color: palette.mutedForeground,
      fontFamily: AppFontFamily.mono,
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: CodeEditor(
        controller: controller,
        autofocus: false,
        autocompleteSymbols: true,
        wordWrap: false,
        padding: const EdgeInsets.all(14),
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(AppRadii.card),
        clipBehavior: Clip.antiAlias,
        style: CodeEditorStyle(
          fontFamily: AppFontFamily.mono,
          fontSize: style.fontSize,
          textColor: palette.foreground,
          backgroundColor: palette.muted,
          selectionColor: palette.selection,
          cursorColor: palette.primary,
          cursorLineColor: palette.primary.withValues(alpha: .05),
          codeTheme: CodeHighlightTheme(
            languages: {'json': CodeHighlightThemeMode(mode: langJson)},
            theme: codeTheme,
          ),
        ),
        indicatorBuilder: (context, editingController, _, notifier) =>
            Container(
              color: Color.lerp(palette.card, palette.surfaceHover, .76),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 14),
              child: DefaultCodeLineNumber(
                controller: editingController,
                notifier: notifier,
                textStyle: lineNumberStyle,
                focusedTextStyle: lineNumberStyle.copyWith(
                  color: palette.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        leadingDivider: Container(width: 1, color: palette.border),
      ),
    );
  }
}
