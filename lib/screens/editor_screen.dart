/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Editor Screen
///
/// Post-capture editor: re-adjust grain, leak, vignette, change film stock,
/// toggle date stamp, and reprocess the image.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/film_stocks.dart';
import '../core/hive_boxes.dart';
import '../models/retro_photo.dart';
import '../utils/image_processor.dart';
import '../widgets/film_stock_selector.dart';
import '../widgets/grain_overlay.dart';
import '../widgets/retro_slider.dart';
import 'preview_screen.dart';

class EditorScreen extends StatefulWidget {
  final RetroPhoto photo;

  const EditorScreen({super.key, required this.photo});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late FilmStock _selectedStock;
  late double _grain;
  late double _leakStrength;
  late double _saturation;
  late double _vignette;
  late double _scratchLevel;
  late bool _dateStampEnabled;
  late DateStampStyle _dateStampStyle;
  late DateStampPosition _dateStampPosition;

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _selectedStock = FilmStocks.getById(widget.photo.filmStockId);
    _grain = widget.photo.grain;
    _leakStrength = widget.photo.leakStrength;
    _saturation = widget.photo.saturation;
    _vignette = widget.photo.vignette;
    _scratchLevel = widget.photo.scratchLevel;
    _dateStampEnabled = widget.photo.dateStampEnabled;
    _dateStampStyle = DateStampStyle.values.firstWhere(
      (s) => s.name == widget.photo.dateStampStyle,
      orElse: () => DateStampStyle.classic90s,
    );
    _dateStampPosition = DateStampPosition.values.firstWhere(
      (p) => p.name == widget.photo.dateStampPosition,
      orElse: () => DateStampPosition.bottomRight,
    );
  }

  Future<void> _reprocess() async {
    setState(() => _isProcessing = true);

    try {
      final originalFile = File(widget.photo.originalPath);
      if (!originalFile.existsSync()) {
        throw Exception('Original file not found');
      }

      final result = await ImageProcessor.processRetroImage(
        originalFile,
        filmStock: _selectedStock,
        grain: _grain,
        leakStrength: _leakStrength,
        saturationOverride: _saturation,
        vignette: _vignette,
        scratchLevel: _scratchLevel,
        dateStampEnabled: _dateStampEnabled,
        dateStampStyle: _dateStampStyle,
        dateStampPosition: _dateStampPosition,
        analogRandomness: HiveService.analogRandomnessEnabled,
        captureDate: widget.photo.capturedAt,
      );

      // Update photo in Hive
      final updatedPhoto = widget.photo.copyWith(
        processedPath: result.file.path,
        filmStockId: _selectedStock.id,
        grain: _grain,
        leakStrength: _leakStrength,
        saturation: _saturation,
        vignette: _vignette,
        scratchLevel: _scratchLevel,
        dateStampStyle: _dateStampStyle.name,
        dateStampPosition: _dateStampPosition.name,
        dateStampEnabled: _dateStampEnabled,
      );
      await HiveService.photosBox.put(updatedPhoto.id, updatedPhoto.toMap());

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PreviewScreen(
            photo: updatedPhoto,
            processedBytes: result.bytes,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reprocess failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RetroColors.background,
      appBar: AppBar(
        title: const Text('EDITOR'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: RetroColors.accent,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _reprocess,
              child: Text(
                'DEVELOP',
                style: GoogleFonts.spaceMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: RetroColors.accent,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GrainOverlay(opacity: 0.03)),
          SingleChildScrollView(
            padding: const EdgeInsets.all(RetroDimens.paddingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Current Image Preview ────────────────────────────────
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
                    child: Image.file(
                      File(widget.photo.processedPath),
                      height: 260,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Film Stock ───────────────────────────────────────────
                _sectionTitle('FILM STOCK'),
                const SizedBox(height: 8),
                FilmStockSelector(
                  selectedStock: _selectedStock,
                  onStockChanged: (stock) {
                    setState(() => _selectedStock = stock);
                  },
                  compact: true,
                ),
                const SizedBox(height: 24),

                // ── Effect Controls ──────────────────────────────────────
                _sectionTitle('EFFECTS'),
                const SizedBox(height: 8),
                RetroSlider(
                  label: 'GRAIN',
                  icon: Icons.grain,
                  value: _grain,
                  onChanged: (v) => setState(() => _grain = v),
                ),
                RetroSlider(
                  label: 'LEAK',
                  icon: Icons.flare,
                  value: _leakStrength,
                  onChanged: (v) => setState(() => _leakStrength = v),
                ),
                RetroSlider(
                  label: 'SAT',
                  icon: Icons.palette,
                  value: _saturation,
                  min: 0,
                  max: 2.0,
                  onChanged: (v) => setState(() => _saturation = v),
                ),
                RetroSlider(
                  label: 'VIGNETTE',
                  icon: Icons.vignette,
                  value: _vignette,
                  onChanged: (v) => setState(() => _vignette = v),
                ),
                RetroSlider(
                  label: 'SCRATCH',
                  icon: Icons.brush,
                  value: _scratchLevel,
                  onChanged: (v) => setState(() => _scratchLevel = v),
                ),
                const SizedBox(height: 24),

                // ── Date Stamp ───────────────────────────────────────────
                _sectionTitle('DATE STAMP'),
                const SizedBox(height: 8),

                SwitchListTile(
                  title: Text(
                    'Show Date Stamp',
                    style: GoogleFonts.spaceMono(
                      fontSize: 12,
                      color: RetroColors.textPrimary,
                    ),
                  ),
                  value: _dateStampEnabled,
                  onChanged: (v) => setState(() => _dateStampEnabled = v),
                  activeColor: RetroColors.accent,
                  contentPadding: EdgeInsets.zero,
                ),

                if (_dateStampEnabled) ...[
                  // Style selector
                  _chipSelector<DateStampStyle>(
                    'Style',
                    DateStampStyle.values,
                    _dateStampStyle,
                    (s) => s.label,
                    (s) => setState(() => _dateStampStyle = s),
                  ),
                  const SizedBox(height: 12),

                  // Position selector
                  _chipSelector<DateStampPosition>(
                    'Position',
                    DateStampPosition.values,
                    _dateStampPosition,
                    (p) => p.label,
                    (p) => setState(() => _dateStampPosition = p),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.spaceMono(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: RetroColors.accent,
        letterSpacing: 2,
      ),
    );
  }

  Widget _chipSelector<T>(
    String label,
    List<T> values,
    T selected,
    String Function(T) labelGetter,
    ValueChanged<T> onSelected,
  ) {
    return Wrap(
      spacing: 8,
      children: values.map((value) {
        final isSelected = value == selected;
        return ChoiceChip(
          label: Text(
            labelGetter(value),
            style: GoogleFonts.spaceMono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : RetroColors.textSecondary,
            ),
          ),
          selected: isSelected,
          onSelected: (_) => onSelected(value),
          selectedColor: RetroColors.accent,
          backgroundColor: RetroColors.surface,
          side: BorderSide(
            color: isSelected
                ? RetroColors.accent
                : RetroColors.surfaceLight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        );
      }).toList(),
    );
  }
}
