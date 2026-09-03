import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
      expect(material.appBarTheme.titleSpacing, AppSpacing.page);
      expect(
        material.appBarTheme.actionsPadding,
        const EdgeInsetsDirectional.only(end: AppSpacing.page),
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

    test('dark Material and Shad themes share the mapped opaque borders', () {
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
      expect(shad.border, const Color(0xFF2B3543));
      expect(shad.input, const Color(0xFF2B3543));
      expect(palette.primary, const Color(0xFF69A5FF));
      expect(palette.primarySolid, const Color(0xFF1F6AF9));
      expect(palette.foreground, const Color(0xFFF2F5F8));
    });

    test('Material and Shad themes share the Geist typography system', () {
      final material = AppTheme.light;
      final shad = AppTheme.shad(Brightness.light);

      expect(material.textTheme.bodyMedium?.fontFamily, AppFontFamily.sans);
      expect(
        material.textTheme.bodyMedium?.fontFamilyFallback,
        AppFontFamily.sansFallback,
      );
      expect(material.textTheme.bodyMedium?.fontSize, 13);
      expect(material.textTheme.bodyMedium?.height, 1.5);
      expect(material.textTheme.bodySmall?.fontSize, 12);
      expect(material.textTheme.labelSmall?.fontSize, 11);
      expect(shad.textTheme.family, AppFontFamily.sans);
      expect(
        shad.textTheme.muted.fontFamilyFallback,
        AppFontFamily.sansFallback,
      );
      expect(shad.textTheme.p.fontSize, 13);
      expect(shad.textTheme.p.height, 1.5);
      expect(shad.textTheme.small.fontSize, 13);
      expect(shad.textTheme.muted.fontSize, 12);
      expect(shad.textTheme.muted.height, 1.5);
      expect(shad.textTheme.h1.letterSpacing, 31 * -0.035);
      expect(shad.textTheme.h4.letterSpacing, 0);
      expect(AppTypography.pageTitle.fontSize, 31);
      expect(AppTypography.panelTitle.fontSize, 19);
      expect(AppTypography.supporting.fontSize, 12);
      expect(AppTypography.navigationLabel.fontSize, 16);
      expect(AppTypography.badge.fontSize, 11);
      expect(AppTypography.control.fontVariations, const [
        FontVariation('wght', 620),
      ]);
      expect(AppTypography.navigationLabel.fontVariations, const [
        FontVariation('wght', 520),
      ]);
      expect(AppTypography.code.fontFamily, AppFontFamily.mono);
      expect(AppTypography.code.fontSize, 12);
      expect(AppTypography.code.height, 1.55);
      expect(AppTypography.metric.fontSize, 20);
      expect(AppTypography.metric.fontFeatures, const [
        FontFeature.tabularFigures(),
      ]);
      expect(AppFontFamily.windowsSansFallback, const <String>[
        "Microsoft YaHei UI",
        "Microsoft YaHei",
      ]);
    });

    test(
      'both themes keep solid button colors separate from interactive text',
      () {
        for (final brightness in Brightness.values) {
          final palette = AppColorTokens.fallback(brightness).palette;
          final material = AppTheme.material(brightness);
          final shad = AppTheme.shad(brightness);
          final filled = material.filledButtonTheme.style!;
          expect(filled.backgroundColor!.resolve({}), palette.primarySolid);
          expect(
            filled.backgroundColor!.resolve({WidgetState.hovered}),
            palette.primarySolidHover,
          );
          expect(filled.foregroundColor!.resolve({}), Colors.white);
          expect(
            material.textButtonTheme.style!.foregroundColor!.resolve({}),
            palette.primary,
          );
          expect(shad.primaryButtonTheme.backgroundColor, palette.primarySolid);
          expect(
            shad.primaryButtonTheme.hoverBackgroundColor,
            palette.primarySolidHover,
          );
          expect(shad.primaryButtonTheme.foregroundColor, Colors.white);
          expect(
            shad.destructiveButtonTheme.backgroundColor,
            palette.destructiveSolid,
          );
          expect(shad.destructiveButtonTheme.foregroundColor, Colors.white);
          expect(shad.outlineButtonTheme.foregroundColor, palette.foreground);
          expect(
            shad.inputTheme.style!.fontSize,
            material.textTheme.bodyMedium!.fontSize,
          );
          expect(
            shad.switchTheme.checkedTrackColor,
            material.switchTheme.trackColor!.resolve({WidgetState.selected}),
          );
          expect(
            shad.switchTheme.uncheckedTrackColor,
            material.switchTheme.trackColor!.resolve({}),
          );
          expect(shad.switchTheme.thumbColor, Colors.white);
          expect(material.dialogTheme.barrierColor, palette.overlay);
          expect(
            material.navigationRailTheme.indicatorColor,
            palette.selectedSurface,
          );
          expect(
            material.navigationRailTheme.selectedLabelTextStyle!.fontVariations,
            AppTypography.selectedNavigationLabel.fontVariations,
          );
          final input =
              material.inputDecorationTheme.border! as OutlineInputBorder;
          expect(input.borderRadius, BorderRadius.circular(AppRadii.control));
        }
      },
    );

    test('mobile theme uses shared header, gutter and button sizes', () {
      final material = AppTheme.material(Brightness.light, mobile: true);
      final shad = AppTheme.shad(Brightness.light, mobile: true);
      expect(material.appBarTheme.titleTextStyle!.fontSize, 21);
      expect(material.appBarTheme.titleTextStyle!.letterSpacing, 21 * -0.025);
      expect(material.appBarTheme.toolbarHeight, AppLayout.mobileHeaderHeight);
      expect(material.appBarTheme.titleSpacing, AppSpacing.mobilePage);
      expect(
        material.filledButtonTheme.style!.minimumSize!.resolve({}),
        const Size.square(AppLayout.mobileButtonMinHeight),
      );
      expect(
        shad.buttonSizesTheme.regular!.height,
        AppLayout.mobileButtonMinHeight,
      );
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

  testWidgets('scaled Shad footer grows and avoids keyboard and safe area', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const scale = TextScaler.linear(2);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.material(Brightness.dark, mobile: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: scale,
            padding: const EdgeInsets.only(bottom: 34),
            viewPadding: const EdgeInsets.only(bottom: 34),
            viewInsets: const EdgeInsets.only(bottom: 240),
          ),
          child: ShadTheme(
            data: AppTheme.shad(
              Brightness.dark,
              mobile: true,
              textScaler: scale,
            ),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: ListView(
            children: List.generate(30, (i) => ListTile(title: Text('Row $i'))),
          ),
          bottomNavigationBar: PageActionBar(
            children: [
              ShadButton.outline(onPressed: () {}, child: const Text('Cancel')),
              ShadButton(onPressed: () {}, child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final save = find.byType(ShadButton).last;
    final rect = tester.getRect(save);
    expect(rect.height, greaterThanOrEqualTo(59));
    expect(rect.bottom, lessThanOrEqualTo(800 - 240 - 34));
    expect(tester.getSize(find.text('Save')).height, greaterThan(26));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(save), rect);
    expect(tester.takeException(), isNull);
  });
}
