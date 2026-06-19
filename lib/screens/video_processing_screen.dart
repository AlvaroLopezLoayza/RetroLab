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

  @override
  void initState() {
    super.initState();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted) return;
      setState(() {
        _progressValue = (_progressValue + 0.08).clamp(0.15, 0.92);
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
      await Gal.putVideo(result.processedFile.path, album: RetroStrings.appName);
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset(RetroAssets.lottieDeveloping, height: 120, reverse: true),
                const SizedBox(height: 40),
                Text(
                  _statusText,
                  style: GoogleFonts.spaceMono(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: RetroColors.accent,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 64),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progressValue,
                      backgroundColor: RetroColors.surfaceLight,
                      valueColor: const AlwaysStoppedAnimation(RetroColors.accent),
                      minHeight: 4,
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
