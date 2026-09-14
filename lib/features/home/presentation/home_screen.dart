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
  late final AnimationController _entryController;
  late final AnimationController _ctaController;

  @override
  void initState() {
    super.initState();

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..forward();

    _ctaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _urlController.addListener(_onUrlChanged);
    _urlFocusNode.addListener(_onFocusChanged);
    _loadStorageUsage();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _entryController.dispose();
    _ctaController.dispose();
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
        title: 'Clipboard đang trống',
        message: 'Hãy sao chép liên kết video hoặc âm thanh trước.',
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
        message: 'Dán URL media vào ô trung tâm để bắt đầu phân tích.',
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
        message: 'Ví dụ hợp lệ: https://youtube.com/...',
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
        barrierColor: Colors.black.withAlpha(180),
        elevation: 0,
        enableDrag: true,
        clipBehavior: Clip.none,
        sheetAnimationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 460),
          reverseDuration: Duration(milliseconds: 300),
        ),
        builder: (_) => AnalyzeSheet(mediaInfo: info),
      );
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _showNotice(
        title: 'Không thể trích xuất media',
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
    Duration duration = const Duration(milliseconds: 2600),
  }) {
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _paletteForTone(tone, isDark);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          duration: duration,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
          padding: EdgeInsets.zero,
          content: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: palette.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 65 : 24),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: palette.accent.withAlpha(isDark ? 38 : 24),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(icon, color: palette.accent, size: 20),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: palette.text,
                              fontSize: 13.5,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.text.withAlpha(170),
                              fontSize: 11.5,
                              height: 1.25,
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
      );
  }

  _NoticePalette _paletteForTone(_NoticeTone tone, bool isDark) {
    final surface = isDark
        ? const Color(0xE51A1D28)
        : const Color(0xF5FFFFFF);
    final border = isDark
        ? Colors.white.withAlpha(24)
        : const Color(0xFF0F172A).withAlpha(18);
    final text = isDark ? Colors.white : const Color(0xFF111827);

    switch (tone) {
      case _NoticeTone.warning:
        return _NoticePalette(
          surface: surface,
          border: border,
          text: text,
          accent: const Color(0xFFF59E0B),
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
          accent: const Color(0xFF5B8CFF),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _HomeColors.resolve(isDark);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: colors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildBackground(isDark, colors),
          ),
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                final w = constraints.maxWidth;
                final ultraCompact = h < 580;
                final compact = h < 700;
                final wide = w >= 700;
                final bottomClearance = ultraCompact
                    ? 58.0
                    : compact
                    ? 70.0
                    : 84.0;

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 28 : 18,
                    compact ? 8 : 12,
                    wide ? 28 : 18,
                    0,
                  ),
                  child: Column(
                    children: [
                      _enter(
                        index: 0,
                        child: _buildHeader(
                          colors: colors,
                          isDark: isDark,
                          compact: compact,
                        ),
                      ),
                      SizedBox(height: ultraCompact ? 8 : compact ? 10 : 14),
                      _enter(
                        index: 1,
                        child: _buildHero(
                          colors: colors,
                          compact: compact,
                          ultraCompact: ultraCompact,
                        ),
                      ),
                      SizedBox(height: ultraCompact ? 7 : compact ? 10 : 13),
                      _enter(
                        index: 2,
                        child: _buildUrlComposer(
                          colors: colors,
                          isDark: isDark,
                          compact: compact,
                          ultraCompact: ultraCompact,
                        ),
                      ),
                      SizedBox(height: ultraCompact ? 7 : 10),
                      _enter(
                        index: 3,
                        child: _buildPrimaryAction(
                          colors: colors,
                          compact: compact,
                          ultraCompact: ultraCompact,
                        ),
                      ),
                      SizedBox(height: ultraCompact ? 8 : compact ? 10 : 14),
                      Expanded(
                        child: _enter(
                          index: 4,
                          child: _buildPlatformDeck(
                            colors: colors,
                            isDark: isDark,
                            wide: wide,
                            compact: compact,
                            ultraCompact: ultraCompact,
                          ),
                        ),
                      ),
                      SizedBox(height: ultraCompact ? 7 : compact ? 9 : 12),
                      _enter(
                        index: 5,
                        child: _buildStatusRail(
                          colors: colors,
                          isDark: isDark,
                          compact: compact,
                        ),
                      ),
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

  Widget _enter({required int index, required Widget child}) {
    final begin = (index * 0.07).clamp(0.0, 0.42).toDouble();
    final end = (begin + 0.5).clamp(0.5, 1.0).toDouble();
    final animation = CurvedAnimation(
      parent: _entryController,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  Widget _buildBackground(bool isDark, _HomeColors colors) {
    return AnimatedBuilder(
      animation: _ambientController,
      builder: (context, _) {
        final t = _ambientController.value * 6.283185307179586;
        final dx1 = 28.0 * _fastSin(t);
        final dy1 = 22.0 * _fastCos(t * 0.78);
        final dx2 = 34.0 * _fastCos(t * 0.72);
        final dy2 = 26.0 * _fastSin(t * 0.91);

        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: colors.background),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _CommandGridPainter(
                  color: colors.grid,
                  strongColor: colors.gridStrong,
                ),
              ),
            ),
            Positioned(
              top: -160 + dy1,
              right: -120 + dx1,
              child: _AuraOrb(
                size: 410,
                color: const Color(0xFF345DFF),
                opacity: isDark ? 0.17 : 0.12,
              ),
            ),
            Positioned(
              top: 220 + dy2,
              left: -210 + dx2,
              child: _AuraOrb(
                size: 430,
                color: const Color(0xFF8B5CF6),
                opacity: isDark ? 0.11 : 0.08,
              ),
            ),
            Positioned(
              bottom: -180 - dy1,
              right: -150 - dx2,
              child: _AuraOrb(
                size: 420,
                color: const Color(0xFF00D4FF),
                opacity: isDark ? 0.10 : 0.07,
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
                      colors.background.withAlpha(isDark ? 30 : 18),
                      colors.background.withAlpha(isDark ? 120 : 90),
                    ],
                    stops: const [0.0, 0.56, 1.0],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader({
    required _HomeColors colors,
    required bool isDark,
    required bool compact,
  }) {
    return SizedBox(
      height: compact ? 44 : 48,
      child: Row(
        children: [
          Container(
            width: compact ? 40 : 44,
            height: compact ? 40 : 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(compact ? 14 : 16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6A7CFF),
                  Color(0xFF275DFF),
                  Color(0xFF00C8FF),
                ],
              ),
              border: Border.all(color: Colors.white.withAlpha(42)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2F67FF).withAlpha(isDark ? 95 : 50),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.arrow_downward_rounded,
                  color: Colors.white,
                  size: 23,
                ),
                Positioned(
                  bottom: 8,
                  child: Container(
                    width: 14,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'SNAPDOWN',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: compact ? 16 : 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(width: 7),
                    _buildLiveDot(colors),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  'MEDIA EXTRACTION ENGINE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: compact ? 8.5 : 9.2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (!compact)
            _buildHeaderStatusChip(colors)
          else
            const SizedBox.shrink(),
          if (!compact) const SizedBox(width: 8),
          _buildHeaderButton(
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
          _buildHeaderButton(
            colors: colors,
            isDark: isDark,
            icon: Icons.settings,
            tooltip: 'Bộ nhớ',
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

  Widget _buildLiveDot(_HomeColors colors) {
    return AnimatedBuilder(
      animation: _ambientController,
      builder: (context, _) {
        final phase = (_ambientController.value * 2.0);
        final pulse = phase <= 1 ? phase : 2 - phase;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.success,
            boxShadow: [
              BoxShadow(
                color: colors.success.withAlpha((40 + pulse * 130).round()),
                blurRadius: 4 + (pulse * 7),
                spreadRadius: pulse * 1.2,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderStatusChip(_HomeColors colors) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, color: colors.success, size: 13),
          const SizedBox(width: 5),
          Text(
            'READY',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required _HomeColors colors,
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.surfaceSoft,
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
    required _HomeColors colors,
    required bool compact,
    required bool ultraCompact,
  }) {
    return SizedBox(
      height: ultraCompact ? 58 : compact ? 72 : 92,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!ultraCompact)
                  Row(
                    children: [
                      Container(
                        width: 18,
                        height: 1.5,
                        decoration: BoxDecoration(
                          color: colors.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'ONE-TAP MEDIA EXTRACTOR',
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: compact ? 8.5 : 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.45,
                        ),
                      ),
                    ],
                  ),
                if (!ultraCompact) SizedBox(height: compact ? 5 : 7),
                Text(
                  ultraCompact
                      ? 'Bắt link. Giữ chất lượng.'
                      : 'Bắt link. Tách media.\nGiữ nguyên chất lượng.',
                  maxLines: ultraCompact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: ultraCompact ? 23 : compact ? 24 : 28,
                    height: 1.01,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 18),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '4K VIDEO  •  LOSSLESS AUDIO\nNO RE-COMPRESSION',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 9.5,
                  height: 1.55,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUrlComposer({
    required _HomeColors colors,
    required bool isDark,
    required bool compact,
    required bool ultraCompact,
  }) {
    final focused = _urlFocusNode.hasFocus;
    final hasText = _urlController.text.trim().isNotEmpty;
    final platform = _platformMeta(_detectedPlatform, isDark);
    final activeColor = _detectedPlatform.isNotEmpty
        ? platform.color
        : colors.accent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      height: ultraCompact ? 84 : compact ? 96 : 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: activeColor.withAlpha(
              focused || _detectedPlatform.isNotEmpty ? 35 : 12,
            ),
            blurRadius: focused ? 34 : 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.fromLTRB(
              ultraCompact ? 12 : 14,
              ultraCompact ? 10 : 12,
              ultraCompact ? 10 : 12,
              ultraCompact ? 10 : 12,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceStrong,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: focused || _detectedPlatform.isNotEmpty
                    ? activeColor.withAlpha(isDark ? 145 : 120)
                    : colors.borderStrong,
                width: focused ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                _buildSourceBadge(
                  platform: platform,
                  colors: colors,
                  compact: compact,
                  ultraCompact: ultraCompact,
                ),
                SizedBox(width: ultraCompact ? 10 : 13),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'MEDIA URL',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: ultraCompact ? 8.2 : 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.25,
                            ),
                          ),
                          if (_detectedPlatform.isNotEmpty) ...[
                            const SizedBox(width: 7),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: platform.color.withAlpha(
                                    isDark ? 28 : 18,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: platform.color.withAlpha(65),
                                  ),
                                ),
                                child: Text(
                                  'ĐÃ NHẬN DIỆN ${platform.name.toUpperCase()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: platform.color,
                                    fontSize: ultraCompact ? 7.4 : 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.45,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: ultraCompact ? 2 : 4),
                      TextField(
                        controller: _urlController,
                        focusNode: _urlFocusNode,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.go,
                        autocorrect: false,
                        enableSuggestions: false,
                        maxLines: 1,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: ultraCompact ? 13 : 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.15,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: 'Dán liên kết video / audio tại đây',
                          hintStyle: TextStyle(
                            color: colors.textMuted.withAlpha(150),
                            fontSize: ultraCompact ? 12.2 : 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onSubmitted: (_) => _analyzeUrl(),
                      ),
                      if (!ultraCompact) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.lock_rounded,
                              size: 10,
                              color: colors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Phân tích trực tiếp • Không lưu lịch sử liên kết',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: ultraCompact ? 7 : 10),
                if (hasText)
                  _buildComposerAction(
                    colors: colors,
                    icon: Icons.close_rounded,
                    label: compact ? null : 'XÓA',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _urlController.clear();
                      _urlFocusNode.requestFocus();
                    },
                  )
                else
                  _buildComposerAction(
                    colors: colors,
                    icon: Icons.content_paste_go_rounded,
                    label: ultraCompact ? null : 'DÁN LINK',
                    highlighted: true,
                    onTap: _pasteFromClipboard,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceBadge({
    required _PlatformMeta platform,
    required _HomeColors colors,
    required bool compact,
    required bool ultraCompact,
  }) {
    final size = ultraCompact ? 44.0 : compact ? 50.0 : 56.0;
    final color = _detectedPlatform.isEmpty ? colors.accent : platform.color;
    final icon = _detectedPlatform.isEmpty ? Icons.link_rounded : platform.icon;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withAlpha(50),
            color.withAlpha(18),
          ],
        ),
        border: Border.all(color: color.withAlpha(90)),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: ultraCompact ? 21 : 24),
    );
  }

  Widget _buildComposerAction({
    required _HomeColors colors,
    required IconData icon,
    required VoidCallback onTap,
    String? label,
    bool highlighted = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 38,
          padding: EdgeInsets.symmetric(horizontal: label == null ? 10 : 11),
          decoration: BoxDecoration(
            color: highlighted
                ? colors.accent.withAlpha(22)
                : colors.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlighted
                  ? colors.accent.withAlpha(75)
                  : colors.borderSoft,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: highlighted ? colors.accent : colors.textSecondary,
              ),
              if (label != null) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: highlighted ? colors.accent : colors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryAction({
    required _HomeColors colors,
    required bool compact,
    required bool ultraCompact,
  }) {
    final height = ultraCompact ? 46.0 : compact ? 50.0 : 54.0;

    return SizedBox(
      height: height,
      child: AnimatedBuilder(
        animation: _ctaController,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFF334CFF),
                      Color(0xFF3B78FF),
                      Color(0xFF00B8F5),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF316BFF).withAlpha(80),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Align(
                  alignment: Alignment(
                    -1.35 + (_ctaController.value * 2.7),
                    0,
                  ),
                  child: Transform.rotate(
                    angle: -0.18,
                    child: Container(
                      width: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.white.withAlpha(0),
                            Colors.white.withAlpha(44),
                            Colors.white.withAlpha(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isAnalyzing ? null : () => _analyzeUrl(),
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: ultraCompact ? 14 : 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isAnalyzing)
                          SizedBox(
                            width: ultraCompact ? 16 : 18,
                            height: ultraCompact ? 16 : 18,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        else
                          Container(
                            width: ultraCompact ? 28 : 31,
                            height: ultraCompact ? 28 : 31,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(32),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withAlpha(45),
                              ),
                            ),
                            child: const Icon(
                              Icons.bolt_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        SizedBox(width: ultraCompact ? 8 : 10),
                        Flexible(
                          child: Text(
                            _isAnalyzing
                                ? 'ĐANG PHÂN TÍCH NGUỒN MEDIA...'
                                : 'PHÂN TÍCH & MỞ TRÌNH TẢI',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: ultraCompact ? 11.2 : 12.2,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.72,
                            ),
                          ),
                        ),
                        if (!ultraCompact && !_isAnalyzing) ...[
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (_isAnalyzing)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 2,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white.withAlpha(24),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlatformDeck({
    required _HomeColors colors,
    required bool isDark,
    required bool wide,
    required bool compact,
    required bool ultraCompact,
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            12,
            ultraCompact ? 8 : compact ? 9 : 11,
            12,
            ultraCompact ? 8 : compact ? 9 : 11,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceSoft,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.borderSoft),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: colors.accent.withAlpha(20),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.hub_rounded,
                      size: 14,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'NGUỒN TƯƠNG THÍCH',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: ultraCompact ? 8.2 : 9.1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.15,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.success.withAlpha(isDark ? 22 : 16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: colors.success.withAlpha(55),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'AUTO DETECT',
                          style: TextStyle(
                            color: colors.success,
                            fontSize: 7.6,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.65,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: ultraCompact ? 6 : compact ? 7 : 9),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = wide ? 7 : 4;
                    final rows = (platforms.length / columns).ceil();
                    final hGap = wide ? 7.0 : 6.0;
                    final vGap = ultraCompact ? 5.0 : 6.0;
                    final tileWidth =
                        (constraints.maxWidth - (hGap * (columns - 1))) /
                            columns;
                    final usableHeight =
                        constraints.maxHeight - (vGap * (rows - 1));
                    final tileHeight =
                    usableHeight > 0 ? usableHeight / rows : 0.0;

                    return Align(
                      alignment: Alignment.topCenter,
                      child: Wrap(
                        spacing: hGap,
                        runSpacing: vGap,
                        children: platforms.map((platform) {
                          return SizedBox(
                            width: tileWidth,
                            height: tileHeight,
                            child: _buildPlatformTile(
                              platform: platform,
                              colors: colors,
                              isDark: isDark,
                              compact: compact,
                              ultraCompact: ultraCompact,
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformTile({
    required _PlatformMeta platform,
    required _HomeColors colors,
    required bool isDark,
    required bool compact,
    required bool ultraCompact,
  }) {
    final selected = _detectedPlatform == platform.id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected
            ? platform.color.withAlpha(isDark ? 24 : 16)
            : colors.tileSurface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: selected
              ? platform.color.withAlpha(105)
              : colors.tileBorder,
          width: selected ? 1.2 : 1,
        ),
        boxShadow: selected
            ? [
          BoxShadow(
            color: platform.color.withAlpha(25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ultraCompact ? 5 : 7,
          vertical: ultraCompact ? 4 : 5,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Container(
                width: ultraCompact ? 26 : 30,
                height: ultraCompact ? 26 : 30,
                decoration: BoxDecoration(
                  color: platform.color.withAlpha(isDark ? 24 : 16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  platform.icon,
                  color: platform.color,
                  size: ultraCompact ? 15 : 17,
                ),
              ),
            ),
            SizedBox(height: ultraCompact ? 3 : 4),
            Text(
              platform.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? platform.color : colors.textSecondary,
                fontSize: ultraCompact ? 8 : compact ? 8.6 : 9.3,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.05,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRail({
    required _HomeColors colors,
    required bool isDark,
    required bool compact,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: compact ? 38 : 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: colors.surfaceSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.borderSoft),
          ),
          child: Row(
            children: [
              _statusItem(
                colors: colors,
                icon: Icons.offline_bolt_rounded,
                value: 'READY',
                label: compact ? null : 'LOCAL',
                accent: colors.success,
              ),
              _railDivider(colors),
              Expanded(
                child: _statusItem(
                  colors: colors,
                  icon: Icons.shield_outlined,
                  value: 'PRIVATE',
                  label: compact ? null : 'SESSION',
                  accent: colors.textSecondary,
                ),
              ),
              _railDivider(colors),
              Expanded(
                child: _statusItem(
                  colors: colors,
                  icon: Icons.sd_storage_rounded,
                  value: _formattedStorage,
                  label: compact ? null : 'ĐÃ LƯU',
                  accent: colors.accent,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusItem({
    required _HomeColors colors,
    required IconData icon,
    required String value,
    required Color accent,
    String? label,
    bool alignEnd = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
      alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: accent),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 9.2,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.35,
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 8.2,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.35,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _railDivider(_HomeColors colors) {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: colors.borderSoft,
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
          color: Color(0xFF19E3D4),
        );
      case 'facebook':
        return const _PlatformMeta(
          id: 'facebook',
          name: 'Facebook',
          icon: Icons.facebook_rounded,
          color: Color(0xFF4C8DFF),
        );
      case 'instagram':
        return const _PlatformMeta(
          id: 'instagram',
          name: 'Instagram',
          icon: Icons.camera_alt_rounded,
          color: Color(0xFFFF4D91),
        );
      case 'twitter':
        return _PlatformMeta(
          id: 'twitter',
          name: 'X / Twitter',
          icon: Icons.alternate_email_rounded,
          color: isDark ? Colors.white : const Color(0xFF111827),
        );
      case 'vimeo':
        return const _PlatformMeta(
          id: 'vimeo',
          name: 'Vimeo',
          icon: Icons.video_library_rounded,
          color: Color(0xFF35B7F3),
        );
      case 'direct':
        return const _PlatformMeta(
          id: 'direct',
          name: 'Direct Link',
          icon: Icons.language_rounded,
          color: Color(0xFF14B8A6),
        );
      default:
        return const _PlatformMeta(
          id: '',
          name: 'Tự động',
          icon: Icons.link_rounded,
          color: Color(0xFF5B8CFF),
        );
    }
  }

  double _fastSin(double x) {
    final normalized = x % 6.283185307179586;
    final y = normalized < 3.141592653589793
        ? normalized
        : normalized - 6.283185307179586;
    final b = 4 / 3.141592653589793;
    final c = -4 / (3.141592653589793 * 3.141592653589793);
    final estimate = b * y + c * y.abs() * y;
    const p = 0.225;
    return p * (estimate * estimate.abs() - estimate) + estimate;
  }

  double _fastCos(double x) => _fastSin(x + 1.5707963267948966);
}

class _AuraOrb extends StatelessWidget {
  const _AuraOrb({
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
              color.withAlpha((100 * opacity).round()),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
      ),
    );
  }
}

class _CommandGridPainter extends CustomPainter {
  const _CommandGridPainter({
    required this.color,
    required this.strongColor,
  });

  final Color color;
  final Color strongColor;

  @override
  void paint(Canvas canvas, Size size) {
    final minorPaint = Paint()
      ..color = color
      ..strokeWidth = 0.55;
    final majorPaint = Paint()
      ..color = strongColor
      ..strokeWidth = 0.7;

    const step = 32.0;
    const majorEvery = 4;

    var index = 0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        index % majorEvery == 0 ? majorPaint : minorPaint,
      );
      index++;
    }

    index = 0;
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        index % majorEvery == 0 ? majorPaint : minorPaint,
      );
      index++;
    }
  }

  @override
  bool shouldRepaint(covariant _CommandGridPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strongColor != strongColor;
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

class _HomeColors {
  const _HomeColors({
    required this.background,
    required this.surfaceStrong,
    required this.surfaceSoft,
    required this.tileSurface,
    required this.borderStrong,
    required this.borderSoft,
    required this.tileBorder,
    required this.grid,
    required this.gridStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.success,
  });

  final Color background;
  final Color surfaceStrong;
  final Color surfaceSoft;
  final Color tileSurface;
  final Color borderStrong;
  final Color borderSoft;
  final Color tileBorder;
  final Color grid;
  final Color gridStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color success;

  static _HomeColors resolve(bool isDark) {
    if (isDark) {
      return _HomeColors(
        background: const Color(0xFF080A10),
        surfaceStrong: const Color(0xE6131722),
        surfaceSoft: Colors.white.withAlpha(11),
        tileSurface: Colors.white.withAlpha(8),
        borderStrong: Colors.white.withAlpha(31),
        borderSoft: Colors.white.withAlpha(20),
        tileBorder: Colors.white.withAlpha(16),
        grid: Colors.white.withAlpha(5),
        gridStrong: Colors.white.withAlpha(8),
        textPrimary: const Color(0xFFF7F9FF),
        textSecondary: const Color(0xFFC4CAD8),
        textMuted: const Color(0xFF7B8498),
        accent: const Color(0xFF6A8DFF),
        success: const Color(0xFF36D399),
      );
    }

    return _HomeColors(
      background: const Color(0xFFF3F6FB),
      surfaceStrong: const Color(0xEFFFFFFF),
      surfaceSoft: Colors.white.withAlpha(175),
      tileSurface: Colors.white.withAlpha(205),
      borderStrong: const Color(0xFF172033).withAlpha(24),
      borderSoft: const Color(0xFF172033).withAlpha(17),
      tileBorder: const Color(0xFF172033).withAlpha(14),
      grid: const Color(0xFF24324C).withAlpha(6),
      gridStrong: const Color(0xFF24324C).withAlpha(10),
      textPrimary: const Color(0xFF111827),
      textSecondary: const Color(0xFF4E596D),
      textMuted: const Color(0xFF8A94A8),
      accent: const Color(0xFF3F6FFF),
      success: const Color(0xFF129B72),
    );
  }
}
