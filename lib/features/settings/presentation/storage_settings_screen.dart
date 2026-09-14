import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/storage/storage_manager.dart';

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá bộ nhớ đệm & tệp tạm?'),
        content: const Text(
          'Hành động này sẽ xoá an toàn các phân đoạn tải tạm thời và ảnh thu nhỏ bộ nhớ đệm.\n\n'
          'CÁC BẢN NHẠC VÀ VIDEO ĐÃ TẢI XUỐNG CỦA BẠN SẼ KHÔNG BỊ XOÁ.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xoá ngay', style: TextStyle(color: AppColors.accentCyan)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storage.clearTempFiles();
      await _loadStorageData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã dọn dẹp bộ nhớ đệm thành công')),
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
      appBar: AppBar(
        title: Text('Dung lượng & Bộ nhớ đệm', style: AppTypography.h2.copyWith(color: textPrimary)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentCyan))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s16),
              children: [
                // Total Storage Summary Card
                _buildSummaryCard(isDark, textPrimary, textSecondary),
                const SizedBox(height: AppSpacing.s24),

                // Breakdown list
                _buildStorageItem('Nhạc / Âm thanh', _breakdown!.formattedAudio, AppColors.accentAmber, Icons.headphones_rounded),
                const SizedBox(height: AppSpacing.s12),
                _buildStorageItem('Video', _breakdown!.formattedVideo, AppColors.accentCyan, Icons.movie_rounded),
                const SizedBox(height: AppSpacing.s12),
                _buildStorageItem('Ảnh bìa & Thu nhỏ', _breakdown!.formattedArtwork, AppColors.accentBlue, Icons.image_rounded),
                const SizedBox(height: AppSpacing.s12),
                _buildStorageItem('Tệp tạm thời', _breakdown!.formattedTemp, AppColors.accentRed, Icons.folder_delete_rounded),
                const SizedBox(height: AppSpacing.s32),

                // Clear Cache Button
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkElevated : AppColors.lightElevated,
                    borderRadius: AppRadius.radiusMd,
                    border: Border.all(
                      color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                    ),
                  ),
                  child: TextButton.icon(
                    onPressed: _clearCache,
                    icon: const Icon(Icons.cleaning_services_rounded, color: AppColors.accentCyan),
                    label: Text(
                      'Dọn dẹp bộ nhớ đệm',
                      style: AppTypography.label.copyWith(color: AppColors.accentCyan),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(bool isDark, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tổng dung lượng lưu trữ', style: AppTypography.bodySmall.copyWith(color: textSecondary)),
          const SizedBox(height: 6),
          Text(
            _breakdown!.formattedTotal,
            style: AppTypography.display.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // Proportional Bar
          ClipRRect(
            borderRadius: AppRadius.radiusPill,
            child: SizedBox(
              height: 10,
              child: _breakdown!.totalBytes > 0
                  ? Row(
                      children: [
                        if (_breakdown!.audioBytes > 0)
                          Expanded(
                            flex: _breakdown!.audioBytes,
                            child: Container(color: AppColors.accentAmber),
                          ),
                        if (_breakdown!.videoBytes > 0)
                          Expanded(
                            flex: _breakdown!.videoBytes,
                            child: Container(color: AppColors.accentCyan),
                          ),
                        if (_breakdown!.artworkBytes > 0)
                          Expanded(
                            flex: _breakdown!.artworkBytes,
                            child: Container(color: AppColors.accentBlue),
                          ),
                        if (_breakdown!.tempBytes > 0)
                          Expanded(
                            flex: _breakdown!.tempBytes,
                            child: Container(color: AppColors.accentRed),
                          ),
                      ],
                    )
                  : Container(color: isDark ? AppColors.darkHighlight : AppColors.lightHighlight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageItem(String label, String size, Color color, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(label, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          ),
          Text(size, style: AppTypography.bodyMedium.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
