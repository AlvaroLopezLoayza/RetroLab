library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/film_stocks.dart';

enum OverlayMode { off, thirds, golden, center }

class ViewfinderOverlay extends StatelessWidget {
  final FilmStock filmStock;
  final int remainingExposures;
  final OverlayMode overlayMode;

  const ViewfinderOverlay({
    super.key,
    required this.filmStock,
    required this.remainingExposures,
    this.overlayMode = OverlayMode.off,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          ..._buildCornerBrackets(),
          if (overlayMode != OverlayMode.off)
            Positioned.fill(
              child: CustomPaint(
                painter: _CompositionPainter(mode: overlayMode),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: RetroDimens.paddingMd,
                vertical: RetroDimens.paddingSm,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: filmStock.badgeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(
                          RetroDimens.radiusSm,
                        ),
                        border: Border.all(
                          color: filmStock.badgeColor.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            filmStock.icon,
                            size: 14,
                            color: filmStock.badgeColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            filmStock.shortName,
                            style: GoogleFonts.spaceMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: filmStock.badgeColor,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(
                          RetroDimens.radiusSm,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$remainingExposures',
                            style: GoogleFonts.spaceMono(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color:
                                  remainingExposures <= 5
                                      ? RetroColors.error
                                      : RetroColors.dateYellow,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            RetroStrings.exposuresRemaining,
                            style: GoogleFonts.spaceMono(
                              fontSize: 9,
                              color: RetroColors.textMuted,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: RetroDimens.paddingMd,
            child: Text(
              _formatDate(),
              style: GoogleFonts.spaceMono(
                fontSize: 12,
                color: RetroColors.dateYellow.withValues(alpha: 0.7),
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate() {
    final now = DateTime.now();
    return '${now.month.toString().padLeft(2, '0')}  '
        '${now.day.toString().padLeft(2, '0')}  '
        "'${now.year.toString().substring(2)}";
  }

  List<Widget> _buildCornerBrackets() {
    const bracketSize = 30.0;
    const bracketThickness = 2.8;
    const color = RetroColors.textSecondary;
    const margin = 20.0;

    Widget bracket({required bool top, required bool left}) {
      return Positioned(
        top: top ? margin : null,
        bottom: !top ? margin + 80 : null,
        left: left ? margin : null,
        right: !left ? margin : null,
        child: SizedBox(
          width: bracketSize,
          height: bracketSize,
          child: CustomPaint(
            painter: _BracketPainter(
              top: top,
              left: left,
              color: color,
              thickness: bracketThickness,
            ),
          ),
        ),
      );
    }

    return [
      bracket(top: true, left: true),
      bracket(top: true, left: false),
      bracket(top: false, left: true),
      bracket(top: false, left: false),
    ];
  }
}

class _BracketPainter extends CustomPainter {
  final bool top;
  final bool left;
  final Color color;
  final double thickness;

  const _BracketPainter({
    required this.top,
    required this.left,
    required this.color,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color.withValues(alpha: 0.82)
          ..strokeWidth = thickness
          ..style = PaintingStyle.stroke;

    final path = Path();
    if (top && left) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (top && !left) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CompositionPainter extends CustomPainter {
  final OverlayMode mode;

  const _CompositionPainter({required this.mode});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.32)
          ..strokeWidth = 1.4;
    final pointPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.42)
          ..style = PaintingStyle.fill;

    switch (mode) {
      case OverlayMode.off:
        break;
      case OverlayMode.thirds:
        _drawThirds(canvas, size, linePaint);
        break;
      case OverlayMode.golden:
        _drawGolden(canvas, size, linePaint, pointPaint);
        break;
      case OverlayMode.center:
        _drawCenter(canvas, size, linePaint);
        break;
    }
  }

  void _drawThirds(Canvas canvas, Size size, Paint paint) {
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );
  }

  void _drawGolden(
    Canvas canvas,
    Size size,
    Paint linePaint,
    Paint pointPaint,
  ) {
    const minor = 0.38196601125;
    const major = 0.61803398875;
    final xs = [size.width * minor, size.width * major];
    final ys = [size.height * minor, size.height * major];

    for (final x in xs) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (final y in ys) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    for (final x in xs) {
      for (final y in ys) {
        canvas.drawCircle(Offset(x, y), 3.2, pointPaint);
      }
    }
  }

  void _drawCenter(Canvas canvas, Size size, Paint paint) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final square = math.min(size.width, size.height) * 0.58;
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: square,
      height: square,
    );

    canvas.drawRect(rect, paint);
    canvas.drawLine(Offset(cx - 26, cy), Offset(cx + 26, cy), paint);
    canvas.drawLine(Offset(cx, cy - 26), Offset(cx, cy + 26), paint);
  }

  @override
  bool shouldRepaint(covariant _CompositionPainter oldDelegate) =>
      oldDelegate.mode != mode;
}
