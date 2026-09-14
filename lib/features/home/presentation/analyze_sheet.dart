import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
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
  int _selectedTab = 0; // 0 = Video, 1 = Audio
  MediaFormat? _selectedFormat;
  bool _convertToMp3 = false;
  int _mp3Bitrate = 320;

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

    DownloadManager().enqueue(
      mediaInfo: widget.mediaInfo,
      selectedFormat: _selectedFormat!,
      convertToMp3: _selectedTab == 1 && _convertToMp3,
      mp3Bitrate: _mp3Bitrate,
    );

    Navigator.of(context).pop();

    // Nhảy ngay sang tab Tải xuống
    ref.read(navigationTabProvider.notifier).switchToDownloads();
  }

  void _onStreamNowPressed() async {
    if (_selectedFormat == null) return;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final primaryAccent = isDark ? AppColors.accentCyan : AppColors.accentBlue;

    final info = widget.mediaInfo;
    final videoFormats = info.videoFormats;
    final audioFormats = info.audioFormats;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: AppSpacing.s12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thanh kéo nhẹ
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkHighlight : AppColors.lightHighlight,
                    borderRadius: AppRadius.radiusPill,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),

              // Thông tin tệp
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.radiusMd,
                    child: info.thumbnailUrl != null
                        ? Image.network(
                            info.thumbnailUrl!,
                            width: 100,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _thumbPlaceholder(),
                          )
                        : _thumbPlaceholder(),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryAccent.withAlpha(30),
                            borderRadius: AppRadius.radiusXs,
                          ),
                          child: Text(
                            info.platform.toUpperCase(),
                            style: AppTypography.caption.copyWith(
                              color: primaryAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          HtmlUtils.unescape(info.title),
                          style: AppTypography.bodyMedium.copyWith(
                            color: textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${HtmlUtils.unescape(info.author)} • ${info.formattedDuration}',
                          style: AppTypography.caption.copyWith(color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),

              // Segment chọn: [ VIDEO | ÂM THANH ]
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkElevated : AppColors.lightElevated,
                  borderRadius: AppRadius.radiusMd,
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSegmentButton(
                        title: 'VIDEO',
                        icon: Icons.movie_outlined,
                        selected: _selectedTab == 0,
                        primaryAccent: primaryAccent,
                        onTap: () {
                          setState(() {
                            _selectedTab = 0;
                            _selectedFormat = info.highestQualityVideo ?? videoFormats.firstOrNull;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: _buildSegmentButton(
                        title: 'ÂM THANH',
                        icon: Icons.headphones_outlined,
                        selected: _selectedTab == 1,
                        primaryAccent: primaryAccent,
                        onTap: () {
                          setState(() {
                            _selectedTab = 1;
                            _selectedFormat = info.bestAudio ?? audioFormats.firstOrNull;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),

              // Danh sách định dạng
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView(
                  shrinkWrap: true,
                  children: _selectedTab == 0
                      ? _buildVideoOptions(videoFormats, textPrimary, textSecondary, primaryAccent)
                      : _buildAudioOptions(audioFormats, textPrimary, textSecondary, primaryAccent),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),

              // Nút hành động
              Row(
                children: [
                  // Nút phụ: Xem / Nghe trực tiếp
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                        side: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      onPressed: _onStreamNowPressed,
                      icon: Icon(
                        _selectedTab == 0 ? Icons.play_arrow_rounded : Icons.headphones_rounded,
                        color: textPrimary,
                      ),
                      label: Text(
                        _selectedTab == 0 ? 'XEM NGAY' : 'NGHE NGAY',
                        style: AppTypography.label.copyWith(color: textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),

                  // Nút chính: Tải về
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isDark ? AppColors.cyanBlueGradient : AppColors.lightPrimaryGradient,
                        borderRadius: AppRadius.radiusMd,
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                        ),
                        onPressed: _onDownloadPressed,
                        icon: const Icon(Icons.download_rounded, color: Colors.white),
                        label: Text(
                          'TẢI XUỐNG',
                          style: AppTypography.label.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
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

  List<Widget> _buildVideoOptions(
    List<MediaFormat> formats,
    Color textPrimary,
    Color textSecondary,
    Color primaryAccent,
  ) {
    if (formats.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Text('Không tìm thấy luồng video', style: AppTypography.bodySmall.copyWith(color: textSecondary)),
        )
      ];
    }

    return formats.map((fmt) {
      final isSelected = _selectedFormat?.formatId == fmt.formatId;
      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s8),
        decoration: BoxDecoration(
          color: isSelected ? primaryAccent.withAlpha(20) : Colors.transparent,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(
            color: isSelected ? primaryAccent : AppColors.darkBorderSubtle,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: ListTile(
          dense: true,
          onTap: () => setState(() => _selectedFormat = fmt),
          title: Row(
            children: [
              Text(
                fmt.displayQuality,
                style: AppTypography.bodyMedium.copyWith(
                  color: isSelected ? primaryAccent : textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              if (fmt.fps != null && fmt.fps! >= 50)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withAlpha(40),
                    borderRadius: AppRadius.radiusXs,
                  ),
                  child: Text('${fmt.fps} FPS', style: AppTypography.caption.copyWith(color: primaryAccent)),
                ),
            ],
          ),
          subtitle: Text(fmt.displayDetails, style: AppTypography.caption.copyWith(color: textSecondary)),
          trailing: Text(fmt.formattedSize, style: AppTypography.bodySmall.copyWith(color: textSecondary)),
        ),
      );
    }).toList();
  }

  List<Widget> _buildAudioOptions(
    List<MediaFormat> formats,
    Color textPrimary,
    Color textSecondary,
    Color primaryAccent,
  ) {
    return [
      // 1. Lựa chọn Best Audio
      Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s8),
        decoration: BoxDecoration(
          color: (!_convertToMp3) ? AppColors.accentAmber.withAlpha(20) : Colors.transparent,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(
            color: (!_convertToMp3) ? AppColors.accentAmber : AppColors.darkBorderSubtle,
            width: (!_convertToMp3) ? 1.5 : 1,
          ),
        ),
        child: ListTile(
          dense: true,
          onTap: () {
            setState(() {
              _convertToMp3 = false;
              _selectedFormat = widget.mediaInfo.bestAudio ?? formats.firstOrNull;
            });
          },
          title: Row(
            children: [
              Text(
                'ÂM THANH TỐT NHẤT',
                style: AppTypography.bodyMedium.copyWith(
                  color: (!_convertToMp3) ? AppColors.accentAmber : textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withAlpha(30),
                  borderRadius: AppRadius.radiusXs,
                ),
                child: Text('KHUYÊN DÙNG', style: AppTypography.caption.copyWith(color: AppColors.accentGreen)),
              ),
            ],
          ),
          subtitle: Text(
            'Chất lượng gốc (${_selectedFormat?.container.toUpperCase() ?? 'M4A/OPUS'}) • Không nén lại',
            style: AppTypography.caption.copyWith(color: textSecondary),
          ),
        ),
      ),

      // 2. Lựa chọn chuyển sang MP3
      Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s8),
        decoration: BoxDecoration(
          color: _convertToMp3 ? primaryAccent.withAlpha(20) : Colors.transparent,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(
            color: _convertToMp3 ? primaryAccent : AppColors.darkBorderSubtle,
            width: _convertToMp3 ? 1.5 : 1,
          ),
        ),
        child: ListTile(
          dense: true,
          onTap: () {
            setState(() {
              _convertToMp3 = true;
              _selectedFormat = widget.mediaInfo.bestAudio ?? formats.firstOrNull;
            });
          },
          title: Row(
            children: [
              Text(
                'Chuyển đổi MP3',
                style: AppTypography.bodyMedium.copyWith(
                  color: _convertToMp3 ? primaryAccent : textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _mp3Bitrate,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 320, child: Text('320 kbps')),
                  DropdownMenuItem(value: 256, child: Text('256 kbps')),
                  DropdownMenuItem(value: 192, child: Text('192 kbps')),
                  DropdownMenuItem(value: 128, child: Text('128 kbps')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _mp3Bitrate = val);
                },
              ),
            ],
          ),
          subtitle: Text('Định dạng MP3 tương thích mọi thiết bị', style: AppTypography.caption.copyWith(color: textSecondary)),
        ),
      ),
    ];
  }

  Widget _buildSegmentButton({
    required String title,
    required IconData icon,
    required bool selected,
    required Color primaryAccent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primaryAccent : Colors.transparent,
          borderRadius: AppRadius.radiusSm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : AppColors.darkTextSecondary),
            const SizedBox(width: 6),
            Text(
              title,
              style: AppTypography.label.copyWith(
                color: selected ? Colors.white : AppColors.darkTextSecondary,
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 100,
      height: 64,
      color: AppColors.darkHighlight,
      child: const Center(
        child: Icon(Icons.movie_rounded, color: AppColors.accentCyan, size: 28),
      ),
    );
  }
}
