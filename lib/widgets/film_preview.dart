import 'dart:io';
import 'dart:math' as math;
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
  final bool analogRandomness;
  final int artifactSeed;

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
    required this.analogRandomness,
    required this.artifactSeed,
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

  bool get _texturesReady => _leak != null && _dust != null && _scratch != null;
  bool get _shaderReady => _shader != null && _texturesReady;
  bool get _useShaderPreview => !Platform.isAndroid;

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
          _useShaderPreview && ui.ImageFilter.isShaderFilterSupported
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
        if (oldLeak != null &&
            oldAsset != null &&
            !_cachedAssets.contains(oldAsset)) {
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
    if (!_shaderReady) {
      return _fallback();
    }

    final stock = widget.stock;
    final shader = _shader!;
    final highlight = stock.highlightTint;
    final shadow = stock.shadowTint;
    final glare = stock.glareTint;
    final artifacts = stock.resolveArtifacts(
      seed: widget.artifactSeed,
      analogRandomness: widget.analogRandomness,
    );
    final matrix = stock.colorMatrix;

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
      matrix[0],
      matrix[1],
      matrix[2],
      matrix[3],
      matrix[4],
      matrix[5],
      matrix[6],
      matrix[7],
      matrix[8],
      glare.r / 255.0,
      glare.g / 255.0,
      glare.b / 255.0,
      artifacts.borderGlare,
      artifacts.glareWidth,
      artifacts.glareAngle,
      artifacts.chromaticAberrationX,
      artifacts.chromaticAberrationY,
    ];
    for (var i = 0; i < values.length; i++) {
      shader.setFloat(i + 2, values[i]);
    }
    shader
      ..setImageSampler(1, _scratch!)
      ..setImageSampler(2, _leak!)
      ..setImageSampler(3, _dust!);

    return ImageFiltered(
      imageFilter: ui.ImageFilter.shader(shader),
      child: widget.child,
    );
  }

  Widget _fallback() {
    final layers = <Widget>[
      ColorFiltered(
        colorFilter: _previewColorFilter(widget.stock, widget.saturation),
        child: widget.child,
      ),
      IgnorePointer(
        child: CustomPaint(
          painter: _FallbackTonePainter(
            stock: widget.stock,
            vignette: widget.vignette,
            analogRandomness: widget.analogRandomness,
            artifactSeed: widget.artifactSeed,
          ),
        ),
      ),
    ];
    if (widget.grain > 0) {
      layers.add(
        IgnorePointer(
          child: CustomPaint(
            painter: _FallbackGrainPainter(
              grain: widget.grain,
              grainSize: widget.stock.grainSize,
              colored: widget.stock.coloredGrain,
              seed: widget.artifactSeed,
            ),
          ),
        ),
      );
    }
    if (_scratch != null && widget.scratchLevel > 0) {
      layers.add(
        _texture(_scratch!, widget.scratchLevel * 0.5, BlendMode.screen),
      );
    }
    if (_leak != null && widget.leakStrength > 0) {
      layers.add(
        _texture(_leak!, widget.leakStrength * 0.34, BlendMode.softLight),
      );
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

  static ColorFilter _previewColorFilter(FilmStock stock, double saturation) {
    final black = _previewGrade(stock, saturation, 0, 0, 0);
    final red = _previewGrade(stock, saturation, 1, 0, 0);
    final green = _previewGrade(stock, saturation, 0, 1, 0);
    final blue = _previewGrade(stock, saturation, 0, 0, 1);
    final r = _basis(red, black);
    final g = _basis(green, black);
    final b = _basis(blue, black);
    return ColorFilter.matrix([
      r.$1,
      g.$1,
      b.$1,
      0,
      black.$1 * 255,
      r.$2,
      g.$2,
      b.$2,
      0,
      black.$2 * 255,
      r.$3,
      g.$3,
      b.$3,
      0,
      black.$3 * 255,
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  static (double, double, double) _basis(
    (double, double, double) color,
    (double, double, double) black,
  ) {
    return (color.$1 - black.$1, color.$2 - black.$2, color.$3 - black.$3);
  }

  static (double, double, double) _previewGrade(
    FilmStock stock,
    double saturation,
    double r,
    double g,
    double b,
  ) {
    var color = _baseGrade(stock, saturation, r, g, b);
    final lut = _lutGrade(stock.id, color.$1, color.$2, color.$3);
    color = (
      _mix(color.$1, lut.$1, 0.42),
      _mix(color.$2, lut.$2, 0.42),
      _mix(color.$3, lut.$3, 0.42),
    );
    return (
      color.$1.clamp(0.0, 1.0),
      color.$2.clamp(0.0, 1.0),
      color.$3.clamp(0.0, 1.0),
    );
  }

  static (double, double, double) _baseGrade(
    FilmStock stock,
    double saturation,
    double r,
    double g,
    double b,
  ) {
    if (stock.temperature != 0) {
      final luminance = _luma(r, g, b);
      final t =
          stock.temperature * (24.0 / 255.0) * (1.0 - luminance * luminance);
      r += t;
      g += t * 0.18;
      b -= t;
    }

    r = math.pow(r.clamp(0.0, 1.0), stock.redGamma).toDouble();
    g = math.pow(g.clamp(0.0, 1.0), stock.greenGamma).toDouble();
    b = math.pow(b.clamp(0.0, 1.0), stock.blueGamma).toDouble();

    final matrix = stock.colorMatrix;
    final rr = r * matrix[0] + g * matrix[1] + b * matrix[2];
    final gg = r * matrix[3] + g * matrix[4] + b * matrix[5];
    final bb = r * matrix[6] + g * matrix[7] + b * matrix[8];
    r = rr.clamp(0.0, 1.0);
    g = gg.clamp(0.0, 1.0);
    b = bb.clamp(0.0, 1.0);

    var luminance = _luma(r, g, b);
    r = luminance + (r - luminance) * saturation;
    g = luminance + (g - luminance) * saturation;
    b = luminance + (b - luminance) * saturation;

    r = _contrastCurve(r, stock.contrast);
    g = _contrastCurve(g, stock.contrast);
    b = _contrastCurve(b, stock.contrast);

    if (stock.brightness > 0) {
      r += stock.brightness * (1.0 - r);
      g += stock.brightness * (1.0 - g);
      b += stock.brightness * (1.0 - b);
    } else {
      r += stock.brightness;
      g += stock.brightness;
      b += stock.brightness;
    }

    if (stock.tintStrength > 0) {
      luminance = _luma(r, g, b);
      final highlightMix =
          _smoothstep(0.55, 0.92, luminance) * stock.tintStrength;
      final shadowMix =
          (1.0 - _smoothstep(0.08, 0.45, luminance)) * stock.tintStrength;
      r = _mix(r, stock.highlightTint.r * (240.0 / 255.0), highlightMix);
      g = _mix(g, stock.highlightTint.g * (240.0 / 255.0), highlightMix);
      b = _mix(b, stock.highlightTint.b * (240.0 / 255.0), highlightMix);
      r = _mix(r, stock.shadowTint.r, shadowMix);
      g = _mix(g, stock.shadowTint.g, shadowMix);
      b = _mix(b, stock.shadowTint.b, shadowMix);
    }

    r += stock.shadowLift * math.pow(1.0 - r, 2.0).toDouble();
    g += stock.shadowLift * math.pow(1.0 - g, 2.0).toDouble();
    b += stock.shadowLift * math.pow(1.0 - b, 2.0).toDouble();

    r = _pullBlackPoint(r, stock.contrast);
    g = _pullBlackPoint(g, stock.contrast);
    b = _pullBlackPoint(b, stock.contrast);

    return (_shoulder(r), _shoulder(g), _shoulder(b));
  }

  static (double, double, double) _lutGrade(
    String filmStockId,
    double red,
    double green,
    double blue,
  ) {
    final id = filmStockId.toLowerCase();
    var r = red;
    var g = green;
    var b = blue;
    var saturation = 1.04;
    var contrast = 0.03;
    var lift = 0.0;

    if (id.contains('portra')) {
      r += 0.018;
      g += 0.006;
      b -= 0.012;
      saturation = 0.98;
      contrast = -0.015;
      lift = 0.01;
    } else if (id.contains('gold') ||
        id.contains('ultramax') ||
        id.contains('kodak')) {
      r += 0.028;
      g += 0.01;
      b -= 0.025;
      saturation = 1.08;
      contrast = 0.045;
    } else if (id.contains('cinestill') || id.contains('800t')) {
      r += _smoothstep(0, 1, red) * 0.035;
      g -= 0.006;
      b += (1 - _smoothstep(0, 1, red)) * 0.026;
      saturation = 1.06;
      contrast = 0.035;
    } else if (id.contains('fuji') ||
        id.contains('superia') ||
        id.contains('provia')) {
      r -= 0.012;
      g += 0.02;
      b += 0.014;
      saturation = 1.09;
      contrast = 0.04;
    } else if (id.contains('velvia')) {
      r += 0.006;
      g += 0.024;
      b += 0.006;
      saturation = 1.18;
      contrast = 0.07;
    } else if (id.contains('ilford') ||
        id.contains('delta') ||
        id.contains('tri') ||
        id.contains('bw')) {
      final luma = _luma(red, green, blue);
      r = luma * 1.02;
      g = luma;
      b = luma * 0.96;
      saturation = 0;
      contrast = 0.08;
    } else if (id.contains('expired')) {
      r += 0.026;
      g -= 0.012;
      b += 0.02;
      saturation = 0.82;
      contrast = -0.035;
      lift = 0.03;
    } else if (id.contains('lomo') || id.contains('cross')) {
      r += 0.03;
      g += 0.018;
      b -= 0.018;
      saturation = 1.2;
      contrast = 0.09;
    } else if (id.contains('polaroid')) {
      r += 0.022;
      g += 0.01;
      b -= 0.006;
      saturation = 0.9;
      contrast = -0.02;
      lift = 0.025;
    }

    r = _tone(r, contrast, lift);
    g = _tone(g, contrast, lift);
    b = _tone(b, contrast, lift);
    final luma = _luma(r, g, b);
    return (
      luma + (r - luma) * saturation,
      luma + (g - luma) * saturation,
      luma + (b - luma) * saturation,
    );
  }

  static double _tone(double value, double contrast, double lift) {
    return ((value - 0.5) * (1.0 + contrast) + 0.5 + lift * (1.0 - value))
        .clamp(0.0, 1.0);
  }

  static double _contrastCurve(double value, double contrast) {
    final x = value.clamp(0.0, 1.5);
    if (contrast >= 0) {
      final curve = x < 0.5 ? 2.0 * x * x : 1.0 - 2.0 * math.pow(1.0 - x, 2.0);
      return _mix(x, curve.toDouble(), contrast.clamp(0.0, 1.0));
    }
    return 0.5 + (x - 0.5) * (1.0 + contrast.clamp(-1.0, 0.0));
  }

  static double _shoulder(double value) {
    final x = value.clamp(0.0, 1.5);
    const start = 200.0 / 255.0;
    if (x <= start) return x;
    final t = ((x - start) / (55.0 / 255.0)).clamp(0.0, 2.0);
    final shaped = (t * 1.35) / (1.0 + 0.35 * t);
    return start + (55.0 / 255.0) * shaped.clamp(0.0, 1.0);
  }

  static double _pullBlackPoint(double value, double contrast) {
    final blackPoint = (0.018 +
            math.max(contrast, 0.0) * 0.07 +
            math.min(contrast, 0.0) * 0.02)
        .clamp(0.012, 0.052);
    return ((value - blackPoint) / (1.0 - blackPoint)).clamp(0.0, 1.0);
  }

  static double _smoothstep(double edge0, double edge1, double x) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  static double _luma(double r, double g, double b) =>
      r * 0.299 + g * 0.587 + b * 0.114;

  static double _mix(double a, double b, double t) => a + (b - a) * t;
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

class _FallbackGrainPainter extends CustomPainter {
  final double grain;
  final double grainSize;
  final bool colored;
  final int seed;

  const _FallbackGrainPainter({
    required this.grain,
    required this.grainSize,
    required this.colored,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final amount = grain.clamp(0.0, 1.0);
    if (amount <= 0) return;

    final count = (360 + amount * 980).round();
    final dotSize = (0.55 + grainSize * 0.75).clamp(0.7, 2.2);
    final paint = Paint()..blendMode = BlendMode.overlay;
    var state = seed & 0x7fffffff;

    for (var i = 0; i < count; i++) {
      state = _next(state);
      final x = (state / 0x7fffffff) * size.width;
      state = _next(state);
      final y = (state / 0x7fffffff) * size.height;
      state = _next(state);
      final noise = (state / 0x7fffffff) - 0.5;
      final alpha = (amount * (0.10 + noise.abs() * 0.16)).clamp(0.0, 0.24);
      if (colored) {
        final hue = (state % 360).toDouble();
        paint.color =
            HSVColor.fromAHSV(alpha, hue, 0.22, noise > 0 ? 1 : 0.12).toColor();
      } else {
        final value = noise > 0 ? 255 : 0;
        paint.color = Color.fromARGB(
          (alpha * 255).round(),
          value,
          value,
          value,
        );
      }
      canvas.drawCircle(Offset(x, y), dotSize, paint);
    }
  }

  static int _next(int value) => (value * 1103515245 + 12345) & 0x7fffffff;

  @override
  bool shouldRepaint(_FallbackGrainPainter oldDelegate) =>
      oldDelegate.grain != grain ||
      oldDelegate.grainSize != grainSize ||
      oldDelegate.colored != colored ||
      oldDelegate.seed != seed;
}

class _FallbackTonePainter extends CustomPainter {
  final FilmStock stock;
  final double vignette;
  final bool analogRandomness;
  final int artifactSeed;

  const _FallbackTonePainter({
    required this.stock,
    required this.vignette,
    required this.analogRandomness,
    required this.artifactSeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final artifacts = stock.resolveArtifacts(
      seed: artifactSeed,
      analogRandomness: analogRandomness,
    );

    if (stock.tintStrength > 0) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui
              .Gradient.linear(Offset.zero, Offset(0, size.height * 0.6), [
            stock.highlightTint.withValues(alpha: stock.tintStrength * 0.10),
            Colors.transparent,
          ])
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

    if (artifacts.borderGlare > 0) {
      final center = rect.center;
      final direction = Offset(
        artifacts.glareAngle,
        -artifacts.glareAngle * 0.7,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            center +
                Offset(
                  direction.dx * size.width * 0.18,
                  direction.dy * size.height * 0.18,
                ),
            size.longestSide * (0.55 + artifacts.glareWidth * 0.35),
            [
              Colors.transparent,
              Colors.transparent,
              stock.glareTint.withValues(alpha: artifacts.borderGlare * 0.34),
            ],
            const [0.0, 0.72, 1.0],
          )
          ..blendMode = BlendMode.screen,
      );
    }
  }

  @override
  bool shouldRepaint(_FallbackTonePainter oldDelegate) =>
      oldDelegate.stock != stock ||
      oldDelegate.vignette != vignette ||
      oldDelegate.analogRandomness != analogRandomness ||
      oldDelegate.artifactSeed != artifactSeed;
}
