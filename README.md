# 📷 RetroLab

> **Analog Magic. Digital Soul.**

A next-generation disposable camera simulator that goes beyond HUJI Cam — featuring multiple film stocks, virtual film rolls, adjustable retro controls, and a full darkroom lab experience.

---

## ✨ Features

### 🎞️ 6 Legendary Film Stocks
| Film Stock | Character |
|---|---|
| **Kodak Gold 200** | Warm golden tones, classic summer film |
| **Fuji Superia 400** | Cool greens, natural everyday colors |
| **Ilford HP5 Plus** | Classic B&W with rich grain |
| **Polaroid 600** | Dreamy, soft, washed-out |
| **Lomo 400** | Vivid cross-processed, heavy vignette |
| **Expired 1998** | Unpredictable pink/magenta shifts |

### 📸 Camera Features
- **Virtual Film Rolls** — 36 exposures per roll, realistic counter
- **Adjustable Effects** — Grain, Light Leaks, Saturation, Vignette, Scratches
- **Timer** — 3s / 10s hands-free timer
- **Burst Mode** — 3 rapid shots
- **Flash Modes** — Off / Auto / Always
- **Grid Overlay** — Rule of thirds

### 🔬 The Lab (Gallery)
- Grid & Film Strip view modes
- Filter by film stock
- Export as film strip PNG
- Photo detail with sharing

### ✏️ Post-Capture Editor
- Re-adjust all effects after shooting
- Change film stock and reprocess
- Toggle date stamp on/off
- Choose date stamp style & position

### 📊 Darkroom Stats
- Total shots & rolls developed
- Favorite film stock
- Per-stock usage breakdown

### 🎨 Date Stamp Styles
- **Classic 90s** — Yellow digital (like disposable cameras)
- **Handwritten** — Casual white script
- **Polaroid** — Clean off-white

### 🔀 Analog Randomness
Random subtle defects make each photo unique:
- Light streaks
- Color shifts
- Edge overexposure
- All togglable in Settings

---

## 🚀 Getting Started

### Prerequisites
- Flutter 3.24+ (latest stable)
- Android SDK / Xcode for iOS

### Installation
```bash
cd retrolab
flutter pub get
flutter run
```

### Adding Real Assets

The project uses placeholder files for assets. Replace them with real files:

#### Light Leaks (`assets/light_leaks/`)
Add 10 semi-transparent PNG files named `leak_1.png` through `leak_10.png`.

**Recommended specs:**
- Size: 1920×1280 px
- Format: PNG with alpha channel
- Style: Warm orange/yellow/red gradients, lens flare overlays

