import 'package:flutter/material.dart';

import 'kalonet_colors.dart';

abstract final class KalonetSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
  static const section = 40.0;
  static const page = 20.0;
}

abstract final class KalonetRadii {
  static const sm = 8.0;
  static const md = 10.0;
  static const lg = 12.0;
  static const pill = 999.0;
}

abstract final class KalonetMotion {
  static const quick = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);
  static const curve = Curves.easeOutCubic;

  static Duration resolve(BuildContext context, Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }
}

abstract final class KalonetElevation {
  static const card = 2.0;
  static const dialog = 12.0;
}

abstract final class KalonetGradients {
  static const page = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [KalonetColors.backgroundSoft, KalonetColors.background],
  );

  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [KalonetColors.primaryBright, KalonetColors.primary],
  );

  static const surface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [KalonetColors.surfaceElevated, KalonetColors.surface],
  );
}

enum KalonetWindowSizeClass { compact, medium, expanded, large, extraLarge }

KalonetWindowSizeClass kalonetWindowSizeClassFor(double width) {
  if (width < 600) return KalonetWindowSizeClass.compact;
  if (width < 840) return KalonetWindowSizeClass.medium;
  if (width < 1200) return KalonetWindowSizeClass.expanded;
  if (width < 1600) return KalonetWindowSizeClass.large;
  return KalonetWindowSizeClass.extraLarge;
}

@immutable
final class KalonetThemeTokens extends ThemeExtension<KalonetThemeTokens> {
  const KalonetThemeTokens({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceGlass,
    required this.border,
    required this.borderPale,
    required this.brand,
    required this.brandBright,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.nutrition,
    required this.hydration,
    required this.steps,
    required this.activity,
    required this.gamification,
  });

  const KalonetThemeTokens.dark()
    : background = KalonetColors.background,
      surface = KalonetColors.surface,
      surfaceRaised = KalonetColors.surfaceElevated,
      surfaceGlass = KalonetColors.surfaceGlass,
      border = KalonetColors.border,
      borderPale = KalonetColors.borderPale,
      brand = KalonetColors.primary,
      brandBright = KalonetColors.primaryBright,
      textPrimary = KalonetColors.textPrimary,
      textSecondary = KalonetColors.textSecondary,
      textMuted = KalonetColors.textMuted,
      nutrition = KalonetColors.nutrition,
      hydration = KalonetColors.hydration,
      steps = KalonetColors.steps,
      activity = KalonetColors.activity,
      gamification = KalonetColors.gamification;

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceGlass;
  final Color border;
  final Color borderPale;
  final Color brand;
  final Color brandBright;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color nutrition;
  final Color hydration;
  final Color steps;
  final Color activity;
  final Color gamification;

  static KalonetThemeTokens of(BuildContext context) {
    return Theme.of(context).extension<KalonetThemeTokens>() ??
        const KalonetThemeTokens.dark();
  }

  @override
  KalonetThemeTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceGlass,
    Color? border,
    Color? borderPale,
    Color? brand,
    Color? brandBright,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? nutrition,
    Color? hydration,
    Color? steps,
    Color? activity,
    Color? gamification,
  }) {
    return KalonetThemeTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceGlass: surfaceGlass ?? this.surfaceGlass,
      border: border ?? this.border,
      borderPale: borderPale ?? this.borderPale,
      brand: brand ?? this.brand,
      brandBright: brandBright ?? this.brandBright,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      nutrition: nutrition ?? this.nutrition,
      hydration: hydration ?? this.hydration,
      steps: steps ?? this.steps,
      activity: activity ?? this.activity,
      gamification: gamification ?? this.gamification,
    );
  }

  @override
  KalonetThemeTokens lerp(
    covariant ThemeExtension<KalonetThemeTokens>? other,
    double t,
  ) {
    if (other is! KalonetThemeTokens) return this;
    return KalonetThemeTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceGlass: Color.lerp(surfaceGlass, other.surfaceGlass, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderPale: Color.lerp(borderPale, other.borderPale, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandBright: Color.lerp(brandBright, other.brandBright, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      nutrition: Color.lerp(nutrition, other.nutrition, t)!,
      hydration: Color.lerp(hydration, other.hydration, t)!,
      steps: Color.lerp(steps, other.steps, t)!,
      activity: Color.lerp(activity, other.activity, t)!,
      gamification: Color.lerp(gamification, other.gamification, t)!,
    );
  }
}
