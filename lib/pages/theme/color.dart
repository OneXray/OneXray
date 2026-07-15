import 'package:flutter/material.dart';

@immutable
class AppPalette {
  const AppPalette({
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.popover,
    required this.popoverForeground,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.destructive,
    required this.destructiveForeground,
    required this.border,
    required this.input,
    required this.ring,
    required this.selection,
    required this.scannerBackground,
    required this.header,
    required this.sidebar,
    required this.sidebarForeground,
    required this.sidebarPrimary,
    required this.sidebarPrimaryForeground,
    required this.sidebarAccent,
    required this.sidebarAccentForeground,
    required this.sidebarBorder,
    required this.sidebarRing,
    required this.selectedSurface,
    required this.running,
    required this.runningText,
    required this.runningBadge,
    required this.runningBadgeForeground,
    required this.runningForeground,
    required this.runningSurface,
    required this.restarting,
    required this.restartingText,
    required this.destructiveSurface,
    required this.chart1,
    required this.chart2,
    required this.chart3,
    required this.chart4,
    required this.chart5,
  });

  // sRGB equivalents of the prototype's OKLCH design tokens.
  static const light = AppPalette(
    background: Color(0xFFFBFCFD),
    foreground: Color(0xFF10141B),
    card: Color(0xFFFFFFFF),
    cardForeground: Color(0xFF10141B),
    popover: Color(0xFFFFFFFF),
    popoverForeground: Color(0xFF10141B),
    primary: Color(0xFF0073E9),
    primaryForeground: Color(0xFFFAFAFA),
    secondary: Color(0xFFF1F4F7),
    secondaryForeground: Color(0xFF1D2229),
    muted: Color(0xFFF1F4F7),
    mutedForeground: Color(0xFF616A76),
    accent: Color(0xFFE8EFF9),
    accentForeground: Color(0xFF19273A),
    destructive: Color(0xFFE32729),
    destructiveForeground: Color(0xFFFAFAFA),
    border: Color(0xFFDADEE5),
    input: Color(0xFFDADEE5),
    ring: Color(0xFF0073E9),
    selection: Color(0xFFCFE2FB),
    scannerBackground: Color(0xFF101214),
    header: Color(0xFFFAFBFD),
    sidebar: Color(0xFFF6F8FA),
    sidebarForeground: Color(0xFF1A2027),
    sidebarPrimary: Color(0xFF0073E9),
    sidebarPrimaryForeground: Color(0xFFFAFAFA),
    sidebarAccent: Color(0xFFE4ECF7),
    sidebarAccentForeground: Color(0xFF133D70),
    sidebarBorder: Color(0xFFDADEE5),
    sidebarRing: Color(0xFF0073E9),
    selectedSurface: Color(0xFFF4F8FF),
    running: Color(0xFF00B667),
    runningText: Color(0xFF059669),
    runningBadge: Color(0xFF047857),
    runningBadgeForeground: Color(0xFFFFFFFF),
    runningForeground: Color(0xFF10141B),
    runningSurface: Color(0xFFF6FCF7),
    restarting: Color(0xFFDD9400),
    restartingText: Color(0xFFD97706),
    destructiveSurface: Color(0x1AE32729),
    chart1: Color(0xFF2584F5),
    chart2: Color(0xFF0BAA6B),
    chart3: Color(0xFFD98B00),
    chart4: Color(0xFFE54151),
    chart5: Color(0xFF8C54B2),
  );

