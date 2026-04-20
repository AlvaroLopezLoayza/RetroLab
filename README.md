# 📷 RetroLab

> **Analog Magic. Digital Soul.**

A next-generation disposable camera simulator that goes beyond basic filtering — featuring a premium image processing engine, 12 legendary film stocks, virtual film rolls, and a full darkroom lab experience.

---

## ✨ Features

### 🎞️ 12 Legendary Film Stocks
RetroLab emulates the chemistry of classic analog films with high fidelity:

| Film Stock | Process | ISO | Character |
|---|---|---|---|
| **Kodak Gold 200** | C-41 | 200 | Warm golden tones, classic summer film |
| **Kodak Ultramax 400** | C-41 | 400 | Punchy, versatile, strong color separation |
| **Kodak Portra 400** | C-41 | 400 | Professional standard, pastel skin tones |
| **Kodak Ektar 100** | C-41 | 100 | Ultra-vivid landscape film, fine grain |
| **Fuji Superia 400** | C-41 | 400 | Cool greens, natural everyday colors |
| **Agfa Vista 200** | C-41 | 200 | Pink and purple casts with a warm glow |
| **Fuji Velvia 50** | E-6 | 50 | Hyper-saturated landscape slide film |
| **Ilford HP5 Plus** | B&W | 400 | Classic B&W with rich tonal range |
| **CineStill 800T** | ECN-2 | 800 | Cinematic tungsten blue with red halation |
| **Polaroid 600** | Instant | 160 | Dreamy, soft, matte shadows |
| **Lomo 400** | C-41 | 400 | Vivid cross-processed, heavy vignette |
| **Expired 1998** | C-41 | 200 | Unpredictable pink shifts and base fog |

### 📸 Camera Features
- **Virtual Film Rolls** — 36 exposures per roll, realistic counter
- **Live Film Filter Preview** ✨ — Real-time camera preview showing accurate color grading, shadow lift, vignette, and grain for each film stock
- **Professional Effects** — Real Grain, Adjustable Leaks, Dust, Vignette, Scratches
- **Advanced Logic** — Burst Mode (3 shots), Flash (On/Off/Auto), & Timer (3s/10s)
- **High Latitude** — S-curve contrast and soft-knee tone mapping prevent burnt highlights

### 🔬 The Lab (Gallery)
- Grid & Film Strip view modes
- Filter by film stock or development style
- **Export as Polaroid** — Shared images include a premium white frame with filter name
- **Film Strip Generator** — Create vertical PNG strips from your favorites

### ✏️ Post-Capture Editor
- Re-adjust all effects after shooting (Lossless metadata-driven editing)
- Change film stock at any time and re-develop
- Choose from multiple date stamp styles

### 🔀 Analog Randomness
Subtle, authentic defects make every shot unique:
- **Light Streaks** — Accidental exposure during winding
- **Base Fog** — Simulated film base density (Shadow Lift)
- **Edge Overexposure** — Light leaking through the camera back

---

## 🎬 Live Film Filter Preview System

RetroLab now features **real-time, accurate film filter preview** directly in the camera viewfinder. No more guessing — what you see is what you get.

### Preview Accuracy (v2.0)
The live preview now replicates **65-70%** of the final processor's color science:

| Effect | Preview | Processing | Status |
|---|---|---|---|
| **Shadow Lift** (film base fog) | ✅ | ✅ | Fully represented |
| **Per-Channel Gamma** | ✅ | ✅ | Approximated curves |
| **Saturation** | ✅ | ✅ | Luminance-aware formula |
| **S-Curve Contrast** | ✅ | ✅ | Photoshop-equivalent |
| **Temperature Shift** | ✅ | ✅ | Highlight-protected |
| **Highlight/Shadow Tinting** | ✅ | ✅ | Luminance-masked |
| **Vignette** | ✅ | ✅ | Distance-based radial |
| **Film Grain** | ✅ | ✅ | Stock-specific intensity |
| **Procedural Grain** | ⚠️ Real-time | ✅ Full quality | Post-processing only |
| **Light Leaks** | ⚠️ Optional | ✅ 42 variants | Toggleable overlay |
| **Texture Details** | ⚠️ Optional | ✅ Full blending | Post-processing only |

