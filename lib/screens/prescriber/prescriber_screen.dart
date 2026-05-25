import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/prescription.dart';
import '../../providers/prescriber_provider.dart';
import '../../providers/backend_auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';

class PrescriberScreen extends ConsumerStatefulWidget {
  const PrescriberScreen({super.key});

  @override
  ConsumerState<PrescriberScreen> createState() => _PrescriberScreenState();
}

class _PrescriberScreenState extends ConsumerState<PrescriberScreen>
    with TickerProviderStateMixin {
  final _inputController = TextEditingController();
  late AnimationController _animController;
  late AnimationController _loadingController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    // 每次进入页面时重置状态，避免残留的 done 状态导致白屏
    Future.microtask(() {
      ref.read(prescriberProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _animController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  /// 检查授权状态，未授权则跳转扫码页
  Future<bool> _ensureAuthorized() async {
    final authState = ref.read(backendAuthProvider);
    if (authState.isAuthorized) return true;

    final result = await Navigator.pushNamed(context, AppRoutes.qrAuth);
    return result == true;
  }

  void _diagnoseWithTheme(String themeId) async {
    if (!await _ensureAuthorized()) return;
    final locale = Localizations.localeOf(context).languageCode;
    ref.read(prescriberProvider.notifier).diagnose(
      input: themeId,
      inputType: 'theme',
      language: locale == 'zh' ? 'zh' : 'en',
    );
    _animController.forward(from: 0);
  }

  void _diagnoseWithInput() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    if (!await _ensureAuthorized()) return;
    final locale = Localizations.localeOf(context).languageCode;
    ref.read(prescriberProvider.notifier).diagnose(
      input: text,
      inputType: 'free',
      language: locale == 'zh' ? 'zh' : 'en',
    );
    _animController.forward(from: 0);
    FocusScope.of(context).unfocus();
  }

  /// 重试上一次失败：自由输入有内容则用自由输入，否则不动
  void _retryLastInput() {
    if (_inputController.text.trim().isNotEmpty) {
      _diagnoseWithInput();
    }
  }

  void _reset() {
    ref.read(prescriberProvider.notifier).reset();
    _inputController.clear();
    _animController.reset();
  }

  void _onGetBook(ReadingTip tip) {
    if (tip.matchedBook != null) {
      Navigator.of(context).pushNamed(
        AppRoutes.bookDetail,
        arguments: tip.matchedBook,
      );
    } else {
      Navigator.of(context).pushNamed(AppRoutes.search);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(prescriberProvider);
    final locale = Localizations.localeOf(context).languageCode;
    final isZh = locale == 'zh';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha:0.08),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                floating: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  isZh ? '✨ AI 智阅锦囊' : '✨ AI Reading Bag',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                centerTitle: true,
                actions: [
                  if (state.status == PrescriberStatus.done)
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          color: AppColors.primary),
                      onPressed: _reset,
                      tooltip: isZh ? '重新开始' : 'Start Over',
                    ),
                ],
              ),

              // Content
              if (state.status == PrescriberStatus.idle ||
                  state.status == PrescriberStatus.error)
                _buildInputSection(isZh),

              if (state.status == PrescriberStatus.loading)
                _buildLoadingSection(isZh),

              if (state.status == PrescriberStatus.done &&
                  state.result != null)
                _buildResultSection(state.result!, isZh),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 输入阶段 ====================
  Widget _buildInputSection(bool isZh) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            // 错误提示横条
            _buildErrorBanner(isZh),
            // 顶部引导文案
            Text(
              isZh ? '选一个最近的状态' : 'Pick your current mood',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isZh
                  ? '我们会为你推荐最合适的书'
                  : "We'll recommend the perfect books for you",
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // 格式筛选
            _buildFormatPicker(isZh),
            const SizedBox(height: 16),

            // 预设主题卡片
            ..._buildThemeCards(isZh),

            const SizedBox(height: 28),

            // 分隔线
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    isZh ? '或者用自己的话描述' : 'Or describe in your own words',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[300])),
              ],
            ),
            const SizedBox(height: 20),

            // 自由输入框
            TextField(
              controller: _inputController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: isZh
                    ? '描述一下你最近的状态或困惑...'
                    : 'Describe how you feel lately...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),

            // 生成锦囊按钮
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _diagnoseWithInput,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isZh ? '生成锦囊' : 'Generate Reading Bag',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(bool isZh) {
    final state = ref.watch(prescriberProvider);
    if (state.status != PrescriberStatus.error || state.errorMessage == null) {
      return const SizedBox.shrink();
    }
    final canRetry = _inputController.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3F0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFCDC2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFE65A3D), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isZh ? '生成失败' : 'Failed to generate',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE65A3D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    state.errorMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (canRetry)
              TextButton(
                onPressed: _retryLastInput,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE65A3D),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(isZh ? '重试' : 'Retry'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatPicker(bool isZh) {
    final currentFormat = ref.watch(prescriberProvider).preferredFormat;
    final formats = <String?>[null, 'pdf', 'epub', 'mobi'];
    final labels = <String?>['${isZh ? '不限' : 'Any'}', 'PDF', 'EPUB', 'MOBI'];

    return Row(
      children: [
        Icon(Icons.filter_list_rounded,
            size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          isZh ? '格式' : 'Format',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 10),
        ...List.generate(formats.length, (i) {
          final fmt = formats[i];
          final selected = currentFormat == fmt;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(
                labels[i]!,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: selected,
              selectedColor: AppColors.primary,
              backgroundColor: Colors.grey[100],
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              onSelected: (_) {
                ref.read(prescriberProvider.notifier).setFormat(fmt);
              },
            ),
          );
        }),
      ],
    );
  }

  List<Widget> _buildThemeCards(bool isZh) {
    final themes = prescriberThemes;
    final List<Widget> rows = [];

    for (int i = 0; i < themes.length; i += 2) {
      final row = Row(
        children: [
          Expanded(
            child: _ThemeCard(
              theme: themes[i],
              isZh: isZh,
              onTap: () => _diagnoseWithTheme(themes[i].id),
            ),
          ),
          const SizedBox(width: 12),
          if (i + 1 < themes.length)
            Expanded(
              child: _ThemeCard(
                theme: themes[i + 1],
                isZh: isZh,
                onTap: () => _diagnoseWithTheme(themes[i + 1].id),
              ),
            )
          else
            const Expanded(child: SizedBox()),
        ],
      );
      rows.add(row);
      if (i + 2 < themes.length) {
        rows.add(const SizedBox(height: 12));
      }
    }
    return rows;
  }

  // ==================== 加载阶段 ====================
  Widget _buildLoadingSection(bool isZh) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 动画图标 — 持续旋转
            RotationTransition(
              turns: _loadingController,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha:0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isZh ? '正在为你挑选好书...' : 'AI is picking books for you...',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isZh ? '请稍候片刻' : 'Please wait a moment',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 结果阶段 ====================
  Widget _buildResultSection(ReadingBag bag, bool isZh) {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // 诊断单卡片
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha:0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 顶部装饰条
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha:0.8),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_stories,
                              color: Colors.white, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isZh ? '📜 你的专属阅读锦囊' : '📜 Your Reading Bag',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 诊断语
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha:0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha:0.15),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('💡', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                bag.diagnosis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.6,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 书目列表
                    ...bag.tips.asMap().entries.map((entry) {
                      final index = entry.key;
                      final tip = entry.value;
                      return _buildBookTip(tip, index + 1, isZh);
                    }),

                    const SizedBox(height: 20),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 重新开始按钮
              TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(isZh ? '重新开始' : 'Start Over'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookTip(ReadingTip tip, int index, bool isZh) {
    final dosages = ['第一味', '第二味', '第三味'];
    final dosagesEn = ['First', 'Second', 'Third'];
    final doseLabel = isZh
        ? (index <= 3 ? dosages[index - 1] : '第${index}味')
        : (index <= 3 ? dosagesEn[index - 1] : '#$index');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: GestureDetector(
        onTap: tip.isSearching ? null : () => _onGetBook(tip),
        child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：剂次 + 类别
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    doseLabel,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha:0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tip.category,
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 书名 + 作者
            Text(
              '📖 ${tip.bookName}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tip.author,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),

            // 推荐理由
            Text(
              tip.reason,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),

            // 去找书 按钮
            SizedBox(
              width: double.infinity,
              height: 40,
              child: tip.isSearching
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => _onGetBook(tip),
                      icon: Icon(
                        tip.matchedBook != null
                            ? Icons.download_rounded
                            : Icons.search_rounded,
                        size: 18,
                      ),
                      label: Text(
                        tip.matchedBook != null
                            ? (isZh ? '查看并下载' : 'View & Download')
                            : (isZh ? '去找书' : 'Find Book'),
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tip.matchedBook != null
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        side: BorderSide(
                          color: tip.matchedBook != null
                              ? AppColors.primary
                              : Colors.grey[300]!,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ==================== 主题卡片组件 ====================
class _ThemeCard extends StatelessWidget {
  final PrescriberTheme theme;
  final bool isZh;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isZh,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(theme.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isZh ? theme.labelZh : theme.labelEn,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
