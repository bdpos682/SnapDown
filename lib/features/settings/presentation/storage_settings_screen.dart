import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings_vi.dart';
import '../../../core/storage/storage_manager.dart';
import '../../../core/widgets/app_dialogs.dart';

class StorageSettingsScreen extends StatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  State<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends State<StorageSettingsScreen> {
  final StorageManager _storage = StorageManager();
  StorageBreakdown? _breakdown;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStorageData();
  }

  Future<void> _loadStorageData() async {
    setState(() => _isLoading = true);
    final data = await _storage.getStorageBreakdown();
    if (mounted) {
      setState(() {
        _breakdown = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await AppDialogs.showConfirmation(
      context: context,
      title: 'Dọn dẹp bộ nhớ đệm?',
      message: AppStringsVi.cleanCacheConfirm,
      icon: Icons.cleaning_services_rounded,
      iconColor: AppColors.accentCyan,
      confirmText: 'Dọn dẹp ngay',
      cancelText: 'Hủy bỏ',
    );

    if (confirmed == true) {
      HapticFeedback.mediumImpact();
      await _storage.clearTempFiles();
      await _loadStorageData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStringsVi.cleanCacheSuccess),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          AppStringsVi.storageCenter,
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentCyan))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thẻ Tổng Quan Dung Lượng
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? const LinearGradient(
                              colors: [Color(0xFF1E2438), Color(0xFF131724)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFFFFFFF), Color(0xFFEDF2F8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 50 : 10),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStringsVi.totalUsed,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _breakdown?.formattedTotal ?? '0 B',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: 1.0,
                            minHeight: 8,
                            backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Chi tiết từng phân vùng',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Danh sách phân vùng
                  _buildStorageRow(
                    icon: Icons.music_note_rounded,
                    color: AppColors.accentCyan,
                    title: AppStringsVi.audioStorage,
                    sizeStr: _breakdown?.formattedAudio ?? '0 B',
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  _buildStorageRow(
                    icon: Icons.movie_rounded,
                    color: AppColors.accentBlue,
                    title: AppStringsVi.videoStorage,
                    sizeStr: _breakdown?.formattedVideo ?? '0 B',
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  _buildStorageRow(
                    icon: Icons.image_rounded,
                    color: AppColors.accentViolet,
                    title: AppStringsVi.artworkStorage,
                    sizeStr: _breakdown?.formattedArtwork ?? '0 B',
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  _buildStorageRow(
                    icon: Icons.cached_rounded,
                    color: AppColors.accentAmber,
                    title: AppStringsVi.tempStorage,
                    sizeStr: _breakdown?.formattedTemp ?? '0 B',
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),

                  const SizedBox(height: 28),

                  // Nút Xóa bộ nhớ đệm
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: const BorderSide(color: AppColors.accentCyan, width: 1.3),
                      ),
                      icon: const Icon(Icons.cleaning_services_rounded, color: AppColors.accentCyan),
                      label: const Text(
                        AppStringsVi.cleanCacheButton,
                        style: TextStyle(
                          color: AppColors.accentCyan,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      onPressed: _clearCache,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStorageRow({
    required IconData icon,
    required Color color,
    required String title,
    required String sizeStr,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(isDark ? 40 : 25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            sizeStr,
            style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
