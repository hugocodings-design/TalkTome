import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/talktome_theme.dart';
import '../widgets/tomy.dart';
import '../models/ebook.dart';
import '../models/folder.dart';
import 'reader_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Box<Ebook>? _ebookBox;
  Box<Folder>? _folderBox;
  bool _isSelectionMode = false;
  Set<String> _selectedIds = {};
  String? _currentFolderId; // null = racine (tous les livres sans dossier)

  @override
  void initState() {
    super.initState();
    _initializeHive();
  }

  void _initializeHive() {
    // Les boxes sont déjà ouvertes dans main.dart — on les récupère directement
    setState(() {
      _ebookBox = Hive.box<Ebook>('ebooks');
      _folderBox = Hive.box<Folder>('folders');
    });
  }

  // ─── Getters filtrés ────────────────────────────────────────────────────────

  List<Folder> get _folders => _folderBox?.values.toList() ?? [];

  List<Ebook> get _visibleEbooks {
    if (_ebookBox == null) return [];
    return _ebookBox!.values
        .where((e) => e.folderId == _currentFolderId)
        .toList();
  }

  // ─── Upload ─────────────────────────────────────────────────────────────────

  // ─── Sélection ──────────────────────────────────────────────────────────────

  void _enterSelectionMode(String ebookId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds = {ebookId};
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds = {};
    });
  }

  void _toggleSelection(String ebookId) {
    setState(() {
      if (_selectedIds.contains(ebookId)) {
        _selectedIds.remove(ebookId);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(ebookId);
      }
    });
  }

  // ─── Actions sur un livre ────────────────────────────────────────────────────

  Future<void> _renameEbook(Ebook ebook) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: ebook.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.home_renameBookTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.home_titleFieldLabel),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.home_rename),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty && newTitle != ebook.title) {
      ebook.title = newTitle;
      await _ebookBox!.put(ebook.id, ebook);
      setState(() {});
    }
  }

  Future<void> _deleteEbook(Ebook ebook) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.home_deleteBookTitle),
        content: Text(l10n.home_deleteBookConfirm(ebook.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.common_delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _ebookBox!.delete(ebook.id);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.home_bookDeleted(ebook.title))),
        );
      }
    }
  }

  Future<void> _moveEbookToFolder(Ebook ebook) async {
    await _showMoveToFolderDialog([ebook.id]);
  }

  // ─── Actions sur la sélection ────────────────────────────────────────────────

  Future<void> _deleteSelected() async {
    final l10n = AppLocalizations.of(context)!;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.home_deleteBooksTitle),
        content: Text(l10n.home_deleteSelectedConfirm(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.common_delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final id in _selectedIds) {
        await _ebookBox!.delete(id);
      }
      _exitSelectionMode();
      setState(() {});
    }
  }

  Future<void> _moveSelected() async {
    await _showMoveToFolderDialog(_selectedIds.toList());
    _exitSelectionMode();
  }

  // ─── Dossiers ────────────────────────────────────────────────────────────────

  Future<void> _createFolder() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.home_newFolder),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.home_folderNameLabel),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.home_create),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final folder = Folder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        createdAt: DateTime.now(),
      );
      await _folderBox!.put(folder.id, folder);
      setState(() {});
    }
  }

  Future<void> _renameFolder(Folder folder) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: folder.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.home_renameFolderTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.home_nameLabel),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.home_rename),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != folder.name) {
      folder.name = newName;
      await _folderBox!.put(folder.id, folder);
      setState(() {});
    }
  }

  Future<void> _deleteFolder(Folder folder) async {
    final l10n = AppLocalizations.of(context)!;
    final bookCount = _ebookBox?.values
            .where((e) => e.folderId == folder.id)
            .length ??
        0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.home_deleteFolderTitle),
        content: Text(bookCount > 0
            ? l10n.home_deleteFolderWithBooksConfirm(bookCount, folder.name)
            : l10n.home_deleteFolderEmptyConfirm(folder.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.common_delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Déplacer les livres du dossier vers la racine
      for (final ebook in _ebookBox!.values.where((e) => e.folderId == folder.id)) {
        ebook.folderId = null;
        await _ebookBox!.put(ebook.id, ebook);
      }
      await _folderBox!.delete(folder.id);

      // Si on était dans ce dossier, revenir à la racine
      if (_currentFolderId == folder.id) {
        setState(() => _currentFolderId = null);
      }
      setState(() {});
    }
  }

  Future<void> _showMoveToFolderDialog(List<String> ebookIds) async {
    final l10n = AppLocalizations.of(context)!;
    final folders = _folders;
    String? targetFolderId = _currentFolderId;

    final result = await showDialog<String?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.home_moveToFolderTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Option racine
                RadioListTile<String?>(
                  title: Text(l10n.home_noFolderRoot),
                  value: null,
                  groupValue: targetFolderId,
                  onChanged: (v) => setDialogState(() => targetFolderId = v),
                ),
                // Dossiers existants
                ...folders.map((f) => RadioListTile<String?>(
                      title: Text(f.name),
                      value: f.id,
                      groupValue: targetFolderId,
                      onChanged: (v) =>
                          setDialogState(() => targetFolderId = v),
                    )),
                // Créer un nouveau dossier
                TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _createFolder();
                    // Rouvrir le dialog après création
                    if (mounted) await _showMoveToFolderDialog(ebookIds);
                  },
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: Text(l10n.home_newFolder),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.common_cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, targetFolderId ?? '__null__'),
              child: Text(l10n.home_move),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final folderId = result == '__null__' ? null : result;
      for (final id in ebookIds) {
        final ebook = _ebookBox!.get(id);
        if (ebook != null) {
          ebook.folderId = folderId;
          await _ebookBox!.put(id, ebook);
        }
      }
      setState(() {});
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_ebookBox == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ValueListenableBuilder(
      valueListenable: _ebookBox!.listenable(),
      builder: (context, _, __) {
        final books = _visibleEbooks;
        final folders = _folders;
        final isRoot = _currentFolderId == null;

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
          body: (books.isEmpty && folders.isEmpty && isRoot)
              ? _buildEmptyState()
              : _buildContent(books, folders, isRoot),
        );
      },
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    final l10n = AppLocalizations.of(context)!;
    final currentFolder = _currentFolderId != null
        ? _folderBox?.get(_currentFolderId)
        : null;

    return AppBar(
      leading: _currentFolderId != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _currentFolderId = null),
            )
          : null,
      title: Text(currentFolder?.name ?? 'TalkTome'),
      centerTitle: true,
      elevation: 0,
      actions: [
        if (_currentFolderId == null)
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: l10n.home_newFolder,
            onPressed: _createFolder,
          ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    final l10n = AppLocalizations.of(context)!;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitSelectionMode,
      ),
      title: Text(l10n.home_selectedCount(_selectedIds.length)),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.drive_file_move_outline),
          tooltip: l10n.home_move,
          onPressed: _moveSelected,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: l10n.common_delete,
          onPressed: _deleteSelected,
        ),
      ],
    );
  }

  Widget _buildContent(List<Ebook> books, List<Folder> folders, bool isRoot) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        // Dossiers (visibles seulement à la racine)
        if (isRoot && folders.isNotEmpty) ...[
          MysticSectionHeader(label: l10n.home_folders),
          ...folders.map((folder) => _buildFolderTile(folder)),
          const Divider(indent: 16, endIndent: 16),
        ],

        // Livres
        if (books.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                l10n.home_noBooksHere,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else ...[
          MysticSectionHeader(label: l10n.home_books),
          _buildEbookGrid(books),
        ],
      ],
    );
  }

  Widget _buildFolderTile(Folder folder) {
    final l10n = AppLocalizations.of(context)!;
    final bookCount = _ebookBox?.values
            .where((e) => e.folderId == folder.id)
            .length ??
        0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(Icons.folder_special_rounded, color: TT.accent(context), size: 32),
        title: Text(folder.name),
        subtitle: Text(l10n.home_booksCount(bookCount)),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (action) {
            if (action == 'rename') _renameFolder(folder);
            if (action == 'delete') _deleteFolder(folder);
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'rename',
              child: ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.home_rename),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(l10n.common_delete, style: const TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        onTap: () => setState(() => _currentFolderId = folder.id),
      ),
    );
  }

  Widget _buildProgressSubtitle(Ebook ebook) {
    final l10n = AppLocalizations.of(context)!;
    final total = ebook.totalSentences;
    final pos = ebook.lastReadPosition;
    final hasProgress = total > 0 && pos > 0;
    final progress = hasProgress ? (pos / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${ebook.chapters.length} chapitres • ${ebook.totalWords} mots',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 4),
        if (total > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            pos == 0
                ? l10n.home_notStarted
                : pos >= total - 1
                    ? l10n.home_finished
                    : l10n.home_percentReadSentence((progress * 100).round(), pos, total),
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  Widget _buildEbookGrid(List<Ebook> books) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.62,
        ),
        itemCount: books.length,
        itemBuilder: (context, i) => _buildEbookCard(books[i]),
      ),
    );
  }

  Widget _buildEbookCard(Ebook ebook) {
    final isSelected = _selectedIds.contains(ebook.id);
    final isPdf = ebook.fileFormat == 'pdf';
    final total = ebook.totalSentences;
    final pos = ebook.lastReadPosition;
    final progress = (total > 0 && pos > 0) ? (pos / total).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: _isSelectionMode
          ? () => _toggleSelection(ebook.id)
          : () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReaderScreen(ebook: ebook)),
              ).then((_) => setState(() {})),
      onLongPress: _isSelectionMode ? null : () => _enterSelectionMode(ebook.id),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.hardEdge,
        color: isSelected
            ? TT.accent(context).withOpacity(0.18)
            : Theme.of(context).colorScheme.surfaceContainerHigh.withOpacity(0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isSelected
                ? TT.accent(context)
                : TT.accent(context).withOpacity(0.22),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Couverture ────────────────────────────────────────────
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  BookCover(
                    title: ebook.title,
                    isPdf: isPdf,
                    coverImagePath: ebook.coverImagePath,
                  ),
                  if (_isSelectionMode)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white.withOpacity(0.85),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  if (!_isSelectionMode)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: _EbookCardMenu(
                        ebook: ebook,
                        onOpen: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ReaderScreen(ebook: ebook)),
                        ).then((_) => setState(() {})),
                        onRename: () => _renameEbook(ebook),
                        onSelect: () => _enterSelectionMode(ebook.id),
                        onMove: () => _moveEbookToFolder(ebook),
                        onDelete: () => _deleteEbook(ebook),
                      ),
                    ),
                ],
              ),
            ),
            // ── Infos ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 5, 6, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ebook.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  if (total > 0)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                                ),
                    ),
                  if (total > 0) const SizedBox(height: 2),
                  Text(
                    pos == 0
                        ? isPdf ? 'PDF' : 'EPUB'
                        : pos >= total - 1
                            ? AppLocalizations.of(context)!.home_finished
                            : '${(progress * 100).round()}%',
                    style: TextStyle(fontSize: 10, color: TT.accent(context), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEbookTile(Ebook ebook) {
    final l10n = AppLocalizations.of(context)!;
    final isSelected = _selectedIds.contains(ebook.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isSelected
          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
          : null,
      child: ListTile(
        leading: _isSelectionMode
            ? Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelection(ebook.id),
              )
            : Icon(
                ebook.fileFormat == 'pdf'
                    ? Icons.picture_as_pdf
                    : Icons.import_contacts,
                color: TT.accent(context),
              ),
        title: Text(ebook.title),
        subtitle: _buildProgressSubtitle(ebook),
        trailing: _isSelectionMode
            ? null
            : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (action) {
                  if (action == 'open') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReaderScreen(ebook: ebook),
                      ),
                    ).then((_) => setState(() {}));
                  }
                  if (action == 'rename') _renameEbook(ebook);
                  if (action == 'select') _enterSelectionMode(ebook.id);
                  if (action == 'move') _moveEbookToFolder(ebook);
                  if (action == 'delete') _deleteEbook(ebook);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'open',
                    child: ListTile(
                      leading: const Icon(Icons.play_arrow_outlined),
                      title: Text(l10n.home_open),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'rename',
                    child: ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(l10n.home_rename),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'select',
                    child: ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(l10n.home_select),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'move',
                    child: ListTile(
                      leading: const Icon(Icons.drive_file_move_outline),
                      title: Text(l10n.home_moveToFolderMenu),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: const Icon(Icons.delete_outline, color: Colors.red),
                      title: Text(
                        l10n.common_delete,
                        style: const TextStyle(color: Colors.red),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
        onTap: _isSelectionMode
            ? () => _toggleSelection(ebook.id)
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReaderScreen(ebook: ebook),
                  ),
                ).then((_) => setState(() {})),
        onLongPress: _isSelectionMode
            ? null
            : () => _enterSelectionMode(ebook.id),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return TomyEmptyState(title: l10n.home_noBooks, message: l10n.home_addPrompt);
  }

  @override
  void dispose() {
    // Ne pas fermer la box ici — elle est partagée avec MainScreen et RecentScreen
    super.dispose();
  }
}

// ─── Couverture générée ────────────────────────────────────────────────────────

class BookCover extends StatelessWidget {
  final String title;
  final bool isPdf;
  final String? coverImagePath;

  const BookCover({required this.title, required this.isPdf, this.coverImagePath});

  // Couleur dérivée du titre pour varier les couvertures
  Color _baseColor() {
    final colors = [
      // Palette "Mystic night"
      const Color(0xFF4A2896), // violet grimoire
      const Color(0xFF2B1D6E), // indigo nuit
      const Color(0xFF8E1530), // rouge signet
      const Color(0xFF1F4E6B), // bleu crépuscule
      const Color(0xFF5B2A7A), // prune
      const Color(0xFF1E5A55), // vert sortilège
      const Color(0xFF6B3A1E), // cuir ancien
      const Color(0xFF3A2C8C), // améthyste
    ];
    final index = title.codeUnits.fold(0, (a, b) => a + b) % colors.length;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    // Image réelle disponible → l'afficher directement
    if (coverImagePath != null) {
      final file = File(coverImagePath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }

    // Couverture générée (fallback)
    final color = _baseColor();
    final initials = title
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.45)!],
        ),
      ),
      child: Stack(
        children: [
          // Liseré doré façon reliure
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: TT.gold.withOpacity(0.45), width: 1),
              ),
            ),
          ),
          // Grandes initiales en filigrane
          Positioned(
            bottom: -8,
            right: -4,
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                color: Colors.white.withOpacity(0.15),
                height: 1,
              ),
            ),
          ),
          // Badge type de fichier
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isPdf ? 'PDF' : 'EPUB',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          // Icône centrale
          Center(
            child: Icon(
              isPdf ? Icons.picture_as_pdf_rounded : Icons.auto_stories_rounded,
              color: TT.goldLight.withOpacity(0.75),
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Menu contextuel compact pour la grille ───────────────────────────────────

class _EbookCardMenu extends StatelessWidget {
  final Ebook ebook;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onSelect;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  const _EbookCardMenu({
    required this.ebook,
    required this.onOpen,
    required this.onRename,
    required this.onSelect,
    required this.onMove,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.more_vert, color: Colors.white, size: 16),
      ),
      onSelected: (action) {
        switch (action) {
          case 'open': onOpen();
          case 'rename': onRename();
          case 'select': onSelect();
          case 'move': onMove();
          case 'delete': onDelete();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'open',
          child: ListTile(
            leading: const Icon(Icons.play_arrow_outlined),
            title: Text(l10n.home_open),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'rename',
          child: ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.home_rename),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'select',
          child: ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(l10n.home_select),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'move',
          child: ListTile(
            leading: const Icon(Icons.drive_file_move_outline),
            title: Text(l10n.home_move),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: Text(l10n.common_delete, style: const TextStyle(color: Colors.red)),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
    );
  }
}
