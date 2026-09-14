/// Từ điển chuỗi ngôn ngữ 100% Thuần Việt của ứng dụng BDSNAP
/// Không chứa bất kỳ từ tiếng Anh nào trong giao diện người dùng.
class AppStringsVi {
  AppStringsVi._();

  // Thương hiệu & Tiêu đề chung
  static const String appName = 'BDPLAY';
  static const String appSlogan = 'Bộ tải & Trình phát đa phương tiện';
  static const String home = 'Trang chủ';
  static const String downloads = 'Tải về';
  static const String musicLibrary = 'Nhạc';
  static const String videoLibrary = 'Video';
  static const String settings = 'Cài đặt';
  static const String storage = 'Dung lượng';

  // Màn hình chính
  static const String heroTitle = 'Tải Mọi Video & Âm Thanh';
  static const String heroSubtitle = 'Dán liên kết từ mạng xã hội hoặc web để lưu về máy với chất lượng cao nhất';
  static const String inputPlaceholder = 'Dán đường dẫn video hoặc âm thanh tại đây...';
  static const String pasteButton = 'Dán liên kết';
  static const String analyzeButton = 'Tải Video/Audio';
  static const String analyzing = 'Phân tích link';
  static const String clipboardDetected = 'Phát hiện liên kết mới trong bộ nhớ tạm!';
  static const String clickToAnalyze = 'Chạm để nạp và phân tích ngay';
  static const String supportedPlatforms = 'Nền tảng hỗ trợ';
  static const String recentDownloads = 'Đang tải gần đây';
  static const String viewAll = 'Xem tất cả';

  // Các nền tảng thuần Việt
  static const String platformYoutube = 'Kênh YouTube';
  static const String platformTiktok = 'Video TikTok';
  static const String platformFacebook = 'Mạng Facebook';
  static const String platformInstagram = 'Ảnh/Video Instagram';
  static const String platformTwitter = 'Mạng xã hội X';
  static const String platformVimeo = 'Kênh Vimeo';
  static const String platformDirect = 'Liên kết tệp trực tiếp';

  // Bảng chọn định dạng (Analyze Sheet)
  static const String previewMedia = 'Xem trước nội dung';
  static const String tabVideo = 'Hình ảnh & Video';
  static const String tabAudio = 'Âm thanh & Nhạc';
  static const String selectQuality = 'Lựa chọn chất lượng';
  static const String convertToMp3 = 'Chuyển sang tệp âm thanh chuẩn (MP3)';
  static const String convertToMp3Hint = 'Đảm bảo tương thích với mọi thiết bị và loa ngoài';
  static const String downloadNow = 'Tải về máy ngay';
  static const String playNow = 'Xem / Nghe thử';
  static const String resolutionSuper = 'Siêu nét (1080p)';
  static const String resolutionHigh = 'Sắc nét (720p)';
  static const String resolutionStandard = 'Tiêu chuẩn (480p)';
  static const String resolutionEconomy = 'Tiết kiệm (360p)';
  static const String audioStudio = 'Chất lượng phòng thu (320 kb/giây)';
  static const String audioHigh = 'Chất lượng cao (256 kb/giây)';
  static const String audioStandard = 'Chất lượng chuẩn (192 kb/giây)';
  static const String audioEconomy = 'Tiết kiệm bộ nhớ (128 kb/giây)';
  static const String badgeBest = 'Tốt nhất';
  static const String badgeRecommended = 'Khuyên dùng';
  static const String badgeSmallSize = 'Nhẹ máy';
  static const String estimatedSize = 'Dung lượng ước tính';

  // Quản lý tải xuống (Downloads)
  static const String downloadManagement = 'Quản lý tải về';
  static const String tabAll = 'Tất cả';
  static const String tabDownloading = 'Đang tiến hành';
  static const String tabCompleted = 'Đã tải xong';
  static const String noDownloads = 'Chưa có tệp nào được tải';
  static const String noDownloadsDesc = 'Hãy quay lại Trang chủ và dán liên kết để bắt đầu tải về máy.';
  static const String clearCompleted = 'Dọn danh sách đã xong';
  static const String clearConfirmTitle = 'Dọn dẹp danh sách đã tải?';
  static const String clearConfirmContent = 'Thao tác này chỉ xóa danh sách hiển thị, các tệp đã lưu trong máy vẫn được giữ nguyên vẹn.';
  static const String statusQueued = 'Đang xếp hàng chờ';
  static const String statusDownloading = 'Đang tải dữ liệu...';
  static const String statusMerging = 'Đang ghép luồng hình ảnh và âm thanh...';
  static const String statusConverting = 'Đang chuyển đổi sang định dạng mong muốn...';
  static const String statusCompleted = 'Đã tải hoàn tất';
  static const String statusFailed = 'Gặp sự cố, chạm để thử lại';
  static const String cancelTask = 'Hủy tải';
  static const String retryTask = 'Thử lại';
  static const String deleteTask = 'Xóa tệp khỏi máy';

