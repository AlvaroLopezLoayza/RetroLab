library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../core/constants.dart';
import '../core/hive_boxes.dart';
import '../models/retro_video.dart';
import '../utils/video_processor.dart';
import '../widgets/grain_overlay.dart';
import 'lab_screen.dart';

class VideoProcessingScreen extends StatefulWidget {
  final File rawFile;
  final String videoId;
  final VideoEffectSettings settings;

  const VideoProcessingScreen({
    super.key,
    required this.rawFile,
    required this.videoId,
    required this.settings,
  });

  @override
  State<VideoProcessingScreen> createState() => _VideoProcessingScreenState();
}

class _VideoProcessingScreenState extends State<VideoProcessingScreen> {
  Timer? _progressTimer;
  double _progressValue = 0.15;
  String _statusText = 'REVELANDO VIDEO...';
  final List<String> _statuses = [
    'PREPARANDO CLIP...',
    'APLICANDO LOOK...',
    'SUMANDO ARTEFACTOS...',
    'EXPORTANDO MASTER...',
    'GUARDANDO EN LAB...',
  ];

  @override
  void initState() {
    super.initState();
    var statusIndex = 0;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted) return;
      setState(() {
        _progressValue = (_progressValue + 0.08).clamp(0.15, 0.92);
        if (statusIndex < _statuses.length - 1 &&
            _progressValue > (statusIndex + 2) / (_statuses.length + 1)) {
          statusIndex++;
          _statusText = _statuses[statusIndex];
        }
      });
    });
    _process();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _process() async {
    try {
      final result = await VideoProcessor.processVideo(
        widget.rawFile,
        outputId: widget.videoId,
        settings: widget.settings,
      );
      await Gal.putVideo(
        result.processedFile.path,
        album: RetroStrings.appName,
      );
      final video = RetroVideo(
        id: widget.videoId,
        rawPath: widget.rawFile.path,
        processedPath: result.processedFile.path,
        thumbnailPath: result.thumbnailFile.path,
        filmStockId: widget.settings.stock.id,
        capturedAt: DateTime.now(),
        durationMs: result.durationMs,
        grain: widget.settings.grain,
        leakStrength: widget.settings.leakStrength,
        dustStrength: widget.settings.dustStrength,
        lightLeakIndex: widget.settings.lightLeakIndex,
        saturation: widget.settings.saturation,
        vignette: widget.settings.vignette,
        scratchLevel: widget.settings.scratchLevel,
      );
      await HiveService.videosBox.put(video.id, video.toMap());
      if (widget.rawFile.existsSync()) {
        await widget.rawFile.delete();
      }
      if (!mounted) return;
      setState(() {
        _progressValue = 1.0;
        _statusText = 'LISTO';
      });
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LabScreen(initialTab: 1)),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      final retry = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: RetroColors.surface,
            title: Text(
              'No se pudo procesar',
              style: GoogleFonts.spaceMono(color: RetroColors.textPrimary),
            ),
            content: Text(
              'Puedes reintentar o descartar el clip crudo.',
              style: GoogleFonts.inter(color: RetroColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('DESCARTAR'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('REINTENTAR'),
              ),
            ],
          );
        },
      );
      if (retry == true) {
        _process();
        return;
      }
      if (widget.rawFile.existsSync()) {
        await widget.rawFile.delete();
      }
      if (!mounted) return;
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
                          widget.settings.stock.shortName,
                          widget.settings.stock.badgeColor,
                        ),
                        _statusChip('VIDEO', RetroColors.accent),
                        _statusChip(
                          'GRAIN ${(widget.settings.grain * 100).round()}%',
                          RetroColors.dateYellow,
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
                      'VIDEO LAB',
                      style: GoogleFonts.spaceMono(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: RetroColors.accent,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        _statusText,
                        key: ValueKey(_statusText),
                        style: GoogleFonts.spaceMono(
                          fontSize: 11,
                          color: RetroColors.textSecondary,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Applying the same analog treatment to the exported clip.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: RetroColors.textSecondary,
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
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
