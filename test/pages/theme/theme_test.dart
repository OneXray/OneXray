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
      expect(material.iconTheme.color, palette.foreground);
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
      expect(
        material.navigationBarTheme.height,
        AppLayout.mobileNavigationHeight,
      );

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
      expect(material.iconTheme.color, palette.foreground);
      expect(material.dividerTheme.color, palette.border);
      expect(
        material.navigationBarTheme.backgroundColor,
        palette.card.withValues(alpha: 0.96),
      );
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
      expect(AppFontFamily.androidSansFallback, const <String>["sans-serif"]);
      for (final (style, size, weight) in [
        (AppTypography.connectStatusTitle, 17, 650),
        (AppTypography.connectButton, 16, 660),
        (AppTypography.connectCaption, 12, 620),
        (AppTypography.connectChoiceLabel, 11, 520),
        (AppTypography.connectChoiceTitle, 14, 620),
        (AppTypography.connectChoiceMeta, 10.5, 600),
        (AppTypography.connectTrafficTitle, 15, 650),
        (AppTypography.connectTrafficGroupTitle, 11, 520),
        (AppTypography.connectTrafficValue, 15, 620),
        (AppTypography.connectRawTitle, 12, 650),
        (AppTypography.connectRawCount, 12, 610),
        (AppTypography.dialogTitle, 18, 700),
        (AppTypography.dialogSubtitle, 13, 400),
      ]) {
        expect(style.fontSize, size);
        expect(style.fontVariations, [
          FontVariation('wght', weight.toDouble()),
        ]);
      }
      expect(AppTypography.connectStatusTitle.height, 1.3);
      expect(AppTypography.connectChoiceTitle.height, 1.4);
      expect(AppTypography.connectChoiceDetail.height, 1.35);
      expect(AppTypography.connectStatusDetail.height, kTextHeightNone);
      expect(AppTypography.connectTrafficValue.height, kTextHeightNone);
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
          expect(shad.switchTheme.width, 42);
          expect(shad.switchTheme.height, 24);
          expect(shad.switchTheme.margin, 2);
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
      expect(
        material.appBarTheme.titleSpacing,
        AppSpacing.mobileHeaderHorizontal,
      );
      expect(
        material.appBarTheme.actionsPadding,
        const EdgeInsetsDirectional.only(
          end: AppSpacing.mobileHeaderHorizontal,
        ),
      );
      final navigation = material.navigationBarTheme;
      expect(navigation.height, 92);
      expect(navigation.indicatorColor, Colors.transparent);
      expect(navigation.iconTheme!.resolve({})!.size, 21);
      expect(
        navigation.iconTheme!.resolve({})!.color,
        AppPalette.light.mutedStrong,
      );
      expect(navigation.labelTextStyle!.resolve({})!.fontSize, 10);
      expect(
        navigation.labelTextStyle!.resolve({})!.fontWeight,
        FontWeight.w400,
      );
      expect(
        navigation.labelTextStyle!.resolve({
          WidgetState.selected,
        })!.fontVariations,
        const [FontVariation('wght', 620)],
      );
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

  testWidgets('connection button keeps prototype colors and disabled opacity', (
    tester,
  ) async {
    expect(
      const AppDashedBorder().copyWith(side: const BorderSide(width: 2)),
      isA<AppDashedBorder>(),
    );
    for (final brightness in Brightness.values) {
      final palette = AppColorTokens.fallback(brightness).palette;
      late ButtonStyle primary;
      late ButtonStyle destructive;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.material(brightness, mobile: true),
          home: Builder(
            builder: (context) {
              primary = AppTheme.connectionButton(context, destructive: false);
              destructive = AppTheme.connectionButton(
                context,
                destructive: true,
              );
              return Scaffold(
                body: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: AppDashedBorder(
                      side: BorderSide(color: palette.borderStrong),
                      borderRadius: BorderRadius.circular(AppRadii.card),
                    ),
                  ),
                  child: FilledButton(
                    onPressed: () {},
                    style: primary,
                    child: const Text('Connect'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(primary.backgroundColor!.resolve({}), palette.primarySolid);
      expect(
        primary.backgroundColor!.resolve({WidgetState.disabled}),
        Color.alphaBlend(
          palette.primarySolid.withValues(alpha: 0.52),
          palette.card,
        ),
      );
      expect(
        destructive.backgroundColor!.resolve({}),
        palette.destructiveSolid,
      );
      expect(
        destructive.backgroundColor!.resolve({WidgetState.hovered}),
        palette.destructiveSolidHover,
      );
      expect(
        primary.overlayColor!.resolve({WidgetState.pressed}),
        Colors.transparent,
      );
      expect(primary.textStyle!.resolve({})!.fontSize, 16);
      expect(tester.getSize(find.byType(FilledButton)).height, 45);
      expect(tester.takeException(), isNull);
    }
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
