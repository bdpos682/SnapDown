import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings_vi.dart';
import '../../../core/database/repositories/media_repository.dart';
import '../../../core/utils/html_utils.dart';
import '../../../core/widgets/app_dialogs.dart';
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

  int _selectedFilterIndex = 0; // 0: Tất cả, 1: Đang tải, 2: Đã tải xong

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final accent = isDark ? AppColors.accentCyan : AppColors.accentBlue;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          AppStringsVi.downloadManagement,
          style: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_rounded),
            tooltip: AppStringsVi.clearCompleted,
            onPressed: () => _showClearCompletedDialog(context),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: _buildFilterPills(isDark, accent, textPrimary, textSecondary),
        ),
      ),
      body: StreamBuilder<List<DownloadTask>>(
        stream: _manager.tasksStream,
        initialData: _manager.tasks,
        builder: (context, snapshot) {
          final allTasks = snapshot.data ?? [];

          final filteredTasks = allTasks.where((task) {
            if (_selectedFilterIndex == 1) {
              return task.status == DownloadStatus.downloading ||
                  task.status == DownloadStatus.queued;
            } else if (_selectedFilterIndex == 2) {
              return task.status == DownloadStatus.completed;
            }
            return true;
          }).toList();

          if (filteredTasks.isEmpty) {
            return _buildEmptyState(textPrimary, textSecondary);
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            itemCount: filteredTasks.length,
            itemBuilder: (context, index) {
              final task = filteredTasks[index];
              return _buildTaskCard(task, isDark, textPrimary, textSecondary, accent);
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterPills(
    bool isDark,
    Color accent,
    Color textPrimary,
    Color textSecondary,
  ) {
    final filters = [
      AppStringsVi.tabAll,
      AppStringsVi.tabDownloading,
      AppStringsVi.tabCompleted,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: List.generate(filters.length, (index) {
          final isSelected = _selectedFilterIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedFilterIndex = index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent
                      : (isDark ? AppColors.darkSurface : AppColors.lightElevated),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? accent
                        : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                  ),
                ),
                child: Text(
                  filters[index],
                  style: TextStyle(
                    color: isSelected ? Colors.black : textSecondary,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTaskCard(
    DownloadTask task,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color accent,
  ) {
    final info = task.mediaInfo;
    final isCompleted = task.status == DownloadStatus.completed;
    final isFailed = task.status == DownloadStatus.failed;
    final isDownloading = task.status == DownloadStatus.downloading;
    final isQueued = task.status == DownloadStatus.queued;

    final progress = task.progress.clamp(0.0, 1.0);
    final title = HtmlUtils.unescape(info.title);
    final author = HtmlUtils.unescape(info.author);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ảnh bìa
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: _buildThumbnail(task),
                ),
              ),
              const SizedBox(width: 12),

              // Thông tin tiêu đề & trạng thái
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textSecondary, fontSize: 11.5),
                    ),
                  ],
                ),
              ),

              // Nút hành động nhanh
              if (isCompleted)
                IconButton(
                  icon: const Icon(Icons.play_circle_fill_rounded, size: 36, color: AppColors.accentCyan),
                  tooltip: 'Phát ngay',
                  onPressed: () => _playCompletedTask(task),
                )
              else if (isFailed)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 28, color: AppColors.accentRed),
                  tooltip: AppStringsVi.retryTask,
                  onPressed: () {
                    task.status = DownloadStatus.queued;
                    task.errorMessage = null;
                    _manager.enqueue(
                      mediaInfo: task.mediaInfo,
                      selectedFormat: task.selectedFormat,
                      convertToMp3: task.convertToMp3,
                      mp3Bitrate: task.mp3Bitrate,
                    );
                  },
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Thanh tiến trình nếu đang tải
          if (isDownloading || isQueued) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: isQueued ? null : progress,
                minHeight: 5,
                backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  task.statusMessage.isNotEmpty
                      ? task.statusMessage
                      : (isQueued ? AppStringsVi.statusQueued : AppStringsVi.statusDownloading),
                  style: TextStyle(
                    color: isDark ? AppColors.accentCyan : AppColors.accentBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!isQueued && task.speedBytesPerSec > 0)
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}% • ${AppStringsVi.formatSpeed(task.speedBytesPerSec)}',
                    style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ] else if (isCompleted) ...[
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.accentGreen),
                const SizedBox(width: 6),
                Text(
                  AppStringsVi.statusCompleted,
                  style: const TextStyle(color: AppColors.accentGreen, fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (task.finalLocalPath != null)
                  Text(
                    _getFileSize(task.finalLocalPath!),
                    style: TextStyle(color: textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ] else if (isFailed) ...[
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.accentRed),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    task.errorMessage ?? AppStringsVi.statusFailed,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.accentRed, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThumbnail(DownloadTask task) {
    if (task.mediaInfo.thumbnailUrl != null) {
      return Image.network(
        task.mediaInfo.thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stack) => _defaultThumb(),
      );
    }
    return _defaultThumb();
  }

  Widget _defaultThumb() {
    return Container(
      color: AppColors.accentCyan.withAlpha(40),
      child: const Icon(Icons.download_rounded, color: AppColors.accentCyan),
    );
  }

  String _getFileSize(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) {
        return AppStringsVi.formatBytes(f.lengthSync());
      }
    } catch (_) {}
    return '';
  }

  Future<void> _playCompletedTask(DownloadTask task) async {
    final path = task.finalLocalPath;
    if (path == null) return;

    final mediaItem = await _repository.getMediaById(task.id);
    if (mediaItem != null && mounted) {
      final controller = ref.read(playbackControllerProvider.notifier);
      await controller.playLocalItem(mediaItem);

      if (!mounted) return;
      if (mediaItem.isVideo) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const VideoPlayerScreen()),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
        );
      }
    }
  }

  Widget _buildEmptyState(Color textPrimary, Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.accentCyan.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_download_outlined, size: 36, color: AppColors.accentCyan),
            ),
            const SizedBox(height: 16),
            Text(
              AppStringsVi.noDownloads,
              style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              AppStringsVi.noDownloadsDesc,
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showClearCompletedDialog(BuildContext context) async {
    final confirmed = await AppDialogs.showConfirmDelete(
      context: context,
      title: AppStringsVi.clearConfirmTitle,
      message: AppStringsVi.clearConfirmContent,
      confirmText: 'Dọn sạch',
      cancelText: 'Hủy bỏ',
    );

    if (confirmed) {
      _manager.clearCompletedTasks();
    }
  }
}