  static const dark = AppPalette(
    background: Color(0xFF090E13),
    foreground: Color(0xFFEFF2F6),
    card: Color(0xFF11151B),
    cardForeground: Color(0xFFEFF2F6),
    popover: Color(0xFF11151B),
    popoverForeground: Color(0xFFEFF2F6),
    primary: Color(0xFF4296FB),
    primaryForeground: Color(0xFF060B14),
    secondary: Color(0xFF1C2128),
    secondaryForeground: Color(0xFFECEFF2),
    muted: Color(0xFF1A1E25),
    mutedForeground: Color(0xFF979FAB),
    accent: Color(0xFF1B2737),
    accentForeground: Color(0xFFDDEDFF),
    destructive: Color(0xFFFA6865),
    destructiveForeground: Color(0xFF060B14),
    border: Color(0x1CFFFFFF),
    input: Color(0x26FFFFFF),
    ring: Color(0xFF4296FB),
    selection: Color(0xFF1C2C42),
    scannerBackground: Color(0xFF101214),
    header: Color(0xFF0A0E14),
    sidebar: Color(0xFF0E1218),
    sidebarForeground: Color(0xFFECEFF2),
    sidebarPrimary: Color(0xFF4296FB),
    sidebarPrimaryForeground: Color(0xFF060B14),
    sidebarAccent: Color(0xFF1B232F),
    sidebarAccentForeground: Color(0xFFDDEDFF),
    sidebarBorder: Color(0x1AFFFFFF),
    sidebarRing: Color(0xFF4296FB),
    selectedSurface: Color(0xFF141B24),
    running: Color(0xFF00B667),
    runningText: Color(0xFF34D399),
    runningBadge: Color(0xFF6EE7B7),
    runningBadgeForeground: Color(0xFF052E16),
    runningForeground: Color(0xFF060B14),
    runningSurface: Color(0xFF121D16),
    restarting: Color(0xFFDD9400),
    restartingText: Color(0xFFFBBF24),
    destructiveSurface: Color(0x33FA6865),
    chart1: Color(0xFF2584F5),
    chart2: Color(0xFF0BAA6B),
    chart3: Color(0xFFD98B00),
    chart4: Color(0xFFE54151),
    chart5: Color(0xFF8C54B2),
  );

  final Color background;
  final Color foreground;
  final Color card;
  final Color cardForeground;
  final Color popover;
  final Color popoverForeground;
  final Color primary;
  final Color primaryForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color accentForeground;
  final Color destructive;
  final Color destructiveForeground;
  final Color border;
  final Color input;
  final Color ring;
  final Color selection;
  final Color scannerBackground;
  final Color header;
  final Color sidebar;
  final Color sidebarForeground;
  final Color sidebarPrimary;
  final Color sidebarPrimaryForeground;
  final Color sidebarAccent;
  final Color sidebarAccentForeground;
  final Color sidebarBorder;
  final Color sidebarRing;
  final Color selectedSurface;
  final Color running;
  final Color runningText;
  final Color runningBadge;
  final Color runningBadgeForeground;
  final Color runningForeground;
  final Color runningSurface;
  final Color restarting;
  final Color restartingText;
  final Color destructiveSurface;
  final Color chart1;
  final Color chart2;
  final Color chart3;
  final Color chart4;
  final Color chart5;

  static AppPalette lerp(AppPalette begin, AppPalette end, double t) {
    Color color(Color a, Color b) => Color.lerp(a, b, t) ?? b;

    return AppPalette(
      background: color(begin.background, end.background),
      foreground: color(begin.foreground, end.foreground),
      card: color(begin.card, end.card),
      cardForeground: color(begin.cardForeground, end.cardForeground),
      popover: color(begin.popover, end.popover),
      popoverForeground: color(begin.popoverForeground, end.popoverForeground),
      primary: color(begin.primary, end.primary),
      primaryForeground: color(begin.primaryForeground, end.primaryForeground),
      secondary: color(begin.secondary, end.secondary),
      secondaryForeground: color(
        begin.secondaryForeground,
        end.secondaryForeground,
      ),
      muted: color(begin.muted, end.muted),
      mutedForeground: color(begin.mutedForeground, end.mutedForeground),
      accent: color(begin.accent, end.accent),
      accentForeground: color(begin.accentForeground, end.accentForeground),
      destructive: color(begin.destructive, end.destructive),
      destructiveForeground: color(
        begin.destructiveForeground,
        end.destructiveForeground,
      ),
      border: color(begin.border, end.border),
      input: color(begin.input, end.input),
      ring: color(begin.ring, end.ring),
      selection: color(begin.selection, end.selection),
      scannerBackground: color(begin.scannerBackground, end.scannerBackground),
      header: color(begin.header, end.header),
      sidebar: color(begin.sidebar, end.sidebar),
      sidebarForeground: color(begin.sidebarForeground, end.sidebarForeground),
      sidebarPrimary: color(begin.sidebarPrimary, end.sidebarPrimary),
      sidebarPrimaryForeground: color(
        begin.sidebarPrimaryForeground,
        end.sidebarPrimaryForeground,
      ),
      sidebarAccent: color(begin.sidebarAccent, end.sidebarAccent),
      sidebarAccentForeground: color(
        begin.sidebarAccentForeground,
        end.sidebarAccentForeground,
      ),
      sidebarBorder: color(begin.sidebarBorder, end.sidebarBorder),
      sidebarRing: color(begin.sidebarRing, end.sidebarRing),
      selectedSurface: color(begin.selectedSurface, end.selectedSurface),
      running: color(begin.running, end.running),
      runningText: color(begin.runningText, end.runningText),
      runningBadge: color(begin.runningBadge, end.runningBadge),
      runningBadgeForeground: color(
        begin.runningBadgeForeground,
        end.runningBadgeForeground,
      ),
      runningForeground: color(begin.runningForeground, end.runningForeground),
      runningSurface: color(begin.runningSurface, end.runningSurface),
      restarting: color(begin.restarting, end.restarting),
      restartingText: color(begin.restartingText, end.restartingText),
      destructiveSurface: color(
        begin.destructiveSurface,
        end.destructiveSurface,
      ),
      chart1: color(begin.chart1, end.chart1),
      chart2: color(begin.chart2, end.chart2),
      chart3: color(begin.chart3, end.chart3),
      chart4: color(begin.chart4, end.chart4),
      chart5: color(begin.chart5, end.chart5),
    );
  }
}

