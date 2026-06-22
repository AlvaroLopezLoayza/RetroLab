library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/film_stocks.dart';
import '../core/hive_boxes.dart';
import '../models/retro_photo.dart';
import '../utils/image_processor.dart';
import '../widgets/film_preview.dart';
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
  late double _dustStrength;
  late int _lightLeakIndex;
  late double _saturation;
  late double _vignette;
  late double _scratchLevel;
  late bool _dateStampEnabled;
  late DateStampStyle _dateStampStyle;
  late DateStampPosition _dateStampPosition;

  bool _isProcessing = false;

  String get _dateStampSummary =>
      _dateStampEnabled
          ? '${_dateStampStyle.label} · ${_dateStampPosition.label}'
          : 'Disabled';

  String get _randomnessSummary =>
      HiveService.analogRandomnessEnabled ? 'Enabled' : 'Disabled';

  @override
  void initState() {
    super.initState();
    _selectedStock = FilmStocks.getById(widget.photo.filmStockId);
    _grain = widget.photo.grain;
    _leakStrength = widget.photo.leakStrength;
    _dustStrength = widget.photo.dustStrength;
    _lightLeakIndex = widget.photo.lightLeakIndex;
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
        dustStrength: _dustStrength,
        lightLeakIndex: _lightLeakIndex,
        saturationOverride: _saturation,
        vignette: _vignette,
        scratchLevel: _scratchLevel,
        dateStampEnabled: _dateStampEnabled,
        dateStampStyle: _dateStampStyle,
        dateStampPosition: _dateStampPosition,
        analogRandomness: HiveService.analogRandomnessEnabled,
        artifactSeed: widget.photo.id.hashCode,
        captureDate: widget.photo.capturedAt,
      );

      final updatedPhoto = widget.photo.copyWith(
        processedPath: result.file.path,
        filmStockId: _selectedStock.id,
        grain: _grain,
        leakStrength: _leakStrength,
        dustStrength: _dustStrength,
        lightLeakIndex: _lightLeakIndex,
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
          builder:
              (_) => PreviewScreen(
                photo: updatedPhoto,
                processedBytes: result.bytes,
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reprocess failed: $e')));
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
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.16),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.28),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(RetroDimens.paddingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCard(),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: RetroColors.surface,
                    borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.24),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
                    child: SizedBox(
                      height: 260,
                      width: double.infinity,
                      child: FilmPreview(
                        stock: _selectedStock,
                        grain: _grain,
                        leakStrength: _leakStrength,
                        dustStrength: _dustStrength,
                        saturation: _saturation,
                        vignette: _vignette,
                        scratchLevel: _scratchLevel,
                        lightLeakIndex: _lightLeakIndex,
                        analogRandomness: HiveService.analogRandomnessEnabled,
                        artifactSeed: widget.photo.id.hashCode,
                        child: Image.file(
                          File(widget.photo.originalPath),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _sectionCard(
                  title: 'LOOK',
                  subtitle: 'Film stock and overall response curve.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FilmStockSelector(
                        selectedStock: _selectedStock,
                        onStockChanged: (stock) {
                          setState(() {
                            _selectedStock = stock;
                            _saturation = stock.saturation;
                            _vignette = stock.baseVignette;
                            _lightLeakIndex = stock.id.hashCode.abs() % 42;
                          });
                        },
                        compact: true,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _summaryChip(
                            _selectedStock.shortName,
                            _selectedStock.badgeColor,
                          ),
                          _summaryChip(
                            'SAT ${_saturation.toStringAsFixed(2)}',
                            RetroColors.accent,
                          ),
                          _summaryChip(
                            'VIG ${_vignette.toStringAsFixed(2)}',
                            Colors.white70,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _sectionCard(
                  title: 'TEXTURE',
                  subtitle: 'Analog imperfections and tone adjustments.',
                  child: Column(
                    children: [
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
                        label: 'DUST',
                        icon: Icons.blur_on,
                        value: _dustStrength,
                        onChanged: (v) => setState(() => _dustStrength = v),
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
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _sectionCard(
                  title: 'DATE STAMP',
                  subtitle:
                      'Overlay metadata with the same final output settings.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        title: Text(
                          'Show Date Stamp',
                          style: GoogleFonts.spaceMono(
                            fontSize: 12,
                            color: RetroColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          _dateStampSummary,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: RetroColors.textSecondary,
                          ),
                        ),
                        value: _dateStampEnabled,
                        onChanged: (v) => setState(() => _dateStampEnabled = v),
                        activeThumbColor: RetroColors.accent,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _summaryChip(
                            'RANDOMNESS $_randomnessSummary',
                            RetroColors.dateYellow,
                          ),
                          _summaryChip(
                            _dateStampEnabled ? 'STAMP ON' : 'STAMP OFF',
                            _dateStampEnabled
                                ? RetroColors.success
                                : Colors.white70,
                          ),
                        ],
                      ),
                      if (_dateStampEnabled) ...[
                        const SizedBox(height: 16),
                        _fieldLabel('STYLE'),
                        const SizedBox(height: 10),
                        _chipSelector<DateStampStyle>(
                          DateStampStyle.values,
                          _dateStampStyle,
                          (s) => s.label,
                          (s) => setState(() => _dateStampStyle = s),
                        ),
                        const SizedBox(height: 16),
                        _fieldLabel('POSITION'),
                        const SizedBox(height: 10),
                        _chipSelector<DateStampPosition>(
                          DateStampPosition.values,
                          _dateStampPosition,
                          (p) => p.label,
                          (p) => setState(() => _dateStampPosition = p),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
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
            'FINE TUNE THIS FRAME',
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: RetroColors.accent,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _selectedStock.name,
            style: GoogleFonts.spaceMono(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: RetroColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Preview stays close to final output while keeping edits fast.',
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
              _summaryChip(
                widget.photo.isImported ? 'IMPORTED' : 'CAMERA FRAME',
                RetroColors.accent,
              ),
              _summaryChip(
                'RANDOMNESS $_randomnessSummary',
                RetroColors.dateYellow,
              ),
              _summaryChip(
                _dateStampEnabled ? 'STAMP READY' : 'NO STAMP',
                _dateStampEnabled ? RetroColors.success : Colors.white70,
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
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _fieldLabel(String title) {
    return Text(
      title,
      style: GoogleFonts.spaceMono(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: RetroColors.textPrimary,
        letterSpacing: 1.0,
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

  Widget _chipSelector<T>(
    List<T> values,
    T selected,
    String Function(T) labelGetter,
    ValueChanged<T> onSelected,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          values.map((value) {
            final isSelected = value == selected;
            return ChoiceChip(
              label: Text(
                labelGetter(value),
                style: GoogleFonts.spaceMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : RetroColors.textSecondary,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => onSelected(value),
              selectedColor: RetroColors.accent,
              backgroundColor: RetroColors.background.withValues(alpha: 0.65),
              side: BorderSide(
                color:
                    isSelected ? RetroColors.accent : RetroColors.surfaceLight,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            );
          }).toList(),
    );
  }
}
