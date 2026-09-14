import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings_vi.dart';
import '../../../core/database/repositories/media_repository.dart';
import '../../../core/utils/html_utils.dart';
import '../controller/global_playback_controller.dart';
import '../controller/playback_state.dart';

class MusicPlayerScreen extends ConsumerStatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  ConsumerState<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends ConsumerState<MusicPlayerScreen>
    with SingleTickerProviderStateMixin {
  final MediaRepository _repository = MediaRepository();

  double _volume = 1.0;
  double? _dragPositionMs;
  Timer? _sleepTimer;
  int? _sleepTimerRemainingMinutes;

  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(playbackControllerProvider).hasMedia && mounted) {
        Navigator.of(context).maybePop();
        return;
      }
      final controller = ref.read(playbackControllerProvider.notifier);
      setState(() {
        _volume = controller.currentVolume;
      });
      if (ref.read(playbackControllerProvider).isPlaying) {
        _rotationController.repeat();
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _sleepTimer?.cancel();
    super.dispose();
  }

  void _setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (minutes <= 0) {
      setState(() => _sleepTimerRemainingMinutes = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tắt hẹn giờ tắt nhạc'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _sleepTimerRemainingMinutes = minutes);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sẽ tự động dừng phát sau $minutes phút'),
        duration: const Duration(seconds: 2),
      ),
    );

    _sleepTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final rem = (_sleepTimerRemainingMinutes ?? 0) - 1;
      if (rem <= 0) {
        timer.cancel();
        ref.read(playbackControllerProvider.notifier).pause();
        setState(() => _sleepTimerRemainingMinutes = null);
      } else {
        setState(() => _sleepTimerRemainingMinutes = rem);
      }
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PlaybackStateModel>(playbackControllerProvider, (previous, next) {
      if (!next.hasMedia && mounted) {
        Navigator.of(context).maybePop();
      }
    });

    final playback = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tự động dừng/chạy đĩa than theo trạng thái phát để tiết kiệm CPU/pin
    if (playback.isPlaying && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!playback.isPlaying && _rotationController.isAnimating) {
      _rotationController.stop();
    }

    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final accent = isDark ? AppColors.accentCyan : AppColors.accentBlue;

    final currentPosMs = _dragPositionMs ?? playback.position.inMilliseconds.toDouble();
    final totalDurationMs = math.max(playback.duration.inMilliseconds.toDouble(), 1.0);
    final clampedPosMs = currentPosMs.clamp(0.0, totalDurationMs);

    final title = HtmlUtils.unescape(playback.title.isNotEmpty ? playback.title : 'Chưa chọn bài hát');
    final artist = HtmlUtils.unescape(playback.artist.isNotEmpty ? playback.artist : AppStringsVi.appName);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: textPrimary, size: 32),
          tooltip: 'Thu nhỏ',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              AppStringsVi.nowPlaying.toUpperCase(),
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              artist,
              style: TextStyle(
                color: textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _sleepTimerRemainingMinutes != null ? Icons.alarm_on_rounded : Icons.alarm_rounded,
              color: _sleepTimerRemainingMinutes != null ? accent : textPrimary,
            ),
            tooltip: 'Hẹn giờ tắt nhạc',
            onPressed: () => _showSleepTimerDialog(context),
          ),
          IconButton(
            icon: Icon(Icons.queue_music_rounded, color: textPrimary),
            tooltip: 'Danh sách chờ phát',
            onPressed: () => _showQueueBottomSheet(context, playback),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Đĩa than Vinyl có ảnh bìa & viền ánh sáng
              Center(
                child: AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationController.value * 2 * math.pi,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF111319),
                      border: Border.all(
                        color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(20),
                        width: 5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withAlpha(isDark ? 60 : 35),
                          blurRadius: 36,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: ClipOval(
                        child: SizedBox(
                          width: 140,
                          height: 140,
                          child: _buildArtwork(playback),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Thông tin bài hát & Nút thích
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (playback.localItem != null)
                    IconButton(
                      icon: Icon(
                        playback.localItem!.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: playback.localItem!.isFavorite ? AppColors.accentRed : textSecondary,
                        size: 28,
                      ),
                      tooltip: 'Thích bài hát',
                      onPressed: () async {
                        HapticFeedback.selectionClick();
                        await _repository.toggleFavorite(playback.localItem!.id);
                      },
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Thanh kéo tua thời gian mượt mà
              Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: accent,
                      inactiveTrackColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      thumbColor: accent,
                      overlayColor: accent.withAlpha(40),
                    ),
                    child: Slider(
                      value: clampedPosMs,
                      min: 0.0,
                      max: totalDurationMs,
                      onChanged: (val) {
                        setState(() => _dragPositionMs = val);
                      },
                      onChangeEnd: (val) {
                        controller.seekTo(Duration(milliseconds: val.toInt()));
                        setState(() => _dragPositionMs = null);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(Duration(milliseconds: clampedPosMs.toInt())),
                          style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _formatDuration(playback.duration),
                          style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Cụm nút điều khiển chính
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Nút Trộn bài
                  IconButton(
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: playback.isShuffle ? accent : textSecondary,
                      size: 26,
                    ),
                    tooltip: playback.isShuffle ? AppStringsVi.shuffleOn : AppStringsVi.shuffleOff,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      controller.toggleShuffle();
                    },
                  ),

                  // Nút Bài trước
                  IconButton(
                    icon: Icon(Icons.skip_previous_rounded, color: textPrimary, size: 36),
                    tooltip: AppStringsVi.prevTrack,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      controller.skipToPrevious();
                    },
                  ),

                  // Nút Bật / Tạm dừng (Lớn, Gradient nổi bật)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      controller.togglePlayPause();
                    },
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withAlpha(120),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        playback.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 38,
                      ),
                    ),
                  ),

                  // Nút Bài kế tiếp
                  IconButton(
                    icon: Icon(Icons.skip_next_rounded, color: textPrimary, size: 36),
                    tooltip: AppStringsVi.nextTrack,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      controller.skipToNext();
                    },
                  ),

                  // Nút Lặp lại
                  IconButton(
                    icon: Icon(
                      playback.repeatMode == RepeatMode.one
                          ? Icons.repeat_one_rounded
                          : playback.repeatMode == RepeatMode.all
                              ? Icons.repeat_rounded
                              : Icons.repeat_rounded,
                      color: playback.repeatMode != RepeatMode.off ? accent : textSecondary,
                      size: 26,
                    ),
                    tooltip: playback.repeatMode == RepeatMode.one
                        ? AppStringsVi.repeatOne
                        : playback.repeatMode == RepeatMode.all
                            ? AppStringsVi.repeatAll
                            : AppStringsVi.repeatOff,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      controller.cycleRepeatMode();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Tốc độ phát & Âm lượng
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    icon: Icon(Icons.speed_rounded, color: accent, size: 18),
                    label: Text(
                      'Tốc độ ${playback.speed}x',
                      style: TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => _showSpeedSelectorDialog(context, playback, controller),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.volume_down_rounded, color: textSecondary, size: 18),
                  SizedBox(
                    width: 110,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2.5,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                        activeTrackColor: textSecondary,
                        inactiveTrackColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        thumbColor: textPrimary,
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
                  Icon(Icons.volume_up_rounded, color: textSecondary, size: 18),
                ],
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  void _showSleepTimerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hẹn giờ tự động tắt nhạc',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.timer_off_rounded),
                title: const Text('Tắt hẹn giờ'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setSleepTimer(0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bedtime_rounded),
                title: const Text('Sau 15 phút'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setSleepTimer(15);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bedtime_rounded),
                title: const Text('Sau 30 phút'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setSleepTimer(30);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bedtime_rounded),
                title: const Text('Sau 45 phút'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setSleepTimer(45);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bedtime_rounded),
                title: const Text('Sau 60 phút (1 tiếng)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setSleepTimer(60);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSpeedSelectorDialog(
      BuildContext context, PlaybackStateModel playback, GlobalPlaybackController controller) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Lựa chọn tốc độ phát', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: speeds.map((s) {
                  final isSel = (playback.speed - s).abs() < 0.05;
                  return ChoiceChip(
                    label: Text('${s}x'),
                    selected: isSel,
                    onSelected: (_) {
                      controller.setSpeed(s);
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQueueBottomSheet(BuildContext context, PlaybackStateModel playback) {
    final queue = playback.queue;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Danh sách đang chờ phát',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (queue.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Chỉ có 1 bài hát đang phát'),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: queue.length,
                    itemBuilder: (context, i) {
                      final item = queue[i];
                      final isCurrent = i == playback.currentIndex;
                      return ListTile(
                        leading: isCurrent
                            ? const Icon(Icons.equalizer_rounded, color: AppColors.accentCyan)
                            : Text('${i + 1}'),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent ? AppColors.accentCyan : null,
                          ),
                        ),
                        subtitle: Text(item.artist, maxLines: 1),
                        onTap: () {
                          ref.read(playbackControllerProvider.notifier).playQueueItem(i);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtwork(dynamic playback) {
    if (playback.thumbnailPath != null && File(playback.thumbnailPath!).existsSync()) {
      return Image.file(
        File(playback.thumbnailPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, error, stack) => _defaultArtwork(),
      );
    }
    if (playback.thumbnailUrl != null && playback.thumbnailUrl!.isNotEmpty) {
      return Image.network(
        playback.thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stack) => _defaultArtwork(),
      );
    }
    return _defaultArtwork();
  }

  Widget _defaultArtwork() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white,
        size: 54,
      ),
    );
  }
}
