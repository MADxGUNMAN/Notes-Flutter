import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../models/note.dart';
import '../widgets/note_card.dart';
import 'note_editor_screen.dart';

/// Screen displaying favorite notes
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoriteNotesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        elevation: 0,
      ),
      body: favoritesAsync.when(
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
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.star_outline,
            size: 100,
            color: Colors.amber.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'No favorites yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add notes to favorites to see them here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList(BuildContext context, WidgetRef ref, List<Note> notes) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return NoteCard(
          note: note,
          onTap: () => _editNote(context, ref, note),
          onDelete: () => _removeFromFavorites(context, ref, note),
          onTogglePin: () => _togglePin(ref, note),
          onToggleFavorite: () => _toggleFavorite(context, ref, note),
          onArchive: () => _archiveNote(context, ref, note),
        );
      },
    );
  }

  void _editNote(BuildContext context, WidgetRef ref, Note note) {
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

  Future<void> _removeFromFavorites(BuildContext context, WidgetRef ref, Note note) async {
    ref.read(currentFolderIdProvider.notifier).state = note.folderId;
    await ref.read(notesProvider.notifier).toggleFavorite(note);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from favorites')),
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
