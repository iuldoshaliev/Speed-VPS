// lib/ui/theme/app_theme.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import '../widgets/background_effects.dart';

/// SpeedVPS Design System
/// 4 стилизации по speedvps_design.html:
/// Emerald, Black + Green, Mono Dark, Mono Light

enum AppThemeVariant { emerald, blackGreen, monoDark, monoLight }

/// Палитра одной стилизации (зеркало CSS-переменных из дизайна)
class ThemePalette {
  const ThemePalette({
    required this.name,
    required this.bg,
    required this.bgPanel,
    required this.accent,
    required this.accentDim,
    required this.text,
    required this.textDim,
    required this.textDark,
    required this.sidebarTop,
    required this.sidebarBottom,
    required this.glassFillLight1,
    required this.glassFillLight2,
    required this.glassFillAccent,
    required this.glassFillDark,
    required this.glassBorder,
    required this.glassTopLine,
    required this.controlTop,
    required this.controlBottom,
    required this.hover,
    required this.borderSubtle,
    required this.isLight,
  });

  final String name;

  // Base
  final Color bg;
  final Color bgPanel;

  // Accent
  final Color accent;
  final Color accentDim;

  // Text
  final Color text;
  final Color textDim;
  final Color textDark;

  // Sidebar
  final Color sidebarTop;
  final Color sidebarBottom;

  // Liquid glass
  final Color glassFillLight1;
  final Color glassFillLight2;
  final Color glassFillAccent;
  final Color glassFillDark;
  final Color glassBorder;
  final Color glassTopLine;

  // Controls (play button, primary buttons)
  final Color controlTop;
  final Color controlBottom;

  // Misc
  final Color hover;
  final Color borderSubtle;
  final bool isLight;
}

/// Пресеты 4 стилизаций из speedvps_design.html
class ThemePalettes {
  static const ThemePalette emerald = ThemePalette(
    name: 'Emerald',
    bg: Color(0xFF05140c),
    bgPanel: Color(0xFF0a1f14),
    accent: Color(0xFF00ff88),
    accentDim: Color(0xFF00cc6a),
    text: Color(0xFFe8f5e9),
    textDim: Color(0xFF88b89a),
    textDark: Color(0xFF4a7a5c),
    sidebarTop: Color(0xFF0a2819),
    sidebarBottom: Color(0xFF05140c),
    glassFillLight1: Color(0x0BFFFFFF),
    glassFillLight2: Color(0x04FFFFFF),
    glassFillAccent: Color(0x0300ff88),
    glassFillDark: Color(0x38000000),
    glassBorder: Color(0x1F00ff88),
    glassTopLine: Color(0x14FFFFFF),
    controlTop: Color(0xFF0b0b0b),
    controlBottom: Color(0xFF000000),
    hover: Color(0x0F00ff88),
    borderSubtle: Color(0x0FFFFFFF),
    isLight: false,
  );

  static const ThemePalette blackGreen = ThemePalette(
    name: 'Black + Green',
    bg: Color(0xFF030303),
    bgPanel: Color(0xFF0a0a0a),
    accent: Color(0xFF00e676),
    accentDim: Color(0xFF00b85c),
    text: Color(0xFFe8e8e8),
    textDim: Color(0xFF9a9a9a),
    textDark: Color(0xFF5c5c5c),
    sidebarTop: Color(0xFF0c0c0c),
    sidebarBottom: Color(0xFF000000),
    glassFillLight1: Color(0x0BFFFFFF),
    glassFillLight2: Color(0x04FFFFFF),
    glassFillAccent: Color(0x0300e676),
    glassFillDark: Color(0x38000000),
    glassBorder: Color(0x1F00e676),
    glassTopLine: Color(0x29FFFFFF),
    controlTop: Color(0xFF0b0b0b),
    controlBottom: Color(0xFF000000),
    hover: Color(0x0AFFFFFF),
    borderSubtle: Color(0x0FFFFFFF),
    isLight: false,
  );

