import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../models/folder.dart';
import '../models/label.dart';
import '../services/firestore_service.dart';
import 'auth_providers.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

/// Provider for bottom navigation index
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

/// Provider for unlocked folders (stores folder IDs that have been unlocked)
final unlockedFoldersProvider = StateProvider<Map<String, bool>>((ref) => {});

/// Provider to check if a specific folder is unlocked
final isFolderUnlockedProvider = Provider.family<bool, String>((ref, folderId) {
  final unlockedFolders = ref.watch(unlockedFoldersProvider);
  return unlockedFolders[folderId] ?? false;
});

// ==================== FOLDER PROVIDERS ====================

final foldersProvider = StateNotifierProvider<FoldersNotifier, List<Folder>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final user = ref.watch(currentUserProvider);
  return FoldersNotifier(firestoreService, user?.uid);
});

class FoldersNotifier extends StateNotifier<List<Folder>> {
  final FirestoreService _firestoreService;
  final String? _userId;
  StreamSubscription<List<Folder>>? _subscription;

  FoldersNotifier(this._firestoreService, this._userId) : super([]) {
    if (_userId != null) {
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _firestoreService.getFoldersStream().listen((folders) {
      state = folders;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<Folder> createFolder({
    required String name,
    required int colorValue,
    String? encryptedPin,
  }) async {
    return await _firestoreService.createFolder(
      name: name,
      colorValue: colorValue,
      encryptedPin: encryptedPin,
    );
  }

  Future<void> updateFolder(Folder folder) async {
    await _firestoreService.updateFolder(folder);
  }

  Future<void> moveToTrash(String folderId) async {
    await _firestoreService.moveFolderToTrash(folderId);
  }

  Future<void> restoreFolder(String folderId) async {
    await _firestoreService.restoreFolder(folderId);
  }

  Future<void> deleteFolder(String folderId) async {
    await _firestoreService.deleteFolder(folderId);
  }
}

// ==================== TRASHED FOLDERS PROVIDER ====================

final trashedFoldersProvider = StreamProvider<List<Folder>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return firestoreService.getTrashedFoldersStream();
});

// ==================== CURRENT FOLDER PROVIDER ====================

final currentFolderIdProvider = StateProvider<String?>((ref) => null);

final currentFolderProvider = Provider<Folder?>((ref) {
  final folderId = ref.watch(currentFolderIdProvider);
  if (folderId == null) return null;
  
  final folders = ref.watch(foldersProvider);
  try {
    return folders.firstWhere((folder) => folder.id == folderId);
  } catch (_) {
    return null;
  }
});

// ==================== NOTE PROVIDERS ====================

final notesProvider = StateNotifierProvider<NotesNotifier, List<Note>>((ref) {
  final folderId = ref.watch(currentFolderIdProvider);
  final firestoreService = ref.watch(firestoreServiceProvider);
  final user = ref.watch(currentUserProvider);
  return NotesNotifier(firestoreService, folderId, user?.uid);
});

class NotesNotifier extends StateNotifier<List<Note>> {
  final FirestoreService _firestoreService;
  final String? folderId;
  final String? _userId;
  StreamSubscription<List<Note>>? _subscription;

  NotesNotifier(this._firestoreService, this.folderId, this._userId) : super([]) {
    if (_userId != null) {
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription?.cancel();
    if (folderId != null) {
      _subscription = _firestoreService.getNotesByFolderStream(folderId!).listen((notes) {
        state = notes;
      });
    } else {
      state = [];
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<Note> createNote({
    required String title,
    required String content,
    bool isPinned = false,
  }) async {
    if (folderId == null) {
      throw Exception('No folder selected');
    }

    return await _firestoreService.createNote(
      title: title,
      content: content,
      folderId: folderId!,
      isPinned: isPinned,
    );
  }

  Future<void> updateNote(Note note) async {
    await _firestoreService.updateNote(note);
  }

  Future<void> deleteNote(String noteId) async {
    await _firestoreService.deleteNote(noteId);
  }

  Future<void> togglePin(Note note) async {
    await _firestoreService.togglePin(note.id, !note.isPinned);
  }

  Future<void> toggleFavorite(Note note) async {
    await _firestoreService.toggleFavorite(note.id, !note.isFavorite);
  }

  Future<void> moveToTrash(String noteId) async {
    await _firestoreService.moveToTrash(noteId);
  }

  Future<void> archiveNote(String noteId) async {
    await _firestoreService.archiveNote(noteId);
  }

  Future<void> unarchiveNote(String noteId) async {
    await _firestoreService.unarchiveNote(noteId);
  }
}

// ==================== SEARCH PROVIDERS ====================

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = Provider<List<Note>>((ref) {
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final notes = ref.watch(notesProvider);

  if (query.isEmpty) {
    return notes;
  }

  return notes.where((note) {
    return note.title.toLowerCase().contains(query) ||
        note.content.toLowerCase().contains(query);
  }).toList();
});

final globalSearchQueryProvider = StateProvider<String>((ref) => '');

final globalSearchResultsProvider = StreamProvider<List<Note>>((ref) {
  final query = ref.watch(globalSearchQueryProvider).toLowerCase();
  
  // Return empty if query is empty to avoid fetching everything
  if (query.isEmpty) return Stream.value([]);
  
  final firestoreService = ref.watch(firestoreServiceProvider);
  
  // Client-side filtering of all notes stream
  return firestoreService.getAllNotesStream().map((notes) {
    return notes.where((note) {
      return note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query);
    }).toList();
  });
});

// ==================== ALL NOTES PROVIDER ====================

final allNotesProvider = StreamProvider<List<Note>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return firestoreService.getAllNotesStream();
});

// ==================== FOLDER NOTE COUNT PROVIDER ====================

/// Provides a map of folder IDs to their note counts
final folderNoteCountProvider = StreamProvider<Map<String, int>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value({});
  
  return firestoreService.getAllNotesStream().map((notes) {
    final counts = <String, int>{};
    for (final note in notes) {
      counts[note.folderId] = (counts[note.folderId] ?? 0) + 1;
    }
    return counts;
  });
});

