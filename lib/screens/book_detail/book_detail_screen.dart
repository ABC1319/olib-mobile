import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_filex/open_filex.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/book.dart';
import '../../providers/books_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/domain_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/update_service.dart';
import '../../routes/app_routes.dart';
import '../similar/similar_books_screen.dart';
import '../reader/reader_screen.dart';

class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ModalRoute.of(context)!.settings.arguments as Book;
    final tasks = ref.watch(downloadProvider);
    final l10n = AppLocalizations.of(context);

    DownloadTask? downloadTask;
    try {
      downloadTask = tasks.firstWhere((t) => t.id == book.id.toString());
    } catch (_) {}

    final isDownloading = downloadTask?.status == DownloadStatus.downloading;
    final isCompleted = downloadTask?.status == DownloadStatus.completed;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Watch favorite state
    final favAsync = ref.watch(isBookFavoritedProvider(book.id.toString()));
    final isFavorited = favAsync.valueOrNull ?? false;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.background,
      // ── Sticky Bottom Action Bar ──
      bottomNavigationBar: _buildBottomBar(
        context, ref, book, downloadTask, isDownloading, isCompleted, l10n, isDark,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 1. Hero Section with Glassmorphism ──
          _buildHeroSection(context, ref, book, isDark, isFavorited),

          // ── 2. Content Body ──
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -32),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha:isDark ? 0.3 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Series / Subtitle ──
                    if (book.series != null && book.series!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          book.series!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    // ── Main Title ──
                    Text(
                      book.title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ── Author ──
                    if (book.author != null && book.author!.isNotEmpty)
                      Text(
                        book.author!,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                    const SizedBox(height: 20),

                    // ── Metadata Capsules ──
                    _buildMetadataCapsules(context, book, isDark),

                    // ── Description ──
                    if (book.description != null && book.description!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        l10n.get('description'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        book.description!,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: isDark ? Colors.white70 : AppColors.textSecondary,
                        ),
                      ),
                    ],

                    // ── Similar Books Entry Card ──
                    if (book.hash != null && book.hash!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSimilarBooksCard(context, book, isDark, l10n),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  HERO SECTION — Blurred cover background + 3D book cover
  // ════════════════════════════════════════════════════════════
  Widget _buildHeroSection(
    BuildContext context, WidgetRef ref, Book book, bool isDark, bool isFavorited,
  ) {
    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.background,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black26,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      actions: [
        // ── Favorite Heart Icon ──
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black26,
            child: IconButton(
              icon: Icon(
                isFavorited ? Icons.favorite : Icons.favorite_border,
                color: isFavorited ? Colors.redAccent : Colors.white,
                size: 20,
              ),
              onPressed: () async {
                final bookId = book.id.toString();
                if (isFavorited) {
                  await ref.read(savedBooksProvider.notifier).unsaveBook(bookId);
                } else {
                  await ref.read(savedBooksProvider.notifier).saveBook(bookId);
                }
                // Refresh the favorite state
                ref.invalidate(isBookFavoritedProvider(bookId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isFavorited ? '已取消收藏' : AppLocalizations.of(context).get('like')),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // ── Layer 1: Blurred Cover Background ──
            if (book.cover != null)
              CachedNetworkImage(
                imageUrl: book.cover!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.primary.withValues(alpha:0.3),
                ),
              )
            else
              Container(color: AppColors.primary.withValues(alpha:0.3)),

            // ── Layer 2: Blur Filter ──
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(color: Colors.transparent),
              ),
            ),

            // ── Layer 3: Gradient Overlay ──
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha:0.4),
                    Colors.black.withValues(alpha:0.2),
                    (isDark ? const Color(0xFF121212) : AppColors.background).withValues(alpha:0.8),
                    isDark ? const Color(0xFF121212) : AppColors.background,
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),

            // ── Layer 4: 3D Book Cover ──
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 48, bottom: 32),
                child: _build3DBookCover(book),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  3D BOOK COVER — Drop shadow + slight perspective
  // ════════════════════════════════════════════════════════════
  Widget _build3DBookCover(Book book) {
    return Container(
      height: 220,
      width: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.5),
            blurRadius: 24,
            offset: const Offset(8, 12),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha:0.2),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: book.cover != null
            ? CachedNetworkImage(
                imageUrl: book.cover!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _buildCoverPlaceholder(book),
              )
            : _buildCoverPlaceholder(book),
      ),
    );
  }

  Widget _buildCoverPlaceholder(Book book) {
    return Container(
      color: AppColors.primary.withValues(alpha:0.15),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_rounded, size: 40, color: AppColors.primary),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                book.title,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  METADATA CAPSULES — Horizontal Wrap of key info
  // ════════════════════════════════════════════════════════════
  Widget _buildMetadataCapsules(BuildContext context, Book book, bool isDark) {
    final capsules = <Widget>[];

    // Format
    if (book.extension != null && book.extension!.isNotEmpty) {
      capsules.add(_capsule(
        Icons.description_outlined,
        book.extension!.toUpperCase(),
        isDark,
        highlight: true,
      ));
    }

    // File size
    if (book.filesizeString != null && book.filesizeString!.isNotEmpty) {
      capsules.add(_capsule(Icons.storage_outlined, book.filesizeString!, isDark));
    }

    // Year
    if (book.year != null && book.year != 0) {
      capsules.add(_capsule(Icons.calendar_today_outlined, '${book.year}', isDark));
    }

    // Publisher
    if (book.publisher != null && book.publisher!.isNotEmpty) {
      capsules.add(_capsule(Icons.business_outlined, book.publisher!, isDark));
    }

    // Pages — hide if 0 or null
    if (book.pages != null && book.pages != 0) {
      capsules.add(_capsule(Icons.auto_stories_outlined, '${book.pages} p', isDark));
    }

    // Language tag
    if (book.language != null && book.language!.isNotEmpty) {
      capsules.add(_languageTag(book.language!, isDark));
    }

    if (capsules.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: capsules,
    );
  }

  Widget _capsule(IconData icon, String text, bool isDark, {bool highlight = false}) {
    final bgColor = highlight
        ? AppColors.primary.withValues(alpha:0.12)
        : (isDark ? Colors.white.withValues(alpha:0.08) : const Color(0xFFF0F2F5));
    final fgColor = highlight
        ? AppColors.primary
        : (isDark ? Colors.white70 : AppColors.textSecondary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fgColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                color: fgColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageTag(String language, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha:0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.info.withValues(alpha:0.3),
          width: 1,
        ),
      ),
      child: Text(
        language,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.info,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SIMILAR BOOKS ENTRY — Card-style navigation
  // ════════════════════════════════════════════════════════════
  Widget _buildSimilarBooksCard(
    BuildContext context, Book book, bool isDark, AppLocalizations l10n,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).pushNamed(
          AppRoutes.similarBooks,
          arguments: SimilarBooksArgs(
            bookId: book.id,
            hashId: book.hash!,
            bookTitle: book.title,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha:0.06)
              : AppColors.primary.withValues(alpha:0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha:0.1)
                : AppColors.primary.withValues(alpha:0.15),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha:0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.get('similar_books'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDark ? 'Discover more like this' : '发现更多类似书籍',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  BOTTOM ACTION BAR — Read + Download sticky bar
  // ════════════════════════════════════════════════════════════
  Widget _buildBottomBar(
    BuildContext context,
    WidgetRef ref,
    Book book,
    DownloadTask? downloadTask,
    bool isDownloading,
    bool isCompleted,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final hasReadOnline = book.readOnlineUrl != null && book.readOnlineUrl!.isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 12, 20, MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Download Button (Secondary or Primary if no read) ──
          Expanded(
            child: _buildDownloadButton(
              context, ref, book, downloadTask,
              isDownloading, isCompleted, l10n, isDark,
              isPrimary: !hasReadOnline,
            ),
          ),

          if (hasReadOnline) ...[
            const SizedBox(width: 12),

            // ── Read Button (Primary) ──
            Expanded(
              child: _buildReadButton(context, ref, book, l10n, isDark),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadButton(
    BuildContext context,
    WidgetRef ref,
    Book book,
    DownloadTask? downloadTask,
    bool isDownloading,
    bool isCompleted,
    AppLocalizations l10n,
    bool isDark, {
    bool isPrimary = false,
  }) {
    final IconData icon;
    final String label;

    if (isCompleted) {
      icon = Icons.folder_open_rounded;
      label = l10n.get('open_file');
    } else if (isDownloading) {
      icon = Icons.downloading_rounded;
      label = '${(downloadTask!.progress * 100).toStringAsFixed(0)}%';
    } else {
      icon = Icons.download_rounded;
      label = l10n.get('download');
    }

    if (isPrimary) {
      return SizedBox(
        height: 50,
        child: ElevatedButton.icon(
          onPressed: isDownloading ? null : () => _handleDownload(
            context, ref, book, downloadTask, isCompleted,
          ),
          icon: Icon(icon, size: 20),
          label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: isCompleted ? AppColors.success : AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
      );
    }

    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: isDownloading ? null : () => _handleDownload(
          context, ref, book, downloadTask, isCompleted,
        ),
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: isCompleted
              ? AppColors.success
              : (isDark ? Colors.white : AppColors.primary),
          side: BorderSide(
            color: isCompleted
                ? AppColors.success
                : (isDark ? Colors.white30 : AppColors.primary.withValues(alpha:0.5)),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildReadButton(
    BuildContext context, WidgetRef ref, Book book,
    AppLocalizations l10n, bool isDark,
  ) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: () => _handleRead(context, ref, book),
        icon: const Icon(Icons.menu_book_rounded, size: 20),
        label: Text(
          l10n.get('read'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  ACTION HANDLERS (unchanged logic, extracted for clarity)
  // ════════════════════════════════════════════════════════════
  void _handleRead(BuildContext context, WidgetRef ref, Book book) {
    final customDomain = ref.read(domainProvider);
    final authState = ref.read(authProvider);
    final user = authState.user;

    // Build the reader domain from the custom domain:
    // - If the domain has a language prefix (e.g. zh.bra101.ru), replace it with 'reader'
    // - Otherwise (e.g. pkuedu.online), prepend 'reader.' to the domain
    final String readerDomain;
    final languagePrefixes = {'zh', 'en', 'de', 'fr', 'es', 'it', 'pt', 'ja', 'ko', 'ru', 'ar'};
    final dotIndex = customDomain.indexOf('.');
    if (dotIndex > 0) {
      final prefix = customDomain.substring(0, dotIndex);
      if (languagePrefixes.contains(prefix)) {
        readerDomain = 'reader${customDomain.substring(dotIndex)}';
      } else {
        readerDomain = 'reader.$customDomain';
      }
    } else {
      readerDomain = 'reader.$customDomain';
    }

    String url = book.readOnlineUrl!;
    url = url.replaceAll(RegExp(r'cdn\.reader\.'), 'reader.');
    url = url.replaceAll(RegExp(r'reader\.[a-zA-Z0-9.-]+'), readerDomain);
    url = url.replaceAll(RegExp(r'z-library\.[a-zA-Z]+'), customDomain);

    if (user != null) {
      final separator = url.contains('?') ? '&' : '?';
      url = '$url${separator}remix_userkey=${user.remixUserkey}&remix_userid=${user.id}';
    }

    Navigator.of(context).pushNamed(
      AppRoutes.reader,
      arguments: ReaderArgs(url: url, title: book.title),
    );
  }

  void _handleDownload(
    BuildContext context, WidgetRef ref, Book book,
    DownloadTask? downloadTask, bool isCompleted,
  ) async {
    // Check for force update block
    if (UpdateService.isBlocked && !isCompleted) {
      final locale = Localizations.localeOf(context).languageCode;
      final isZh = locale == 'zh';

      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        animType: AnimType.bottomSlide,
        title: isZh ? '功能已禁用' : 'Feature Disabled',
        desc: isZh
            ? '当前版本已过期，请更新到最新版本后使用下载功能。'
            : 'This version is outdated. Please update to use download.',
        btnOkText: isZh ? '立即更新' : 'Update Now',
        btnOkColor: AppColors.primary,
        btnOkOnPress: () {
          if (UpdateService.downloadUrl != null) {
            launchUrl(
              Uri.parse(UpdateService.downloadUrl!),
              mode: LaunchMode.externalApplication,
            );
          }
        },
      ).show();
      return;
    }

    if (isCompleted && downloadTask?.filePath != null) {
      OpenFilex.open(downloadTask!.filePath!);
    } else {
      // Check if file already exists
      final existingPath = await ref
          .read(downloadProvider.notifier)
          .checkFileExists(book);

      if (existingPath != null && context.mounted) {
        final locale = Localizations.localeOf(context).languageCode;
        final isZh = locale == 'zh';

        AwesomeDialog(
          context: context,
          dialogType: DialogType.info,
          animType: AnimType.bottomSlide,
          title: isZh ? '文件已存在' : 'File Already Exists',
          desc: isZh
              ? '这本书已经下载过了。\n\n您可以打开现有文件或重新下载。'
              : 'This book has already been downloaded.\n\nYou can open the existing file or download again.',
          btnCancelText: isZh ? '打开文件' : 'Open File',
          btnCancelColor: Colors.green,
          btnCancelOnPress: () {
            OpenFilex.open(existingPath);
          },
          btnOkText: isZh ? '重新下载' : 'Download Again',
          btnOkColor: AppColors.primary,
          btnOkOnPress: () {
            ref.read(downloadProvider.notifier).startDownload(book);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context).get('downloading')),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
        ).show();
        return;
      }

      ref.read(downloadProvider.notifier).startDownload(book);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).get('downloading')),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}
