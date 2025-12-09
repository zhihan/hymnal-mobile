import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'hymn_detail_screen.dart';
import 'search_screen.dart';
import 'song_lists_screen.dart';
import 'song_list_detail_screen.dart';
import '../services/hymn_loader_service.dart';
import '../providers/song_list_provider.dart';
import '../services/song_list_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _hymnNumberController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, String> _books = {};
  String _selectedBookId = 'ch'; // Default to 'ch' (大本)

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadSongLists();
  }

  Future<void> _loadSongLists() async {
    final provider = Provider.of<SongListProvider>(context, listen: false);
    if (!provider.isLoaded) {
      await provider.loadLists();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final books = await HymnLoaderService.getCategories();
      setState(() {
        _books = books;
        // Set default bookId if 'ns' exists, otherwise use first available
        if (!books.containsKey(_selectedBookId) && books.isNotEmpty) {
          _selectedBookId = books.keys.first;
        }
      });
    } catch (e) {
      // If books fail to load, keep default
    }
  }

  @override
  void dispose() {
    _hymnNumberController.dispose();
    super.dispose();
  }

  Future<void> _goToHymn() async {
    if (_formKey.currentState!.validate()) {
      final hymnNumber = int.parse(_hymnNumberController.text);

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // Try to load the hymn to verify it exists
        await HymnLoaderService.loadHymnByNumber(_selectedBookId, hymnNumber);

        // If successful, navigate to detail screen
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HymnDetailScreen(
                initialHymnNumber: hymnNumber,
                bookId: _selectedBookId,
              ),
            ),
          );
        }
      } catch (e) {
        // If hymn doesn't exist, show error message
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = '诗歌编号 $hymnNumber 不存在，请输入其他编号';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookDisplayName = _books[_selectedBookId] ?? 'New Songs';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(bookDisplayName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            tooltip: 'Favorites',
            onPressed: () async {
              // Navigate to default favorites list
              final songListService = SongListService();
              final defaultList = await songListService.getDefaultList();

              if (defaultList != null) {
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SongListDetailScreen(listId: defaultList.id),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索诗歌',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Song Lists Section
              _buildSongListsSection(),
              const SizedBox(height: 32),
              // Main hymn lookup section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.music_note,
                      size: 60,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      bookDisplayName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              // Book selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    if (_books.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedBookId,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: _books.entries.map((entry) {
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(
                                entry.value,
                                style: const TextStyle(fontSize: 16),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedBookId = newValue;
                                _errorMessage = null;
                              });
                            }
                          },
                        ),
                      ),
                    const SizedBox(height: 24),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _hymnNumberController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            enabled: !_isLoading,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              labelText: '请输入诗歌编号',
                              hintText: '例如: 1, 101, 501',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 20,
                                horizontal: 16,
                              ),
                              errorText: _errorMessage,
                              errorMaxLines: 2,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '请输入诗歌编号';
                              }
                              final number = int.tryParse(value);
                              if (number == null) {
                                return '请输入有效的数字';
                              }
                              if (number < 1) {
                                return '请输入大于0的数字';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _goToHymn(),
                            onChanged: (_) {
                              // Clear error when user starts typing
                              if (_errorMessage != null) {
                                setState(() {
                                  _errorMessage = null;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _goToHymn,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('查看诗歌'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongListsSection() {
    return Consumer<SongListProvider>(
      builder: (context, provider, child) {
        if (!provider.isLoaded) {
          return const SizedBox.shrink();
        }

        final lists = provider.lists;
        if (lists.isEmpty) {
          return const SizedBox.shrink();
        }

        // Show up to 3 lists as quick access cards
        final displayLists = lists.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Song Lists',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SongListsScreen(),
                        ),
                      );
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                scrollDirection: Axis.horizontal,
                itemCount: displayLists.length,
                itemBuilder: (context, index) {
                  final list = displayLists[index];
                  return Card(
                    margin: const EdgeInsets.only(right: 12),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SongListDetailScreen(listId: list.id),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 160,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Icon(
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
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    list.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${list.hymnCount} hymns',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
