import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_strings_vi.dart';
import '../core/navigation/navigation_provider.dart';
import '../features/downloads/domain/download_status.dart';
import '../features/downloads/engine/download_manager.dart';
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
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // Màn hình chính theo tab
          IndexedStack(
            index: currentIndex,
            children: _screens,
          ),

          // Thanh điều khiển phát thu nhỏ & Thanh điều hướng nổi
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: RepaintBoundary(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MiniPlayer(),
                  _buildNeoGlassDock(context, ref, currentIndex, isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeoGlassDock(
    BuildContext context,
    WidgetRef ref,
    int currentIndex,
    bool isDark,
  ) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final dockBottomPadding = bottomInset > 0 ? bottomInset + 2 : 16.0;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: dockBottomPadding,
        top: 6,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: isDark ? AppColors.liquidGlassDark : AppColors.liquidGlassLight,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 80 : 16),
                  blurRadius: 20,
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
                  label: AppStringsVi.home,
                  iconOutline: Icons.home_outlined,
                  iconFilled: Icons.home_rounded,
                  isDark: isDark,
                ),
                _buildNavItem(
                  ref: ref,
                  index: 1,
                  currentIndex: currentIndex,
                  label: AppStringsVi.downloads,
                  iconOutline: Icons.arrow_downward_outlined,
                  iconFilled: Icons.arrow_downward_rounded,
                  isDark: isDark,
                  showBadge: true,
                ),
                _buildNavItem(
                  ref: ref,
                  index: 2,
                  currentIndex: currentIndex,
                  label: AppStringsVi.musicLibrary,
                  iconOutline: Icons.music_note_outlined,
                  iconFilled: Icons.music_note_rounded,
                  isDark: isDark,
                ),
                _buildNavItem(
                  ref: ref,
                  index: 3,
                  currentIndex: currentIndex,
                  label: AppStringsVi.videoLibrary,
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
    bool showBadge = false,
  }) {
    final isSelected = index == currentIndex;
    final activeColor = isDark ? AppColors.accentCyan : AppColors.accentBlue;
    final inactiveColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

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
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    isSelected ? iconFilled : iconOutline,
                    color: isSelected ? activeColor : inactiveColor,
                    size: 24,
                  ),
                ),
                if (showBadge)
                  StreamBuilder(
                    stream: DownloadManager().tasksStream,
                    initialData: DownloadManager().tasks,
                    builder: (context, snapshot) {
                      final tasks = snapshot.data ?? [];
                      final activeCount = tasks
                          .where((t) =>
                              t.status == DownloadStatus.downloading ||
                              t.status == DownloadStatus.queued)
                          .length;
                      if (activeCount == 0) return const SizedBox.shrink();

                      return Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentCyan.withAlpha(120),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Text(
                            '$activeCount',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                fontSize: 10.5,
                letterSpacing: -0.2,
              ),
              child: Text(label),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: isSelected ? 16 : 0,
              height: 3,
              decoration: BoxDecoration(
                gradient: isSelected ? AppColors.primaryGradient : null,
                color: isSelected ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: activeColor.withAlpha(140),
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
