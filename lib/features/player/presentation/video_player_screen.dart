import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart' hide RepeatMode;
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

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> with SingleTickerProviderStateMixin {
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
    if (_isLocked) {
      setState(() => _controlsVisible = !_controlsVisible);
      return;
    }
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

  void _showSettingsSheet() {
    final playback = ref.read(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF141923),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
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
                  Icon(Icons.tune_rounded, color: AppColors.accentCyan, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Cài đặt phát video',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Tốc độ phát
              const Text(
                'Tốc độ phát:',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                    final isSelected = (playback.speed - speed).abs() < 0.05;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          controller.setSpeed(speed);
                          Navigator.pop(ctx);
                          _showToast('Đã đặt tốc độ: ${speed}x');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.accentCyan : Colors.white.withAlpha(15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? Colors.transparent : Colors.white24,
                            ),
                          ),
                          child: Text(
                            speed == 1.0 ? 'Chuẩn' : '${speed}x',
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),

              // Tỷ lệ khung hình
              const Text(
                'Tỷ lệ khung hình:',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  _buildAspectChip('Vừa vặn', VideoAspectRatioMode.fit, ctx),
                  _buildAspectChip('Lấp đầy', VideoAspectRatioMode.fill, ctx),
                  _buildAspectChip('16:9', VideoAspectRatioMode.sixteenNine, ctx),
                  _buildAspectChip('4:3', VideoAspectRatioMode.fourThree, ctx),
                ],
              ),
              const SizedBox(height: 16),

              // Lặp lại
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  playback.repeatMode == RepeatMode.one
                      ? Icons.repeat_one_rounded
                      : playback.repeatMode == RepeatMode.all
                          ? Icons.repeat_rounded
                          : Icons.repeat_rounded,
                  color: playback.repeatMode != RepeatMode.off ? AppColors.accentCyan : Colors.white60,
                ),
                title: Text(
                  playback.repeatMode == RepeatMode.one
                      ? 'Lặp lại video này: Đang bật'
                      : playback.repeatMode == RepeatMode.all
                          ? 'Lặp lại toàn bộ: Đang bật'
                          : 'Lặp lại: Tắt',
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                ),
                trailing: const Icon(Icons.swap_horiz_rounded, color: Colors.white54),
                onTap: () {
                  controller.cycleRepeatMode();
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAspectChip(String label, VideoAspectRatioMode mode, BuildContext ctx) {
    final isSelected = _aspectRatioMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _aspectRatioMode = mode);
        Navigator.pop(ctx);
        _showToast('Đã chuyển tỷ lệ: $label');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentCyan : Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
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

    // Khi đang trong chế độ PiP của hệ điều hành, ẩn 100% thanh điều khiển để màn hình nhỏ sạch hoàn toàn!
    if (playback.isPipActive) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: videoCtrl != null && videoCtrl.value.isInitialized
              ? VideoPlayer(videoCtrl)
              : const SizedBox.shrink(),
        ),
      );
    }

    final title = HtmlUtils.unescape(playback.title.isNotEmpty ? playback.title : 'Đang xem video');
    final artist = HtmlUtils.unescape(playback.artist.isNotEmpty ? playback.artist : AppStringsVi.appName);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (_isLandscape) {
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          top: !_isLandscape,
          bottom: !_isLandscape,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Trình hiển thị video chính hoặc Màn hình chỉ nghe tiếng
              if (playback.isAudioOnly)
                _buildAudioOnlyScreen(playback, controller)
              else if (videoCtrl != null && videoCtrl.value.isInitialized)
                Center(child: _buildVideoView(videoCtrl))
              else
                const Center(
                  child: CircularProgressIndicator(color: AppColors.accentCyan),
                ),

              // Cử chỉ tương tác chuẩn YouTube Premium
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleControls,
                  // YouTube Premium signature: Giữ chặt để tăng tốc 2x
                  onLongPressStart: (_) {
                    if (!_isLocked && !playback.isAudioOnly) {
                      HapticFeedback.mediumImpact();
                      controller.start2xSpeed();
                    }
                  },
                  onLongPressEnd: (_) {
                    if (playback.is2xSpeedActive) {
                      HapticFeedback.lightImpact();
                      controller.stop2xSpeed();
                    }
                  },
                  // Double tap tua 10 giây 2 bên màn hình
                  onDoubleTapDown: (details) {
                    if (_isLocked) return;
                    final screenWidth = MediaQuery.of(context).size.width;
                    if (details.globalPosition.dx < screenWidth / 2) {
                      _doubleTapSeek(false);
                    } else {
                      _doubleTapSeek(true);
                    }
                  },
                  // Vuốt chỉnh Độ sáng (trái) và Âm lượng (phải)
                  onVerticalDragUpdate: (details) {
                    if (_isLocked || playback.isAudioOnly) return;
                    final screenWidth = MediaQuery.of(context).size.width;
                    final delta = -details.primaryDelta! / 200;

                    if (details.globalPosition.dx > screenWidth / 2) {
                      final newVol = (_volume + delta).clamp(0.0, 1.0);
                      setState(() => _volume = newVol);
                      controller.setVolume(newVol);
                      _showGestureHud(isVolume: true, value: newVol);
                    } else {
                      final newBrt = (_brightness + delta).clamp(0.0, 1.0);
                      setState(() => _brightness = newBrt);
                      _showGestureHud(isVolume: false, value: newBrt);
                    }
                  },
                ),
              ),

              // Huy hiệu 2.0x Tốc độ khi giữ tay (YouTube Premium Gesture)
              if (playback.is2xSpeedActive)
                Positioned(
                  top: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(200),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.accentCyan.withAlpha(120), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentCyan.withAlpha(50),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fast_forward_rounded, color: AppColors.accentCyan, size: 18),
                          SizedBox(width: 8),
                          Text(
                            '2.0x Tốc độ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Hoạt họa tua nhanh 10s bên trái (Gợn sóng YouTube)
              if (_showRewindIndicator)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 110,
                    height: 110,
                    margin: const EdgeInsets.only(left: 36),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withAlpha(150),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.replay_10_rounded, color: Colors.white, size: 40),
                        SizedBox(height: 4),
                        Text('-10 giây', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),

              // Hoạt họa tua nhanh 10s bên phải (Gợn sóng YouTube)
              if (_showForwardIndicator)
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 110,
                    height: 110,
                    margin: const EdgeInsets.only(right: 36),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withAlpha(150),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forward_10_rounded, color: Colors.white, size: 40),
                        SizedBox(height: 4),
                        Text('+10 giây', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),

              // Thanh HUD Âm lượng / Độ sáng ở giữa
              if (_showHud)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(200),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
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
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 110,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _isHudVolume ? _volume : _brightness,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                              minHeight: 5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${((_isHudVolume ? _volume : _brightness) * 100).round()}%',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),

              // Lớp Điều Khiển Chuẩn YouTube Premium (Controls Overlay)
              AnimatedOpacity(
                opacity: _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: Container(
                    color: Colors.black.withAlpha(115),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Thanh Tiêu Đề Trên Cùng
                        _buildTopBar(context, title, artist, playback, controller),

                        // Cụm Điều Khiển Trung Tâm (Tua 10s - Play/Pause - Tua 10s)
                        if (!_isLocked)
                          _buildCenterControls(playback, controller)
                        else
                          // Nút mở khóa khi đang khóa
                          Center(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _isLocked = false);
                                _startHideTimer();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(180),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white30),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock_outline_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text('Chạm để mở khóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // Thanh Tiến Trình & Nút Chức Năng Dưới Cùng
                        _buildBottomBar(playback, controller),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Màn hình giao diện khi ở chế độ "Chỉ nghe âm thanh"
  Widget _buildAudioOnlyScreen(PlaybackStateModel playback, GlobalPlaybackController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(12),
              border: Border.all(color: AppColors.accentCyan.withAlpha(100), width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentCyan.withAlpha(40),
                  blurRadius: 30,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.headphones_rounded,
                color: AppColors.accentCyan,
                size: 56,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Chế độ phát âm thanh nền',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tắt màn hình vẫn nghe âm thanh liên tục • Tiết kiệm 80% pin',
            style: TextStyle(color: Colors.white60, fontSize: 12.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            icon: const Icon(Icons.videocam_rounded, size: 20),
            label: const Text('Bật lại hình ảnh video', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              controller.toggleAudioOnly();
            },
          ),
        ],
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

  Widget _buildTopBar(
    BuildContext context,
    String title,
    String artist,
    PlaybackStateModel playback,
    GlobalPlaybackController controller,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withAlpha(200),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Nút thu nhỏ dạng mũi tên xuống (YouTube style)
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32),
            tooltip: 'Thu nhỏ video',
            onPressed: () {
              if (_isLandscape) {
                SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
              }
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 4),

          // Tên video & Tác giả
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),

          // Nút Bật / Tắt chế độ chỉ nghe âm thanh (Headphones)
          IconButton(
            icon: Icon(
              playback.isAudioOnly ? Icons.headphones_rounded : Icons.headphones_outlined,
              color: playback.isAudioOnly ? AppColors.accentCyan : Colors.white,
              size: 24,
            ),
            tooltip: 'Chỉ nghe âm thanh (Tắt màn hình vẫn nghe)',
            onPressed: () {
              HapticFeedback.selectionClick();
              controller.toggleAudioOnly();
              _showToast(playback.isAudioOnly ? 'Đã bật lại hình ảnh video' : 'Đã chuyển sang chế độ chỉ nghe tiếng');
            },
          ),

          // Nút Thu nhỏ ra màn hình chính (PiP)
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white, size: 24),
            tooltip: 'Màn hình nhỏ PiP',
            onPressed: () {
              HapticFeedback.selectionClick();
              controller.enterPip();
            },
          ),

          // Nút Cài đặt (Settings)
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 23),
            tooltip: 'Cài đặt',
            onPressed: () {
              HapticFeedback.selectionClick();
              _showSettingsSheet();
            },
          ),

          // Nút Khóa cảm ứng
          IconButton(
            icon: Icon(_isLocked ? Icons.lock_rounded : Icons.lock_open_rounded, color: Colors.white, size: 22),
            tooltip: _isLocked ? 'Đã khóa màn hình' : 'Khóa cảm ứng',
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _isLocked = !_isLocked);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls(PlaybackStateModel playback, GlobalPlaybackController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Nút Bài trước
        if (playback.queue.length > 1) ...[
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 34),
            tooltip: 'Bài trước',
            onPressed: () {
              HapticFeedback.selectionClick();
              controller.previous();
              _startHideTimer();
            },
          ),
          const SizedBox(width: 16),
        ],

        // Nút Tua lùi 10 giây
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            controller.seekBackward(const Duration(seconds: 10));
            _startHideTimer();
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withAlpha(80),
            ),
            child: const Center(
              child: Icon(Icons.replay_10_rounded, color: Colors.white, size: 36),
            ),
          ),
        ),
        const SizedBox(width: 28),

        // Nút Play/Pause chính giữa lớn
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.mediumImpact();
            controller.togglePlayPause();
            _startHideTimer();
          },
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentCyan.withAlpha(100),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                playback.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.black87,
                size: 40,
              ),
            ),
          ),
        ),
        const SizedBox(width: 28),

        // Nút Tua tới 10 giây
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            controller.seekForward(const Duration(seconds: 10));
            _startHideTimer();
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withAlpha(80),
            ),
            child: const Center(
              child: Icon(Icons.forward_10_rounded, color: Colors.white, size: 36),
            ),
          ),
        ),

        // Nút Bài tiếp theo
        if (playback.queue.length > 1) ...[
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 34),
            tooltip: 'Bài tiếp theo',
            onPressed: () {
              HapticFeedback.selectionClick();
              controller.next();
              _startHideTimer();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildBottomBar(PlaybackStateModel playback, GlobalPlaybackController controller) {
    if (_isLocked) return const SizedBox.shrink();

    final posMs = playback.position.inMilliseconds.toDouble();
    final durMs = math.max(playback.duration.inMilliseconds.toDouble(), 1.0);
    final clampedPos = posMs.clamp(0.0, durMs);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withAlpha(200),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thanh trượt tiến trình chuẩn YouTube (Màu đỏ Ruby / Neon Cyan)
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: const Color(0xFFFF0033),
              inactiveTrackColor: Colors.white30,
              thumbColor: const Color(0xFFFF0033),
              overlayColor: const Color(0xFFFF0033).withAlpha(50),
              trackShape: const RectangularSliderTrackShape(),
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

          // Hàng thời gian & Nút toàn màn hình
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatDuration(playback.position)} / ${_formatDuration(playback.duration)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              Row(
                children: [
                  // Nút xoay toàn màn hình
                  IconButton(
                    icon: Icon(
                      _isLandscape ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    tooltip: _isLandscape ? 'Thu nhỏ dọc' : 'Toàn màn hình',
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
}
