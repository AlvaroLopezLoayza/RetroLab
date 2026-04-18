/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Retro Slider Widget
///
/// Custom styled slider with label, value display, and retro aesthetics.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';

class RetroSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const RetroSlider({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = ((value - min) / (max - min) * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RetroDimens.paddingMd,
        vertical: 4,
      ),
      child: Row(
        children: [
          // Icon
          Icon(icon, size: 18, color: RetroColors.accent),
          const SizedBox(width: 10),

          // Label
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: GoogleFonts.spaceMono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: RetroColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Slider
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),

          // Value
          SizedBox(
            width: 36,
            child: Text(
              '$percentage%',
              style: GoogleFonts.spaceMono(
                fontSize: 10,
                color: RetroColors.dateYellow,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
