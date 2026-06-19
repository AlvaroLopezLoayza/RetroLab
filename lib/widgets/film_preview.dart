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
  static final Map<String, Future<ui.Image>> _images = {};

  ui.FragmentShader? _shader;
  ui.Image? _grain;
  ui.Image? _leak;
  ui.Image? _dust;
  ui.Image? _scratch;

  bool get _ready =>
      _shader != null &&
      _grain != null &&
      _leak != null &&
      _dust != null &&
      _scratch != null;

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
        _image(RetroAssets.textureGrain),
        _image(RetroAssets.textureDust),
        _image(RetroAssets.textureScratch),
        _image(RetroAssets.lightLeak(widget.lightLeakIndex)),
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
        _grain = images[0];
        _dust = images[1];
        _scratch = images[2];
        _leak = images[3];
      });
    } catch (error) {
      debugPrint('[RetroLab] Film preview shader unavailable: $error');
    }
  }

  Future<void> _loadLeak() async {
    try {
      final image = await _image(RetroAssets.lightLeak(widget.lightLeakIndex));
      if (mounted) setState(() => _leak = image);
    } catch (error) {
      debugPrint('[RetroLab] Film preview leak unavailable: $error');
    }
  }

  static Future<ui.Image> _image(String asset) {
    return _images.putIfAbsent(asset, () async {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    });
  }

  @override
  void dispose() {
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
      widget.vignette,
      widget.scratchLevel,
      widget.leakStrength,
      widget.dustStrength,
    ];
    for (var i = 0; i < values.length; i++) {
      shader.setFloat(i + 2, values[i]);
    }
    shader
      ..setImageSampler(1, _grain!, filterQuality: FilterQuality.low)
      ..setImageSampler(2, _scratch!, filterQuality: FilterQuality.low)
      ..setImageSampler(3, _leak!, filterQuality: FilterQuality.low)
      ..setImageSampler(4, _dust!, filterQuality: FilterQuality.low);

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
    ];
    if (_grain != null && widget.grain > 0) {
      layers.add(_texture(_grain!, widget.grain, BlendMode.multiply));
    }
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
