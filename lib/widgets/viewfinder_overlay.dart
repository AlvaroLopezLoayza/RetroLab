/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Viewfinder Overlay Widget
///
/// Renders a camera viewfinder with corner brackets, grid lines,
/// and film stock info overlay on the camera preview.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../core/film_stocks.dart';

class ViewfinderOverlay extends StatelessWidget {
  final FilmStock filmStock;
  final int remainingExposures;
  final bool showGrid;

  const ViewfinderOverlay({
    super.key,
    required this.filmStock,
    required this.remainingExposures,
    this.showGrid = false,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          // ── Corner Brackets ────────────────────────────────────────────
          ..._buildCornerBrackets(),

          // ── Grid Lines (optional) ─────────────────────────────────────
          if (showGrid) _buildGrid(),

          // ── Top Info Bar ──────────────────────────────────────────────
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
                    // Film stock name
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

                    // Exposure counter
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
                              color: remainingExposures <= 5
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

          // ── Date Preview (bottom-right, like HUJI) ────────────────────
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
    const bracketThickness = 2.0;
    const color = RetroColors.textSecondary;
    const margin = 20.0;

    Widget bracket({
      required Alignment alignment,
      required bool top,
      required bool left,
    }) {
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
      bracket(alignment: Alignment.topLeft, top: true, left: true),
      bracket(alignment: Alignment.topRight, top: true, left: false),
      bracket(alignment: Alignment.bottomLeft, top: false, left: true),
      bracket(alignment: Alignment.bottomRight, top: false, left: false),
    ];
  }

  Widget _buildGrid() {
    return Positioned.fill(
      child: CustomPaint(painter: _GridPainter()),
    );
  }
}

class _BracketPainter extends CustomPainter {
  final bool top;
  final bool left;
  final Color color;
  final double thickness;

  _BracketPainter({
    required this.top,
    required this.left,
    required this.color,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
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

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 0.5;

    // Rule of thirds
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
