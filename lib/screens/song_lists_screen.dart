import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/song_list_provider.dart';
import '../models/song_list.dart';
import '../services/song_list_share_service.dart';
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
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                _shareSongList(list);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _renameList(list);
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

  Future<void> _shareSongList(SongList list) async {
    try {
      final shareUrl = SongListShareService.generateShareUrl(list);
      final box = context.findRenderObject() as RenderBox?;
      await Share.share(
        shareUrl,
        subject: 'Share Song List: ${list.name}',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share: $e')),
      );
    }
  }

  void _renameList(SongList list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEditListScreen(listToEdit: list),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Song Lists'),
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
