import 'package:flutter/material.dart';

/// Colors outside ColorScheme (tokens from the oCamera mockup).
class OcamColors extends ThemeExtension<OcamColors> {
  final Color surface2;
  final Color surface3;
  final Color outlineStrong;
  final Color muted;
  final Color online;
  final Color inUse;
  final Color offline;
  final Color accentContainer;
  final Color onAccentContainer;
  final Color hangUp;

  const OcamColors({
    required this.surface2,
    required this.surface3,
    required this.outlineStrong,
    required this.muted,
    required this.online,
    required this.inUse,
    required this.offline,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.hangUp,
  });

  static const dark = OcamColors(
    surface2: Color(0xFF1D2226),
    surface3: Color(0xFF262C31),
    outlineStrong: Color(0xFF3D454C),
    muted: Color(0xFFA3ACB3),
    online: Color(0xFF3FB950),
    inUse: Color(0xFFE3A008),
    offline: Color(0xFF6B747B),
    accentContainer: Color(0xFF11403B),
    onAccentContainer: Color(0xFFA8F0E8),
    hangUp: Color(0xFFC5221F),
  );

  static const light = OcamColors(
    surface2: Color(0xFFE9EEF0),
    surface3: Color(0xFFDDE3E6),
    outlineStrong: Color(0xFFB9C2C7),
    muted: Color(0xFF4E575E),
    online: Color(0xFF1E8E3E),
    inUse: Color(0xFFB26A00),
    offline: Color(0xFF8A9399),
    accentContainer: Color(0xFFCDEFEA),
    onAccentContainer: Color(0xFF00201D),
    hangUp: Color(0xFFC5221F),
  );

  @override
  OcamColors copyWith() => this;

  @override
  OcamColors lerp(ThemeExtension<OcamColors>? other, double t) =>
      t < 0.5 ? this : (other as OcamColors? ?? this);
}

extension OcamTheme on BuildContext {
  OcamColors get oc => Theme.of(this).extension<OcamColors>()!;
}

class AppTheme {
  /// Translucent background of the bars laid over the video.
  static const videoChrome = Color(0x9E0A0C0E);

  static ThemeData get dark => _build(
        const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFF4FD1C5),
          onPrimary: Color(0xFF00201D),
          secondary: Color(0xFF4FD1C5),
          onSecondary: Color(0xFF00201D),
          error: Color(0xFFFFB4AB),
          onError: Color(0xFF410E0B),
          errorContainer: Color(0xFF4A1C18),
          onErrorContainer: Color(0xFFFFDAD6),
          surface: Color(0xFF161A1D),
          onSurface: Color(0xFFE6E9EB),
          outline: Color(0xFF2A3136),
        ),
        const Color(0xFF0F1214),
        OcamColors.dark,
      );

  static ThemeData get light => _build(
        const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF00796E),
          onPrimary: Colors.white,
          secondary: Color(0xFF00796E),
          onSecondary: Colors.white,
          error: Color(0xFFB3261E),
          onError: Colors.white,
          errorContainer: Color(0xFFFCE4E2),
          onErrorContainer: Color(0xFF410E0B),
          surface: Colors.white,
          onSurface: Color(0xFF14181B),
          outline: Color(0xFFD5DCDF),
        ),
        const Color(0xFFF5F7F8),
        OcamColors.light,
      );

  static ThemeData _build(ColorScheme cs, Color bg, OcamColors oc) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c, width: w),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: bg,
      extensions: [oc],
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
            color: cs.onSurface, fontSize: 22, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: border(oc.outlineStrong),
        enabledBorder: border(oc.outlineStrong),
        focusedBorder: border(cs.primary, 2),
        errorBorder: border(cs.error),
        focusedErrorBorder: border(cs.error, 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
          side: BorderSide(color: oc.outlineStrong),
          textStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dividerTheme: DividerThemeData(color: cs.outline, space: 1, thickness: 1),
    );
  }
}
