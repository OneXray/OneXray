import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/theme.dart';

void main() {
  group('AppTheme', () {
    test('light Material and Shad themes share the prototype palette', () {
      const tokens = AppColorTokens.light;
      final palette = tokens.palette;
      final material = AppTheme.light;
      final shad = AppTheme.shadColorScheme(Brightness.light);

      expect(material.scaffoldBackgroundColor, palette.background);
      expect(material.colorScheme.primary, palette.primary);
      expect(material.colorScheme.onPrimary, palette.primaryForeground);
      expect(material.colorScheme.surface, palette.card);
      expect(material.colorScheme.onSurface, palette.foreground);
      expect(material.colorScheme.error, palette.destructive);
      expect(material.colorScheme.outline, palette.border);
      expect(material.appBarTheme.backgroundColor, palette.header);
      expect(material.appBarTheme.foregroundColor, palette.foreground);
      expect(material.appBarTheme.toolbarHeight, isNull);
      expect(material.appBarTheme.titleSpacing, 20);
      expect(
        material.appBarTheme.actionsPadding,
        const EdgeInsetsDirectional.only(end: 12),
      );
      expect(material.appBarTheme.iconTheme, isNull);
      expect(material.appBarTheme.actionsIconTheme, isNull);
      expect(
        material.appBarTheme.systemOverlayStyle?.statusBarColor,
        palette.header,
      );
      expect(
        material.appBarTheme.systemOverlayStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
      expect(material.navigationRailTheme.backgroundColor, palette.sidebar);
      expect(material.navigationBarTheme.height, isNull);

      expect(shad.background, palette.background);
      expect(shad.foreground, palette.foreground);
      expect(shad.card, palette.card);
      expect(shad.primary, palette.primary);
      expect(shad.secondary, palette.secondary);
      expect(shad.muted, palette.muted);
      expect(shad.accent, palette.accent);
      expect(shad.destructive, palette.destructive);
      expect(shad.border, palette.border);
      expect(shad.input, palette.input);
      expect(shad.ring, palette.ring);
      expect(shad.custom['running'], palette.running);
      expect(shad.custom['runningText'], palette.runningText);
    });

    test('dark Material and Shad themes share translucent borders', () {
      const tokens = AppColorTokens.dark;
      final palette = tokens.palette;
      final material = AppTheme.dark;
      final shad = AppTheme.shadColorScheme(Brightness.dark);

      expect(material.brightness, Brightness.dark);
      expect(material.colorScheme.primary, palette.primary);
      expect(material.colorScheme.surface, palette.card);
      expect(material.dividerTheme.color, palette.border);
      expect(material.navigationBarTheme.backgroundColor, palette.sidebar);
      expect(
        material.appBarTheme.systemOverlayStyle?.statusBarIconBrightness,
        Brightness.light,
      );

      expect(shad.background, palette.background);
      expect(shad.card, palette.card);
      expect(shad.popover, palette.popover);
      expect(shad.border, const Color(0x1CFFFFFF));
      expect(shad.input, const Color(0x26FFFFFF));
    });

    test('Material and Shad themes share the Geist typography system', () {
      final material = AppTheme.light;
      final shad = AppTheme.shad(Brightness.light);

      expect(material.textTheme.bodyMedium?.fontFamily, AppFontFamily.sans);
      expect(
        material.textTheme.bodyMedium?.fontFamilyFallback,
        AppFontFamily.sansFallback,
      );
      expect(material.textTheme.bodyMedium?.fontSize, 14);
      expect(material.textTheme.bodyMedium?.height, 20 / 14);
      expect(material.textTheme.bodySmall?.fontSize, 14);
      expect(material.textTheme.labelSmall?.fontSize, 14);
      expect(shad.textTheme.family, AppFontFamily.sans);
      expect(
        shad.textTheme.muted.fontFamilyFallback,
        AppFontFamily.sansFallback,
      );
      expect(shad.textTheme.p.fontSize, 16);
      expect(shad.textTheme.p.height, 28 / 16);
      expect(shad.textTheme.small.fontSize, 14);
      expect(shad.textTheme.muted.fontSize, 14);
      expect(shad.textTheme.muted.height, 20 / 14);
      expect(shad.textTheme.h1.letterSpacing, 0);
      expect(shad.textTheme.h4.letterSpacing, 0);
      expect(AppTypography.supporting.fontSize, 14);
      expect(AppTypography.navigationLabel.fontSize, 14);
      expect(AppTypography.badge.fontSize, 14);
      expect(AppTypography.code.fontFamily, AppFontFamily.mono);
      expect(AppTypography.code.fontSize, 14);
      expect(AppTypography.code.height, 20 / 14);
      expect(AppFontFamily.windowsSansFallback, const <String>[
        "Microsoft YaHei UI",
        "Microsoft YaHei",
      ]);
    });

    test('legacy color accessors map to semantic prototype tokens', () {
      const tokens = AppColorTokens.light;
      final palette = tokens.palette;

      expect(tokens.pageBackground, palette.background);
      expect(tokens.surface, palette.card);
      expect(tokens.surfaceBorder, palette.border);
      expect(tokens.primaryText, palette.foreground);
      expect(tokens.secondaryText, palette.mutedForeground);
      expect(tokens.tagBackground, palette.muted);
      expect(tokens.sectionTitle, palette.mutedForeground);
      expect(tokens.interactiveText, palette.primary);
      expect(tokens.secondaryButtonBackground, palette.secondary);
      expect(tokens.secondaryButtonForeground, palette.secondaryForeground);
    });
  });
}
