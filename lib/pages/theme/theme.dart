import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/color.dart';

abstract final class AppTheme {
  static const _primarySeed = Color(0xFF2563EB);

  static ThemeData get light {
    return _build(Brightness.light, AppColorTokens.light);
  }

  static ThemeData get dark {
    return _build(Brightness.dark, AppColorTokens.dark);
  }

  static ThemeData _build(Brightness brightness, AppColorTokens colors) {
    final colorScheme =
        SeedColorScheme.fromSeeds(
          brightness: brightness,
          primaryKey: _primarySeed,
        ).copyWith(
          surface: colors.surface,
          onSurface: colors.primaryText,
          outline: colors.surfaceBorder,
          outlineVariant: colors.surfaceBorder,
        );
    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      useMaterial3: true,
      extensions: [colors],
      scaffoldBackgroundColor: colors.pageBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.primaryText,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: colors.surfaceBorder,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: colorScheme.onPrimary,
          backgroundColor: colorScheme.primary,
          disabledForegroundColor: colors.secondaryText,
          disabledBackgroundColor: colors.secondaryButtonBackground,
          shape: const StadiumBorder(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: colors.tagBackground,
        prefixIconColor: colors.secondaryText,
        suffixIconColor: colors.secondaryText,
        labelStyle: TextStyle(color: colors.secondaryText),
        floatingLabelStyle: TextStyle(color: colors.interactiveText),
        hintStyle: TextStyle(color: colors.secondaryText),
        helperStyle: TextStyle(color: colors.secondaryText),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: colors.primaryText),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.interactiveText,
        unselectedLabelColor: colors.secondaryText,
        indicatorColor: colors.interactiveText,
        dividerColor: colors.surfaceBorder,
      ),
      iconTheme: IconThemeData(color: colors.secondaryText),
    );
  }
}
