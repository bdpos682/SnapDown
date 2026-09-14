import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
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

  @override
  void initState() {
    super.initState();

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _urlController.addListener(_onUrlChanged);
    _urlFocusNode.addListener(_onFocusChanged);
    _loadStorageUsage();
  }

  @override
  void dispose() {
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
        barrierColor: Colors.black.withAlpha(178),
        elevation: 0,
        enableDrag: true,
        clipBehavior: Clip.none,
        sheetAnimationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 520),
          reverseDuration: Duration(milliseconds: 320),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _noticePalette(tone, isDark);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          duration: duration,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
          padding: EdgeInsets.zero,
          content: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 13, 15, 13),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: palette.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 86 : 24),
                      blurRadius: 32,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: palette.accent.withAlpha(isDark ? 38 : 22),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: palette.accent, size: 21),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.text,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.text.withAlpha(160),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
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
      );
  }

  _NoticePalette _noticePalette(_NoticeTone tone, bool isDark) {
    final surface = isDark
        ? const Color(0xF2181A20)
        : const Color(0xFAFFFFFF);
    final border = isDark
        ? Colors.white.withAlpha(24)
        : const Color(0xFF182033).withAlpha(18);
    final text = isDark ? const Color(0xFFF6F7FB) : const Color(0xFF10131A);

    switch (tone) {
      case _NoticeTone.warning:
        return _NoticePalette(
          surface: surface,
          border: border,
          text: text,
          accent: const Color(0xFFF0A126),
        );
      case _NoticeTone.error:
        return _NoticePalette(
          surface: surface,
          border: border,
          text: text,
          accent: AppColors.accentRed,
        );
      case _NoticeTone.info:
        return _NoticePalette(
          surface: surface,
          border: border,
          text: text,
          accent: const Color(0xFF3D73FF),
        );
    }
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
          Positioned.fill(child: _buildPremiumBackground(colors, isDark)),
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                final w = constraints.maxWidth;
                final tiny = h < 560;
                final compact = h < 680;
                final roomy = h >= 780;
                final wide = w >= 700;

                final horizontal = wide ? 30.0 : 18.0;
                final bottomClearance = tiny
                    ? 54.0
                    : compact
                    ? 66.0
                    : 82.0;

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    tiny ? 8 : 12,
                    horizontal,
                    0,
                  ),
                  child: Column(
                    children: [
                      _intro(
                        index: 0,
                        child: _buildHeader(
                          colors: colors,
                          isDark: isDark,
                          compact: compact,
                        ),
                      ),
                      SizedBox(height: tiny ? 10 : compact ? 14 : 20),
                      _intro(
                        index: 1,
                        child: _buildHero(
                          colors: colors,
                          tiny: tiny,
                          compact: compact,
                          roomy: roomy,
                          wide: wide,
                        ),
                      ),
                      SizedBox(height: tiny ? 10 : compact ? 14 : 18),
                      _intro(
                        index: 2,
                        child: _buildLinkCard(
                          colors: colors,
                          isDark: isDark,
                          tiny: tiny,
                          compact: compact,
                        ),
                      ),
                      SizedBox(height: tiny ? 9 : compact ? 11 : 13),
                      _intro(
                        index: 3,
                        child: _buildPrimaryButton(
                          colors: colors,
                          tiny: tiny,
                          compact: compact,
                        ),
                      ),
                      SizedBox(height: tiny ? 10 : compact ? 13 : 17),
                      Expanded(
                        child: _intro(
                          index: 4,
                          child: _buildPlatformPanel(
                            colors: colors,
                            isDark: isDark,
                            tiny: tiny,
                            compact: compact,
                            wide: wide,
                          ),
                        ),
                      ),
                      SizedBox(height: tiny ? 7 : compact ? 9 : 11),
                      SizedBox(height: bottomClearance),
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
    final start = (index * 0.07).clamp(0.0, 0.4).toDouble();
    final end = (start + 0.48).clamp(0.48, 1.0).toDouble();
    final animation = CurvedAnimation(
      parent: _introController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.045),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  Widget _buildPremiumBackground(_BDSnapColors colors, bool isDark) {
    return AnimatedBuilder(
      animation: _ambientController,
      builder: (context, _) {
        final t = _ambientController.value;
        final x = _wave(t) * 42;
        final y = _wave((t + 0.25) % 1.0) * 26;

        return Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: colors.background)),
            Positioned(
              top: -190 + y,
              right: -150 + x,
              child: _SoftOrb(
                size: 450,
                color: colors.brand,
                opacity: isDark ? 0.13 : 0.08,
              ),
            ),
            Positioned(
              top: 210 - y,
              left: -250 - x,
              child: _SoftOrb(
                size: 500,
                color: colors.violet,
                opacity: isDark ? 0.055 : 0.035,
              ),
            ),
            Positioned(
              bottom: -250 + y,
              right: -170 - x,
              child: _SoftOrb(
                size: 500,
                color: colors.cyan,
                opacity: isDark ? 0.07 : 0.045,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.background.withAlpha(0),
                      colors.background.withAlpha(isDark ? 15 : 8),
                      colors.background.withAlpha(isDark ? 105 : 70),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _wave(double t) {
    final p = t <= 0.5 ? t * 2 : (1 - t) * 2;
    return Curves.easeInOut.transform(p) * 2 - 1;
  }

  Widget _buildHeader({
    required _BDSnapColors colors,
    required bool isDark,
    required bool compact,
  }) {
    return SizedBox(
      height: compact ? 46 : 50,
      child: Row(
        children: [
          _buildBrandMark(colors, compact),
          const SizedBox(width: 11),
          Expanded(
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
                    fontSize: compact ? 17 : 18.5,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tải video và âm thanh',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: compact ? 9.5 : 10.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!compact) ...[
            _buildReadyPill(colors),
            const SizedBox(width: 8),
          ],
          _buildHeaderIconButton(
            colors: colors,
            isDark: isDark,
            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            tooltip: 'Đổi giao diện',
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),
          const SizedBox(width: 7),
          _buildHeaderIconButton(
            colors: colors,
            isDark: isDark,
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

  Widget _buildBrandMark(_BDSnapColors colors, bool compact) {
    final size = compact ? 40.0 : 44.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.textPrimary,
        borderRadius: BorderRadius.circular(compact ? 13 : 14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'B',
            style: TextStyle(
              color: colors.background,
              fontSize: compact ? 20 : 22,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: -1,
            ),
          ),
          Positioned(
            right: 7,
            bottom: 7,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colors.brand,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.arrow_downward_rounded,
                size: 8,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyPill(_BDSnapColors colors) {
    return Container(
      height: 31,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: colors.success,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors.success.withAlpha(70),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            'Sẵn sàng',
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

  Widget _buildHeaderIconButton({
    required _BDSnapColors colors,
    required bool isDark,
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.borderSoft),
                ),
                child: Icon(icon, color: colors.textPrimary, size: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero({
    required _BDSnapColors colors,
    required bool tiny,
    required bool compact,
    required bool roomy,
    required bool wide,
  }) {
    final height = tiny
        ? 65.0
        : compact
        ? 86.0
        : roomy
        ? 126.0
        : 106.0;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!tiny)
                  Text(
                    'NHANH • GỌN • GIỮ NGUYÊN CHẤT LƯỢNG',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.brand,
                      fontSize: compact ? 9 : 9.8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.15,
                    ),
                  ),
                if (!tiny) SizedBox(height: compact ? 7 : 9),
                Text(
                  tiny
                      ? 'Tải nội dung. Giữ trọn chất lượng.'
                      : 'Tải nội dung.\nGiữ trọn chất lượng.',
                  maxLines: tiny ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: tiny ? 22 : compact ? 27 : roomy ? 34 : 31,
                    height: 0.98,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                  ),
                ),
              ],
            ),
          ),
          if (wide && !compact) ...[
            const SizedBox(width: 24),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.borderSoft),
                ),
                child: Text(
                  '4K  •  Âm thanh nguyên bản  •  Không nén lại',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 10.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLinkCard({
    required _BDSnapColors colors,
    required bool isDark,
    required bool tiny,
    required bool compact,
  }) {
    final focused = _urlFocusNode.hasFocus;
    final hasText = _urlController.text.trim().isNotEmpty;
    final platform = _platformMeta(_detectedPlatform, isDark);
    final active = _detectedPlatform.isEmpty ? colors.brand : platform.color;
    final height = tiny ? 94.0 : compact ? 108.0 : 122.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: active.withAlpha(focused || hasText ? 34 : 16),
            blurRadius: focused ? 34 : 24,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            padding: EdgeInsets.fromLTRB(
              tiny ? 11 : 14,
              tiny ? 10 : 13,
              tiny ? 10 : 12,
              tiny ? 10 : 13,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceStrong,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: focused || _detectedPlatform.isNotEmpty
                    ? active.withAlpha(isDark ? 125 : 92)
                    : colors.border,
                width: focused ? 1.35 : 1,
              ),
            ),
            child: Row(
              children: [
                _buildPlatformIdentity(
                  platform: platform,
                  colors: colors,
                  tiny: tiny,
                ),
                SizedBox(width: tiny ? 10 : 13),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _detectedPlatform.isEmpty
                                ? 'DÁN LIÊN KẾT'
                                : 'ĐÃ NHẬN DIỆN ${platform.name.toUpperCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _detectedPlatform.isEmpty
                                  ? colors.textMuted
                                  : active,
                              fontSize: tiny ? 8.5 : 9.2,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.05,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: tiny ? 4 : 6),
                      TextField(
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
                          fontSize: tiny ? 13 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Dán liên kết video hoặc âm thanh vào đây',
                          hintStyle: TextStyle(
                            color: colors.textMuted.withAlpha(145),
                            fontSize: tiny ? 12.2 : 13.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (!tiny) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 12,
                              color: colors.textMuted,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'Liên kết chỉ được dùng để phân tích trong phiên hiện tại',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: tiny ? 7 : 10),
                if (hasText)
                  _buildCompactAction(
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
                  _buildPasteAction(colors: colors, tiny: tiny),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformIdentity({
    required _PlatformMeta platform,
    required _BDSnapColors colors,
    required bool tiny,
  }) {
    final color = _detectedPlatform.isEmpty ? colors.brand : platform.color;
    final size = tiny ? 54.0 : 62.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(tiny ? 18 : 20),
        border: Border.all(color: color.withAlpha(45)),
      ),
      child: Icon(
        _detectedPlatform.isEmpty ? Icons.link_rounded : platform.icon,
        color: color,
        size: tiny ? 24 : 27,
      ),
    );
  }

  Widget _buildCompactAction({
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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: colors.borderSoft),
            ),
            child: Icon(icon, size: 18, color: colors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildPasteAction({
    required _BDSnapColors colors,
    required bool tiny,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pasteFromClipboard,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: tiny ? 10 : 12),
          decoration: BoxDecoration(
            color: colors.brand.withAlpha(18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.brand.withAlpha(35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.content_paste_rounded,
                color: colors.brand,
                size: 16,
              ),
              if (!tiny) ...[
                const SizedBox(width: 6),
                Text(
                  'Dán',
                  style: TextStyle(
                    color: colors.brand,
                    fontSize: 11.5,
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

  Widget _buildPrimaryButton({
    required _BDSnapColors colors,
    required bool tiny,
    required bool compact,
  }) {
    final height = tiny ? 48.0 : compact ? 52.0 : 56.0;

    return AnimatedBuilder(
      animation: _shineController,
      builder: (context, _) {
        final t = _shineController.value;

        return Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: colors.brand,
            boxShadow: [
              BoxShadow(
                color: colors.brand.withAlpha(72),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
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
                          colors.brand,
                          colors.brandBright,
                        ],
                      ),
                    ),
                  ),
                ),
                if (!_isAnalyzing)
                  Positioned(
                    top: -30,
                    bottom: -30,
                    left: -120 + t * 520,
                    width: 86,
                    child: Transform.rotate(
                      angle: -0.28,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withAlpha(0),
                              Colors.white.withAlpha(42),
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
                            key: const ValueKey('dang-phan-tich'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Đang phân tích liên kết...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: tiny ? 12.7 : 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          )
                              : Row(
                            key: const ValueKey('phan-tich'),
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
                                  fontSize: tiny ? 12.2 : 13.1,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.65,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 18,
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

  Widget _buildPlatformPanel({
    required _BDSnapColors colors,
    required bool isDark,
    required bool tiny,
    required bool compact,
    required bool wide,
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
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        tiny ? 12 : 15,
        tiny ? 10 : 13,
        tiny ? 12 : 15,
        tiny ? 10 : 13,
      ),
      decoration: BoxDecoration(
        color: colors.surfacePanel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!tiny)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'NỀN TẢNG HỖ TRỢ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 9.6,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: colors.brand,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Tự động nhận diện',
                      style: TextStyle(
                        color: colors.brand,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          if (!tiny) SizedBox(height: compact ? 10 : 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final firstRowCount = wide ? 7 : 4;
                final secondRowCount = wide ? 0 : 3;
                final gap = tiny ? 6.0 : 8.0;
                final rowGap = tiny ? 6.0 : 8.0;

                if (wide) {
                  return Row(
                    children: List.generate(platforms.length, (index) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index == platforms.length - 1 ? 0 : gap,
                          ),
                          child: _buildPlatformTile(
                            meta: platforms[index],
                            colors: colors,
                            tiny: tiny,
                            compact: compact,
                          ),
                        ),
                      );
                    }),
                  );
                }

                final top = platforms.take(firstRowCount).toList();
                final bottom = platforms.skip(firstRowCount).take(secondRowCount).toList();

                return Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: List.generate(top.length, (index) {
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: index == top.length - 1 ? 0 : gap,
                              ),
                              child: _buildPlatformTile(
                                meta: top[index],
                                colors: colors,
                                tiny: tiny,
                                compact: compact,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    SizedBox(height: rowGap),
                    Expanded(
                      child: Row(
                        children: List.generate(bottom.length, (index) {
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: index == bottom.length - 1 ? 0 : gap,
                              ),
                              child: _buildPlatformTile(
                                meta: bottom[index],
                                colors: colors,
                                tiny: tiny,
                                compact: compact,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformTile({
    required _PlatformMeta meta,
    required _BDSnapColors colors,
    required bool tiny,
    required bool compact,
  }) {
    final active = _detectedPlatform == meta.id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: active ? meta.color.withAlpha(18) : colors.tile,
        borderRadius: BorderRadius.circular(tiny ? 15 : 17),
        border: Border.all(
          color: active ? meta.color.withAlpha(90) : colors.borderSoft,
          width: active ? 1.2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: tiny ? 31 : compact ? 34 : 37,
            height: tiny ? 31 : compact ? 34 : 37,
            decoration: BoxDecoration(
              color: meta.color.withAlpha(active ? 30 : 17),
              borderRadius: BorderRadius.circular(tiny ? 10 : 12),
            ),
            child: Icon(
              meta.icon,
              color: meta.color,
              size: tiny ? 17 : compact ? 18 : 19,
            ),
          ),
          SizedBox(height: tiny ? 4 : 6),
          Text(
            meta.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? colors.textPrimary : colors.textSecondary,
              fontSize: tiny ? 8.8 : compact ? 9.3 : 9.8,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          if (!tiny && active) ...[
            const SizedBox(height: 3),
            Text(
              'Đã nhận diện',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: meta.color,
                fontSize: 7.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
          color: Color(0xFF11B9AE),
        );
      case 'facebook':
        return const _PlatformMeta(
          id: 'facebook',
          name: 'Facebook',
          icon: Icons.facebook_rounded,
          color: Color(0xFF3976EA),
        );
      case 'instagram':
        return const _PlatformMeta(
          id: 'instagram',
          name: 'Instagram',
          icon: Icons.camera_alt_rounded,
          color: Color(0xFFE84393),
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
          color: Color(0xFF26A8E6),
        );
      case 'direct':
        return const _PlatformMeta(
          id: 'direct',
          name: 'Trang web',
          icon: Icons.language_rounded,
          color: Color(0xFF14866D),
        );
      default:
        return const _PlatformMeta(
          id: '',
          name: 'Tự động',
          icon: Icons.link_rounded,
          color: Color(0xFF3D73FF),
        );
    }
  }
}

class _SoftOrb extends StatelessWidget {
  const _SoftOrb({
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
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withAlpha((255 * opacity).round()),
              color.withAlpha((92 * opacity).round()),
              Colors.transparent,
            ],
            stops: const [0.0, 0.48, 1.0],
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

class _NoticePalette {
  const _NoticePalette({
    required this.surface,
    required this.border,
    required this.text,
    required this.accent,
  });

  final Color surface;
  final Color border;
  final Color text;
  final Color accent;
}

class _BDSnapColors {
  const _BDSnapColors({
    required this.background,
    required this.surface,
    required this.surfaceStrong,
    required this.surfacePanel,
    required this.surfaceMuted,
    required this.tile,
    required this.border,
    required this.borderSoft,
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
  final Color surfaceStrong;
  final Color surfacePanel;
  final Color surfaceMuted;
  final Color tile;
  final Color border;
  final Color borderSoft;
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
        background: const Color(0xFF0C0D10),
        surface: const Color(0xB8181A20),
        surfaceStrong: const Color(0xE515171C),
        surfacePanel: const Color(0xB5121418),
        surfaceMuted: Colors.white.withAlpha(9),
        tile: Colors.white.withAlpha(7),
        border: Colors.white.withAlpha(31),
        borderSoft: Colors.white.withAlpha(18),
        textPrimary: const Color(0xFFF5F6F8),
        textSecondary: const Color(0xFFB8BDC7),
        textMuted: const Color(0xFF757B87),
        brand: const Color(0xFF3D73FF),
        brandDark: const Color(0xFF2859D9),
        brandBright: const Color(0xFF5E8BFF),
        violet: const Color(0xFF7A6CF6),
        cyan: const Color(0xFF47BFD1),
        success: const Color(0xFF35C991),
      );
    }

    return _BDSnapColors(
      background: const Color(0xFFF4F3F0),
      surface: const Color(0xDFFFFFFF),
      surfaceStrong: const Color(0xF6FFFFFF),
      surfacePanel: const Color(0xE8FFFFFF),
      surfaceMuted: const Color(0xBFFFFFFF),
      tile: const Color(0xDFFFFFFF),
      border: const Color(0xFF151821).withAlpha(24),
      borderSoft: const Color(0xFF151821).withAlpha(15),
      textPrimary: const Color(0xFF121318),
      textSecondary: const Color(0xFF515662),
      textMuted: const Color(0xFF858A94),
      brand: const Color(0xFF2F66F3),
      brandDark: const Color(0xFF214EC2),
      brandBright: const Color(0xFF5B86F5),
      violet: const Color(0xFF8273F1),
      cyan: const Color(0xFF45B3C0),
      success: const Color(0xFF168860),
    );
  }
}
