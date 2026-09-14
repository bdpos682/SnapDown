import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/models/media_item_model.dart';
import '../../../core/database/repositories/media_repository.dart';
import '../../../core/storage/storage_manager.dart';
import '../../player/controller/global_playback_controller.dart';
import '../../player/presentation/video_player_screen.dart';
import '../controller/library_state_provider.dart';

class VideoLibraryScreen extends ConsumerStatefulWidget {
  const VideoLibraryScreen({super.key});

  @override
  ConsumerState<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends ConsumerState<VideoLibraryScreen> {
  final MediaRepository _repository = MediaRepository();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteVideo(MediaItemModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa video?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc chắn muốn xóa "${item.title}" khỏi thiết bị?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageManager().deleteFile(item.localPath);
      if (item.thumbnailPath != null) {
        await StorageManager().deleteFile(item.thumbnailPath!);
      }
      await _repository.deleteMedia(item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? Colors.white.withAlpha(160) : const Color(0xFF6B7280);
    const videoAccent = Color(0xFF007AFF); // Apple iOS Cinema Blue

    final videoAsync = ref.watch(videoLibraryProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Apple TV Large Header
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 16, top: 12, bottom: 4),
              child: Text(
                'Video',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
            ),

            // 2. iOS Translucent Search Capsule
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.black.withAlpha(12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    Icon(Icons.search_rounded, color: textSecondary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(color: textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm video rạp chiếu...',
                          hintStyle: TextStyle(color: textSecondary.withAlpha(140), fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.cancel_rounded, size: 18),
                        color: textSecondary,
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            // 3. Video Grid View
            Expanded(
              child: videoAsync.when(
                data: (allVideos) {
                  var videos = allVideos;
                  final query = _searchController.text.trim().toLowerCase();
                  if (query.isNotEmpty) {
                    videos = videos.where((v) =>
                      v.title.toLowerCase().contains(query) ||
                      v.artist.toLowerCase().contains(query),
                    ).toList();
                  }

                  if (videos.isEmpty) {
                    return _buildEmptyState(textPrimary, textSecondary);
                  }

                  return Column(
                    children: [
                      // Play All Capsule Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(isDark ? 40 : 8),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                ref.read(playbackControllerProvider.notifier).playAll(videos, shuffle: false);
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const VideoPlayerScreen()),
                                );
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.play_arrow_rounded, color: videoAccent, size: 24),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Phát tất cả (${videos.length} video)',
                                    style: const TextStyle(
                                      color: videoAccent,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.only(left: 18, right: 18, top: 4, bottom: 120),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.96,
                          ),
                          itemCount: videos.length,
                          itemBuilder: (context, index) {
                            final video = videos[index];
                            return _buildVideoCard(video, videos, isDark, textPrimary, textSecondary, videoAccent);
                          },
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: videoAccent)),
                error: (err, _) => Center(child: Text('Lỗi tải video: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(
    MediaItemModel video,
    List<MediaItemModel> queue,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color accent,
  ) {
    final progress = video.durationMs > 0 ? (video.lastPositionMs / video.durationMs).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(playbackControllerProvider.notifier).playLocalItem(video, queue: queue, resumePosition: false);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const VideoPlayerScreen()),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 35 : 8),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail & Badges
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                      child: video.thumbnailPath != null && File(video.thumbnailPath!).existsSync()
                          ? Image.file(File(video.thumbnailPath!), fit: BoxFit.cover)
                          : (video.thumbnailUrl != null
                              ? Image.network(video.thumbnailUrl!, fit: BoxFit.cover)
                              : Icon(Icons.movie_rounded, color: accent, size: 40)),
                    ),

                    // Duration Badge (Bottom Right)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(190),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          video.formattedDuration,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                    // Resolution Badge (Top Left)
                    if (video.formattedResolution.isNotEmpty)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            video.formattedResolution,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),

                    // Resume Progress Line
                    if (progress > 0)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFA2D48)),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Video Title & Options
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${video.formattedFileSize} • ${video.container.toUpperCase()}',
                        style: TextStyle(color: textSecondary, fontSize: 10.5, fontWeight: FontWeight.w500),
                      ),
                      GestureDetector(
                        onTap: () => _deleteVideo(video),
                        child: Icon(Icons.more_horiz_rounded, size: 18, color: textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie_rounded, color: textSecondary.withAlpha(120), size: 64),
          const SizedBox(height: 14),
          Text(
            'Chưa có video nào',
            style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Video sau khi tải sẽ tự động xuất hiện tại đây.',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
