import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
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

  @override
  void initState() {
    super.initState();

    // Background animation
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    // Entry animation
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _urlController.addListener(_onUrlChanged);
    _urlFocusNode.addListener(_onFocusChanged);
    _loadStorageUsage();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _entryController.dispose();
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
    if (_detectedPlatform != detected) {
      setState(() => _detectedPlatform = detected);
      if (detected.isNotEmpty) {
        HapticFeedback.lightImpact();
      }
    }
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
    Duration duration = const Duration(milliseconds: 3000),
  }) {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _HomeColors.resolve(isDark);

    Color accentColor;
    switch (tone) {
      case _NoticeTone.warning:
        accentColor = const Color(0xFFF59E0B);
        break;
      case _NoticeTone.error:
        accentColor = AppColors.accentRed;
        break;
      case _NoticeTone.info:
        accentColor = const Color(0xFF3B82F6);
        break;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          duration: duration,
          margin: const EdgeInsets.only(bottom: 40, left: 20, right: 20),
          padding: EdgeInsets.zero,
          content: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceStrong.withAlpha(isDark ? 220 : 240),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.borderSoft),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 40 : 10),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: accentColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
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

  // --- UI BUILDING ---

  Widget _animateIn({required int index, required Widget child}) {
    final begin = (index * 0.1).clamp(0.0, 0.5);
    final end = (begin + 0.5).clamp(0.5, 1.0);
    final animation = CurvedAnimation(
      parent: _entryController,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _HomeColors.resolve(isDark);
    final size = MediaQuery.of(context).size;
    final isCompact = size.height < 750;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // 1. Sleek Animated Background (Aurora effect)
          _buildPremiumBackground(isDark, colors),

          // 2. Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Header
                  _animateIn(index: 0, child: _buildHeader(colors, isDark)),

                  SizedBox(height: isCompact ? 32 : 50),

                  // Hero Section
                  _animateIn(index: 1, child: _buildHero(colors)),

                  SizedBox(height: isCompact ? 32 : 50),

                  // Central Card: Input & Action
                  _animateIn(
                      index: 2,
                      child: _buildInteractionCard(colors, isDark)
                  ),

                  const Spacer(),

                  // Platform Support Line
                  _animateIn(
                      index: 3,
                      child: _buildPlatformRow(colors, isDark)
                  ),

                  const SizedBox(height: 24),

                  // Bottom Status Pill
                  _animateIn(
                      index: 4,
                      child: Center(child: _buildStatusPill(colors, isDark))
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBackground(bool isDark, _HomeColors colors) {
    return AnimatedBuilder(
      animation: _ambientController,
      builder: (context, _) {
        final t = _ambientController.value * 2 * math.pi;
        final d1 = math.sin(t) * 40;
        final d2 = math.cos(t * 0.8) * 50;

        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: colors.background),
            // Top Right glow
            Positioned(
              top: -100 + d1,
              right: -100 + d2,
              child: _GlowingOrb(
                color: colors.accent.withAlpha(isDark ? 80 : 40),
                size: 400,
              ),
            ),
            // Bottom Left glow
            Positioned(
              bottom: -150 - d2,
              left: -100 - d1,
              child: _GlowingOrb(
                color: const Color(0xFF00C8FF).withAlpha(isDark ? 60 : 30),
                size: 450,
              ),
            ),
            // Apply heavy blur to blend them smoothly
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: const SizedBox.expand(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(_HomeColors colors, bool isDark) {
    return Row(
      children: [
        // Premium Logo Style
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.accent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: colors.accent.withAlpha(isDark ? 100 : 50),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          'Snapdown',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        _buildIconBtn(
          icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          colors: colors,
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(themeModeProvider.notifier).toggleTheme();
          },
        ),
        const SizedBox(width: 8),
        _buildIconBtn(
          icon: Icons.storage_rounded,
          colors: colors,
          onTap: () async {
            HapticFeedback.selectionClick();
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StorageSettingsScreen()),
            );
            if (mounted) await _loadStorageUsage();
          },
        ),
      ],
    );
  }

  Widget _buildIconBtn({
    required IconData icon,
    required _HomeColors colors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.surfaceSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.borderSoft),
          ),
          child: Icon(icon, color: colors.textPrimary, size: 20),
        ),
      ),
    );
  }

  Widget _buildHero(_HomeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.accent.withAlpha(20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.accent.withAlpha(40)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded, size: 14, color: colors.accent),
              const SizedBox(width: 4),
              Text(
                'NO RE-COMPRESSION',
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Tách Media.\nGiữ Nguyên Bản.',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 38,
            height: 1.1,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Hỗ trợ trích xuất chất lượng tối đa từ YouTube, TikTok, Facebook và nhiều nền tảng khác chỉ với 1 chạm.',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInteractionCard(_HomeColors colors, bool isDark) {
    final platform = _platformMeta(_detectedPlatform, isDark);
    final isFocused = _urlFocusNode.hasFocus;
    final hasUrl = _urlController.text.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceStrong,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isFocused ? colors.accent : colors.borderStrong,
          width: isFocused ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isFocused ? colors.accent : Colors.black).withAlpha(isDark ? 30 : 15),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Input Field Area
          Container(
            height: 64,
            padding: const EdgeInsets.only(left: 16, right: 8),
            decoration: BoxDecoration(
              color: colors.surfaceSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    _detectedPlatform.isEmpty ? Icons.link_rounded : platform.icon,
                    key: ValueKey(_detectedPlatform),
                    color: _detectedPlatform.isEmpty ? colors.textMuted : platform.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    focusNode: _urlFocusNode,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Dán liên kết vào đây...',
                      hintStyle: TextStyle(
                        color: colors.textMuted,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onSubmitted: (_) => _analyzeUrl(),
                  ),
                ),
                // Action Icon Inside Input
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: hasUrl
                        ? () {
                      _urlController.clear();
                      _urlFocusNode.requestFocus();
                    }
                        : _pasteFromClipboard,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: hasUrl
                            ? colors.textMuted.withAlpha(20)
                            : colors.accent.withAlpha(20),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        hasUrl ? 'Xóa' : 'Dán',
                        style: TextStyle(
                          color: hasUrl ? colors.textSecondary : colors.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Primary Action Button
          SizedBox(
            width: double.infinity,
            height: 60,
            child: FilledButton(
              onPressed: _isAnalyzing ? null : () => _analyzeUrl(),
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
              child: _isAnalyzing
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Text(
                'Phân tích & Tải xuống',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformRow(_HomeColors colors, bool isDark) {
    final platforms = <_PlatformMeta>[
      _platformMeta('youtube', isDark),
      _platformMeta('tiktok', isDark),
      _platformMeta('facebook', isDark),
      _platformMeta('instagram', isDark),
      _platformMeta('twitter', isDark),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tương thích mượt mà',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: platforms.map((p) {
            final isSelected = _detectedPlatform == p.id;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected
                    ? p.color.withAlpha(20)
                    : colors.surfaceStrong,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? p.color.withAlpha(100) : colors.borderSoft,
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: p.color.withAlpha(30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ] : [],
              ),
              child: Icon(
                p.icon,
                color: isSelected ? p.color : colors.textMuted,
                size: 28,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatusPill(_HomeColors colors, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surfaceStrong.withAlpha(isDark ? 150 : 200),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: colors.borderSoft),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_rounded, size: 14, color: colors.success),
              const SizedBox(width: 6),
              Text(
                'An toàn',
                style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: 4, height: 4,
                decoration: BoxDecoration(color: colors.textMuted, shape: BoxShape.circle),
              ),
              Icon(Icons.sd_storage_rounded, size: 14, color: colors.accent),
              const SizedBox(width: 6),
              Text(
                _formattedStorage,
                style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _PlatformMeta _platformMeta(String id, bool isDark) {
    switch (id) {
      case 'youtube':
        return const _PlatformMeta(id: 'youtube', name: 'YouTube', icon: Icons.play_arrow_rounded, color: Color(0xFFFF3B30));
      case 'tiktok':
        return const _PlatformMeta(id: 'tiktok', name: 'TikTok', icon: Icons.music_note_rounded, color: Color(0xFF19E3D4));
      case 'facebook':
        return const _PlatformMeta(id: 'facebook', name: 'Facebook', icon: Icons.facebook_rounded, color: Color(0xFF4C8DFF));
      case 'instagram':
        return const _PlatformMeta(id: 'instagram', name: 'Instagram', icon: Icons.camera_alt_rounded, color: Color(0xFFFF4D91));
      case 'twitter':
        return _PlatformMeta(id: 'twitter', name: 'X / Twitter', icon: Icons.alternate_email_rounded, color: isDark ? Colors.white : const Color(0xFF111827));
      case 'vimeo':
        return const _PlatformMeta(id: 'vimeo', name: 'Vimeo', icon: Icons.video_library_rounded, color: Color(0xFF35B7F3));
      case 'direct':
        return const _PlatformMeta(id: 'direct', name: 'Direct Link', icon: Icons.language_rounded, color: Color(0xFF14B8A6));
      default:
        return const _PlatformMeta(id: '', name: 'Tự động', icon: Icons.link_rounded, color: Color(0xFF3B82F6));
    }
  }
}

// --- HELPER WIDGETS & CLASSES ---

class _GlowingOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowingOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
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

class _HomeColors {
  const _HomeColors({
    required this.background,
    required this.surfaceStrong,
    required this.surfaceSoft,
    required this.borderStrong,
    required this.borderSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.success,
  });

  final Color background;
  final Color surfaceStrong;
  final Color surfaceSoft;
  final Color borderStrong;
  final Color borderSoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color success;

  static _HomeColors resolve(bool isDark) {
    if (isDark) {
      return _HomeColors(
        background: const Color(0xFF09090B), // Very deep black/gray
        surfaceStrong: const Color(0xFF18181B), // Slightly lighter surface
        surfaceSoft: const Color(0xFF27272A).withAlpha(120),
        borderStrong: Colors.white.withAlpha(25),
        borderSoft: Colors.white.withAlpha(12),
        textPrimary: const Color(0xFFFAFAFA),
        textSecondary: const Color(0xFFA1A1AA),
        textMuted: const Color(0xFF71717A),
        accent: const Color(0xFF4F46E5), // Indigo accent
        success: const Color(0xFF10B981),
      );
    }

    return _HomeColors(
      background: const Color(0xFFF8FAFC), // Off-white/slate
      surfaceStrong: Colors.white,
      surfaceSoft: const Color(0xFFF1F5F9),
      borderStrong: const Color(0xFFE2E8F0),
      borderSoft: const Color(0xFFF1F5F9),
      textPrimary: const Color(0xFF0F172A),
      textSecondary: const Color(0xFF475569),
      textMuted: const Color(0xFF94A3B8),
      accent: const Color(0xFF4338CA), // Deep Indigo
      success: const Color(0xFF059669),
    );
  }
}