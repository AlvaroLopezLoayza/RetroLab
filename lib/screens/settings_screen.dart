/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Settings Screen
///
/// App settings: theme, analog randomness, date stamp defaults,
/// and about section.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/hive_boxes.dart';
import '../widgets/grain_overlay.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onThemeChanged;

  const SettingsScreen({super.key, required this.onThemeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _isDarkMode;
  late bool _analogRandomness;
  late DateStampStyle _dateStampStyle;
  late DateStampPosition _dateStampPosition;
  late bool _saveLocationData;

  @override
  void initState() {
    super.initState();
    _isDarkMode = HiveService.isDarkMode;
    _analogRandomness = HiveService.analogRandomnessEnabled;
    _dateStampStyle = DateStampStyle.values.firstWhere(
      (s) => s.name == HiveService.dateStampStyle,
      orElse: () => DateStampStyle.classic90s,
    );
    _dateStampPosition = DateStampPosition.values.firstWhere(
      (p) => p.name == HiveService.dateStampPosition,
      orElse: () => DateStampPosition.bottomRight,
    );
    _saveLocationData = HiveService.saveLocationDataEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RetroColors.background,
      appBar: AppBar(title: const Text('SETTINGS')),
      body: Stack(
        children: [
          const Positioned.fill(child: GrainOverlay(opacity: 0.03)),
          ListView(
            padding: const EdgeInsets.all(RetroDimens.paddingMd),
            children: [
              // ── Appearance ─────────────────────────────────────────────
              _sectionTitle('APPEARANCE'),
              _settingsTile(
                icon: Icons.dark_mode,
                title: 'Dark Mode',
                subtitle: _isDarkMode ? 'Classic Black' : 'Daylight Yellow',
                trailing: Switch(
                  value: _isDarkMode,
                  onChanged: (v) {
                    setState(() => _isDarkMode = v);
                    HiveService.setDarkMode(v);
                    widget.onThemeChanged();
                  },
                  activeColor: RetroColors.accent,
                ),
              ),
              const Divider(),

              // ── Analog Effects ─────────────────────────────────────────
              _sectionTitle('ANALOG EFFECTS'),
              _settingsTile(
                icon: Icons.auto_awesome,
                title: 'Analog Randomness',
                subtitle: 'Random light streaks, color shifts & dust',
                trailing: Switch(
                  value: _analogRandomness,
                  onChanged: (v) {
                    setState(() => _analogRandomness = v);
                    HiveService.setAnalogRandomness(v);
                  },
                  activeColor: RetroColors.accent,
                ),
              ),
              const Divider(),

              // ── Date Stamp ─────────────────────────────────────────────
              _sectionTitle('DATE STAMP DEFAULT'),
              _dropdownTile<DateStampStyle>(
                icon: Icons.calendar_today,
                title: 'Style',
                value: _dateStampStyle,
                items: DateStampStyle.values,
                labelGetter: (s) => s.label,
                onChanged: (s) {
                  if (s == null) return;
                  setState(() => _dateStampStyle = s);
                  HiveService.setDateStampStyle(s.name);
                },
              ),
              _dropdownTile<DateStampPosition>(
                icon: Icons.place,
                title: 'Position',
                value: _dateStampPosition,
                items: DateStampPosition.values,
                labelGetter: (p) => p.label,
                onChanged: (p) {
                  if (p == null) return;
                  setState(() => _dateStampPosition = p);
                  HiveService.setDateStampPosition(p.name);
                },
              ),
              const Divider(),

              // ── Privacy ───────────────────────────────────────────────
              _sectionTitle('PRIVACY'),
              _settingsTile(
                icon: Icons.location_off,
                title: 'Save Location Data',
                subtitle: 'Preserve GPS EXIF data in exported photos',
                trailing: Switch(
                  value: _saveLocationData,
                  onChanged: (v) {
                    setState(() => _saveLocationData = v);
                    HiveService.setSaveLocationData(v);
                  },
                  activeColor: RetroColors.accent,
                ),
              ),
              const Divider(),

              // ── About ──────────────────────────────────────────────────
              _sectionTitle('ABOUT'),
              _settingsTile(
                icon: Icons.info_outline,
                title: RetroStrings.appName,
                subtitle: '${RetroStrings.tagline}\nv1.0.0',
              ),
              const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.spaceMono(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: RetroColors.accent,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: RetroColors.surface,
          borderRadius: BorderRadius.circular(RetroDimens.radiusSm),
        ),
        child: Icon(icon, size: 20, color: RetroColors.textSecondary),
      ),
      title: Text(
        title,
        style: GoogleFonts.spaceMono(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: RetroColors.textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: RetroColors.textMuted,
              ),
            )
          : null,
      trailing: trailing,
    );
  }

  Widget _dropdownTile<T>({
    required IconData icon,
    required String title,
    required T value,
    required List<T> items,
    required String Function(T) labelGetter,
    required ValueChanged<T?> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: RetroColors.surface,
          borderRadius: BorderRadius.circular(RetroDimens.radiusSm),
        ),
        child: Icon(icon, size: 20, color: RetroColors.textSecondary),
      ),
      title: Text(
        title,
        style: GoogleFonts.spaceMono(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: RetroColors.textPrimary,
        ),
      ),
      trailing: DropdownButton<T>(
        value: value,
        dropdownColor: RetroColors.surface,
        underline: const SizedBox(),
        style: GoogleFonts.spaceMono(
          fontSize: 11,
          color: RetroColors.textSecondary,
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(labelGetter(item)),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
