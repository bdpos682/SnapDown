import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/database/models/media_item_model.dart';
import '../../../core/database/repositories/media_repository.dart';
import '../../../core/storage/storage_manager.dart';
import '../../../core/utils/html_utils.dart';
import '../../player/controller/global_playback_controller.dart';
import '../../player/presentation/music_player_screen.dart';
import '../../player/presentation/video_player_screen.dart';
import '../domain/download_status.dart';
import '../domain/download_task.dart';
import '../engine/download_manager.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  final MediaRepository _repository = MediaRepository();
  final DownloadManager _manager = DownloadManager();
  final StorageManager _storage = StorageManager();

  int _selectedFilterIndex = 0; // 0: Tất cả, 1: Đang tải, 2: Đã tải xong

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final accent = isDark ? AppColors.accentCyan : AppColors.accentBlue;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tải xuống',
          style: AppTypography.h2.copyWith(color: textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_rounded),
            tooltip: 'Dọn dẹp danh sách đã tải',
            onPressed: () => _showClearCompletedDialog(context),
          ),
          const SizedBox(width: AppSpacing.s8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildFilterTabs(isDark, accent, textPrimary, textSecondary),
        ),
      ),
      body: StreamBuilder<List<DownloadTask>>(
        stream: _manager.tasksStream,
        initialData: _manager.tasks,
        builder: (context, taskSnapshot) {
          final activeTasks = taskSnapshot.data ?? [];

          return StreamBuilder<List<MediaItemModel>>(
            stream: _repository.watchAllMedia(),
            builder: (context, mediaSnapshot) {
              final completedMedia = mediaSnapshot.data ?? [];

              // Lọc các mục theo tab đã chọn
              final filteredActiveTasks = activeTasks.where((t) {
                if (_selectedFilterIndex == 2) return false; // Chỉ hiển thị đã xong
                return t.status.isActive || t.status == DownloadStatus.failed || t.status == DownloadStatus.canceled;
              }).toList();

              final filteredCompleted = completedMedia.where((m) {
                if (_selectedFilterIndex == 1) return false; // Chỉ hiển thị đang tải
                // Tránh hiển thị trùng nếu task vừa tải xong đang tồn tại ở cả 2 nguồn
                return !activeTasks.any((t) => t.id == m.id && t.status.isActive);
              }).toList();

              final totalItems = filteredActiveTasks.length + filteredCompleted.length;

              if (totalItems == 0) {
                return _buildEmptyState(textSecondary, isDark);
              }

              return ListView.builder(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 120),
                itemCount: filteredActiveTasks.length + filteredCompleted.length,
                itemBuilder: (context, index) {
                  if (index < filteredActiveTasks.length) {
                    final task = filteredActiveTasks[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                      child: _buildActiveTaskCard(context, task, isDark, textPrimary, textSecondary, accent),
                    );
                  } else {
                    final media = filteredCompleted[index - filteredActiveTasks.length];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                      child: _buildCompletedMediaCard(context, media, isDark, textPrimary, textSecondary, accent),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterTabs(bool isDark, Color accent, Color textPrimary, Color textSecondary) {
    final tabs = ['Tất cả', 'Đang tải', 'Đã xong'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedFilterIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                tabs[index],
                style: TextStyle(
                  color: isSelected ? Colors.white : textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
              selected: isSelected,
              selectedColor: accent,
              backgroundColor: isDark ? AppColors.darkElevated : AppColors.lightElevated,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusPill),
              side: BorderSide(
                color: isSelected ? accent : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
              ),
              onSelected: (_) => setState(() => _selectedFilterIndex = index),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActiveTaskCard(
    BuildContext context,
    DownloadTask task,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color accent,
  ) {
    final isFailed = task.status == DownloadStatus.failed;
    final isCanceled = task.status == DownloadStatus.canceled;
    final isActive = task.status.isActive;

    Color statusColor = isActive ? accent : AppColors.accentRed;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: AppRadius.radiusSm,
                child: Container(
                  width: 80,
                  height: 52,
                  color: AppColors.darkHighlight,
                  child: task.mediaInfo.thumbnailUrl != null
                      ? Image.network(
                          task.mediaInfo.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.movie_rounded, color: AppColors.accentCyan),
                        )
                      : const Icon(Icons.movie_rounded, color: AppColors.accentCyan),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      HtmlUtils.unescape(task.mediaInfo.title),
                      style: AppTypography.bodyMedium.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(30),
                            borderRadius: AppRadius.radiusXs,
                          ),
                          child: Text(
                            task.status.displayNameVi.toUpperCase(),
                            style: AppTypography.caption.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${task.selectedFormat.container.toUpperCase()} • ${task.selectedFormat.displayQuality}',
                            style: AppTypography.caption.copyWith(color: textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isFailed || isCanceled) ...[
                IconButton(
                  icon: Icon(Icons.replay_rounded, color: accent),
                  tooltip: 'Tải lại',
                  onPressed: () => _manager.retryTask(task.id),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.accentRed, size: 20),
                  tooltip: 'Xóa tác vụ',
                  onPressed: () => _manager.deleteTask(task.id),
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.accentRed),
                  tooltip: 'Hủy tải',
                  onPressed: () => _manager.cancelTask(task.id),
                ),
              ],
            ],
          ),
          if (isFailed && task.errorMessage != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentRed.withAlpha(20),
                borderRadius: AppRadius.radiusXs,
              ),
              child: Text(
                'Lỗi: ${task.errorMessage}',
                style: AppTypography.caption.copyWith(color: AppColors.accentRed),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (isActive) ...[
            const SizedBox(height: AppSpacing.s12),
            ClipRRect(
              borderRadius: AppRadius.radiusPill,
              child: LinearProgressIndicator(
                value: task.progress > 0 ? task.progress : null,
                minHeight: 4,
                backgroundColor: isDark ? AppColors.darkHighlight : AppColors.lightHighlight,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${task.statusMessage} (${task.formattedProgress})',
                  style: AppTypography.caption.copyWith(color: accent),
                ),
                Text(
                  '${task.formattedSpeed} • Còn lại: ${task.formattedEta}',
                  style: AppTypography.caption.copyWith(color: textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedMediaCard(
    BuildContext context,
    MediaItemModel media,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _playMedia(context, media),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: AppRadius.radiusSm,
                  child: Container(
                    width: 80,
                    height: 52,
                    color: AppColors.darkHighlight,
                    child: media.thumbnailUrl != null
                        ? Image.network(
                            media.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              media.isVideo ? Icons.movie_rounded : Icons.music_note_rounded,
                              color: accent,
                            ),
                          )
                        : Icon(
                            media.isVideo ? Icons.movie_rounded : Icons.music_note_rounded,
                            color: accent,
                          ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(120),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  HtmlUtils.unescape(media.title),
                  style: AppTypography.bodyMedium.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withAlpha(30),
                        borderRadius: AppRadius.radiusXs,
                      ),
                      child: Text(
                        'HOÀN TẤT',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.accentGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${media.container.toUpperCase()} • ${media.formattedFileSize} • ${media.formattedDuration}',
                        style: AppTypography.caption.copyWith(color: textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.play_circle_fill_rounded, color: accent, size: 30),
            tooltip: 'Phát ngay',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onPressed: () => _playMedia(context, media),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: textSecondary, size: 20),
            tooltip: 'Xóa tệp tải',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onPressed: () => _showDeleteMediaDialog(context, media),
          ),
        ],
      ),
    );
  }

  void _playMedia(BuildContext context, MediaItemModel media) {
    ref.read(playbackControllerProvider.notifier).playLocalItem(media);
    if (media.isVideo) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const VideoPlayerScreen()),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
      );
    }
  }

  void _showDeleteMediaDialog(BuildContext context, MediaItemModel media) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tệp tải xuống'),
        content: Text('Bạn muốn xóa "${media.title}" khỏi danh sách tải xuống?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('HỦY'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _repository.deleteMedia(media.id);
            },
            child: const Text('XÓA KHỎI DANH SÁCH'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.accentRed),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _storage.deleteFile(media.localPath);
              if (media.thumbnailPath != null) {
                await _storage.deleteFile(media.thumbnailPath!);
              }
              await _repository.deleteMedia(media.id);
            },
            child: const Text('XÓA CẢ TỆP VẬT LÝ'),
          ),
        ],
      ),
    );
  }

  void _showClearCompletedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dọn dẹp danh sách'),
        content: const Text(
          'Bạn có muốn xóa toàn bộ lịch sử các mục đã tải xuống thành công khỏi danh sách không? (Tệp âm thanh và video vẫn được giữ nguyên trong máy)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final all = await _repository.getAllMedia();
              for (final item in all) {
                await _repository.deleteMedia(item.id);
              }
            },
            child: const Text('XÓA LỊCH SỬ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color textSecondary, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkHighlight : AppColors.lightHighlight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_download_outlined,
              color: isDark ? AppColors.accentCyan : AppColors.accentBlue,
              size: 48,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text('Chưa có tệp tải xuống nào', style: AppTypography.h3),
          const SizedBox(height: 6),
          Text(
            'Dán liên kết ở Trang chủ để bắt đầu phân tích và tải về.',
            style: AppTypography.bodySmall.copyWith(color: textSecondary),
          ),
        ],
      ),
    );
  }
}
