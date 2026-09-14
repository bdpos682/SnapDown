import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../controller/global_playback_controller.dart';
import '../controller/playback_state.dart';

enum VideoAspectRatioMode {
  fit, // Box fit contain
  fill, // Box fit cover (Zoom to fill screen)
  sixteenNine, // 16:9
  fourThree, // 4:3
}

class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key});

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> with SingleTickerProviderStateMixin {
  bool _controlsVisible = true;
  Timer? _hideTimer;
  bool _isLandscape = false;
  bool _isLocked = false;

  // Double tap seek indicators
  bool _showRewindIndicator = false;
  bool _showForwardIndicator = false;
  Timer? _seekIndicatorTimer;

  // Gesture HUD (Volume & Brightness)
  double _volume = 1.0;
  double _brightness = 0.5;
  bool _showHud = false;
  bool _isHudVolume = true; // true: volume, false: brightness
  Timer? _hudTimer;

  // Video aspect ratio
  VideoAspectRatioMode _aspectRatioMode = VideoAspectRatioMode.fit;

  // Sleep Timer
  Timer? _sleepTimer;
  String? _sleepTimerLabel;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_isLocked) return;
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    if (_isLocked) {
      setState(() => _controlsVisible = !_controlsVisible);
      if (_controlsVisible) _startHideTimer();
      return;
    }

    setState(() {
      _controlsVisible = !_controlsVisible;
      if (_controlsVisible) _startHideTimer();
    });
  }

  void _toggleOrientation() {
    HapticFeedback.selectionClick();
    setState(() => _isLandscape = !_isLandscape);
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _handleDoubleTap(TapDownDetails details, BoxConstraints constraints) {
    if (_isLocked) return;
    final screenWidth = constraints.maxWidth;
    final tapX = details.localPosition.dx;
    final controller = ref.read(playbackControllerProvider.notifier);

    HapticFeedback.mediumImpact();

    if (tapX < screenWidth / 2) {
      // Tua lui 10s
      controller.seekRelative(const Duration(seconds: -10));
      setState(() {
        _showRewindIndicator = true;
        _showForwardIndicator = false;
      });
    } else {
      // Tua toi 10s
      controller.seekRelative(const Duration(seconds: 10));
      setState(() {
        _showForwardIndicator = true;
        _showRewindIndicator = false;
      });
    }

    _seekIndicatorTimer?.cancel();
    _seekIndicatorTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _showRewindIndicator = false;
          _showForwardIndicator = false;
        });
      }
    });

    _startHideTimer();
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_isLocked) return;
    final screenWidth = constraints.maxWidth;
    final startX = details.globalPosition.dx;
    final deltaY = details.primaryDelta ?? 0;
    final sensitivity = 0.005;

    final controller = ref.read(playbackControllerProvider.notifier);
    final videoController = controller.videoController;

    if (startX < screenWidth / 2) {
      // Left side: Brightness
      setState(() {
        _isHudVolume = false;
        _brightness = (_brightness - (deltaY * sensitivity)).clamp(0.05, 1.0);
        _showHud = true;
      });
    } else {
      // Right side: Volume
      final newVol = (_volume - (deltaY * sensitivity)).clamp(0.0, 1.0);
      videoController?.setVolume(newVol);
      setState(() {
        _isHudVolume = true;
        _volume = newVol;
        _showHud = true;
      });
    }

    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showHud = false);
    });
  }

  void _setSleepTimer(Duration? duration, String label) {
    _sleepTimer?.cancel();
    if (duration == null) {
      setState(() => _sleepTimerLabel = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã hủy hẹn giờ tắt video.')),
      );
      return;
    }

    setState(() => _sleepTimerLabel = label);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã đặt hẹn giờ tắt: $label')),
    );

    _sleepTimer = Timer(duration, () {
      ref.read(playbackControllerProvider.notifier).togglePlayPause();
      if (mounted) {
        setState(() => _sleepTimerLabel = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hẹn giờ: Đã tự động tạm dừng video.')),
        );
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    _hudTimer?.cancel();
    _sleepTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);
    final videoController = controller.videoController;

    final durMs = playback.duration.inMilliseconds.toDouble();
    final posMs = playback.position.inMilliseconds.toDouble();
    final clampedPos = durMs > 0 ? posMs.clamp(0.0, durMs) : 0.0;
    final bufMs = playback.bufferedPosition.inMilliseconds.toDouble();
    final clampedBuf = durMs > 0 ? bufMs.clamp(0.0, durMs) : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTap: _toggleControls,
            onDoubleTapDown: (details) => _handleDoubleTap(details, constraints),
            onVerticalDragUpdate: (details) => _handleVerticalDragUpdate(details, constraints),
            behavior: HitTestBehavior.opaque,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. VIDEO SURFACE WITH ASPECT RATIO CONTROLS
                if (playback.isAudioOnly)
                  _buildAudioOnlySurface(playback)
                else if (videoController != null && videoController.value.isInitialized)
                  _buildVideoSurface(videoController)
                else
                  const Center(
                    child: CircularProgressIndicator(color: AppColors.accentCyan),
                  ),

                // 2. VIRTUAL BRIGHTNESS FILTER
                if (_brightness < 1.0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.black.withAlpha(((1.0 - _brightness) * 180).toInt()),
                      ),
                    ),
                  ),

                // 3. DOUBLE TAP SEEK ANIMATION OVERLAYS
                if (_showRewindIndicator)
                  Positioned(
                    left: 40,
                    child: _buildSeekRippleIndicator(isForward: false),
                  ),
                if (_showForwardIndicator)
                  Positioned(
                    right: 40,
                    child: _buildSeekRippleIndicator(isForward: true),
                  ),

                // 4. VOLUME / BRIGHTNESS HUD POPUP
                if (_showHud)
                  Positioned(
                    top: 80,
                    child: _buildGestureHud(),
                  ),

                // 5. SCREEN LOCK TOGGLE FLOATING PILL (WHEN LOCKED)
                if (_isLocked)
                  Positioned(
                    top: 40,
                    left: 20,
                    child: AnimatedOpacity(
                      opacity: _controlsVisible ? 1.0 : 0.3,
                      duration: const Duration(milliseconds: 200),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          setState(() {
                            _isLocked = false;
                            _controlsVisible = true;
                          });
                          _startHideTimer();
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(200),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.accentAmber, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.lock_rounded, color: AppColors.accentAmber, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Đang khóa • Chạm để mở',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // 6. MAIN OVERLAY CONTROLS
                if (!_isLocked)
                  AnimatedOpacity(
                    opacity: _controlsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: IgnorePointer(
                      ignoring: !_controlsVisible,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withAlpha(200),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withAlpha(220),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.25, 0.7, 1.0],
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Top Bar
                            _buildTopBar(context, playback, controller),

                            // Center Controls (Previous, Rewind, Play/Pause, Forward, Next)
                            _buildCenterControls(playback, controller),

                            // Bottom Bar (Timeline scrub & Action tools)
                            _buildBottomBar(context, playback, controller, clampedPos, durMs, clampedBuf),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoSurface(VideoPlayerController videoController) {
    switch (_aspectRatioMode) {
      case VideoAspectRatioMode.fit:
        return Center(
          child: AspectRatio(
            aspectRatio: videoController.value.aspectRatio,
            child: VideoPlayer(videoController),
          ),
        );
      case VideoAspectRatioMode.fill:
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: videoController.value.size.width,
              height: videoController.value.size.height,
              child: VideoPlayer(videoController),
            ),
          ),
        );
      case VideoAspectRatioMode.sixteenNine:
        return Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: VideoPlayer(videoController),
          ),
        );
      case VideoAspectRatioMode.fourThree:
        return Center(
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: VideoPlayer(videoController),
          ),
        );
    }
  }

  Widget _buildSeekRippleIndicator({required bool isForward}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(160),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withAlpha(50)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isForward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            isForward ? '+10 giây' : '-10 giây',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildGestureHud() {
    final value = _isHudVolume ? _volume : _brightness;
    final percent = (value * 100).toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(200),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isHudVolume
                ? (_volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded)
                : Icons.brightness_6_rounded,
            color: _isHudVolume ? AppColors.accentCyan : AppColors.accentAmber,
            size: 20,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: Colors.white.withAlpha(40),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isHudVolume ? AppColors.accentCyan : AppColors.accentAmber,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$percent%',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    PlaybackStateModel playback,
    GlobalPlaybackController controller,
  ) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 34),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playback.title.isNotEmpty ? playback.title : 'Đang phát video',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (playback.artist.isNotEmpty)
                    Text(
                      playback.artist,
                      style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Lock screen button
            IconButton(
              icon: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 22),
              tooltip: 'Khóa màn hình (Tránh chạm nhầm)',
              onPressed: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  _isLocked = true;
                  _controlsVisible = true;
                });
                _startHideTimer();
              },
            ),
            // Audio-Only Mode Toggle Button
            IconButton(
              icon: Icon(
                playback.isAudioOnly ? Icons.headphones_rounded : Icons.headphones_outlined,
                color: playback.isAudioOnly ? AppColors.accentAmber : Colors.white,
                size: 22,
              ),
              tooltip: 'Chế độ chỉ nghe âm thanh (Tiết kiệm pin)',
              onPressed: () {
                controller.toggleAudioOnly();
                _startHideTimer();
              },
            ),
            // YouTube Premium Settings Button (Gear icon)
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 22),
              tooltip: 'Cài đặt phát cao cấp',
              onPressed: () {
                _showPremiumSettingsSheet(context, playback, controller);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls(
    PlaybackStateModel playback,
    GlobalPlaybackController controller,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous video in playlist
        if (playback.queue.length > 1) ...[
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 34),
            tooltip: 'Video trước',
            onPressed: () {
              controller.previous();
              _startHideTimer();
            },
          ),
          const SizedBox(width: AppSpacing.s16),
        ],

        // Rewind 10s
        IconButton(
          icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 40),
          tooltip: 'Lùi 10s',
          onPressed: () {
            controller.seekRelative(const Duration(seconds: -10));
            _startHideTimer();
          },
        ),
        const SizedBox(width: AppSpacing.s24),

        // Big Play/Pause Button
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(40),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(80), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(80),
                blurRadius: 16,
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              playback.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 42,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              controller.togglePlayPause();
              _startHideTimer();
            },
          ),
        ),
        const SizedBox(width: AppSpacing.s24),

        // Forward 10s
        IconButton(
          icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 40),
          tooltip: 'Tới 10s',
          onPressed: () {
            controller.seekRelative(const Duration(seconds: 10));
            _startHideTimer();
          },
        ),

        // Next video in playlist
        if (playback.queue.length > 1) ...[
          const SizedBox(width: AppSpacing.s16),
          IconButton(
            icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 34),
            tooltip: 'Video kế tiếp',
            onPressed: () {
              controller.next();
              _startHideTimer();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    PlaybackStateModel playback,
    GlobalPlaybackController controller,
    double posMs,
    double durMs,
    double bufMs,
  ) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Custom Scrub Bar with Buffer Support
            Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Buffer track
                if (durMs > 0)
                  Positioned(
                    left: 12,
                    right: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: durMs > 0 ? (bufMs / durMs).clamp(0.0, 1.0) : 0.0,
                        minHeight: 3,
                        backgroundColor: Colors.white.withAlpha(30),
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withAlpha(90)),
                      ),
                    ),
                  ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 3,
                    activeTrackColor: AppColors.accentCyan,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: AppColors.accentCyan,
                    overlayColor: AppColors.accentCyan.withAlpha(50),
                  ),
                  child: Slider(
                    value: posMs,
                    min: 0.0,
                    max: durMs > 0 ? durMs : 1.0,
                    onChanged: (val) {
                      controller.seek(Duration(milliseconds: val.toInt()));
                      _startHideTimer();
                    },
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      _formatDuration(playback.position),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      ' / ${_formatDuration(playback.duration)}',
                      style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 13),
                    ),
                    if (_sleepTimerLabel != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentAmber.withAlpha(40),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined, color: AppColors.accentAmber, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              _sleepTimerLabel!,
                              style: const TextStyle(color: AppColors.accentAmber, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    // Aspect ratio cycling
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _aspectRatioMode = switch (_aspectRatioMode) {
                            VideoAspectRatioMode.fit => VideoAspectRatioMode.fill,
                            VideoAspectRatioMode.fill => VideoAspectRatioMode.sixteenNine,
                            VideoAspectRatioMode.sixteenNine => VideoAspectRatioMode.fourThree,
                            VideoAspectRatioMode.fourThree => VideoAspectRatioMode.fit,
                          };
                        });
                        _startHideTimer();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          switch (_aspectRatioMode) {
                            VideoAspectRatioMode.fit => 'VỪA VẶN',
                            VideoAspectRatioMode.fill => 'LẤP ĐẦY',
                            VideoAspectRatioMode.sixteenNine => '16:9',
                            VideoAspectRatioMode.fourThree => '4:3',
                          },
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // PiP Button
                    IconButton(
                      icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white, size: 22),
                      tooltip: 'Hình trong hình (PiP)',
                      onPressed: () {
                        controller.enterPip();
                      },
                    ),
                    // Fullscreen Button
                    IconButton(
                      icon: Icon(
                        _isLandscape ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      onPressed: _toggleOrientation,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPremiumSettingsSheet(
    BuildContext context,
    PlaybackStateModel playback,
    GlobalPlaybackController controller,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E222B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cài đặt Video Player Premium',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),

                // Speed Selector
                ListTile(
                  leading: const Icon(Icons.speed_rounded, color: AppColors.accentCyan),
                  title: const Text('Tốc độ phát', style: TextStyle(color: Colors.white)),
                  trailing: Text(
                    '${playback.speed}x',
                    style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showSpeedPicker(context, controller, playback.speed);
                  },
                ),

                // Sleep timer
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: AppColors.accentAmber),
                  title: const Text('Hẹn giờ tắt', style: TextStyle(color: Colors.white)),
                  trailing: Text(
                    _sleepTimerLabel ?? 'Tắt',
                    style: TextStyle(
                      color: _sleepTimerLabel != null ? AppColors.accentAmber : Colors.white.withAlpha(150),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showSleepTimerPicker(context);
                  },
                ),

                // Background audio mode
                SwitchListTile(
                  secondary: const Icon(Icons.headphones_rounded, color: AppColors.accentGreen),
                  title: const Text('Nghe khi khóa màn hình', style: TextStyle(color: Colors.white)),
                  subtitle: const Text(
                    'Tắt màn hình vẫn tiếp tục phát âm thanh',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  value: playback.isAudioOnly,
                  activeTrackColor: AppColors.accentGreen,
                  onChanged: (val) {
                    controller.toggleAudioOnly();
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSpeedPicker(BuildContext context, GlobalPlaybackController controller, double currentSpeed) {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E222B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: speeds.map((s) {
            final isSelected = (s == currentSpeed);
            return ListTile(
              title: Text(
                s == 1.0 ? '1.0x (Chuẩn)' : '${s}x',
                style: TextStyle(
                  color: isSelected ? AppColors.accentCyan : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isSelected ? const Icon(Icons.check_rounded, color: AppColors.accentCyan) : null,
              onTap: () {
                controller.setSpeed(s);
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showSleepTimerPicker(BuildContext context) {
    final options = [
      {'label': 'Tắt hẹn giờ', 'duration': null},
      {'label': '15 phút', 'duration': const Duration(minutes: 15)},
      {'label': '30 phút', 'duration': const Duration(minutes: 30)},
      {'label': '45 phút', 'duration': const Duration(minutes: 45)},
      {'label': '60 phút', 'duration': const Duration(minutes: 60)},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E222B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: options.map((opt) {
            final label = opt['label'] as String;
            final dur = opt['duration'] as Duration?;
            final isSelected = (_sleepTimerLabel == label) || (dur == null && _sleepTimerLabel == null);
            return ListTile(
              title: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.accentAmber : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isSelected ? const Icon(Icons.check_rounded, color: AppColors.accentAmber) : null,
              onTap: () {
                _setSleepTimer(dur, label);
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAudioOnlySurface(PlaybackStateModel playback) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentAmber.withAlpha(40),
              borderRadius: AppRadius.radiusPill,
              border: Border.all(color: AppColors.accentAmber.withAlpha(120)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.headphones_rounded, color: AppColors.accentAmber, size: 16),
                SizedBox(width: 6),
                Text(
                  'CHẾ ĐỘ CHỈ NGHE ÂM THANH (Tiết kiệm pin)',
                  style: TextStyle(
                    color: AppColors.accentAmber,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s24),
          if (playback.thumbnailPath != null && File(playback.thumbnailPath!).existsSync())
            ClipRRect(
              borderRadius: AppRadius.radiusLg,
              child: Image.file(
                File(playback.thumbnailPath!),
                width: 220,
                height: 124,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 220,
              height: 124,
              decoration: BoxDecoration(
                color: AppColors.darkElevated,
                borderRadius: AppRadius.radiusLg,
              ),
              child: const Icon(Icons.music_video_rounded, color: AppColors.accentCyan, size: 48),
            ),
          const SizedBox(height: AppSpacing.s16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              playback.title,
              style: AppTypography.bodyMedium.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