class AppColorTokens extends ThemeExtension<AppColorTokens> {
  const AppColorTokens(this.palette);

  static const light = AppColorTokens(AppPalette.light);
  static const dark = AppColorTokens(AppPalette.dark);

  final AppPalette palette;

  Color get pageBackground => palette.background;
  Color get surface => palette.card;
  Color get surfaceBorder => palette.border;
  Color get primaryText => palette.foreground;
  Color get secondaryText => palette.mutedForeground;
  Color get tagBackground => palette.muted;
  Color get selectedBackground => palette.selectedSurface;
  Color get runningBackground => palette.runningSurface;
  Color get stopButtonBackground => palette.destructiveSurface;
  Color get stopButtonForeground => palette.destructive;
  Color get sectionTitle => palette.mutedForeground;
  Color get interactiveText => palette.primary;
  Color get secondaryButtonBackground => palette.secondary;
  Color get secondaryButtonForeground => palette.secondaryForeground;

  static AppColorTokens fallback(Brightness brightness) {
    return brightness == Brightness.light ? light : dark;
  }

  @override
  AppColorTokens copyWith({AppPalette? palette}) {
    return AppColorTokens(palette ?? this.palette);
  }

  @override
  AppColorTokens lerp(ThemeExtension<AppColorTokens>? other, double t) {
    if (other is! AppColorTokens) {
      return this;
    }
    return AppColorTokens(AppPalette.lerp(palette, other.palette, t));
  }
}

class ColorManager {
  static AppColorTokens tokens(BuildContext context) {
    return Theme.of(context).extension<AppColorTokens>() ??
        AppColorTokens.fallback(Theme.of(context).brightness);
  }

  static AppPalette palette(BuildContext context) => tokens(context).palette;

  static Color scaffoldBackground(Brightness brightness) {
    return AppColorTokens.fallback(brightness).pageBackground;
  }

  static Color surface(BuildContext context) => tokens(context).surface;

  static Color primaryText(BuildContext context) => tokens(context).primaryText;

  static Color secondaryText(BuildContext context) {
    return tokens(context).secondaryText;
  }

  static Color tagBackground(BuildContext context) {
    return tokens(context).tagBackground;
  }

  static Color border(BuildContext context) => tokens(context).surfaceBorder;

  static Color selected(BuildContext context) {
    return tokens(context).selectedBackground;
  }

  static Color running(BuildContext context) {
    return tokens(context).runningBackground;
  }

  static Color buttonStop(BuildContext context) {
    return tokens(context).stopButtonBackground;
  }

  static Color buttonStopForeground(BuildContext context) {
    return tokens(context).stopButtonForeground;
  }

  static Color sectionTitle(BuildContext context) {
    return tokens(context).sectionTitle;
  }

  static Color interactiveText(BuildContext context) {
    return tokens(context).interactiveText;
  }

  static Color formTitle(BuildContext context) {
    return interactiveText(context);
  }

  static Color secondaryButtonBackground(BuildContext context) {
    return tokens(context).secondaryButtonBackground;
  }

  static Color secondaryButtonForeground(BuildContext context) {
    return tokens(context).secondaryButtonForeground;
  }
}
