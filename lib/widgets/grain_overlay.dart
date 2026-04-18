/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Grain Overlay Widget
///
/// Animated semi-transparent film grain overlay that sits on top of any screen.
/// Uses a custom painter for performant real-time grain simulation.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:math';

import 'package:flutter/material.dart';

class GrainOverlay extends StatefulWidget {
  final double opacity;
  final bool animate;

  const GrainOverlay({
    super.key,
    this.opacity = 0.06,
    this.animate = true,
  });

  @override
  State<GrainOverlay> createState() => _GrainOverlayState();
}

class _GrainOverlayState extends State<GrainOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _GrainPainter(
              opacity: widget.opacity,
              seed: DateTime.now().millisecondsSinceEpoch,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  final double opacity;
  final int seed;

  _GrainPainter({required this.opacity, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    final paint = Paint();

    // Draw sparse noise points for performance
    final density = (size.width * size.height / 60).round();
    for (int i = 0; i < density; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final brightness = random.nextInt(256);
      paint.color = Color.fromRGBO(brightness, brightness, brightness, opacity);

      canvas.drawRect(
        Rect.fromLTWH(x, y, 1.5, 1.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) => true;
}
