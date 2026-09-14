import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings_vi.dart';
import '../../../core/theme/theme_provider.dart';
import '../../resolver/domain/resolver_registry.dart';
import '../../settings/presentation/storage_settings_screen.dart';
import 'analyze_sheet.dart';
import 'widgets/home_download_pulse_card.dart';
import 'widgets/quick_platform_grid.dart';
import 'widgets/smart_clipboard_banner.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();

  bool _isAnalyzing = false;
  String _detectedPlatform = '';
  String? _clipboardUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _urlController.addListener(_onUrlChanged);
    _checkClipboardForLink();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboardForLink();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkClipboardForLink() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isNotEmpty &&
          (text.startsWith('http://') || text.startsWith('https://')) &&
          text != _urlController.text.trim()) {
        if (mounted) {
          setState(() => _clipboardUrl = text);
        }
      }
    } catch (_) {}
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

    if (mounted && _detectedPlatform != detected) {
      setState(() => _detectedPlatform = detected);
    }
  }

  Future<void> _pasteFromClipboard() async {
    HapticFeedback.selectionClick();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';

    if (text.isEmpty) {
      _showToast('Bộ nhớ tạm đang trống. Hãy sao chép liên kết trước!');
      return;
    }

    _urlController.text = text;
    _urlController.selection = TextSelection.collapsed(offset: text.length);
    setState(() => _clipboardUrl = null);
    _startAnalysis(text);
  }

  Future<void> _startAnalysis([String? targetUrl]) async {
    final raw = targetUrl ?? _urlController.text.trim();
    if (raw.isEmpty) {
      _showToast('Vui lòng nhập hoặc dán liên kết để bắt đầu!');
      return;
    }

    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      _showToast('Liên kết không hợp lệ! Cần bắt đầu bằng https://');
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
      setState(() => _clipboardUrl = null);

      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AnalyzeSheet(mediaInfo: info),
      );
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _showToast('Không thể phân tích liên kết này. Lỗi: $e');
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thanh Tiêu đề & Cài đặt giao diện
              _buildTopHeader(isDark, textPrimary, textSecondary),

              const SizedBox(height: 20),

              // Thẻ thông báo phát hiện liên kết trong bộ nhớ tạm
              if (_clipboardUrl != null)
                SmartClipboardBanner(
                  detectedUrl: _clipboardUrl!,
                  onAnalyze: () {
                    _urlController.text = _clipboardUrl!;
                    _startAnalysis(_clipboardUrl!);
                  },
                  onDismiss: () {
                    setState(() => _clipboardUrl = null);
                  },
                ),

              // Thẻ Trung tâm Chỉ huy Nhập Liên kết
              _buildInputCard(isDark, textPrimary, textSecondary),

              const SizedBox(height: 24),

              // Lưới Nền tảng Hỗ trợ Thuần Việt
              QuickPlatformGrid(
                activePlatform: _detectedPlatform,
                onPlatformTap: (platform) {},
              ),

              // Thẻ nhịp đập theo dõi tiến trình tải
              const HomeDownloadPulseCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(bool isDark, Color textPrimary, Color textSecondary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 80 : 25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStringsVi.appName,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  AppStringsVi.appSlogan,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            // Nút chuyển đổi Theme Sáng/Tối
            IconButton(
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: textPrimary,
              ),
              tooltip: isDark ? 'Chuyển sang Chế độ Sáng' : 'Chuyển sang Chế độ Tối',
              onPressed: () {
                HapticFeedback.selectionClick();
                ref.read(themeModeProvider.notifier).toggleTheme();
              },
            ),
            // Nút vào trung tâm quản lý bộ nhớ
            IconButton(
              icon: Icon(Icons.pie_chart_outline_rounded, color: textPrimary),
              tooltip: AppStringsVi.storageCenter,
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StorageSettingsScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInputCard(bool isDark, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 60 : 10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStringsVi.heroTitle,
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppStringsVi.heroSubtitle,
            style: TextStyle(
              color: textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // Ô nhập đường dẫn
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _urlFocusNode.hasFocus
                    ? AppColors.accentCyan
                    : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                width: 1.3,
              ),
            ),
            child: TextField(
              controller: _urlController,
              focusNode: _urlFocusNode,
              style: TextStyle(color: textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: AppStringsVi.inputPlaceholder,
                hintStyle: TextStyle(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary, fontSize: 13),
                prefixIcon: const Icon(Icons.link_rounded, color: AppColors.accentCyan, size: 22),
                suffixIcon: _urlController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _urlController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Hàng nút hành động: Dán & Phân tích
          Row(
            children: [
              // Nút Dán liên kết
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                label: Text(
                  AppStringsVi.pasteButton,
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                onPressed: _pasteFromClipboard,
              ),
              const SizedBox(width: 10),

              // Nút Bắt đầu Tải
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentCyan.withAlpha(isDark ? 90 : 50),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _isAnalyzing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black),
                          )
                        : const Icon(Icons.bolt_rounded, color: Colors.black, size: 22),
                    label: Text(
                      _isAnalyzing ? AppStringsVi.analyzing : AppStringsVi.analyzeButton,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                    onPressed: _isAnalyzing ? null : () => _startAnalysis(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
