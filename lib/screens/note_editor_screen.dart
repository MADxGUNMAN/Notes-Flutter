import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../providers/app_providers.dart';

/// Screen for creating or editing a note
/// Features: Auto-save on typing, Undo/Redo functionality
class NoteEditorScreen extends ConsumerStatefulWidget {
  final Note? note;
  final String folderId;
  final Color folderColor;

  const NoteEditorScreen({
    super.key,
    this.note,
    required this.folderId,
    required this.folderColor,
  });

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final UndoHistoryController _undoController;
  late bool _isPinned;
  List<String> _labelIds = [];
  DateTime? _reminderDate;
  bool _hasChanges = false;
  bool _isSaving = false;
  Timer? _autoSaveTimer;
  String? _savedNoteId;

  // Auto-save delay in milliseconds
  static const int _autoSaveDelay = 1500;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _undoController = UndoHistoryController();
    _isPinned = widget.note?.isPinned ?? false;
    _labelIds = widget.note?.labelIds ?? [];
    _reminderDate = widget.note?.reminderDate;
    _savedNoteId = widget.note?.id;

    // Track changes and trigger auto-save
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.removeListener(_onTextChanged);
    _contentController.removeListener(_onTextChanged);
    _titleController.dispose();
    _contentController.dispose();
    _undoController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
    // Reset and start auto-save timer
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(
      const Duration(milliseconds: _autoSaveDelay),
      _autoSave,
    );
  }

  /// Auto-save note in background
  Future<void> _autoSave() async {
    if (!_hasChanges) return;
    
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // Don't auto-save completely empty notes
    if (title.isEmpty && content.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final finalTitle = title.isEmpty ? 'Untitled' : title;

      if (_savedNoteId == null) {
        // Create new note and store its ID
        // Note: We need to update createNote to accept labelIds, or update it after creation
        // For now, let's create then update if labels exist, or better yet, assume createNote doesn't take labels yet
        // and we rely on update logic or we add labelIds param to createNote.
        // Actually, Note object has labelIds. 
        // Let's check NotesNotifier.createNote. It usually just takes title/content/pinned.
        // So we might need to do an immediate update if labels are selected.
        
        final newNote = await ref.read(notesProvider.notifier).createNote(
              title: finalTitle,
              content: content,
              isPinned: _isPinned,
            );
        _savedNoteId = newNote.id;

        // If we have labels, we need to apply them now
        if (_labelIds.isNotEmpty) {
           final noteWithLabels = newNote.copyWith(labelIds: _labelIds);
           await ref.read(notesProvider.notifier).updateNote(noteWithLabels);
        }

      } else {
        // Update existing note
        final updatedNote = Note(
          id: _savedNoteId!,
          title: finalTitle,
          content: content,
          folderId: widget.folderId,
          isPinned: _isPinned,
          isFavorite: widget.note?.isFavorite ?? false,
          isArchived: widget.note?.isArchived ?? false,
          isTrashed: widget.note?.isTrashed ?? false,
          trashedAt: widget.note?.trashedAt,
          reminderDate: _reminderDate,
          labelIds: _labelIds,
          createdAt: widget.note?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await ref.read(notesProvider.notifier).updateNote(updatedNote);
      }
      
      _hasChanges = false;
    } catch (e) {
      // Silently fail auto-save, will retry on next change
      debugPrint('Auto-save failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showLabelSelectionDialog() {
    final labels = ref.read(labelsProvider);
    final selectedIds = Set<String>.from(_labelIds);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Labels'),
              content: SizedBox(
                width: double.maxFinite,
                child: labels.isEmpty
                    ? const Center(child: Text('No labels created yet'))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: labels.length,
                        itemBuilder: (context, index) {
                          final label = labels[index];
                          final isSelected = selectedIds.contains(label.id);
                          return CheckboxListTile(
                            title: Text(label.name),
                            secondary: Icon(
                              Icons.label,
                              color: Color(label.colorValue),
                            ),
                            value: isSelected,
                            onChanged: (value) {
                              setDialogState(() {
                                if (value == true) {
                                  selectedIds.add(label.id);
                                } else {
                                  selectedIds.remove(label.id);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _labelIds = selectedIds.toList();
                      _hasChanges = true;
                    });
                     _onTextChanged(); // Trigger auto-save
                    Navigator.pop(context);
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReminderPicker() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Set Reminder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_reminderDate != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.alarm, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Current: ${_formatDateTime(_reminderDate!)}',
                          style: Theme.of(dialogContext).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Pick date & time'),
                onTap: () async {
                  Navigator.pop(dialogContext);
                  await _pickReminderDateTime();
                },
              ),
              if (_reminderDate != null)
                ListTile(
                  leading: const Icon(Icons.clear, color: Colors.red),
                  title: const Text('Remove reminder', 
                    style: TextStyle(color: Colors.red)),
                  onTap: () {
                    setState(() {
                      _reminderDate = null;
                      _hasChanges = true;
                    });
                    _onTextChanged();
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reminder removed')),
                    );
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickReminderDateTime() async {
    final now = DateTime.now();
    final initialDate = _reminderDate ?? now.add(const Duration(hours: 1));
    
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    
    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );
      
      if (pickedTime != null && mounted) {
        setState(() {
          _reminderDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          _hasChanges = true;
        });
        _onTextChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminder set for ${_formatDateTime(_reminderDate!)}')),
        );
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $hour:${dt.minute.toString().padLeft(2, '0')} $amPm';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          // Cancel any pending auto-save and save immediately
          _autoSaveTimer?.cancel();
          if (_hasChanges) {
            await _autoSave();
          }
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Text(widget.note == null ? 'New Note' : 'Edit Note'),
              const SizedBox(width: 8),
              // Auto-save indicator
              if (_isSaving)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _getContrastColor(widget.folderColor).withOpacity(0.7),
                  ),
                )
              else if (_hasChanges)
                Icon(
                  Icons.edit,
                  size: 16,
                  color: _getContrastColor(widget.folderColor).withOpacity(0.7),
                )
              else if (_savedNoteId != null)
                Icon(
                  Icons.cloud_done,
                  size: 16,
                  color: _getContrastColor(widget.folderColor).withOpacity(0.7),
                ),
            ],
          ),
          backgroundColor: widget.folderColor,
          foregroundColor: _getContrastColor(widget.folderColor),
          elevation: 0,
          actions: [
            // Undo button
            ListenableBuilder(
              listenable: _undoController,
              builder: (context, child) {
                return IconButton(
                  icon: const Icon(Icons.undo),
                  onPressed: _undoController.value.canUndo
                      ? () => _undoController.undo()
                      : null,
                  tooltip: 'Undo',
                );
              },
            ),
            // Redo button
            ListenableBuilder(
              listenable: _undoController,
              builder: (context, child) {
                return IconButton(
                  icon: const Icon(Icons.redo),
                  onPressed: _undoController.value.canRedo
                      ? () => _undoController.redo()
                      : null,
                  tooltip: 'Redo',
                );
              },
            ),
            // Pin button
            IconButton(
              icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              onPressed: () {
                setState(() => _isPinned = !_isPinned);
                _hasChanges = true;
                _onTextChanged(); // Trigger auto-save
              },
              tooltip: _isPinned ? 'Unpin note' : 'Pin note',
            ),
            // Labels button
            IconButton(
              icon: const Icon(Icons.label_outlined),
              onPressed: _showLabelSelectionDialog,
              tooltip: 'Labels',
            ),
            // Reminder button
            IconButton(
              icon: Icon(
                _reminderDate != null ? Icons.alarm_on : Icons.alarm_add,
                color: _reminderDate != null ? Colors.amber : null,
              ),
              onPressed: _showReminderPicker,
              tooltip: _reminderDate != null ? 'Edit reminder' : 'Set reminder',
            ),
            // Save button (for manual save)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () async {
                _autoSaveTimer?.cancel();
                await _autoSave();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              tooltip: 'Save & Close',
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Title field
              TextField(
                controller: _titleController,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                  filled: false,
                ),
                textInputAction: TextInputAction.next,
              ),
              const Divider(),
              const SizedBox(height: 8),
              // Content field with undo support
              Expanded(
                child: TextField(
                  controller: _contentController,
                  undoController: _undoController,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'Start writing...',
                    border: InputBorder.none,
                    filled: false,
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
            ],
          ),
        ),
        // Status bar at bottom
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Icon(
                  _isSaving 
                      ? Icons.sync 
                      : (_hasChanges ? Icons.edit_note : Icons.cloud_done),
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  _isSaving 
                      ? 'Saving...' 
                      : (_hasChanges ? 'Unsaved changes' : 'All changes saved'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const Spacer(),
                Text(
                  '${_contentController.text.length} characters',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Calculate contrasting color for text on colored background
  Color _getContrastColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
