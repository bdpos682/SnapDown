import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
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
        title: const Text('Xóa video?'),
        content: Text('Bạn có chắc chắn muốn xóa "${item.title}" khỏi bộ nhớ thiết bị?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa', style: TextStyle(color: AppColors.accentRed)),
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
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final primaryAccent = isDark ? AppColors.accentCyan : AppColors.accentBlue;

    final videoAsync = ref.watch(videoLibraryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Thư viện Video', style: AppTypography.h2.copyWith(color: textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm video...',
                prefixIcon: Icon(Icons.search_rounded, color: primaryAccent),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Lưới Video
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
                  return _buildEmptyState(textSecondary);
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            ref.read(playbackControllerProvider.notifier).playAll(videos, shuffle: false);
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const VideoPlayerScreen()),
                            );
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 24),
                          label: Text('Phát tất cả (${videos.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 120),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: AppSpacing.s12,
                          mainAxisSpacing: AppSpacing.s16,
                          childAspectRatio: 0.95,
                        ),
                        itemCount: videos.length,
                        itemBuilder: (context, index) {
                          final video = videos[index];
                          return _buildVideoCard(video, videos, isDark, textPrimary, textSecondary, primaryAccent);
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => Center(child: CircularProgressIndicator(color: primaryAccent)),
              error: (err, _) => Center(child: Text('Lỗi tải video: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(
    MediaItemModel video,
    List<MediaItemModel> queue,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color primaryAccent,
  ) {
    final progress = video.durationMs > 0 ? (video.lastPositionMs / video.durationMs).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: () {
        ref.read(playbackControllerProvider.notifier).playLocalItem(video, queue: queue, resumePosition: false);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const VideoPlayerScreen()),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail & Badges
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadius.radiusMd,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: AppColors.darkHighlight,
                    child: video.thumbnailPath != null && File(video.thumbnailPath!).existsSync()
                        ? Image.file(File(video.thumbnailPath!), fit: BoxFit.cover)
                        : (video.thumbnailUrl != null
                            ? Image.network(video.thumbnailUrl!, fit: BoxFit.cover)
                            : Icon(Icons.movie_rounded, color: primaryAccent, size: 40)),
                  ),

                  // Badge thời lượng (góc dưới phải)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(200),
                        borderRadius: AppRadius.radiusXs,
                      ),
                      child: Text(
                        video.formattedDuration,
                        style: AppTypography.caption.copyWith(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),

                  // Badge độ phân giải (góc trên trái)
                  if (video.formattedResolution.isNotEmpty)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryAccent,
                          borderRadius: AppRadius.radiusXs,
                        ),
                        child: Text(
                          video.formattedResolution,
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),

                  // Thanh tiến trình xem dở
                  if (progress > 0)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentAmber),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Tiêu đề & Thông số
          Text(
            video.title,
            style: AppTypography.bodySmall.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${video.formattedFileSize} • ${video.container.toUpperCase()}',
                style: AppTypography.caption.copyWith(color: textSecondary, fontSize: 10),
              ),
              GestureDetector(
                onTap: () => _deleteVideo(video),
                child: Icon(Icons.more_horiz_rounded, size: 18, color: textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.video_library_rounded, color: AppColors.accentCyan, size: 54),
          const SizedBox(height: AppSpacing.s16),
          Text('Chưa có video nào', style: AppTypography.h3),
          const SizedBox(height: 6),
          Text('Video sau khi tải sẽ tự động xuất hiện ở đây.', style: AppTypography.bodySmall.copyWith(color: textSecondary)),
        ],
      ),
    );
  }
}
