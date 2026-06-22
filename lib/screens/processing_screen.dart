library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../core/constants.dart';
import '../core/film_stocks.dart';
import '../core/hive_boxes.dart';
import '../models/film_roll.dart';
import '../models/retro_photo.dart';
import '../utils/image_processor.dart';
import '../widgets/grain_overlay.dart';
import 'preview_screen.dart';

class ProcessingScreen extends StatefulWidget {
  final File originalFile;
  final FilmStock filmStock;
  final FilmRoll roll;
  final String photoId;
  final double grain;
  final double leakStrength;
  final double dustStrength;
  final int lightLeakIndex;
  final double saturation;
  final double vignette;
  final double scratchLevel;
  final bool isImported;

  const ProcessingScreen({
    super.key,
    required this.originalFile,
    required this.filmStock,
    required this.roll,
    required this.photoId,
    this.grain = 0.10,
    this.leakStrength = 0.10,
    this.dustStrength = 0.05,
    this.lightLeakIndex = 0,
    this.saturation = 1.0,
    this.vignette = 0.3,
    this.scratchLevel = 0.0,
    this.isImported = false,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  double _progressValue = 0.0;
  Timer? _progressTimer;
  String _statusText = 'LOADING NEGATIVE...';

  final List<String> _statuses = [
    'LOADING NEGATIVE...',
    'APPLYING CHEMISTRY...',
    'DEVELOPING COLORS...',
    'FIXING IMAGE...',
    'DRYING...',
    'ALMOST READY...',
  ];

  String get _rollSummary =>
      '${widget.roll.usedExposures + 1}/${widget.roll.totalExposures}';

  @override
  void initState() {
    super.initState();
    _startProcessing();
    _startFakeProgress();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startFakeProgress() {
    int statusIndex = 0;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progressValue = (_progressValue + 0.15).clamp(0.0, 0.95);
        if (statusIndex < _statuses.length - 1 &&
            _progressValue > (statusIndex + 1) / _statuses.length) {
          statusIndex++;
          _statusText = _statuses[statusIndex];
        }
      });
    });
  }

  Future<void> _startProcessing() async {
    try {
      final capturedAt = DateTime.now();
      final result = await ImageProcessor.processRetroImage(
        widget.originalFile,
        filmStock: widget.filmStock,
        grain: widget.grain,
        leakStrength: widget.leakStrength,
        dustStrength: widget.dustStrength,
        lightLeakIndex: widget.lightLeakIndex,
        saturationOverride: widget.saturation,
        vignette: widget.vignette,
        scratchLevel: widget.scratchLevel,
        analogRandomness: HiveService.analogRandomnessEnabled,
        artifactSeed: widget.photoId.hashCode,
        captureDate: capturedAt,
        dateStampStyle: DateStampStyle.values.firstWhere(
          (s) => s.name == HiveService.dateStampStyle,
          orElse: () => DateStampStyle.classic90s,
        ),
        dateStampPosition: DateStampPosition.values.firstWhere(
          (p) => p.name == HiveService.dateStampPosition,
          orElse: () => DateStampPosition.bottomRight,
        ),
        saveLocationData: HiveService.saveLocationDataEnabled,
      );

      final photo = RetroPhoto(
        id: widget.photoId,
        originalPath: widget.originalFile.path,
        processedPath: result.file.path,
        filmStockId: widget.filmStock.id,
        rollId: widget.roll.id,
        capturedAt: capturedAt,
        grain: widget.grain,
        leakStrength: widget.leakStrength,
        dustStrength: widget.dustStrength,
        lightLeakIndex: widget.lightLeakIndex,
        saturation: widget.saturation,
        vignette: widget.vignette,
        scratchLevel: widget.scratchLevel,
        dateStampStyle: HiveService.dateStampStyle,
        dateStampPosition: HiveService.dateStampPosition,
        isImported: widget.isImported,
      );
      await HiveService.photosBox.put(photo.id, photo.toMap());

      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      setState(() {
        _progressValue = 1.0;
        _statusText = 'READY!';
      });

      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => PreviewScreen(photo: photo, processedBytes: result.bytes),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Processing failed: $e')));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RetroColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GrainOverlay(opacity: 0.05)),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(RetroDimens.paddingLg),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(RetroDimens.paddingLg),
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
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _statusChip(
                          widget.filmStock.shortName,
                          widget.filmStock.badgeColor,
                        ),
                        _statusChip(
                          'ROLL $_rollSummary',
                          RetroColors.dateYellow,
                        ),
                        _statusChip(
                          widget.isImported ? 'IMPORT' : 'CAMERA',
                          RetroColors.accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Lottie.asset(
                      RetroAssets.lottieDeveloping,
                      height: 120,
                      reverse: true,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      RetroStrings.developing,
                      style: GoogleFonts.spaceMono(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: RetroColors.accent,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Building the final frame with the selected film response.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: RetroColors.textSecondary,
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _statusText,
                        key: ValueKey(_statusText),
                        style: GoogleFonts.spaceMono(
                          fontSize: 11,
                          color: RetroColors.textMuted,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: _progressValue,
                        backgroundColor: RetroColors.surfaceLight,
                        valueColor: const AlwaysStoppedAnimation(
                          RetroColors.accent,
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${(_progressValue * 100).round()}%',
                        style: GoogleFonts.spaceMono(
                          fontSize: 11,
                          color: RetroColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
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
}
