import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Premium "Aurora Light" design system for WeatherGPT.
///
/// Light, airy base (so existing screens keep working) with an aurora
/// teal -> sky -> indigo accent, glass surfaces, and tight, confident
/// typography. All premium surfaces should use these tokens instead of
/// hard-coded greys, so the look stays consistent across the app.
class PremiumColors {
  static const Color mist = Color(0xFFF6F8FB);
  static const Color ink = Color(0xFF0B1220);
  static const Color slate = Color(0xFF475569);
  static const Color muted = Color(0xFF94A3B8);
  static const Color card = Colors.white;
  static const Color line = Color(0xFFE6EBF2);

  static const Color teal = Color(0xFF0D9488);
  static const Color sky = Color(0xFF0284C7);
  static const Color indigo = Color(0xFF4F46E5);
  static const Color amber = Color(0xFFF59E0B);

  static const LinearGradient accentGradient = LinearGradient(
    colors: [teal, sky, indigo],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0B1220), Color(0xFF0F2A43), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Soft aurora blobs used behind the home hero. Keep opacity low so
  /// text stays readable on a light background.
  static const List<Color> auroraBlobs = [
    Color(0xFF99F6E4),
    Color(0xFFBAE6FD),
    Color(0xFFC7D2FE),
  ];
}

class PremiumTheme {
  static ThemeData themeData() {
    const ColorScheme scheme = ColorScheme.light(
      primary: PremiumColors.teal,
      secondary: PremiumColors.sky,
      tertiary: PremiumColors.indigo,
      surface: PremiumColors.card,
      onSurface: PremiumColors.ink,
    );
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: PremiumColors.mist,
      colorScheme: scheme,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
          height: 1.05,
          color: PremiumColors.ink,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: PremiumColors.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: PremiumColors.ink,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: PremiumColors.slate,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: PremiumColors.muted,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: PremiumColors.mist,
        foregroundColor: PremiumColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Frosted-glass surface: white at 85% over a soft shadow, hairline
/// border, generous radius. Use for cards, input areas and pills.
class PremiumGlass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  const PremiumGlass({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(
            color: PremiumColors.ink.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Circular glass icon button used in top navigation bars.
class PremiumIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const PremiumIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: PremiumColors.line),
        boxShadow: [
          BoxShadow(
            color: PremiumColors.ink.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onPressed,
          child: Center(
            child: Icon(icon, size: 22, color: PremiumColors.ink),
          ),
        ),
      ),
    );
  }
}

/// Small gradient pill used for quick actions on the home hero.
class PremiumActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const PremiumActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: PremiumColors.line),
            boxShadow: [
              BoxShadow(
                color: PremiumColors.ink.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) =>
                    PremiumColors.accentGradient.createShader(bounds),
                child: Icon(icon, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PremiumColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aurora background: three soft colour blobs on the mist base.
/// Decorative only — place it behind content in a Stack.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PremiumColors.auroraBlobs[0].withValues(alpha: 0.55),
            ),
          ),
        ),
        Positioned(
          top: 120,
          left: -90,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PremiumColors.auroraBlobs[1].withValues(alpha: 0.5),
            ),
          ),
        ),
        Positioned(
          bottom: -40,
          right: 40,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PremiumColors.auroraBlobs[2].withValues(alpha: 0.45),
            ),
          ),
        ),
      ],
    );
  }
}

/// Gradient-filled circular button (send / primary actions).
class PremiumGradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double size;

  const PremiumGradientButton({
    super.key,
    required this.child,
    required this.onTap,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: PremiumColors.accentGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: PremiumColors.sky.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(size / 2),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}
