import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

/// Hệ thống hộp thoại (Dialogs / Popups) BDSNAP phong cách Neo-Glass sang trọng & chuyên nghiệp
class AppDialogs {
  AppDialogs._();

  /// Hộp thoại xác nhận xóa (Destructive action)
  static Future<bool> showConfirmDelete({
    required BuildContext context,
    required String title,
    required String message,
    String? itemName,
    String confirmText = 'Xóa vĩnh viễn',
    String cancelText = 'Hủy bỏ',
  }) async {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Xác nhận xóa',
      barrierColor: Colors.black.withAlpha(140),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (context, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141824).withAlpha(240) : Colors.white.withAlpha(245),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(14),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 120 : 35),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Huy hiệu Icon đỏ rực cảnh báo
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accentRed.withAlpha(22),
                            border: Border.all(
                              color: AppColors.accentRed.withAlpha(60),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentRed.withAlpha(45),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.delete_forever_rounded,
                              color: AppColors.accentRed,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Tiêu đề
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 17.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Tên mục cần xóa (nếu có)
                        if (itemName != null && itemName.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              itemName,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Lời giải thích / Cảnh báo
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Hàng nút bấm hành động
                        Row(
                          children: [
                            // Nút Hủy
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: textSecondary,
                                    side: BorderSide(
                                      color: isDark ? Colors.white.withAlpha(24) : Colors.black.withAlpha(16),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    backgroundColor: isDark
                                        ? Colors.white.withAlpha(8)
                                        : Colors.black.withAlpha(5),
                                  ),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.pop(ctx, false);
                                  },
                                  child: Text(
                                    cancelText,
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Nút Xác nhận Xóa (Màu Đỏ Nổi Bật)
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFF3366), Color(0xFFFF416C)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF3366).withAlpha(90),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      Navigator.pop(ctx, true);
                                    },
                                    child: Text(
                                      confirmText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  /// Hộp thoại xác nhận hành động chung (Dọn dẹp cache, hoàn tất tải...)
  static Future<bool> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    IconData icon = Icons.help_outline_rounded,
    Color iconColor = AppColors.accentCyan,
    String confirmText = 'Xác nhận',
    String cancelText = 'Hủy bỏ',
  }) async {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Xác nhận',
      barrierColor: Colors.black.withAlpha(140),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (context, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141824).withAlpha(240) : Colors.white.withAlpha(245),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(14),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 120 : 35),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Huy hiệu Icon
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: iconColor.withAlpha(25),
                            border: Border.all(
                              color: iconColor.withAlpha(70),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: iconColor.withAlpha(50),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(icon, color: iconColor, size: 28),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 17.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 10),

                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),

                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: textSecondary,
                                    side: BorderSide(
                                      color: isDark ? Colors.white.withAlpha(24) : Colors.black.withAlpha(16),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    backgroundColor: isDark
                                        ? Colors.white.withAlpha(8)
                                        : Colors.black.withAlpha(5),
                                  ),
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(
                                    cancelText,
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accentCyan.withAlpha(80),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      Navigator.pop(ctx, true);
                                    },
                                    child: Text(
                                      confirmText,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  /// Hộp thoại nhập văn bản (Ví dụ: Tạo danh sách phát mới)
  static Future<String?> showTextInputDialog({
    required BuildContext context,
    required String title,
    required String hintText,
    String confirmText = 'Tạo mới',
    String cancelText = 'Hủy bỏ',
    IconData icon = Icons.playlist_add_rounded,
    String? initialValue,
  }) async {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final controller = TextEditingController(text: initialValue ?? '');

    final result = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      barrierColor: Colors.black.withAlpha(140),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (context, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF141824).withAlpha(240) : Colors.white.withAlpha(245),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: isDark ? Colors.white.withAlpha(28) : Colors.black.withAlpha(14),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 120 : 35),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accentCyan.withAlpha(25),
                              border: Border.all(
                                color: AppColors.accentCyan.withAlpha(70),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentCyan.withAlpha(50),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(icon, color: AppColors.accentCyan, size: 28),
                            ),
                          ),
                          const SizedBox(height: 16),

                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 16),

                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : AppColors.lightElevated,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                              ),
                            ),
                            child: TextField(
                              controller: controller,
                              autofocus: true,
                              style: TextStyle(color: textPrimary, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: hintText,
                                hintStyle: TextStyle(
                                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                  fontSize: 13.5,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),

                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: textSecondary,
                                      side: BorderSide(
                                        color: isDark ? Colors.white.withAlpha(24) : Colors.black.withAlpha(16),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      backgroundColor: isDark
                                          ? Colors.white.withAlpha(8)
                                          : Colors.black.withAlpha(5),
                                    ),
                                    onPressed: () => Navigator.pop(ctx, null),
                                    child: Text(
                                      cancelText,
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.accentCyan.withAlpha(80),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      onPressed: () {
                                        final text = controller.text.trim();
                                        if (text.isNotEmpty) {
                                          HapticFeedback.mediumImpact();
                                          Navigator.pop(ctx, text);
                                        }
                                      },
                                      child: Text(
                                        confirmText,
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    return result;
  }
}
