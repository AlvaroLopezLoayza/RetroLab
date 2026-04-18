/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Stats Dashboard Screen
///
/// Displays fun photography statistics: total shots, rolls developed,
/// favorite film stock, and per-stock usage breakdown.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/film_stocks.dart';
import '../core/hive_boxes.dart';
import '../widgets/grain_overlay.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final totalShots = HiveService.totalShots;
    final totalRolls = HiveService.totalRolls;
    final favoriteStock = FilmStocks.getById(HiveService.favoriteStockId);
    final usageMap = Map<String, int>.from(
      HiveService.statsBox.get('stock_usage', defaultValue: {}) as Map,
    );

    return Scaffold(
      backgroundColor: RetroColors.background,
      appBar: AppBar(title: const Text('DARKROOM STATS')),
      body: Stack(
        children: [
          const Positioned.fill(child: GrainOverlay(opacity: 0.03)),
          SingleChildScrollView(
            padding: const EdgeInsets.all(RetroDimens.paddingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero Stats ───────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        icon: Icons.camera_alt,
                        value: '$totalShots',
                        label: 'Total Shots',
                        color: RetroColors.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        icon: Icons.camera_roll,
                        value: '$totalRolls',
                        label: 'Films Used',
                        color: RetroColors.dateYellow,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Favorite Film Stock
                _statCard(
                  icon: favoriteStock.icon,
                  value: favoriteStock.name,
                  label: 'Favorite Film Stock',
                  color: favoriteStock.badgeColor,
                  wide: true,
                ),
                const SizedBox(height: 32),

                // ── Per-Stock Breakdown ───────────────────────────────────
                Text(
                  'FILM USAGE',
                  style: GoogleFonts.spaceMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: RetroColors.accent,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),

                ...FilmStocks.all.map((stock) {
                  final count = usageMap[stock.id] ?? 0;
                  final maxCount = usageMap.values.isEmpty
                      ? 1
                      : usageMap.values.reduce((a, b) => a > b ? a : b);
                  final fraction =
                      maxCount > 0 ? count / maxCount : 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(stock.icon, size: 16, color: stock.badgeColor),
                            const SizedBox(width: 8),
                            Text(
                              stock.shortName,
                              style: GoogleFonts.spaceMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: RetroColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$count shots',
                              style: GoogleFonts.spaceMono(
                                fontSize: 11,
                                color: RetroColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: fraction,
                            backgroundColor: RetroColors.surfaceLight,
                            valueColor: AlwaysStoppedAnimation(
                              stock.badgeColor,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 32),

                // ── Fun Fact ─────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(RetroDimens.paddingMd),
                  decoration: BoxDecoration(
                    color: RetroColors.surface,
                    borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
                    border: Border.all(color: RetroColors.surfaceLight),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: RetroColors.dateYellow,
                        size: 28,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _getFunFact(totalShots),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: RetroColors.textSecondary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    bool wide = false,
  }) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(RetroDimens.paddingMd),
      decoration: BoxDecoration(
        color: RetroColors.surface,
        borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.spaceMono(
              fontSize: wide ? 16 : 24,
              fontWeight: FontWeight.w700,
              color: RetroColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: RetroColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  String _getFunFact(int shots) {
    if (shots == 0) return 'Your darkroom is empty. Go shoot something!';
    if (shots < 10) return 'You\'re just getting started. Keep shooting!';
    if (shots < 50) {
      return 'That\'s $shots memories preserved in analog glory. '
          'A real photographer in the making!';
    }
    if (shots < 100) {
      return '$shots shots! You\'re burning through film like a pro. '
          'Time to try a new stock?';
    }
    return '$shots shots developed! You\'re a darkroom legend. '
        'Ansel Adams would be proud.';
  }
}
