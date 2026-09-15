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
import '../../library/presentation/widgets/add_to_playlist_sheet.dart';
import '../../../core/theme/theme_provider.dart';
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
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF0C0F17),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

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

    final themeMode = ref.read(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

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
    ref.listen<bool>(playbackControllerProvider.select((s) => s.hasMedia), (previous, hasMedia) {
      if (!hasMedia && mounted) {
        Navigator.of(context).maybePop();
      }
    });

    final playback = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);

    // Tự động dừng/chạy đĩa than theo trạng thái phát để tiết kiệm CPU/pin
    if (playback.isPlaying && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!playback.isPlaying && _rotationController.isAnimating) {
      _rotationController.stop();
    }

    // Luôn luôn áp dụng giao diện tối Midnight Obsidian cho màn hình đang phát dù ở bất kỳ theme nào
    const darkBg = Color(0xFF0C0F17);
    const textPrimary = AppColors.darkTextPrimary;
    const textSecondary = AppColors.darkTextSecondary;
    const accent = AppColors.accentCyan;

    final currentPosMs = _dragPositionMs ?? playback.position.inMilliseconds.toDouble();
    final totalDurationMs = math.max(playback.duration.inMilliseconds.toDouble(), 1.0);
    final clampedPosMs = currentPosMs.clamp(0.0, totalDurationMs);

    final title = HtmlUtils.unescape(playback.title.isNotEmpty ? playback.title : 'Chưa chọn bài hát');
    final artist = HtmlUtils.unescape(playback.artist.isNotEmpty ? playback.artist : AppStringsVi.appName);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: darkBg,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: darkBg,
        appBar: AppBar(
          backgroundColor: darkBg,
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: darkBg,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: textPrimary, size: 32),
            tooltip: 'Thu nhỏ',
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            children: [
              Text(
                AppStringsVi.nowPlaying.toUpperCase(),
                style: const TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                artist,
                style: const TextStyle(
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
              icon: const Icon(Icons.queue_music_rounded, color: textPrimary),
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
                        color: Colors.white.withAlpha(25),
                        width: 5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withAlpha(60),
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

              // Thông tin bài hát & Nút thích / Nút thêm playlist
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
                          style: const TextStyle(
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
                          style: const TextStyle(
                            color: textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (playback.localItem != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.playlist_add_rounded,
                            color: textSecondary,
                            size: 26,
                          ),
                          tooltip: 'Thêm vào danh sách phát',
                          onPressed: () => AddToPlaylistSheet.show(context, playback.localItem!),
                        ),
                        IconButton(
                          icon: Icon(
                            playback.localItem!.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: playback.localItem!.isFavorite ? AppColors.accentRed : textSecondary,
                            size: 26,
                          ),
                          tooltip: 'Thích bài hát',
                          onPressed: () async {
                            HapticFeedback.selectionClick();
                            await _repository.toggleFavorite(playback.localItem!.id);
                          },
                        ),
                      ],
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
                      inactiveTrackColor: AppColors.darkBorder,
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
                      playback.repeatMode == PlaybackRepeatMode.one
                          ? Icons.repeat_one_rounded
                          : playback.repeatMode == PlaybackRepeatMode.all
                              ? Icons.repeat_rounded
                              : Icons.repeat_rounded,
                      color: playback.repeatMode != PlaybackRepeatMode.off ? accent : textSecondary,
                      size: 26,
                    ),
                    tooltip: playback.repeatMode == PlaybackRepeatMode.one
                        ? AppStringsVi.repeatOne
                        : playback.repeatMode == PlaybackRepeatMode.all
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
                        inactiveTrackColor: AppColors.darkBorder,
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
    ),
    );
  }

  void _showSleepTimerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141824),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withAlpha(25), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(140),
              blurRadius: 30,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(45),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Hẹn giờ tự động tắt nhạc',
                  style: TextStyle(color: Colors.white, fontSize: 17.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                _buildSleepTimerTile(ctx, 'Tắt hẹn giờ', Icons.timer_off_rounded, 0),
                _buildSleepTimerTile(ctx, 'Sau 15 phút', Icons.bedtime_rounded, 15),
                _buildSleepTimerTile(ctx, 'Sau 30 phút', Icons.bedtime_rounded, 30),
                _buildSleepTimerTile(ctx, 'Sau 45 phút', Icons.bedtime_rounded, 45),
                _buildSleepTimerTile(ctx, 'Sau 60 phút (1 tiếng)', Icons.bedtime_rounded, 60),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSleepTimerTile(BuildContext ctx, String label, IconData icon, int minutes) {
    final isCurrent = _sleepTimerRemainingMinutes == minutes ||
        (_sleepTimerRemainingMinutes == null && minutes == 0);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.accentCyan.withAlpha(25) : Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? AppColors.accentCyan : Colors.white.withAlpha(12),
          width: isCurrent ? 1.4 : 1.0,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: isCurrent ? AppColors.accentCyan : Colors.white70, size: 22),
        title: Text(
          label,
          style: TextStyle(
            color: isCurrent ? AppColors.accentCyan : Colors.white,
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
        trailing: isCurrent
            ? const Icon(Icons.check_circle_rounded, color: AppColors.accentCyan, size: 20)
            : null,
        onTap: () {
          Navigator.pop(ctx);
          _setSleepTimer(minutes);
        },
      ),
    );
  }

  void _showSpeedSelectorDialog(
      BuildContext context, PlaybackStateModel playback, GlobalPlaybackController controller) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141824),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withAlpha(25), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(140),
              blurRadius: 30,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(45),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Lựa chọn tốc độ phát',
                  style: TextStyle(color: Colors.white, fontSize: 17.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: speeds.map((s) {
                    final isSel = (playback.speed - s).abs() < 0.05;
                    return ChoiceChip(
                      label: Text(
                        '${s}x',
                        style: TextStyle(
                          color: isSel ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: AppColors.accentCyan,
                      backgroundColor: Colors.white.withAlpha(12),
                      side: BorderSide(
                        color: isSel ? AppColors.accentCyan : Colors.white.withAlpha(20),
                      ),
                      onSelected: (_) {
                        controller.setSpeed(s);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQueueBottomSheet(BuildContext context, PlaybackStateModel playback) {
    final queue = playback.queue;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF141824),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: Colors.white.withAlpha(25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(140),
              blurRadius: 30,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thanh gạt
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentCyan.withAlpha(80),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.queue_music_rounded, color: Colors.black, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Danh sách chờ phát',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${queue.length} bản nhạc trong hàng đợi',
                            style: TextStyle(
                              color: Colors.white.withAlpha(160),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(18),
                        ),
                        child: const Center(
                          child: Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white12, height: 1),

              // Danh sách
              if (queue.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.music_off_rounded, size: 48, color: Colors.white38),
                      SizedBox(height: 12),
                      Text(
                        'Chỉ có 1 bài hát đang phát',
                        style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: queue.length,
                    itemBuilder: (context, i) {
                      final item = queue[i];
                      final isCurrent = i == playback.currentIndex;
                      final title = HtmlUtils.unescape(item.title);
                      final artist = HtmlUtils.unescape(item.artist);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppColors.accentCyan.withAlpha(25)
                              : Colors.white.withAlpha(8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent ? AppColors.accentCyan : Colors.white.withAlpha(12),
                            width: isCurrent ? 1.4 : 1.0,
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: item.thumbnailPath != null &&
                                            File(item.thumbnailPath!).existsSync()
                                        ? Image.file(File(item.thumbnailPath!), fit: BoxFit.cover)
                                        : Container(
                                            color: AppColors.accentCyan.withAlpha(40),
                                            child: const Icon(Icons.music_note_rounded,
                                                color: AppColors.accentCyan, size: 20),
                                          ),
                                  ),
                                  if (isCurrent)
                                    Container(
                                      color: Colors.black.withAlpha(130),
                                      child: const Center(
                                        child: Icon(Icons.equalizer_rounded,
                                            color: AppColors.accentCyan, size: 22),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          title: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrent ? AppColors.accentCyan : const Color(0xFFF8FAFC),
                              fontSize: 13.5,
                              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            isCurrent ? '$artist • Đang phát' : artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrent
                                  ? AppColors.accentCyan.withAlpha(210)
                                  : const Color(0xFF94A3B8),
                              fontSize: 11.5,
                              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          trailing: isCurrent
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentCyan.withAlpha(35),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'ĐANG PHÁT',
                                    style: TextStyle(
                                      color: AppColors.accentCyan,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                )
                              : Text(
                                  '#${i + 1}',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(90),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref.read(playbackControllerProvider.notifier).playQueueItem(i);
                            Navigator.pop(ctx);
                          },
                        ),
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
