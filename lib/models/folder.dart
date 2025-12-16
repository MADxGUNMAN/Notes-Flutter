import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'folder.g.dart';

/// Represents a folder that can contain multiple notes
/// Supports PIN protection and custom color themes
@HiveType(typeId: 1)
class Folder extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late int colorValue; // Store color as int for Hive compatibility

  @HiveField(3)
  late bool isLocked;

  @HiveField(4)
  String? encryptedPin; // Encrypted 6-digit PIN (nullable if no PIN set)

  @HiveField(5)
  late DateTime createdAt;

  @HiveField(6)
  late DateTime updatedAt;

  @HiveField(7)
  late int iconCodePoint; // Icon code point for custom folder icons

  @HiveField(8)
  late bool useGradient; // Whether to use gradient instead of solid color

  @HiveField(9)
  int? gradientColorValue; // Secondary color for gradient

  @HiveField(10)
  late int orderIndex; // For drag-to-reorder functionality

  @HiveField(11)
  late bool isTrashed; // Whether folder is in trash

  @HiveField(12)
  DateTime? trashedAt; // When the folder was moved to trash

  Folder({
    required this.id,
    required this.name,
    required this.colorValue,
    this.isLocked = false,
    this.encryptedPin,
    required this.createdAt,
    required this.updatedAt,
    this.iconCodePoint = 0xe2c7, // Default folder icon
    this.useGradient = false,
    this.gradientColorValue,
    this.orderIndex = 0,
    this.isTrashed = false,
    this.trashedAt,
  });

  /// Get color object from stored int value
  Color get color => Color(colorValue);

  /// Set color from Color object
  set color(Color value) => colorValue = value.value;

  /// Check if folder has PIN protection enabled
  bool get hasPinProtection => encryptedPin != null && encryptedPin!.isNotEmpty;

  /// Get icon for this folder.
  ///
  /// Note: Using a constant [IconData] here to support icon tree-shaking in
  /// release builds. If you later need per-folder custom icons, use an enum or
  /// another compile-time constant mechanism instead of a raw code point.
  IconData get icon => const IconData(0xe2c7, fontFamily: 'MaterialIcons');

  /// Get gradient color if enabled
  Color? get gradientColor => gradientColorValue != null ? Color(gradientColorValue!) : null;

  /// Create a copy of this folder with updated fields
  Folder copyWith({
    String? id,
    String? name,
    int? colorValue,
    bool? isLocked,
    String? encryptedPin,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? iconCodePoint,
    bool? useGradient,
    int? gradientColorValue,
    int? orderIndex,
    bool? isTrashed,
    DateTime? trashedAt,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      isLocked: isLocked ?? this.isLocked,
      encryptedPin: encryptedPin ?? this.encryptedPin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      useGradient: useGradient ?? this.useGradient,
      gradientColorValue: gradientColorValue ?? this.gradientColorValue,
      orderIndex: orderIndex ?? this.orderIndex,
      isTrashed: isTrashed ?? this.isTrashed,
      trashedAt: trashedAt ?? this.trashedAt,
    );
  }

  @override
  String toString() {
    return 'Folder(id: $id, name: $name, isLocked: $isLocked, hasPIN: $hasPinProtection, isTrashed: $isTrashed)';
  }
}
