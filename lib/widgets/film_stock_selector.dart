/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Film Stock Selector Widget
///
/// Horizontal scrolling carousel for selecting film stock presets.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../core/film_stocks.dart';

class FilmStockSelector extends StatelessWidget {
  final FilmStock selectedStock;
  final ValueChanged<FilmStock> onStockChanged;
  final bool compact;

  const FilmStockSelector({
    super.key,
    required this.selectedStock,
    required this.onStockChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 48 : 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: RetroDimens.paddingMd),
        itemCount: FilmStocks.all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final stock = FilmStocks.all[index];
          final isSelected = stock.id == selectedStock.id;
          return _FilmStockChip(
            stock: stock,
            isSelected: isSelected,
            compact: compact,
            onTap: () => onStockChanged(stock),
          );
        },
      ),
    );
  }
}

class _FilmStockChip extends StatelessWidget {
  final FilmStock stock;
  final bool isSelected;
  final bool compact;
  final VoidCallback onTap;

  const _FilmStockChip({
    required this.stock,
    required this.isSelected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? stock.badgeColor.withValues(alpha: 0.15)
              : RetroColors.surface,
          borderRadius: BorderRadius.circular(
            compact ? RetroDimens.radiusSm : RetroDimens.radiusMd,
          ),
          border: Border.all(
            color: isSelected
                ? stock.badgeColor
                : RetroColors.surfaceLight,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: stock.badgeColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: compact
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(stock.icon, size: 14, color: stock.badgeColor),
                  const SizedBox(width: 6),
                  Text(
                    stock.shortName,
                    style: GoogleFonts.spaceMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? stock.badgeColor
                          : RetroColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(stock.icon, size: 22, color: stock.badgeColor),
                  const SizedBox(height: 6),
                  Text(
                    stock.shortName,
                    style: GoogleFonts.spaceMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? stock.badgeColor
                          : RetroColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stock.name,
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      color: RetroColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
}
