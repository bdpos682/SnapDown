import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/models/media_item_model.dart';
import '../../../core/database/models/playlist_model.dart';
import '../../../core/database/repositories/media_repository.dart';
import '../../../core/utils/html_utils.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../player/controller/global_playback_controller.dart';
import '../../player/presentation/music_player_screen.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final PlaylistModel playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  final MediaRepository _repository = MediaRepository();
  List<MediaItemModel> _tracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final items = await _repository.getPlaylistItems(widget.playlist.id);
    if (mounted) {
      setState(() {
        _tracks = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeTrack(MediaItemModel item) async {
    HapticFeedback.mediumImpact();
    await _repository.removeMediaFromPlaylist(widget.playlist.id, item.id);
    await _loadTracks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa "${HtmlUtils.unescape(item.title)}" khỏi danh sách'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showAddTracksPicker() async {
    HapticFeedback.selectionClick();
    final allAudio = await _repository.getAudioItems();
    final existingIds = _tracks.map((t) => t.id).toSet();
    final available = allAudio.where((t) => !existingIds.contains(t.id)).toList();

    if (!mounted) return;

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tất cả bài hát trong kho đã có trong danh sách này rồi!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selectedIds = <String>{};

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
            final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
            final accent = isDark ? AppColors.accentCyan : AppColors.accentBlue;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141824) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(12),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withAlpha(50) : Colors.black.withAlpha(30),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Thêm bài hát vào danh sách',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: textSecondary, size: 22),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),

                    // Danh sách bài có thể thêm
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: available.length,
                        itemBuilder: (context, i) {
                          final item = available[i];
                          final isSelected = selectedIds.contains(item.id);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accent.withAlpha(isDark ? 25 : 15)
                                  : (isDark ? AppColors.darkCard : AppColors.lightCard),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? accent
                                    : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: item.thumbnailPath != null &&
                                          File(item.thumbnailPath!).existsSync()
                                      ? Image.file(File(item.thumbnailPath!), fit: BoxFit.cover)
                                      : Container(
                                          color: accent.withAlpha(40),
                                          child: Icon(Icons.music_note_rounded, color: accent),
                                        ),
                                ),
                              ),
                              title: Text(
                                HtmlUtils.unescape(item.title),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                HtmlUtils.unescape(item.artist),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: textSecondary, fontSize: 11),
                              ),
                              trailing: Checkbox(
                                value: isSelected,
                                activeColor: accent,
                                checkColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                onChanged: (val) {
                                  setModalState(() {
                                    if (val == true) {
                                      selectedIds.add(item.id);
                                    } else {
                                      selectedIds.remove(item.id);
                                    }
                                  });
                                },
                              ),
                              onTap: () {
                                setModalState(() {
                                  if (selectedIds.contains(item.id)) {
                                    selectedIds.remove(item.id);
                                  } else {
                                    selectedIds.add(item.id);
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),

                    // Nút xác nhận thêm
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withAlpha(80),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: selectedIds.isEmpty
                                ? null
                                : () async {
                                    HapticFeedback.mediumImpact();
                                    for (final id in selectedIds) {
                                      await _repository.addMediaToPlaylist(widget.playlist.id, id);
                                    }
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    await _loadTracks();
                                  },
                            child: Text(
                              'Thêm ${selectedIds.length} bài hát đã chọn',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
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
          widget.playlist.name,
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 28),
            tooltip: 'Thêm bài hát',
            onPressed: _showAddTracksPicker,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 22),
            tooltip: 'Xóa danh sách',
            onPressed: () async {
              final confirmed = await AppDialogs.showConfirmDelete(
                context: context,
                title: 'Xóa danh sách phát?',
                message: 'Các bài hát trong kho nhạc của bạn sẽ không bị ảnh hưởng.',
                itemName: widget.playlist.name,
                confirmText: 'Xóa danh sách',
                cancelText: 'Giữ lại',
              );
              if (confirmed && context.mounted) {
                await _repository.deletePlaylist(widget.playlist.id);
                if (!context.mounted) return;
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentCyan))
          : CustomScrollView(
              slivers: [
                // Header Banner
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent.withAlpha(isDark ? 40 : 25),
                            AppColors.accentBlue.withAlpha(isDark ? 30 : 15),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accent.withAlpha(50),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withAlpha(80),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(Icons.queue_music_rounded, color: Colors.black, size: 34),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.playlist.name,
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_tracks.length} bản nhạc trong danh sách',
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Hàng nút điều khiển Phát tất cả / Trộn bài / Thêm bài
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 42,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22),
                                    label: const Text(
                                      'Phát tất cả',
                                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13),
                                    ),
                                    onPressed: _tracks.isEmpty
                                        ? null
                                        : () async {
                                            HapticFeedback.mediumImpact();
                                            final controller = ref.read(playbackControllerProvider.notifier);
                                            await controller.playAll(_tracks, shuffle: false);
                                          },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: isDark ? AppColors.darkCard : AppColors.lightElevated,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.shuffle_rounded, color: AppColors.accentCyan, size: 20),
                                tooltip: 'Trộn bài',
                                onPressed: _tracks.isEmpty
                                    ? null
                                    : () async {
                                        HapticFeedback.mediumImpact();
                                        final controller = ref.read(playbackControllerProvider.notifier);
                                        await controller.playAll(_tracks, shuffle: true);
                                      },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: isDark ? AppColors.darkCard : AppColors.lightElevated,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.playlist_add_rounded, color: AppColors.accentCyan, size: 22),
                                tooltip: 'Thêm bài hát',
                                onPressed: _showAddTracksPicker,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Danh sách bài hát trong Playlist
                if (_tracks.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.music_off_rounded, size: 54, color: textSecondary),
                            const SizedBox(height: 12),
                            Text(
                              'Danh sách đang trống',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Chưa có bài hát nào trong danh sách này.\nHãy thêm bài hát bạn yêu thích vào nhé!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textSecondary, fontSize: 12.5),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Thêm bài hát ngay', style: TextStyle(fontWeight: FontWeight.w800)),
                              onPressed: _showAddTracksPicker,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = _tracks[index];
                          final title = HtmlUtils.unescape(item.title);
                          final artist = HtmlUtils.unescape(item.artist);

                          return Dismissible(
                            key: ValueKey('pl_item_${item.id}_$index'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3366),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.remove_circle_outline_rounded, color: Colors.white, size: 22),
                                  SizedBox(width: 6),
                                  Text(
                                    'Xóa khỏi danh sách',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            onDismissed: (_) => _removeTrack(item),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: item.thumbnailPath != null &&
                                            File(item.thumbnailPath!).existsSync()
                                        ? Image.file(File(item.thumbnailPath!), fit: BoxFit.cover)
                                        : Container(
                                            color: accent.withAlpha(40),
                                            child: Icon(Icons.music_note_rounded, color: accent),
                                          ),
                                  ),
                                ),
                                title: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                  ),
                                ),
                                subtitle: Text(
                                  artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: textSecondary, fontSize: 11),
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.remove_circle_outline_rounded, color: textSecondary, size: 20),
                                  tooltip: 'Xóa khỏi danh sách',
                                  onPressed: () => _removeTrack(item),
                                ),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  ref.read(playbackControllerProvider.notifier).playLocalItem(
                                        item,
                                        queue: _tracks,
                                      );
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                        childCount: _tracks.length,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