  // Kho thư viện (Library)
  static const String musicHub = 'Kho bài hát';
  static const String videoHub = 'Kho video';
  static const String allTracks = 'Tất cả';
  static const String favorites = 'Nhạc Yêu thích';
  static const String playlists = 'Danh sách playlist';
  static const String searchPlaceholder = 'Tìm theo tên bài hát hoặc nghệ sĩ...';
  static const String emptyMusic = 'Chưa có bản nhạc nào';
  static const String emptyMusicDesc = 'Những tệp âm thanh bạn tải về sẽ tự động xuất hiện tại đây.';
  static const String emptyVideo = 'Chưa có video nào';
  static const String emptyVideoDesc = 'Những video bạn tải về sẽ được lưu giữ tại đây.';
  static const String createPlaylist = 'Tạo danh sách mới';
  static const String playlistName = 'Tên danh sách phát';
  static const String save = 'Lưu lại';
  static const String cancel = 'Hủy bỏ';
  static const String delete = 'Xóa';
  static const String deleteConfirm = 'Bạn có chắc chắn muốn xóa tệp này khỏi thiết bị?';

  // Trình phát phương tiện (Player)
  static const String musicPlayer = 'Trình phát nhạc';
  static const String videoPlayer = 'Trình phát video';
  static const String nowPlaying = 'Đang phát';
  static const String playbackSpeed = 'Tốc độ phát';
  static const String speedNormal = 'Chuẩn 1.0x';
  static const String repeatAll = 'Lặp lại toàn bộ';
  static const String repeatOne = 'Lặp lại một bài';
  static const String repeatOff = 'Không lặp lại';
  static const String shuffleOn = 'Trộn bài ngẫu nhiên: Bật';
  static const String shuffleOff = 'Trộn bài ngẫu nhiên: Tắt';
  static const String nextTrack = 'Bài kế tiếp';
  static const String prevTrack = 'Bài phía trước';
  static const String play = 'Phát';
  static const String pause = 'Tạm dừng';
  static const String pipMode = 'Thu nhỏ góc màn hình';

  // Quản lý bộ nhớ & Cài đặt (Settings & Storage)
  static const String storageCenter = 'Quản lý dung lượng & Thiết bị';
  static const String totalUsed = 'Tổng dung lượng đã dùng';
  static const String audioStorage = 'Bộ nhớ bài hát';
  static const String videoStorage = 'Bộ nhớ video';
  static const String artworkStorage = 'Ảnh bìa tác phẩm';
  static const String tempStorage = 'Tệp tạm & Bộ nhớ đệm';
  static const String cleanCacheButton = 'Xóa tệp tạm & Bộ nhớ đệm';
  static const String cleanCacheConfirm = 'Thao tác này sẽ dọn sạch các tệp tạm thời không còn sử dụng để giải phóng bộ nhớ. CÁC BẢN NHẠC VÀ VIDEO BẠN ĐÃ TẢI SẼ ĐƯỢC BẢO TOÀN TUYỆT ĐỐI.';
  static const String cleanCacheSuccess = 'Đã dọn dẹp sạch sẽ bộ nhớ đệm!';
  static const String themeToggle = 'Giao diện hiển thị';
  static const String themeDark = 'Chế độ Ban đêm (Tối)';
  static const String themeLight = 'Chế độ Ban ngày (Sáng)';
  static const String themeSystem = 'Tự động theo hệ thống';

  // Đơn vị đo thuần Việt
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String formatSpeed(int bytesPerSec) {
    if (bytesPerSec <= 0) return '0 KB/giây';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/giây';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(2)} MB/giây';
  }

  static String formatEta(int seconds) {
    if (seconds <= 0) return 'Chờ giây lát...';
    if (seconds < 60) return 'còn $seconds giây';
    final minutes = seconds ~/ 60;
    final remainingSecs = seconds % 60;
    return 'còn $minutes phút $remainingSecs giây';
  }
}
