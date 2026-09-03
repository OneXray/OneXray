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
  // Keep Android's locale-aware CJK fallback; Apple font names are not portable.
  // This does not claim that the browser and device render the same CJK font.
  static const androidSansFallback = <String>["sans-serif"];

  static List<String>? get sansFallback {
    if (AppPlatform.isWindows) return windowsSansFallback;
    if (AppPlatform.isAndroid) return androidSansFallback;
    return null;
  }
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

  // CSS `normal` uses font metrics. kTextHeightNone prevents a surrounding
  // DefaultTextStyle from replacing it with the general body's 1.5 multiplier.
  static TextStyle _prototypeRole(
    double size,
    double weight, {
    double height = kTextHeightNone,
  }) => _style(
    size,
    height: height,
    weight: FontWeight.values[(weight / 100).round() - 1],
  ).copyWith(fontVariations: [FontVariation('wght', weight)]);

  static final mobileNavigationLabel = _prototypeRole(10, 400);
  static final selectedMobileNavigationLabel = _prototypeRole(10, 620);

  static final pageAction = _prototypeRole(12, 620, height: 1.4);
  static final secondaryPageTitle = _prototypeRole(
    16,
    680,
    height: 1.18,
  ).copyWith(letterSpacing: 16 * -0.035);
  static final advancedPageTitle = _prototypeRole(
    23,
    700,
    height: 1.18,
  ).copyWith(letterSpacing: 23 * -0.035);
  static final advancedTab = _prototypeRole(12.5, 560);
  static final selectedAdvancedTab = _prototypeRole(12.5, 620);

  static final settingsSectionTitle = _prototypeRole(14, 650, height: 1.3);
  static final settingsSectionDesktopTitle = _prototypeRole(
    16,
    650,
    height: 1.3,
  );
  static final settingsRow = _prototypeRole(14, 560);
  static final settingsFieldTitle = _prototypeRole(13.5, 560);
  static final settingsValueLabel = _prototypeRole(12.5, 400);
  static final settingsValue = _prototypeRole(12.5, 520);
  static final settingsStatus = _prototypeRole(12.5, 620);
  static final settingsHint = _prototypeRole(10.5, 400, height: 1.5);
  static final settingsThemeOption = _prototypeRole(14, 400);
  static final settingsThemeOptionMobile = _prototypeRole(12.5, 400);
  static final settingsVersion = _prototypeRole(12.5, 400);
  static final settingsNote = _prototypeRole(10.5, 400, height: 1.45);
  static final settingsDetailNote = _prototypeRole(12, 400, height: 1.6);
  static final settingsSelect = _prototypeRole(14, 400, height: 1.4);
  static final settingsInput = _prototypeRole(13, 400);
  static final aboutBrandTitle = _prototypeRole(19, 700, height: 1.3);
  static final aboutBrandDescription = _prototypeRole(12, 400, height: 1.375);
  static final settingsChoiceTitle = _prototypeRole(14, 570);
  static final settingsChoiceDetail = _prototypeRole(11, 400, height: 1.5);
  static final settingsDanger = _prototypeRole(13.5, 570);
  static final backupBody = _prototypeRole(14, 400, height: 1.65);
  static final backupScopeHint = _prototypeRole(12, 400, height: 1.65);
  static final backupAction = _prototypeRole(12, 620);
  static final backupEmptyTitle = _prototypeRole(16, 700);

  static final runtimeLabel = _prototypeRole(9.5, 400);
  static final runtimeDesktopLabel = _prototypeRole(11, 400);
  static final runtimeValue = _prototypeRole(11, 700);
  static final runtimeDesktopValue = _prototypeRole(13, 700);
  static final runtimeNavigationHint = _prototypeRole(11.5, 400);
  static final runtimePushHint = _prototypeRole(10, 400);
  static final runtimeDesktopPushHint = _prototypeRole(11, 400);
  static final runtimeSelector = _prototypeRole(12, 400);
  static final runtimeDesktopSelector = _prototypeRole(14, 400);

  static final serverBody = _prototypeRole(16, 400);
  static final serverTitle = _prototypeRole(14, 630);
  // HTML small inherits 5/6 of the prototype's 16px body text.
  static final serverDetail = _prototypeRole(16 * 5 / 6, 400);
  static final serverGroupDetail = _prototypeRole(16 * 5 / 6, 400, height: 1.4);
  static final serverSectionTitle = _prototypeRole(
    12,
    650,
    height: 1.3,
  ).copyWith(letterSpacing: 12 * 0.035);
  static final serverRegionCode = _prototypeRole(11, 720);
  static final serverSelectionHealth = _prototypeRole(11, 620);
  static final serverSelectionLabel = _prototypeRole(11, 400);
  static final serverSelectionTitle = _prototypeRole(14, 700);
  static final serverSelectionDetail = _prototypeRole(12, 400);
  static final serverUseLabel = _prototypeRole(10.5, 620);
  static final serverUseCount = _prototypeRole(14, 630, height: 1);

  static final connectStatusTitle = _prototypeRole(17, 650, height: 1.3);
  static final connectStatusDetail = _prototypeRole(13, 400);
  static final connectButton = _prototypeRole(16, 660);
  static final connectCaption = _prototypeRole(12, 620);
  static final connectChoiceLabel = _prototypeRole(11, 520);
  static final connectChoiceTitle = _prototypeRole(14, 620, height: 1.4);
  static final connectChoiceDetail = _prototypeRole(10.5, 400, height: 1.35);
  static final connectChoiceMeta = _prototypeRole(10.5, 600);
  static final connectWhy = _prototypeRole(14, 570);
  static final connectTrafficTitle = _prototypeRole(15, 650);
  static final connectTrafficGroupTitle = _prototypeRole(11, 520, height: 1.35);
  static final connectTrafficLabel = _prototypeRole(10, 400);
  static final connectTrafficValue = _prototypeRole(
    15,
    620,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  static final connectRawTitle = _prototypeRole(12, 650);
  static final connectRawCount = _prototypeRole(12, 610);
  static final connectRawEmptyTitle = _prototypeRole(12, 700);
  static final connectRawEmptyDetail = _prototypeRole(10, 400, height: 1.45);
  static final connectRawNotice = _prototypeRole(10, 400, height: 1.4);
  static final connectRawRowTitle = _prototypeRole(13, 630);
  static final connectRawRowDetail = _prototypeRole(10.5, 400);

  static final dialogTitle = _prototypeRole(18, 700, height: 1.3);
  static final dialogSubtitle = _prototypeRole(13, 400, height: 1.45);
  static final dialogBody = _prototypeRole(14, 400, height: 1.55);
  static final dialogCallout = _prototypeRole(13, 400, height: 1.45);
  static final dialogOptionTitle = _prototypeRole(14, 700);
  static final dialogOptionDescription = _prototypeRole(12, 400, height: 1.4);
  static final dialogOptionEdit = _prototypeRole(12, 650);
  static final dialogGroupTitle = _prototypeRole(13, 700);
  static final dialogGroupMeta = _prototypeRole(10.5, 400);
  static final dialogAddAction = _prototypeRole(12, 620);
  static final confirmationDesktopTitle = _prototypeRole(20, 700, height: 1.3);
  static final confirmationSubject = _prototypeRole(14, 700, height: 1.6);
  static final confirmationBody = _prototypeRole(14, 400, height: 1.6);

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
