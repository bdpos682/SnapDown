import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
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

    final progress = playback.duration.inMilliseconds > 0
        ? (playback.position.inMilliseconds / playback.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: () {
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: isDark ? AppColors.liquidGlassElevatedDark : AppColors.liquidGlassElevatedLight,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white.withAlpha(40) : Colors.white.withAlpha(200),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 60 : 15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                // Top micro progress line
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                    child: Row(
                      children: [
                        // Artwork Thumbnail
                        _buildArtwork(playback),
                        const SizedBox(width: AppSpacing.s12),

                        // Title & Artist
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                playback.title.isNotEmpty ? HtmlUtils.unescape(playback.title) : 'Đang phát media',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                playback.isVideoMode
                                    ? (playback.isAudioOnly ? 'Chế độ chỉ phát âm thanh' : 'Đang phát video')
                                    : (playback.artist.isNotEmpty ? playback.artist : 'Trình phát SnapDown'),
                                style: AppTypography.caption.copyWith(color: textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Play/Pause Button
                        IconButton(
                          onPressed: () => controller.togglePlayPause(),
                          icon: Icon(
                            playback.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: textPrimary,
                            size: 28,
                          ),
                        ),

                        // Next Button (if in queue or audio)
                        if (!playback.isVideoMode)
                          IconButton(
                            onPressed: () => controller.next(),
                            icon: Icon(
                              Icons.skip_next_rounded,
                              color: textSecondary,
                              size: 24,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildArtwork(dynamic playback) {
    Widget imageWidget;
    if (playback.thumbnailPath != null && File(playback.thumbnailPath!).existsSync()) {
      imageWidget = Image.file(
        File(playback.thumbnailPath!),
        fit: BoxFit.cover,
        width: 44,
        height: 44,
      );
    } else if (playback.thumbnailUrl != null) {
      imageWidget = Image.network(
        playback.thumbnailUrl!,
        fit: BoxFit.cover,
        width: 44,
        height: 44,
        errorBuilder: (context, error, stackTrace) => _defaultArtwork(playback.isVideoMode),
      );
    } else {
      imageWidget = _defaultArtwork(playback.isVideoMode);
    }

    return ClipRRect(
      borderRadius: AppRadius.radiusSm,
      child: Container(
        width: 44,
        height: 44,
        color: AppColors.darkHighlight,
        child: imageWidget,
      ),
    );
  }

  Widget _defaultArtwork(bool isVideo) {
    return Container(
      color: AppColors.darkHighlight,
      child: Center(
        child: Icon(
          isVideo ? Icons.movie_rounded : Icons.music_note_rounded,
          color: AppColors.accentCyan,
          size: 22,
        ),
      ),
    );
  }
}
