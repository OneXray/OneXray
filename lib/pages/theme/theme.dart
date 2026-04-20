import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/color.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final ColorScheme schemeLight = SeedColorScheme.fromSeeds(
      brightness: Brightness.light,
      primaryKey: Colors.blue,
    );
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: schemeLight,
      useMaterial3: true,
      scaffoldBackgroundColor: ColorManager.scaffoldBackground(
        Brightness.light,
      ),
      dividerTheme: DividerThemeData(space: 1),
    );
  }

  static ThemeData get dark {
    final ColorScheme schemeLight = SeedColorScheme.fromSeeds(
      brightness: Brightness.dark,
      primaryKey: Colors.blue,
    );
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: schemeLight,
      useMaterial3: true,
      scaffoldBackgroundColor: ColorManager.scaffoldBackground(Brightness.dark),
      dividerTheme: DividerThemeData(space: 1),
    );
  }
}
