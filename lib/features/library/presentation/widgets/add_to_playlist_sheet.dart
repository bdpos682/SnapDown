import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/models/media_item_model.dart';
import '../../../../core/database/models/playlist_model.dart';
import '../../../../core/database/repositories/media_repository.dart';
import '../../../../core/utils/html_utils.dart';
import '../../../../core/widgets/app_dialogs.dart';

class AddToPlaylistSheet extends StatefulWidget {
  final MediaItemModel item;

  const AddToPlaylistSheet({super.key, required this.item});

  static Future<void> show(BuildContext context, MediaItemModel item) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddToPlaylistSheet(item: item),
    );
  }

  @override
  State<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<AddToPlaylistSheet> {
  final MediaRepository _repository = MediaRepository();
  List<PlaylistModel> _playlists = [];
  Set<String> _containingPlaylistIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    final playlists = await _repository.getPlaylists();
    final containing = await _repository.getPlaylistsContainingMedia(widget.item.id);
    if (mounted) {
      setState(() {
        _playlists = playlists;
        _containingPlaylistIds = containing.toSet();
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePlaylist(PlaylistModel playlist) async {
    HapticFeedback.selectionClick();
    final isInPlaylist = _containingPlaylistIds.contains(playlist.id);
    final messenger = ScaffoldMessenger.of(context);

    if (isInPlaylist) {
      await _repository.removeMediaFromPlaylist(playlist.id, widget.item.id);
      if (mounted) {
        setState(() {
          _containingPlaylistIds.remove(playlist.id);
        });
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Đã xóa khỏi danh sách "${playlist.name}"'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      await _repository.addMediaToPlaylist(playlist.id, widget.item.id);
      if (mounted) {
        setState(() {
          _containingPlaylistIds.add(playlist.id);
        });
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Đã thêm vào danh sách "${playlist.name}"'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _createNewPlaylist() async {
    final name = await AppDialogs.showTextInputDialog(
      context: context,
      title: 'Tạo danh sách phát mới',
      hintText: 'Nhập tên danh sách bài hát...',
      confirmText: 'Tạo & Thêm vào',
      cancelText: 'Hủy',
      icon: Icons.playlist_add_rounded,
    );

    if (name != null && name.trim().isNotEmpty) {
      final p = await _repository.createPlaylist(name.trim());
      await _repository.addMediaToPlaylist(p.id, widget.item.id);
      await _loadPlaylists();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã tạo và thêm vào "${p.name}"'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final accent = isDark ? AppColors.accentCyan : AppColors.accentBlue;

    final title = HtmlUtils.unescape(widget.item.title);
    final artist = HtmlUtils.unescape(widget.item.artist);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141824) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 100 : 25),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thanh gạt drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(50) : Colors.black.withAlpha(30),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Tiêu đề BottomSheet
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Thêm vào danh sách phát',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Thẻ tóm tắt bài hát đang chọn
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: widget.item.thumbnailPath != null &&
                              File(widget.item.thumbnailPath!).existsSync()
                          ? Image.file(File(widget.item.thumbnailPath!), fit: BoxFit.cover)
                          : Container(
                              color: accent.withAlpha(40),
                              child: Icon(Icons.music_note_rounded, color: accent),
                            ),
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
                            color: textPrimary,
                            fontSize: 13,
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
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Nút Tạo danh sách mới nổi bật
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: InkWell(
                onTap: _createNewPlaylist,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withAlpha(isDark ? 45 : 25),
                        AppColors.accentBlue.withAlpha(isDark ? 45 : 25),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.black, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Tạo danh sách phát mới...',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Danh sách các Playlist
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(color: AppColors.accentCyan),
                      ),
                    )
                  : _playlists.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.queue_music_rounded, size: 44, color: textSecondary),
                              const SizedBox(height: 10),
                              Text(
                                'Bạn chưa có danh sách phát nào',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Hãy tạo danh sách phát đầu tiên ở nút phía trên',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          itemCount: _playlists.length,
                          itemBuilder: (context, i) {
                            final p = _playlists[i];
                            final isAdded = _containingPlaylistIds.contains(p.id);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isAdded
                                    ? accent.withAlpha(isDark ? 25 : 15)
                                    : (isDark ? AppColors.darkCard : AppColors.lightCard),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isAdded
                                      ? accent
                                      : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                                  width: isAdded ? 1.3 : 1.0,
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                leading: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    gradient: isAdded ? AppColors.primaryGradient : null,
                                    color: isAdded ? null : (isDark ? Colors.white12 : Colors.black12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.queue_music_rounded,
                                    color: isAdded ? Colors.black : textSecondary,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  p.name,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: isAdded ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                                subtitle: Text(
                                  '${p.itemCount} bản nhạc',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                                trailing: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isAdded ? accent : Colors.transparent,
                                    border: isAdded
                                        ? null
                                        : Border.all(
                                            color: isDark ? Colors.white30 : Colors.black26,
                                            width: 1.5,
                                          ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isAdded ? Icons.check_rounded : Icons.add_rounded,
                                      color: isAdded ? Colors.black : textSecondary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                onTap: () => _togglePlaylist(p),
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
