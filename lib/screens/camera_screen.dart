/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Camera Screen
///
/// Main screen — live camera preview with viewfinder overlay, film stock
/// selector, adjustable retro controls, timer, and burst mode.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/constants.dart';
import '../core/film_stocks.dart';
import '../core/hive_boxes.dart';
import '../models/film_roll.dart';
import '../widgets/film_stock_selector.dart';
import '../widgets/grain_overlay.dart';
import '../widgets/retro_slider.dart';
import '../widgets/shutter_button.dart';
import '../widgets/viewfinder_overlay.dart';
import 'lab_screen.dart';
import 'processing_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  // ── Camera ─────────────────────────────────────────────────────────────
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  bool _isCameraReady = false;

  // ── Film State ─────────────────────────────────────────────────────────
  FilmStock _selectedStock = FilmStocks.kodakGold200;
  late FilmRoll _currentRoll;
  bool _showFilmSelector = false;
  bool _showControls = false;

  // ── Effect Controls ────────────────────────────────────────────────────
  double _grain = 0.18;
  double _leakStrength = 0.6;
  double _saturation = 1.0;
  double _vignette = 0.3;
  double _scratchLevel = 0.0;

  // ── Timer & Burst ──────────────────────────────────────────────────────
  ShutterTimer _shutterTimer = ShutterTimer.off;
  bool _isBurstMode = false;
  bool _isCapturing = false;
  int _timerCountdown = 0;

  // ── Audio ──────────────────────────────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ── Grid ───────────────────────────────────────────────────────────────
  bool _showGrid = false;

  // ── Flash ──────────────────────────────────────────────────────────────
  FlashMode _flashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadOrCreateRoll();
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  // ── Initialization ─────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    // Show rationale if we haven't asked or if denied
    if (await Permission.camera.isDenied) {
      if (!mounted) return;
      bool? consent = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: RetroColors.surface,
          title: Text(
            'Camera Access',
            style: GoogleFonts.spaceMono(color: RetroColors.textPrimary),
          ),
          content: Text(
            'RetroLab needs camera access to capture your analog moments. Operations are offline and hardware access is only active when the app is open.',
            style: GoogleFonts.inter(color: RetroColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('DENY', style: GoogleFonts.spaceMono(color: RetroColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: RetroColors.accent),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('ALLOW', style: GoogleFonts.spaceMono(color: RetroColors.background, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (consent != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission required to shoot film.')),
          );
        }
        return;
      }
    }

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required')),
        );
      }
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw Exception('No cameras found on device');
      }
      await _setupCamera(_cameras[_currentCameraIndex]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera initialization failed: \${e.toString()}')),
        );
      }
    }
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    _cameraController?.dispose();

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
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
    // Try to load the current active roll from Hive
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

  // ── Capture Logic ──────────────────────────────────────────────────────

  Future<void> _onShutterPressed() async {
    if (_isCapturing) return;
    if (_currentRoll.isFinished) {
      _showFilmFinishedDialog();
      return;
    }

    // Handle timer
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
      // Burst: 3 rapid shots
      for (int i = 0; i < 3; i++) {
        await _capturePhoto();
        if (i < 2) await Future.delayed(const Duration(milliseconds: 400));
        if (_currentRoll.isFinished) break;
      }
    } else {
      await _capturePhoto();
    }
  }

  Future<void> _capturePhoto() async {
    if (!_isCameraReady || _cameraController == null) return;

    setState(() => _isCapturing = true);

    try {
      // Play shutter sound
      _playShutterSound();

      // Take photo
      final xFile = await _cameraController!.takePicture();
      final file = File(xFile.path);

      // Update roll
      final photoId = DateTime.now().millisecondsSinceEpoch.toString();
      _currentRoll = _currentRoll.withExposureTaken(photoId);
      await HiveService.rollsBox.put(_currentRoll.id, _currentRoll.toMap());
      await HiveService.incrementShots();
      await HiveService.recordStockUsage(_selectedStock.id);

      if (!mounted) return;

      // Navigate to processing screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProcessingScreen(
            originalFile: file,
            filmStock: _selectedStock,
            roll: _currentRoll,
            photoId: photoId,
            grain: _grain,
            leakStrength: _leakStrength,
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
            content: Text('Failed to capture photo: $e'),
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
      _audioPlayer.play(AssetSource(RetroAssets.soundShutter.replaceFirst('assets/', '')));
    } catch (_) {
      // Sound asset not available — skip
    }
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
        builder: (_) => ProcessingScreen(
          originalFile: file,
          filmStock: _selectedStock,
          roll: _currentRoll,
          photoId: photoId,
          grain: _grain,
          leakStrength: _leakStrength,
          saturation: _saturation,
          vignette: _vignette,
          scratchLevel: _scratchLevel,
          isImported: true,
        ),
      ),
    );
  }

  void _flipCamera() {
    if (_cameras.length < 2) return;
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    _setupCamera(_cameras[_currentCameraIndex]);
  }

  void _cycleFlash() {
    final modes = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final currentIndex = modes.indexOf(_flashMode);
    _flashMode = modes[(currentIndex + 1) % modes.length];
    _cameraController?.setFlashMode(_flashMode);
    setState(() {});
  }

  void _cycleTimer() {
    final timers = ShutterTimer.values;
    final currentIndex = timers.indexOf(_shutterTimer);
    setState(() {
      _shutterTimer = timers[(currentIndex + 1) % timers.length];
    });
  }

  void _showFilmFinishedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
              'Your ${_selectedStock.name} roll is fully exposed!\n'
              'Load a new roll to keep shooting.',
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
            child: const Text('VIEW LAB'),
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
          // ── Camera Preview ─────────────────────────────────────────────
          if (_isCameraReady && _cameraController != null)
            Positioned.fill(
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cameraController!.value.previewSize?.height ?? 1,
                    height: _cameraController!.value.previewSize?.width ?? 1,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Center(
                child: Text(
                  '[ WARMING UP SENSOR... ]',
                  style: GoogleFonts.spaceMono(
                    color: RetroColors.accent,
                    fontSize: 14,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // ── Film Grain Overlay ─────────────────────────────────────────
          const Positioned.fill(
            child: GrainOverlay(opacity: 0.03),
          ),

          // ── Viewfinder Overlay ─────────────────────────────────────────
          Positioned.fill(
            child: ViewfinderOverlay(
              filmStock: _selectedStock,
              remainingExposures: _currentRoll.remainingExposures,
              showGrid: _showGrid,
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

          // ── Controls Panel (expandable) ────────────────────────────────
          if (_showControls)
            Positioned(
              bottom: 160,
              left: 0,
              right: 0,
              child: _buildControlsPanel(),
            ),

          // ── Film Stock Selector (expandable) ──────────────────────────
          if (_showFilmSelector)
            Positioned(
              bottom: 160,
              left: 0,
              right: 0,
              child: Container(
                color: RetroColors.background.withValues(alpha: 0.9),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: FilmStockSelector(
                  selectedStock: _selectedStock,
                  onStockChanged: (stock) {
                    setState(() {
                      _selectedStock = stock;
                      _showFilmSelector = false;
                    });
                  },
                ),
              ),
            ),

          // ── Bottom Bar ─────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(),
          ),

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
                      tooltip: 'Grid',
                    ),
                    _iconButton(
                      Icons.flip_camera_ios,
                      _flipCamera,
                      tooltip: 'Flip Camera',
                    ),
                    _iconButton(
                      Icons.timer,
                      _cycleTimer,
                      active: _shutterTimer != ShutterTimer.off,
                      label: _shutterTimer.label,
                      tooltip: 'Timer',
                    ),
                    _iconButton(
                      Icons.burst_mode,
                      () => setState(() => _isBurstMode = !_isBurstMode),
                      active: _isBurstMode,
                      tooltip: 'Burst Mode',
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

  IconData get _flashIcon {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      default:
        return Icons.flash_off;
    }
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
          onTap: onPressed,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: active
                  ? RetroColors.accent.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: active
                  ? Border.all(color: RetroColors.accent, width: 1.5)
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: active ? RetroColors.accent : RetroColors.textSecondary,
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
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 150,
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
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Gallery / Lab
              _bottomAction(
                icon: Icons.photo_library_outlined,
                label: 'LAB',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LabScreen()),
                ),
              ),

              // Film selector toggle
              _bottomAction(
                icon: Icons.camera_roll_outlined,
                label: 'FILM',
                onTap: () =>
                    setState(() {
                      _showFilmSelector = !_showFilmSelector;
                      _showControls = false;
                    }),
                active: _showFilmSelector,
              ),

              // Shutter Button
              ShutterButton(
                onPressed: _onShutterPressed,
                enabled: !_isCapturing && _isCameraReady,
              ),

              // Controls toggle
              _bottomAction(
                icon: Icons.tune,
                label: 'FX',
                onTap: () =>
                    setState(() {
                      _showControls = !_showControls;
                      _showFilmSelector = false;
                    }),
                active: _showControls,
              ),

              // Import from gallery
              _bottomAction(
                icon: Icons.add_photo_alternate_outlined,
                label: 'IMPORT',
                onTap: _importFromGallery,
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
  }) {
    return GestureDetector(
      onTap: onTap,
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
              color: active ? RetroColors.accent : RetroColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.spaceMono(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: active ? RetroColors.accent : RetroColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
