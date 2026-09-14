import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings_vi.dart';
import '../../../core/database/models/media_item_model.dart';
import '../../../core/database/models/playlist_model.dart';
import '../../../core/database/repositories/media_repository.dart';
import '../../../core/storage/storage_manager.dart';
import '../../../core/utils/html_utils.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../player/controller/global_playback_controller.dart';
import '../../player/presentation/music_player_screen.dart';
import '../controller/library_state_provider.dart';

class MusicLibraryScreen extends ConsumerStatefulWidget {
  const MusicLibraryScreen({super.key});

  @override
  ConsumerState<MusicLibraryScreen> createState() => _MusicLibraryScreenState();
}

class _MusicLibraryScreenState extends ConsumerState<MusicLibraryScreen> {
  final MediaRepository _repository = MediaRepository();
  final TextEditingController _searchController = TextEditingController();

  int _selectedFilter = 0; // 0 = Tất cả, 1 = Yêu thích, 2 = Danh sách tự tạo
  String _searchQuery = '';

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

  Future<void> _toggleFavorite(MediaItemModel item) async {
    HapticFeedback.selectionClick();
    await _repository.toggleFavorite(item.id);
  }

  Future<bool> _deleteTrack(MediaItemModel item) async {
    final confirmed = await AppDialogs.showConfirmDelete(
      context: context,
      title: 'Xóa bài hát?',
      message: 'Bạn có chắc chắn muốn xóa bản nhạc này khỏi thiết bị không?',
      itemName: HtmlUtils.unescape(item.title),
      confirmText: 'Xóa bài hát',
      cancelText: 'Giữ lại',
    );

    if (confirmed == true) {
      await StorageManager().deleteFile(item.localPath);
      if (item.thumbnailPath != null) {
        await StorageManager().deleteFile(item.thumbnailPath!);
      }
      await _repository.deleteMedia(item.id);
      return true;
    }
    return false;
  }

