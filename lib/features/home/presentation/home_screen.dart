import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  final StorageManager _storage = StorageManager();

  bool _isAnalyzing = false;
  String _detectedPlatform = '';
  String _formattedStorage = '0 B';

  late final AnimationController _ambientController;
  late final AnimationController _introController;
  late final AnimationController _shineController;

  OverlayEntry? _noticeEntry;
  Timer? _noticeTimer;

  @override
  void initState() {
    super.initState();

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    )..forward();

    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _urlController.addListener(_onUrlChanged);
    _urlFocusNode.addListener(_onFocusChanged);
    _loadStorageUsage();
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _noticeEntry?.remove();
    _ambientController.dispose();
    _introController.dispose();
    _shineController.dispose();
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _urlFocusNode.removeListener(_onFocusChanged);
    _urlFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _onUrlChanged() {
    final text = _urlController.text.trim().toLowerCase();
    String detected = '';

    if (text.contains('youtube.com') || text.contains('youtu.be')) {
      detected = 'youtube';
    } else if (text.contains('tiktok.com') || text.contains('douyin.com')) {
      detected = 'tiktok';
    } else if (text.contains('facebook.com') ||
        text.contains('fb.watch') ||
        text.contains('fb.com')) {
      detected = 'facebook';
    } else if (text.contains('instagram.com')) {
      detected = 'instagram';
    } else if (text.contains('twitter.com') || text.contains('x.com')) {
      detected = 'twitter';
    } else if (text.contains('vimeo.com')) {
      detected = 'vimeo';
    } else if (text.endsWith('.mp4') ||
        text.endsWith('.mp3') ||
        text.endsWith('.m4a')) {
      detected = 'direct';
    }

    if (!mounted) return;
    setState(() => _detectedPlatform = detected);
  }

  Future<void> _loadStorageUsage() async {
    final breakdown = await _storage.getStorageBreakdown();
    if (!mounted) return;
    setState(() => _formattedStorage = breakdown.formattedTotal);
  }

  Future<void> _pasteFromClipboard() async {
    HapticFeedback.selectionClick();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';

    if (text.isEmpty) {
      _showNotice(
        title: 'Bộ nhớ tạm đang trống',
        message: 'Hãy sao chép một liên kết video hoặc âm thanh trước.',
        icon: Icons.content_paste_off_rounded,
        tone: _NoticeTone.warning,
      );
      return;
    }

    _urlController.text = text;
    _urlController.selection = TextSelection.collapsed(offset: text.length);
    _urlFocusNode.unfocus();
    await _analyzeUrl();
  }

  Future<void> _analyzeUrl([String? directUrl]) async {
    final rawText = directUrl ?? _urlController.text.trim();

    if (rawText.isEmpty) {
      HapticFeedback.lightImpact();
      _showNotice(
        title: 'Chưa có liên kết',
        message: 'Dán liên kết cần tải vào ô trung tâm để bắt đầu.',
        icon: Icons.link_off_rounded,
        tone: _NoticeTone.info,
      );
      return;
    }

    final uri = Uri.tryParse(rawText);
    if (uri == null || !uri.hasScheme) {
      HapticFeedback.lightImpact();
      _showNotice(
        title: 'Liên kết không hợp lệ',
        message: 'Liên kết cần bắt đầu bằng https:// hoặc http://',
        icon: Icons.error_outline_rounded,
        tone: _NoticeTone.warning,
      );
      return;
    }

    if (_isAnalyzing) return;

    setState(() => _isAnalyzing = true);
    _urlFocusNode.unfocus();
    HapticFeedback.mediumImpact();

    try {
      final info = await ResolverRegistry().analyze(uri);
      if (!mounted) return;

      HapticFeedback.selectionClick();
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withAlpha(190),
        elevation: 0,
        enableDrag: true,
        clipBehavior: Clip.none,
        sheetAnimationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 460),
          reverseDuration: Duration(milliseconds: 280),
        ),
        builder: (_) => AnalyzeSheet(mediaInfo: info),
      );
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _showNotice(
        title: 'Không thể phân tích liên kết',
        message: '$e',
        icon: Icons.warning_amber_rounded,
        tone: _NoticeTone.error,
        duration: const Duration(seconds: 4),
      );
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _showNotice({
    required String title,
    required String message,
    required IconData icon,
    required _NoticeTone tone,
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    if (!mounted) return;

    _noticeTimer?.cancel();
    _noticeEntry?.remove();

    final overlay = Overlay.of(context, rootOverlay: true);
    _noticeEntry = OverlayEntry(
      builder: (overlayContext) {
        return _FloatingNotice(
          title: title,
          message: message,
          icon: icon,
          tone: tone,
        );
      },
    );

    overlay.insert(_noticeEntry!);
    _noticeTimer = Timer(duration, () {
      _noticeEntry?.remove();
      _noticeEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _BDSnapColors.resolve(isDark);

    return Scaffold(
      backgroundColor: colors.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(child: _buildBackground(colors, isDark)),
          SafeArea(
            bottom: false, // Bỏ safeArea bottom để tự kiểm soát padding với Dock
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                final isWide = width >= 760;
                final isVeryWide = width >= 1080;
                final compactHeight = height < 650;
                final tinyHeight = height < 560;

                final side = isVeryWide ? 34.0 : isWide ? 26.0 : 16.0;
                final top = tinyHeight ? 10.0 : 16.0;

                // TĂNG PADDING BOTTOM LÊN 100 ĐỂ KHÔNG BỊ DÍNH VÀO DOCK CỦA BẠN
                final bottom = tinyHeight ? 80.0 : 100.0;

                return Padding(
                  padding: EdgeInsets.fromLTRB(side, top, side, bottom),
                  child: Column(
                    children: [
                      _intro(
                        index: 0,
                        child: _buildHeader(
                          colors: colors,
                          isDark: isDark,
                          compactHeight: compactHeight,
                          isWide: isWide,
                        ),
                      ),
                      SizedBox(height: tinyHeight ? 10 : 16),
                      Expanded(
                        child: _intro(
                          index: 1,
                          child: isWide
                              ? _buildWideStage(
                            colors: colors,
                            isDark: isDark,
                            isWide: isWide,
                            compactHeight: compactHeight,
                            tinyHeight: tinyHeight,
                          )
                              : _buildCompactStage(
                            colors: colors,
                            isDark: isDark,
                            isWide: isWide,
                            compactHeight: compactHeight,
                            tinyHeight: tinyHeight,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _intro({required int index, required Widget child}) {
    final start = (index * 0.08).clamp(0.0, 0.32).toDouble();
    final end = (start + 0.62).clamp(0.62, 1.0).toDouble();
    final animation = CurvedAnimation(
      parent: _introController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.025),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  Widget _buildBackground(_BDSnapColors colors, bool isDark) {
    return AnimatedBuilder(
      animation: _ambientController,
      builder: (context, _) {
        final t = _ambientController.value;
        final phase = t * 6.28318530718;
        final dx = 34 * _fastSin(phase);
        final dy = 20 * _fastCos(phase * 0.8);

        return Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: colors.background)),
            Positioned.fill(
              child: CustomPaint(
                painter: _StudioGridPainter(
                  lineColor: colors.grid,
                  vignetteColor: colors.background,
                ),
              ),
            ),
            Positioned(
              top: -180 + dy,
              left: -130 + dx,
              child: _BlurOrb(
                size: 410,
                color: colors.brand,
                opacity: isDark ? 0.17 : 0.11,
              ),
            ),
            Positioned(
              right: -220 - dx,
              top: 120 - dy,
              child: _BlurOrb(
                size: 520,
                color: colors.violet,
                opacity: isDark ? 0.10 : 0.07,
              ),
            ),
            Positioned(
              left: 80 - dx,
              bottom: -300 + dy,
              child: _BlurOrb(
                size: 560,
                color: colors.cyan,
                opacity: isDark ? 0.075 : 0.055,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.background.withAlpha(8),
                      colors.background.withAlpha(65),
                      colors.background.withAlpha(isDark ? 176 : 130),
                    ],
                    stops: const [0.0, 0.58, 1.0],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _fastSin(double x) {
    final wrapped = x % 6.28318530718;
    if (wrapped < 3.14159265359) {
      final y = wrapped / 3.14159265359;
      return 4 * y * (1 - y);
    }
    final y = (wrapped - 3.14159265359) / 3.14159265359;
    return -4 * y * (1 - y);
  }

  double _fastCos(double x) => _fastSin(x + 1.57079632679);

  Widget _buildHeader({
    required _BDSnapColors colors,
    required bool isDark,
    required bool compactHeight,
    required bool isWide,
  }) {
    final logoSize = compactHeight ? 42.0 : 46.0;

    return SizedBox(
      height: compactHeight ? 48 : 54,
      child: Row(
        children: [
          Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.brandBright, colors.brand],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: colors.brand.withAlpha(isDark ? 72 : 44),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  'B',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compactHeight ? 20 : 22,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.4,
                  ),
                ),
                Positioned(
                  right: 7,
                  bottom: 7,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.arrow_downward_rounded,
                      size: 8,
                      color: colors.brandDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BDSNAP',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: compactHeight ? 17 : 18.5,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Trình tải đa nền tảng',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: compactHeight ? 9.3 : 10.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isWide) ...[
                  const SizedBox(width: 18),
                  _headerMetaPill(
                    colors: colors,
                    icon: Icons.bolt_rounded,
                    label: 'Sẵn sàng',
                    accent: colors.success,
                  ),
                  const SizedBox(width: 8),
                  _headerMetaPill(
                    colors: colors,
                    icon: Icons.cloud_done_rounded,
                    label: 'Tự nhận diện',
                    accent: colors.brand,
                  ),
                ],
              ],
            ),
          ),
          _headerIconButton(
            colors: colors,
            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            tooltip: 'Đổi giao diện',
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),
          const SizedBox(width: 8),
          _headerIconButton(
            colors: colors,
            icon: Icons.folder_open_rounded,
            tooltip: 'Quản lý bộ nhớ',
            onTap: () async {
              HapticFeedback.selectionClick();
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StorageSettingsScreen(),
                ),
              );
              if (mounted) await _loadStorageUsage();
            },
          ),
        ],
      ),
    );
  }

  Widget _headerMetaPill({
    required _BDSnapColors colors,
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: colors.surfaceLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton({
    required _BDSnapColors colors,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.borderSoft),
                ),
                child: Icon(icon, size: 18, color: colors.textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideStage({
    required _BDSnapColors colors,
    required bool isDark,
    required bool isWide,
    required bool compactHeight,
    required bool tinyHeight,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 9,
          child: _buildEditorialHero(
            colors: colors,
            compactHeight: compactHeight,
            tinyHeight: tinyHeight,
          ),
        ),
        SizedBox(width: compactHeight ? 18 : 24),
        Expanded(
          flex: 11,
          child: _buildWorkspace(
            colors: colors,
            isDark: isDark,
            isWide: isWide,
            compactHeight: compactHeight,
            tinyHeight: tinyHeight,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStage({
    required _BDSnapColors colors,
    required bool isDark,
    required bool isWide,
    required bool compactHeight,
    required bool tinyHeight,
  }) {
    return Column(
      children: [
        _buildCompactHero(
          colors: colors,
          compactHeight: compactHeight,
          tinyHeight: tinyHeight,
        ),
        SizedBox(height: tinyHeight ? 10 : 14),
        Expanded(
          child: _buildWorkspace(
            colors: colors,
            isDark: isDark,
            isWide: isWide,
            compactHeight: compactHeight,
            tinyHeight: tinyHeight,
          ),
        ),
      ],
    );
  }

  Widget _buildEditorialHero({
    required _BDSnapColors colors,
    required bool compactHeight,
    required bool tinyHeight,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(tinyHeight ? 18 : compactHeight ? 22 : 28),
      decoration: BoxDecoration(
        color: colors.heroSurface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            bottom: -40,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.055,
                child: Icon(
                  Icons.download_for_offline_rounded,
                  size: compactHeight ? 210 : 260,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionEyebrow(
                colors: colors,
                icon: Icons.auto_awesome_rounded,
                text: 'TẢI NHANH · GIỮ NGUYÊN CHẤT LƯỢNG',
              ),
              const Spacer(),
              Text(
                'Một liên kết.\nMọi nội dung.',
                maxLines: 2,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: tinyHeight ? 30 : compactHeight ? 36 : 44,
                  height: 0.98,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.9,
                ),
              ),
              SizedBox(height: compactHeight ? 12 : 16),
              Text(
                'Dán liên kết từ nền tảng bạn muốn. BDSNAP tự nhận diện nguồn và chuẩn bị lựa chọn video hoặc âm thanh phù hợp.',
                maxLines: compactHeight ? 3 : 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: compactHeight ? 11.2 : 12.4,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: compactHeight ? 14 : 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _featureTag(colors, Icons.high_quality_rounded, 'Tối đa 4K'),
                  _featureTag(colors, Icons.graphic_eq_rounded, 'Âm thanh gốc'),
                  _featureTag(colors, Icons.compress_rounded, 'Không nén lại'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHero({
    required _BDSnapColors colors,
    required bool compactHeight,
    required bool tinyHeight,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 4,
        vertical: tinyHeight ? 4 : 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Tiêu đề căn trái mạnh mẽ, gọn gàng
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tải nhanh đa nền tảng',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: tinyHeight ? 18 : 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'YouTube, TikTok, Facebook, Instagram...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: tinyHeight ? 10.5 : 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Huy hiệu chất lượng gọn đẹp bên phải
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surfaceLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.borderSoft),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, size: 13, color: colors.success),
                const SizedBox(width: 5),
                Text(
                  '4K & MP3',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroTag(_BDSnapColors colors, String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colors.textSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }


  Widget _sectionEyebrow({
    required _BDSnapColors colors,
    required IconData icon,
    required String text,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.brandBright),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.brandBright,
              fontSize: 9.2,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _featureTag(_BDSnapColors colors, IconData icon, String text) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: colors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.textSecondary),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspace({
    required _BDSnapColors colors,
    required bool isDark,
    required bool isWide,
    required bool compactHeight,
    required bool tinyHeight,
  }) {
    final platform = _platformMeta(_detectedPlatform, isDark);
    final hasText = _urlController.text.trim().isNotEmpty;
    final focused = _urlFocusNode.hasFocus;
    final accent = _detectedPlatform.isEmpty ? colors.brand : platform.color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        tinyHeight ? 14 : compactHeight ? 18 : 22,
        tinyHeight ? 14 : compactHeight ? 18 : 22,
        tinyHeight ? 14 : compactHeight ? 18 : 22,
        tinyHeight ? 13 : compactHeight ? 17 : 20,
      ),
      decoration: BoxDecoration(
        color: colors.workspace,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: focused ? accent.withAlpha(isDark ? 118 : 92) : colors.border,
          width: focused ? 1.25 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 54 : 18),
            blurRadius: 38,
            offset: const Offset(0, 18),
          ),
          if (focused || _detectedPlatform.isNotEmpty)
            BoxShadow(
              color: accent.withAlpha(isDark ? 24 : 18),
              blurRadius: 34,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRUNG TÂM TẢI XUỐNG',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: tinyHeight ? 10.4 : 11.2,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (!tinyHeight) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Dán liên kết, BDSNAP lo phần còn lại.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 9.6,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: accent.withAlpha(isDark ? 24 : 18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withAlpha(52)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(platform.icon, size: 13, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      _detectedPlatform.isEmpty ? 'Tự động' : platform.name,
                      style: TextStyle(
                        color: accent,
                        fontSize: 9.7,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: tinyHeight ? 10 : compactHeight ? 14 : 18),

          _buildPlatformRail(
            colors: colors,
            isDark: isDark,
            isWide: isWide,
            tinyHeight: tinyHeight,
          ),

          SizedBox(height: tinyHeight ? 10 : compactHeight ? 14 : 18),

          // Khối Input và Nút bấm nằm sát ngay dưới thanh Icon
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.all(tinyHeight ? 8 : 10),
                  decoration: BoxDecoration(
                    color: colors.inputShell,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: focused
                          ? accent.withAlpha(isDark ? 118 : 86)
                          : colors.borderSoft,
                      width: focused ? 1.2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: tinyHeight ? 42 : 48,
                        height: tinyHeight ? 42 : 48,
                        decoration: BoxDecoration(
                          color: accent.withAlpha(isDark ? 28 : 20),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          platform.icon,
                          size: tinyHeight ? 20 : 22,
                          color: accent,
                        ),
                      ),
                      SizedBox(width: tinyHeight ? 10 : 12),
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          focusNode: _urlFocusNode,
                          textInputAction: TextInputAction.go,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          enableSuggestions: false,
                          maxLines: 1,
                          onSubmitted: (_) => _analyzeUrl(),
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: tinyHeight ? 12.3 : 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Dán liên kết video hoặc âm thanh',
                            hintStyle: TextStyle(
                              color: colors.textMuted.withAlpha(170),
                              fontSize: tinyHeight ? 11.7 : 12.6,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (hasText)
                        _smallInputAction(
                          colors: colors,
                          icon: Icons.close_rounded,
                          tooltip: 'Xóa liên kết',
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _urlController.clear();
                            _urlFocusNode.requestFocus();
                          },
                        )
                      else
                        _pasteButton(
                          colors: colors,
                          accent: accent,
                          compact: tinyHeight,
                        ),
                    ],
                  ),
                ),
                SizedBox(height: tinyHeight ? 9 : compactHeight ? 12 : 14),
                _buildAnalyzeButton(
                  colors: colors,
                  accent: accent,
                  tinyHeight: tinyHeight,
                ),
              ],
            ),
          ),

          // Spacer đẩy thanh trạng thái dưới cùng xuống mép dưới
          const Spacer(),

          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 13,
                color: colors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Liên kết chỉ được dùng để phân tích trong phiên hiện tại',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 9.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color: colors.surfaceLow,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colors.borderSoft),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sd_storage_outlined,
                      size: 12,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _formattedStorage,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 9.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallInputAction({
    required _BDSnapColors colors,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.surfaceLow,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: colors.borderSoft),
            ),
            child: Icon(icon, size: 18, color: colors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _pasteButton({
    required _BDSnapColors colors,
    required Color accent,
    required bool compact,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pasteFromClipboard,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
          decoration: BoxDecoration(
            color: accent.withAlpha(18),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: accent.withAlpha(42)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.content_paste_rounded, size: 15, color: accent),
              if (!compact) ...[
                const SizedBox(width: 6),
                Text(
                  'Dán',
                  style: TextStyle(
                    color: accent,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyzeButton({
    required _BDSnapColors colors,
    required Color accent,
    required bool tinyHeight,
  }) {
    return AnimatedBuilder(
      animation: _shineController,
      builder: (context, _) {
        final t = _shineController.value;

        return Container(
          height: tinyHeight ? 46 : 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            boxShadow: [
              BoxShadow(
                color: accent.withAlpha(58),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          colors.brandDark,
                          accent,
                          colors.brandBright,
                        ],
                      ),
                    ),
                  ),
                ),
                if (!_isAnalyzing)
                  Positioned(
                    top: -34,
                    bottom: -34,
                    left: -130 + (t * 700),
                    width: 90,
                    child: Transform.rotate(
                      angle: -0.25,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withAlpha(0),
                              Colors.white.withAlpha(55),
                              Colors.white.withAlpha(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isAnalyzing ? null : () => _analyzeUrl(),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _isAnalyzing
                              ? Row(
                            key: const ValueKey('analyzing'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Text(
                                'Đang phân tích...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: tinyHeight ? 12.2 : 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          )
                              : Row(
                            key: const ValueKey('analyze'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'PHÂN TÍCH LIÊN KẾT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: tinyHeight ? 11.8 : 12.7,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.65,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 17,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlatformRail({
    required _BDSnapColors colors,
    required bool isDark,
    required bool isWide,
    required bool tinyHeight,
  }) {
    final platforms = <_PlatformMeta>[
      _platformMeta('youtube', isDark),
      _platformMeta('tiktok', isDark),
      _platformMeta('facebook', isDark),
      _platformMeta('instagram', isDark),
      _platformMeta('twitter', isDark),
      _platformMeta('vimeo', isDark),
      _platformMeta('direct', isDark),
    ];

    return Container(
      height: tinyHeight ? 58 : 66,
      padding: EdgeInsets.symmetric(horizontal: tinyHeight ? 8 : 10),
      decoration: BoxDecoration(
        color: colors.rail,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Row(
        children: [
          if (isWide) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '7 NỀN TẢNG',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 9.2,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tự nhận diện nguồn',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 8.8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: colors.borderSoft,
            ),
          ],
          ...List.generate(platforms.length, (index) {
            final meta = platforms[index];
            final active = _detectedPlatform == meta.id;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 4 : 3,
                  right: index == platforms.length - 1 ? 4 : 3,
                ),
                child: Tooltip(
                  message: meta.name,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: tinyHeight ? 42 : 48,
                    decoration: BoxDecoration(
                      color: active
                          ? meta.color.withAlpha(isDark ? 27 : 20)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: active
                          ? Border.all(color: meta.color.withAlpha(68))
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: tinyHeight ? 28 : 31,
                          height: tinyHeight ? 28 : 31,
                          decoration: BoxDecoration(
                            color: meta.color.withAlpha(active ? 30 : 16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            meta.icon,
                            size: tinyHeight ? 15 : 16,
                            color: meta.color,
                          ),
                        ),
                        if (isWide) ...[
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              meta.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: active
                                    ? colors.textPrimary
                                    : colors.textSecondary,
                                fontSize: 9.3,
                                fontWeight: active
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  _PlatformMeta _platformMeta(String id, bool isDark) {
    switch (id) {
      case 'youtube':
        return const _PlatformMeta(
          id: 'youtube',
          name: 'YouTube',
          icon: Icons.play_arrow_rounded,
          color: Color(0xFFFF3B30),
        );
      case 'tiktok':
        return const _PlatformMeta(
          id: 'tiktok',
          name: 'TikTok',
          icon: Icons.music_note_rounded,
          color: Color(0xFF16C7BC),
        );
      case 'facebook':
        return const _PlatformMeta(
          id: 'facebook',
          name: 'Facebook',
          icon: Icons.facebook_rounded,
          color: Color(0xFF4386F5),
        );
      case 'instagram':
        return const _PlatformMeta(
          id: 'instagram',
          name: 'Instagram',
          icon: Icons.camera_alt_rounded,
          color: Color(0xFFE84A9B),
        );
      case 'twitter':
        return _PlatformMeta(
          id: 'twitter',
          name: 'X / Twitter',
          icon: Icons.alternate_email_rounded,
          color: isDark ? Colors.white : const Color(0xFF15171B),
        );
      case 'vimeo':
        return const _PlatformMeta(
          id: 'vimeo',
          name: 'Vimeo',
          icon: Icons.video_library_rounded,
          color: Color(0xFF2AA9E8),
        );
      case 'direct':
        return const _PlatformMeta(
          id: 'direct',
          name: 'Trang web',
          icon: Icons.language_rounded,
          color: Color(0xFF19A47C),
        );
      default:
        return const _PlatformMeta(
          id: '',
          name: 'Tự động',
          icon: Icons.link_rounded,
          color: Color(0xFF5E6CFF),
        );
    }
  }
}

class _FloatingNotice extends StatefulWidget {
  const _FloatingNotice({
    required this.title,
    required this.message,
    required this.icon,
    required this.tone,
  });

  final String title;
  final String message;
  final IconData icon;
  final _NoticeTone tone;

  @override
  State<_FloatingNotice> createState() => _FloatingNoticeState();
}

class _FloatingNoticeState extends State<_FloatingNotice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.22),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _BDSnapColors.resolve(isDark);
    final accent = switch (widget.tone) {
      _NoticeTone.info => colors.brandBright,
      _NoticeTone.warning => const Color(0xFFF3AA3D),
      _NoticeTone.error => const Color(0xFFFF5B63),
    };

    return Positioned(
      top: MediaQuery.paddingOf(context).top + 14,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
                        decoration: BoxDecoration(
                          color: colors.notice,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(isDark ? 76 : 22),
                              blurRadius: 32,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: accent.withAlpha(isDark ? 30 : 20),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(widget.icon, size: 19, color: accent),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 12.4,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    widget.message,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontSize: 10.3,
                                      height: 1.3,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudioGridPainter extends CustomPainter {
  const _StudioGridPainter({
    required this.lineColor,
    required this.vignetteColor,
  });

  final Color lineColor;
  final Color vignetteColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.6;

    const gap = 36.0;
    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final vignette = Paint()
      ..shader = RadialGradient(
        radius: 0.85,
        colors: [
          Colors.transparent,
          vignetteColor.withAlpha(90),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _StudioGridPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.vignetteColor != vignetteColor;
  }
}

class _BlurOrb extends StatelessWidget {
  const _BlurOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withAlpha((255 * opacity).round()),
          ),
        ),
      ),
    );
  }
}

class _PlatformMeta {
  const _PlatformMeta({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;
}

enum _NoticeTone { info, warning, error }

class _BDSnapColors {
  const _BDSnapColors({
    required this.background,
    required this.surface,
    required this.surfaceLow,
    required this.heroSurface,
    required this.workspace,
    required this.inputShell,
    required this.rail,
    required this.notice,
    required this.border,
    required this.borderSoft,
    required this.grid,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.brand,
    required this.brandDark,
    required this.brandBright,
    required this.violet,
    required this.cyan,
    required this.success,
  });

  final Color background;
  final Color surface;
  final Color surfaceLow;
  final Color heroSurface;
  final Color workspace;
  final Color inputShell;
  final Color rail;
  final Color notice;
  final Color border;
  final Color borderSoft;
  final Color grid;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color brand;
  final Color brandDark;
  final Color brandBright;
  final Color violet;
  final Color cyan;
  final Color success;

  static _BDSnapColors resolve(bool isDark) {
    if (isDark) {
      return _BDSnapColors(
        background: const Color(0xFF090B10),
        surface: const Color(0xB6151820),
        surfaceLow: Colors.white.withAlpha(9),
        heroSurface: const Color(0xA411141B),
        workspace: const Color(0xEA12151D),
        inputShell: const Color(0xFF0D1017),
        rail: const Color(0xC510131A),
        notice: const Color(0xF4161920),
        border: Colors.white.withAlpha(30),
        borderSoft: Colors.white.withAlpha(17),
        grid: Colors.white.withAlpha(7),
        textPrimary: const Color(0xFFF7F8FB),
        textSecondary: const Color(0xFFB8BFCC),
        textMuted: const Color(0xFF747C8B),
        brand: const Color(0xFF596BFF),
        brandDark: const Color(0xFF4052E5),
        brandBright: const Color(0xFF8090FF),
        violet: const Color(0xFFA06CFF),
        cyan: const Color(0xFF43C8D9),
        success: const Color(0xFF3AD29D),
      );
    }

    return _BDSnapColors(
      background: const Color(0xFFF2F4F8),
      surface: const Color(0xDDFFFFFF),
      surfaceLow: const Color(0xCCFFFFFF),
      heroSurface: const Color(0xD6FFFFFF),
      workspace: const Color(0xF7FFFFFF),
      inputShell: const Color(0xFFF5F7FB),
      rail: const Color(0xE6FFFFFF),
      notice: const Color(0xFAFFFFFF),
      border: const Color(0xFF161C2A).withAlpha(25),
      borderSoft: const Color(0xFF161C2A).withAlpha(15),
      grid: const Color(0xFF65708A).withAlpha(10),
      textPrimary: const Color(0xFF121620),
      textSecondary: const Color(0xFF505969),
      textMuted: const Color(0xFF89909C),
      brand: const Color(0xFF5366F5),
      brandDark: const Color(0xFF3C4ECC),
      brandBright: const Color(0xFF7787FF),
      violet: const Color(0xFF986FF1),
      cyan: const Color(0xFF40B8C9),
      success: const Color(0xFF168C66),
    );
  }
}