**Free sources:**
- [Film Composite Pack by RocketStock](https://www.rocketstock.com)
- Search "free light leak overlays PNG" on Unsplash/Pexels

#### Lottie Animations (`assets/lottie/`)
Replace `developing.json` and `film_reel.json` with real Lottie animations.

**Recommended:**
- [LottieFiles](https://lottiefiles.com) — search "film reel", "camera", "developing"

#### Shutter Sound (`assets/sounds/`)
Replace `shutter.mp3` with a real camera shutter click sound.

**Free sources:**
- [Freesound.org](https://freesound.org) — search "camera shutter click"

#### Textures (`assets/textures/`)
- `grain.png` — Film grain texture (tileable, grayscale)
- `scratch.png` — Film scratch overlay
- `dust.png` — Dust particle overlay

#### Fonts (`assets/fonts/`)
Replace `RetroDigital.ttf` with a real retro digital font.

**Recommended free fonts:**
- [Digital-7](https://www.dafont.com/digital-7.font)
- [DS-Digital](https://www.dafont.com/ds-digital.font)

> **Note:** The app uses Google Fonts (Space Mono, Inter) for most UI text.
> The RetroDigital font is optional for the date stamp display.

---

## 🏗️ Architecture

```
lib/
├── main.dart                    # App entry point
├── core/
│   ├── constants.dart           # Colors, dimensions, strings, enums
│   ├── theme.dart               # Dark & light theme definitions
│   ├── film_stocks.dart         # 6 film stock preset definitions
│   └── hive_boxes.dart          # Local storage service
├── models/
│   ├── retro_photo.dart         # Photo metadata model
│   └── film_roll.dart           # Film roll model (36 exposures)
├── screens/
│   ├── onboarding_screen.dart   # 3-page onboarding
│   ├── camera_screen.dart       # Main camera with controls
│   ├── processing_screen.dart   # "DEVELOPING..." animation
│   ├── preview_screen.dart      # Post-capture preview
│   ├── editor_screen.dart       # Re-edit effects & film stock
│   ├── lab_screen.dart          # Gallery with grid & strip views
│   ├── stats_screen.dart        # Photography statistics
│   └── settings_screen.dart     # App settings
├── widgets/
│   ├── shutter_button.dart      # Animated shutter button
│   ├── viewfinder_overlay.dart  # Camera overlay with brackets
│   ├── film_stock_selector.dart # Horizontal film stock picker
│   ├── grain_overlay.dart       # Animated film grain
│   ├── retro_slider.dart        # Custom effect slider
│   └── film_counter.dart        # LED-style exposure counter
└── utils/
    └── image_processor.dart     # Core image processing engine
```

---

## 🔧 Extending Film Stocks

To add a new film stock, edit `lib/core/film_stocks.dart`:

```dart
static const myCustomFilm = FilmStock(
  id: 'my_custom_film',
  name: 'My Custom Film',
  shortName: 'CUSTOM',
  description: 'Description of the look.',
  badgeColor: Color(0xFF...),
  icon: Icons.camera,                    
  temperature: 0.2,       // -1.0 (cool) to 1.0 (warm)
  saturation: 1.1,        // 0.0 (B&W) to 2.0 (vivid)
  contrast: 1.05,         // Multiplier
  brightness: 0.0,        // -1.0 to 1.0
  highlightTint: Color(), // Tint for bright areas
  shadowTint: Color(),    // Tint for dark areas
  tintStrength: 0.15,     // 0.0 to 1.0
  baseGrain: 0.15,        // 0.0 to 1.0
  coloredGrain: true,     // true = color noise, false = B&W noise
  baseVignette: 0.3,      // 0.0 to 1.0
  redGamma: 1.0,          // Channel curve (< 1 brightens, > 1 darkens)
  greenGamma: 1.0,
  blueGamma: 1.0,
);
```

Then add it to the `all` list:
```dart
static const List<FilmStock> all = [
  // ...existing stocks
  myCustomFilm,
];
```

---

## 📱 Platform Setup

### Android
Add camera and storage permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-feature android:name="android.hardware.camera" />
```

Set minimum SDK to 21 in `android/app/build.gradle`:
```groovy
minSdkVersion 21
```

### iOS
Add to `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>RetroLab needs camera access to capture analog-style photos.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>RetroLab saves processed photos to your photo library.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>RetroLab saves developed photos to your gallery.</string>
<key>NSMicrophoneUsageDescription</key>
<string>RetroLab uses the microphone for video capture.</string>
```

---

## 📦 Dependencies

| Package | Purpose |
|---|---|
| `camera` | Live camera preview & capture |
| `image` | Pixel-level image processing |
| `path_provider` | App document directory |
| `permission_handler` | Runtime permissions |
| `image_gallery_saver_plus` | Save to phone gallery |
| `image_picker` | Import from gallery |
| `intl` | Date formatting |
| `google_fonts` | Space Mono & Inter fonts |
| `lottie` | Developing animations |
| `hive` / `hive_flutter` | Local persistent storage |
| `audioplayers` | Shutter click sound |
| `share_plus` | Share photos |

---

## 📄 License

MIT License — build something beautiful.

---

*Shot on RetroLab • 2026*
