import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../models/folder.dart';
import '../services/database_service.dart';

// ==================== FOLDER PROVIDERS ====================

/// Provider for the list of all folders
/// Automatically updates when folders are modified
final foldersProvider = StateNotifierProvider<FoldersNotifier, List<Folder>>((ref) {
  return FoldersNotifier();
});

class FoldersNotifier extends StateNotifier<List<Folder>> {
  FoldersNotifier() : super([]) {
    loadFolders();
  }

  /// Load all folders from database
  void loadFolders() {
    state = DatabaseService.getAllFolders();
  }

  /// Create a new folder
  Future<Folder> createFolder({
    required String name,
    required int colorValue,
    String? encryptedPin,
  }) async {
    final folder = await DatabaseService.createFolder(
      name: name,
      color: Color(colorValue),
      encryptedPin: encryptedPin,
    );
    loadFolders();
    return folder;
  }

  /// Update an existing folder
  Future<void> updateFolder(Folder folder) async {
    await DatabaseService.updateFolder(folder);
    loadFolders();
  }

  /// Delete a folder
  Future<void> deleteFolder(String folderId) async {
    await DatabaseService.deleteFolder(folderId);
    loadFolders();
  }
}

// ==================== CURRENT FOLDER PROVIDER ====================

/// Provider for the currently selected folder ID
final currentFolderIdProvider = StateProvider<String?>((ref) => null);

/// Provider for the currently selected folder object
final currentFolderProvider = Provider<Folder?>((ref) {
  final folderId = ref.watch(currentFolderIdProvider);
  if (folderId == null) return null;
  
  final folders = ref.watch(foldersProvider);
  return folders.firstWhere(
    (folder) => folder.id == folderId,
    orElse: () => folders.first,
  );
});

// ==================== NOTE PROVIDERS ====================

/// Provider for notes in the current folder
final notesProvider = StateNotifierProvider<NotesNotifier, List<Note>>((ref) {
  final folderId = ref.watch(currentFolderIdProvider);
  return NotesNotifier(folderId);
});

class NotesNotifier extends StateNotifier<List<Note>> {
  final String? folderId;

  NotesNotifier(this.folderId) : super([]) {
    loadNotes();
  }

  /// Load notes for the current folder
  void loadNotes() {
    final id = folderId;
    if (id == null || id.isEmpty) {
      state = [];
      return;
    }
    state = DatabaseService.getNotesByFolder(id);
  }

  /// Create a new note
  Future<Note> createNote({
    required String title,
    required String content,
    bool isPinned = false,
  }) async {
    final id = folderId;
    if (id == null || id.isEmpty) {
      throw Exception('No folder selected');
    }

    final note = await DatabaseService.createNote(
      title: title,
      content: content,
      folderId: id,
      isPinned: isPinned,
    );
    loadNotes();
    return note;
  }

  /// Update an existing note
  Future<void> updateNote(Note note) async {
    await DatabaseService.updateNote(note);
    loadNotes();
  }

  /// Delete a note
  Future<void> deleteNote(String noteId) async {
    await DatabaseService.deleteNote(noteId);
    loadNotes();
  }

  /// Toggle pin status of a note
  Future<void> togglePin(Note note) async {
    final updatedNote = note.copyWith(isPinned: !note.isPinned);
    await updateNote(updatedNote);
  }
}

// ==================== SEARCH PROVIDERS ====================

/// Provider for search query with debouncing
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for debounced search results
/// Implements 300ms debounce to prevent excessive searches
final searchResultsProvider = StreamProvider<List<Note>>((ref) {
  final query = ref.watch(searchQueryProvider);
  final folderId = ref.watch(currentFolderIdProvider);

  // Create a stream controller for debounced search
  final controller = StreamController<List<Note>>();

  // Debounce search by 300ms
  final debounceTimer = Timer(const Duration(milliseconds: 300), () {
    if (query.isEmpty) {
      // Return notes in current folder when no search query
      if (folderId != null && folderId.isNotEmpty) {
        controller.add(DatabaseService.getNotesByFolder(folderId));
      } else {
        controller.add([]);
      }
    } else {
      // Search notes
      controller.add(DatabaseService.searchNotes(query, folderId: folderId));
    }
  });

  ref.onDispose(() {
    debounceTimer.cancel();
    controller.close();
  });

  return controller.stream;
});