// ==================== FAVORITES PROVIDER ====================

final favoriteNotesProvider = StreamProvider<List<Note>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  
  // Client-side filtering for favorites
  return firestoreService.getAllNotesStream().map((notes) {
    return notes.where((note) => note.isFavorite && !note.isArchived && !note.isTrashed).toList();
  });
});

// ==================== ARCHIVE PROVIDERS ====================

final archiveNotesProvider = StateNotifierProvider<ArchiveNotifier, AsyncValue<List<Note>>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final user = ref.watch(currentUserProvider);
  return ArchiveNotifier(firestoreService, user?.uid);
});

class ArchiveNotifier extends StateNotifier<AsyncValue<List<Note>>> {
  final FirestoreService _firestoreService;
  StreamSubscription<List<Note>>? _subscription;

  ArchiveNotifier(this._firestoreService, String? userId) : super(const AsyncValue.loading()) {
    if (userId != null) {
      _subscription = _firestoreService.getArchivedNotesStream().listen((notes) {
        state = AsyncValue.data(notes);
      }, onError: (err, stack) {
        state = AsyncValue.error(err, stack);
      });
    } else {
      state = const AsyncValue.data([]);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> unarchiveNote(String noteId) async {
    await _firestoreService.unarchiveNote(noteId);
  }
  
  Future<void> deleteNote(String noteId) async {
    await _firestoreService.moveToTrash(noteId);
  }
}

// ==================== TRASH PROVIDERS ====================

final trashNotesProvider = StateNotifierProvider<TrashNotifier, AsyncValue<List<Note>>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final user = ref.watch(currentUserProvider);
  return TrashNotifier(firestoreService, user?.uid);
});

class TrashNotifier extends StateNotifier<AsyncValue<List<Note>>> {
  final FirestoreService _firestoreService;
  StreamSubscription<List<Note>>? _subscription;

  TrashNotifier(this._firestoreService, String? userId) : super(const AsyncValue.loading()) {
    if (userId != null) {
      _subscription = _firestoreService.getTrashedNotesStream().listen((notes) {
        state = AsyncValue.data(notes);
      }, onError: (err, stack) {
        state = AsyncValue.error(err, stack);
      });
    } else {
      state = const AsyncValue.data([]);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> restoreNote(String noteId) async {
    await _firestoreService.restoreFromTrash(noteId);
  }
  
  Future<void> deletePermanently(String noteId) async {
    await _firestoreService.deleteNote(noteId);
  }
  
  Future<void> emptyTrash() async {
    await _firestoreService.emptyTrash();
  }
}

// ==================== REMINDERS PROVIDER ====================

final activeRemindersProvider = StreamProvider<List<Note>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return firestoreService.getRemindersStream();
});

// ==================== LABELS PROVIDERS ====================

final labelsProvider = StateNotifierProvider<LabelsNotifier, List<Label>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final user = ref.watch(currentUserProvider);
  return LabelsNotifier(firestoreService, user?.uid);
});

class LabelsNotifier extends StateNotifier<List<Label>> {
  final FirestoreService _firestoreService;
  final String? _userId;
  StreamSubscription<List<Label>>? _subscription;

  LabelsNotifier(this._firestoreService, this._userId) : super([]) {
    if (_userId != null) {
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _firestoreService.getLabelsStream().listen((labels) {
      state = labels;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> createLabel({required String name, required int colorValue}) async {
    await _firestoreService.createLabel(name: name, colorValue: colorValue);
  }

  Future<void> updateLabel(Label label) async {
    await _firestoreService.updateLabel(label);
  }

  Future<void> deleteLabel(String labelId) async {
    await _firestoreService.deleteLabel(labelId);
  }
}

final notesByLabelProvider = StreamProvider.family<List<Note>, String>((ref, labelId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  
  // Client-side filtering
  return firestoreService.getAllNotesStream().map((notes) {
    return notes.where((note) => note.labelIds.contains(labelId)).toList();
  });
});
