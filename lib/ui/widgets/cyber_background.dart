// lib/ui/widgets/cyber_background.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'voxel_crystal.dart';

/// Анимированный cyber-фон с сеткой, частицами и воксельным кристаллом
class CyberBackground extends StatefulWidget {
  const CyberBackground({super.key});

  @override
  State<CyberBackground> createState() => _CyberBackgroundState();
}

class _CyberBackgroundState extends State<CyberBackground>
    with TickerProviderStateMixin {
  late AnimationController _gridController;
  late AnimationController _particlesController;

  @override
  void initState() {
    super.initState();
    _gridController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
    _particlesController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _gridController.dispose();
    _particlesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Grid
        AnimatedBuilder(
          animation: _gridController,
          builder: (context, child) {
            return CustomPaint(
              painter: _GridPainter(progress: _gridController.value),
              size: Size.infinite,
            );
          },
        ),
        // Particles
        AnimatedBuilder(
          animation: _particlesController,
          builder: (context, child) {
            return CustomPaint(
              painter: _ParticlesPainter(progress: _particlesController.value),
              size: Size.infinite,
            );
          },
        ),
        // Voxel crystal centered at bottom
        Align(
          alignment: const Alignment(0, 0.6),
          child: VoxelCrystal(size: 180),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.emerald.withOpacity(0.04)
      ..strokeWidth = 1;

    const cellSize = 60.0;
    final offsetY = progress * cellSize;

    for (double x = 0; x <= size.width; x += cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = -cellSize + offsetY; y <= size.height; y += cellSize) {
      if (y >= 0) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ParticlesPainter extends CustomPainter {
  _ParticlesPainter({required this.progress});

  final double progress;
  final _random = Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    const count = 60;
    for (var i = 0; i < count; i++) {
      final x = _random.nextDouble() * size.width;
      final baseY = _random.nextDouble() * size.height;
      final speed = 0.3 + _random.nextDouble() * 0.7;
      final radius = 1.5 + _random.nextDouble() * 3.0;

      var y = baseY - (progress * size.height * speed);
      if (y < 0) y += size.height;

      final isCyan = _random.nextDouble() > 0.7;
      final baseColor = isCyan ? const Color(0xFF00ffff) : AppColors.emerald;
      final opacity = 0.5 + _random.nextDouble() * 0.5;

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = baseColor.withOpacity(opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
