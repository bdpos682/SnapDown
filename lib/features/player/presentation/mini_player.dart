import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings_vi.dart';
import '../../../core/utils/html_utils.dart';
import '../controller/global_playback_controller.dart';
import 'music_player_screen.dart';
import 'video_player_screen.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);

    if (!playback.hasMedia) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final accent = isDark ? AppColors.accentCyan : AppColors.accentBlue;

    final progress = playback.duration.inMilliseconds > 0
        ? (playback.position.inMilliseconds / playback.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final title = HtmlUtils.unescape(playback.title.isNotEmpty ? playback.title : 'Đang phát nội dung');
    final artist = HtmlUtils.unescape(playback.artist.isNotEmpty ? playback.artist : AppStringsVi.appName);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: isDark ? AppColors.liquidGlassElevatedDark : AppColors.liquidGlassElevatedLight,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? Colors.white.withAlpha(35) : Colors.black.withAlpha(12),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 80 : 15),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Nội dung chính
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      // Khu vực chạm để Mở toàn màn hình phát (Ảnh bìa + Tiêu đề + Nghệ sĩ)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (playback.isVideoMode) {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const VideoPlayerScreen()),
                              );
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
                              );
                            }
                          },
                          child: Row(
                            children: [
                              // Ảnh bìa
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: _buildArtwork(playback),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Tiêu đề & Tác giả
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Nút Bật / Tạm dừng
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          controller.togglePlayPause();
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                          ),
                          child: Center(
                            child: Icon(
                              playback.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Nút Đóng / Tắt hẳn bài hát và đóng popup thẻ MiniPlayer
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          await controller.dismissPlayer();
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(8),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.close_rounded,
                              color: textSecondary,
                              size: 19,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                  // Thanh tiến trình siêu mảnh uốn mép dưới
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 2.2,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                  ),
                ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtwork(dynamic playback) {
    if (playback.thumbnailPath != null && File(playback.thumbnailPath!).existsSync()) {
      return Image.file(
        File(playback.thumbnailPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, error, stack) => _defaultArtwork(),
      );
    }
    if (playback.thumbnailUrl != null && playback.thumbnailUrl!.isNotEmpty) {
      return Image.network(
        playback.thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stack) => _defaultArtwork(),
      );
    }
    return _defaultArtwork();
  }

  Widget _defaultArtwork() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}
