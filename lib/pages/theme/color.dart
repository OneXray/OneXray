import 'package:flutter/material.dart';

class AppColorTokens extends ThemeExtension<AppColorTokens> {
  final Color pageBackground;
  final Color surface;
  final Color surfaceBorder;
  final Color primaryText;
  final Color secondaryText;
  final Color tagBackground;
  final Color selectedBackground;
  final Color runningBackground;
  final Color stopButtonBackground;
  final Color stopButtonForeground;
  final Color sectionTitle;
  final Color interactiveText;
  final Color secondaryButtonBackground;
  final Color secondaryButtonForeground;

  const AppColorTokens({
    required this.pageBackground,
    required this.surface,
    required this.surfaceBorder,
    required this.primaryText,
    required this.secondaryText,
    required this.tagBackground,
    required this.selectedBackground,
    required this.runningBackground,
    required this.stopButtonBackground,
    required this.stopButtonForeground,
    required this.sectionTitle,
    required this.interactiveText,
    required this.secondaryButtonBackground,
    required this.secondaryButtonForeground,
  });

  static const light = AppColorTokens(
    pageBackground: Color(0xFFF6F7F9),
    surface: Color(0xFFFFFFFF),
    surfaceBorder: Color(0xFFDADDE3),
    primaryText: Color(0xFF202124),
    secondaryText: Color(0xFF69717D),
    tagBackground: Color(0xFFEEF2F6),
    selectedBackground: Color(0xFFC7DCFF),
    runningBackground: Color(0xFFC5EFD2),
    stopButtonBackground: Color(0xFFE5E7EB),
    stopButtonForeground: Color(0xFF374151),
    sectionTitle: Color(0xFF1D4ED8),
    interactiveText: Color(0xFF2563EB),
    secondaryButtonBackground: Color(0xFFEFF3F8),
    secondaryButtonForeground: Color(0xFF1D4ED8),
  );

  static const dark = AppColorTokens(
    pageBackground: Color(0xFF101214),
    surface: Color(0xFF1B1F24),
    surfaceBorder: Color(0xFF343A44),
    primaryText: Color(0xFFF4F6F8),
    secondaryText: Color(0xFFA7B0BD),
    tagBackground: Color(0xFF252B33),
    selectedBackground: Color(0xFF214A7A),
    runningBackground: Color(0xFF235A3A),
    stopButtonBackground: Color(0xFF303741),
    stopButtonForeground: Color(0xFFD7DDE5),
    sectionTitle: Color(0xFF93C5FD),
    interactiveText: Color(0xFF93C5FD),
    secondaryButtonBackground: Color(0xFF242B35),
    secondaryButtonForeground: Color(0xFF93C5FD),
  );

  static AppColorTokens fallback(Brightness brightness) {
    return brightness == Brightness.light ? light : dark;
  }

  @override
  AppColorTokens copyWith({
    Color? pageBackground,
    Color? surface,
    Color? surfaceBorder,
    Color? primaryText,
    Color? secondaryText,
    Color? tagBackground,
    Color? selectedBackground,
    Color? runningBackground,
    Color? stopButtonBackground,
    Color? stopButtonForeground,
    Color? sectionTitle,
    Color? interactiveText,
    Color? secondaryButtonBackground,
    Color? secondaryButtonForeground,
  }) {
    return AppColorTokens(
      pageBackground: pageBackground ?? this.pageBackground,
      surface: surface ?? this.surface,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      tagBackground: tagBackground ?? this.tagBackground,
      selectedBackground: selectedBackground ?? this.selectedBackground,
      runningBackground: runningBackground ?? this.runningBackground,
      stopButtonBackground: stopButtonBackground ?? this.stopButtonBackground,
      stopButtonForeground: stopButtonForeground ?? this.stopButtonForeground,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      interactiveText: interactiveText ?? this.interactiveText,
      secondaryButtonBackground:
          secondaryButtonBackground ?? this.secondaryButtonBackground,
      secondaryButtonForeground:
          secondaryButtonForeground ?? this.secondaryButtonForeground,
    );
  }

  @override
  AppColorTokens lerp(ThemeExtension<AppColorTokens>? other, double t) {
    if (other is! AppColorTokens) {
      return this;
    }
    return AppColorTokens(
      pageBackground: _lerp(pageBackground, other.pageBackground, t),
      surface: _lerp(surface, other.surface, t),
      surfaceBorder: _lerp(surfaceBorder, other.surfaceBorder, t),
      primaryText: _lerp(primaryText, other.primaryText, t),
      secondaryText: _lerp(secondaryText, other.secondaryText, t),
      tagBackground: _lerp(tagBackground, other.tagBackground, t),
      selectedBackground: _lerp(
        selectedBackground,
        other.selectedBackground,
        t,
      ),
      runningBackground: _lerp(runningBackground, other.runningBackground, t),
      stopButtonBackground: _lerp(
        stopButtonBackground,
        other.stopButtonBackground,
        t,
      ),
      stopButtonForeground: _lerp(
        stopButtonForeground,
        other.stopButtonForeground,
        t,
      ),
      sectionTitle: _lerp(sectionTitle, other.sectionTitle, t),
      interactiveText: _lerp(interactiveText, other.interactiveText, t),
      secondaryButtonBackground: _lerp(
        secondaryButtonBackground,
        other.secondaryButtonBackground,
        t,
      ),
      secondaryButtonForeground: _lerp(
        secondaryButtonForeground,
        other.secondaryButtonForeground,
        t,
      ),
    );
  }

  static Color _lerp(Color begin, Color end, double t) {
    return Color.lerp(begin, end, t) ?? end;
  }
}

class ColorManager {
  static AppColorTokens tokens(BuildContext context) {
    return Theme.of(context).extension<AppColorTokens>() ??
        AppColorTokens.fallback(Theme.of(context).brightness);
  }

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
