import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    HapticFeedback.selectionClick();
    await _repository.toggleFavorite(item.id);
  }

  Future<void> _deleteTrack(MediaItemModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa bài hát?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc muốn xóa "${item.title}" khỏi thiết bị?'),
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

  void _showCreatePlaylistDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Tạo Playlist Mới', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Tên danh sách phát *',
                hintText: 'Ví dụ: Nhạc Chill, Top Hits...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: 'Mô tả (tùy chọn)',
                hintText: 'Ghi chú cho playlist này...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFA2D48),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await _repository.createPlaylist(name, description: descController.text.trim());
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  setState(() => _selectedFilter = 1);
                }
              }
            },
            child: const Text('Tạo ngay', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistSheet(MediaItemModel track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final playlistsAsync = ref.watch(playlistListProvider);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              color: isDark ? const Color(0xFF1C1C1E).withAlpha(240) : Colors.white.withAlpha(240),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(80),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Thêm vào Playlist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    leading: const Icon(Icons.add_circle_rounded, color: Color(0xFFFA2D48), size: 28),
                    title: const Text('Tạo Playlist mới', style: TextStyle(fontWeight: FontWeight.w600)),
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
                          child: Text('Chưa có playlist nào. Hãy tạo mới ở trên!', style: TextStyle(color: Colors.grey)),
                        );
                      }
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: playlists.length,
                          itemBuilder: (context, index) {
                            final p = playlists[index];
                            return ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              leading: const Icon(Icons.queue_music_rounded, color: Color(0xFFFA2D48)),
                              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${p.itemCount} bài hát', style: const TextStyle(fontSize: 12)),
                              onTap: () async {
                                await _repository.addMediaToPlaylist(p.id, track.id);
                                if (ctx.mounted) Navigator.of(ctx).pop();
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
          ),
        );
      },
    );
  }

  void _openPlaylistDetails(PlaylistModel playlist) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.75,
              color: isDark ? const Color(0xFF1C1C1E).withAlpha(245) : Colors.white.withAlpha(245),
              child: FutureBuilder<List<MediaItemModel>>(
                future: _repository.getPlaylistItems(playlist.id),
                builder: (context, snapshot) {
                  final items = snapshot.data ?? [];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.withAlpha(80),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    playlist.name,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${items.length} bài hát',
                                    style: TextStyle(
                                      color: isDark ? Colors.white60 : Colors.black54,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (items.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFA2D48),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: () {
                                    ref.read(playbackControllerProvider.notifier).playAll(items, shuffle: false);
                                    Navigator.of(ctx).pop();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
                                    );
                                  },
                                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                                  label: const Text('Phát tất cả', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10),
                                    foregroundColor: isDark ? Colors.white : Colors.black87,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: () {
                                    ref.read(playbackControllerProvider.notifier).playAll(items, shuffle: true);
                                    Navigator.of(ctx).pop();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
                                    );
                                  },
                                  icon: const Icon(Icons.shuffle_rounded, size: 20, color: Color(0xFFFA2D48)),
                                  label: const Text('Xáo trộn', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Divider(height: 24),
                        Expanded(
                          child: items.isEmpty
                              ? const Center(child: Text('Danh sách phát này chưa có bài hát nào.'))
                              : ListView.separated(
                                  itemCount: items.length,
                                  separatorBuilder: (_, index) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final item = items[index];
                                    return ListTile(
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: SizedBox(
                                          width: 44,
                                          height: 44,
                                          child: item.thumbnailPath != null && File(item.thumbnailPath!).existsSync()
                                              ? Image.file(File(item.thumbnailPath!), fit: BoxFit.cover)
                                              : Container(
                                                  color: const Color(0xFFFA2D48).withAlpha(25),
                                                  child: const Icon(Icons.music_note_rounded, color: Color(0xFFFA2D48)),
                                                ),
                                        ),
                                      ),
                                      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      subtitle: Text(item.artist, maxLines: 1),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent),
                                        onPressed: () async {
                                          await _repository.removeMediaFromPlaylist(playlist.id, item.id);
                                          if (ctx.mounted) Navigator.of(ctx).pop();
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
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? Colors.white.withAlpha(160) : const Color(0xFF6B7280);
    const appleMusicAccent = Color(0xFFFA2D48); // Official Apple Music Signature Red

    final audioAsync = ref.watch(audioLibraryProvider);
    final playlistsAsync = ref.watch(playlistListProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Apple Music Large SF Pro Title Header
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 16, top: 12, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nhạc',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  if (_selectedFilter == 1)
                    IconButton(
                      icon: const Icon(Icons.add_circle_rounded, color: appleMusicAccent, size: 28),
                      tooltip: 'Tạo Playlist',
                      onPressed: _showCreatePlaylistDialog,
                    ),
                ],
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
                          hintText: 'Tìm kiếm trong thư viện...',
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

            // 3. Apple Segmented Control Pill Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.black.withAlpha(14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _buildSegmentButton('Tất cả', 0, isDark, textPrimary),
                    _buildSegmentButton('Danh sách phát', 1, isDark, textPrimary),
                    _buildSegmentButton('Yêu thích', 2, isDark, textPrimary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 4),

            // 4. Content View
            Expanded(
              child: _selectedFilter == 1
                  ? _buildPlaylistsView(playlistsAsync, textPrimary, textSecondary, appleMusicAccent, isDark)
                  : _buildTracksView(audioAsync, textPrimary, textSecondary, appleMusicAccent, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton(String label, int index, bool isDark, Color textPrimary) {
    final isSelected = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedFilter = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2C2C2E) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 50 : 18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? textPrimary : textPrimary.withAlpha(140),
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistsView(
    AsyncValue<List<PlaylistModel>> playlistsAsync,
    Color textPrimary,
    Color textSecondary,
    Color accent,
    bool isDark,
  ) {
    return playlistsAsync.when(
      data: (playlists) {
        if (playlists.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.queue_music_rounded, size: 64, color: accent.withAlpha(160)),
                const SizedBox(height: 14),
                Text('Chưa có danh sách phát', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Nhấn bên dưới để tạo playlist đầu tiên của bạn', style: TextStyle(color: textSecondary, fontSize: 13)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: _showCreatePlaylistDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Tạo Playlist Mới', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(left: 18, right: 18, top: 8, bottom: 120),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final p = playlists[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 30 : 6),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [accent, accent.withAlpha(180)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 24),
                ),
                title: Text(p.name, style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: Text('${p.itemCount} bài hát', style: TextStyle(color: textSecondary, fontSize: 12.5)),
                trailing: IconButton(
                  icon: Icon(Icons.more_horiz_rounded, color: textSecondary),
                  onPressed: () => _openPlaylistDetails(p),
                ),
                onTap: () => _openPlaylistDetails(p),
              ),
            );
          },
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: accent)),
      error: (err, _) => Center(child: Text('Lỗi tải playlist: $err')),
    );
  }

  Widget _buildTracksView(
    AsyncValue<List<MediaItemModel>> audioAsync,
    Color textPrimary,
    Color textSecondary,
    Color accent,
    bool isDark,
  ) {
    return audioAsync.when(
      data: (allTracks) {
        var tracks = allTracks;

        if (_selectedFilter == 2) {
          tracks = tracks.where((t) => t.isFavorite).toList();
        }

        final query = _searchController.text.trim().toLowerCase();
        if (query.isNotEmpty) {
          tracks = tracks.where((t) =>
            t.title.toLowerCase().contains(query) ||
            t.artist.toLowerCase().contains(query),
          ).toList();
        }

        if (tracks.isEmpty) {
          return _buildEmptyState(textPrimary, textSecondary);
        }

        return Column(
          children: [
            // Apple Music Signature Dual Action Pills: [ ▶ Phát tất cả ] & [ 🔀 Xáo trộn ]
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
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
                            ref.read(playbackControllerProvider.notifier).playAll(tracks, shuffle: false);
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: accent, size: 24),
                              const SizedBox(width: 6),
                              Text(
                                'Phát tất cả (${tracks.length})',
                                style: TextStyle(
                                  color: accent,
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 46,
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
                            ref.read(playbackControllerProvider.notifier).playAll(tracks, shuffle: true);
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shuffle_rounded, color: accent, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                'Xáo trộn',
                                style: TextStyle(
                                  color: accent,
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
                ],
              ),
            ),

            // Track List (Apple Music Row)
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(left: 18, right: 18, top: 4, bottom: 120),
                itemCount: tracks.length,
                separatorBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(left: 64),
                  child: Divider(
                    height: 1,
                    color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
                  ),
                ),
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  return _buildTrackTile(track, tracks, textPrimary, textSecondary, accent, isDark);
                },
              ),
            ),
          ],
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: accent)),
      error: (err, _) => Center(child: Text('Lỗi tải nhạc: $err')),
    );
  }

  Widget _buildTrackTile(
    MediaItemModel track,
    List<MediaItemModel> queue,
    Color textPrimary,
    Color textSecondary,
    Color accent,
    bool isDark,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(playbackControllerProvider.notifier).playLocalItem(track, queue: queue, resumePosition: false);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MusicPlayerScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // Artwork with subtle shadow
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 45 : 18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: track.thumbnailPath != null && File(track.thumbnailPath!).existsSync()
                      ? Image.file(File(track.thumbnailPath!), fit: BoxFit.cover)
                      : (track.thumbnailUrl != null
                          ? Image.network(track.thumbnailUrl!, fit: BoxFit.cover)
                          : Container(
                              color: accent.withAlpha(25),
                              child: Icon(Icons.music_note_rounded, color: accent, size: 24),
                            )),
                ),
              ),
              const SizedBox(width: 12),

              // Title and Artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'LOSSLESS',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${track.artist} • ${track.formattedDuration}',
                            style: TextStyle(color: textSecondary, fontSize: 12.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Favorite Heart
              IconButton(
                icon: Icon(
                  track.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: track.isFavorite ? accent : textSecondary.withAlpha(120),
                  size: 20,
                ),
                onPressed: () => _toggleFavorite(track),
              ),

              // Action Dots
              IconButton(
                icon: Icon(Icons.more_horiz_rounded, color: textSecondary, size: 20),
                onPressed: () {
                  _showTrackOptions(track);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTrackOptions(MediaItemModel track) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: isDark ? const Color(0xFF1C1C1E).withAlpha(240) : Colors.white.withAlpha(240),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.playlist_add_rounded, color: Color(0xFFFA2D48)),
                  title: const Text('Thêm vào Playlist', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showAddToPlaylistSheet(track);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: const Text('Xóa bài hát', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _deleteTrack(track);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note_rounded, color: textSecondary.withAlpha(120), size: 64),
          const SizedBox(height: 14),
          Text(
            'Thư viện trống',
            style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Bài hát sau khi tải sẽ tự động xuất hiện tại đây.',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
