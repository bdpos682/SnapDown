import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/database/repositories/media_repository.dart';
import '../controller/global_playback_controller.dart';
import '../controller/playback_state.dart';

class MusicPlayerScreen extends ConsumerStatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  ConsumerState<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends ConsumerState<MusicPlayerScreen> with TickerProviderStateMixin {
  final MediaRepository _repository = MediaRepository();

  double _volume = 1.0;
  bool _showLyrics = false;
  double? _dragPositionMs;
  Timer? _sleepTimer;
  int? _sleepTimerRemainingMinutes;

  late final AnimationController _waveAnimController;

  @override
  void initState() {
    super.initState();
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(playbackControllerProvider.notifier);
      setState(() {
        _volume = controller.currentVolume;
      });
    });
  }

  @override
  void dispose() {
    _waveAnimController.dispose();
    _sleepTimer?.cancel();
    super.dispose();
  }

  void _setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (minutes <= 0) {
      setState(() => _sleepTimerRemainingMinutes = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tắt hẹn giờ ngủ'), duration: Duration(seconds: 2)),
      );
      return;
    }

    setState(() => _sleepTimerRemainingMinutes = minutes);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hẹn giờ tắt nhạc sau $minutes phút'),
        duration: const Duration(seconds: 2),
      ),
    );

    _sleepTimer = Timer(Duration(minutes: minutes), () {
      ref.read(playbackControllerProvider.notifier).togglePlayPause();
      if (mounted) {
        setState(() => _sleepTimerRemainingMinutes = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã dừng phát nhạc theo hẹn giờ')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);

    final durMs = playback.duration.inMilliseconds.toDouble();
    final currentPosMs = playback.position.inMilliseconds.toDouble();
    final activePosMs = (_dragPositionMs ?? currentPosMs).clamp(0.0, durMs > 0 ? durMs : 1.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Dynamic Ambient Fluid Glow (Apple Music style)
          _buildAmbientBackground(playback),

          // 2. Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
              child: Column(
                children: [
                  // Top Drag Handle & Navigation
                  _buildTopBar(context, playback, controller),

                  const Spacer(flex: 1),

                  // Hero Artwork or Real-time Lyrics
                  Expanded(
                    flex: 12,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _showLyrics
                          ? _buildLyricsView(playback)
                          : _buildArtwork(playback),
                    ),
                  ),

                  const Spacer(flex: 1),

                  // Song Metadata & Heart Favorite
                  _buildSongInfoRow(playback),

                  const SizedBox(height: AppSpacing.s16),

                  // Scrubber (Apple Music Slider with negative remaining time)
                  _buildScrubber(activePosMs, durMs, playback, controller),

                  const SizedBox(height: AppSpacing.s16),

                  // Playback Core Controls (Shuffle, Prev, Play/Pause, Next, Repeat)
                  _buildPlaybackControls(playback, controller),

                  const SizedBox(height: AppSpacing.s20),

                  // Volume Slider with Apple Speaker Icons
                  _buildVolumeBar(controller),

                  const SizedBox(height: AppSpacing.s16),

                  // Bottom Action Bar (Lyrics, AirPlay, Queue)
                  _buildBottomActionBar(context, playback, controller),

                  const SizedBox(height: AppSpacing.s8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // MARK: - Dynamic Ambient Background
  Widget _buildAmbientBackground(PlaybackStateModel playback) {
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (playback.thumbnailPath != null && File(playback.thumbnailPath!).existsSync())
            Image.file(File(playback.thumbnailPath!), fit: BoxFit.cover)
          else if (playback.thumbnailUrl != null)
            Image.network(playback.thumbnailUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const SizedBox())
          else
            Container(color: const Color(0xFF1C1C1E)),

          // Heavy Gaussian Blur for fluid glow
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withAlpha(160),
                    Colors.black.withAlpha(210),
                    Colors.black.withAlpha(245),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // MARK: - Top Navigation Bar
  Widget _buildTopBar(
    BuildContext context,
    PlaybackStateModel playback,
    GlobalPlaybackController controller,
  ) {
    return Column(
      children: [
        const SizedBox(height: 6),
        // iOS Grabber Pill
        Container(
          width: 38,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(80),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 32),
              tooltip: 'Thu nhỏ',
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'ĐANG PHÁT TỪ DANH SÁCH',
                    style: TextStyle(
                      color: Colors.white.withAlpha(150),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    playback.localItem != null ? 'Thư viện SnapDown' : 'Bộ giải mã trực tuyến',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70, size: 26),
              tooltip: 'Tùy chọn khác',
              onPressed: () => _showMoreActionsSheet(context, playback, controller),
            ),
          ],
        ),
      ],
    );
  }

  // MARK: - Hero Artwork with Scale Animation
  Widget _buildArtwork(PlaybackStateModel playback) {
    final size = MediaQuery.of(context).size.width * 0.76;

    Widget imageContent;
    if (playback.thumbnailPath != null && File(playback.thumbnailPath!).existsSync()) {
      imageContent = Image.file(File(playback.thumbnailPath!), fit: BoxFit.cover);
    } else if (playback.thumbnailUrl != null) {
      imageContent = Image.network(
        playback.thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _artworkPlaceholder(),
      );
    } else {
      imageContent = _artworkPlaceholder();
    }

    // Apple Music signature scale effect: 1.0 when playing, 0.84 when paused
    return Center(
      child: AnimatedScale(
        scale: playback.isPlaying ? 1.0 : 0.84,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(150),
                blurRadius: 36,
                offset: const Offset(0, 18),
                spreadRadius: 2,
              ),
              BoxShadow(
                color: AppColors.accentCyan.withAlpha(playback.isPlaying ? 40 : 15),
                blurRadius: 40,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: imageContent,
          ),
        ),
      ),
    );
  }

  Widget _artworkPlaceholder() {
    return Container(
      color: const Color(0xFF2C2C2E),
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: AppColors.accentCyan, size: 72),
      ),
    );
  }

  // MARK: - Lyrics & Visualizer View
  Widget _buildLyricsView(PlaybackStateModel playback) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lyrics_rounded, color: AppColors.accentCyan, size: 44),
          const SizedBox(height: 16),
          Text(
            playback.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            playback.artist,
            style: TextStyle(
              color: Colors.white.withAlpha(180),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          // Animated Real-time Sound Waveform
          AnimatedBuilder(
            animation: _waveAnimController,
            builder: (context, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(18, (index) {
                  final wave = (playback.isPlaying)
                      ? (0.2 + 0.8 * (0.5 + 0.5 * (index % 2 == 0 ? _waveAnimController.value : (1 - _waveAnimController.value))))
                      : 0.15;
                  final height = (30 * wave).clamp(6.0, 48.0);
                  return Container(
                    width: 4,
                    height: height,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withAlpha((180 + (index * 4)).clamp(100, 255)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Lời bài hát trực tiếp đang đồng bộ...',
            style: TextStyle(
              color: Colors.white.withAlpha(120),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // MARK: - Song Info Row & Heart
  Widget _buildSongInfoRow(PlaybackStateModel playback) {
    final isFav = playback.localItem?.isFavorite ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                playback.title.isNotEmpty ? playback.title : 'Bản nhạc',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      playback.artist.isNotEmpty ? playback.artist : 'Nghệ sĩ SnapDown',
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Apple Music Lossless / Hi-Res Chip
                  GestureDetector(
                    onTap: () => _showAudioQualityDetails(playback),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white.withAlpha(40), width: 0.8),
                      ),
                      child: const Text(
                        'LOSSLESS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Favorite Heart Button
        IconButton(
          icon: Icon(
            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFav ? AppColors.accentRed : Colors.white70,
            size: 26,
          ),
          onPressed: () async {
            HapticFeedback.lightImpact();
            if (playback.localItem != null) {
              await _repository.toggleFavorite(playback.localItem!.id);
              // Trigger refresh on state if needed
            }
          },
        ),
      ],
    );
  }

  // MARK: - Scrubber (Slider with negative remaining time)
  Widget _buildScrubber(
    double activePosMs,
    double durMs,
    PlaybackStateModel playback,
    GlobalPlaybackController controller,
  ) {
    final remainingMs = (durMs - activePosMs).clamp(0.0, durMs);
    final remainingDuration = Duration(milliseconds: remainingMs.toInt());

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withAlpha(50),
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayColor: Colors.white.withAlpha(30),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: activePosMs,
            min: 0.0,
            max: durMs > 0 ? durMs : 1.0,
            onChangeStart: (val) {
              setState(() => _dragPositionMs = val);
            },
            onChanged: (val) {
              setState(() => _dragPositionMs = val);
            },
            onChangeEnd: (val) {
              controller.seek(Duration(milliseconds: val.toInt()));
              setState(() => _dragPositionMs = null);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(Duration(milliseconds: activePosMs.toInt())),
                style: TextStyle(
                  color: Colors.white.withAlpha(160),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '-${_formatDuration(remainingDuration)}',
                style: TextStyle(
                  color: Colors.white.withAlpha(160),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // MARK: - Playback Core Controls
  Widget _buildPlaybackControls(
    PlaybackStateModel playback,
    GlobalPlaybackController controller,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Shuffle Button
        IconButton(
          icon: Icon(
            Icons.shuffle_rounded,
            color: playback.isShuffle ? AppColors.accentCyan : Colors.white54,
            size: 24,
          ),
          tooltip: 'Phát ngẫu nhiên',
          onPressed: () {
            HapticFeedback.selectionClick();
            controller.toggleShuffle();
          },
        ),

        // Previous Track
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 38),
          tooltip: 'Bài trước',
          onPressed: () {
            HapticFeedback.selectionClick();
            controller.previous();
          },
        ),

        // Big Play/Pause Button
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            controller.togglePlayPause();
          },
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withAlpha(70),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              playback.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.black,
              size: 44,
            ),
          ),
        ),

        // Next Track
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 38),
          tooltip: 'Bài kế tiếp',
          onPressed: () {
            HapticFeedback.selectionClick();
            controller.next();
          },
        ),

        // Repeat Button
        IconButton(
          icon: Icon(
            playback.repeatMode == RepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            color: playback.repeatMode != RepeatMode.off ? AppColors.accentCyan : Colors.white54,
            size: 24,
          ),
          tooltip: 'Lặp lại',
          onPressed: () {
            HapticFeedback.selectionClick();
            controller.toggleRepeat();
          },
        ),
      ],
    );
  }

  // MARK: - Volume Bar with Speaker Icons
  Widget _buildVolumeBar(GlobalPlaybackController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(
            _volume == 0 ? Icons.volume_mute_rounded : Icons.volume_down_rounded,
            color: Colors.white54,
            size: 20,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.5,
                activeTrackColor: Colors.white70,
                inactiveTrackColor: Colors.white.withAlpha(40),
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(
                value: _volume,
                min: 0.0,
                max: 1.0,
                onChanged: (val) {
                  setState(() => _volume = val);
                  controller.setVolume(val);
                },
              ),
            ),
          ),
          const Icon(Icons.volume_up_rounded, color: Colors.white54, size: 20),
        ],
      ),
    );
  }

  // MARK: - Bottom Action Bar (3 Iconic Apple Music Icons)
  Widget _buildBottomActionBar(
    BuildContext context,
    PlaybackStateModel playback,
    GlobalPlaybackController controller,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 1. Lyrics Toggle
        IconButton(
          icon: Icon(
            Icons.chat_bubble_outline_rounded,
            color: _showLyrics ? AppColors.accentCyan : Colors.white60,
            size: 24,
          ),
          tooltip: 'Lời bài hát',
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => _showLyrics = !_showLyrics);
          },
        ),

        // 2. AirPlay / Audio Output Route
        IconButton(
          icon: const Icon(Icons.airplay_rounded, color: Colors.white60, size: 24),
          tooltip: 'Thiết bị phát',
          onPressed: () => _showAudioRouteSheet(context),
        ),

        // 3. Up Next Playing Queue
        IconButton(
          icon: const Icon(Icons.queue_music_rounded, color: Colors.white60, size: 26),
          tooltip: 'Danh sách tiếp theo',
          onPressed: () => _showPlayingQueueSheet(context, playback, controller),
        ),
      ],
    );
  }

  // MARK: - Audio Quality Specs Dialog
  void _showAudioQualityDetails(PlaybackStateModel playback) {
    final item = playback.localItem;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.graphic_eq_rounded, color: AppColors.accentCyan),
                  SizedBox(width: 8),
                  Text(
                    'Định Dạng Âm Thanh Chuẩn Lossless',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSpecTile('Bộ mã hóa (Codec)', item?.audioCodec ?? 'AAC / Opus Studio Master'),
              _buildSpecTile('Định dạng tệp', item?.container.toUpperCase() ?? 'M4A'),
              _buildSpecTile('Tốc độ bit (Bitrate)', item?.bitrate != null ? '${(item!.bitrate! / 1000).round()} kbps' : '320 kbps (High Fidelity)'),
              _buildSpecTile('Kênh âm thanh', 'Stereo 2 Kênh • 48.000 Hz'),
              _buildSpecTile('Dung lượng tệp', item?.formattedFileSize ?? 'Chất lượng cao'),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // MARK: - AirPlay / Audio Route Sheet
  void _showAudioRouteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Thiết Bị Phát Âm Thanh',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.phone_iphone_rounded, color: AppColors.accentCyan),
                title: const Text('Loa thiết bị này', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.check_circle_rounded, color: AppColors.accentCyan),
                onTap: () => Navigator.of(ctx).pop(),
              ),
              ListTile(
                leading: const Icon(Icons.headphones_rounded, color: Colors.white70),
                title: const Text('Tai nghe / Bluetooth', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Tự động định tuyến khi kết nối', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () => Navigator.of(ctx).pop(),
              ),
              ListTile(
                leading: const Icon(Icons.cast_rounded, color: Colors.white70),
                title: const Text('Google Cast / AirPlay', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // MARK: - Playing Queue Sheet (Up Next)
  void _showPlayingQueueSheet(
    BuildContext context,
    PlaybackStateModel playback,
    GlobalPlaybackController controller,
  ) {
    final queue = playback.queue;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tiếp theo',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${queue.length} bài hát',
                    style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 13),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: queue.isEmpty
                  ? Center(
                      child: Text(
                        'Hàng đợi trống\nHãy chọn phát một playlist từ Thư viện',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withAlpha(120)),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: queue.length,
                      itemBuilder: (context, index) {
                        final item = queue[index];
                        final isCurrent = index == playback.queueIndex;

                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 44,
                              height: 44,
                              color: Colors.white10,
                              child: item.thumbnailUrl != null
                                  ? Image.network(item.thumbnailUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.music_note_rounded, color: AppColors.accentCyan))
                                  : const Icon(Icons.music_note_rounded, color: AppColors.accentCyan),
                            ),
                          ),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrent ? AppColors.accentCyan : Colors.white,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            '${item.artist} • ${item.formattedDuration}',
                            style: TextStyle(color: Colors.white.withAlpha(140), fontSize: 12),
                          ),
                          trailing: isCurrent
                              ? const Icon(Icons.equalizer_rounded, color: AppColors.accentCyan)
                              : null,
                          onTap: () {
                            controller.playLocalItem(item, queue: queue);
                            Navigator.of(ctx).pop();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - More Actions Menu Sheet
  void _showMoreActionsSheet(
    BuildContext context,
    PlaybackStateModel playback,
    GlobalPlaybackController controller,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.speed_rounded, color: Colors.white),
                title: const Text('Tốc độ phát', style: TextStyle(color: Colors.white)),
                trailing: Text('${playback.speed}x', style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showSpeedPicker(context, controller, playback.speed);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bedtime_rounded, color: Colors.white),
                title: const Text('Hẹn giờ ngủ (Sleep Timer)', style: TextStyle(color: Colors.white)),
                trailing: Text(
                  _sleepTimerRemainingMinutes != null ? '$_sleepTimerRemainingMinutes phút' : 'Tắt',
                  style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showSleepTimerPicker(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.equalizer_rounded, color: Colors.white),
                title: const Text('Bộ cân bằng âm thanh (EQ)', style: TextStyle(color: Colors.white)),
                trailing: const Text('Bass Boosted', style: TextStyle(color: Colors.white54, fontSize: 13)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showEqPicker(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: Colors.white),
                title: const Text('Chia sẻ bài hát', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSpeedPicker(BuildContext context, GlobalPlaybackController controller, double currentSpeed) {
    final speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: speeds.map((s) {
            final isSelected = s == currentSpeed;
            return ListTile(
              title: Text('${s}x ${s == 1.0 ? "(Chuẩn)" : ""}', style: TextStyle(color: isSelected ? AppColors.accentCyan : Colors.white)),
              trailing: isSelected ? const Icon(Icons.check, color: AppColors.accentCyan) : null,
              onTap: () {
                controller.setSpeed(s);
                Navigator.of(ctx).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showSleepTimerPicker(BuildContext context) {
    final options = [
      {'label': 'Tắt hẹn giờ', 'min': 0},
      {'label': '15 phút', 'min': 15},
      {'label': '30 phút', 'min': 30},
      {'label': '45 phút', 'min': 45},
      {'label': '60 phút (1 giờ)', 'min': 60},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((opt) {
            final min = opt['min'] as int;
            return ListTile(
              title: Text(opt['label'] as String, style: const TextStyle(color: Colors.white)),
              onTap: () {
                _setSleepTimer(min);
                Navigator.of(ctx).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showEqPicker(BuildContext context) {
    final presets = ['Phẳng (Flat)', 'Bass Booster (Tăng âm trầm)', 'Vocal Booster (Tôn giọng ca)', 'Acoustic / Cổ điển', 'Electronic / Dance'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: presets.map((preset) {
            return ListTile(
              title: Text(preset, style: const TextStyle(color: Colors.white)),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã kích hoạt chế độ EQ: $preset'), duration: const Duration(seconds: 2)),
                );
                Navigator.of(ctx).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
