import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/hymn_song.dart';
import '../services/hymn_loader_service.dart';
import '../widgets/hymn_display.dart';
import '../providers/song_list_provider.dart';

class HymnDetailScreen extends StatefulWidget {
  final int initialHymnNumber;
  final String bookId;

  const HymnDetailScreen({
    super.key,
    required this.initialHymnNumber,
    required this.bookId,
  });

  @override
  State<HymnDetailScreen> createState() => _HymnDetailScreenState();
}

class _HymnDetailScreenState extends State<HymnDetailScreen> {
  HymnSong? _currentHymn;
  bool _isLoading = true;
  String? _error;
  int _currentHymnNumber = 1;
  String _currentBookId = 'ts';
  String _bookDisplayName = '';
  int _transposeOffset = 0;
  bool _showTransposeControls = false;
  bool _showChords = true; // Show chords by default
  int? _nextHymnNumber;
  int? _previousHymnNumber;
  bool _showLanguageNavigation = false;

  // Book short names for display
  static const Map<String, String> _bookShortNames = {
    'ch': '大',
    'ts': '补',
    'h': 'E',
  };

  @override
  void initState() {
    super.initState();
    _currentHymnNumber = widget.initialHymnNumber;
    _currentBookId = widget.bookId;
    _loadBookDisplayName();
    _loadHymn(_currentHymnNumber);
  }

  Future<void> _loadBookDisplayName() async {
    try {
      final books = await HymnLoaderService.getCategories();
      setState(() {
        _bookDisplayName = books[_currentBookId] ?? '补充本';
      });
    } catch (e) {
      setState(() {
        _bookDisplayName = '补充本';
      });
    }
  }

  Future<void> _loadHymn(int hymnNumber) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load the hymn first
      final hymn = await HymnLoaderService.loadHymnByNumber(_currentBookId, hymnNumber);

      // Then load navigation info (these use cached available numbers)
      // Wrap in try-catch to handle errors gracefully
      int? nextNumber;
      int? previousNumber;

      try {
        nextNumber = await HymnLoaderService.getNextHymnNumber(_currentBookId, hymnNumber);
        previousNumber = await HymnLoaderService.getPreviousHymnNumber(_currentBookId, hymnNumber);
      } catch (navError) {
        // If navigation loading fails, we can still show the hymn
        // Just disable the navigation buttons
        // Navigation will be null, buttons will be disabled
      }

