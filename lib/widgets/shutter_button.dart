/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Shutter Button Widget
///
/// Premium animated shutter button with press animation and glow effect.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';

class ShutterButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool enabled;
  final double size;

  const ShutterButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
    this.size = 80,
  });

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.88,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (!widget.enabled) return;
    _controller.forward();
    HapticFeedback.mediumImpact();
  }

  void _handleTapUp(TapUpDetails _) {
    if (!widget.enabled) return;
    _controller.reverse();
    widget.onPressed();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: RetroColors.accent.withValues(
                      alpha: 0.3 + _glowAnimation.value * 0.4,
                    ),
                    blurRadius: 16 + _glowAnimation.value * 20,
                    spreadRadius: _glowAnimation.value * 4,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ring
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            widget.enabled
                                ? RetroColors.accent
                                : RetroColors.textMuted,
                        width: 4,
                      ),
                    ),
                  ),
                  // Inner filled circle
                  Container(
                    width: widget.size * 0.75,
                    height: widget.size * 0.75,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          widget.enabled
                              ? RetroColors.accent
                              : RetroColors.textMuted,
                      gradient:
                          widget.enabled
                              ? const RadialGradient(
                                colors: [
                                  RetroColors.accentLight,
                                  RetroColors.accent,
                                  RetroColors.accentDark,
                                ],
                                stops: [0.0, 0.5, 1.0],
                              )
                              : null,
                    ),
                  ),
                  // Center dot (aperture feel)
                  Container(
                    width: widget.size * 0.15,
                    height: widget.size * 0.15,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