  Future<void> _showCreatePlaylistDialog() async {
    final name = await AppDialogs.showTextInputDialog(
      context: context,
      title: 'Tạo danh sách phát mới',
      hintText: 'Nhập tên danh sách bài hát...',
      confirmText: 'Tạo danh sách',
      cancelText: 'Hủy bỏ',
      icon: Icons.playlist_add_rounded,
    );

    if (name != null && name.trim().isNotEmpty) {
      await _repository.createPlaylist(name.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final accent = isDark ? AppColors.accentCyan : AppColors.accentBlue;

    final audioAsync = ref.watch(audioLibraryProvider);
    final playlistsAsync = ref.watch(playlistListProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          AppStringsVi.musicHub,
          style: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_rounded, size: 26),
            tooltip: AppStringsVi.createPlaylist,
            onPressed: _showCreatePlaylistDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  hintText: AppStringsVi.searchPlaceholder,
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

          // Bộ lọc danh mục
          _buildFilterTabs(isDark, accent, textPrimary, textSecondary),

          // Danh sách nội dung
          Expanded(
            child: _selectedFilter == 2
                ? _buildPlaylistsView(playlistsAsync, isDark, textPrimary, textSecondary)
                : _buildTracksView(audioAsync, isDark, textPrimary, textSecondary, accent),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(bool isDark, Color accent, Color textPrimary, Color textSecondary) {
    final tabs = [
      AppStringsVi.allTracks,
      AppStringsVi.favorites,
      AppStringsVi.playlists,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSel = _selectedFilter == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedFilter = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSel ? accent : (isDark ? AppColors.darkSurface : AppColors.lightElevated),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSel ? accent : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                  ),
                ),
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    color: isSel ? Colors.black : textSecondary,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
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

  Widget _buildTracksView(
    AsyncValue<List<MediaItemModel>> audioAsync,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color accent,
  ) {
    return audioAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (items) {
        var filtered = items;
        if (_selectedFilter == 1) {
          filtered = filtered.where((item) => item.isFavorite).toList();
        }
        if (_searchQuery.isNotEmpty) {
          filtered = filtered.where((item) {
            final t = item.title.toLowerCase();
            final a = item.artist.toLowerCase();
            return t.contains(_searchQuery) || a.contains(_searchQuery);
          }).toList();
        }

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off_rounded, size: 48, color: textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    AppStringsVi.emptyMusic,
                    style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppStringsVi.emptyMusicDesc,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          );
        }

        final currentMediaId = ref.watch(playbackControllerProvider).mediaId;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          children: [
            // Thanh hành động Phát tất cả & Trộn bài
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentCyan.withAlpha(isDark ? 80 : 40),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 24),
                        label: Text(
                          _selectedFilter == 1
                              ? 'Phát tất cả bài yêu thích (${filtered.length})'
                              : 'Phát tất cả (${filtered.length} bài)',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          final nav = Navigator.of(context);
                          final controller = ref.read(playbackControllerProvider.notifier);
                          await controller.playAll(filtered, shuffle: false);
                          if (!mounted) return;
                          nav.push(
                            MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightElevated,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.all(10),
                    ),
                    icon: const Icon(Icons.shuffle_rounded, color: AppColors.accentCyan, size: 22),
                    tooltip: 'Trộn bài ngẫu nhiên',
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      final nav = Navigator.of(context);
                      final controller = ref.read(playbackControllerProvider.notifier);
                      await controller.playAll(filtered, shuffle: true);
                      if (!mounted) return;
                      nav.push(
                        MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Danh sách từng bài hát
            ...filtered.map((item) {
              final isPlaying = currentMediaId == item.id;
              final title = HtmlUtils.unescape(item.title);
              final artist = HtmlUtils.unescape(item.artist);

              return Dismissible(
                key: ValueKey('track_${item.id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) async {
                  return await _deleteTrack(item);
                },
                background: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF3366), Color(0xFFFF416C)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_forever_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 6),
                      Text(
                        'Xóa bài hát',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isPlaying
                          ? accent
                          : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                      width: isPlaying ? 1.4 : 1.0,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: _buildItemArtwork(item),
                      ),
                    ),
                    title: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isPlaying ? accent : textPrimary,
                        fontSize: 13,
                        fontWeight: isPlaying ? FontWeight.w800 : FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '$artist • ${AppStringsVi.formatBytes(item.fileSize)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textSecondary, fontSize: 11),
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        item.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: item.isFavorite ? AppColors.accentRed : textSecondary.withAlpha(120),
                        size: 22,
                      ),
                      tooltip: item.isFavorite ? 'Bỏ thích' : 'Yêu thích',
                      onPressed: () => _toggleFavorite(item),
                    ),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(playbackControllerProvider.notifier).playLocalItem(item);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
                      );
                    },
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildPlaylistsView(
    AsyncValue<List<PlaylistModel>> playlistsAsync,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return playlistsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (playlists) {
        if (playlists.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.queue_music_rounded, size: 48, color: textSecondary),
                const SizedBox(height: 12),
                Text(
                  'Chưa có danh sách phát nào',
                  style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(AppStringsVi.createPlaylist),
                  onPressed: _showCreatePlaylistDialog,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final p = playlists[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.queue_music_rounded, color: Colors.black, size: 24),
                  ),
                ),
                title: Text(
                  p.name,
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
                ),
                subtitle: Text(
                  '${p.itemCount} bản nhạc',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nút phát tất cả bài trong Playlist
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.accentCyan, size: 34),
                      tooltip: 'Phát toàn bộ danh sách này',
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        final nav = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        final tracks = await _repository.getPlaylistItems(p.id);
                        if (tracks.isEmpty) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Danh sách này chưa có bản nhạc nào! Hãy thêm nhạc vào danh sách trước.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        if (!mounted) return;
                        final controller = ref.read(playbackControllerProvider.notifier);
                        await controller.playAll(tracks, shuffle: false);
                        if (!mounted) return;
                        nav.push(
                          MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: textSecondary, size: 20),
                      tooltip: 'Xóa danh sách',
                      onPressed: () async {
                        final confirmed = await AppDialogs.showConfirmDelete(
                          context: context,
                          title: 'Xóa danh sách phát?',
                          message: 'Các bài hát trong kho nhạc của bạn sẽ không bị ảnh hưởng.',
                          itemName: p.name,
                          confirmText: 'Xóa danh sách',
                          cancelText: 'Giữ lại',
                        );
                        if (confirmed) {
                          await _repository.deletePlaylist(p.id);
                        }
                      },
                    ),
                  ],
                ),
                onTap: () async {
                  HapticFeedback.selectionClick();
                  final nav = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final tracks = await _repository.getPlaylistItems(p.id);
                  if (tracks.isEmpty) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Danh sách này chưa có bản nhạc nào!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  if (!mounted) return;
                  final controller = ref.read(playbackControllerProvider.notifier);
                  await controller.playAll(tracks, shuffle: false);
                  if (!mounted) return;
                  nav.push(
                    MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildItemArtwork(MediaItemModel item) {
    if (item.thumbnailPath != null && File(item.thumbnailPath!).existsSync()) {
      return Image.file(File(item.thumbnailPath!), fit: BoxFit.cover);
    }
    return Container(
      color: AppColors.accentCyan.withAlpha(40),
      child: const Icon(Icons.music_note_rounded, color: AppColors.accentCyan),
    );
  }
}
