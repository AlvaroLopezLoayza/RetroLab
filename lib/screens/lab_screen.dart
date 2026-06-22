library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../core/constants.dart';
import '../core/film_stocks.dart';
import '../core/hive_boxes.dart';
import '../models/retro_photo.dart';
import '../models/retro_video.dart';
import '../utils/image_processor.dart';
import '../widgets/grain_overlay.dart';
import 'stats_screen.dart';

class LabScreen extends StatefulWidget {
  final int initialTab;

  const LabScreen({super.key, this.initialTab = 0});

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<RetroPhoto> _photos = [];
  List<RetroVideo> _videos = [];
  String? _filterStockId;
  bool _isFilmStripView = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _loadMedia();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadMedia() {
    final photos = <RetroPhoto>[];
    final videos = <RetroVideo>[];

    for (int i = 0; i < HiveService.photosBox.length; i++) {
      final map = HiveService.photosBox.getAt(i);
      if (map != null) {
        photos.add(RetroPhoto.fromMap(Map<String, dynamic>.from(map)));
      }
    }
    for (int i = 0; i < HiveService.videosBox.length; i++) {
      final map = HiveService.videosBox.getAt(i);
      if (map != null) {
        videos.add(RetroVideo.fromMap(Map<String, dynamic>.from(map)));
      }
    }

    photos.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    videos.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));

    setState(() {
      _photos = photos;
      _videos = videos;
    });
  }

  List<RetroPhoto> get _filteredPhotos {
    if (_filterStockId == null) return _photos;
    return _photos.where((p) => p.filmStockId == _filterStockId).toList();
  }

  List<RetroVideo> get _filteredVideos {
    if (_filterStockId == null) return _videos;
    return _videos.where((v) => v.filmStockId == _filterStockId).toList();
  }

  String get _activeFilterLabel {
    if (_filterStockId == null) return 'ALL STOCKS';
    return FilmStocks.getById(_filterStockId!).name.toUpperCase();
  }

  Future<void> _exportAsFilmStrip() async {
    final files =
        _filteredPhotos
            .map((p) => File(p.processedPath))
            .where((f) => f.existsSync())
            .take(12)
            .toList();
    if (files.isEmpty) return;
    final stripFile = await ImageProcessor.createFilmStrip(files);
    Share.shareXFiles([XFile(stripFile.path)], text: RetroStrings.watermark);
  }

  Future<void> _deletePhoto(RetroPhoto photo) async {
    final confirmed = await _confirmDelete('foto');
    if (confirmed != true) return;
    await HiveService.photosBox.delete(photo.id);
    final file = File(photo.processedPath);
    if (file.existsSync()) {
      await file.delete();
    }
    _loadMedia();
  }

  Future<void> _deleteVideo(RetroVideo video) async {
    final confirmed = await _confirmDelete('video');
    if (confirmed != true) return;
    await HiveService.videosBox.delete(video.id);
    for (final path in [video.processedPath, video.thumbnailPath]) {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    }
    _loadMedia();
  }

  Future<bool?> _confirmDelete(String kind) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: RetroColors.surface,
          title: Text(
            'Borrar $kind',
            style: GoogleFonts.spaceMono(color: RetroColors.textPrimary),
          ),
          content: Text(
            'Esta acción no se puede deshacer.',
            style: GoogleFonts.inter(color: RetroColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCELAR'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'BORRAR',
                style: GoogleFonts.spaceMono(color: RetroColors.error),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RetroColors.background,
      appBar: AppBar(
        title: const Text('THE LAB'),
        actions: [
          IconButton(
            icon: Icon(
              _isFilmStripView
                  ? Icons.grid_view_rounded
                  : Icons.view_column_rounded,
            ),
            onPressed:
                _tabController.index == 0
                    ? () => setState(() => _isFilmStripView = !_isFilmStripView)
                    : null,
          ),
          IconButton(
            icon: const Icon(Icons.movie_filter),
            onPressed: _tabController.index == 0 ? _exportAsFilmStrip : null,
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StatsScreen()),
                ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GrainOverlay(opacity: 0.02)),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildLabHero(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: RetroColors.surface.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      onTap: (_) => setState(() {}),
                      indicator: BoxDecoration(
                        color: RetroColors.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(
                          RetroDimens.radiusMd,
                        ),
                      ),
                      dividerColor: Colors.transparent,
                      labelColor: RetroColors.accent,
                      unselectedLabelColor: RetroColors.textSecondary,
                      labelStyle: GoogleFonts.spaceMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                      tabs: const [Tab(text: 'FOTOS'), Tab(text: 'VIDEOS')],
                    ),
                  ),
                ),
              ),
              _buildFilterBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _filteredPhotos.isEmpty
                        ? _buildEmptyState('AUN NO HAY FOTOS')
                        : _isFilmStripView
                        ? _buildFilmStripView()
                        : _buildPhotoGrid(),
                    _filteredVideos.isEmpty
                        ? _buildEmptyState('AUN NO HAY VIDEOS')
                        : _buildVideoGrid(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RetroDimens.paddingMd),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF221B16), RetroColors.surface],
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
            'Developed Archive',
            style: GoogleFonts.spaceMono(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: RetroColors.textPrimary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A tighter view of the images and clips that made it out of the roll.',
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
              _summaryChip('${_photos.length} PHOTOS', RetroColors.accent),
              _summaryChip('${_videos.length} VIDEOS', RetroColors.dateYellow),
              _summaryChip(_activeFilterLabel, RetroColors.textSecondary),
              if (_tabController.index == 0)
                _summaryChip(
                  _isFilmStripView ? 'FILM STRIP' : 'GRID VIEW',
                  RetroColors.accentLight,
                ),
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

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _filterChip(null, 'ALL'),
            ...FilmStocks.all.map(
              (stock) =>
                  _filterChip(stock.id, stock.shortName, stock.badgeColor),
            ),
          ],
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? (color ?? RetroColors.accent).withValues(alpha: 0.2)
                    : RetroColors.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  isSelected
                      ? (color ?? RetroColors.accent)
                      : Colors.white.withValues(alpha: 0.08),
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 600
                ? 3
                : 2;
        return GridView.builder(
          padding: const EdgeInsets.all(RetroDimens.paddingMd),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemCount: _filteredPhotos.length,
          itemBuilder: (context, index) {
            final photo = _filteredPhotos[index];
            final stock = FilmStocks.getById(photo.filmStockId);
            final file = File(photo.processedPath);
            return GestureDetector(
              onTap: () => _openPhotoDetail(photo),
              onLongPress: () => _deletePhoto(photo),
              child: Container(
                decoration: BoxDecoration(
                  color: RetroColors.surface,
                  borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(RetroDimens.radiusMd),
                            ),
                            child:
                                file.existsSync()
                                    ? Image.file(
                                      file,
                                      fit: BoxFit.cover,
                                      cacheWidth: 500,
                                      cacheHeight: 500,
                                    )
                                    : Container(
                                      color: RetroColors.surfaceLight,
                                    ),
                          ),
                          _stockBadge(stock.shortName, stock.badgeColor),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stock.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: stock.badgeColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatCapturedAt(photo.capturedAt),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: RetroColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVideoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(RetroDimens.paddingMd),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.74,
      ),
      itemCount: _filteredVideos.length,
      itemBuilder: (context, index) {
        final video = _filteredVideos[index];
        final stock = FilmStocks.getById(video.filmStockId);
        final thumb = File(video.thumbnailPath);
        return GestureDetector(
          onTap: () => _openVideoDetail(video),
          onLongPress: () => _deleteVideo(video),
          child: Container(
            decoration: BoxDecoration(
              color: RetroColors.surface,
              borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(RetroDimens.radiusMd),
                        ),
                        child:
                            thumb.existsSync()
                                ? Image.file(thumb, fit: BoxFit.cover)
                                : Container(color: RetroColors.surfaceLight),
                      ),
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white70,
                          size: 56,
                        ),
                      ),
                      _stockBadge(stock.shortName, stock.badgeColor),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        stock.shortName,
                        style: GoogleFonts.spaceMono(
                          fontSize: 10,
                          color: stock.badgeColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${_formatDuration(video.durationMs)} · ${_formatCapturedAt(video.capturedAt)}',
                        style: GoogleFonts.spaceMono(
                          fontSize: 9,
                          color: RetroColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilmStripView() {
    return Container(
      color: const Color(0xFF1A1510),
      child: Column(
        children: [
          _buildSprocketRow(),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _filteredPhotos.length,
              itemBuilder: (context, index) {
                final photo = _filteredPhotos[index];
                final file = File(photo.processedPath);
                return GestureDetector(
                  onTap: () => _openPhotoDetail(photo),
                  child: Container(
                    width: 220,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
                      border: Border.all(
                        color: const Color(0xFF3D3530),
                        width: 2,
                      ),
                    ),
                    child:
                        file.existsSync()
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(
                                RetroDimens.radiusSm,
                              ),
                              child: Image.file(
                                file,
                                fit: BoxFit.cover,
                                cacheHeight: 420,
                              ),
                            )
                            : Container(color: RetroColors.surface),
                  ),
                );
              },
            ),
          ),
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

  Widget _buildEmptyState(String title) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: RetroColors.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.camera_roll_outlined,
              size: 72,
              color: RetroColors.textMuted.withValues(alpha: 0.42),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: GoogleFonts.spaceMono(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: RetroColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Shoot something worth keeping and it will show up here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: RetroColors.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stockBadge(String label, Color color) {
    return Positioned(
      top: 4,
      left: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceMono(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  String _formatCapturedAt(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
  }

  Future<void> _openPhotoDetail(RetroPhoto photo) async {
    final file = File(photo.processedPath);
    if (!file.existsSync()) return;
    final stock = FilmStocks.getById(photo.filmStockId);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: RetroColors.surface.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
                    child: Image.file(file, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stock.name,
                              style: GoogleFonts.spaceMono(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: stock.badgeColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatCapturedAt(photo.capturedAt),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: RetroColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _metadataPill(stock.processLabel),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _detailAction(
                          Icons.share,
                          'Compartir',
                          RetroColors.accent,
                          () {
                            Share.shareXFiles([XFile(photo.processedPath)]);
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _detailAction(
                          Icons.delete_outline,
                          'Borrar',
                          RetroColors.error,
                          () async {
                            Navigator.pop(ctx);
                            await _deletePhoto(photo);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _detailAction(
                          Icons.close,
                          'Cerrar',
                          RetroColors.textSecondary,
                          () {
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openVideoDetail(RetroVideo video) async {
    await showDialog<void>(
      context: context,
      builder:
          (_) => _VideoDialog(
            video: video,
            onDelete: () async {
              Navigator.of(context).pop();
              await _deleteVideo(video);
            },
          ),
    );
  }

  Widget _metadataPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: RetroColors.surfaceLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceMono(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: RetroColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _detailAction(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceMono(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int durationMs) {
    final totalSeconds = (durationMs / 1000).round();
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _VideoDialog extends StatefulWidget {
  final RetroVideo video;
  final Future<void> Function() onDelete;

  const _VideoDialog({required this.video, required this.onDelete});

  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
  late final VideoPlayerController _controller;
  Future<void>? _initFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.video.processedPath));
    _initFuture = _controller.initialize().then((_) {
      _controller.setLooping(true);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(int durationMs) {
    final totalSeconds = (durationMs / 1000).round();
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatCapturedAt(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
  }

  Widget _metadataPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: RetroColors.surfaceLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceMono(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: RetroColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stock = FilmStocks.getById(widget.video.filmStockId);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          return Container(
            decoration: BoxDecoration(
              color: RetroColors.surface.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
                    child:
                        _controller.value.isInitialized
                            ? AspectRatio(
                              aspectRatio: _controller.value.aspectRatio,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  VideoPlayer(_controller),
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.42,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.14,
                                        ),
                                      ),
                                    ),
                                    child: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          if (_controller.value.isPlaying) {
                                            _controller.pause();
                                          } else {
                                            _controller.play();
                                          }
                                        });
                                      },
                                      icon: Icon(
                                        _controller.value.isPlaying
                                            ? Icons.pause_circle_filled
                                            : Icons.play_circle_fill,
                                        color: Colors.white70,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : Container(
                              height: 320,
                              color: RetroColors.surface,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stock.name,
                              style: GoogleFonts.spaceMono(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: stock.badgeColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatDuration(widget.video.durationMs)} · ${_formatCapturedAt(widget.video.capturedAt)}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: RetroColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _metadataPill(stock.processLabel),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _action(
                          Icons.share,
                          'Compartir',
                          RetroColors.accent,
                          () {
                            Share.shareXFiles([
                              XFile(widget.video.processedPath),
                            ]);
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _action(
                          Icons.delete_outline,
                          'Borrar',
                          RetroColors.error,
                          widget.onDelete,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _action(
                          Icons.close,
                          'Cerrar',
                          RetroColors.textSecondary,
                          () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _action(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceMono(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
