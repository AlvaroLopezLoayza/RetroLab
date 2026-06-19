import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/film_stocks.dart';

class FilmPreview extends StatefulWidget {
  final Widget child;
  final FilmStock stock;
  final double grain;
  final double leakStrength;
  final double dustStrength;
  final double saturation;
  final double vignette;
  final double scratchLevel;
  final int lightLeakIndex;

  const FilmPreview({
    super.key,
    required this.child,
    required this.stock,
    required this.grain,
    required this.leakStrength,
    required this.dustStrength,
    required this.saturation,
    required this.vignette,
    required this.scratchLevel,
    required this.lightLeakIndex,
  });

  @override
  State<FilmPreview> createState() => _FilmPreviewState();
}

class _FilmPreviewState extends State<FilmPreview> {
  static Future<ui.FragmentProgram>? _program;
  static const Set<String> _cachedAssets = {
    RetroAssets.textureDust,
    RetroAssets.textureScratch,
  };
  static final Map<String, Future<ui.Image>> _images = {};

  ui.FragmentShader? _shader;
  ui.Image? _leak;
  ui.Image? _dust;
  ui.Image? _scratch;
  String? _currentLeakAsset;

  bool get _ready =>
      _shader != null && _leak != null && _dust != null && _scratch != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(FilmPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lightLeakIndex != widget.lightLeakIndex) {
      _loadLeak();
    }
  }

  Future<void> _load() async {
    try {
      final images = await Future.wait([
        _image(RetroAssets.textureDust),
        _image(RetroAssets.textureScratch),
        _image(RetroAssets.lightLeak(widget.lightLeakIndex), cache: false),
      ]);
      final shader =
          ui.ImageFilter.isShaderFilterSupported
              ? await (_program ??= ui.FragmentProgram.fromAsset(
                    'shaders/film_preview.frag',
                  ))
                  .then((program) => program.fragmentShader())
              : null;
      if (!mounted) return;
      setState(() {
        _shader = shader;
        _dust = images[0];
        _scratch = images[1];
        _leak = images[2];
        _currentLeakAsset = RetroAssets.lightLeak(widget.lightLeakIndex);
      });
    } catch (error) {
      debugPrint('[RetroLab] Film preview shader unavailable: $error');
    }
  }

  Future<void> _loadLeak() async {
    try {
      final asset = RetroAssets.lightLeak(widget.lightLeakIndex);
      final image = await _image(asset, cache: false);
      if (mounted) {
        final oldLeak = _leak;
        final oldAsset = _currentLeakAsset;
        setState(() {
          _leak = image;
          _currentLeakAsset = asset;
        });
        if (oldLeak != null && oldAsset != null && !_cachedAssets.contains(oldAsset)) {
          oldLeak.dispose();
        }
      }
    } catch (error) {
      debugPrint('[RetroLab] Film preview leak unavailable: $error');
    }
  }

  static Future<ui.Image> _image(String asset, {bool cache = true}) {
    Future<ui.Image> decode() async {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    }

    if (!cache) {
      return decode();
    }

    return _images.putIfAbsent(asset, decode);
  }

  @override
  void dispose() {
    if (_leak != null &&
        _currentLeakAsset != null &&
        !_cachedAssets.contains(_currentLeakAsset)) {
      _leak!.dispose();
    }
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return _fallback();
    }

    final stock = widget.stock;
    final shader = _shader!;
    final highlight = stock.highlightTint;
    final shadow = stock.shadowTint;

    final values = <double>[
      stock.temperature,
      widget.saturation,
      stock.contrast,
      stock.brightness,
      stock.shadowLift,
      stock.tintStrength,
      stock.redGamma,
      stock.greenGamma,
      stock.blueGamma,
      highlight.r,
      highlight.g,
      highlight.b,
      shadow.r,
      shadow.g,
      shadow.b,
      widget.grain,
      stock.grainSize,
      stock.coloredGrain ? 1.0 : 0.0,
      widget.vignette,
      widget.scratchLevel,
      widget.leakStrength,
      widget.dustStrength,
      stock.halation,
    ];
    for (var i = 0; i < values.length; i++) {
      shader.setFloat(i + 2, values[i]);
    }
    shader
      ..setImageSampler(1, _scratch!, filterQuality: FilterQuality.low)
      ..setImageSampler(2, _leak!, filterQuality: FilterQuality.low)
      ..setImageSampler(3, _dust!, filterQuality: FilterQuality.low);

    return ImageFiltered(
      imageFilter: ui.ImageFilter.shader(shader),
      child: widget.child,
    );
  }

  Widget _fallback() {
    final layers = <Widget>[
      ColorFiltered(
        colorFilter: _fallbackColorFilter(widget.stock, widget.saturation),
        child: widget.child,
      ),
      IgnorePointer(
        child: CustomPaint(
          painter: _FallbackTonePainter(
            stock: widget.stock,
            vignette: widget.vignette,
          ),
        ),
      ),
    ];
    if (_scratch != null && widget.scratchLevel > 0) {
      layers.add(
        _texture(_scratch!, widget.scratchLevel * 0.5, BlendMode.screen),
      );
    }
    if (_leak != null && widget.leakStrength > 0) {
      layers.add(_texture(_leak!, widget.leakStrength * 0.5, BlendMode.screen));
    }
    if (_dust != null && widget.dustStrength > 0) {
      layers.add(_texture(_dust!, widget.dustStrength * 0.5, BlendMode.screen));
    }
    return Stack(fit: StackFit.expand, children: layers);
  }

  Widget _texture(ui.Image image, double opacity, BlendMode blendMode) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _TexturePainter(
          image: image,
          opacity: opacity.clamp(0.0, 1.0),
          blendMode: blendMode,
        ),
      ),
    );
  }

  static ColorFilter _fallbackColorFilter(FilmStock stock, double saturation) {
    const lumR = 0.299;
    const lumG = 0.587;
    const lumB = 0.114;
    final inv = 1 - saturation;
    final contrast =
        stock.contrast > 0 ? 1 + stock.contrast * 2 : 1 + stock.contrast;
    final offset =
        128 * (1 - contrast) + stock.brightness * 255 + stock.shadowLift * 255;
    return ColorFilter.matrix([
      contrast * (lumR * inv + saturation),
      contrast * lumG * inv,
      contrast * lumB * inv,
      0,
      offset + stock.temperature * 20,
      contrast * lumR * inv,
      contrast * (lumG * inv + saturation),
      contrast * lumB * inv,
      0,
      offset,
      contrast * lumR * inv,
      contrast * lumG * inv,
      contrast * (lumB * inv + saturation),
      0,
      offset - stock.temperature * 20,
      0,
      0,
      0,
      1,
      0,
    ]);
  }
}