  static const ThemePalette monoDark = ThemePalette(
    name: 'Mono Dark',
    bg: Color(0xFF000000),
    bgPanel: Color(0xFF0a0a0a),
    accent: Color(0xFFffffff),
    accentDim: Color(0xFFd0d0d0),
    text: Color(0xFFf0f0f0),
    textDim: Color(0xFFa0a0a0),
    textDark: Color(0xFF606060),
    sidebarTop: Color(0xFF0c0c0c),
    sidebarBottom: Color(0xFF000000),
    glassFillLight1: Color(0x0BFFFFFF),
    glassFillLight2: Color(0x04FFFFFF),
    glassFillAccent: Color(0x03FFFFFF),
    glassFillDark: Color(0x38000000),
    glassBorder: Color(0x1FFFFFFF),
    glassTopLine: Color(0x29FFFFFF),
    controlTop: Color(0xFF0b0b0b),
    controlBottom: Color(0xFF000000),
    hover: Color(0x0AFFFFFF),
    borderSubtle: Color(0x0FFFFFFF),
    isLight: false,
  );

  static const ThemePalette monoLight = ThemePalette(
    name: 'Mono Light',
    bg: Color(0xFFf4f4f4),
    bgPanel: Color(0xFFffffff),
    accent: Color(0xFF000000),
    accentDim: Color(0xFF1a1a1a),
    text: Color(0xFF111111),
    textDim: Color(0xFF555555),
    textDark: Color(0xFF888888),
    sidebarTop: Color(0xFFffffff),
    sidebarBottom: Color(0xFFf0f0f0),
    glassFillLight1: Color(0xC7FFFFFF),
    glassFillLight2: Color(0x73FFFFFF),
    glassFillAccent: Color(0x04000000),
    glassFillDark: Color(0x8CFFFFFF),
    glassBorder: Color(0x1F000000),
    glassTopLine: Color(0xF2FFFFFF),
    controlTop: Color(0xFFffffff),
    controlBottom: Color(0xFFececec),
    hover: Color(0x0A000000),
    borderSubtle: Color(0x14000000),
    isLight: true,
  );

  static ThemePalette resolve(AppThemeVariant variant) {
    switch (variant) {
      case AppThemeVariant.emerald:
        return emerald;
      case AppThemeVariant.blackGreen:
        return blackGreen;
      case AppThemeVariant.monoDark:
        return monoDark;
      case AppThemeVariant.monoLight:
        return monoLight;
    }
  }

  /// Градиенты точек-переключателей (как в HTML: linear-gradient(135deg, bg 50%, accent 100%))
  static List<Color> dotColors(AppThemeVariant variant) {
    switch (variant) {
      case AppThemeVariant.emerald:
        return const [Color(0xFF05140c), Color(0xFF00ff88)];
      case AppThemeVariant.blackGreen:
        return const [Color(0xFF000000), Color(0xFF00e676)];
      case AppThemeVariant.monoDark:
        return const [Color(0xFF000000), Color(0xFFffffff)];
      case AppThemeVariant.monoLight:
        return const [Color(0xFFf4f4f4), Color(0xFF000000)];
    }
  }
}

/// Глобальные цвета приложения.
/// Все значения берутся из активной палитры и обновляются
/// при переключении стилизации (см. [ThemeService]).
class AppColors extends ChangeNotifier {
  AppColors._();

  static ThemePalette _palette = ThemePalettes.emerald;

  static ThemePalette get palette => _palette;

  static AppThemeVariant get variant {
    for (final v in AppThemeVariant.values) {
      if (identical(ThemePalettes.resolve(v), _palette)) return v;
    }
    return AppThemeVariant.emerald;
  }

  static bool get isLight => _palette.isLight;

  /// Применить стилизацию. Уведомляет слушателей (экраны перерисовываются).
  static void setVariant(AppThemeVariant value) {
    final next = ThemePalettes.resolve(value);
    if (identical(next, _palette)) return;
    _palette = next;
    _instance.notifyListeners();
  }

  static final AppColors _instance = AppColors._();

  /// Listenable для AnimatedBuilder — позволяет экранам перерисовываться
  /// при смене стилизации без потери состояния.
  static Listenable get listenable => _instance;

  // ── Backgrounds ────────────────────────────────────────────
  static Color get bg => _palette.bg;
  static Color get bgPanel => _palette.bgPanel;
  static Color get bgElevated =>
      Color.alphaBlend(_palette.accent.withOpacity(0.06), _palette.bgPanel);

