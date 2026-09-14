import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings_vi.dart';
import '../../../core/navigation/navigation_provider.dart';
import '../../../core/utils/html_utils.dart';
import '../../downloads/engine/download_manager.dart';
import '../../player/controller/global_playback_controller.dart';
import '../../player/presentation/music_player_screen.dart';
import '../../player/presentation/video_player_screen.dart';
import '../../resolver/domain/media_format.dart';
import '../../resolver/domain/media_info.dart';

class AnalyzeSheet extends ConsumerStatefulWidget {
  final MediaInfo mediaInfo;

  const AnalyzeSheet({super.key, required this.mediaInfo});

  @override
  ConsumerState<AnalyzeSheet> createState() => _AnalyzeSheetState();
}

class _AnalyzeSheetState extends ConsumerState<AnalyzeSheet> {
  int _selectedTab = 0; // 0 = Video, 1 = Âm thanh
  MediaFormat? _selectedFormat;
  bool _convertToMp3 = true;
  final int _mp3Bitrate = 320;

  @override
  void initState() {
    super.initState();
    if (widget.mediaInfo.videoFormats.isNotEmpty) {
      _selectedTab = 0;
      _selectedFormat = widget.mediaInfo.highestQualityVideo ?? widget.mediaInfo.formats.first;
    } else {
      _selectedTab = 1;
      _selectedFormat = widget.mediaInfo.bestAudio ?? widget.mediaInfo.formats.first;
    }
  }

  void _onDownloadPressed() {
    if (_selectedFormat == null) return;
    HapticFeedback.mediumImpact();

    DownloadManager().enqueue(
      mediaInfo: widget.mediaInfo,
      selectedFormat: _selectedFormat!,
      convertToMp3: _selectedTab == 1 && _convertToMp3,
      mp3Bitrate: _mp3Bitrate,
    );

    Navigator.of(context).pop();
    ref.read(navigationTabProvider.notifier).switchToDownloads();
  }

  void _onStreamNowPressed() async {
    if (_selectedFormat == null) return;
    HapticFeedback.selectionClick();

    final controller = ref.read(playbackControllerProvider.notifier);
    Navigator.of(context).pop();

    await controller.playOnlineStream(widget.mediaInfo, _selectedFormat!);

    if (mounted) {
      if (_selectedFormat!.hasVideo) {
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

  String _formatResolution(MediaFormat format) {
    final h = format.height ?? 0;
    if (h >= 1080) return AppStringsVi.resolutionSuper;
    if (h >= 720) return AppStringsVi.resolutionHigh;
    if (h >= 480) return AppStringsVi.resolutionStandard;
    return AppStringsVi.resolutionEconomy;
  }

  String _formatAudioQuality(MediaFormat format) {
    final br = (format.bitrate ?? 0) ~/ 1000;
    if (br >= 320) return AppStringsVi.audioStudio;
    if (br >= 256) return AppStringsVi.audioHigh;
    if (br >= 192) return AppStringsVi.audioStandard;
    return AppStringsVi.audioEconomy;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final accent = isDark ? AppColors.accentCyan : AppColors.accentBlue;

    final info = widget.mediaInfo;
    final videoFormats = info.videoFormats;
    final audioFormats = info.audioFormats;

    final title = HtmlUtils.unescape(info.title);
    final author = HtmlUtils.unescape(info.author);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thanh kéo nhẹ phía trên
              Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Thẻ tác phẩm (Ảnh bìa + Tên + Tác giả)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 90,
                      height: 60,
                      child: info.thumbnailUrl != null
                          ? Image.network(
                              info.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, error, stack) => _defaultThumb(),
                            )
                          : _defaultThumb(),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$author • ${_formatDuration(info.duration)}',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Bộ chọn Tab: Hình ảnh & Video VS Âm thanh & Nhạc
              Container(
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightElevated,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedTab = 0;
                            if (videoFormats.isNotEmpty) {
                              _selectedFormat = videoFormats.first;
                            }
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: _selectedTab == 0
                                ? (isDark ? AppColors.darkElevated : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _selectedTab == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(isDark ? 50 : 15),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.movie_rounded,
                                  size: 16,
                                  color: _selectedTab == 0 ? accent : textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  AppStringsVi.tabVideo,
                                  style: TextStyle(
                                    color: _selectedTab == 0 ? textPrimary : textSecondary,
                                    fontWeight: _selectedTab == 0 ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedTab = 1;
                            if (audioFormats.isNotEmpty) {
                              _selectedFormat = audioFormats.first;
                            }
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: _selectedTab == 1
                                ? (isDark ? AppColors.darkElevated : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _selectedTab == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(isDark ? 50 : 15),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.music_note_rounded,
                                  size: 16,
                                  color: _selectedTab == 1 ? accent : textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  AppStringsVi.tabAudio,
                                  style: TextStyle(
                                    color: _selectedTab == 1 ? textPrimary : textSecondary,
                                    fontWeight: _selectedTab == 1 ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 12.5,
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

              const SizedBox(height: 14),

              // Danh sách các định dạng theo Tab đã chọn
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView(
                  shrinkWrap: true,
                  children: _selectedTab == 0
                      ? videoFormats.map((fmt) => _buildFormatTile(fmt, isDark, textPrimary, textSecondary, accent)).toList()
                      : audioFormats.map((fmt) => _buildFormatTile(fmt, isDark, textPrimary, textSecondary, accent)).toList(),
                ),
              ),

              // Tùy chọn chuyển sang MP3 nếu ở Tab Âm thanh
              if (_selectedTab == 1) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: accent,
                  checkColor: Colors.black,
                  value: _convertToMp3,
                  title: const Text(
                    AppStringsVi.convertToMp3,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    AppStringsVi.convertToMp3Hint,
                    style: TextStyle(fontSize: 11),
                  ),
                  onChanged: (val) {
                    setState(() => _convertToMp3 = val ?? true);
                  },
                ),
              ],

              const SizedBox(height: 16),

              // 2 Phím hành động: Tải về máy ngay & Xem/Nghe thử
              Row(
                children: [
                  // Nút Xem / Nghe thử
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    icon: Icon(
                      _selectedTab == 0 ? Icons.play_circle_outline_rounded : Icons.headphones_rounded,
                      size: 20,
                      color: textPrimary,
                    ),
                    label: Text(
                      AppStringsVi.playNow,
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    onPressed: _onStreamNowPressed,
                  ),
                  const SizedBox(width: 10),

                  // Nút Tải về máy ngay
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentCyan.withAlpha(isDark ? 90 : 50),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.arrow_downward_rounded, color: Colors.black, size: 22),
                        label: const Text(
                          AppStringsVi.downloadNow,
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: _onDownloadPressed,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatTile(
    MediaFormat fmt,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color accent,
  ) {
    final isSelected = _selectedFormat == fmt;
    final label = fmt.hasVideo ? _formatResolution(fmt) : _formatAudioQuality(fmt);
    final sizeStr = fmt.estimatedSizeBytes != null
        ? AppStringsVi.formatBytes(fmt.estimatedSizeBytes!)
        : 'Tự động';

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFormat = fmt);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withAlpha(isDark ? 40 : 25)
              : (isDark ? AppColors.darkSurface : AppColors.lightElevated),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accent : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: isSelected ? accent : textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? (isDark ? Colors.white : accent) : textPrimary,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Định dạng ${fmt.container.toUpperCase()} • $sizeStr',
                    style: TextStyle(color: textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultThumb() {
    return Container(
      color: AppColors.accentCyan.withAlpha(40),
      child: const Icon(Icons.video_library_rounded, color: AppColors.accentCyan),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