class _TexturePainter extends CustomPainter {
  final ui.Image image;
  final double opacity;
  final BlendMode blendMode;

  const _TexturePainter({
    required this.image,
    required this.opacity,
    required this.blendMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()
        ..blendMode = blendMode
        ..filterQuality = FilterQuality.low
        ..color = Colors.white.withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(_TexturePainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.opacity != opacity ||
      oldDelegate.blendMode != blendMode;
}

class _FallbackTonePainter extends CustomPainter {
  final FilmStock stock;
  final double vignette;

  const _FallbackTonePainter({required this.stock, required this.vignette});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (stock.tintStrength > 0) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(0, size.height * 0.6),
            [
              stock.highlightTint.withValues(alpha: stock.tintStrength * 0.10),
              Colors.transparent,
            ],
          )
          ..blendMode = BlendMode.screen,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, size.height),
            Offset(0, size.height * 0.35),
            [
              stock.shadowTint.withValues(alpha: stock.tintStrength * 0.12),
              Colors.transparent,
            ],
          )
          ..blendMode = BlendMode.multiply,
      );
    }

    if (stock.halation > 0) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(size.width * 0.5, size.height * 0.28),
            size.shortestSide * 0.42,
            [
              stock.highlightTint.withValues(alpha: stock.halation * 0.16),
              Colors.transparent,
            ],
          )
          ..blendMode = BlendMode.screen,
      );
    }

    if (vignette > 0) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            rect.center,
            size.longestSide * 0.72,
            [
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: vignette.clamp(0.0, 1.0) * 0.42),
            ],
            const [0.0, 0.62, 1.0],
          )
          ..blendMode = BlendMode.multiply,
      );
    }
  }

  @override
  bool shouldRepaint(_FallbackTonePainter oldDelegate) =>
      oldDelegate.stock != stock || oldDelegate.vignette != vignette;
}
