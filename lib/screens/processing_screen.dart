/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Processing Screen
///
/// "DEVELOPING..." screen shown while the image is being processed.
/// Displays a film reel animation and a fake developing timer.
/// ─────────────────────────────────────────────────────────────────────────────
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
    this.grain = 0.18,
    this.leakStrength = 0.6,
    this.dustStrength = 0.6,
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
      final result = await ImageProcessor.processRetroImage(
        widget.originalFile,
        filmStock: widget.filmStock,
        grain: widget.grain,
        leakStrength: widget.leakStrength,
        saturationOverride: widget.saturation,
        vignette: widget.vignette,
        scratchLevel: widget.scratchLevel,
        analogRandomness: HiveService.analogRandomnessEnabled,
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

      // Save photo metadata to Hive
      final photo = RetroPhoto(
        id: widget.photoId,
        originalPath: widget.originalFile.path,
        processedPath: result.file.path,
        filmStockId: widget.filmStock.id,
        rollId: widget.roll.id,
        capturedAt: DateTime.now(),
        grain: widget.grain,
        leakStrength: widget.leakStrength,
        saturation: widget.saturation,
        vignette: widget.vignette,
        scratchLevel: widget.scratchLevel,
        dateStampStyle: HiveService.dateStampStyle,
        dateStampPosition: HiveService.dateStampPosition,
        isImported: widget.isImported,
      );
      await HiveService.photosBox.put(photo.id, photo.toMap());

      // Ensure minimum display time for the developing experience
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      setState(() {
        _progressValue = 1.0;
        _statusText = 'READY!';
      });

      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;

      // Navigate to preview
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Film Reel Animation ──────────────────────────────────
                Lottie.asset(
                  RetroAssets.lottieDeveloping,
                  height: 120,
                  reverse: true,
                ),
                const SizedBox(height: 40),

                // ── DEVELOPING... Text ───────────────────────────────────
                Text(
                  RetroStrings.developing,
                  style: GoogleFonts.spaceMono(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: RetroColors.accent,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Status Text ──────────────────────────────────────────
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
                const SizedBox(height: 32),

                // ── Progress Bar ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 64),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progressValue,
                      backgroundColor: RetroColors.surfaceLight,
                      valueColor: const AlwaysStoppedAnimation(
                        RetroColors.accent,
                      ),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Film Stock Badge ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: widget.filmStock.badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(RetroDimens.radiusSm),
                    border: Border.all(
                      color: widget.filmStock.badgeColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    widget.filmStock.name,
                    style: GoogleFonts.spaceMono(
                      fontSize: 10,
                      color: widget.filmStock.badgeColor,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
