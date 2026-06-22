library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants.dart';
import '../core/film_stocks.dart';
import '../models/retro_photo.dart';
import '../utils/image_processor.dart';
import '../widgets/grain_overlay.dart';
import 'editor_screen.dart';

class PreviewScreen extends StatefulWidget {
  final RetroPhoto photo;
  final Uint8List processedBytes;

  const PreviewScreen({
    super.key,
    required this.photo,
    required this.processedBytes,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  bool _showActions = true;

  String _formatCapturedAt(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} · $hour:$minute';
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _shareImage() {
    Share.shareXFiles([
      XFile(widget.photo.processedPath),
    ], text: RetroStrings.watermark);
  }

  Future<void> _shareAsPolaroid() async {
    try {
      final filmStock = FilmStocks.getById(widget.photo.filmStockId);
      final polaroidFile = await ImageProcessor.createPolaroidFrame(
        File(widget.photo.processedPath),
        filterName: filmStock.name,
      );
      Share.shareXFiles([
        XFile(polaroidFile.path),
      ], text: RetroStrings.watermark);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating Polaroid: $e')));
    }
  }

  void _openEditor() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditorScreen(photo: widget.photo)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filmStock = FilmStocks.getById(widget.photo.filmStockId);

    return Scaffold(
      backgroundColor: RetroColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GrainOverlay(opacity: 0.03)),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.46),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.72),
                    ],
                    stops: const [0.0, 0.18, 0.58, 1.0],
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _showActions = !_showActions),
            child: Center(
              child: FadeTransition(
                opacity: _fadeController,
                child: Hero(
                  tag: 'photo_${widget.photo.id}',
                  child: Container(
                    margin: const EdgeInsets.all(RetroDimens.paddingMd),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
                      child: Image.memory(
                        widget.processedBytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showActions)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _topButton(
                            icon: Icons.close,
                            onTap:
                                () => Navigator.of(
                                  context,
                                ).popUntil((route) => route.isFirst),
                          ),
                          const Spacer(),
                          _topButton(
                            icon: Icons.visibility_off_outlined,
                            onTap: () => setState(() => _showActions = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(RetroDimens.paddingMd),
                        decoration: BoxDecoration(
                          color: RetroColors.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(
                            RetroDimens.radiusLg,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    filmStock.name,
                                    style: GoogleFonts.spaceMono(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: RetroColors.textPrimary,
                                    ),
                                  ),
                                ),
                                _metadataPill(
                                  filmStock.shortName,
                                  filmStock.badgeColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatCapturedAt(widget.photo.capturedAt),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: RetroColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _metadataPill(
                                  widget.photo.isImported
                                      ? 'IMPORT'
                                      : 'CAPTURE',
                                  RetroColors.accent,
                                ),
                                _metadataPill(
                                  widget.photo.dateStampEnabled
                                      ? 'DATE STAMP ON'
                                      : 'DATE STAMP OFF',
                                  RetroColors.dateYellow,
                                ),
                                _metadataPill(
                                  'GRAIN ${(widget.photo.grain * 100).round()}%',
                                  Colors.white70,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_showActions)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(RetroDimens.paddingMd),
                  child: Container(
                    padding: const EdgeInsets.all(RetroDimens.paddingMd),
                    decoration: BoxDecoration(
                      color: RetroColors.surface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'OUTPUT ACTIONS',
                                style: GoogleFonts.spaceMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: RetroColors.accent,
                                  letterSpacing: 1.6,
                                ),
                              ),
                            ),
                            Text(
                              'tap photo to hide UI',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: RetroColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _actionButton(
                                Icons.edit_outlined,
                                'Edit',
                                'Adjust look',
                                _openEditor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _actionButton(
                                Icons.ios_share_outlined,
                                'Share',
                                'Processed file',
                                _shareImage,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _actionButton(
                                Icons.photo_size_select_actual_outlined,
                                'Polaroid',
                                'Frame export',
                                _shareAsPolaroid,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _actionButton(
                                Icons.check_circle_outline,
                                'Done',
                                'Back to camera',
                                () => Navigator.of(
                                  context,
                                ).popUntil((route) => route.isFirst),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (!_showActions)
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _topButton(
                    icon: Icons.visibility_outlined,
                    onTap: () => setState(() => _showActions = true),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: RetroColors.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(icon, color: RetroColors.textPrimary),
        ),
      ),
    );
  }

  Widget _metadataPill(String label, Color color) {
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
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _actionButton(
    IconData icon,
    String label,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: RetroColors.background.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
            border: Border.all(
              color: RetroColors.surfaceLight.withValues(alpha: 0.9),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: RetroColors.textPrimary),
              const SizedBox(height: 12),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.spaceMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: RetroColors.textPrimary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: RetroColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
