import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings_vi.dart';
import '../../../../core/navigation/navigation_provider.dart';
import '../../../downloads/domain/download_status.dart';
import '../../../downloads/engine/download_manager.dart';

class HomeDownloadPulseCard extends ConsumerWidget {
  const HomeDownloadPulseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder(
      stream: DownloadManager().tasksStream,
      initialData: DownloadManager().tasks,
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? [];
        final activeTask = tasks.cast<dynamic>().firstWhere(
              (t) => t.status == DownloadStatus.downloading,
              orElse: () => null,
            );

        if (activeTask == null) return const SizedBox.shrink();

        final progress = (activeTask.progress as double).clamp(0.0, 1.0);
        final speed = AppStringsVi.formatSpeed(activeTask.speedBytesPerSec as int);
        final eta = AppStringsVi.formatEta(activeTask.etaSeconds as int);

        return Container(
          margin: const EdgeInsets.only(top: 18),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.accentCyan.withAlpha(isDark ? 60 : 100),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentCyan.withAlpha(isDark ? 20 : 12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentCyan,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Đang tải xuống dữ liệu...',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      ref.read(navigationTabProvider.notifier).switchToDownloads();
                    },
                    child: Text(
                      'Xem chi tiết >',
                      style: TextStyle(
                        color: isDark ? AppColors.accentCyan : AppColors.accentBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                activeTask.mediaInfo.title as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}% • $speed',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    eta,
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
