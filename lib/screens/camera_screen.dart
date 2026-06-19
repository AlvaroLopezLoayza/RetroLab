/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Camera Screen (v2 — Live FX Preview)
///
/// Changes over v1:
///   • _buildColorFilter now accepts all slider overrides (_saturation,
///     _vignette etc.) — previously it only read the film stock defaults,
///     so slider changes had zero effect on the live preview.
///   • GrainOverlay driven by _grain slider (was hardcoded to stock.baseGrain).
///   • Light leak preview overlay added — _leakStrength now visually affects
///     the live preview with an animated warm/cool color wash.
///   • Scratch overlay added as scanline noise, driven by _scratchLevel.
///   • Vignette gradient already used _vignette — kept, but alpha formula
///     tightened so it matches the processor's 0.4-radius rolloff.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/constants.dart';
import '../core/film_stocks.dart';
import '../core/hive_boxes.dart';
import '../models/film_roll.dart';
import '../utils/video_processor.dart';
import '../widgets/film_preview.dart';
import '../widgets/film_stock_selector.dart';
import '../widgets/retro_slider.dart';
import '../widgets/shutter_button.dart';
import '../widgets/viewfinder_overlay.dart';
import 'lab_screen.dart';
import 'processing_screen.dart';
import 'video_processing_screen.dart';

