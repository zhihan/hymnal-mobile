import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/song_list_provider.dart';
import '../models/song_list.dart';
import 'song_list_detail_screen.dart';
import 'create_edit_list_screen.dart';

class SongListsScreen extends StatefulWidget {
  const SongListsScreen({super.key});

  @override
  State<SongListsScreen> createState() => _SongListsScreenState();
}

class _SongListsScreenState extends State<SongListsScreen> {
  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    final provider = Provider.of<SongListProvider>(context, listen: false);
    if (!provider.isLoaded) {
      await provider.loadLists();
    }
  }

  void _createNewList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateEditListScreen(),
      ),
    );
  }

  void _viewListDetail(SongList list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SongListDetailScreen(listId: list.id),
      ),
    );
  }

  void _showListOptions(SongList list) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _renameList(list);
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Export'),
              onTap: () {
                Navigator.pop(context);
                _exportList(list);
              },
            ),
            if (!list.isDefault && !list.isBuiltIn)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteList(list);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _renameList(SongList list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEditListScreen(listToEdit: list),
      ),
    );
  }

  Future<void> _exportList(SongList list) async {
    final provider = Provider.of<SongListProvider>(context, listen: false);
    final jsonString = await provider.exportList(list.id);

    if (jsonString == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export list')),
        );
      }
      return;
    }

    try {
      // Get directory to save file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${list.name.replaceAll(' ', '_').toLowerCase()}.json';
      final file = File('${directory.path}/$fileName');

      // Write file
      await file.writeAsString(jsonString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: ${file.path}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: $e')),
        );
      }
    }
  }

  void _deleteList(SongList list) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete List'),
        content: Text('Are you sure you want to delete "${list.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final provider = Provider.of<SongListProvider>(context, listen: false);
              final success = await provider.deleteList(list.id);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'List deleted'
                          : 'Failed to delete list',
                    ),
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _importList() async {
    try {
      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();

      final provider = Provider.of<SongListProvider>(context, listen: false);
      final importedList = await provider.importList(jsonString);

      if (mounted) {
        if (importedList != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported list: ${importedList.name}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to import list. Invalid file.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Song Lists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _importList,
            tooltip: 'Import List',
          ),
        ],
      ),
      body: Consumer<SongListProvider>(
        builder: (context, provider, child) {
          if (!provider.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final lists = provider.lists;

          if (lists.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.library_music,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No song lists yet',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a list to organize your favorite hymns',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[500],
                          ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final list = lists[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _viewListDetail(list),
                  onLongPress: () => _showListOptions(list),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: list.isDefault
                                ? Colors.red.withValues(alpha: 0.1)
                                : list.isBuiltIn
                                    ? Colors.orange.withValues(alpha: 0.1)
                                    : Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            list.isDefault
                                ? Icons.favorite
                                : list.isBuiltIn
                                    ? Icons.auto_awesome
                                    : Icons.library_music,
                            color: list.isDefault
                                ? Colors.red
                                : list.isBuiltIn
                                    ? Colors.orange
                                    : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                list.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${list.hymnCount} hymns',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () => _showListOptions(list),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewList,
        tooltip: 'Create List',
        child: const Icon(Icons.add),
      ),
    );
  }
}
