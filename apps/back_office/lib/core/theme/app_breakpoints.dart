/// UI-802 Design System — responsive breakpoints.
///
/// Back Office is desktop-first: primary target 1280 px and up, adaptive down
/// to phones (< 600 px) so the owner can run the restaurant from one.
abstract final class AppBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1280;

  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < tablet;

  /// Compact layout (working minimum 1024 px — tablet 1024x768).
  static bool isDesktopCompact(double width) =>
      width >= tablet && width < desktop;

  /// Primary layout (1280 px and up).
  static bool isDesktop(double width) => width >= desktop;
}
