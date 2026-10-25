import 'package:flutter/material.dart';

const copper = Color(0xFFA85E3E);

ThemeData bitreeTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: copper, brightness: brightness)
      .copyWith(
        primary: dark ? const Color(0xFFE5AE8F) : copper,
        surface: dark ? const Color(0xFF17191C) : const Color(0xFFF8F9FB),
        surfaceContainerLow: dark ? const Color(0xFF1E2125) : Colors.white,
        surfaceContainer: dark
            ? const Color(0xFF282C31)
            : const Color(0xFFF0F2F5),
        outlineVariant: dark
            ? const Color(0xFF34383F)
            : const Color(0xFFE2E5E9),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamilyFallback: const [
      'Noto Sans CJK SC',
      'Microsoft YaHei',
      'PingFang SC',
    ],
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 500),
    ),
  );
}

({Color fill, Color text, Color accent}) courseColors(
  BuildContext context,
  int index,
) {
  const light = [
    (0xFFD9F0E2, 0xFF254D35, 0xFF5C9772),
    (0xFFF7E0D1, 0xFF79442C, 0xFFB57652),
    (0xFFDDE9FF, 0xFF304F7A, 0xFF6C92C7),
    (0xFFE9E0FA, 0xFF60447F, 0xFF9773BF),
    (0xFFF6EAC5, 0xFF705623, 0xFFB79B4B),
    (0xFFD7EFEF, 0xFF285E61, 0xFF589D9F),
  ];
  const dark = [
    (0xFF2D3C2D, 0xFFD0DFCA, 0xFF93AE86),
    (0xFF463329, 0xFFF0D0B9, 0xFFC69670),
    (0xFF293B4E, 0xFFCADCF1, 0xFF8DADD1),
    (0xFF3C3046, 0xFFE3D1F0, 0xFFB59DC8),
    (0xFF403B28, 0xFFE8DDAE, 0xFFC1AB6A),
    (0xFF253F39, 0xFFBFE1D7, 0xFF8BB8A8),
  ];
  final colors = (Theme.of(context).brightness == Brightness.dark
      ? dark
      : light)[index];
  return (
    fill: Color(colors.$1),
    text: Color(colors.$2),
    accent: Color(colors.$3),
  );
}