// ==================== LOCKED FOLDERS PROVIDER ====================

/// Provider to track which folders have been unlocked in current session
/// Map of folder ID to unlock status
final unlockedFoldersProvider = StateProvider<Map<String, bool>>((ref) => {});

/// Check if a folder is unlocked in current session
final isFolderUnlockedProvider = Provider.family<bool, String>((ref, folderId) {
  final unlockedFolders = ref.watch(unlockedFoldersProvider);
  return unlockedFolders[folderId] ?? false;
});

// ==================== FAVORITES PROVIDER ====================

/// Provider for favorite notes
final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<Note>>((ref) {
  return FavoritesNotifier();
});

class FavoritesNotifier extends StateNotifier<List<Note>> {
  FavoritesNotifier() : super([]) {
    loadFavorites();
  }

  void loadFavorites() {
    state = DatabaseService.getFavoriteNotes();
  }

  Future<void> toggleFavorite(String noteId) async {
    await DatabaseService.toggleFavorite(noteId);
    loadFavorites();
  }
}

// ==================== ARCHIVE PROVIDER ====================

/// Provider for archived notes
final archivedNotesProvider = StateNotifierProvider<ArchivedNotesNotifier, List<Note>>((ref) {
  return ArchivedNotesNotifier();
});

class ArchivedNotesNotifier extends StateNotifier<List<Note>> {
  ArchivedNotesNotifier() : super([]) {
    loadArchived();
  }

  void loadArchived() {
    state = DatabaseService.getArchivedNotes();
  }

  Future<void> archiveNote(String noteId) async {
    await DatabaseService.archiveNote(noteId);
    loadArchived();
  }

  Future<void> unarchiveNote(String noteId) async {
    await DatabaseService.unarchiveNote(noteId);
    loadArchived();
  }
}

// ==================== TRASH PROVIDER ====================

/// Provider for trashed notes
final trashedNotesProvider = StateNotifierProvider<TrashedNotesNotifier, List<Note>>((ref) {
  return TrashedNotesNotifier();
});

class TrashedNotesNotifier extends StateNotifier<List<Note>> {
  TrashedNotesNotifier() : super([]) {
    loadTrashed();
  }

  void loadTrashed() {
    state = DatabaseService.getTrashedNotes();
  }

  Future<void> moveToTrash(String noteId) async {
    await DatabaseService.moveToTrash(noteId);
    loadTrashed();
  }

  Future<void> restoreFromTrash(String noteId) async {
    await DatabaseService.restoreFromTrash(noteId);
    loadTrashed();
  }

  Future<void> permanentlyDelete(String noteId) async {
    await DatabaseService.permanentlyDeleteNote(noteId);
    loadTrashed();
  }

  Future<void> emptyTrash() async {
    await DatabaseService.emptyTrash();
    loadTrashed();
  }
}

// ==================== REMINDERS PROVIDER ====================

/// Provider for notes with reminders
final remindersProvider = StateNotifierProvider<RemindersNotifier, List<Note>>((ref) {
  return RemindersNotifier();
});

class RemindersNotifier extends StateNotifier<List<Note>> {
  RemindersNotifier() : super([]) {
    loadReminders();
  }

  void loadReminders() {
    state = DatabaseService.getUpcomingReminders();
  }

  Future<void> setReminder(String noteId, DateTime reminderDate) async {
    await DatabaseService.setReminder(noteId, reminderDate);
    loadReminders();
  }

  Future<void> removeReminder(String noteId) async {
    await DatabaseService.removeReminder(noteId);
    loadReminders();
  }
}
