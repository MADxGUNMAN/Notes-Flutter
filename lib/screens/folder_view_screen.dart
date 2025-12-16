import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/folder.dart';
import '../models/note.dart';
import '../providers/app_providers.dart';
import '../widgets/note_card.dart';
import 'note_editor_screen.dart';

/// Screen displaying all notes within a folder with search functionality
class FolderViewScreen extends ConsumerStatefulWidget {
  final Folder folder;

  const FolderViewScreen({super.key, required this.folder});

  @override
  ConsumerState<FolderViewScreen> createState() => _FolderViewScreenState();
}

class _FolderViewScreenState extends ConsumerState<FolderViewScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // Set current folder
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentFolderIdProvider.notifier).state = widget.folder.id;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    
    // Use search results if searching, otherwise use regular notes
    final displayNotes = _isSearching && searchQuery.isNotEmpty
        ? ref.watch(searchResultsProvider)
        : notes;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching ? _buildSearchField() : Text(widget.folder.name),
        backgroundColor: widget.folder.color,
        foregroundColor: _getContrastColor(widget.folder.color),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(searchQueryProvider.notifier).state = '';
                }
              });
            },
            tooltip: _isSearching ? 'Close search' : 'Search notes',
          ),
        ],
      ),
      body: displayNotes.isEmpty
          ? _buildEmptyState(context)
          : _buildNotesList(context, displayNotes),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewNote(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search notes...',
        border: InputBorder.none,
        hintStyle: TextStyle(
          color: _getContrastColor(widget.folder.color).withOpacity(0.7),
        ),
      ),
      style: TextStyle(color: _getContrastColor(widget.folder.color)),
      onChanged: (value) {
        ref.read(searchQueryProvider.notifier).state = value;
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isSearching = _isSearching && _searchController.text.isNotEmpty;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.note_outlined,
            size: 120,
            color: widget.folder.color.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            isSearching ? 'No notes found' : 'No notes yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            isSearching
                ? 'Try a different search term'
                : 'Tap + to create your first note',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList(BuildContext context, List<Note> notes) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive layout: list for narrow screens, grid for wide screens
        if (constraints.maxWidth > 600) {
          return _buildNotesGrid(notes);
        } else {
          return _buildNotesListView(notes);
        }
      },
    );
  }

  Widget _buildNotesGrid(List<Note> notes) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        return NoteCard(
          note: notes[index],
          onTap: () => _editNote(context, notes[index]),
          onDelete: () => _deleteNote(context, notes[index]),
          onTogglePin: () => _togglePin(notes[index]),
          onToggleFavorite: () => _toggleFavorite(notes[index]),
          onArchive: () => _archiveNote(notes[index]),
        );
      },
    );
  }

  Widget _buildNotesListView(List<Note> notes) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        return NoteCard(
          note: notes[index],
          onTap: () => _editNote(context, notes[index]),
          onDelete: () => _deleteNote(context, notes[index]),
          onTogglePin: () => _togglePin(notes[index]),
          onToggleFavorite: () => _toggleFavorite(notes[index]),
          onArchive: () => _archiveNote(notes[index]),
        );
      },
    );
  }

  void _createNewNote(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorScreen(
          folderId: widget.folder.id,
          folderColor: widget.folder.color,
        ),
      ),
    );
  }

  void _editNote(BuildContext context, Note note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorScreen(
          note: note,
          folderId: widget.folder.id,
          folderColor: widget.folder.color,
        ),
      ),
    );
  }

  void _deleteNote(BuildContext context, Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(notesProvider.notifier).moveToTrash(note.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Note moved to trash')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePin(Note note) async {
    try {
      await ref.read(notesProvider.notifier).togglePin(note);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _toggleFavorite(Note note) async {
    try {
      await ref.read(notesProvider.notifier).toggleFavorite(note);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(note.isFavorite ? 'Removed from favorites' : 'Added to favorites'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _archiveNote(Note note) async {
    try {
      await ref.read(notesProvider.notifier).archiveNote(note.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note archived')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Calculate contrasting color for text on colored background
  Color _getContrastColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

