import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/database/models/media_item_model.dart';
import '../../../core/database/models/playlist_model.dart';
import '../../../core/database/repositories/media_repository.dart';
import '../../../core/storage/storage_manager.dart';
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

  int _selectedFilter = 0; // 0 = Tất cả, 1 = Danh sách phát, 2 = Yêu thích

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite(MediaItemModel item) async {
    await _repository.toggleFavorite(item.id);
  }

  Future<void> _deleteTrack(MediaItemModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bài hát?'),
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

  void _showCreatePlaylistDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo Playlist Mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Tên danh sách phát *',
                hintText: 'Ví dụ: Nhạc Chill, Top Hits...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Mô tả (tùy chọn)',
                hintText: 'Ghi chú cho playlist này...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await _repository.createPlaylist(name, description: descController.text.trim());
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistSheet(MediaItemModel track) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, child) {
            final playlistsAsync = ref.watch(playlistListProvider);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Thêm vào Danh sách phát', style: AppTypography.h3),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline_rounded, color: AppColors.accentCyan),
                      title: const Text('Tạo Playlist mới', style: TextStyle(fontWeight: FontWeight.bold)),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _showCreatePlaylistDialog();
                      },
                    ),
                    const Divider(),
                    playlistsAsync.when(
                      data: (playlists) {
                        if (playlists.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Chưa có playlist nào. Hãy tạo mới ở trên!'),
                          );
                        }
                        return ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 250),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: playlists.length,
                            itemBuilder: (context, index) {
                              final p = playlists[index];
                              return ListTile(
                                leading: const Icon(Icons.queue_music_rounded, color: AppColors.accentAmber),
                                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('${p.itemCount} bài hát'),
                                onTap: () async {
                                  await _repository.addMediaToPlaylist(p.id, track.id);
                                  if (ctx.mounted) {
                                    Navigator.of(ctx).pop();
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Đã thêm vào "${p.name}"')),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Text('Lỗi: $err'),
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

  void _openPlaylistDetails(PlaylistModel playlist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<List<MediaItemModel>>(
              future: _repository.getPlaylistItems(playlist.id),
              builder: (context, snapshot) {
                final items = snapshot.data ?? [];
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withAlpha(100),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(playlist.name, style: AppTypography.h2),
                                Text('${items.length} bài hát', style: AppTypography.caption),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (items.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.accentCyan : AppColors.accentBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                ),
                                onPressed: () {
                                  ref.read(playbackControllerProvider.notifier).playAll(items, shuffle: false);
                                  Navigator.of(ctx).pop();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
                                  );
                                },
                                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                label: const Text('Phát tất cả', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).brightness == Brightness.dark
                                      ? AppColors.darkElevated
                                      : AppColors.lightElevated,
                                  foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                ),
                                onPressed: () {
                                  ref.read(playbackControllerProvider.notifier).playAll(items, shuffle: true);
                                  Navigator.of(ctx).pop();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
                                  );
                                },
                                icon: const Icon(Icons.shuffle_rounded, size: 18),
                                label: const Text('Xáo trộn', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Divider(),
                      Expanded(
                        child: items.isEmpty
                          ? const Center(child: Text('Danh sách phát này chưa có bài hát nào.'))
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return ListTile(
                                  leading: const Icon(Icons.music_note_rounded, color: AppColors.accentCyan),
                                  title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(item.artist, maxLines: 1),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.accentRed),
                                    onPressed: () async {
                                      await _repository.removeMediaFromPlaylist(playlist.id, item.id);
                                      if (ctx.mounted) {
                                        Navigator.of(ctx).pop();
                                      }
                                    },
                                  ),
                                  onTap: () {
                                    ref.read(playbackControllerProvider.notifier).playLocalItem(item, queue: items, resumePosition: false);
                                    Navigator.of(ctx).pop();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
                                    );
                                  },
                                );
                              },
                            ),
                      ),
                    ],
                  ),
                );
              },
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
    final primaryAccent = isDark ? AppColors.accentCyan : AppColors.accentBlue;

    final audioAsync = ref.watch(audioLibraryProvider);
    final playlistsAsync = ref.watch(playlistListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Thư viện Nhạc', style: AppTypography.h2.copyWith(color: textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          if (_selectedFilter == 1)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Tạo Playlist',
              onPressed: _showCreatePlaylistDialog,
            ),
        ],
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
                hintText: 'Tìm kiếm bài hát, nghệ sĩ...',
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

          // Bộ lọc (Tất cả, Danh sách phát, Yêu thích)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s4),
            child: Row(
              children: [
                _buildFilterChip('Tất cả', 0, primaryAccent),
                const SizedBox(width: AppSpacing.s8),
                _buildFilterChip('Danh sách phát', 1, primaryAccent),
                const SizedBox(width: AppSpacing.s8),
                _buildFilterChip('Yêu thích', 2, primaryAccent),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s8),

          // Nội dung hiển thị
          Expanded(
            child: _selectedFilter == 1
                ? _buildPlaylistsView(playlistsAsync, textPrimary, textSecondary, primaryAccent)
                : _buildTracksView(audioAsync, textPrimary, textSecondary, primaryAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsView(
    AsyncValue<List<PlaylistModel>> playlistsAsync,
    Color textPrimary,
    Color textSecondary,
    Color primaryAccent,
  ) {
    return playlistsAsync.when(
      data: (playlists) {
        if (playlists.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.playlist_add_rounded, size: 64, color: AppColors.accentCyan),
                const SizedBox(height: 16),
                Text('Chưa có danh sách phát nào', style: AppTypography.h3),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _showCreatePlaylistDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Tạo Playlist Đầu Tiên'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 120),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final p = playlists[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurface
                    : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkBorderSubtle
                      : AppColors.lightBorder,
                ),
              ),
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.queue_music_rounded, color: AppColors.accentCyan),
                ),
                title: Text(p.name, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                subtitle: Text('${p.itemCount} bài hát ${p.description != null && p.description!.isNotEmpty ? "• ${p.description}" : ""}', style: AppTypography.caption),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.accentRed, size: 20),
                  onPressed: () async {
                    await _repository.deletePlaylist(p.id);
                  },
                ),
                onTap: () => _openPlaylistDetails(p),
              ),
            );
          },
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: primaryAccent)),
      error: (err, _) => Center(child: Text('Lỗi tải playlist: $err')),
    );
  }

  Widget _buildTracksView(
    AsyncValue<List<MediaItemModel>> audioAsync,
    Color textPrimary,
    Color textSecondary,
    Color primaryAccent,
  ) {
    return audioAsync.when(
      data: (allTracks) {
        var tracks = allTracks;

        // Lọc yêu thích nếu chọn tab 2
        if (_selectedFilter == 2) {
          tracks = tracks.where((t) => t.isFavorite).toList();
        }

        // Lọc theo từ khóa tìm kiếm
        final query = _searchController.text.trim().toLowerCase();
        if (query.isNotEmpty) {
          tracks = tracks.where((t) =>
            t.title.toLowerCase().contains(query) ||
            t.artist.toLowerCase().contains(query),
          ).toList();
        }

        if (tracks.isEmpty) {
          return _buildEmptyState(textSecondary);
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Column(
          children: [
            // Apple Music Header: Phát Tất Cả & Xáo Trộn
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () {
                        ref.read(playbackControllerProvider.notifier).playAll(tracks, shuffle: false);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
                        );
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 24),
                      label: Text('Phát tất cả (${tracks.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.darkElevated : AppColors.lightElevated,
                        foregroundColor: textPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(
                          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () {
                        ref.read(playbackControllerProvider.notifier).playAll(tracks, shuffle: true);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
                        );
                      },
                      icon: Icon(Icons.shuffle_rounded, color: primaryAccent, size: 20),
                      label: const Text('Xáo trộn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 120),
                itemCount: tracks.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  return _buildTrackTile(track, tracks, textPrimary, textSecondary, primaryAccent);
                },
              ),
            ),
          ],
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: primaryAccent)),
      error: (err, _) => Center(child: Text('Lỗi tải nhạc: $err')),
    );
  }

  Widget _buildFilterChip(String label, int index, Color primaryAccent) {
    final isSelected = _selectedFilter == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = index),
      selectedColor: primaryAccent,
      labelStyle: AppTypography.caption.copyWith(
        color: isSelected ? Colors.white : AppColors.darkTextSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildTrackTile(
    MediaItemModel track,
    List<MediaItemModel> queue,
    Color textPrimary,
    Color textSecondary,
    Color primaryAccent,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: ClipRRect(
        borderRadius: AppRadius.radiusSm,
        child: Container(
          width: 52,
          height: 52,
          color: AppColors.darkHighlight,
          child: track.thumbnailPath != null && File(track.thumbnailPath!).existsSync()
              ? Image.file(File(track.thumbnailPath!), fit: BoxFit.cover)
              : (track.thumbnailUrl != null
                  ? Image.network(track.thumbnailUrl!, fit: BoxFit.cover)
                  : Icon(Icons.music_note_rounded, color: primaryAccent)),
        ),
      ),
      title: Text(
        track.title,
        style: AppTypography.bodyMedium.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${track.artist} • ${track.formattedDuration} • ${track.container.toUpperCase()}',
        style: AppTypography.caption.copyWith(color: textSecondary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              track.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: track.isFavorite ? AppColors.accentAmber : textSecondary,
              size: 22,
            ),
            tooltip: 'Yêu thích',
            onPressed: () => _toggleFavorite(track),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: textSecondary, size: 20),
            onSelected: (val) {
              if (val == 'playlist') {
                _showAddToPlaylistSheet(track);
              } else if (val == 'delete') {
                _deleteTrack(track);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'playlist',
                child: Row(
                  children: [
                    Icon(Icons.playlist_add_rounded, color: AppColors.accentCyan, size: 18),
                    SizedBox(width: 8),
                    Text('Thêm vào Playlist'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: AppColors.accentRed, size: 18),
                    SizedBox(width: 8),
                    Text('Xóa', style: TextStyle(color: AppColors.accentRed)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () {
        ref.read(playbackControllerProvider.notifier).playLocalItem(track, queue: queue, resumePosition: false);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
        );
      },
    );
  }

  Widget _buildEmptyState(Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.queue_music_rounded, color: AppColors.accentAmber, size: 54),
          const SizedBox(height: AppSpacing.s16),
          Text('Chưa có bài hát nào', style: AppTypography.h3),
          const SizedBox(height: 6),
          Text('Nhạc và âm thanh sau khi tải sẽ tự động xuất hiện ở đây ngay lập tức.', style: AppTypography.bodySmall.copyWith(color: textSecondary)),
        ],
      ),
    );
  }
}
