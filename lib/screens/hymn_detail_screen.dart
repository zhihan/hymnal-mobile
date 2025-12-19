import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import '../models/hymn_song.dart';
import '../services/hymn_loader_service.dart';
import '../services/midi_player_service.dart';
import '../widgets/hymn_display.dart';
import '../providers/song_list_provider.dart';
import 'category_detail_screen.dart';

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
  int _transposeOffset = 0;
  bool _showTransposeControls = false;
  bool _showChords = true; // Show chords by default
  int? _nextHymnNumber;
  int? _previousHymnNumber;
  bool _showLanguageNavigation = false;

  // MIDI player
  final MidiPlayerService _midiPlayer = MidiPlayerService();
  bool _isMidiLoaded = false;
  String? _currentMidiUrl;
  int _midiPitchOffset = 0; // Separate pitch offset for MIDI playback

  // PageView state
  late PageController _pageController;
  List<int> _availableHymnNumbers = [];
  int _currentPageIndex = 0;
  Key _pageViewKey = UniqueKey(); // Key to force PageView rebuild when switching books

  // Cache loaded hymns by hymn number
  final Map<int, HymnSong> _hymnCache = {};

  // Book short names for display
  static const Map<String, String> _bookShortNames = {
    'ch': '大',
    'ts': '补',
    'h': 'H',
    'ns': 'NS',
    'nt': 'NT',
  };

  @override
  void initState() {
    super.initState();
    _currentHymnNumber = widget.initialHymnNumber;
    _currentBookId = widget.bookId;
    _initializePageView();
  }

  Future<void> _initializePageView() async {
    try {
      // Load available hymn numbers for the current book
      _availableHymnNumbers = await HymnLoaderService.getAvailableHymnNumbers(_currentBookId);

      // Find the index of the current hymn in the available numbers
      _currentPageIndex = _availableHymnNumbers.indexOf(_currentHymnNumber);
      if (_currentPageIndex == -1) {
        // If hymn number not found, default to first hymn
        _currentPageIndex = 0;
        _currentHymnNumber = _availableHymnNumbers.isNotEmpty ? _availableHymnNumbers[0] : 1;
      }

      // Initialize PageController
      _pageController = PageController(initialPage: _currentPageIndex);

      // Load the initial hymn
      await _loadHymn(_currentHymnNumber);
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _midiPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadHymn(int hymnNumber) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load the hymn (from cache if available)
      HymnSong hymn;
      if (_hymnCache.containsKey(hymnNumber)) {
        hymn = _hymnCache[hymnNumber]!;
      } else {
        hymn = await HymnLoaderService.loadHymnByNumber(_currentBookId, hymnNumber);
        _hymnCache[hymnNumber] = hymn;
      }

      // Update navigation info based on current page index
      int? nextNumber;
      int? previousNumber;

      if (_availableHymnNumbers.isNotEmpty) {
        final currentIndex = _availableHymnNumbers.indexOf(hymnNumber);
        if (currentIndex != -1) {
          if (currentIndex < _availableHymnNumbers.length - 1) {
            nextNumber = _availableHymnNumbers[currentIndex + 1];
          }
          if (currentIndex > 0) {
            previousNumber = _availableHymnNumbers[currentIndex - 1];
          }
        }
      }

      // Extract MIDI URL if available
      final midiUrl = hymn.metadata?['midi_tune_url'] as String?;

      setState(() {
        _currentHymn = hymn;
        _nextHymnNumber = nextNumber;
        _previousHymnNumber = previousNumber;
        _currentHymnNumber = hymnNumber;
        _isLoading = false;
        _transposeOffset = 0; // Reset transpose when loading new hymn
        _isMidiLoaded = false; // Reset MIDI loaded state
        _currentMidiUrl = midiUrl; // Set MIDI URL if available
        _midiPitchOffset = 0; // Reset MIDI pitch when loading new hymn
      });

      // Stop any currently playing MIDI
      await _midiPlayer.stop();

      // Preload adjacent hymns in the background
      _preloadAdjacentHymns(hymnNumber);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _preloadAdjacentHymns(int currentHymnNumber) async {
    if (_availableHymnNumbers.isEmpty) return;

    final currentIndex = _availableHymnNumbers.indexOf(currentHymnNumber);
    if (currentIndex == -1) return;

    // Preload next hymn
    if (currentIndex < _availableHymnNumbers.length - 1) {
      final nextHymnNumber = _availableHymnNumbers[currentIndex + 1];
      if (!_hymnCache.containsKey(nextHymnNumber)) {
        try {
          final nextHymn = await HymnLoaderService.loadHymnByNumber(_currentBookId, nextHymnNumber);
          _hymnCache[nextHymnNumber] = nextHymn;
        } catch (e) {
          // Silently fail preloading
        }
      }
    }

    // Preload previous hymn
    if (currentIndex > 0) {
      final prevHymnNumber = _availableHymnNumbers[currentIndex - 1];
      if (!_hymnCache.containsKey(prevHymnNumber)) {
        try {
          final prevHymn = await HymnLoaderService.loadHymnByNumber(_currentBookId, prevHymnNumber);
          _hymnCache[prevHymnNumber] = prevHymn;
        } catch (e) {
          // Silently fail preloading
        }
      }
    }
  }

  Future<void> _loadAndPlayMidi() async {
    if (_currentMidiUrl == null || _currentMidiUrl!.isEmpty) {
      return;
    }

    // If already loaded, just toggle play/pause
    if (_isMidiLoaded) {
      await _midiPlayer.togglePlayPause();
      setState(() {});
      return;
    }

    // Load MIDI for the first time
    try {
      await _midiPlayer.load(_currentMidiUrl!, transposeOffset: _midiPitchOffset);
      setState(() {
        _isMidiLoaded = true;
      });
      print('MIDI loaded successfully: $_currentMidiUrl');

      // Start playing after loading
      await _midiPlayer.togglePlayPause();
      setState(() {});
    } catch (e) {
      setState(() {
        _isMidiLoaded = false;
      });
      print('Failed to load MIDI: $e');

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load MIDI: $e')),
        );
      }
    }
  }

  void _onPageChanged(int pageIndex) {
    if (pageIndex >= 0 && pageIndex < _availableHymnNumbers.length) {
      final hymnNumber = _availableHymnNumbers[pageIndex];
      _currentPageIndex = pageIndex;
      _loadHymn(hymnNumber);
    }
  }

  void _navigateToPreviousHymn() {
    if (_previousHymnNumber != null && _currentPageIndex > 0) {
      _pageController.animateToPage(
        _currentPageIndex - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _navigateToNextHymn() {
    if (_nextHymnNumber != null && _currentPageIndex < _availableHymnNumbers.length - 1) {
      _pageController.animateToPage(
        _currentPageIndex + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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

  void _midiPitchUp() {
    setState(() {
      _midiPitchOffset++;
    });
    _updateMidiPitch();
  }

  void _midiPitchDown() {
    setState(() {
      _midiPitchOffset--;
    });
    _updateMidiPitch();
  }

  void _resetMidiPitch() {
    setState(() {
      _midiPitchOffset = 0;
    });
    _updateMidiPitch();
  }

  void _updateMidiPitch() {
    if (_isMidiLoaded && _currentMidiUrl != null) {
      // Reload MIDI with new pitch offset
      _midiPlayer.load(_currentMidiUrl!, transposeOffset: _midiPitchOffset).then((_) {
        print('MIDI reloaded with pitch offset: $_midiPitchOffset');
      }).catchError((e) {
        print('Failed to reload MIDI with pitch offset: $e');
      });
    }
  }

  List<Map<String, dynamic>> _getRelatedHymns() {
    if (_currentHymn?.metadata == null) return [];
    final related = _currentHymn!.metadata!['related'];
    if (related == null || related is! List) return [];
    return List<Map<String, dynamic>>.from(related);
  }

  Future<void> _navigateToRelatedHymn(String bookId, String number) async {
    final hymnNumber = int.tryParse(number);
    if (hymnNumber == null) return;

    // If switching to a different book, need to reload available numbers
    if (bookId != _currentBookId) {
      try {
        // Load available hymn numbers for the new book
        final newAvailableNumbers = await HymnLoaderService.getAvailableHymnNumbers(bookId);

        // Find the index of the target hymn
        int newPageIndex = newAvailableNumbers.indexOf(hymnNumber);
        if (newPageIndex == -1) {
          // If hymn not found, default to first hymn
          newPageIndex = 0;
          if (newAvailableNumbers.isNotEmpty) {
            // Use the first available hymn number instead
            final firstHymnNumber = newAvailableNumbers[0];
            final firstHymn = await HymnLoaderService.loadHymnByNumber(bookId, firstHymnNumber);
            _updateBookAndHymn(bookId, firstHymnNumber, firstHymn, newAvailableNumbers, 0);
            return;
          }
        }

        // Load the target hymn
        final newHymn = await HymnLoaderService.loadHymnByNumber(bookId, hymnNumber);

        // Update state
        _updateBookAndHymn(bookId, hymnNumber, newHymn, newAvailableNumbers, newPageIndex);

        // Preload adjacent hymns
        _preloadAdjacentHymns(hymnNumber);
      } catch (e) {
        // Show error but don't block the UI
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load hymn: $e')),
          );
        }
      }
    } else {
      // Same book, just navigate to the hymn
      final pageIndex = _availableHymnNumbers.indexOf(hymnNumber);
      if (pageIndex != -1) {
        _pageController.animateToPage(
          pageIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _updateBookAndHymn(String bookId, int hymnNumber, HymnSong hymn, List<int> availableNumbers, int pageIndex) {
    if (!mounted) return;

    // Save reference to old controller before setState
    final oldController = _pageController;

    setState(() {
      // Create new PageController FIRST
      _pageController = PageController(initialPage: pageIndex);

      // Generate new key to force PageView rebuild
      _pageViewKey = UniqueKey();

      // Update all state
      _currentBookId = bookId;
      _currentHymnNumber = hymnNumber;
      _availableHymnNumbers = availableNumbers;
      _currentPageIndex = pageIndex;
      _currentHymn = hymn;
      _isLoading = false;  // Clear any loading state from previous operations
      _error = null;  // Clear any error state
      _transposeOffset = 0;

      // Clear cache and add new hymn
      _hymnCache.clear();
      _hymnCache[hymnNumber] = hymn;

      // Update navigation info
      if (pageIndex < availableNumbers.length - 1) {
        _nextHymnNumber = availableNumbers[pageIndex + 1];
      } else {
        _nextHymnNumber = null;
      }
      if (pageIndex > 0) {
        _previousHymnNumber = availableNumbers[pageIndex - 1];
      } else {
        _previousHymnNumber = null;
      }
    });

    // Dispose old controller AFTER setState completes
    oldController.dispose();
  }

  String get _currentHymnId => '${_currentBookId}_$_currentHymnNumber';

  void _shareHymn() {
    final shortName = _bookShortNames[_currentBookId] ?? _currentBookId.toUpperCase();
    final hymnTitle = _currentHymn?.title ?? 'Hymn';
    final hymnId = _currentHymnId;
    final deepLink = 'https://cicmusic.net/hymn/$_currentBookId/$_currentHymnNumber';

    final shareText = '''
$hymnId - $hymnTitle

$deepLink
''';

    Share.share(
      shareText,
      subject: '$shortName$_currentHymnNumber - $hymnTitle',
    );
  }

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
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () {
            // Navigate to home screen using GoRouter
            context.go('/');
          },
          tooltip: 'Home',
        ),
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
            icon: const Icon(Icons.share),
            onPressed: _shareHymn,
            tooltip: 'Share hymn',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: _previousHymnNumber != null
                ? _navigateToPreviousHymn
                : null,
            tooltip: _previousHymnNumber != null
                ? 'Previous hymn ($_previousHymnNumber)'
                : 'No previous hymn',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: _nextHymnNumber != null
                ? _navigateToNextHymn
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
                'Unable to Load Hymn',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!.contains('Failed to load')
                    ? 'Hymn #$_currentHymnNumber does not exist\nPlease go back and select another hymn'
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
        // Hymn display with PageView for swipe navigation
        Expanded(
          child: _availableHymnNumbers.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : PageView.builder(
                  key: _pageViewKey,  // Force rebuild when switching books
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _availableHymnNumbers.length,
                  itemBuilder: (context, index) {
                    final hymnNumber = _availableHymnNumbers[index];

                    // Check if this hymn is cached
                    if (_hymnCache.containsKey(hymnNumber)) {
                      return HymnDisplay(
                        hymn: _hymnCache[hymnNumber]!,
                        transposeOffset: index == _currentPageIndex ? _transposeOffset : 0,
                        showChords: _showChords,
                        hymnIdTag: '${_bookShortNames[_currentBookId] ?? _currentBookId.toUpperCase()}$hymnNumber',
                        onCategoryTap: (category) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CategoryDetailScreen(categoryName: category),
                            ),
                          );
                        },
                      );
                    }

                    // Not cached yet, show loading indicator
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
        ),
        // Bottom button bar
        if (_currentMidiUrl != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                top: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // MIDI play/pause button
                ElevatedButton.icon(
                  onPressed: _loadAndPlayMidi,
                  icon: Icon(
                    _midiPlayer.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 24,
                  ),
                  label: Text(
                    _midiPlayer.isPlaying ? 'Pause' : 'Play',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),

                // MIDI pitch down button
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _midiPitchDown,
                  tooltip: 'Lower pitch',
                  iconSize: 28,
                ),
                // Current MIDI pitch offset display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: Text(
                    _midiPitchOffset > 0
                        ? '+$_midiPitchOffset'
                        : _midiPitchOffset.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // MIDI pitch up button
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _midiPitchUp,
                  tooltip: 'Raise pitch',
                  iconSize: 28,
                ),
                // Reset pitch button
                TextButton(
                  onPressed: _midiPitchOffset != 0 ? _resetMidiPitch : null,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
