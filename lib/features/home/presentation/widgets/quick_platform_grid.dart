import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings_vi.dart';

class QuickPlatformGrid extends StatelessWidget {
  final String activePlatform;
  final Function(String) onPlatformTap;

  const QuickPlatformGrid({
    super.key,
    required this.activePlatform,
    required this.onPlatformTap,
  });

  static const List<Map<String, dynamic>> _platforms = [
    {
      'id': 'youtube',
      'title': AppStringsVi.platformYoutube,
      'subtitle': 'Video 4K & Nhạc 320k',
      'accentColor': Color(0xFFFF2A2A),
      'iconGradient': LinearGradient(
        colors: [Color(0xFFFF334B), Color(0xFFE50914)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'icon': Icons.play_arrow_rounded,
    },
    {
      'id': 'tiktok',
      'title': AppStringsVi.platformTiktok,
      'subtitle': 'Không dính Logo/Mờ',
      'accentColor': Color(0xFF00C4D6),
      'iconGradient': LinearGradient(
        colors: [Color(0xFF00E5FF), Color(0xFF0070F3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'icon': Icons.music_note_rounded,
    },
    {
      'id': 'facebook',
      'title': AppStringsVi.platformFacebook,
      'subtitle': 'Video HD & Thước phim',
      'accentColor': Color(0xFF1877F2),
      'iconGradient': LinearGradient(
        colors: [Color(0xFF2E89FF), Color(0xFF0055D4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'icon': Icons.facebook_rounded,
    },
    {
      'id': 'instagram',
      'title': 'Instagram',
      'subtitle': 'Reels, Story & Bài viết',
      'accentColor': Color(0xFFE1306C),
      'iconGradient': LinearGradient(
        colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'icon': Icons.camera_alt_rounded,
    },
    {
      'id': 'twitter',
      'title': AppStringsVi.platformTwitter,
      'subtitle': 'Video clip & Tải nhanh',
      'accentColor': Color(0xFF1DA1F2),
      'iconGradient': LinearGradient(
        colors: [Color(0xFF1DA1F2), Color(0xFF0D6EFD)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'icon': Icons.alternate_email_rounded,
    },
    {
      'id': 'direct',
      'title': AppStringsVi.platformDirect,
      'subtitle': 'Tải MP4, MP3 từ Web',
      'accentColor': Color(0xFF10B981),
      'iconGradient': LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'icon': Icons.link_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStringsVi.supportedPlatforms,
              style: TextStyle(
                color: textPrimary,
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                ),
              ),
              child: Text(
                'Tự động nhận diện',
                style: TextStyle(
                  color: isDark ? AppColors.accentCyan : AppColors.accentBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Lưới 6 thẻ phong cách Neo-Glass thanh lịch, hài hòa, không chói mắt
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: _platforms.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.15,
          ),
          itemBuilder: (context, index) {
            final p = _platforms[index];
            final isDetected = activePlatform == p['id'];
            final accent = p['accentColor'] as Color;
            final iconGradient = p['iconGradient'] as LinearGradient;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onPlatformTap(p['id'] as String);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  // Nền thẻ dịu mắt: Phủ nhẹ màu thương hiệu tinh tế
                  color: isDark
                      ? (isDetected ? accent.withAlpha(45) : AppColors.darkCard)
                      : (isDetected ? accent.withAlpha(25) : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDetected
                        ? accent
                        : (isDark
                            ? accent.withAlpha(35)
                            : accent.withAlpha(30)),
                    width: isDetected ? 1.8 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDetected
                          ? accent.withAlpha(isDark ? 80 : 40)
                          : Colors.black.withAlpha(isDark ? 40 : 8),
                      blurRadius: isDetected ? 12 : 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Viên ngọc Icon nổi bật, tinh tế
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: iconGradient,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withAlpha(80),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          p['icon'] as IconData,
                          size: 21,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Tiêu đề & Phụ đề rõ ràng, thanh nhã
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['title'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDetected ? (isDark ? Colors.white : accent) : textPrimary,
                              fontSize: 12.5,
                              fontWeight: isDetected ? FontWeight.w900 : FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p['subtitle'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
