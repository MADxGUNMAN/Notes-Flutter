import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/folder.dart';
import '../utils/encryption_helper.dart';
import '../screens/pin_input_screen.dart';

/// Dialog for creating or editing a folder with color selection and optional PIN
class CreateFolderDialog extends StatefulWidget {
  final Folder? folder; // If provided, edit mode; otherwise create mode
  final Function(String name, Color color, String? encryptedPin) onCreateFolder;

  const CreateFolderDialog({
    super.key,
    this.folder,
    required this.onCreateFolder,
  });

  @override
  State<CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<CreateFolderDialog> {
  late final TextEditingController _nameController;
  late Color _selectedColor;
  bool _hasPin = false;
  String? _encryptedPin;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.folder?.name ?? '');
    _selectedColor = widget.folder?.color ?? Colors.blue;
    _hasPin = widget.folder?.hasPinProtection ?? false;
    _encryptedPin = widget.folder?.encryptedPin;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.folder != null;

    return AlertDialog(
      title: Text(isEditMode ? 'Edit Folder' : 'Create Folder'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Folder Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.folder),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            // Color picker
            Text(
              'Folder Color',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _showColorPicker,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: _selectedColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Tap to change color',
                    style: TextStyle(
                      color: _getContrastColor(_selectedColor),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // PIN protection toggle
            SwitchListTile(
              title: const Text('PIN Protection'),
              subtitle: Text(_hasPin
                  ? 'This folder is protected with a PIN'
                  : 'Add PIN to lock this folder'),
              value: _hasPin,
              onChanged: (value) {
                if (value) {
                  _setupPin();
                } else {
                  setState(() {
                    _hasPin = false;
                    _encryptedPin = null;
                  });
                }
              },
              secondary: Icon(
                _hasPin ? Icons.lock : Icons.lock_open,
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveFolderClicked,
          child: Text(isEditMode ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: _selectedColor,
            onColorChanged: (color) {
              setState(() => _selectedColor = color);
              Navigator.pop(context);
            },
            availableColors: const [
              Colors.blue,
              Colors.red,
              Colors.green,
              Colors.orange,
              Colors.purple,
              Colors.teal,
              Colors.pink,
              Colors.indigo,
              Colors.amber,
              Colors.cyan,
              Colors.deepOrange,
              Colors.deepPurple,
              Colors.lightBlue,
              Colors.lightGreen,
              Colors.lime,
              Colors.brown,
            ],
          ),
        ),
      ),
    );
  }

  void _setupPin() {
    String? firstPin;

    // First PIN entry
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PinInputScreen(
          title: 'Create PIN',
          subtitle: 'Enter a 6-digit PIN for this folder',
          onPinComplete: (pin) {
            firstPin = pin;
            Navigator.pop(context);

            // Confirmation PIN entry
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PinInputScreen(
                  title: 'Confirm PIN',
                  subtitle: 'Re-enter your PIN to confirm',
                  onPinComplete: (confirmPin) {
                    if (firstPin == confirmPin) {
                      // PINs match - encrypt and save
                      setState(() {
                        _hasPin = true;
                        _encryptedPin = EncryptionHelper.encryptPin(pin);
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PIN set successfully')),
                      );
                    } else {
                      // PINs don't match
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('PINs do not match. Please try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _saveFolder() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a folder name')),
      );
      return;
    }

    await widget.onCreateFolder(
      name,
      _selectedColor,
      _hasPin ? _encryptedPin : null,
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _saveFolderClicked() {
    _saveFolder();
  }

  /// Calculate contrasting color for text on colored background
  Color _getContrastColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
