/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Preview Screen
///
/// Shows the processed retro photo with options to re-edit, share,
/// and save in various export formats.
/// ─────────────────────────────────────────────────────────────────────────────
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
    Share.shareXFiles(
      [XFile(widget.photo.processedPath)],
      text: RetroStrings.watermark,
    );
  }

  Future<void> _shareAsPolaroid() async {
    try {
      final polaroidFile = await ImageProcessor.createPolaroidFrame(
        File(widget.photo.processedPath),
      );
      Share.shareXFiles(
        [XFile(polaroidFile.path)],
        text: RetroStrings.watermark,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating Polaroid: $e')),
      );
    }
  }

  void _openEditor() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(photo: widget.photo),
      ),
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

          // ── Photo ──────────────────────────────────────────────────────
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
                      borderRadius: BorderRadius.circular(
                        RetroDimens.radiusSm,
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
                      borderRadius: BorderRadius.circular(
                        RetroDimens.radiusSm,
                      ),
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

          // ── Top Bar ────────────────────────────────────────────────────
          if (_showActions)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RetroDimens.paddingSm,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).popUntil(
                            (route) => route.isFirst,
                          ),
                          icon: const Icon(
                            Icons.close,
                            color: RetroColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        // Film stock badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: filmStock.badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              RetroDimens.radiusSm,
                            ),
                          ),
                          child: Text(
                            filmStock.shortName,
                            style: GoogleFonts.spaceMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: filmStock.badgeColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 48), // Balance
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Bottom Actions ─────────────────────────────────────────────
          if (_showActions)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(RetroDimens.paddingMd),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Action buttons row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _actionButton(
                              Icons.edit,
                              'EDIT',
                              _openEditor,
                            ),
                            _actionButton(
                              Icons.share,
                              'SHARE',
                              _shareImage,
                            ),
                            _actionButton(
                              Icons.photo_size_select_actual,
                              'POLAROID',
                              _shareAsPolaroid,
                            ),
                            _actionButton(
                              Icons.done,
                              'DONE',
                              () => Navigator.of(context).popUntil(
                                (route) => route.isFirst,
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
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: RetroColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: RetroColors.surfaceLight,
                width: 1,
              ),
            ),
            child: Icon(icon, size: 22, color: RetroColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.spaceMono(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: RetroColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
