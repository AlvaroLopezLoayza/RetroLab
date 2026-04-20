/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Hive Local Storage Setup
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:hive_flutter/hive_flutter.dart';
import 'constants.dart';

class HiveService {
  HiveService._();

  static late Box<Map> photosBox;
  static late Box<Map> rollsBox;
  static late Box settingsBox;
  static late Box statsBox;

  /// Initialize Hive and open all boxes.
  static Future<void> init() async {
    await Hive.initFlutter();

    photosBox = await Hive.openBox<Map>(HiveBoxes.photos);
    rollsBox = await Hive.openBox<Map>(HiveBoxes.rolls);
    settingsBox = await Hive.openBox(HiveBoxes.settings);
    statsBox = await Hive.openBox(HiveBoxes.stats);
  }

  // ── Settings Helpers ───────────────────────────────────────────────────

  static bool get hasCompletedOnboarding =>
      settingsBox.get('onboarding_complete', defaultValue: false) as bool;

  static Future<void> setOnboardingComplete() async =>
      settingsBox.put('onboarding_complete', true);

  static bool get isDarkMode =>
      settingsBox.get('dark_mode', defaultValue: true) as bool;

  static Future<void> setDarkMode(bool value) async =>
      settingsBox.put('dark_mode', value);

  static bool get analogRandomnessEnabled =>
      settingsBox.get('analog_randomness', defaultValue: true) as bool;

  static Future<void> setAnalogRandomness(bool value) async =>
      settingsBox.put('analog_randomness', value);

  static String get dateStampStyle =>
      settingsBox.get('date_stamp_style', defaultValue: 'classic90s') as String;

  static Future<void> setDateStampStyle(String value) async =>
      settingsBox.put('date_stamp_style', value);

  static String get dateStampPosition =>
      settingsBox.get('date_stamp_position', defaultValue: 'bottomRight')
          as String;

  static Future<void> setDateStampPosition(String value) async =>
      settingsBox.put('date_stamp_position', value);

  static bool get saveLocationDataEnabled =>
      settingsBox.get('save_location_data', defaultValue: false) as bool;

  static Future<void> setSaveLocationData(bool value) async =>
      settingsBox.put('save_location_data', value);

  // ── Stats Helpers ─────────────────────────────────────────────────────

  static int get totalShots =>
      statsBox.get('total_shots', defaultValue: 0) as int;

  static Future<void> incrementShots() async =>
      statsBox.put('total_shots', totalShots + 1);

  static int get totalRolls =>
      statsBox.get('total_rolls', defaultValue: 0) as int;

  static Future<void> incrementRolls() async =>
      statsBox.put('total_rolls', totalRolls + 1);

  static String get favoriteStockId =>
      statsBox.get('favorite_stock', defaultValue: 'kodak_gold_200') as String;

  /// Update favorite stock based on most used.
  static Future<void> recordStockUsage(String stockId) async {
    final Map usageMap = Map<String, int>.from(
      statsBox.get('stock_usage', defaultValue: {}) as Map,
    );
    usageMap[stockId] = ((usageMap[stockId] as int?) ?? 0) + 1;
    await statsBox.put('stock_usage', usageMap);

    // Find the most used stock
    String topStock = stockId;
    int topCount = 0;
    usageMap.forEach((key, value) {
      if ((value as int) > topCount) {
        topCount = value;
        topStock = key as String;
      }
    });
    await statsBox.put('favorite_stock', topStock);
  }
}
