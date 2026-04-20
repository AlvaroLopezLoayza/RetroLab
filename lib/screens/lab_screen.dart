/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Lab Screen (Advanced Gallery)
///
/// Grid gallery of all developed photos with film stock badges,
/// film strip view mode, filtering, and export capabilities.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants.dart';
import '../core/film_stocks.dart';
import '../core/hive_boxes.dart';
import '../models/retro_photo.dart';
import '../utils/image_processor.dart';
import '../widgets/grain_overlay.dart';
import 'stats_screen.dart';

class LabScreen extends StatefulWidget {
  const LabScreen({super.key});

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<RetroPhoto> _photos = [];
  String? _filterStockId;
  bool _isFilmStripView = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPhotos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadPhotos() {
    final box = HiveService.photosBox;
    final photos = <RetroPhoto>[];
    for (int i = 0; i < box.length; i++) {
      final map = box.getAt(i);
      if (map != null) {
        photos.add(RetroPhoto.fromMap(Map<String, dynamic>.from(map)));
      }
    }
    photos.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    setState(() => _photos = photos);
  }

  List<RetroPhoto> get _filteredPhotos {
    if (_filterStockId == null) return _photos;
    return _photos.where((p) => p.filmStockId == _filterStockId).toList();
  }

  Future<void> _exportAsFilmStrip() async {
    final photos = _filteredPhotos;
    if (photos.isEmpty) return;

    try {
      final files =
          photos
              .map((p) => File(p.processedPath))
              .where((f) => f.existsSync())
              .toList();

      if (files.isEmpty) return;

      final stripFile = await ImageProcessor.createFilmStrip(
        files.take(12).toList(),
      );
      Share.shareXFiles([XFile(stripFile.path)], text: RetroStrings.watermark);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  void _deletePhoto(RetroPhoto photo) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              'Delete Photo?',
              style: GoogleFonts.spaceMono(color: RetroColors.textPrimary),
            ),
            content: Text(
              'This action cannot be undone.',
              style: GoogleFonts.inter(color: RetroColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () {
                  HiveService.photosBox.delete(photo.id);
                  _loadPhotos();
                  Navigator.pop(ctx);
                },
                child: Text(
                  'DELETE',
                  style: GoogleFonts.spaceMono(color: RetroColors.error),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RetroColors.background,
      appBar: AppBar(
        title: const Text('THE LAB'),
        actions: [
          // View toggle
          IconButton(
            icon: Icon(
              _isFilmStripView
                  ? Icons.grid_view_rounded
                  : Icons.view_column_rounded,
            ),
            onPressed:
                () => setState(() => _isFilmStripView = !_isFilmStripView),
            tooltip: _isFilmStripView ? 'Grid View' : 'Film Strip View',
          ),
          // Export strip
          IconButton(
            icon: const Icon(Icons.movie_filter),
            onPressed: _exportAsFilmStrip,
            tooltip: 'Export Film Strip',
          ),
          // Stats
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StatsScreen()),
                ),
            tooltip: 'Stats',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildFilterBar(),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GrainOverlay(opacity: 0.02)),

          _filteredPhotos.isEmpty
              ? _buildEmptyState()
              : _isFilmStripView
              ? _buildFilmStripView()
              : _buildGridView(),
        ],
      ),
    );
  }

  // ── Filter Bar ─────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: RetroDimens.paddingMd),
        children: [
          _filterChip(null, 'ALL'),
          ...FilmStocks.all.map(
            (stock) => _filterChip(stock.id, stock.shortName, stock.badgeColor),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String? stockId, String label, [Color? color]) {
    final isSelected = _filterStockId == stockId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filterStockId = stockId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? (color ?? RetroColors.accent).withValues(alpha: 0.2)
                    : RetroColors.surface,
            borderRadius: BorderRadius.circular(RetroDimens.radiusSm),
            border: Border.all(
              color:
                  isSelected
                      ? (color ?? RetroColors.accent)
                      : RetroColors.surfaceLight,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.spaceMono(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color:
                  isSelected
                      ? (color ?? RetroColors.accent)
                      : RetroColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  // ── Grid View ──────────────────────────────────────────────────────────

  Widget _buildGridView() {
    final photos = _filteredPhotos;
    return GridView.builder(
      padding: const EdgeInsets.all(RetroDimens.paddingSm),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        final stock = FilmStocks.getById(photo.filmStockId);
        final file = File(photo.processedPath);

        return GestureDetector(
          onTap: () => _openPhotoDetail(photo),
          onLongPress: () => _deletePhoto(photo),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child:
                    file.existsSync()
                        ? Image.file(
                          file,
                          fit: BoxFit.cover,
                          cacheWidth: 300,
                          cacheHeight: 300,
                        )
                        : Container(
                          color: RetroColors.surface,
                          child: const Icon(
                            Icons.broken_image,
                            color: RetroColors.textMuted,
                          ),
                        ),
              ),
              // Film stock badge
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    stock.shortName,
                    style: GoogleFonts.spaceMono(
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                      color: stock.badgeColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Film Strip View ────────────────────────────────────────────────────

  Widget _buildFilmStripView() {
    final photos = _filteredPhotos;
    return Container(
      color: const Color(0xFF1A1510),
      child: Column(
        children: [
          // Sprocket holes (top)
          _buildSprocketRow(),

          // Horizontal scroll of frames
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                final file = File(photo.processedPath);

                return GestureDetector(
                  onTap: () => _openPhotoDetail(photo),
                  child: Container(
                    width: 200,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF3D3530),
                        width: 2,
                      ),
                    ),
                    child:
                        file.existsSync()
                            ? Image.file(
                              file,
                              fit: BoxFit.cover,
                              cacheHeight: 400,
                            )
                            : Container(color: RetroColors.surface),
                  ),
                );
              },
            ),
          ),

          // Sprocket holes (bottom)
          _buildSprocketRow(),
        ],
      ),
    );
  }

  Widget _buildSprocketRow() {
    return SizedBox(
      height: 20,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 50,
        itemBuilder:
            (_, __) => Container(
              width: 10,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0A08),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_roll_outlined,
            size: 80,
            color: RetroColors.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'AÚN NO HAY FOTOS',
            style: GoogleFonts.spaceMono(
              fontSize: 16,
              color: RetroColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toma algunas fotos para ver crecer tu galería.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: RetroColors.textMuted.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ── Photo Detail ───────────────────────────────────────────────────────

  void _openPhotoDetail(RetroPhoto photo) {
    final file = File(photo.processedPath);
    if (!file.existsSync()) return;

    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
                  child: Image.file(file, fit: BoxFit.contain),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _detailAction(Icons.share, 'Compartir', () {
                      Share.shareXFiles([XFile(photo.processedPath)]);
                      Navigator.pop(ctx);
                    }),
                    const SizedBox(width: 24),
                    _detailAction(Icons.delete_outline, 'Borrar', () {
                      Navigator.pop(ctx);
                      _deletePhoto(photo);
                    }),
                    const SizedBox(width: 24),
                    _detailAction(Icons.close, 'Cerrar', () {
                      Navigator.pop(ctx);
                    }),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Widget _detailAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: RetroColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: RetroColors.textPrimary, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.spaceMono(
              fontSize: 9,
              color: RetroColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
