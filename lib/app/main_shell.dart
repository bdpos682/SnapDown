import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_typography.dart';
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
        left: 16,
        right: 16,
        bottom: bottomInset > 0 ? bottomInset : 14,
        top: 4,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: isDark ? AppColors.liquidGlassDark : AppColors.liquidGlassLight,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: isDark ? Colors.white.withAlpha(45) : Colors.white.withAlpha(220),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 90 : 25),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: (isDark ? AppColors.accentCyan : AppColors.accentBlue).withAlpha(isDark ? 28 : 18),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
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
                  iconOutline: Icons.download_outlined,
                  iconFilled: Icons.download_rounded,
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
                  iconOutline: Icons.movie_outlined,
                  iconFilled: Icons.movie_rounded,
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
    final activeColor = isDark ? AppColors.accentCyan : AppColors.accentBlue;
    final inactiveColor = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(navigationTabProvider.notifier).setTab(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: isSelected
                ? LinearGradient(
                    colors: isDark
                        ? [
                            AppColors.accentCyan.withAlpha(50),
                            AppColors.accentBlue.withAlpha(20),
                          ]
                        : [
                            AppColors.accentBlue.withAlpha(40),
                            AppColors.accentCyan.withAlpha(20),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            border: isSelected
                ? Border.all(
                    color: activeColor.withAlpha(isDark ? 80 : 60),
                    width: 1,
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: Icon(
                  isSelected ? iconFilled : iconOutline,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: AppTypography.caption.copyWith(
                  color: isSelected ? activeColor : inactiveColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 10,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
