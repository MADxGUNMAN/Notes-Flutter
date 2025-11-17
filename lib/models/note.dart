import 'package:hive/hive.dart';

part 'note.g.dart';

/// Represents a single note with title, content, and metadata
@HiveType(typeId: 0)
class Note extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  late String content;

  @HiveField(3)
  late String folderId;

  @HiveField(4)
  late bool isPinned;

  @HiveField(5)
  late DateTime createdAt;

  @HiveField(6)
  late DateTime updatedAt;

  @HiveField(7)
  late bool isFavorite;

  @HiveField(8)
  late bool isArchived;

  @HiveField(9)
  late bool isTrashed;

  @HiveField(10)
  DateTime? trashedAt;

  @HiveField(11)
  DateTime? reminderDate;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.folderId,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
    this.isFavorite = false,
    this.isArchived = false,
    this.isTrashed = false,
    this.trashedAt,
    this.reminderDate,
  });

  /// Create a copy of this note with updated fields
  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? folderId,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
    bool? isArchived,
    bool? isTrashed,
    DateTime? trashedAt,
    DateTime? reminderDate,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      folderId: folderId ?? this.folderId,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      isTrashed: isTrashed ?? this.isTrashed,
      trashedAt: trashedAt ?? this.trashedAt,
      reminderDate: reminderDate ?? this.reminderDate,
    );
  }

  @override
  String toString() {
    return 'Note(id: $id, title: $title, folderId: $folderId, isPinned: $isPinned)';
  }
}