enum CaptureMode { photo, video }

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // ── Camera ─────────────────────────────────────────────────────────────
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  bool _isCameraReady = false;
  CaptureMode _captureMode = CaptureMode.photo;
  bool _isRecordingVideo = false;
  bool _isProcessingVideo = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  // ── Film State ─────────────────────────────────────────────────────────
  FilmStock _selectedStock = FilmStocks.kodakGold200;
  late FilmRoll _currentRoll;
  bool _showFilmSelector = false;
  bool _showControls = false;
  final ScrollController _filmSelectorScrollController = ScrollController();

  // ── Effect Controls ────────────────────────────────────────────────────
  double _grain = 0.10;
  double _leakStrength = 0.10;
  double _dustStrength = 0.05;
  double _saturation = 1.0;
  double _vignette = 0.3;
  double _scratchLevel = 0.0;
  int _lightLeakIndex = 0;

  // ── Light Leak Preview Animation ──────────────────────────────────────
  // Animates the leak overlay so it feels alive on the preview, not static.

  // ── Timer & Burst ──────────────────────────────────────────────────────
  ShutterTimer _shutterTimer = ShutterTimer.off;
  bool _isBurstMode = false;
  bool _isCapturing = false;
  int _timerCountdown = 0;

  // ── Audio ──────────────────────────────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ── Grid / Flash ───────────────────────────────────────────────────────
  bool _showGrid = false;
  FlashMode _flashMode = FlashMode.off;

  // ── Tap-to-Focus ───────────────────────────────────────────────────────
  Offset? _focusPoint; // Position of the last focus tap (screen coords)
  late final AnimationController _focusAnimController;
  late final Animation<double> _focusScaleAnim;
  late final Animation<double> _focusOpacityAnim;

  // ── Texture Cache (WYSIWYG Preview) ────────────────────────────────────
  // Pre-decoded ui.Image objects for real-time overlay rendering.
  // Stored as ui.Image (not raw bytes) to avoid expensive decoding on every paint.

  bool get _videoSupported => Platform.isAndroid;
  bool get _isVideoMode => _captureMode == CaptureMode.video;
  bool get _isBusy => _isCapturing || _isProcessingVideo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Slow breathing animation for light leak overlay
    // Focus indicator animation (scale + fade out)
    _focusAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _focusScaleAnim = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _focusAnimController, curve: Curves.easeOut),
    );
    _focusOpacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _focusAnimController, curve: Curves.easeOut),
    );

    _loadOrCreateRoll();
    _initializeEffectsFromFilmStock();
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _cameraController?.dispose();
    _audioPlayer.dispose();
    _focusAnimController.dispose();
    _filmSelectorScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedFilm() {
    final index = FilmStocks.all.indexWhere((s) => s.id == _selectedStock.id);
    if (index >= 0 && _filmSelectorScrollController.hasClients) {
      _filmSelectorScrollController.animateTo(
        index * 95.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      if (_isRecordingVideo) {
        _stopVideoRecording(fromLifecycle: true);
      }
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  // ── Initialization ─────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    if (await Permission.camera.isDenied) {
      if (!mounted) return;
      bool? consent = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: RetroColors.surface,
              title: Text(
                'Acceso a la Cámara',
                style: GoogleFonts.spaceMono(color: RetroColors.textPrimary),
              ),
              content: Text(
                'RetroLab necesita acceso a la cámara para capturar tus momentos analógicos. '
                'Las operaciones son sin conexión y el hardware solo se activa con la app abierta.',
                style: GoogleFonts.inter(color: RetroColors.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    'DENEGAR',
                    style: GoogleFonts.spaceMono(color: RetroColors.textMuted),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RetroColors.accent,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    'PERMITIR',
                    style: GoogleFonts.spaceMono(
                      color: RetroColors.background,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
      );
      if (consent != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Se requiere permiso de cámara para tomar fotos.'),
            ),
          );
        }
        return;
      }
    }

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se requiere permiso de cámara')),
        );
      }
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw Exception('No se encontraron cámaras');
      await _setupCamera(_cameras[_currentCameraIndex]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fallo al inicializar la cámara: $e')),
        );
      }
    }
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    if (mounted) {
      setState(() => _isCameraReady = false);
    }
    _cameraController?.dispose();
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: _isVideoMode,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(_flashMode);
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _loadOrCreateRoll() {
    final rollsBox = HiveService.rollsBox;
    FilmRoll? activeRoll;
    for (int i = 0; i < rollsBox.length; i++) {
      final map = rollsBox.getAt(i);
      if (map != null) {
        final roll = FilmRoll.fromMap(Map<String, dynamic>.from(map));
        if (!roll.isFinished) {
          activeRoll = roll;
          break;
        }
      }
    }
    if (activeRoll != null) {
      _currentRoll = activeRoll;
      _selectedStock = FilmStocks.getById(activeRoll.filmStockId);
    } else {
      _createNewRoll();
    }
  }

  void _createNewRoll() {
    _currentRoll = FilmRoll(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      filmStockId: _selectedStock.id,
      loadedAt: DateTime.now(),
    );
    HiveService.rollsBox.put(_currentRoll.id, _currentRoll.toMap());
    HiveService.incrementRolls();
  }

  void _initializeEffectsFromFilmStock({bool resetTextures = true}) {
    setState(() {
      _vignette = _selectedStock.baseVignette;
      _saturation = _selectedStock.saturation;
      if (resetTextures) {
        _grain = 0.10;
        _leakStrength = 0.10;
        _dustStrength = 0.05;
      }
      _scratchLevel = 0.0;
      _lightLeakIndex = _selectedStock.id.hashCode.abs() % 42;
    });
  }

  Future<bool> _ensureMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se requiere micrófono para grabar video.')),
      );
    }
    return false;
  }

  Future<void> _setCaptureMode(CaptureMode mode) async {
    if (!_videoSupported && mode == CaptureMode.video) return;
    if (_captureMode == mode || _isBusy || _isRecordingVideo) return;
    if (mode == CaptureMode.video && !await _ensureMicrophonePermission()) {
      return;
    }
    setState(() {
      _captureMode = mode;
      _showControls = false;
      _showFilmSelector = false;
      _timerCountdown = 0;
      if (mode == CaptureMode.video) {
        _isBurstMode = false;
        _shutterTimer = ShutterTimer.off;
      }
    });
    if (_cameras.isNotEmpty) {
      await _setupCamera(_cameras[_currentCameraIndex]);
    }
  }

  /// Handle tap-to-focus on the camera preview.
  /// Sets focus point and shows animated focus indicator.
  Future<void> _handleTapToFocus(TapDownDetails details) async {
    if (!_isCameraReady || _cameraController == null) return;

    // Store the tap position for the focus indicator
    setState(() {
      _focusPoint = details.localPosition;
    });

    // Animate the focus indicator
    _focusAnimController.forward(from: 0.0);

    // Convert screen coordinates to camera coordinates (normalized 0.0-1.0)
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    // Calculate normalized coordinates
    final x = details.localPosition.dx / size.width;
    final y = details.localPosition.dy / size.height;

    try {
      // Set focus point (x, y are normalized to 0.0-1.0)
      await _cameraController!.setFocusPoint(Offset(x, y));
      // Optionally also set exposure point to the same location
      await _cameraController!.setExposurePoint(Offset(x, y));

      if (mounted) {
        // Brief haptic feedback
        await HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Focus error: $e');
    }
  }

  // ── Capture Logic ──────────────────────────────────────────────────────

  Future<void> _onShutterPressed() async {
    if (_isBusy) return;
    if (_isVideoMode) {
      if (_isRecordingVideo) {
        await _stopVideoRecording();
      } else {
        await _startVideoRecording();
      }
      return;
    }
    if (_currentRoll.isFinished) {
      _showFilmFinishedDialog();
      return;
    }

    if (_shutterTimer != ShutterTimer.off) {
      setState(() => _timerCountdown = _shutterTimer.seconds);
      for (int i = _shutterTimer.seconds; i > 0; i--) {
        if (!mounted) return;
        setState(() => _timerCountdown = i);
        await Future.delayed(const Duration(seconds: 1));
      }
      setState(() => _timerCountdown = 0);
    }

    if (_isBurstMode) {
      for (int i = 0; i < 3; i++) {
        await _capturePhoto();
        if (i < 2) await Future.delayed(const Duration(milliseconds: 400));
        if (_currentRoll.isFinished) break;
      }
    } else {
      await _capturePhoto();
    }
  }

  Future<void> _startVideoRecording() async {
    if (!_isCameraReady || _cameraController == null) return;
    setState(() {
      _isRecordingVideo = true;
      _recordingSeconds = 0;
      _showControls = false;
      _showFilmSelector = false;
    });
    try {
      await _cameraController!.startVideoRecording();
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        final next = _recordingSeconds + 1;
        if (next >= 30) {
          _stopVideoRecording();
          return;
        }
        setState(() => _recordingSeconds = next);
      });
    } catch (e) {
      _recordingTimer?.cancel();
      if (mounted) {
        setState(() => _isRecordingVideo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar video: $e')),
        );
      }
    }
  }

  Future<void> _stopVideoRecording({bool fromLifecycle = false}) async {
    if (_cameraController == null || !_isRecordingVideo) return;
    _recordingTimer?.cancel();
    setState(() {
      _isRecordingVideo = false;
      _isProcessingVideo = !fromLifecycle;
    });
    try {
      final xFile = await _cameraController!.stopVideoRecording();
      if (fromLifecycle || !mounted) return;
      final settings = VideoEffectSettings(
        stock: _selectedStock,
        grain: _grain,
        leakStrength: _leakStrength,
        dustStrength: _dustStrength,
        lightLeakIndex: _lightLeakIndex,
        saturation: _saturation,
        vignette: _vignette,
        scratchLevel: _scratchLevel,
      );
      final videoId = DateTime.now().millisecondsSinceEpoch.toString();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) {
            return VideoProcessingScreen(
              rawFile: File(xFile.path),
              videoId: videoId,
              settings: settings,
            );
          },
        ),
      );
    } catch (e) {
      if (!fromLifecycle && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al detener video: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingVideo = false;
          _recordingSeconds = 0;
        });
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (!_isCameraReady || _cameraController == null) return;
    setState(() => _isCapturing = true);

    try {
      _playShutterSound();
      final xFile = await _cameraController!.takePicture();
      final file = File(xFile.path);

      final photoId = DateTime.now().millisecondsSinceEpoch.toString();
      _currentRoll = _currentRoll.withExposureTaken(photoId);
      await HiveService.rollsBox.put(_currentRoll.id, _currentRoll.toMap());
      await HiveService.incrementShots();
      await HiveService.recordStockUsage(_selectedStock.id);

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => ProcessingScreen(
                originalFile: file,
                filmStock: _selectedStock,
                roll: _currentRoll,
                photoId: photoId,
                grain: _grain,
                leakStrength: _leakStrength,
                dustStrength: _dustStrength,
                lightLeakIndex: _lightLeakIndex,
                saturation: _saturation,
                vignette: _vignette,
                scratchLevel: _scratchLevel,
              ),
        ),
      );
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al capturar la foto: $e'),
            backgroundColor: RetroColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _playShutterSound() {
    try {
      _audioPlayer.play(
        AssetSource(RetroAssets.soundShutter.replaceFirst('assets/', '')),
      );
    } catch (_) {}
  }

  Future<void> _importFromGallery() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile == null) return;

    final file = File(xFile.path);
    final photoId = DateTime.now().millisecondsSinceEpoch.toString();

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ProcessingScreen(
              originalFile: file,
              filmStock: _selectedStock,
              roll: _currentRoll,
              photoId: photoId,
              grain: _grain,
              leakStrength: _leakStrength,
              dustStrength: _dustStrength,
              lightLeakIndex: _lightLeakIndex,
              saturation: _saturation,
              vignette: _vignette,
              scratchLevel: _scratchLevel,
              isImported: true,
            ),
      ),
    );
  }

  void _flipCamera() {
    if (_cameras.length < 2 || _isRecordingVideo) return;
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    _setupCamera(_cameras[_currentCameraIndex]);
  }

  void _cycleFlash() {
    final modes =
        _isVideoMode
            ? [FlashMode.off, FlashMode.torch]
            : [FlashMode.off, FlashMode.auto, FlashMode.always];
    final currentIndex = modes.indexOf(_flashMode);
    _flashMode = modes[(currentIndex + 1) % modes.length];
    _cameraController?.setFlashMode(_flashMode);
    setState(() {});
  }

  void _cycleTimer() {
    if (_isVideoMode) return;
    final timers = ShutterTimer.values;
    setState(() {
      _shutterTimer =
          timers[(timers.indexOf(_shutterTimer) + 1) % timers.length];
    });
  }

  void _showFilmFinishedDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: RetroColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
            ),
            title: Text(
              RetroStrings.filmFinished,
              style: GoogleFonts.spaceMono(color: RetroColors.accent),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.camera_roll,
                  size: 64,
                  color: RetroColors.dateYellow,
                ),
                const SizedBox(height: 16),
                Text(
                  '¡Tu rollo ${_selectedStock.name} está totalmente expuesto!\n'
                  'Carga un nuevo rollo para seguir disparando.',
                  style: GoogleFonts.inter(
                    color: RetroColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('VER LAB'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _createNewRoll();
                  setState(() {});
                },
                child: const Text(RetroStrings.loadNewRoll),
              ),
            ],
          ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RetroColors.background,
      body: Stack(
        children: [
          // ── Camera Preview with Film Color Grade ───────────────────────
          if (_isCameraReady && _cameraController != null)
            Positioned.fill(
              child: ClipRect(
                child: GestureDetector(
                  onTapDown: _handleTapToFocus,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _cameraController!.value.previewSize?.height ?? 1,
                      height: _cameraController!.value.previewSize?.width ?? 1,
                      child: FilmPreview(
                        stock: _selectedStock,
                        grain: _grain,
                        leakStrength: _leakStrength,
                        dustStrength: _dustStrength,
                        saturation: _saturation,
                        vignette: _vignette,
                        scratchLevel: _scratchLevel,
                        lightLeakIndex: _lightLeakIndex,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Center(
                child: Text(
                  '[ CALENTANDO SENSOR... ]',
                  style: GoogleFonts.spaceMono(
                    color: RetroColors.accent,
                    fontSize: 14,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // ── Tap-to-Focus Indicator ─────────────────────────────────────
          if (_focusPoint != null)
            Positioned(
              left: _focusPoint!.dx - 50,
              top: _focusPoint!.dy - 50,
              child: ScaleTransition(
                scale: _focusScaleAnim,
                child: FadeTransition(
                  opacity: _focusOpacityAnim,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      border: Border.all(color: RetroColors.accent, width: 2.0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.center_focus_strong,
                        color: RetroColors.accent,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Viewfinder Overlay ─────────────────────────────────────────
          Positioned.fill(
            child: ViewfinderOverlay(
              filmStock: _selectedStock,
              remainingExposures:
                  _isVideoMode ? 0 : _currentRoll.remainingExposures,
              showGrid: _showGrid,
            ),
          ),

          if (_isRecordingVideo)
            Positioned(
              top: 56,
              left: 16,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(RetroDimens.radiusSm),
                    border: Border.all(color: RetroColors.error),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: RetroColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _recordingLabel,
                        style: GoogleFonts.spaceMono(
                          color: RetroColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Timer Countdown ────────────────────────────────────────────
          if (_timerCountdown > 0)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Center(
                  child: Text(
                    '$_timerCountdown',
                    style: GoogleFonts.spaceMono(
                      fontSize: 120,
                      fontWeight: FontWeight.w700,
                      color: RetroColors.accent,
                    ),
                  ),
                ),
              ),
            ),

          // ── Controls Panel ─────────────────────────────────────────────
          if (_showControls)
            Positioned(
              bottom: 160,
              left: 0,
              right: 0,
              child: _buildControlsPanel(),
            ),

          // ── Film Stock Selector ────────────────────────────────────────
          Positioned(
            bottom: 160,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_showFilmSelector,
              child: AnimatedOpacity(
                opacity: _showFilmSelector ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: RetroColors.background.withValues(alpha: 0.9),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: FilmStockSelector(
                    controller: _filmSelectorScrollController,
                    selectedStock: _selectedStock,
                    onStockChanged: (stock) {
                      setState(() {
                        _selectedStock = stock;
                        _showFilmSelector = false;
                        _currentRoll = _currentRoll.copyWith(
                          filmStockId: stock.id,
                        );
                      });
                      HiveService.rollsBox.put(
                        _currentRoll.id,
                        _currentRoll.toMap(),
                      );
                      _initializeEffectsFromFilmStock(resetTextures: false);
                    },
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom Bar ─────────────────────────────────────────────────
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),

          // ── Top Action Bar ─────────────────────────────────────────────
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(RetroDimens.paddingSm),
                child: Column(
                  children: [
                    _iconButton(
                      _flashIcon,
                      _cycleFlash,
                      tooltip: 'Flash: ${_flashMode.name}',
                    ),
                    _iconButton(
                      Icons.grid_3x3,
                      () => setState(() => _showGrid = !_showGrid),
                      active: _showGrid,
                      tooltip: 'Cuadrícula',
                    ),
                    _iconButton(
                      Icons.flip_camera_ios,
                      _flipCamera,
                      tooltip: 'Cambiar Cámara',
                    ),
                    _iconButton(
                      Icons.timer,
                      _cycleTimer,
                      active:
                          !_isVideoMode && _shutterTimer != ShutterTimer.off,
                      label: _shutterTimer.label,
                      tooltip: 'Temporizador',
                    ),
                    _iconButton(
                      Icons.burst_mode,
                      () => setState(() => _isBurstMode = !_isBurstMode),
                      active: !_isVideoMode && _isBurstMode,
                      tooltip: 'Modo Ráfaga',
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

  // ── Widgets ────────────────────────────────────────────────────────────

  IconData get _flashIcon => switch (_flashMode) {
    FlashMode.auto => Icons.flash_auto,
    FlashMode.torch => Icons.flashlight_on,
    FlashMode.always => Icons.flash_on,
    _ => Icons.flash_off,
  };

  String get _recordingLabel {
    final minutes = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _modeButton(CaptureMode mode, String label) {
    final active = _captureMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap:
            _isBusy || _isRecordingVideo ? null : () => _setCaptureMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:
                active
                    ? RetroColors.accent.withValues(alpha: 0.2)
                    : RetroColors.surface,
            borderRadius: BorderRadius.circular(RetroDimens.radiusSm),
            border: Border.all(
              color: active ? RetroColors.accent : RetroColors.surfaceLight,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active ? RetroColors.accent : RetroColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconButton(
    IconData icon,
    VoidCallback onPressed, {
    bool active = false,
    String? label,
    String? tooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: tooltip ?? '',
        child: GestureDetector(
          onTap: _isRecordingVideo ? null : onPressed,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color:
                  active
                      ? RetroColors.accent.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border:
                  active
                      ? Border.all(color: RetroColors.accent, width: 1.5)
                      : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color:
                      active ? RetroColors.accent : RetroColors.textSecondary,
                ),
                if (label != null)
                  Positioned(
                    bottom: 4,
                    child: Text(
                      label,
                      style: GoogleFonts.spaceMono(
                        fontSize: 7,
                        color: RetroColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlsPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: RetroDimens.paddingMd),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: RetroColors.background.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
        border: Border.all(color: RetroColors.surfaceLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: RetroDimens.paddingMd),
                child: Text(
                  'AJUSTES',
                  style: GoogleFonts.spaceMono(
                    color: RetroColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              TextButton(
                onPressed: _initializeEffectsFromFilmStock,
                child: Text(
                  'RESTAURAR',
                  style: GoogleFonts.spaceMono(
                    color: RetroColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RetroSlider(
            label: 'GRANO',
            icon: Icons.grain,
            value: _grain,
            onChanged: (v) => setState(() => _grain = v),
          ),
          RetroSlider(
            label: 'FUGA',
            icon: Icons.flare,
            value: _leakStrength,
            onChanged: (v) => setState(() => _leakStrength = v),
          ),
          RetroSlider(
            label: 'POLVO',
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
            label: 'VIÑETA',
            icon: Icons.vignette,
            value: _vignette,
            onChanged: (v) => setState(() => _vignette = v),
          ),
          RetroSlider(
            label: 'RAYAS',
            icon: Icons.brush,
            value: _scratchLevel,
            onChanged: (v) => setState(() => _scratchLevel = v),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 196,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            RetroColors.background,
            RetroColors.background.withValues(alpha: 0.8),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _modeButton(CaptureMode.photo, 'FOTO'),
                  if (_videoSupported) ...[
                    const SizedBox(width: 8),
                    _modeButton(CaptureMode.video, 'VIDEO'),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _bottomAction(
                    icon: Icons.photo_library_outlined,
                    label: 'LAB',
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LabScreen()),
                        ),
                  ),
                  _bottomAction(
                    icon: _selectedStock.icon,
                    label: 'FILM',
                    onTap:
                        () => setState(() {
                          _showFilmSelector = !_showFilmSelector;
                          _showControls = false;
                          if (_showFilmSelector) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _scrollToSelectedFilm();
                            });
                          }
                        }),
                    active: _showFilmSelector,
                    enabled: !_isRecordingVideo && !_isBusy,
                  ),
                  ShutterButton(
                    onPressed: _onShutterPressed,
                    enabled: !_isBusy && _isCameraReady,
                    recording: _isRecordingVideo,
                  ),
                  _bottomAction(
                    icon: Icons.tune,
                    label: 'FX',
                    onTap:
                        () => setState(() {
                          _showControls = !_showControls;
                          _showFilmSelector = false;
                        }),
                    active: _showControls,
                    enabled: !_isRecordingVideo && !_isBusy,
                  ),
                  _bottomAction(
                    icon:
                        _isVideoMode
                            ? Icons.videocam_outlined
                            : Icons.add_photo_alternate_outlined,
                    label: _isVideoMode ? '30s' : 'IMPORTAR',
                    onTap: _isVideoMode ? () {} : _importFromGallery,
                    enabled: !_isVideoMode && !_isRecordingVideo && !_isBusy,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color:
                  !enabled
                      ? RetroColors.textMuted
                      : active
                      ? RetroColors.accent
                      : RetroColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.spaceMono(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color:
                    !enabled
                        ? RetroColors.textMuted.withValues(alpha: 0.5)
                        : active
                        ? RetroColors.accent
                        : RetroColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
