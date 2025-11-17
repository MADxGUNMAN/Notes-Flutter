import 'package:flutter/material.dart';
import '../models/folder.dart';
import '../services/database_service.dart';

/// Card widget displaying a folder with its color theme and PIN indicator
class FolderCard extends StatelessWidget {
  final Folder folder;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const FolderCard({
    super.key,
    required this.folder,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final noteCount = DatabaseService.getNotesByFolder(folder.id).length;
    final isDefaultFolder = folder.id == DatabaseService.defaultFolderId;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: folder.useGradient && folder.gradientColor != null
                ? LinearGradient(
                    colors: [
                      folder.color,
                      folder.gradientColor!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      folder.color.withOpacity(0.7),
                      folder.color,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
          ),
          child: Stack(
            children: [
              // Content
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          folder.icon,
                          color: _getContrastColor(folder.color),
                          size: 32,
                        ),
                        const SizedBox(width: 8),
                        if (folder.hasPinProtection)
                          Icon(
                            Icons.lock,
                            color: _getContrastColor(folder.color).withOpacity(0.8),
                            size: 20,
                          ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          folder.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: _getContrastColor(folder.color),
                                fontWeight: FontWeight.bold,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$noteCount ${noteCount == 1 ? 'note' : 'notes'}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: _getContrastColor(folder.color).withOpacity(0.8),
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Menu button
              Positioned(
                top: 4,
                right: 4,
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: _getContrastColor(folder.color),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    if (!isDefaultFolder)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
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
