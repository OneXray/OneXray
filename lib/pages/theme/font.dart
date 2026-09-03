import 'package:flutter/material.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

abstract final class AppFontFamily {
  static const sans = "packages/shadcn_ui/Geist";
  static const mono = "packages/shadcn_ui/GeistMono";
  static const windowsSansFallback = <String>[
    "Microsoft YaHei UI",
    "Microsoft YaHei",
  ];

  static List<String>? get sansFallback =>
      AppPlatform.isWindows ? windowsSansFallback : null;
}

abstract final class AppTypography {
  // Semantic roles from the prototype's src/theme/tokens.json. Use logical
  // pixels and leave system text scaling and locale-specific glyphs to Flutter.
  static TextStyle _style(
    double size, {
    double height = 1.5,
    FontWeight weight = FontWeight.w400,
    double tracking = 0,
  }) {
    return TextStyle(
      fontFamily: AppFontFamily.sans,
      fontFamilyFallback: AppFontFamily.sansFallback,
      fontSize: size,
      height: height,
      fontWeight: weight,
      letterSpacing: size * tracking,
    );
  }

  static final pageTitle = _style(
    31,
    height: 1.18,
    weight: FontWeight.w700,
    tracking: -0.035,
  );
  static final mobilePageTitle = _style(
    21,
    height: 1.18,
    weight: FontWeight.w700,
    tracking: -0.025,
  );
  static final panelTitle = _style(19, height: 1.3, weight: FontWeight.w700);
  static final sectionTitle = _style(14, height: 1.35, weight: FontWeight.w700);
  static final listSectionTitle = _style(16, weight: FontWeight.w600);
  static final rowTitle = _style(13, weight: FontWeight.w700);
  static final rowValue = _style(13);
  static final supporting = _style(12);
  static final metadata = _style(11, height: 1.4);
  static final control = _style(
    13,
    weight: FontWeight.w600,
  ).copyWith(fontVariations: const [FontVariation('wght', 620)]);
  static final navigationLabel = _style(
    16,
    weight: FontWeight.w500,
  ).copyWith(fontVariations: const [FontVariation('wght', 520)]);
  static final selectedNavigationLabel = navigationLabel.copyWith(
    fontWeight: FontWeight.w600,
    fontVariations: const [FontVariation('wght', 620)],
  );
  static final badge = metadata.copyWith(fontWeight: FontWeight.w600);
  static final code = _style(
    12,
    height: 1.55,
  ).copyWith(fontFamily: AppFontFamily.mono);
  static final metric = _style(20, weight: FontWeight.w600).copyWith(
    fontVariations: const [FontVariation('wght', 620)],
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  static final numeric = rowValue.copyWith(
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static final shad = ShadTextTheme.custom(
    h1Large: pageTitle,
    h1: pageTitle,
    h2: panelTitle,
    h3: sectionTitle,
    h4: sectionTitle,
    p: rowValue,
    blockquote: rowValue,
    table: rowValue,
    list: rowValue,
    lead: supporting,
    large: panelTitle,
    small: control,
    muted: supporting,
    family: AppFontFamily.sans,
  );

  static final material = TextTheme(
    displayLarge: pageTitle,
    displayMedium: pageTitle,
    displaySmall: panelTitle,
    headlineLarge: pageTitle,
    headlineMedium: panelTitle,
    headlineSmall: panelTitle,
    titleLarge: panelTitle,
    titleMedium: sectionTitle,
    titleSmall: rowTitle,
    bodyLarge: rowValue,
    bodyMedium: rowValue,
    bodySmall: supporting,
    labelLarge: control,
    labelMedium: control,
    labelSmall: badge,
  );
}
