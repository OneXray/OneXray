import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

abstract final class AppTheme {
  static ThemeData get light =>
      _build(brightness: Brightness.light, colors: AppColorTokens.light);

  static ThemeData get dark =>
      _build(brightness: Brightness.dark, colors: AppColorTokens.dark);

  static ShadThemeData shad(Brightness brightness) {
    return ShadThemeData(
      brightness: brightness,
      colorScheme: shadColorScheme(brightness),
      radius: const BorderRadius.all(Radius.circular(8)),
      textTheme: AppTypography.shad,
    );
  }

  static ShadColorScheme shadColorScheme(Brightness brightness) {
    final palette = AppColorTokens.fallback(brightness).palette;
    return ShadColorScheme(
      background: palette.background,
      foreground: palette.foreground,
      card: palette.card,
      cardForeground: palette.cardForeground,
      popover: palette.popover,
      popoverForeground: palette.popoverForeground,
      primary: palette.primary,
      primaryForeground: palette.primaryForeground,
      secondary: palette.secondary,
      secondaryForeground: palette.secondaryForeground,
      muted: palette.muted,
      mutedForeground: palette.mutedForeground,
      accent: palette.accent,
      accentForeground: palette.accentForeground,
      destructive: palette.destructive,
      destructiveForeground: palette.destructiveForeground,
      border: palette.border,
      input: palette.input,
      ring: palette.ring,
      selection: palette.selection,
      custom: {
        'chart1': palette.chart1,
        'chart2': palette.chart2,
        'chart3': palette.chart3,
        'chart4': palette.chart4,
        'chart5': palette.chart5,
        'running': palette.running,
        'runningText': palette.runningText,
        'restarting': palette.restarting,
        'restartingText': palette.restartingText,
      },
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required AppColorTokens colors,
  }) {
    final palette = colors.palette;
    final inversePalette = brightness == Brightness.light
        ? AppPalette.dark
        : AppPalette.light;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: palette.primary,
      onPrimary: palette.primaryForeground,
      primaryContainer: palette.accent,
      onPrimaryContainer: palette.accentForeground,
      primaryFixed: palette.primary,
      primaryFixedDim: palette.accent,
      onPrimaryFixed: palette.primaryForeground,
      onPrimaryFixedVariant: palette.accentForeground,
      secondary: palette.secondary,
      onSecondary: palette.secondaryForeground,
      secondaryContainer: palette.muted,
      onSecondaryContainer: palette.secondaryForeground,
      secondaryFixed: palette.secondary,
      secondaryFixedDim: palette.muted,
      onSecondaryFixed: palette.secondaryForeground,
      onSecondaryFixedVariant: palette.mutedForeground,
      tertiary: palette.running,
      onTertiary: palette.runningForeground,
      tertiaryContainer: palette.runningSurface,
      onTertiaryContainer: palette.foreground,
      error: palette.destructive,
      onError: palette.destructiveForeground,
      errorContainer: palette.destructiveSurface,
      onErrorContainer: palette.destructive,
      surface: palette.card,
      onSurface: palette.foreground,
      surfaceDim: palette.background,
      surfaceBright: palette.card,
      surfaceContainerLowest: palette.card,
      surfaceContainerLow: palette.background,
      surfaceContainer: palette.secondary,
      surfaceContainerHigh: palette.muted,
      surfaceContainerHighest: palette.accent,
      onSurfaceVariant: palette.mutedForeground,
      outline: palette.border,
      outlineVariant: palette.input,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: palette.foreground,
      onInverseSurface: palette.background,
      inversePrimary: inversePalette.primary,
      surfaceTint: Colors.transparent,
    );
    final roundedRectangle = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    final borderedRectangle = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: palette.border),
    );
    final textTheme = AppTypography.material.apply(
      bodyColor: palette.foreground,
      displayColor: palette.foreground,
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: AppFontFamily.sans,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: [colors],
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      disabledColor: palette.mutedForeground.withValues(alpha: 0.5),
      focusColor: palette.ring.withValues(alpha: 0.18),
      hoverColor: palette.accent.withValues(alpha: 0.72),
      highlightColor: palette.accent,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.primary,
        selectionColor: palette.selection,
        selectionHandleColor: palette.primary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.header,
        foregroundColor: palette.foreground,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 66,
        titleSpacing: 20,
        actionsPadding: const EdgeInsetsDirectional.only(end: 12),
        titleTextStyle: AppTypography.pageTitle.copyWith(
          color: palette.foreground,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: palette.header,
          statusBarIconBrightness: brightness == Brightness.light
              ? Brightness.dark
              : Brightness.light,
          statusBarBrightness: brightness,
        ),
        shape: Border(bottom: BorderSide(color: palette.border, width: 1)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: palette.card,
        modalBarrierColor: Colors.black.withValues(alpha: 0.42),
        shape: roundedRectangle,
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.07),
        elevation: 0,
        shape: borderedRectangle,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.popover,
        surfaceTintColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.42),
        shape: borderedRectangle,
        titleTextStyle: AppTypography.panelTitle.copyWith(
          color: palette.popoverForeground,
        ),
        contentTextStyle: AppTypography.rowValue.copyWith(
          color: palette.mutedForeground,
        ),
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: palette.border,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: palette.primaryForeground,
          backgroundColor: palette.primary,
          disabledForegroundColor: palette.mutedForeground,
          disabledBackgroundColor: palette.secondary,
          elevation: 0,
          minimumSize: const Size(40, 40),
          shape: roundedRectangle,
          textStyle: AppTypography.control,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: palette.primaryForeground,
          backgroundColor: palette.primary,
          disabledForegroundColor: palette.mutedForeground,
          disabledBackgroundColor: palette.secondary,
          minimumSize: const Size(40, 40),
          shape: roundedRectangle,
          textStyle: AppTypography.control,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.foreground,
          backgroundColor: Colors.transparent,
          disabledForegroundColor: palette.mutedForeground,
          minimumSize: const Size(40, 40),
          side: BorderSide(color: palette.input),
          shape: roundedRectangle,
          textStyle: AppTypography.control,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          disabledForegroundColor: palette.mutedForeground,
          minimumSize: const Size(40, 40),
          shape: roundedRectangle,
          textStyle: AppTypography.control,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: palette.foreground,
          disabledForegroundColor: palette.mutedForeground,
          minimumSize: const Size(40, 40),
          shape: roundedRectangle,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.transparent,
        prefixIconColor: palette.mutedForeground,
        suffixIconColor: palette.mutedForeground,
        labelStyle: AppTypography.rowValue.copyWith(
          color: palette.mutedForeground,
        ),
        floatingLabelStyle: AppTypography.rowValue.copyWith(
          color: palette.primary,
        ),
        hintStyle: AppTypography.rowValue.copyWith(
          color: palette.mutedForeground,
        ),
        helperStyle: AppTypography.supporting.copyWith(
          color: palette.mutedForeground,
        ),
        errorStyle: AppTypography.supporting.copyWith(
          color: palette.destructive,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: palette.input),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: palette.input),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: palette.ring),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: palette.destructive),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: palette.destructive),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(palette.popover),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: 0.12),
          ),
          elevation: const WidgetStatePropertyAll(6),
          side: WidgetStatePropertyAll(BorderSide(color: palette.border)),
          shape: WidgetStatePropertyAll(roundedRectangle),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(AppTypography.rowValue),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? palette.mutedForeground
                : palette.popoverForeground,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? palette.mutedForeground.withValues(alpha: 0.5)
                : palette.mutedForeground,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.hovered)
                ? palette.accent
                : Colors.transparent,
          ),
          shape: WidgetStatePropertyAll(roundedRectangle),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.popover,
        surfaceTintColor: Colors.transparent,
        textStyle: AppTypography.rowValue.copyWith(
          color: palette.popoverForeground,
        ),
        shape: borderedRectangle,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: AppTypography.rowValue.copyWith(color: palette.foreground),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(palette.popover),
          side: WidgetStatePropertyAll(BorderSide(color: palette.border)),
          shape: WidgetStatePropertyAll(roundedRectangle),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: palette.input),
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: palette.primary,
        unselectedLabelColor: palette.mutedForeground,
        labelStyle: AppTypography.control,
        unselectedLabelStyle: AppTypography.control,
        indicatorColor: palette.primary,
        dividerColor: palette.border,
        overlayColor: WidgetStatePropertyAll(
          palette.accent.withValues(alpha: 0.72),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.sidebar,
        surfaceTintColor: Colors.transparent,
        indicatorColor: palette.sidebarAccent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? palette.sidebarPrimary
                : palette.mutedForeground,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTypography.supporting.copyWith(
            color: states.contains(WidgetState.selected)
                ? palette.sidebarAccentForeground
                : palette.mutedForeground,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: palette.sidebar,
        indicatorColor: palette.sidebarAccent,
        selectedIconTheme: IconThemeData(color: palette.sidebarPrimary),
        unselectedIconTheme: IconThemeData(color: palette.mutedForeground),
        selectedLabelTextStyle: AppTypography.supporting.copyWith(
          color: palette.sidebarAccentForeground,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: AppTypography.supporting.copyWith(
          color: palette.mutedForeground,
          fontWeight: FontWeight.w500,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.primaryForeground
              : palette.card,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.primary
              : palette.input,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(palette.primaryForeground),
        side: BorderSide(color: palette.input),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.primary
              : palette.mutedForeground,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.muted,
        selectedColor: palette.accent,
        disabledColor: palette.muted.withValues(alpha: 0.5),
        labelStyle: AppTypography.supporting.copyWith(
          color: palette.foreground,
        ),
        secondaryLabelStyle: AppTypography.supporting.copyWith(
          color: palette.accentForeground,
        ),
        side: BorderSide(color: palette.border),
        shape: roundedRectangle,
      ),
      listTileTheme: ListTileThemeData(
        textColor: palette.foreground,
        iconColor: palette.mutedForeground,
        selectedColor: palette.primary,
        selectedTileColor: palette.selectedSurface,
        titleTextStyle: AppTypography.rowTitle.copyWith(
          color: palette.foreground,
        ),
        subtitleTextStyle: AppTypography.supporting.copyWith(
          color: palette.mutedForeground,
        ),
        leadingAndTrailingTextStyle: AppTypography.supporting.copyWith(
          color: palette.mutedForeground,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: palette.popover,
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        textStyle: AppTypography.supporting.copyWith(
          color: palette.popoverForeground,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.foreground,
        contentTextStyle: AppTypography.rowValue.copyWith(
          color: palette.background,
        ),
        actionTextColor: inversePalette.primary,
        shape: roundedRectangle,
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
        linearTrackColor: palette.muted,
        circularTrackColor: palette.muted,
      ),
      iconTheme: IconThemeData(color: palette.mutedForeground),
    );
  }
}
