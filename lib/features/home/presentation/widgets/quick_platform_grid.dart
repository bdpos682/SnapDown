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
      'title': 'YouTube',
      'subtitle': 'Video 4K & Nhạc 320k',
      'accentColor': Color(0xFFFF0000),
      'iconGradient': LinearGradient(
        colors: [Color(0xFFFF1E27), Color(0xFFCC0000)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'id': 'tiktok',
      'title': 'TikTok',
      'subtitle': 'Không dính Logo/Mờ',
      'accentColor': Color(0xFFFE2C55),
      'iconGradient': LinearGradient(
        colors: [Color(0xFF1C1C1E), Color(0xFF000000)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'id': 'facebook',
      'title': 'Facebook',
      'subtitle': 'Video HD & Thước phim',
      'accentColor': Color(0xFF1877F2),
      'iconGradient': LinearGradient(
        colors: [Color(0xFF1877F2), Color(0xFF0866FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'id': 'instagram',
      'title': 'Instagram',
      'subtitle': 'Reels, Story & Bài viết',
      'accentColor': Color(0xFFE1306C),
      'iconGradient': LinearGradient(
        colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCAF45)],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ),
    },
    {
      'id': 'twitter',
      'title': 'X (Twitter)',
      'subtitle': 'Video clip & Tải nhanh',
      'accentColor': Color(0xFF000000),
      'iconGradient': LinearGradient(
        colors: [Color(0xFF2C2C2E), Color(0xFF000000)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    {
      'id': 'direct',
      'title': 'Liên kết trực tiếp',
      'subtitle': 'Tải MP4, MP3 từ Web',
      'accentColor': Color(0xFF10B981),
      'iconGradient': LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
  ];

  Widget _buildPlatformIcon(String id) {
    switch (id) {
      case 'youtube':
        return const CustomPaint(
          size: Size(22, 22),
          painter: _YoutubeLogoPainter(),
        );
      case 'tiktok':
        return const CustomPaint(
          size: Size(21, 21),
          painter: _TikTokPainter(),
        );
      case 'facebook':
        return const CustomPaint(
          size: Size(22, 22),
          painter: _FacebookLogoPainter(),
        );
      case 'instagram':
        return const CustomPaint(
          size: Size(21, 21),
          painter: _InstagramLogoPainter(),
        );
      case 'twitter':
        return const CustomPaint(
          size: Size(20, 20),
          painter: _XLogoPainter(),
        );
      case 'direct':
      default:
        return const Icon(
          Icons.link_rounded,
          size: 21,
          color: Colors.white,
        );
    }
  }

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

        // Lưới 6 thẻ phong cách Neo-Glass thanh lịch, chuẩn nhận diện thương hiệu
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
            final rawAccent = p['accentColor'] as Color;
            // Với X trên nền tối, viền và điểm nhấn dùng màu bạc/trắng trang nhã
            final accent = (p['id'] == 'twitter' && isDark)
                ? const Color(0xFFE7E9EA)
                : rawAccent;
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
                    // Viên ngọc Icon nổi bật, tinh tế chuẩn thương hiệu
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: iconGradient,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: (p['id'] == 'twitter' && !isDark)
                                ? Colors.black.withAlpha(60)
                                : accent.withAlpha(80),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _buildPlatformIcon(p['id'] as String),
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

/// Logo TikTok chuẩn nhận diện với hiệu ứng 3D Chromatic Glitch (Cyan & Pink & White)
class _TikTokPainter extends CustomPainter {
  const _TikTokPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    Path buildNotePath() {
      final p = Path();
      p.moveTo(18.2, 5.5);
      p.cubicTo(16.0, 5.5, 14.2, 3.8, 14.0, 2.0);
      p.lineTo(11.2, 2.0);
      p.lineTo(11.2, 14.6);
      p.cubicTo(10.2, 13.7, 8.8, 13.2, 7.2, 13.6);
      p.cubicTo(4.7, 14.2, 3.0, 16.6, 3.4, 19.3);
      p.cubicTo(3.8, 21.8, 6.4, 23.3, 9.0, 22.8);
      p.cubicTo(11.4, 22.3, 13.4, 19.8, 13.4, 17.0);
      p.lineTo(13.4, 9.2);
      p.cubicTo(15.2, 10.6, 17.5, 11.2, 20.0, 11.2);
      p.lineTo(20.0, 8.4);
      p.cubicTo(19.2, 8.4, 18.5, 7.3, 18.2, 5.5);
      p.close();
      return p;
    }

    final path = buildNotePath();

    // 1. Cyan offset (lệch trên-trái)
    final cyanPaint = Paint()
      ..color = const Color(0xFF25F4EE)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(-1.1, -1.0);
    canvas.drawPath(path, cyanPaint);
    canvas.restore();

    // 2. Magenta/Pink offset (lệch dưới-phải)
    final pinkPaint = Paint()
      ..color = const Color(0xFFFE2C55)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(1.1, 1.0);
    canvas.drawPath(path, pinkPaint);
    canvas.restore();

    // 3. White center chính diện
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, whitePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Logo X (Twitter) chuẩn vector chính xác với đường chéo rỗng đặc trưng
class _XLogoPainter extends CustomPainter {
  const _XLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final path = Path()..fillType = PathFillType.evenOdd;

    // Viền bao ngoài chữ X
    path.moveTo(18.244, 2.25);
    path.lineTo(21.552, 2.25);
    path.lineTo(14.325, 10.51);
    path.lineTo(22.827, 21.75);
    path.lineTo(16.170, 21.75);
    path.lineTo(10.956, 14.933);
    path.lineTo(4.990, 21.75);
    path.lineTo(1.680, 21.75);
    path.lineTo(9.410, 12.915);
    path.lineTo(1.254, 2.25);
    path.lineTo(8.080, 2.25);
    path.lineTo(12.793, 8.481);
    path.close();

    // Khoảng hở rỗng dọc theo nhánh chéo \
    path.moveTo(17.083, 19.77);
    path.lineTo(18.916, 19.77);
    path.lineTo(7.084, 4.126);
    path.lineTo(5.117, 4.126);
    path.close();

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Biểu tượng Instagram Camera chuẩn nhận diện thương hiệu
class _InstagramLogoPainter extends CustomPainter {
  const _InstagramLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Khung bo góc camera
    final outerRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(3.2, 3.2, 17.6, 17.6),
      const Radius.circular(5.2),
    );
    canvas.drawRRect(outerRect, strokePaint);

    // Vòng tròn ống kính trung tâm
    canvas.drawCircle(const Offset(12.0, 12.0), 4.3, strokePaint);

    // Chấm đèn flash góc trên bên phải
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(16.8, 7.2), 1.25, fillPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Chữ "f" Facebook chuẩn nhận diện Meta
class _FacebookLogoPainter extends CustomPainter {
  const _FacebookLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final path = Path();
    path.moveTo(13.4, 24.0);
    path.lineTo(13.4, 14.6);
    path.lineTo(16.5, 14.6);
    path.lineTo(17.0, 11.1);
    path.lineTo(13.4, 11.1);
    path.lineTo(13.4, 8.9);
    path.cubicTo(13.4, 7.9, 13.9, 7.0, 15.3, 7.0);
    path.lineTo(17.0, 7.0);
    path.lineTo(17.0, 3.9);
    path.cubicTo(16.5, 3.8, 15.4, 3.6, 14.1, 3.6);
    path.cubicTo(11.3, 3.6, 9.4, 5.3, 9.4, 8.4);
    path.lineTo(9.4, 11.1);
    path.lineTo(6.4, 11.1);
    path.lineTo(6.4, 14.6);
    path.lineTo(9.4, 14.6);
    path.lineTo(9.4, 24.0);
    path.close();

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Nút Play YouTube bo góc mượt mà chính diện
class _YoutubeLogoPainter extends CustomPainter {
  const _YoutubeLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final path = Path();
    // Tam giác Play với đỉnh bo nhẹ tinh tế
    path.moveTo(9.5, 6.8);
    path.cubicTo(9.5, 6.2, 10.2, 5.8, 10.7, 6.1);
    path.lineTo(17.5, 11.2);
    path.cubicTo(18.1, 11.6, 18.1, 12.4, 17.5, 12.8);
    path.lineTo(10.7, 17.9);
    path.cubicTo(10.2, 18.2, 9.5, 17.8, 9.5, 17.2);
    path.close();

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
