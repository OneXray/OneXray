/// Shared logical-pixel values mapped from the approved prototype theme.
/// Keep platform safe areas and text scaling outside these constants.
abstract final class AppLayout {
  static const mobileBreakpoint = 720.0;
  static const compactDesktopBreakpoint = 900.0;
  static const desktopSidebarWidth = 225.0;
  static const compactSidebarWidth = 190.0;
  static const standardMaxWidth = 1120.0;
  static const contentBreakpoint = 840.0;
  static const mobileHeaderHeight = 61.0;
  static const pageActionMinHeight = 72.0;
  static const mobilePageActionMinHeight = 64.0;
  static const pageActionButtonMinHeight = 46.0;
  static const pageActionButtonMinWidth = 150.0;
  static const buttonMinHeight = 40.0;
  static const mobileButtonMinHeight = 42.0;
}

abstract final class AppSpacing {
  static const page = 28.0;
  static const mobilePage = 14.0;
  static const controlHorizontal = 12.0;
  static const controlVertical = 10.0;
  static const actionGap = 10.0;
  static const actionRunGap = 8.0;
}

abstract final class AppRadii {
  static const card = 8.0;
  static const control = 7.0;
  static const compact = 6.0;
  static const chip = 5.0;
  static const indicator = 3.0;
  static const pill = 999.0;
}
