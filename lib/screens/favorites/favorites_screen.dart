import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'package:olib_api_plugin/olib_api_plugin.dart';
import '../../providers/books_provider.dart';
import '../../screens/book_detail/book_detail_screen.dart';
import '../../services/booklist_import_service.dart';
import '../../services/booklist_share_codec.dart';
import '../../services/share_intent_handler.dart';
import '../../utils/booklist_file_utils.dart';
import '../../widgets/book_card.dart';
import '../../widgets/book_list_tile.dart';
import '../../widgets/share_preview_sheet.dart'; // [New]
import 'scanner_screen.dart'; // [New]
import '../../theme/app_colors.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  bool _isListView = false;
  bool _isSelectMode = false;
  Set<int> _selectedBookIds = {};

  @override
  Widget build(BuildContext context) {
    final savedBooksAsync = ref.watch(savedBooksProvider);
    final l = AppLocalizations.of(context);

    // 系统分享/深链投递进来的书单，自动跑导入流程
    ref.listen<BooklistShareData?>(pendingBooklistImportProvider,
        (prev, next) {
      if (next == null) return;
      ref.read(pendingBooklistImportProvider.notifier).state = null;
      _runImport(l, next);
    });

    return Scaffold(
      body: savedBooksAsync.when(
        data: (books) => CustomScrollView(
          slivers: [
            _buildSliverAppBar(l, books),
            if (books.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(l),
              )
            else ...[
              SliverToBoxAdapter(child: _buildInfoBar(l, books.length)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: _isListView
                    ? _buildSliverList(books)
                    : _buildSliverGrid(books),
              ),
            ],
          ],
        ),
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l.get('loading_favorites')),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Text('${l.get('error')}: $err'),
        ),
      ),
      bottomNavigationBar: _isSelectMode && _selectedBookIds.isNotEmpty
          ? _buildBottomBar(l, savedBooksAsync)
          : null,
    );
  }

  // ─── AppBar ───────────────────────────────────────────

  Widget _buildSliverAppBar(AppLocalizations l, List<Book> books) {
    if (_isSelectMode) {
      return SliverAppBar(
        pinned: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() {
            _isSelectMode = false;
            _selectedBookIds.clear();
          }),
        ),
        title: Text(
          '${_selectedBookIds.length} / ${books.length}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final allIds =
                  books.map((b) => b.id).whereType<int>().toSet();
              setState(() {
                if (_selectedBookIds.length == allIds.length) {
                  _selectedBookIds.clear();
                } else {
                  _selectedBookIds = Set.from(allIds);
                }
              });
            },
            child: Text(
              _selectedBookIds.length == books.length
                  ? l.get('deselect_all')
                  : l.get('select_all'),
            ),
          ),
        ],
      );
    }

    return SliverAppBar.large(
      pinned: true,
      title: Text(
        l.get('favorites'),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      actions: [
        PopupMenuButton<_ImportSource>(
          tooltip: l.get('import_booklist'),
          icon: const Icon(Icons.file_download_outlined),
          onSelected: (src) => _handleImport(l, src),
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: _ImportSource.scan,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.qr_code_scanner_rounded),
                title: Text(l.get('import_from_scan')),
              ),
            ),
            PopupMenuItem(
              value: _ImportSource.paste,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.content_paste_rounded),
                title: Text(l.get('import_from_paste')),
              ),
            ),
            PopupMenuItem(
              value: _ImportSource.file,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(l.get('import_from_file')),
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ─── Info Bar ─────────────────────────────────────────

  Widget _buildInfoBar(AppLocalizations l, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            l.get('books_count').replaceAll('%d', '$count'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          // View mode toggle
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildViewToggle(
                  icon: Icons.grid_view_rounded,
                  selected: !_isListView,
                  onTap: () => setState(() => _isListView = false),
                  tooltip: l.get('grid_view'),
                ),
                _buildViewToggle(
                  icon: Icons.view_list_rounded,
                  selected: _isListView,
                  onTap: () => setState(() => _isListView = true),
                  tooltip: l.get('list_view'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha:0.12) : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 20,
            color: selected
                ? AppColors.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  // ─── Grid View ────────────────────────────────────────

  Widget _buildSliverGrid(List<Book> books) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.58,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final book = books[index];
          final isSelected = _selectedBookIds.contains(book.id);

          return GestureDetector(
            onLongPress: () => _enterSelectModeWith(book.id),
            child: Stack(
              children: [
                BookCard(
                  book: book,
                  onTap: () {
                    if (_isSelectMode) {
                      _toggleSelection(book.id);
                    } else {
                      _navigateToDetail(book);
                    }
                  },
                ),
                if (_isSelectMode)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _toggleSelection(book.id),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        childCount: books.length,
      ),
    );
  }

  // ─── List View ────────────────────────────────────────

  Widget _buildSliverList(List<Book> books) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final book = books[index];
          final isSelected = _selectedBookIds.contains(book.id);

          final tile = _isSelectMode
              ? Row(
                  children: [
                    Checkbox(
                      value: isSelected,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (_) => _toggleSelection(book.id),
                    ),
                    Expanded(
                      child: BookListTile(
                        book: book,
                        onTap: () => _toggleSelection(book.id),
                      ),
                    ),
                  ],
                )
              : BookListTile(
                  book: book,
                  onTap: () => _navigateToDetail(book),
                );

          return GestureDetector(
            onLongPress: () => _enterSelectModeWith(book.id),
            child: tile,
          );
        },
        childCount: books.length,
      ),
    );
  }

  // ─── Empty State ──────────────────────────────────────

  Widget _buildEmptyState(AppLocalizations l) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha:0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bookmark_border_rounded,
              size: 56,
              color: AppColors.primary.withValues(alpha:0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l.get('no_favorites'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l.get('save_books_hint'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom Bar (select mode) ─────────────────────────

  Widget _buildBottomBar(AppLocalizations l, AsyncValue<List<Book>> booksAsync) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          // Batch remove
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _confirmBatchRemove(l),
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              label: Text(l.get('batch_remove')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[400],
                side: BorderSide(color: Colors.red[300]!),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Share booklist
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _showSharePreview(l, booksAsync),
              icon: const Icon(Icons.share_rounded, size: 20),
              label: Text(l.get('share_booklist')),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────

  void _toggleSelection(int? bookId) {
    if (bookId == null) return;
    setState(() {
      if (_selectedBookIds.contains(bookId)) {
        _selectedBookIds.remove(bookId);
      } else {
        _selectedBookIds.add(bookId);
      }
    });
  }

  void _enterSelectModeWith(int? bookId) {
    if (bookId == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectMode = true;
      _selectedBookIds.add(bookId);
    });
  }

  void _navigateToDetail(Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BookDetailScreen(),
        settings: RouteSettings(arguments: book),
      ),
    );
  }

  void _confirmBatchRemove(AppLocalizations l) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('confirm_remove_title')),
        content: Text(
          l.get('confirm_remove_msg').replaceAll('%d', '${_selectedBookIds.length}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.get('cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _batchRemove();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red[400],
            ),
            child: Text(l.get('remove')),
          ),
        ],
      ),
    );
  }

  Future<void> _batchRemove() async {
    final notifier = ref.read(savedBooksProvider.notifier);
    for (final id in _selectedBookIds.toList()) {
      await notifier.unsaveBook(id.toString());
    }
    if (mounted) {
      setState(() {
        _selectedBookIds.clear();
        _isSelectMode = false;
      });
    }
  }

  void _showSharePreview(AppLocalizations l, AsyncValue<List<Book>> booksAsync) {
    final allBooks = booksAsync.valueOrNull ?? [];
    final selectedBooks = allBooks
        .where((b) => _selectedBookIds.contains(b.id))
        .toList();

    if (selectedBooks.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SharePreviewSheet(books: selectedBooks),
    );
  }

  Future<void> _handleImport(AppLocalizations l, _ImportSource source) async {
    BooklistShareData? data;
    switch (source) {
      case _ImportSource.scan:
        final scanned = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScannerScreen()),
        );
        if (scanned is String) {
          data = BooklistShareCodec.tryDecode(scanned);
        }
        break;
      case _ImportSource.paste:
        data = await _pasteAndDecode(l);
        break;
      case _ImportSource.file:
        try {
          data = await BooklistFileUtils.pickAndParse();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${l.get('error')}: $e')),
            );
          }
          return;
        }
        break;
    }

    if (!mounted) return;
    if (data == null || data.entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.get('invalid_booklist'))),
      );
      return;
    }

    await _runImport(l, data);
  }

  Future<BooklistShareData?> _pasteAndDecode(AppLocalizations l) async {
    final clip = await Clipboard.getData('text/plain');
    final initial = clip?.text ?? '';
    if (!mounted) return null;

    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('paste_token')),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: l.get('paste_token_hint'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l.get('import')),
          ),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return null;
    return BooklistShareCodec.tryDecode(result);
  }

  Future<void> _runImport(
      AppLocalizations l, BooklistShareData data) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(l.get('processing'))),
    );

    final service = ref.read(booklistImportServiceProvider);
    final r = await service.importFromData(data);

    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    final msg = l
        .get('import_result')
        .replaceAll('%i', '${r.imported}')
        .replaceAll('%s', '${r.skipped}')
        .replaceAll('%f', '${r.failed}');
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: r.imported > 0 ? Colors.green : null,
      ),
    );
  }
}

enum _ImportSource { scan, paste, file }
