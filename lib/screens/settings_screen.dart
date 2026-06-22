library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/hive_boxes.dart';
import '../widgets/grain_overlay.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onThemeChanged;

  const SettingsScreen({super.key, this.onThemeChanged});

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
              _buildHeroCard(),
              const SizedBox(height: 20),
              _sectionTitle('CAPTURE LOOK'),
              _sectionCard(
                children: [
                  _settingsTile(
                    icon: Icons.auto_awesome,
                    title: 'Analog Randomness',
                    subtitle: 'Variations in glare, drift, and texture mood',
                    trailing: Switch(
                      value: _analogRandomness,
                      onChanged: (v) {
                        setState(() => _analogRandomness = v);
                        HiveService.setAnalogRandomness(v);
                      },
                      activeThumbColor: RetroColors.accent,
                    ),
                  ),
                  const Divider(),
                  _dropdownTile<DateStampStyle>(
                    icon: Icons.calendar_today,
                    title: 'Date Stamp Style',
                    value: _dateStampStyle,
                    items: DateStampStyle.values,
                    labelGetter: (s) => s.label,
                    onChanged: (s) {
                      if (s == null) return;
                      setState(() => _dateStampStyle = s);
                      HiveService.setDateStampStyle(s.name);
                    },
                  ),
                  const Divider(),
                  _dropdownTile<DateStampPosition>(
                    icon: Icons.place,
                    title: 'Date Stamp Position',
                    value: _dateStampPosition,
                    items: DateStampPosition.values,
                    labelGetter: (p) => p.label,
                    onChanged: (p) {
                      if (p == null) return;
                      setState(() => _dateStampPosition = p);
                      HiveService.setDateStampPosition(p.name);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _sectionTitle('APP'),
              _sectionCard(
                children: [
                  _settingsTile(
                    icon: Icons.dark_mode,
                    title: 'Dark Mode',
                    subtitle: _isDarkMode ? 'Classic Black' : 'Daylight Yellow',
                    trailing: Switch(
                      value: _isDarkMode,
                      onChanged: (v) {
                        setState(() => _isDarkMode = v);
                        HiveService.setDarkMode(v);
                        widget.onThemeChanged?.call();
                      },
                      activeThumbColor: RetroColors.accent,
                    ),
                  ),
                  const Divider(),
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
                      activeThumbColor: RetroColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _sectionTitle('ABOUT'),
              _sectionCard(
                children: [
                  _settingsTile(
                    icon: Icons.info_outline,
                    title: RetroStrings.appName,
                    subtitle: '${RetroStrings.tagline}\nv1.0.0',
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(RetroDimens.paddingMd),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF26201B), RetroColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tune The Camera',
            style: GoogleFonts.spaceMono(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: RetroColors.textPrimary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep the defaults intentional so the camera feels consistent before the first shot.',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: RetroColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip(
                _analogRandomness ? 'RANDOM ON' : 'RANDOM OFF',
                _analogRandomness ? RetroColors.accent : RetroColors.textMuted,
              ),
              _summaryChip(
                _isDarkMode ? 'DARK UI' : 'LIGHT UI',
                RetroColors.dateYellow,
              ),
              _summaryChip(_dateStampStyle.label, RetroColors.accentLight),
              _summaryChip(_dateStampPosition.label, RetroColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceMono(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.9,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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

  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: RetroColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(children: children),
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
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: RetroColors.surfaceLight,
          borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
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
      subtitle:
          subtitle == null
              ? null
              : Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  height: 1.4,
                  color: RetroColors.textMuted,
                ),
              ),
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
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: RetroColors.surfaceLight,
          borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
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
        borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
        style: GoogleFonts.spaceMono(
          fontSize: 11,
          color: RetroColors.textSecondary,
        ),
        items:
            items
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
