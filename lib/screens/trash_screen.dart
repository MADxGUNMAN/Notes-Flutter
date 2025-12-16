import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/app_providers.dart';
import '../models/note.dart';
import '../models/folder.dart';

/// Screen displaying trashed items with Notes/Folders tabs and selection mode
class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedNoteIds = {};
  final Set<String> _selectedFolderIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _isSelectionMode = false;
          _selectedNoteIds.clear();
          _selectedFolderIds.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id, bool isFolder) {
    setState(() {
      if (isFolder) {
        if (_selectedFolderIds.contains(id)) {
          _selectedFolderIds.remove(id);
        } else {
          _selectedFolderIds.add(id);
        }
        _isSelectionMode = _selectedFolderIds.isNotEmpty;
      } else {
        if (_selectedNoteIds.contains(id)) {
          _selectedNoteIds.remove(id);
        } else {
          _selectedNoteIds.add(id);
        }
        _isSelectionMode = _selectedNoteIds.isNotEmpty;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedNoteIds.clear();
      _selectedFolderIds.clear();
    });
  }

  Future<void> _recoverSelected() async {
    final isNotesTab = _tabController.index == 0;
    
    if (isNotesTab) {
      for (final noteId in _selectedNoteIds) {
        await ref.read(trashNotesProvider.notifier).restoreNote(noteId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedNoteIds.length} note(s) restored')),
        );
      }
    } else {
      for (final folderId in _selectedFolderIds) {
        await ref.read(foldersProvider.notifier).restoreFolder(folderId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedFolderIds.length} folder(s) restored')),
        );
      }
    }
    _clearSelection();
  }

  Future<void> _deleteSelectedPermanently() async {
    final isNotesTab = _tabController.index == 0;
    final count = isNotesTab ? _selectedNoteIds.length : _selectedFolderIds.length;
    final itemType = isNotesTab ? 'note' : 'folder';
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Forever'),
        content: Text(
          'Are you sure you want to permanently delete $count $itemType(s)? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (isNotesTab) {
      for (final noteId in _selectedNoteIds) {
        await ref.read(trashNotesProvider.notifier).deletePermanently(noteId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count note(s) permanently deleted')),
        );
      }
    } else {
      for (final folderId in _selectedFolderIds) {
        await ref.read(foldersProvider.notifier).deleteFolder(folderId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count folder(s) permanently deleted')),
        );
      }
    }
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_tabController.index == 0 ? _selectedNoteIds.length : _selectedFolderIds.length} selected')
            : const Text('Trash'),
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              )
            : null,
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.restore),
                  onPressed: _recoverSelected,
                  tooltip: 'Recover',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  onPressed: _deleteSelectedPermanently,
                  tooltip: 'Delete forever',
                ),
              ]
            : null,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Notes', icon: Icon(Icons.note)),
            Tab(text: 'Folders', icon: Icon(Icons.folder)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Items in trash are automatically deleted after 30 days',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNotesTab(),
                _buildFoldersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesTab() {
    final trashedNotesAsync = ref.watch(trashNotesProvider);
    
    return trashedNotesAsync.when(
      data: (notes) {
        if (notes.isEmpty) {
          return _buildEmptyState(context, 'No trashed notes', Icons.note_outlined);
        }
        return _buildNotesList(notes);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _buildFoldersTab() {
    final trashedFoldersAsync = ref.watch(trashedFoldersProvider);
    
    return trashedFoldersAsync.when(
      data: (folders) {
        if (folders.isEmpty) {
          return _buildEmptyState(context, 'No trashed folders', Icons.folder_outlined);
        }
        return _buildFoldersList(folders);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 100,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList(List<Note> notes) {
    final dateFormat = DateFormat('MMM d, y');
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final isSelected = _selectedNoteIds.contains(note.id);
        final daysRemaining = note.trashedAt != null
            ? 30 - DateTime.now().difference(note.trashedAt!).inDays
            : 30;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: _isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(note.id, false),
                  )
                : null,
            title: Text(
              note.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.content.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: daysRemaining <= 7 ? Colors.red : null,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Deleted ${note.trashedAt != null ? dateFormat.format(note.trashedAt!) : "Unknown"} • $daysRemaining days left',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: daysRemaining <= 7 ? Colors.red : null,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            onTap: () => _toggleSelection(note.id, false),
            onLongPress: () {
              if (!_isSelectionMode) {
                _toggleSelection(note.id, false);
              }
            },
            trailing: !_isSelectionMode
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore),
                        onPressed: () async {
                          await ref.read(trashNotesProvider.notifier).restoreNote(note.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Note restored')),
                            );
                          }
                        },
                        tooltip: 'Restore',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        onPressed: () => _showDeleteNoteDialog(note),
                        tooltip: 'Delete forever',
                      ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildFoldersList(List<Folder> folders) {
    final dateFormat = DateFormat('MMM d, y');
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        final isSelected = _selectedFolderIds.contains(folder.id);
        final daysRemaining = folder.trashedAt != null
            ? 30 - DateTime.now().difference(folder.trashedAt!).inDays
            : 30;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: _isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(folder.id, true),
                  )
                : Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: folder.color.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.folder, color: folder.color),
                  ),
            title: Text(
              folder.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            subtitle: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: daysRemaining <= 7 ? Colors.red : null,
                ),
                const SizedBox(width: 4),
                Text(
                  'Deleted ${folder.trashedAt != null ? dateFormat.format(folder.trashedAt!) : "Unknown"} • $daysRemaining days left',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: daysRemaining <= 7 ? Colors.red : null,
                      ),
                ),
              ],
            ),
            onTap: () => _toggleSelection(folder.id, true),
            onLongPress: () {
              if (!_isSelectionMode) {
                _toggleSelection(folder.id, true);
              }
            },
            trailing: !_isSelectionMode
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore),
                        onPressed: () async {
                          await ref.read(foldersProvider.notifier).restoreFolder(folder.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Folder restored')),
                            );
                          }
                        },
                        tooltip: 'Restore',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        onPressed: () => _showDeleteFolderDialog(folder),
                        tooltip: 'Delete forever',
                      ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }

  void _showDeleteNoteDialog(Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Forever'),
        content: Text(
          'Are you sure you want to permanently delete "${note.title}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(trashNotesProvider.notifier).deletePermanently(note.id);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Note permanently deleted')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }

  void _showDeleteFolderDialog(Folder folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Forever'),
        content: Text(
          'Are you sure you want to permanently delete "${folder.name}" and all its notes? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(foldersProvider.notifier).deleteFolder(folder.id);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Folder permanently deleted')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }
}
