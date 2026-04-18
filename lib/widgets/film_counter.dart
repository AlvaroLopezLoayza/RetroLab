/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Film Counter Widget
///
/// Displays the remaining exposures with a retro LED-style counter.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';

class FilmCounter extends StatelessWidget {
  final int remaining;
  final int total;

  const FilmCounter({
    super.key,
    required this.remaining,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (total - remaining) / total;
    final isLow = remaining <= 5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: RetroColors.surface,
        borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
        border: Border.all(
          color: isLow
              ? RetroColors.error.withValues(alpha: 0.5)
              : RetroColors.surfaceLight,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Film icon
          Icon(
            Icons.camera_roll_outlined,
            size: 16,
            color: isLow ? RetroColors.error : RetroColors.textSecondary,
          ),
          const SizedBox(width: 8),

          // Counter digit
          Text(
            remaining.toString().padLeft(2, '0'),
            style: GoogleFonts.spaceMono(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isLow ? RetroColors.error : RetroColors.dateYellow,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(width: 4),

          // Separator
          Text(
            '/',
            style: GoogleFonts.spaceMono(
              fontSize: 14,
              color: RetroColors.textMuted,
            ),
          ),
          const SizedBox(width: 4),

          Text(
            '$total',
            style: GoogleFonts.spaceMono(
              fontSize: 12,
              color: RetroColors.textMuted,
            ),
          ),
          const SizedBox(width: 12),

          // Progress bar
          SizedBox(
            width: 50,
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: RetroColors.surfaceLight,
                valueColor: AlwaysStoppedAnimation(
                  isLow ? RetroColors.error : RetroColors.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
