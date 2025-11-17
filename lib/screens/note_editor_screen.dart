import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../providers/app_providers.dart';

/// Screen for creating or editing a note
/// Auto-saves on navigation back
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
  late bool _isPinned;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _isPinned = widget.note?.isPinned ?? false;

    // Track changes
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
    _contentController.removeListener(_onTextChanged);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _saveNote();
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.note == null ? 'New Note' : 'Edit Note'),
          backgroundColor: widget.folderColor,
          foregroundColor: _getContrastColor(widget.folderColor),
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              onPressed: () {
                setState(() => _isPinned = !_isPinned);
                _hasChanges = true;
              },
              tooltip: _isPinned ? 'Unpin note' : 'Pin note',
            ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () async {
                await _saveNote();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              tooltip: 'Save',
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
                ),
                textInputAction: TextInputAction.next,
              ),
              const Divider(),
              const SizedBox(height: 8),
              // Content field
              Expanded(
                child: TextField(
                  controller: _contentController,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'Start writing...',
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Save the note if there are changes
  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // Don't save empty notes
    if (title.isEmpty && content.isEmpty) {
      return;
    }

    // Ensure title is not empty (use default if needed)
    final finalTitle = title.isEmpty ? 'Untitled' : title;

    try {
      if (widget.note == null) {
        // Create new note
        await ref.read(notesProvider.notifier).createNote(
              title: finalTitle,
              content: content,
              isPinned: _isPinned,
            );
      } else {
        // Update existing note
        final updatedNote = widget.note!.copyWith(
          title: finalTitle,
          content: content,
          isPinned: _isPinned,
        );
        await ref.read(notesProvider.notifier).updateNote(updatedNote);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving note: $e')),
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
