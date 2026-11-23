import 'dart:math' as math;

import 'package:flutter/material.dart';

/// "Mystic night" — identité visuelle TalkTome (voir claude.md, Brand identity).
/// Violet profond / indigo, accents or doux, rouge réservé au signet de Tomy
/// et aux actions clés. Sombre d'abord ; le thème clair est une variante
/// "parchemin" avec les mêmes accents.
class TT {
  TT._();

  // Nuit
  static const night = Color(0xFF120B2E);
  static const nightDeep = Color(0xFF0C0722);
  static const indigo = Color(0xFF22165A);
  static const indigoLight = Color(0xFF3D2A8C);
  static const surface = Color(0xFF1C1342);
  static const surfaceHigh = Color(0xFF281C58);
  static const surfaceHighest = Color(0xFF33256B);
  static const outline = Color(0xFF4A3A8A);

  // Tomy
  static const purple = Color(0xFF8A5CE0);
  static const purpleSoft = Color(0xFFB79CFF);
  static const purpleDeep = Color(0xFF4A2896);

  // Or
  static const gold = Color(0xFFF2C766);
  static const goldLight = Color(0xFFFFE29A);
  static const goldDeep = Color(0xFFB9822A);

  // Signet (rouge)
  static const signet = Color(0xFFD62F48);
  static const signetDeep = Color(0xFF8E1530);

  // Texte
  static const ink = Color(0xFFF1ECFF);
  static const inkMuted = Color(0xFFADA3D6);

  // Parchemin (clair)
  static const parchment = Color(0xFFF7F1E3);
  static const parchmentHigh = Color(0xFFEFE5CF);
  static const parchmentInk = Color(0xFF2A1A52);

  static const nightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [indigo, night, nightDeep],
    stops: [0.0, 0.55, 1.0],
  );

  static const parchmentGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFBF7EE), parchment, Color(0xFFEFE4CC)],
  );

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldLight, gold, goldDeep],
  );

  static const signetGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE8475E), signet, signetDeep],
  );

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Or en sombre, violet profond en clair (l'or manque de contraste sur crème).
  static Color accent(BuildContext context) =>
      isDark(context) ? gold : purpleDeep;
}

ThemeData buildTalkTomeTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;

  final scheme = dark
      ? const ColorScheme(
          brightness: Brightness.dark,
          primary: TT.purpleSoft,
          onPrimary: TT.nightDeep,
          primaryContainer: TT.purpleDeep,
          onPrimaryContainer: TT.ink,
          secondary: TT.gold,
          onSecondary: TT.nightDeep,
          secondaryContainer: Color(0xFF4A3A1A),
          onSecondaryContainer: TT.goldLight,
          tertiary: TT.signet,
          onTertiary: Colors.white,
          tertiaryContainer: TT.signetDeep,
          onTertiaryContainer: Color(0xFFFFDADF),
          error: Color(0xFFFF8A9A),
          onError: TT.nightDeep,
          surface: TT.surface,
          onSurface: TT.ink,
          onSurfaceVariant: TT.inkMuted,
          surfaceContainerLowest: TT.nightDeep,
          surfaceContainerLow: TT.night,
          surfaceContainer: TT.surface,
          surfaceContainerHigh: TT.surfaceHigh,
          surfaceContainerHighest: TT.surfaceHighest,
          outline: TT.outline,
          outlineVariant: Color(0xFF34286A),
          inverseSurface: TT.ink,
          onInverseSurface: TT.night,
          inversePrimary: TT.purpleDeep,
          shadow: Colors.black,
          scrim: Colors.black,
        )
      : const ColorScheme(
          brightness: Brightness.light,
          primary: TT.purpleDeep,
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFE6DAFF),
          onPrimaryContainer: TT.parchmentInk,
          secondary: TT.goldDeep,
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFFBE6B5),
          onSecondaryContainer: Color(0xFF4A3410),
          tertiary: TT.signet,
          onTertiary: Colors.white,
          tertiaryContainer: Color(0xFFFFDADF),
          onTertiaryContainer: TT.signetDeep,
          error: Color(0xFFB3261E),
          onError: Colors.white,
          surface: TT.parchment,
          onSurface: TT.parchmentInk,
          onSurfaceVariant: Color(0xFF66598C),
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: Color(0xFFFBF7EE),
          surfaceContainer: TT.parchmentHigh,
          surfaceContainerHigh: Color(0xFFE9DDC2),
          surfaceContainerHighest: Color(0xFFE2D4B6),
          outline: Color(0xFFB9A98A),
          outlineVariant: Color(0xFFDCCFB3),
          inverseSurface: TT.night,
          onInverseSurface: TT.ink,
          inversePrimary: TT.purpleSoft,
          shadow: Colors.black,
          scrim: Colors.black,
        );

  final accent = dark ? TT.gold : TT.purpleDeep;
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final text = base.textTheme.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  return base.copyWith(
    scaffoldBackgroundColor: dark ? TT.night : TT.parchment,
    canvasColor: scheme.surface,
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge?.copyWith(letterSpacing: 0.4),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: accent,
      ),
    ),
    bottomAppBarTheme: BottomAppBarThemeData(
      color: dark ? TT.nightDeep : const Color(0xFFF1E8D4),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: accent.withOpacity(0.35)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: scheme.surfaceContainer,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? TT.surfaceHighest : TT.parchmentInk,
      contentTextStyle: const TextStyle(color: TT.ink),
      actionTextColor: TT.gold,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accent,
      linearTrackColor: accent.withOpacity(0.18),
      circularTrackColor: Colors.transparent,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: accent,
      thumbColor: accent,
      inactiveTrackColor: accent.withOpacity(0.2),
      overlayColor: accent.withOpacity(0.12),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? (dark ? TT.nightDeep : Colors.white) : null),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? accent : null),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TT.signet,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: accent,
        elevation: 0,
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: accent.withOpacity(0.6)),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: TT.signet,
      foregroundColor: Colors.white,
      shape: CircleBorder(),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: accent.withOpacity(0.25),
      side: BorderSide(color: scheme.outlineVariant),
      shape: const StadiumBorder(),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent, width: 1.6),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: accent,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: accent,
      dividerColor: Colors.transparent,
    ),
  );
}

/// Fond "nuit étoilée" (ou parchemin en clair) derrière les onglets principaux.
class MysticBackdrop extends StatelessWidget {
  final Widget child;
  const MysticBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = TT.isDark(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: dark ? TT.nightGradient : TT.parchmentGradient,
      ),
      child: CustomPaint(
        painter: _StarPainter(dark: dark),
        child: child,
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  final bool dark;
  _StarPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7); // graine fixe : les étoiles ne bougent pas
    final paint = Paint();
    final count = dark ? 70 : 28;
    for (var i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = 0.6 + rnd.nextDouble() * 1.4;
      final a = dark ? 0.25 + rnd.nextDouble() * 0.5 : 0.10 + rnd.nextDouble() * 0.15;
      paint.color = (dark ? TT.goldLight : TT.goldDeep).withOpacity(a);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.dark != dark;
}

/// Section header: small gold capitals with a sparkle.
class MysticSectionHeader extends StatelessWidget {
  final String label;
  final EdgeInsets padding;
  const MysticSectionHeader({
    super.key,
    required this.label,
    this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 10),
  });

  @override
  Widget build(BuildContext context) {
    final accent = TT.accent(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent.withOpacity(0.5), accent.withOpacity(0.0)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
