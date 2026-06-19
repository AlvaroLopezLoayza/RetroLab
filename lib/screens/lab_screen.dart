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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                onTap: (_) => setState(() {}),
                tabs: const [
                  Tab(text: 'FOTOS'),
                  Tab(text: 'VIDEOS'),
                ],
              ),
              _buildFilterBar(),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GrainOverlay(opacity: 0.02)),
          TabBarView(
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
        ],
      ),
    );
  }

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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(RetroDimens.paddingSm),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: _filteredPhotos.length,
      itemBuilder: (context, index) {
        final photo = _filteredPhotos[index];
        final stock = FilmStocks.getById(photo.filmStockId);
        final file = File(photo.processedPath);
        return GestureDetector(
          onTap: () => _openPhotoDetail(photo),
          onLongPress: () => _deletePhoto(photo),
          child: Stack(
            fit: StackFit.expand,
            children: [
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
                        : Container(color: RetroColors.surface),
              ),
              _stockBadge(stock.shortName, stock.badgeColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(RetroDimens.paddingSm),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.72,
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
              borderRadius: BorderRadius.circular(RetroDimens.radiusSm),
              border: Border.all(color: RetroColors.surfaceLight),
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
                          top: Radius.circular(RetroDimens.radiusSm),
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
                        _formatDuration(video.durationMs),
                        style: GoogleFonts.spaceMono(
                          fontSize: 10,
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
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _filteredPhotos.length,
              itemBuilder: (context, index) {
                final photo = _filteredPhotos[index];
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
                            ? Image.file(file, fit: BoxFit.cover, cacheHeight: 400)
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
            title,
            style: GoogleFonts.spaceMono(
              fontSize: 16,
              color: RetroColors.textMuted,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockBadge(String label, Color color) {
    return Positioned(
      top: 4,
      left: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceMono(
            fontSize: 7,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  Future<void> _openPhotoDetail(RetroPhoto photo) async {
    final file = File(photo.processedPath);
    if (!file.existsSync()) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
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
                  _detailAction(Icons.delete_outline, 'Borrar', () async {
                    Navigator.pop(ctx);
                    await _deletePhoto(photo);
                  }),
                  const SizedBox(width: 24),
                  _detailAction(Icons.close, 'Cerrar', () {
                    Navigator.pop(ctx);
                  }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openVideoDetail(RetroVideo video) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _VideoDialog(
        video: video,
        onDelete: () async {
          Navigator.of(context).pop();
          await _deleteVideo(video);
        },
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
            decoration: const BoxDecoration(
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          return Column(
            mainAxisSize: MainAxisSize.min,
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
                              IconButton(
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
                                  size: 64,
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _action(Icons.share, 'Compartir', () {
                    Share.shareXFiles([XFile(widget.video.processedPath)]);
                    Navigator.pop(context);
                  }),
                  const SizedBox(width: 24),
                  _action(Icons.delete_outline, 'Borrar', widget.onDelete),
                  const SizedBox(width: 24),
                  _action(Icons.close, 'Cerrar', () {
                    Navigator.pop(context);
                  }),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
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
