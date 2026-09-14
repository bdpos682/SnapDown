enum DownloadStatus {
  queued,
  preparing,
  resolving,
  downloading,
  paused,
  processing,
  merging,
  converting,
  completed,
  failed,
  canceled,
}

extension DownloadStatusX on DownloadStatus {
  bool get isActive =>
      this == DownloadStatus.downloading ||
      this == DownloadStatus.processing ||
      this == DownloadStatus.merging ||
      this == DownloadStatus.converting ||
      this == DownloadStatus.preparing ||
      this == DownloadStatus.resolving;

  bool get isFinished =>
      this == DownloadStatus.completed ||
      this == DownloadStatus.failed ||
      this == DownloadStatus.canceled;

  /// Tên trạng thái 100% Tiếng Việt
  String get displayNameVi {
    switch (this) {
      case DownloadStatus.queued:
        return 'Chờ tải';
      case DownloadStatus.preparing:
        return 'Đang chuẩn bị';
      case DownloadStatus.resolving:
        return 'Đang lấy luồng';
      case DownloadStatus.downloading:
        return 'Đang tải về';
      case DownloadStatus.paused:
        return 'Tạm dừng';
      case DownloadStatus.processing:
        return 'Đang xử lý';
      case DownloadStatus.merging:
        return 'Đang ghép luồng';
      case DownloadStatus.converting:
        return 'Đang chuyển đổi';
      case DownloadStatus.completed:
        return 'Hoàn tất';
      case DownloadStatus.failed:
        return 'Thất bại';
      case DownloadStatus.canceled:
        return 'Đã hủy';
    }
  }

  String get displayName => displayNameVi;
}
