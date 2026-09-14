import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings_vi.dart';
import '../../../core/database/models/media_item_model.dart';
import '../../../core/database/repositories/media_repository.dart';
import '../../../core/storage/storage_manager.dart';
import '../../../core/utils/html_utils.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../player/controller/global_playback_controller.dart';
import '../../player/presentation/video_player_screen.dart';
import '../controller/library_state_provider.dart';

enum VideoFilter { all, unfinished, recent }

class VideoLibraryScreen extends ConsumerStatefulWidget {
  const VideoLibraryScreen({super.key});

  @override
  ConsumerState<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends ConsumerState<VideoLibraryScreen> {
  final MediaRepository _repository = MediaRepository();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  VideoFilter _currentFilter = VideoFilter.all;
  bool _isCompactView = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteVideo(MediaItemModel item) async {
    final confirmed = await AppDialogs.showConfirmDelete(
      context: context,
      title: 'Xóa video khỏi máy?',
      message: 'Video này sẽ bị xóa hoàn toàn khỏi bộ nhớ thiết bị của bạn.',
      itemName: HtmlUtils.unescape(item.title),
      confirmText: 'Xóa vĩnh viễn',
      cancelText: 'Giữ lại',
    );

    if (confirmed == true) {
      await StorageManager().deleteFile(item.localPath);
      if (item.thumbnailPath != null) {
        await StorageManager().deleteFile(item.thumbnailPath!);
      }
      await _repository.deleteMedia(item.id);
      ref.invalidate(videoLibraryProvider);
    }
  }

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return 'Hôm nay';
    } else if (diff.inDays == 1) {
      return 'Hôm qua';
    } else if (diff.inDays < 30) {
      return '${diff.inDays} ngày trước';
    }
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  void _showVideoOptionsSheet(MediaItemModel item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = HtmlUtils.unescape(item.title);
    final artist = HtmlUtils.unescape(item.artist.isNotEmpty ? item.artist : AppStringsVi.appName);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141923) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(15),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Header video
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 60,
                      height: 38,
                      child: _buildVideoThumb(item),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$artist • ${_formatDuration(item.durationMs)}',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Xem video toàn màn hình
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_circle_fill_rounded, color: AppColors.accentCyan),
                title: Text(
                  'Xem toàn màn hình',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _playVideo(item);
                },
              ),

              // Chỉ nghe âm thanh (Chế độ phát nền)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.headphones_rounded, color: AppColors.accentBlue),
                title: Text(
                  'Chỉ nghe âm thanh (Tắt màn hình vẫn nghe)',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Tiết kiệm 80% pin, phát ngầm liên tục',
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 11.5),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final controller = ref.read(playbackControllerProvider.notifier);
                  await controller.playLocalItem(item);
                  await controller.toggleAudioOnly();
                  _showToast('Đang phát ở chế độ chỉ nghe âm thanh');
                },
              ),

              // Xóa video
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.accentRed),
                title: const Text(
                  'Xóa video khỏi thiết bị',
                  style: TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteVideo(item);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _playVideo(MediaItemModel item, [List<MediaItemModel>? queue]) async {
    HapticFeedback.selectionClick();
    final controller = ref.read(playbackControllerProvider.notifier);
    await controller.playLocalItem(item, queue: queue);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VideoPlayerScreen()),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final videoAsync = ref.watch(videoLibraryProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              AppStringsVi.videoHub,
              style: TextStyle(
                color: textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF0055), Color(0xFFFF5E3A)],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'PREMIUM',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Nút chuyển đổi giao diện Thẻ lớn / Danh sách gọn
          IconButton(
            icon: Icon(
              _isCompactView ? Icons.view_agenda_outlined : Icons.view_list_rounded,
              color: textPrimary,
            ),
            tooltip: _isCompactView ? 'Xem dạng thẻ lớn' : 'Xem dạng danh sách gọn',
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _isCompactView = !_isCompactView);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm video trong kho...',
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          // Thanh chip lọc nhanh chuẩn YouTube
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('Tất cả', VideoFilter.all, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Chưa xem hết', VideoFilter.unfinished, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Gần đây', VideoFilter.recent, isDark),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Nội dung danh sách video
          Expanded(
            child: videoAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accentCyan),
              ),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
              data: (videos) {
                var filtered = videos;

                // Lọc theo tìm kiếm
                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((v) {
                    return v.title.toLowerCase().contains(_searchQuery) ||
                        v.artist.toLowerCase().contains(_searchQuery);
                  }).toList();
                }

                // Lọc theo chip
                switch (_currentFilter) {
                  case VideoFilter.unfinished:
                    filtered = filtered.where((v) => !v.isCompleted && v.lastPositionMs > 0).toList();
                    break;
                  case VideoFilter.recent:
                    filtered = List.from(filtered)
                      ..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
                    break;
                  case VideoFilter.all:
                    break;
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_library_outlined, size: 52, color: textSecondary.withAlpha(120)),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty ? 'Không tìm thấy video phù hợp' : AppStringsVi.emptyVideo,
                            style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Thử tìm với từ khóa khác'
                                : AppStringsVi.emptyVideoDesc,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textSecondary, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return _isCompactView
                    ? _buildCompactListView(filtered, isDark, textPrimary, textSecondary)
                    : _buildLargeCardsView(filtered, isDark, textPrimary, textSecondary);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VideoFilter filter, bool isDark) {
    final isSelected = _currentFilter == filter;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentFilter = filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : Colors.black87)
              : (isDark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(8)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (isDark ? Colors.black87 : Colors.white)
                : (isDark ? Colors.white70 : Colors.black87),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Dạng thẻ lớn chuẩn YouTube Feed Card 16:9
  Widget _buildLargeCardsView(
    List<MediaItemModel> videos,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final item = videos[index];
        final title = HtmlUtils.unescape(item.title);
        final artist = HtmlUtils.unescape(item.artist.isNotEmpty ? item.artist : 'BDSNAP Video');
        final progress = item.durationMs > 0 ? (item.lastPositionMs / item.durationMs).clamp(0.0, 1.0) : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: GestureDetector(
            onTap: () => _playVideo(item, videos),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131722) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.white.withAlpha(22) : Colors.black.withAlpha(10),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 60 : 12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Khung hình 16:9 sắc nét
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: _buildVideoThumb(item),
                        ),
                      ),
                      // Nhãn thời lượng nền đen bo góc góc phải dưới
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(210),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _formatDuration(item.durationMs),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      // Biểu tượng Play mờ giữa hình
                      const Positioned.fill(
                        child: Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white70,
                            size: 48,
                          ),
                        ),
                      ),
                      // Thanh tiến trình đỏ YouTube khi đang xem dở
                      if (progress > 0 && !item.isCompleted)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 3.5,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0033)),
                          ),
                        ),
                    ],
                  ),

                  // Khối thông tin chuẩn YouTube
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar kênh tròn BDSNAP
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF00F2FE), Color(0xFF4FACFE)],
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.black87,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Tiêu đề & tác giả
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
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$artist • ${AppStringsVi.formatBytes(item.fileSize)} • ${_formatDate(item.downloadedAt)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Nút 3 chấm mở tùy chọn
                        IconButton(
                          icon: Icon(Icons.more_vert_rounded, color: textSecondary, size: 20),
                          onPressed: () => _showVideoOptionsSheet(item),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Dạng danh sách thu gọn (Compact List)
  Widget _buildCompactListView(
    List<MediaItemModel> videos,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final item = videos[index];
        final title = HtmlUtils.unescape(item.title);
        final artist = HtmlUtils.unescape(item.artist.isNotEmpty ? item.artist : 'BDSNAP Video');

        final progress = item.durationMs > 0 ? (item.lastPositionMs / item.durationMs).clamp(0.0, 1.0) : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => _playVideo(item, videos),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131722) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 40 : 8),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Thumbnail nhỏ gọn 16:9
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        SizedBox(
                          width: 110,
                          height: 64,
                          child: _buildVideoThumb(item),
                        ),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatDuration(item.durationMs),
                              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        if (progress > 0 && !item.isCompleted)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 2.5,
                              backgroundColor: Colors.transparent,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0033)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Thông tin
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
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$artist • ${AppStringsVi.formatBytes(item.fileSize)}',
                          style: TextStyle(color: textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  // Menu 3 chấm
                  IconButton(
                    icon: Icon(Icons.more_vert_rounded, color: textSecondary, size: 20),
                    onPressed: () => _showVideoOptionsSheet(item),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoThumb(MediaItemModel item) {
    if (item.thumbnailPath != null && File(item.thumbnailPath!).existsSync()) {
      return Image.file(File(item.thumbnailPath!), fit: BoxFit.cover);
    }
    if (item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty) {
      return Image.network(
        item.thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stack) => _defaultVideoThumb(),
      );
    }
    return _defaultVideoThumb();
  }

  Widget _defaultVideoThumb() {
    return Container(
      color: const Color(0xFF1E293B),
      child: const Center(
        child: Icon(Icons.movie_creation_rounded, color: AppColors.accentCyan, size: 32),
      ),
    );
  }
}
