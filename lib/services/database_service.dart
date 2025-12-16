import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart';
import '../models/note.dart';
import '../models/folder.dart';
import '../models/label.dart';

/// Centralized database service managing all Hive operations
/// Handles initialization, CRUD operations for notes, folders, and labels
class DatabaseService {
  static const String _notesBoxName = 'notes';
  static const String _foldersBoxName = 'folders';
  static const String _labelsBoxName = 'labels';
  static const String _defaultFolderId = 'default_folder';

  static Box<Note>? _notesBox;
  static Box<Folder>? _foldersBox;
  static Box<Label>? _labelsBox;

  /// Initialize Hive database and register adapters
  /// Must be called before any database operations
  static Future<void> initialize() async {
    await Hive.initFlutter();
    
    // Register type adapters if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(NoteAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(FolderAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(LabelAdapter());
    }

    // Open boxes
    _notesBox = await Hive.openBox<Note>(_notesBoxName);
    _foldersBox = await Hive.openBox<Folder>(_foldersBoxName);
    _labelsBox = await Hive.openBox<Label>(_labelsBoxName);

    // Create default folder if it doesn't exist
    await _ensureDefaultFolder();
    
    // Create default labels if they don't exist
    await _ensureDefaultLabels();
  }

  /// Ensure default folder exists for notes without a specific folder
  static Future<void> _ensureDefaultFolder() async {
    if (_foldersBox == null) return;
    
    if (_foldersBox!.get(_defaultFolderId) == null) {
      final defaultFolder = Folder(
        id: _defaultFolderId,
        name: 'General',
        colorValue: Colors.blue.value,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _foldersBox!.put(_defaultFolderId, defaultFolder);
    }
  }

  /// Ensure default labels exist
  static Future<void> _ensureDefaultLabels() async {
    if (_labelsBox == null) return;
    
    // Create Work label if it doesn't exist
    if (_labelsBox!.get('work_label') == null) {
      final workLabel = Label(
        id: 'work_label',
        name: 'Work',
        colorValue: Colors.blue.value,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _labelsBox!.put('work_label', workLabel);
    }
    
    // Create Personal label if it doesn't exist
    if (_labelsBox!.get('personal_label') == null) {
      final personalLabel = Label(
        id: 'personal_label',
        name: 'Personal',
        colorValue: Colors.green.value,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _labelsBox!.put('personal_label', personalLabel);
    }
  }

  // ==================== FOLDER OPERATIONS ====================

  /// Get all folders sorted by creation date
  static List<Folder> getAllFolders() {
    if (_foldersBox == null) return [];
    final folders = _foldersBox!.values.toList();
    folders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return folders;
  }

  /// Get folder by ID
  static Folder? getFolderById(String id) {
    return _foldersBox?.get(id);
  }

  /// Create a new folder
  static Future<Folder> createFolder({
    required String name,
    required Color color,
    String? encryptedPin,
  }) async {
    if (_foldersBox == null) {
      throw Exception('Database not initialized');
    }

    final now = DateTime.now();
    final folder = Folder(
      id: now.millisecondsSinceEpoch.toString(),
      name: name,
      colorValue: color.value,
      isLocked: encryptedPin != null,
      encryptedPin: encryptedPin,
      createdAt: now,
      updatedAt: now,
    );

    await _foldersBox!.put(folder.id, folder);
    return folder;
  }

  /// Update an existing folder
  static Future<void> updateFolder(Folder folder) async {
    if (_foldersBox == null) {
      throw Exception('Database not initialized');
    }

    final updatedFolder = folder.copyWith(updatedAt: DateTime.now());
    await _foldersBox!.put(updatedFolder.id, updatedFolder);
  }

  /// Delete a folder and all its notes
  static Future<void> deleteFolder(String folderId) async {
    if (_foldersBox == null || _notesBox == null) {
      throw Exception('Database not initialized');
    }

    // Don't allow deletion of default folder
    if (folderId == _defaultFolderId) {
      throw Exception('Cannot delete default folder');
    }

    // Delete all notes in this folder
    final notesToDelete = _notesBox!.values
        .where((note) => note.folderId == folderId)
        .map((note) => note.id)
        .toList();

    for (final noteId in notesToDelete) {
      await _notesBox!.delete(noteId);
    }

    // Delete the folder
    await _foldersBox!.delete(folderId);
  }

  // ==================== NOTE OPERATIONS ====================

  /// Get all notes
  static List<Note> getAllNotes() {
    if (_notesBox == null) return [];
    return _notesBox!.values.toList();
  }

  /// Get all notes in a specific folder, sorted by pinned status and update time
  static List<Note> getNotesByFolder(String folderId) {
    if (_notesBox == null) return [];
    
    final notes = _notesBox!.values
        .where((note) => note.folderId == folderId)
        .toList();
    
    // Sort: pinned first, then by most recent update
    notes.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    
    return notes;
  }

  /// Get note by ID
  static Note? getNoteById(String id) {
    return _notesBox?.get(id);
  }

  /// Create a new note
  static Future<Note> createNote({
    required String title,
    required String content,
    required String folderId,
    bool isPinned = false,
  }) async {
    if (_notesBox == null) {
      throw Exception('Database not initialized');
    }

    final now = DateTime.now();
    final note = Note(
      id: now.millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      folderId: folderId,
      isPinned: isPinned,
      createdAt: now,
      updatedAt: now,
    );

    await _notesBox!.put(note.id, note);
    return note;
  }

  /// Update an existing note
  static Future<void> updateNote(Note note) async {
    if (_notesBox == null) {
      throw Exception('Database not initialized');
    }

    final updatedNote = note.copyWith(updatedAt: DateTime.now());
    await _notesBox!.put(updatedNote.id, updatedNote);
  }

  /// Delete a note
  static Future<void> deleteNote(String noteId) async {
    if (_notesBox == null) {
      throw Exception('Database not initialized');
    }

    await _notesBox!.delete(noteId);
  }

  /// Search notes by query string (searches title and content)
  static List<Note> searchNotes(String query, {String? folderId}) {
    if (_notesBox == null || query.isEmpty) {
      return folderId != null ? getNotesByFolder(folderId) : [];
    }

    final lowerQuery = query.toLowerCase();
    final notes = folderId != null
        ? getNotesByFolder(folderId)
        : getAllNotes();

    return notes.where((note) {
      return note.title.toLowerCase().contains(lowerQuery) ||
             note.content.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Close all boxes (call when app is disposed)
  static Future<void> close() async {
    await _notesBox?.close();
    await _foldersBox?.close();
    await _labelsBox?.close();
  }

  /// Get default folder ID
  static String get defaultFolderId => _defaultFolderId;

  // ==================== LABEL OPERATIONS ====================

  /// Get all labels sorted by creation date
  static List<Label> getAllLabels() {
    if (_labelsBox == null) return [];
    final labels = _labelsBox!.values.toList();
    labels.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return labels;
  }

  /// Get label by ID
  static Label? getLabelById(String id) {
    return _labelsBox?.get(id);
  }

  /// Create a new label
  static Future<Label> createLabel({
    required String name,
    required int colorValue,
  }) async {
    if (_labelsBox == null) {
      throw Exception('Database not initialized');
    }

    final now = DateTime.now();
    final label = Label(
      id: now.millisecondsSinceEpoch.toString(),
      name: name,
      colorValue: colorValue,
      createdAt: now,
      updatedAt: now,
    );

    await _labelsBox!.put(label.id, label);
    return label;
  }

  /// Update an existing label
  static Future<void> updateLabel(Label label) async {
    if (_labelsBox == null) {
      throw Exception('Database not initialized');
    }

    final updatedLabel = label.copyWith(updatedAt: DateTime.now());
    await _labelsBox!.put(updatedLabel.id, updatedLabel);
  }

  /// Delete a label
  static Future<void> deleteLabel(String labelId) async {
    if (_labelsBox == null) {
      throw Exception('Database not initialized');
    }

    // Remove label from all notes that have it
    final notes = getAllNotes();
    for (final note in notes) {
      if (note.labelIds.contains(labelId)) {
        final updatedLabelIds = List<String>.from(note.labelIds)..remove(labelId);
        final updatedNote = note.copyWith(labelIds: updatedLabelIds);
        await updateNote(updatedNote);
      }
    }

    await _labelsBox!.delete(labelId);
  }

  /// Get notes by label
  static List<Note> getNotesByLabel(String labelId) {
    if (_notesBox == null) return [];
    return _notesBox!.values
        .where((note) => note.labelIds.contains(labelId) && !note.isArchived && !note.isTrashed)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Add label to note
  static Future<void> addLabelToNote(String noteId, String labelId) async {
    final note = getNoteById(noteId);
    if (note == null) return;

    if (!note.labelIds.contains(labelId)) {
      final updatedLabelIds = List<String>.from(note.labelIds)..add(labelId);
      final updatedNote = note.copyWith(labelIds: updatedLabelIds);
      await updateNote(updatedNote);
    }
  }

  /// Remove label from note
  static Future<void> removeLabelFromNote(String noteId, String labelId) async {
    final note = getNoteById(noteId);
    if (note == null) return;

    if (note.labelIds.contains(labelId)) {
      final updatedLabelIds = List<String>.from(note.labelIds)..remove(labelId);
      final updatedNote = note.copyWith(labelIds: updatedLabelIds);
      await updateNote(updatedNote);
    }
  }

  // ==================== FAVORITES OPERATIONS ====================

  /// Get all favorite notes
  static List<Note> getFavoriteNotes() {
    if (_notesBox == null) return [];
    return _notesBox!.values
        .where((note) => note.isFavorite && !note.isArchived && !note.isTrashed)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Toggle favorite status of a note
  static Future<void> toggleFavorite(String noteId) async {
    final note = getNoteById(noteId);
    if (note == null) return;

    final updatedNote = note.copyWith(isFavorite: !note.isFavorite);
    await updateNote(updatedNote);
  }

  // ==================== ARCHIVE OPERATIONS ====================

  /// Get all archived notes
  static List<Note> getArchivedNotes() {
    if (_notesBox == null) return [];
    return _notesBox!.values
        .where((note) => note.isArchived && !note.isTrashed)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Archive a note
  static Future<void> archiveNote(String noteId) async {
    final note = getNoteById(noteId);
    if (note == null) return;

    final updatedNote = note.copyWith(isArchived: true);
    await updateNote(updatedNote);
  }

  /// Unarchive a note
  static Future<void> unarchiveNote(String noteId) async {
    final note = getNoteById(noteId);
    if (note == null) return;

    final updatedNote = note.copyWith(isArchived: false);
    await updateNote(updatedNote);
  }

  // ==================== TRASH OPERATIONS ====================

  /// Get all trashed notes
  static List<Note> getTrashedNotes() {
    if (_notesBox == null) return [];
    return _notesBox!.values
        .where((note) => note.isTrashed)
        .toList()
      ..sort((a, b) => (b.trashedAt ?? b.updatedAt).compareTo(a.trashedAt ?? a.updatedAt));
  }

  /// Move note to trash
  static Future<void> moveToTrash(String noteId) async {
    final note = getNoteById(noteId);
    if (note == null) return;

    final updatedNote = note.copyWith(
      isTrashed: true,
      trashedAt: DateTime.now(),
    );
    await updateNote(updatedNote);
  }

  /// Restore note from trash
  static Future<void> restoreFromTrash(String noteId) async {
    final note = getNoteById(noteId);
    if (note == null) return;

    final updatedNote = note.copyWith(
      isTrashed: false,
      trashedAt: DateTime.now(), // Reset to null by passing current time
    );
    await updateNote(updatedNote);
  }

  /// Permanently delete a note from trash
  static Future<void> permanentlyDeleteNote(String noteId) async {
    await deleteNote(noteId);
  }

  /// Empty trash (delete all trashed notes)
  static Future<void> emptyTrash() async {
    final trashedNotes = getTrashedNotes();
    for (final note in trashedNotes) {
      await deleteNote(note.id);
    }
  }

  /// Auto-delete notes in trash older than 30 days
  static Future<void> autoDeleteOldTrash() async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final trashedNotes = getTrashedNotes();

    for (final note in trashedNotes) {
      if (note.trashedAt != null && note.trashedAt!.isBefore(thirtyDaysAgo)) {
        await deleteNote(note.id);
      }
    }
  }

  // ==================== REMINDER OPERATIONS ====================

  /// Get notes with upcoming reminders
  static List<Note> getUpcomingReminders() {
    if (_notesBox == null) return [];
    final now = DateTime.now();
    
    return _notesBox!.values
        .where((note) => 
            note.reminderDate != null &&
            !note.isTrashed &&
            note.reminderDate!.isAfter(now))
        .toList()
      ..sort((a, b) => a.reminderDate!.compareTo(b.reminderDate!));
  }

  /// Get all notes with reminders set
  static List<Note> getNotesWithReminders() {
    if (_notesBox == null) return [];
    
    return _notesBox!.values
        .where((note) => note.reminderDate != null && !note.isTrashed)
        .toList()
      ..sort((a, b) => a.reminderDate!.compareTo(b.reminderDate!));
  }

  /// Set reminder for a note
  static Future<void> setReminder(String noteId, DateTime reminderDate) async {
    final note = getNoteById(noteId);
    if (note == null) return;

    final updatedNote = note.copyWith(reminderDate: reminderDate);
    await updateNote(updatedNote);
  }

  /// Remove reminder from a note
  static Future<void> removeReminder(String noteId) async {
    final note = getNoteById(noteId);
    if (note == null) return;

    final updatedNote = note.copyWith(reminderDate: DateTime.now()); // Will be set to null
    await updateNote(updatedNote);
  }

  // ==================== FOLDER ORDERING ====================

  /// Get folders sorted by order index
  static List<Folder> getFoldersByOrder() {
    if (_foldersBox == null) return [];
    final folders = _foldersBox!.values.toList();
    folders.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return folders;
  }

  /// Update folder order
  static Future<void> updateFolderOrder(List<String> folderIds) async {
    if (_foldersBox == null) return;

    for (int i = 0; i < folderIds.length; i++) {
      final folder = _foldersBox!.get(folderIds[i]);
      if (folder != null) {
        final updatedFolder = folder.copyWith(orderIndex: i);
        await _foldersBox!.put(folder.id, updatedFolder);
      }
    }
  }
}
