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
      (style) => style.name == widget.photo.dateStampStyle,
      orElse: () => DateStampStyle.classic90s,
    );
    _dateStampPosition = DateStampPosition.values.firstWhere(
      (position) => position.name == widget.photo.dateStampPosition,
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reprocess failed: $error')));
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
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(flex: 5, child: _previewPane()),
            Expanded(flex: 4, child: _controlsPane()),
          ],
        ),
      ),
      bottomNavigationBar: _developBar(),
    );
  }

  Widget _previewPane() {
    return Stack(
      fit: StackFit.expand,
      children: [
        FilmPreview(
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
          child: ColoredBox(
            color: Colors.black,
            child: Image.file(
              File(widget.photo.originalPath),
              fit: BoxFit.contain,
            ),
          ),
        ),
        const Positioned.fill(child: GrainOverlay(opacity: 0.025)),
        Positioned(
          left: 16,
          right: 16,
          top: 12,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip(_selectedStock.shortName, _selectedStock.badgeColor),
              _summaryChip(
                widget.photo.isImported ? 'IMPORTED' : 'CAMERA',
                RetroColors.accent,
              ),
              _summaryChip(
                _dateStampEnabled ? 'STAMP ON' : 'STAMP OFF',
                _dateStampEnabled ? RetroColors.success : Colors.white70,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _controlsPane() {
    return DefaultTabController(
      length: 3,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: RetroColors.surfaceLight)),
        ),
        child: Column(
          children: [
            TabBar(
              labelColor: RetroColors.accent,
              unselectedLabelColor: RetroColors.textSecondary,
              indicatorColor: RetroColors.accent,
              labelStyle: GoogleFonts.spaceMono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
              tabs: const [
                Tab(icon: Icon(Icons.camera_roll), text: 'LOOK'),
                Tab(icon: Icon(Icons.tune), text: 'TEXTURE'),
                Tab(icon: Icon(Icons.date_range), text: 'DATE'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _scrollTab(_lookControls()),
                  _scrollTab(_textureControls()),
                  _scrollTab(_dateControls()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scrollTab(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: child,
    );
  }

  Widget _lookControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilmStockSelector(
          selectedStock: _selectedStock,
          onStockChanged: (stock) {
            setState(() {
              _selectedStock = stock;
              _saturation = stock.saturation;
              _lightLeakIndex = stock.id.hashCode.abs() % 42;
              _resetTextureDefaults();
            });
          },
          compact: true,
        ),
        const SizedBox(height: 14),
        RetroSlider(
          label: 'SAT',
          icon: Icons.palette,
          value: _saturation,
          min: 0,
          max: 2.0,
          onChanged: (value) => setState(() => _saturation = value),
        ),
      ],
    );
  }

  Widget _textureControls() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'DEFAULTS 58 / 35 / 100',
                style: GoogleFonts.spaceMono(
                  fontSize: 10,
                  color: RetroColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(_resetTextureDefaults),
              icon: const Icon(Icons.restart_alt, size: 16),
              label: const Text('RESET'),
            ),
          ],
        ),
        RetroSlider(
          label: 'GRAIN',
          icon: Icons.grain,
          value: _grain,
          onChanged: (value) => setState(() => _grain = value),
        ),
        RetroSlider(
          label: 'LEAK',
          icon: Icons.flare,
          value: _leakStrength,
          onChanged: (value) => setState(() => _leakStrength = value),
        ),
        RetroSlider(
          label: 'DUST',
          icon: Icons.blur_on,
          value: _dustStrength,
          onChanged: (value) => setState(() => _dustStrength = value),
        ),
        RetroSlider(
          label: 'VIGN',
          icon: Icons.vignette,
          value: _vignette,
          onChanged: (value) => setState(() => _vignette = value),
        ),
        RetroSlider(
          label: 'SCRATCH',
          icon: Icons.brush,
          value: _scratchLevel,
          onChanged: (value) => setState(() => _scratchLevel = value),
        ),
      ],
    );
  }

  Widget _dateControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(
            'Date stamp',
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
          onChanged: (value) => setState(() => _dateStampEnabled = value),
          activeColor: RetroColors.accent,
          contentPadding: EdgeInsets.zero,
        ),
        if (_dateStampEnabled) ...[
          const SizedBox(height: 12),
          _fieldLabel('STYLE'),
          const SizedBox(height: 10),
          _chipSelector<DateStampStyle>(
            DateStampStyle.values,
            _dateStampStyle,
            (style) => style.label,
            (style) => setState(() => _dateStampStyle = style),
          ),
          const SizedBox(height: 18),
          _fieldLabel('POSITION'),
          const SizedBox(height: 10),
          _chipSelector<DateStampPosition>(
            DateStampPosition.values,
            _dateStampPosition,
            (position) => position.label,
            (position) => setState(() => _dateStampPosition = position),
          ),
        ],
      ],
    );
  }

  Widget _developBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isProcessing ? null : _reprocess,
            icon:
                _isProcessing
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.auto_fix_high),
            label: Text(
              _isProcessing ? 'DEVELOPING' : 'DEVELOP',
              style: GoogleFonts.spaceMono(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _resetTextureDefaults() {
    _grain = RetroDefaults.grain;
    _leakStrength = RetroDefaults.leakStrength;
    _dustStrength = RetroDefaults.dustStrength;
    _vignette = RetroDefaults.vignette;
    _scratchLevel = RetroDefaults.scratchLevel;
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
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(RetroDimens.radiusXl),
        border: Border.all(color: color.withValues(alpha: 0.42)),
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
              backgroundColor: RetroColors.surface,
              side: BorderSide(
                color:
                    isSelected ? RetroColors.accent : RetroColors.surfaceLight,
              ),
            );
          }).toList(),
    );
  }
}