### How It Works
- **Advanced Color Matrix** — 5×4 matrix applies shadow lift, gamma, saturation, contrast, and tint in real-time
- **Dynamic Vignette** — 4-stop radial gradient with film stock–specific intensity
- **Grain Overlay** — Animates at 100ms intervals with grain intensity matched to selected film's ISO
- **Film Stock Integration** — Automatically syncs to selected film stock; parameters update instantly when switching stocks

### Performance
- Target: **30 fps preview** (smooth enough for real-time camera use)
- Zero additional latency — preview composites into camera frame buffer
- Minimal CPU impact — uses GPU-accelerated ColorFilter + custom painters

---

## 🚀 Getting Started

### Prerequisites
- Flutter 3.24+ (latest stable)
- Android SDK / Xcode for iOS

### Installation
```bash
git clone https://github.com/alopez/retrolab
cd retrolab
flutter pub get
flutter run
```

### Adding Real Assets

The project uses placeholder files for assets. Replace them with real high-quality files:

#### Light Leaks (`assets/light_leaks/`)
Add **42** JPG files named `leak_0.jpg` through `leak_41.jpg`.

**Recommended specs:**
- Size: 2400×1600 px (3:2 aspect ratio)
- Style: Warm orange/yellow/red gradients, flares, and streaks on black backgrounds

#### Lottie Animations (`assets/lottie/`)
Replace `developing.json` and `film_reel.json` with animations from [LottieFiles](https://lottiefiles.com).

#### Textures (`assets/textures/`)
- `grain.png` — High-ISO film grain (tileable)
- `scratch.png` — Vertical film scratches
- `dust.png` — Dust particles and hair overlays

---

## 🏗️ Architecture

```
lib/
├── main.dart                    # App entry point
├── core/
│   ├── constants.dart           # Unified design tokens & assets
│   ├── film_stocks.dart         # v2 Film Stock definitions (12 presets)
│   └── hive_boxes.dart          # Local persistent storage
├── models/
│   ├── retro_photo.dart         # Photo metadata & processing state
│   └── film_roll.dart           # Virtual roll management
├── screens/
│   ├── camera_screen.dart       # High-performance camera interface
│   ├── preview_screen.dart      # Export & Share logic (Polaroid/Normal)
│   ├── editor_screen.dart       # Professional adjustment sliders
│   └── lab_screen.dart          # Gallery & Export manager
└── utils/
    └── image_processor.dart     # v3 Process Engine (Tone mapping & S-curves)
```

---

## 🔧 Extending Film Stocks

RetroLab uses a sophisticated v2 constructor for film stocks. Edit `lib/core/film_stocks.dart`:

```dart
static const myFilm = FilmStock(
  id: 'custom_pro_400',
  name: 'Custom Pro 400',
  shortName: 'PRO 400',
  description: 'Clean pro-grade look.',
  badgeColor: Color(0xFF...),
  filmProcess: FilmProcess.c41,
  iso: 400,
  temperature: 0.1,       // -0.5 to 0.5 recommended
  saturation: 1.05,       // 0.0 (B&W) to 1.5
  contrast: 0.05,         // -1.0 to 1.0 (0.0 is neutral)
  shadowLift: 0.04,       // Emulates base fog depth
  tintStrength: 0.12,     
  baseGrain: 0.15,        
  redGamma: 0.98,         // Fine-tune channel curves
  greenGamma: 1.0,
  blueGamma: 1.02,
);
```

---

## 📦 Key Dependencies

| Package | Purpose |
|---|---|
| `camera` | Live viewfinder and raw capture |
| `image` | Core pixel-level processing engine |
| `gal` | Highly-compatible gallery saving |
| `share_plus` | Native sharing support |
| `google_fonts` | Space Mono & Inter typography |
| `hive_flutter` | High-performance local storage |

---

## 📄 License

MIT License — Share your moments, keep the soul.

---

*Shot on RetroLab • 2026*