  // ── Accent ─────────────────────────────────────────────────
  static Color get emerald => _palette.accent;
  static Color get accent => _palette.accent;
  static Color get emeraldDim => _palette.accentDim;
  static Color get accentDim => _palette.accentDim;
  static Color get emeraldDark =>
      HSVColor.fromColor(_palette.accent)
          .withValue(HSVColor.fromColor(_palette.accent).value * 0.35)
          .toColor();
  static Color get emeraldGlow => _palette.accent.withOpacity(0.15);
  static Color get accentSoft =>
      Color.lerp(_palette.text, _palette.accent, 0.35) ?? _palette.accent;

  // ── Glass ──────────────────────────────────────────────────
  static Color get glassBg => _palette.accent.withOpacity(0.04);
  static Color get glassBorder => _palette.glassBorder;
  static Color get glassHighlight => _palette.isLight
      ? Colors.black.withOpacity(0.08)
      : Colors.white.withOpacity(0.12);
  static Color get glassSurface => _palette.bgPanel;
  static Color get glassFillLight1 => _palette.glassFillLight1;
  static Color get glassFillLight2 => _palette.glassFillLight2;
  static Color get glassFillAccent => _palette.glassFillAccent;
  static Color get glassFillDark => _palette.glassFillDark;
  static Color get glassTopLine => _palette.glassTopLine;

  // ── Controls ───────────────────────────────────────────────
  static Color get controlTop => _palette.controlTop;
  static Color get controlBottom => _palette.controlBottom;

  // ── Text ───────────────────────────────────────────────────
  static Color get text => _palette.text;
  static Color get textDim => _palette.textDim;
  static Color get textDark => _palette.textDark;

  // ── Status ─────────────────────────────────────────────────
  static const Color disconnected = Color(0xFFff4444);
  static const Color connecting = Color(0xFFffaa00);
  static const Color connected = Color(0xFF00ff88);
  static const Color error = Color(0xFFff4444);
  static const Color warning = Color(0xFFffaa00);

  // ── Utility ────────────────────────────────────────────────
  static Color get hoverBg => _palette.hover;
  static Color get borderSubtle => _palette.borderSubtle;
  static Color get inputFill => _palette.isLight
      ? Colors.black.withOpacity(0.03)
      : Colors.white.withOpacity(0.03);
  static Color get sidebarTop => _palette.sidebarTop;
  static Color get sidebarBottom => _palette.sidebarBottom;
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double full = 999;
}

class AppTypography {
  static TextStyle get headlineLarge => TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: AppColors.text,
    decoration: TextDecoration.none,
  );

  static TextStyle get headlineMedium => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    color: AppColors.text,
    decoration: TextDecoration.none,
  );

  static TextStyle get titleLarge => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
    decoration: TextDecoration.none,
  );

  static TextStyle get titleMedium => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
    decoration: TextDecoration.none,
  );

  static TextStyle get bodyLarge => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.text,
    decoration: TextDecoration.none,
  );

  static TextStyle get bodyMedium => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textDim,
    decoration: TextDecoration.none,
  );

  static TextStyle get labelLarge => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
    decoration: TextDecoration.none,
  );

  static TextStyle get labelSmall => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textDark,
    decoration: TextDecoration.none,
  );

  static TextStyle get monoHeadline => TextStyle(
    fontSize: 42,
    fontWeight: FontWeight.w300,
    letterSpacing: 4,
    color: AppColors.text,
    fontFamily: 'JetBrainsMono',
    decoration: TextDecoration.none,
  );
}

/// breakpoints для адаптивной вёрстки
class AppBreakpoints {
  static const double mobile = 600;
  static const double tablet = 720;
  static const double desktop = 1100;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobile;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobile && width < desktop;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktop;

  static bool isWideScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= tablet;
}

