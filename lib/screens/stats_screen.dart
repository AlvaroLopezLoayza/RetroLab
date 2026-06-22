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
                _heroCard(totalShots, totalRolls, favoriteStock),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        icon: Icons.camera_alt_outlined,
                        value: '$totalShots',
                        label: 'Total Shots',
                        color: RetroColors.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        icon: Icons.camera_roll_outlined,
                        value: '$totalRolls',
                        label: 'Films Used',
                        color: RetroColors.dateYellow,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _statCard(
                  icon: favoriteStock.icon,
                  value: favoriteStock.name,
                  label: 'Favorite Film Stock',
                  color: favoriteStock.badgeColor,
                  wide: true,
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  title: 'FILM USAGE',
                  subtitle: 'How often each stock appears in your lab.',
                  child: Column(
                    children: [
                      ...FilmStocks.all.map((stock) {
                        final count = usageMap[stock.id] ?? 0;
                        final maxCount =
                            usageMap.values.isEmpty
                                ? 1
                                : usageMap.values.reduce(
                                  (a, b) => a > b ? a : b,
                                );
                        final fraction = maxCount > 0 ? count / maxCount : 0.0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    stock.icon,
                                    size: 16,
                                    color: stock.badgeColor,
                                  ),
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
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: fraction,
                                  backgroundColor: RetroColors.surfaceLight,
                                  valueColor: AlwaysStoppedAnimation(
                                    stock.badgeColor,
                                  ),
                                  minHeight: 7,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  title: 'FUN FACT',
                  subtitle: 'A quick read on your shooting habits.',
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

  Widget _heroCard(int totalShots, int totalRolls, FilmStock favoriteStock) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RetroDimens.paddingMd),
      decoration: BoxDecoration(
        color: RetroColors.surface,
        borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR DARKROOM AT A GLANCE',
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: RetroColors.accent,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            totalShots == 0
                ? 'No frames developed yet.'
                : '$totalShots frames developed.',
            style: GoogleFonts.spaceMono(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: RetroColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Across $totalRolls rolls, ${favoriteStock.shortName} is currently leading your usage.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: RetroColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip('SHOTS $totalShots', RetroColors.accent),
              _summaryChip('ROLLS $totalRolls', RetroColors.dateYellow),
              _summaryChip(
                'TOP ${favoriteStock.shortName}',
                favoriteStock.badgeColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RetroDimens.paddingMd),
      decoration: BoxDecoration(
        color: RetroColors.surface,
        borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceMono(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: RetroColors.accent,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: RetroColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _summaryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(RetroDimens.radiusXl),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceMono(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.7,
        ),
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
        borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
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
            textAlign: wide ? TextAlign.left : TextAlign.center,
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