      setState(() {
        _currentHymn = hymn;
        _nextHymnNumber = nextNumber;
        _previousHymnNumber = previousNumber;
        _currentHymnNumber = hymnNumber;
        _isLoading = false;
        _transposeOffset = 0; // Reset transpose when loading new hymn
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _transposeUp() {
    setState(() {
      _transposeOffset++;
    });
  }

  void _transposeDown() {
    setState(() {
      _transposeOffset--;
    });
  }

  void _resetTranspose() {
    setState(() {
      _transposeOffset = 0;
    });
  }

  List<Map<String, dynamic>> _getRelatedHymns() {
    if (_currentHymn?.metadata == null) return [];
    final related = _currentHymn!.metadata!['related'];
    if (related == null || related is! List) return [];
    return List<Map<String, dynamic>>.from(related);
  }

  void _navigateToRelatedHymn(String bookId, String number) {
    final hymnNumber = int.tryParse(number);
    if (hymnNumber == null) return;

    setState(() {
      _currentBookId = bookId;
    });
    _loadBookDisplayName();
    _loadHymn(hymnNumber);
  }

  String get _currentHymnId => '${_currentBookId}_$_currentHymnNumber';

  void _showAddToListMenu() {
    final songListProvider = Provider.of<SongListProvider>(context, listen: false);
    final lists = songListProvider.lists;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Add to List',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            if (lists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('No lists available'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                itemCount: lists.length,
                itemBuilder: (context, index) {
                  final list = lists[index];
                  final isInList = list.containsHymn(_currentHymnId);
                  final isFull = list.isFull();
                  final isBuiltIn = list.isBuiltIn;

                  return ListTile(
                    leading: Icon(
                      list.isDefault
                          ? Icons.favorite
                          : list.isBuiltIn
                              ? Icons.auto_awesome
                              : Icons.library_music,
                      color: isInList
                          ? (list.isDefault
                              ? Colors.red
                              : list.isBuiltIn
                                  ? Colors.orange
                                  : Theme.of(context).colorScheme.primary)
                          : Colors.grey,
                    ),
                    title: Text(list.name),
                    subtitle: Text(
                      isBuiltIn
                          ? '${list.hymnCount} hymns (Read-only)'
                          : '${list.hymnCount} hymns',
                    ),
                    trailing: isInList
                        ? (isBuiltIn
                            ? const Icon(Icons.lock, color: Colors.grey)
                            : const Icon(Icons.check, color: Colors.green))
                        : (isFull
                            ? const Icon(Icons.block, color: Colors.grey)
                            : (isBuiltIn
                                ? const Icon(Icons.lock, color: Colors.grey)
                                : null)),
                    enabled: !isBuiltIn && (!isFull || isInList),
                    onTap: isBuiltIn
                        ? null
                        : () async {
                            Navigator.pop(context);
                            if (isInList) {
                              await songListProvider.removeHymnFromList(list.id, _currentHymnId);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Removed from ${list.name}')),
                                );
                              }
                            } else {
                              final success = await songListProvider.addHymnToList(list.id, _currentHymnId);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Added to ${list.name}'
                                          : 'Failed to add to ${list.name}',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('$_bookDisplayName $_currentHymnNumber'),
        actions: [
          Consumer<SongListProvider>(
            builder: (context, provider, child) {
              final defaultList = provider.defaultList;
              final isFavorite = defaultList?.containsHymn(_currentHymnId) ?? false;

              return IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : null,
                ),
                onPressed: () {
                  provider.toggleFavorite(_currentHymnId);
                },
                tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add),
            onPressed: _showAddToListMenu,
            tooltip: 'Add to list',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: _previousHymnNumber != null
                ? () => _loadHymn(_previousHymnNumber!)
                : null,
            tooltip: _previousHymnNumber != null
                ? 'Previous hymn ($_previousHymnNumber)'
                : 'No previous hymn',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: _nextHymnNumber != null
                ? () => _loadHymn(_nextHymnNumber!)
                : null,
            tooltip: _nextHymnNumber != null
                ? 'Next hymn ($_nextHymnNumber)'
                : 'No next hymn',
          ),
          if (_getRelatedHymns().isNotEmpty)
            IconButton(
              icon: const Icon(Icons.translate),
              onPressed: () {
                setState(() {
                  _showLanguageNavigation = !_showLanguageNavigation;
                });
              },
              tooltip: 'Toggle language navigation',
            ),
          IconButton(
            icon: Icon(_showTransposeControls
                ? Icons.expand_less
                : Icons.expand_more),
            onPressed: () {
              setState(() {
                _showTransposeControls = !_showTransposeControls;
              });
            },
            tooltip: 'Toggle transpose controls',
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

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                '无法加载诗歌',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!.contains('Failed to load')
                    ? '诗歌编号 $_currentHymnNumber 不存在\n请返回选择其他诗歌'
                    : _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadHymn(_currentHymnNumber),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentHymn == null) {
      return const Center(
        child: Text('No hymn loaded'),
      );
    }

    return Column(
      children: [
        // Language navigation (collapsible)
        if (_showLanguageNavigation && _getRelatedHymns().isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border(
                bottom: BorderSide(color: Colors.blue[100]!, width: 1),
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _getRelatedHymns().map((related) {
                final bookId = related['category'] as String? ?? '';
                final number = related['number'] as String? ?? '';
                final shortName = _bookShortNames[bookId] ?? bookId.toUpperCase();
                final displayText = '$shortName$number';

                return ElevatedButton(
                  onPressed: () => _navigateToRelatedHymn(bookId, number),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    backgroundColor: Colors.blue[100],
                    foregroundColor: Colors.blue[900],
                  ),
                  child: Text(
                    displayText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        // Transpose controls (collapsible)
        if (_showTransposeControls)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Chord visibility toggle
                const Text(
                  'Chords',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Switch(
                  value: _showChords,
                  onChanged: (bool value) {
                    setState(() {
                      _showChords = value;
                    });
                  },
                ),
                const SizedBox(width: 24),
                // Transpose down button
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _transposeDown,
                  tooltip: 'Transpose down',
                  iconSize: 28,
                ),
                // Current transpose offset display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: Text(
                    _transposeOffset > 0
                        ? '+$_transposeOffset'
                        : _transposeOffset.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Transpose up button
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _transposeUp,
                  tooltip: 'Transpose up',
                  iconSize: 28,
                ),
                const SizedBox(width: 8),
                // Reset button
                TextButton(
                  onPressed: _transposeOffset != 0 ? _resetTranspose : null,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
        // Hymn display
        Expanded(
          child: HymnDisplay(
            hymn: _currentHymn!,
            transposeOffset: _transposeOffset,
            showChords: _showChords,
          ),
        ),
      ],
    );
  }
}
