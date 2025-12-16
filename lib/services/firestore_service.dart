import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/note.dart';
import '../models/folder.dart';
import '../models/label.dart';

/// Firestore service for syncing notes, folders, and labels to the cloud
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  /// Get user's notes collection reference
  CollectionReference<Map<String, dynamic>> get _notesCollection {
    if (_userId == null) throw Exception('User not authenticated');
    return _firestore.collection('users').doc(_userId).collection('notes');
  }

  /// Get user's folders collection reference
  CollectionReference<Map<String, dynamic>> get _foldersCollection {
    if (_userId == null) throw Exception('User not authenticated');
    return _firestore.collection('users').doc(_userId).collection('folders');
  }

  /// Get user's labels collection reference
  CollectionReference<Map<String, dynamic>> get _labelsCollection {
    if (_userId == null) throw Exception('User not authenticated');
    return _firestore.collection('users').doc(_userId).collection('labels');
  }

  // ==================== FOLDER OPERATIONS ====================

  /// Stream of all folders for current user (not trashed)
  Stream<List<Folder>> getFoldersStream() {
    if (_userId == null) return Stream.value([]);
    
    return _foldersCollection
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _folderFromDoc(doc))
            .where((folder) => !folder.isTrashed)
            .toList());
  }

  /// Stream of trashed folders
  Stream<List<Folder>> getTrashedFoldersStream() {
    if (_userId == null) return Stream.value([]);
    
    return _foldersCollection
        .orderBy('trashedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _folderFromDoc(doc))
            .where((folder) => folder.isTrashed)
            .toList());
  }

  /// Convert Firestore doc to Folder
  Folder _folderFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Folder(
      id: doc.id,
      name: data['name'] ?? '',
      colorValue: data['colorValue'] ?? 0xFF2196F3,
      isLocked: data['isLocked'] ?? false,
      encryptedPin: data['encryptedPin'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      orderIndex: data['orderIndex'] ?? 0,
      isTrashed: data['isTrashed'] ?? false,
      trashedAt: (data['trashedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Create a new folder
  Future<Folder> createFolder({
    required String name,
    required int colorValue,
    String? encryptedPin,
  }) async {
    final now = DateTime.now();
    final docRef = await _foldersCollection.add({
      'name': name,
      'colorValue': colorValue,
      'isLocked': encryptedPin != null,
      'encryptedPin': encryptedPin,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'orderIndex': 0,
      'isTrashed': false,
      'trashedAt': null,
    });

    return Folder(
      id: docRef.id,
      name: name,
      colorValue: colorValue,
      isLocked: encryptedPin != null,
      encryptedPin: encryptedPin,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Update existing folder
  Future<void> updateFolder(Folder folder) async {
    await _foldersCollection.doc(folder.id).update({
      'name': folder.name,
      'colorValue': folder.colorValue,
      'isLocked': folder.isLocked,
      'encryptedPin': folder.encryptedPin,
      'updatedAt': FieldValue.serverTimestamp(),
      'orderIndex': folder.orderIndex,
    });
  }

  /// Move folder to trash (soft delete)
  Future<void> moveFolderToTrash(String folderId) async {
    await _foldersCollection.doc(folderId).update({
      'isTrashed': true,
      'trashedAt': FieldValue.serverTimestamp(),
    });
    
    // Also move all notes in folder to trash
    final notesSnapshot = await _notesCollection
        .where('folderId', isEqualTo: folderId)
        .get();
    
    for (final doc in notesSnapshot.docs) {
      await doc.reference.update({
        'isTrashed': true,
        'trashedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Restore folder from trash
  Future<void> restoreFolder(String folderId) async {
    await _foldersCollection.doc(folderId).update({
      'isTrashed': false,
      'trashedAt': null,
    });
    
    // Also restore all notes in folder from trash
    final notesSnapshot = await _notesCollection
        .where('folderId', isEqualTo: folderId)
        .get();
    
    for (final doc in notesSnapshot.docs) {
      await doc.reference.update({
        'isTrashed': false,
        'trashedAt': null,
      });
    }
  }

  /// Delete folder permanently and all its notes
  Future<void> deleteFolder(String folderId) async {
    // Delete all notes in folder
    final notesSnapshot = await _notesCollection
        .where('folderId', isEqualTo: folderId)
        .get();
    
    for (final doc in notesSnapshot.docs) {
      await doc.reference.delete();
    }
    
    // Delete folder
    await _foldersCollection.doc(folderId).delete();
  }

  /// Ensure default folder exists
  Future<void> ensureDefaultFolder() async {
    if (_userId == null) return;
    
    final defaultFolderDoc = await _foldersCollection.doc('default_folder').get();
    if (!defaultFolderDoc.exists) {
      await _foldersCollection.doc('default_folder').set({
        'name': 'General',
        'colorValue': 0xFF2196F3,
        'isLocked': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'orderIndex': 0,
        'isTrashed': false,
        'trashedAt': null,
      });
    }
  }

  // ==================== NOTE OPERATIONS ====================

  /// Stream of all notes (not archived, not trashed) - client-side filtering
  Stream<List<Note>> getAllNotesStream() {
    if (_userId == null) return Stream.value([]);
    
    return _notesCollection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _noteFromDoc(doc))
            .where((note) => !note.isArchived && !note.isTrashed)
            .toList());
  }

  /// Stream of notes in a specific folder - client-side filtering
  Stream<List<Note>> getNotesByFolderStream(String folderId) {
    if (_userId == null) return Stream.value([]);
    
    return _notesCollection
        .where('folderId', isEqualTo: folderId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final notes = snapshot.docs
              .map((doc) => _noteFromDoc(doc))
              .where((note) => !note.isArchived && !note.isTrashed)
              .toList();
          // Sort pinned notes first
          notes.sort((a, b) {
            if (a.isPinned && !b.isPinned) return -1;
            if (!a.isPinned && b.isPinned) return 1;
            return b.updatedAt.compareTo(a.updatedAt);
          });
          return notes;
        });
  }

  /// Stream of archived notes - client-side filtering
  Stream<List<Note>> getArchivedNotesStream() {
    if (_userId == null) return Stream.value([]);
    
    return _notesCollection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _noteFromDoc(doc))
            .where((note) => note.isArchived && !note.isTrashed)
            .toList());
  }

  /// Stream of trashed notes - client-side filtering
  Stream<List<Note>> getTrashedNotesStream() {
    if (_userId == null) return Stream.value([]);
    
    return _notesCollection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final notes = snapshot.docs
              .map((doc) => _noteFromDoc(doc))
              .where((note) => note.isTrashed)
              .toList();
          // Sort by trashedAt
          notes.sort((a, b) => (b.trashedAt ?? DateTime.now()).compareTo(a.trashedAt ?? DateTime.now()));
          return notes;
        });
  }

  /// Stream of notes with reminders - client-side filtering
  Stream<List<Note>> getRemindersStream() {
    if (_userId == null) return Stream.value([]);
    
    return _notesCollection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          final notes = snapshot.docs
              .map((doc) => _noteFromDoc(doc))
              .where((note) => !note.isTrashed && note.reminderDate != null && note.reminderDate!.isAfter(now))
              .toList();
          // Sort by reminderDate
          notes.sort((a, b) => (a.reminderDate ?? now).compareTo(b.reminderDate ?? now));
          return notes;
        });
  }

  /// Create a new note
  Future<Note> createNote({
    required String title,
    required String content,
    required String folderId,
    bool isPinned = false,
    List<String> labelIds = const [],
  }) async {
    final now = DateTime.now();
    final docRef = await _notesCollection.add({
      'title': title,
      'content': content,
      'folderId': folderId,
      'isPinned': isPinned,
      'isFavorite': false,
      'isArchived': false,
      'isTrashed': false,
      'labelIds': labelIds,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return Note(
      id: docRef.id,
      title: title,
      content: content,
      folderId: folderId,
      isPinned: isPinned,
      createdAt: now,
      updatedAt: now,
      labelIds: labelIds,
    );
  }

  /// Update existing note
  Future<void> updateNote(Note note) async {
    await _notesCollection.doc(note.id).update({
      'title': note.title,
      'content': note.content,
      'folderId': note.folderId,
      'isPinned': note.isPinned,
      'isFavorite': note.isFavorite,
      'isArchived': note.isArchived,
      'isTrashed': note.isTrashed,
      'trashedAt': note.trashedAt != null ? Timestamp.fromDate(note.trashedAt!) : null,
      'reminderDate': note.reminderDate != null ? Timestamp.fromDate(note.reminderDate!) : null,
      'labelIds': note.labelIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete note permanently
  Future<void> deleteNote(String noteId) async {
    await _notesCollection.doc(noteId).delete();
  }

  /// Move note to trash
  Future<void> moveToTrash(String noteId) async {
    await _notesCollection.doc(noteId).update({
      'isTrashed': true,
      'trashedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Restore note from trash
  Future<void> restoreFromTrash(String noteId) async {
    await _notesCollection.doc(noteId).update({
      'isTrashed': false,
      'trashedAt': null,
    });
  }

  /// Archive note
  Future<void> archiveNote(String noteId) async {
    await _notesCollection.doc(noteId).update({
      'isArchived': true,
    });
  }

  /// Unarchive note
  Future<void> unarchiveNote(String noteId) async {
    await _notesCollection.doc(noteId).update({
      'isArchived': false,
    });
  }

  /// Toggle pin status
  Future<void> togglePin(String noteId, bool isPinned) async {
    await _notesCollection.doc(noteId).update({
      'isPinned': isPinned,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String noteId, bool isFavorite) async {
    await _notesCollection.doc(noteId).update({
      'isFavorite': isFavorite,
    });
  }

  /// Empty trash
  Future<void> emptyTrash() async {
    final trashedNotes = await _notesCollection
        .where('isTrashed', isEqualTo: true)
        .get();
    
    for (final doc in trashedNotes.docs) {
      await doc.reference.delete();
    }
  }

  // ==================== LABEL OPERATIONS ====================

  /// Stream of all labels
  Stream<List<Label>> getLabelsStream() {
    if (_userId == null) return Stream.value([]);
    
    return _labelsCollection
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return Label(
                id: doc.id,
                name: data['name'] ?? '',
                colorValue: data['colorValue'] ?? 0xFF2196F3,
                createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              );
            }).toList());
  }

  /// Create a new label
  Future<Label> createLabel({
    required String name,
    required int colorValue,
  }) async {
    final now = DateTime.now();
    final docRef = await _labelsCollection.add({
      'name': name,
      'colorValue': colorValue,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return Label(
      id: docRef.id,
      name: name,
      colorValue: colorValue,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Update existing label
  Future<void> updateLabel(Label label) async {
    await _labelsCollection.doc(label.id).update({
      'name': label.name,
      'colorValue': label.colorValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete label and remove from all notes
  Future<void> deleteLabel(String labelId) async {
    // Remove label from all notes
    final notesWithLabel = await _notesCollection
        .where('labelIds', arrayContains: labelId)
        .get();
    
    for (final doc in notesWithLabel.docs) {
      final labelIds = List<String>.from(doc.data()['labelIds'] ?? []);
      labelIds.remove(labelId);
      await doc.reference.update({'labelIds': labelIds});
    }
    
    // Delete label
    await _labelsCollection.doc(labelId).delete();
  }

  /// Ensure default labels exist
  Future<void> ensureDefaultLabels() async {
    if (_userId == null) return;
    
    final workLabelDoc = await _labelsCollection.doc('work_label').get();
    if (!workLabelDoc.exists) {
      await _labelsCollection.doc('work_label').set({
        'name': 'Work',
        'colorValue': 0xFF2196F3,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    
    final personalLabelDoc = await _labelsCollection.doc('personal_label').get();
    if (!personalLabelDoc.exists) {
      await _labelsCollection.doc('personal_label').set({
        'name': 'Personal',
        'colorValue': 0xFF4CAF50,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ==================== HELPER METHODS ====================

  /// Convert Firestore document to Note object
  Note _noteFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Note(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      folderId: data['folderId'] ?? 'default_folder',
      isPinned: data['isPinned'] ?? false,
      isFavorite: data['isFavorite'] ?? false,
      isArchived: data['isArchived'] ?? false,
      isTrashed: data['isTrashed'] ?? false,
      trashedAt: (data['trashedAt'] as Timestamp?)?.toDate(),
      reminderDate: (data['reminderDate'] as Timestamp?)?.toDate(),
      labelIds: List<String>.from(data['labelIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Initialize user data (call after signup/signin)
  Future<void> initializeUserData() async {
    await ensureDefaultFolder();
    await ensureDefaultLabels();
  }
}
