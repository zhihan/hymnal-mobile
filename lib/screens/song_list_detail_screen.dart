import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/song_list_provider.dart';
import '../services/hymn_db_service.dart';
import '../services/hymn_loader_service.dart';
import '../services/song_list_share_service.dart';
import '../models/hymn_db.dart';

class SongListDetailScreen extends StatefulWidget {
  final String listId;

  const SongListDetailScreen({
    super.key,
    required this.listId,
  });

  @override
  State<SongListDetailScreen> createState() => _SongListDetailScreenState();
}

class _SongListDetailScreenState extends State<SongListDetailScreen> {
  List<HymnDb> _hymns = [];
  bool _isLoading = true;
  Map<String, String> _categories = {};

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadHymns();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await HymnLoaderService.getCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      // Keep empty map if loading fails
    }
  }

  Future<void> _loadHymns() async {
    setState(() {
      _isLoading = true;
    });

    final provider = Provider.of<SongListProvider>(context, listen: false);
    final list = provider.getListById(widget.listId);

    if (list == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final hymns = <HymnDb>[];
    for (final hymnId in list.hymnIds) {
      final hymn = await HymnDbService.getHymnById(hymnId);
      if (hymn != null) {
        hymns.add(hymn);
      }
    }

    setState(() {
      _hymns = hymns;
      _isLoading = false;
    });
  }

  void _navigateToHymn(HymnDb hymn) {
    context.push('/hymn/${hymn.bookId}/${hymn.number}').then((_) {
      _loadHymns();
    });
  }

  String _getDisplayName(HymnDb hymn) {
    final bookName = _categories[hymn.bookId] ?? hymn.bookId.toUpperCase();
    return '$bookName ${hymn.number}';
  }

  void _removeHymn(HymnDb hymn, int index) {
    final provider = Provider.of<SongListProvider>(context, listen: false);
    provider.removeHymnFromList(widget.listId, hymn.hymnId);

    setState(() {
      _hymns.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${hymn.title} removed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            provider.addHymnToList(widget.listId, hymn.hymnId);
            _loadHymns();
          },
        ),
      ),
    );
  }

  Future<void> _shareSongList() async {
    final provider = Provider.of<SongListProvider>(context, listen: false);
    final list = provider.getListById(widget.listId);

    if (list == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Song list not found')),
      );
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Consumer<SongListProvider>(
          builder: (context, provider, child) {
            final list = provider.getListById(widget.listId);
            return Text(list?.name ?? 'Song List');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share song list',
            onPressed: _shareSongList,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hymns.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.music_note,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No hymns in this list',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add hymns from the hymn detail screen',
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

    return Consumer<SongListProvider>(
      builder: (context, provider, child) {
        final list = provider.getListById(widget.listId);
        final isBuiltIn = list?.isBuiltIn ?? false;

        // Use regular ListView for built-in lists, ReorderableListView for editable lists
        if (isBuiltIn) {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _hymns.length,
            itemBuilder: (context, index) {
              final hymn = _hymns[index];

              return ListTile(
                key: Key(hymn.hymnId),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  hymn.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  _getDisplayName(hymn),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _navigateToHymn(hymn),
              );
            },
          );
        }

        return ReorderableListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _hymns.length,
          onReorder: (oldIndex, newIndex) async {
            if (oldIndex < newIndex) {
              newIndex -= 1;
            }

            final hymn = _hymns.removeAt(oldIndex);
            _hymns.insert(newIndex, hymn);

            // Update order in provider
            final newOrder = _hymns.map((h) => h.hymnId).toList();
            await provider.reorderHymns(widget.listId, newOrder);

            setState(() {});
          },
          itemBuilder: (context, index) {
            final hymn = _hymns[index];

            return Dismissible(
              key: Key(hymn.hymnId),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16.0),
                child: const Icon(
                  Icons.delete,
                  color: Colors.white,
                ),
              ),
              onDismissed: (direction) {
                _removeHymn(hymn, index);
              },
              child: ListTile(
                key: Key(hymn.hymnId),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.drag_handle, color: Colors.grey[400]),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                title: Text(
                  hymn.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  _getDisplayName(hymn),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _navigateToHymn(hymn),
              ),
            );
          },
        );
      },
    );
  }
}
