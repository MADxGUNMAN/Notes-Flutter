import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../models/folder.dart';
import '../widgets/folder_card.dart';
import '../widgets/create_folder_dialog.dart';
import 'folder_view_screen.dart';
import 'pin_input_screen.dart';
import '../utils/encryption_helper.dart';

/// Home screen displaying all folders in a responsive grid
/// Now used as a body inside MainScreen with bottom navigation
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider);

    return Stack(
      children: [
        folders.isEmpty
            ? _buildEmptyState(context)
            : _buildFolderGrid(context, ref, folders),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _showCreateFolderDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('New Folder'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 120,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'No folders yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Create a folder to organize your notes',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderGrid(
    BuildContext context,
    WidgetRef ref,
    List<Folder> folders,
  ) {
    // Watch the folder note counts
    final noteCountsAsync = ref.watch(folderNoteCountProvider);
    final noteCounts = noteCountsAsync.maybeWhen(
      data: (counts) => counts,
      orElse: () => <String, int>{},
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive column count based on screen width
        int crossAxisCount;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 800) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 1;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: folders.length,
          itemBuilder: (context, index) {
            final folder = folders[index];
            final noteCount = noteCounts[folder.id] ?? 0;
            return FolderCard(
              folder: folder,
              noteCount: noteCount,
              onTap: () => _openFolder(context, ref, folder),
              onEdit: () => _showEditFolderDialog(context, ref, folder),
              onDelete: () => _deleteFolder(context, ref, folder),
            );
          },
        );
      },
    );
  }

  void _openFolder(BuildContext context, WidgetRef ref, Folder folder) {
    // Check if folder has PIN protection
    if (folder.hasPinProtection) {
      final isUnlocked = ref.read(isFolderUnlockedProvider(folder.id));
      
      if (!isUnlocked) {
        // Show PIN verification screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PinInputScreen(
              title: 'Enter PIN',
              subtitle: 'Enter PIN to unlock "${folder.name}"',
              onPinComplete: (pin) {
                // Verify PIN
                if (EncryptionHelper.verifyPin(pin, folder.encryptedPin!)) {
                  // Mark folder as unlocked
                  ref.read(unlockedFoldersProvider.notifier).state = {
                    ...ref.read(unlockedFoldersProvider),
                    folder.id: true,
                  };
                  
                  // Navigate to folder
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FolderViewScreen(folder: folder),
                    ),
                  );
                } else {
                  // Wrong PIN - show error and go back
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Incorrect PIN'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ),
        );
        return;
      }
    }

    // No PIN or already unlocked - open directly
    ref.read(currentFolderIdProvider.notifier).state = folder.id;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FolderViewScreen(folder: folder),
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => CreateFolderDialog(
        onCreateFolder: (name, color, pin) async {
          try {
            await ref.read(foldersProvider.notifier).createFolder(
                  name: name,
                  colorValue: color.value,
                  encryptedPin: pin,
                );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Folder created')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _showEditFolderDialog(BuildContext context, WidgetRef ref, Folder folder) {
    showDialog(
      context: context,
      builder: (context) => CreateFolderDialog(
        folder: folder,
        onCreateFolder: (name, color, pin) async {
          try {
            final updatedFolder = folder.copyWith(
              name: name,
              colorValue: color.value,
              encryptedPin: pin,
            );
            await ref.read(foldersProvider.notifier).updateFolder(updatedFolder);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Folder updated')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _deleteFolder(BuildContext context, WidgetRef ref, Folder folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Trash'),
        content: Text(
          'Are you sure you want to move "${folder.name}" to trash? '
          'All notes in this folder will also be moved to trash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(foldersProvider.notifier).moveToTrash(folder.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Folder moved to trash')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );
  }

}
