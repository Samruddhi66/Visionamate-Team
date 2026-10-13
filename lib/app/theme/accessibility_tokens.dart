/// Accessibility-First Design Tokens for VisionMate 2.0
/// Enforces WCAG 2.1 touch target sizes, spacing, and layout invariants.
class AccessibilityTokens {
  AccessibilityTokens._();

  /// Minimum interactive target size per WCAG 2.1 AA (48x48)
  static const double minTouchTarget = 48.0;

  /// Primary action target size (56-64 logical pixels) for easy tactile/motor reach
  static const double primaryActionMinSize = 64.0;

  /// Large hero voice button target height
  static const double heroActionHeight = 76.0;

  /// Feature grid card minimum height
  static const double featureCardMinHeight = 110.0;

  /// Spacing Tokens
  static const double spaceXS = 4.0;
  static const double spaceS = 8.0;
  static const double spaceM = 16.0;
  static const double spaceL = 24.0;
  static const double spaceXL = 32.0;

  /// Radii
  static const double radiusS = 12.0;
  static const double radiusM = 18.0;
  static const double radiusL = 24.0;
  static const double radiusPill = 999.0;

  /// Focus Border Width (for keyboard / switch access)
  static const double focusBorderWidth = 3.0;

  /// Maximum allowed font scale multiplier to prevent clipping while allowing large text
  static const double maxFontScaleFactor = 2.5;
  static const double minFontScaleFactor = 1.0;
}