/// Адаптивный каркас приложения
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.navigationItems,
    required this.bodyBuilder,
    this.selectedIndex = 0,
    this.onNavigationChanged,
    this.themeService,
  });

  final List<AdaptiveNavigationItem> navigationItems;
  final Widget Function(BuildContext context, int index) bodyBuilder;
  final int selectedIndex;
  final ValueChanged<int>? onNavigationChanged;
  final ThemeService? themeService;

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isWideScreen(context);

    if (isWide) {
      return Row(
        children: [
          _Sidebar(
            items: navigationItems,
            selectedIndex: selectedIndex,
            onDestinationSelected: onNavigationChanged,
            themeService: themeService,
          ),
          Expanded(
            child: DefaultTextStyle(
              style: const TextStyle(decoration: TextDecoration.none),
              child: Stack(
                children: [
                  const BackgroundEffects(),
                  // Перерисовка экранов при смене стилизации без потери состояния
                  AnimatedBuilder(
                    animation: AppColors.listenable,
                    builder: (context, _) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: KeyedSubtree(
                          key: ValueKey<int>(selectedIndex),
                          child: bodyBuilder(context, selectedIndex),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: DefaultTextStyle(
        style: const TextStyle(decoration: TextDecoration.none),
        child: Stack(
          children: [
            const BackgroundEffects(),
            AnimatedBuilder(
              animation: AppColors.listenable,
              builder: (context, _) => bodyBuilder(context, selectedIndex),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.sidebarTop, AppColors.sidebarBottom],
          ),
          border: Border(
            top: BorderSide(color: AppColors.glassBorder.withOpacity(0.5)),
          ),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          indicatorColor: AppColors.emerald.withOpacity(0.15),
          selectedIndex: selectedIndex,
          onDestinationSelected: onNavigationChanged,
          destinations: navigationItems
              .map(
                (item) => NavigationDestination(
                  icon: Text(
                    item.iconSymbol,
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textDim,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  selectedIcon: Text(
                    item.iconSymbol,
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.emerald,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  label: item.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.selectedIndex,
    this.onDestinationSelected,
    this.themeService,
  });

  final List<AdaptiveNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final ThemeService? themeService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppColors.listenable,
      builder: (context, _) {
        return DefaultTextStyle(
          style: const TextStyle(decoration: TextDecoration.none),
          child: Container(
            width: 260,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.sidebarTop, AppColors.sidebarBottom],
              ),
              border: Border(
                right: BorderSide(color: AppColors.glassBorder),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 32),
                _buildLogo(),
                const SizedBox(height: 48),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final isActive = selectedIndex == i;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => onDestinationSelected?.call(i),
                            hoverColor: AppColors.hoverBg,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: isActive
                                    ? Border.all(
                                        color: AppColors.emerald.withOpacity(
                                          0.2,
                                        ),
                                      )
                                    : null,
                                gradient: isActive
                                    ? LinearGradient(
                                        colors: [
                                          AppColors.emerald.withOpacity(0.12),
                                          Colors.transparent,
                                        ],
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    items[i].iconSymbol,
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: isActive
                                          ? AppColors.emerald
                                          : AppColors.textDim,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    items[i].label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isActive
                                          ? AppColors.emerald
                                          : AppColors.textDim,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (themeService != null) _buildThemePicker(themeService!),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'SpeedVPS v1.0.0',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textDark.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Переключатель 4 стилизаций (точки как в дизайне)
  Widget _buildThemePicker(ThemeService service) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        children: [
          Divider(color: AppColors.borderSubtle, height: 1),
          const SizedBox(height: 12),
          Text(
            'ТЕМА',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final variant in AppThemeVariant.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: GestureDetector(
                    onTap: () => service.setVariant(variant),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: ThemePalettes.dotColors(variant),
                        ),
                        border: Border.all(
                          color: service.variant == variant
                              ? AppColors.emerald
                              : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: service.variant == variant
                            ? [
                                BoxShadow(
                                  color: AppColors.emerald.withOpacity(0.55),
                                  blurRadius: 12,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Text(
          'SPEEDVPS',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.emerald,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: AppColors.emerald.withOpacity(0.4),
                blurRadius: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'SECURE CONNECTION',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 3,
            color: AppColors.textDim,
          ),
        ),
      ],
    );
  }
}

class AdaptiveNavigationItem {
  const AdaptiveNavigationItem({
    this.icon,
    required this.iconSymbol,
    required this.label,
    this.selectedIcon,
  });

  final IconData? icon;
  final String iconSymbol;
  final String label;
  final IconData? selectedIcon;
}

/// Glass toggle switch matching reference design
class GlassToggle extends StatelessWidget {
  const GlassToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 52,
        height: 28,
        decoration: BoxDecoration(
          gradient: value
              ? LinearGradient(
                  colors: [AppColors.emerald, AppColors.emeraldDim],
                )
              : null,
          color: value ? null : AppColors.inputFill,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: value
                ? AppColors.emerald.withOpacity(0.4)
                : AppColors.borderSubtle,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: AppColors.emerald.withOpacity(0.3),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? AppColors.bg : Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass text field matching reference design
class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    this.controller,
    this.hintText,
    this.onSubmitted,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.2, -1),
          end: const Alignment(1, 1),
          colors: [AppColors.glassFillLight1, AppColors.glassFillAccent],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.glassBorder.withOpacity(0.5)),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: AppColors.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: AppColors.textDark),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          suffixIcon: suffix,
        ),
        onSubmitted: onSubmitted,
        keyboardType: keyboardType,
        obscureText: obscureText,
      ),
    );
  }
}

/// Платформенно-ориентированный виджет
class PlatformWidget extends StatelessWidget {
  const PlatformWidget({
    super.key,
    this.androidBuilder,
    this.iosBuilder,
    this.macosBuilder,
    this.windowsBuilder,
    this.linuxBuilder,
    this.builder,
  });

  final Widget Function(BuildContext)? androidBuilder;
  final Widget Function(BuildContext)? iosBuilder;
  final Widget Function(BuildContext)? macosBuilder;
  final Widget Function(BuildContext)? windowsBuilder;
  final Widget Function(BuildContext)? linuxBuilder;
  final Widget Function(BuildContext)? builder;

  @override
  Widget build(BuildContext context) {
    if (builder != null) return builder!(context);

    if (Platform.isAndroid && androidBuilder != null) {
      return androidBuilder!(context);
    }
    if (Platform.isIOS && iosBuilder != null) return iosBuilder!(context);
    if (Platform.isMacOS && macosBuilder != null) return macosBuilder!(context);
    if (Platform.isWindows && windowsBuilder != null) {
      return windowsBuilder!(context);
    }
    if (Platform.isLinux && linuxBuilder != null) return linuxBuilder!(context);

    return androidBuilder?.call(context) ??
        iosBuilder?.call(context) ??
        const SizedBox.shrink();
  }
}

/// Темы приложения (динамические — зависят от активной палитры)
class AppThemes {
  static ThemeData light() => _buildTheme(Brightness.light);
  static ThemeData dark() => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: AppColors.isLight ? Brightness.light : brightness,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.emerald,
        brightness: AppColors.isLight ? Brightness.light : brightness,
        surface: AppColors.bgPanel,
        primary: AppColors.emerald,
        onPrimary: AppColors.bg,
        secondary: AppColors.emeraldDim,
        onSecondary: AppColors.bg,
        error: AppColors.error,
        onError: Colors.white,
        onSurface: AppColors.text,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: AppColors.bgPanel,
        indicatorColor: AppColors.emerald.withOpacity(0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(
            color: AppColors.textDim,
            fontSize: 12,
            decoration: TextDecoration.none,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: AppColors.emerald);
          }
          return IconThemeData(color: AppColors.textDim);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emerald,
          foregroundColor: AppColors.bg,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            decoration: TextDecoration.none,
          ),
          shadowColor: AppColors.emerald.withOpacity(0.35),
          elevation: 4,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.emerald,
          side: BorderSide(color: AppColors.emerald),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            decoration: TextDecoration.none,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.emerald),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        hintStyle: TextStyle(color: AppColors.textDark),
      ),
      cardTheme: CardThemeData(
        color: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(decoration: TextDecoration.none),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.emerald.withOpacity(0.1),
        side: BorderSide(color: AppColors.emerald),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        labelStyle: TextStyle(
          color: AppColors.emerald,
          decoration: TextDecoration.none,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.glassBorder,
        thickness: 1,
      ),
      textTheme: TextTheme(
        headlineLarge: AppTypography.headlineLarge,
        headlineMedium: AppTypography.headlineMedium,
        titleLarge: AppTypography.titleLarge,
        titleMedium: AppTypography.titleMedium,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        labelLarge: AppTypography.labelLarge,
        labelSmall: AppTypography.labelSmall,
      ).apply(decoration: TextDecoration.none),
    );
  }
}
