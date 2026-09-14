import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings_vi.dart';
import '../../../core/utils/html_utils.dart';
import '../controller/global_playback_controller.dart';
import '../controller/playback_state.dart';

enum VideoAspectRatioMode {
  fit,
  fill,
  sixteenNine,
  fourThree,
}

class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key});

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  bool _controlsVisible = true;
  Timer? _hideTimer;
  bool _isLandscape = false;
  bool _isLocked = false;

  bool _showRewindIndicator = false;
  bool _showForwardIndicator = false;
  Timer? _seekIndicatorTimer;

  double _volume = 1.0;
  double _brightness = 0.5;
  bool _showHud = false;
  bool _isHudVolume = true;
  Timer? _hudTimer;

  VideoAspectRatioMode _aspectRatioMode = VideoAspectRatioMode.fit;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controlsVisible && !_isLocked) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
      if (_controlsVisible) {
        _startHideTimer();
      } else {
        _hideTimer?.cancel();
      }
    });
  }

  void _toggleOrientation() {
    HapticFeedback.selectionClick();
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      setState(() => _isLandscape = false);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      setState(() => _isLandscape = true);
    }
  }

  void _doubleTapSeek(bool isForward) {
    HapticFeedback.lightImpact();
    final controller = ref.read(playbackControllerProvider.notifier);
    if (isForward) {
      controller.seekForward(const Duration(seconds: 10));
      setState(() => _showForwardIndicator = true);
    } else {
      controller.seekBackward(const Duration(seconds: 10));
      setState(() => _showRewindIndicator = true);
    }

    _seekIndicatorTimer?.cancel();
    _seekIndicatorTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() {
          _showRewindIndicator = false;
          _showForwardIndicator = false;
        });
      }
    });
  }

  void _showGestureHud({required bool isVolume, required double value}) {
    setState(() {
      _showHud = true;
      _isHudVolume = isVolume;
    });
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showHud = false);
    });
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    _hudTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);
    final videoCtrl = controller.videoController;

    final title = HtmlUtils.unescape(playback.title.isNotEmpty ? playback.title : 'Đang xem video');

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: !_isLandscape,
        bottom: !_isLandscape,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Trình hiển thị video chính
            if (videoCtrl != null && videoCtrl.value.isInitialized)
              Center(child: _buildVideoView(videoCtrl))
            else
              const Center(
                child: CircularProgressIndicator(color: AppColors.accentCyan),
              ),

            // Lớp cử chỉ vuốt toàn màn hình (Vuốt trái: Độ sáng, Vuốt phải: Âm lượng)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                onDoubleTapDown: (details) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  if (details.globalPosition.dx < screenWidth / 2) {
                    _doubleTapSeek(false);
                  } else {
                    _doubleTapSeek(true);
                  }
                },
                onVerticalDragUpdate: (details) {
                  if (_isLocked) return;
                  final screenWidth = MediaQuery.of(context).size.width;
                  final delta = -details.primaryDelta! / 200;

                  if (details.globalPosition.dx > screenWidth / 2) {
                    // Cột phải: Âm lượng
                    final newVol = (_volume + delta).clamp(0.0, 1.0);
                    setState(() => _volume = newVol);
                    controller.setVolume(newVol);
                    _showGestureHud(isVolume: true, value: newVol);
                  } else {
                    // Cột trái: Độ sáng
                    final newBrt = (_brightness + delta).clamp(0.0, 1.0);
                    setState(() => _brightness = newBrt);
                    _showGestureHud(isVolume: false, value: newBrt);
                  }
                },
              ),
            ),

            // Hoạt họa tua nhanh 10s (Bên trái)
            if (_showRewindIndicator)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 120,
                  height: 120,
                  margin: const EdgeInsets.only(left: 30),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withAlpha(140),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.replay_10_rounded, color: Colors.white, size: 42),
                      SizedBox(height: 4),
                      Text('Lùi 10s', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
              ),

            // Hoạt họa tua nhanh 10s (Bên phải)
            if (_showForwardIndicator)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 120,
                  height: 120,
                  margin: const EdgeInsets.only(right: 30),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withAlpha(140),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.forward_10_rounded, color: Colors.white, size: 42),
                      SizedBox(height: 4),
                      Text('Tiến 10s', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
              ),

            // Thanh HUD hiển thị Âm lượng / Độ sáng
            if (_showHud)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(190),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isHudVolume
                            ? (_volume == 0
                                ? Icons.volume_off_rounded
                                : _volume > 0.5
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_down_rounded)
                            : Icons.brightness_6_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 100,
                        child: LinearProgressIndicator(
                          value: _isHudVolume ? _volume : _brightness,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${((_isHudVolume ? _volume : _brightness) * 100).round()}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

            // Lớp Điều khiển (Controls Overlay)
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Container(
                  color: Colors.black.withAlpha(100),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Thanh Tiêu đề Trên cùng
                      _buildTopBar(context, title, controller),

                      // Nút Play/Pause ở chính giữa
                      if (!_isLocked)
                        IconButton(
                          icon: Icon(
                            playback.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 68,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            controller.togglePlayPause();
                            _startHideTimer();
                          },
                        )
                      else
                        const SizedBox.shrink(),

                      // Thanh Dưới cùng (Tiến trình + Tùy chọn)
                      _buildBottomBar(playback, controller),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoView(VideoPlayerController ctrl) {
    switch (_aspectRatioMode) {
      case VideoAspectRatioMode.fill:
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: ctrl.value.size.width,
              height: ctrl.value.size.height,
              child: VideoPlayer(ctrl),
            ),
          ),
        );
      case VideoAspectRatioMode.sixteenNine:
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: VideoPlayer(ctrl),
        );
      case VideoAspectRatioMode.fourThree:
        return AspectRatio(
          aspectRatio: 4 / 3,
          child: VideoPlayer(ctrl),
        );
      case VideoAspectRatioMode.fit:
        return AspectRatio(
          aspectRatio: ctrl.value.aspectRatio,
          child: VideoPlayer(ctrl),
        );
    }
  }

  Widget _buildTopBar(BuildContext context, String title, GlobalPlaybackController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
            tooltip: 'Quay lại',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: Icon(_isLocked ? Icons.lock_rounded : Icons.lock_open_rounded, color: Colors.white),
            tooltip: _isLocked ? 'Đã khóa màn hình' : 'Khóa cảm ứng',
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _isLocked = !_isLocked);
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white),
            tooltip: AppStringsVi.pipMode,
            onPressed: () => controller.enterPipMode(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(PlaybackStateModel playback, GlobalPlaybackController controller) {
    if (_isLocked) return const SizedBox.shrink();

    final posMs = playback.position.inMilliseconds.toDouble();
    final durMs = math.max(playback.duration.inMilliseconds.toDouble(), 1.0);
    final clampedPos = posMs.clamp(0.0, durMs);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Slider tiến trình
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: AppColors.accentCyan,
              inactiveTrackColor: Colors.white30,
              thumbColor: AppColors.accentCyan,
            ),
            child: Slider(
              value: clampedPos,
              min: 0.0,
              max: durMs,
              onChanged: (val) {
                _startHideTimer();
              },
              onChangeEnd: (val) {
                controller.seekTo(Duration(milliseconds: val.toInt()));
                _startHideTimer();
              },
            ),
          ),

          // Thời gian + Các nút chức năng dưới
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatDuration(playback.position)} / ${_formatDuration(playback.duration)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  // Tỷ lệ khung hình
                  IconButton(
                    icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white, size: 22),
                    tooltip: 'Đổi tỷ lệ khung hình',
                    onPressed: _cycleAspectRatio,
                  ),
                  // Xoay toàn màn hình
                  IconButton(
                    icon: Icon(
                      _isLandscape ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    tooltip: _isLandscape ? 'Thu nhỏ dọc' : 'Toàn màn hình ngang',
                    onPressed: _toggleOrientation,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _cycleAspectRatio() {
    HapticFeedback.selectionClick();
    setState(() {
      switch (_aspectRatioMode) {
        case VideoAspectRatioMode.fit:
          _aspectRatioMode = VideoAspectRatioMode.fill;
          _showToast('Lấp đầy màn hình');
          break;
        case VideoAspectRatioMode.fill:
          _aspectRatioMode = VideoAspectRatioMode.sixteenNine;
          _showToast('Chuẩn 16:9');
          break;
        case VideoAspectRatioMode.sixteenNine:
          _aspectRatioMode = VideoAspectRatioMode.fourThree;
          _showToast('Chuẩn 4:3');
          break;
        case VideoAspectRatioMode.fourThree:
          _aspectRatioMode = VideoAspectRatioMode.fit;
          _showToast('Vừa vặn nguyên bản');
          break;
      }
    });
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
