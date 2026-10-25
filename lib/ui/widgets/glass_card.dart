import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            // Liquid glass (165deg): light1 -> light2 -> accent -> dark
            gradient: LinearGradient(
              begin: const Alignment(-0.9, -1),
              end: const Alignment(0.6, 1),
              colors: [
                AppColors.glassFillLight1,
                AppColors.glassFillLight2,
                AppColors.glassFillAccent,
                AppColors.glassFillDark,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.glassBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.isLight
                    ? Colors.black.withOpacity(0.08)
                    : Colors.black.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Inner depth highlight
              Positioned(
                top: 0,
                left: 20,
                right: 20,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.glassTopLine,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: content,
        ),
      );
    }

    return content;
  }
}
