import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/navigation/navigation_provider.dart';
import '../features/downloads/presentation/download_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/library/presentation/music_library_screen.dart';
import '../features/library/presentation/video_library_screen.dart';
import '../features/player/presentation/mini_player.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const List<Widget> _screens = [
    HomeScreen(),
    DownloadsScreen(),
    MusicLibraryScreen(),
    VideoLibraryScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationTabProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: _screens,
          ),

          // Dock Thủy tinh lỏng (Liquid Glass iOS 27) & MiniPlayer
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // MiniPlayer nổi dạng viên thuốc
                const MiniPlayer(),

                // Floating Liquid Glass Dock
                _buildLiquidGlassDock(context, ref, currentIndex, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiquidGlassDock(
    BuildContext context,
    WidgetRef ref,
    int currentIndex,
    bool isDark,
  ) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: bottomInset > 0 ? bottomInset : 16,
        top: 4,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xCC121624) : Colors.white.withAlpha(210),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDark ? Colors.white.withAlpha(35) : Colors.white.withAlpha(240),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 80 : 18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  ref: ref,
                  index: 0,
                  currentIndex: currentIndex,
                  label: 'Trang chủ',
                  iconOutline: Icons.home_outlined,
                  iconFilled: Icons.home_rounded,
                  isDark: isDark,
                ),
                _buildNavItem(
                  ref: ref,
                  index: 1,
                  currentIndex: currentIndex,
                  label: 'Tải xuống',
                  iconOutline: Icons.arrow_downward_outlined,
                  iconFilled: Icons.arrow_downward_rounded,
                  isDark: isDark,
                ),
                _buildNavItem(
                  ref: ref,
                  index: 2,
                  currentIndex: currentIndex,
                  label: 'Nhạc',
                  iconOutline: Icons.music_note_outlined,
                  iconFilled: Icons.music_note_rounded,
                  isDark: isDark,
                ),
                _buildNavItem(
                  ref: ref,
                  index: 3,
                  currentIndex: currentIndex,
                  label: 'Video',
                  iconOutline: Icons.play_circle_outline_rounded,
                  iconFilled: Icons.play_circle_fill_rounded,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required WidgetRef ref,
    required int index,
    required int currentIndex,
    required String label,
    required IconData iconOutline,
    required IconData iconFilled,
    required bool isDark,
  }) {
    final isSelected = index == currentIndex;
    final activeColor = isDark ? const Color(0xFF00F2FE) : const Color(0xFF007AFF);
    final inactiveColor = isDark ? Colors.white.withAlpha(120) : const Color(0xFF8E8E93);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(navigationTabProvider.notifier).setTab(index);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Icon(
                isSelected ? iconFilled : iconOutline,
                color: isSelected ? activeColor : inactiveColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 10.5,
                letterSpacing: -0.2,
              ),
              child: Text(label),
            ),
            const SizedBox(height: 3),
            // Liquid Droplet Indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: isSelected ? 14 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: isSelected ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: activeColor.withAlpha(120),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
