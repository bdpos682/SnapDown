import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/storage/storage_manager.dart';
import '../../../core/theme/theme_provider.dart';
import '../../resolver/domain/resolver_registry.dart';
import '../../settings/presentation/storage_settings_screen.dart';
import 'analyze_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  final StorageManager _storage = StorageManager();

  bool _isAnalyzing = false;
  String _detectedPlatform = '';
  String _formattedStorage = '0 B';

  late final AnimationController _glowAnimController;

  @override
  void initState() {
    super.initState();
    _glowAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _urlController.addListener(_onUrlChanged);
    _loadStorageUsage();
  }

  @override
  void dispose() {
    _glowAnimController.dispose();
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    final text = _urlController.text.trim().toLowerCase();
    String detected = '';
    if (text.contains('youtube.com') || text.contains('youtu.be')) {
      detected = 'youtube';
    } else if (text.contains('tiktok.com') || text.contains('douyin.com')) {
      detected = 'tiktok';
    } else if (text.contains('facebook.com') || text.contains('fb.watch') || text.contains('fb.com')) {
      detected = 'facebook';
    } else if (text.contains('instagram.com')) {
      detected = 'instagram';
    } else if (text.contains('twitter.com') || text.contains('x.com')) {
      detected = 'twitter';
    } else if (text.contains('vimeo.com')) {
      detected = 'vimeo';
    } else if (text.endsWith('.mp4') || text.endsWith('.mp3') || text.endsWith('.m4a')) {
      detected = 'direct';
    }

    if (detected != _detectedPlatform) {
      setState(() {
        _detectedPlatform = detected;
      });
    }
  }

  Future<void> _loadStorageUsage() async {
    final breakdown = await _storage.getStorageBreakdown();
    if (mounted) {
      setState(() => _formattedStorage = breakdown.formattedTotal);
    }
  }

  Future<void> _pasteFromClipboard() async {
    HapticFeedback.selectionClick();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _urlController.text = data.text!.trim();
      });
      _analyzeUrl();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bộ nhớ tạm trống! Hãy sao chép liên kết video trước.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _analyzeUrl([String? directUrl]) async {
    final rawText = directUrl ?? _urlController.text.trim();
    if (rawText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập hoặc dán liên kết media')),
      );
      return;
    }

    final uri = Uri.tryParse(rawText);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Định dạng liên kết không hợp lệ. Ví dụ: https://youtube.com/...')),
      );
      return;
    }

    setState(() => _isAnalyzing = true);
    HapticFeedback.mediumImpact();

    try {
      final info = await ResolverRegistry().analyze(uri);
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AnalyzeSheet(mediaInfo: info),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi trích xuất: $e'),
            backgroundColor: AppColors.accentRed,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final primaryAccent = isDark ? AppColors.accentCyan : AppColors.accentBlue;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // 1. Dynamic Ambient Aura Mesh in Background
          _buildBackgroundAura(isDark),

          // 2. Main Scrollable Interface
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),

                  // TOP BRANDING & ENGINE TELEMETRY BAR
                  _buildBrandHeader(isDark, textPrimary, textSecondary, primaryAccent),

                  const SizedBox(height: 20),

                  // HERO SMART MEDIA DROPZONE CONSOLE
                  _buildHeroConsole(isDark, textPrimary, textSecondary, primaryAccent),

                  const SizedBox(height: 28),

                  // PLATFORM MATRIX (6 Interactive 3D Cards)
                  _buildPlatformMatrix(isDark, textPrimary, textSecondary, primaryAccent),

                  const SizedBox(height: 28),

                  // STUDIO PRO ENGINE CAPABILITIES (4 Luxury Feature Cards)
                  _buildStudioCapabilities(isDark, textPrimary, textSecondary, primaryAccent),

                  const SizedBox(height: 24),

                  // SYSTEM STATUS & STORAGE TELEMETRY CARD
                  _buildSystemTelemetryCard(isDark, textPrimary, textSecondary, primaryAccent),

                  const SizedBox(height: 120), // Bottom padding for dock
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // MARK: - Ambient Mesh Background
  Widget _buildBackgroundAura(bool isDark) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _glowAnimController,
          builder: (context, _) {
            final t = _glowAnimController.value;
            return Stack(
              children: [
                Positioned(
                  top: -80 + (t * 20),
                  left: -60,
                  width: 320,
                  height: 320,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          (isDark ? AppColors.accentCyan : AppColors.accentBlue).withAlpha(isDark ? 45 : 25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 280 - (t * 25),
                  right: -80,
                  width: 340,
                  height: 340,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          (isDark ? AppColors.accentPurple : const Color(0xFF6366F1)).withAlpha(isDark ? 40 : 20),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // MARK: - Brand Header & Engine Telemetry
  Widget _buildBrandHeader(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color primaryAccent,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            // Glowing Bolt Brand Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [AppColors.accentAmber, Color(0xFFFF5722)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentAmber.withAlpha(isDark ? 90 : 50),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'SNAPDOWN',
                      style: AppTypography.h2.copyWith(
                        color: textPrimary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryAccent.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: primaryAccent.withAlpha(80), width: 0.8),
                      ),
                      child: Text(
                        'STUDIO PRO',
                        style: TextStyle(
                          color: primaryAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.accentGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ENGINE SẴN SÀNG • 4K HDR',
                      style: TextStyle(
                        fontSize: 11,
                        color: textSecondary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Quick Controls: Theme Toggle & Storage
        Row(
          children: [
            // Theme Switcher
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkElevated : AppColors.lightElevated,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorder,
                ),
              ),
              child: IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: isDark ? AppColors.accentAmber : textPrimary,
                  size: 20,
                ),
                tooltip: 'Đổi giao diện Sáng / Tối',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ref.read(themeModeProvider.notifier).toggleTheme();
                },
              ),
            ),
            const SizedBox(width: 8),
            // Storage Settings
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkElevated : AppColors.lightElevated,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorder,
                ),
              ),
              child: IconButton(
                icon: Icon(Icons.storage_rounded, color: textPrimary, size: 20),
                tooltip: 'Bộ nhớ thiết bị',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StorageSettingsScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // MARK: - Hero Smart Media Dropzone Console
  Widget _buildHeroConsole(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color primaryAccent,
  ) {
    return AnimatedBuilder(
      animation: _glowAnimController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      AppColors.accentCyan.withAlpha((40 + (_glowAnimController.value * 25)).toInt()),
                      AppColors.accentPurple.withAlpha((35 + ((1 - _glowAnimController.value) * 25)).toInt()),
                    ]
                  : [
                      Colors.white,
                      Colors.white.withAlpha(240),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? AppColors.accentCyan : AppColors.accentBlue)
                    .withAlpha(isDark ? (40 + (_glowAnimController.value * 25)).toInt() : 20),
                blurRadius: 28,
                offset: const Offset(0, 10),
                spreadRadius: -2,
              ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(50)
                  : primaryAccent.withAlpha(60),
              width: 1.5,
            ),
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryAccent.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: primaryAccent, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        'BỘ TRÍCH XUẤT MEDIA CHUYÊN NGHIỆP',
                        style: TextStyle(
                          color: primaryAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              'Tải Video 4K & Âm Thanh Lossless',
              style: AppTypography.h1.copyWith(
                color: textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Phân giải trực tiếp trên thiết bị • Không nén giảm chất lượng',
              style: AppTypography.bodySmall.copyWith(color: textSecondary, fontSize: 13),
            ),

            const SizedBox(height: 20),

            // High-Tech Input Box
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground.withAlpha(200) : AppColors.lightElevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _detectedPlatform.isNotEmpty
                      ? _getPlatformColor(_detectedPlatform)
                      : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorder),
                  width: _detectedPlatform.isNotEmpty ? 1.6 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  // Dynamic Platform Icon
                  _buildPlatformLeadingIcon(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      style: AppTypography.bodyMedium.copyWith(color: textPrimary, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Dán liên kết video hoặc audio...',
                        hintStyle: TextStyle(color: textSecondary.withAlpha(140), fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onSubmitted: (_) => _analyzeUrl(),
                    ),
                  ),

                  // Clear or Paste Button
                  if (_urlController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: textSecondary,
                      onPressed: () {
                        _urlController.clear();
                        setState(() => _detectedPlatform = '');
                      },
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryAccent.withAlpha(35),
                          foregroundColor: primaryAccent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _pasteFromClipboard,
                        icon: const Icon(Icons.content_paste_rounded, size: 16),
                        label: const Text('Dán', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Primary Extract Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? primaryAccent : AppColors.accentBlue,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shadowColor: primaryAccent.withAlpha(120),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _isAnalyzing ? null : () => _analyzeUrl(),
                child: _isAnalyzing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          ),
                          SizedBox(width: 12),
                          Text('Đang phân giải luồng media...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt_rounded, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'PHÂN TÍCH & TRÍCH XUẤT NGAY',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformLeadingIcon() {
    if (_detectedPlatform == 'youtube') {
      return const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFFF0000), size: 24);
    } else if (_detectedPlatform == 'tiktok') {
      return const Icon(Icons.music_note_rounded, color: Color(0xFF00F2FE), size: 24);
    } else if (_detectedPlatform == 'facebook') {
      return const Icon(Icons.facebook_rounded, color: Color(0xFF1877F2), size: 24);
    } else if (_detectedPlatform == 'instagram') {
      return const Icon(Icons.camera_alt_rounded, color: Color(0xFFE1306C), size: 24);
    } else if (_detectedPlatform == 'twitter') {
      return const Icon(Icons.alternate_email_rounded, color: Color(0xFF1DA1F2), size: 24);
    }
    return const Icon(Icons.link_rounded, color: AppColors.accentCyan, size: 22);
  }

  Color _getPlatformColor(String platform) {
    switch (platform) {
      case 'youtube':
        return const Color(0xFFFF0000);
      case 'tiktok':
        return const Color(0xFF00F2FE);
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'instagram':
        return const Color(0xFFE1306C);
      case 'twitter':
        return const Color(0xFF1DA1F2);
      default:
        return AppColors.accentCyan;
    }
  }

  // MARK: - Platform Matrix (6 Interactive Cards)
  Widget _buildPlatformMatrix(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color primaryAccent,
  ) {
    final platforms = [
      {
        'id': 'youtube',
        'name': 'YouTube',
        'badge': '4K 60fps & 320k',
        'desc': 'Video, Audio & Shorts',
        'icon': Icons.play_circle_fill_rounded,
        'color': const Color(0xFFFF0000),
      },
      {
        'id': 'tiktok',
        'name': 'TikTok',
        'badge': 'Không Logo',
        'desc': 'Video HD & Âm thanh gốc',
        'icon': Icons.music_note_rounded,
        'color': const Color(0xFF00F2FE),
      },
      {
        'id': 'facebook',
        'name': 'Facebook',
        'badge': 'Full HD 1080p',
        'desc': 'Reels, Watch & Story',
        'icon': Icons.facebook_rounded,
        'color': const Color(0xFF1877F2),
      },
      {
        'id': 'instagram',
        'name': 'Instagram',
        'badge': 'Gốc Lossless',
        'desc': 'Reels, Bài viết & Audio',
        'icon': Icons.camera_alt_rounded,
        'color': const Color(0xFFE1306C),
      },
      {
        'id': 'twitter',
        'name': 'X / Twitter',
        'badge': 'MP4 Nguyên Bản',
        'desc': 'Video bài đăng & GIF',
        'icon': Icons.alternate_email_rounded,
        'color': const Color(0xFF1DA1F2),
      },
      {
        'id': 'vimeo',
        'name': 'Vimeo & Web',
        'badge': 'Tự Động Bắt Link',
        'desc': 'HLS, M3U8 & Direct MP4',
        'icon': Icons.language_rounded,
        'color': const Color(0xFF1AB7EA),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'NỀN TẢNG HỖ TRỢ ĐỈNH CAO',
              style: TextStyle(
                color: textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'TỰ ĐỘNG NHẬN DIỆN',
                style: TextStyle(
                  color: AppColors.accentGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: platforms.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          itemBuilder: (context, index) {
            final p = platforms[index];
            final color = p['color'] as Color;
            final icon = p['icon'] as IconData;

            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? color.withAlpha(45) : color.withAlpha(35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withAlpha(isDark ? 15 : 8),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: color.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            p['badge'] as String,
                            style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['name'] as String,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          p['desc'] as String,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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

  // MARK: - Studio Capabilities
  Widget _buildStudioCapabilities(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color primaryAccent,
  ) {
    final features = [
      {
        'title': 'Trích Xuất Âm Thanh Studio',
        'desc': 'Tách nhạc 320kbps AAC / MP3 Lossless siêu tốc trong 0.2s',
        'icon': Icons.graphic_eq_rounded,
        'color': AppColors.accentCyan,
      },
      {
        'title': 'Băng Thông Không Giới Hạn',
        'desc': 'Tải song song đa luồng trực tiếp, xóa bỏ hoàn toàn giới hạn tốc độ',
        'icon': Icons.speed_rounded,
        'color': AppColors.accentAmber,
      },
      {
        'title': 'Phát Chạy Ngầm Khóa Màn Hình',
        'desc': 'Tắt màn hình hoặc chuyển app vẫn tiếp tục phát nhạc mượt mà',
        'icon': Icons.headphones_rounded,
        'color': AppColors.accentGreen,
      },
      {
        'title': 'Bảo Mật & Riêng Tư Tuyệt Đối',
        'desc': 'Không lưu trữ đám mây, 100% dữ liệu xử lý trực tiếp trên điện thoại',
        'icon': Icons.security_rounded,
        'color': const Color(0xFF8B5CF6),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TÍNH NĂNG ĐỘC QUYỀN STUDIO',
          style: TextStyle(
            color: textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 14),

        ...features.map((f) {
          final color = f['color'] as Color;
          final icon = f['icon'] as IconData;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f['title'] as String,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        f['desc'] as String,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // MARK: - System Telemetry Card
  Widget _buildSystemTelemetryCard(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color primaryAccent,
  ) {
    final formattedStorage = _formattedStorage;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_done_rounded, color: AppColors.accentCyan, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bộ Nhớ Media SnapDown',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    'Đã lưu trữ: $formattedStorage tệp ngoại tuyến',
                    style: TextStyle(color: textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StorageSettingsScreen()),
              );
            },
            child: const Text('Quản lý', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
