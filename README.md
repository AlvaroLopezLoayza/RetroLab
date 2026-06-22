# RetroLab

RetroLab is a Flutter camera app built to feel closer to shooting a disposable or compact film camera than applying a generic filter after the fact.

The app combines live film preview, stock-specific color rendering, virtual rolls, post-capture editing, and local-first media storage. The goal is simple: make capture feel opinionated, tactile, and a little imperfect.

## What It Does

- Shoots photos with a live film-style preview.
- Records videos on Android with the same film treatment pipeline.
- Simulates virtual rolls and per-stock shooting character.
- Lets you re-develop photos after capture without losing the original.
- Stores media and settings locally with Hive.
- Adds optional analog artifacts like grain, leaks, dust, glare, and chromatic drift.

## Film Stocks

The app currently ships with 19 built-in looks across C-41, E-6, B&W, instant, and cinematic-inspired stocks, including:

- Kodak Gold 200
- Kodak Ultramax 400
- Portra 400
- Kodak Ektar 100
- Fuji Superia 400
- Agfa Vista 200
- Fuji Velvia 50
- Fuji Provia 100F
- Ilford HP5
- Kodak Tri-X 400
- Ilford Delta 100
- CineStill 800T
- CineStill 50D
- Polaroid 600
- Lomo 400
- Expired 1998
- Disposable Flash 800
- Pocket 110
- Custom 400 C-41

Each stock is defined in `lib/core/film_stocks.dart` with its own color response, vignette, grain behavior, halation, border glare, chromatic aberration, and optional color matrix.

## Capture Flow

RetroLab is designed around a camera-first workflow:

1. Pick a stock.
2. Shoot into a virtual roll.
3. Preview the look live.
4. Process the final image with the same stock pipeline.
5. Re-open the image later and re-develop it if needed.

The camera screen also exposes a quick settings sheet for the toggles that matter during capture, including analog randomness, EXIF location saving, and date-stamp defaults.

## Image Pipeline

The photo processor applies a layered analog treatment rather than a single filter:

- temperature bias
- per-channel gamma
- optional stock color matrix
- saturation and contrast shaping
- highlight and shadow tinting
- shadow lift
- highlight shoulder protection
- halation
- grain
- vignette / exposure falloff
- border glare
- chromatic aberration
- leak / dust / scratch overlays
- optional date stamp

Preview and final output are kept as close as practical by sharing the same stock definitions. On supported devices, preview uses a shader path; otherwise it falls back to a lighter approximation.

## Project Structure

```text
lib/
  core/
    constants.dart
    film_stocks.dart
    hive_boxes.dart
    theme.dart
  models/
    film_roll.dart
    retro_photo.dart
    retro_video.dart
  screens/
    camera_screen.dart
    editor_screen.dart
    lab_screen.dart
    preview_screen.dart
    processing_screen.dart
    settings_screen.dart
    stats_screen.dart
    video_processing_screen.dart
  utils/
    image_processor.dart
    video_processor.dart
  widgets/
    film_preview.dart
```

## Main Tech

- Flutter
- `camera`
- `image`
- `hive_flutter`
- `gal`
- `share_plus`
- Android Media3 / OpenGL video processing

## Local Development

Prerequisites:

- Flutter SDK
- Android toolchain for camera/video work

Run:

```bash
flutter pub get
flutter run
```

Focused checks:

```bash
flutter analyze
flutter test
```

## Notes

- Video processing is implemented on Android.
- The app is local-first; captured media metadata and preferences live in Hive.
- Asset quality matters a lot. Leak, dust, scratch, and animation assets strongly affect the final feel.

## Status

This is an actively evolving personal project focused on film-emulation UX, preview/output parity, and making the camera flow feel deliberate instead of generic.
