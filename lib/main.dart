/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Main Entry Point
///
/// Next-generation disposable camera simulator with premium analog feel.
/// "Analog Magic. Digital Soul."
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/hive_boxes.dart';
import 'core/theme.dart';
import 'screens/camera_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientation for camera experience
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Set system UI style for a premium edge-to-edge experience
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // Enable edge-to-edge mode
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Initialize Hive local storage
  await HiveService.init();

  runApp(const RetroLabApp());
}

class RetroLabApp extends StatefulWidget {
  const RetroLabApp({super.key});

  @override
  State<RetroLabApp> createState() => _RetroLabAppState();
}

class _RetroLabAppState extends State<RetroLabApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = HiveService.isDarkMode;
  }

  @override
  Widget build(BuildContext context) {
    final hasSeenOnboarding = HiveService.hasCompletedOnboarding;

    return MaterialApp(
      title: 'RetroLab',
      debugShowCheckedModeBanner: false,
      theme: _isDarkMode ? RetroTheme.dark : RetroTheme.light,
      home: hasSeenOnboarding ? const CameraScreen() : const OnboardingScreen(),
    );
  }
}
