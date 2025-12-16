import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../models/note.dart';
import '../widgets/note_card.dart';
import 'note_editor_screen.dart';

/// Screen displaying all notes across all folders
class AllNotesScreen extends ConsumerWidget {
  const AllNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(allNotesProvider);

    return notesAsync.when(
      data: (notes) {
        if (notes.isEmpty) {
          return _buildEmptyState(context);
        }
        return _buildNotesList(context, ref, notes);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_outlined,
            size: 120,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'No notes yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first note in a folder',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList(BuildContext context, WidgetRef ref, List<Note> notes) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return _buildNotesGrid(context, ref, notes);
        } else {
          return _buildNotesListView(context, ref, notes);
        }
      },
    );
  }

  Widget _buildNotesGrid(BuildContext context, WidgetRef ref, List<Note> notes) {
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
          onTap: () => _editNote(context, ref, notes[index]),
          onDelete: () => _deleteNote(context, ref, notes[index]),
          onTogglePin: () => _togglePin(ref, notes[index]),
          onToggleFavorite: () => _toggleFavorite(context, ref, notes[index]),
          onArchive: () => _archiveNote(context, ref, notes[index]),
        );
      },
    );
  }

  Widget _buildNotesListView(BuildContext context, WidgetRef ref, List<Note> notes) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        return NoteCard(
          note: notes[index],
          onTap: () => _editNote(context, ref, notes[index]),
          onDelete: () => _deleteNote(context, ref, notes[index]),
          onTogglePin: () => _togglePin(ref, notes[index]),
          onToggleFavorite: () => _toggleFavorite(context, ref, notes[index]),
          onArchive: () => _archiveNote(context, ref, notes[index]),
        );
      },
    );
  }

  void _editNote(BuildContext context, WidgetRef ref, Note note) {
    // Set current folder to the note's folder
    ref.read(currentFolderIdProvider.notifier).state = note.folderId;
    
    final folders = ref.read(foldersProvider);
    final folder = folders.firstWhere(
      (f) => f.id == note.folderId,
      orElse: () => folders.first,
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorScreen(
          note: note,
          folderId: note.folderId,
          folderColor: folder.color,
        ),
      ),
    );
  }

  void _deleteNote(BuildContext context, WidgetRef ref, Note note) {
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
              ref.read(currentFolderIdProvider.notifier).state = note.folderId;
              await ref.read(notesProvider.notifier).moveToTrash(note.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Note moved to trash')),
                );
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

  Future<void> _togglePin(WidgetRef ref, Note note) async {
    ref.read(currentFolderIdProvider.notifier).state = note.folderId;
    await ref.read(notesProvider.notifier).togglePin(note);
  }

  Future<void> _toggleFavorite(BuildContext context, WidgetRef ref, Note note) async {
    ref.read(currentFolderIdProvider.notifier).state = note.folderId;
    await ref.read(notesProvider.notifier).toggleFavorite(note);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(note.isFavorite ? 'Removed from favorites' : 'Added to favorites'),
        ),
      );
    }
  }

  Future<void> _archiveNote(BuildContext context, WidgetRef ref, Note note) async {
    ref.read(currentFolderIdProvider.notifier).state = note.folderId;
    await ref.read(notesProvider.notifier).archiveNote(note.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note archived')),
      );
    }
  }
}
