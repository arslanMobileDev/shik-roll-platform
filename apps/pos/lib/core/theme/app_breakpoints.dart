/// UI-802 Design System — responsive breakpoints.
///
/// POS cashier screen is desktop-first: primary target 1280 px,
/// working minimum 1024 px, adaptive fallback for tablets below.
abstract final class AppBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1280;

  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < tablet;

  /// Compact cashier layout (working minimum 1024 px).
  static bool isDesktopCompact(double width) =>
      width >= tablet && width < desktop;

  /// Primary cashier layout (1280 px and up).
  static bool isDesktop(double width) => width >= desktop;
}
